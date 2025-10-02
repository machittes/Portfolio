//
//  ExpenseRepository.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import Foundation
import CoreData

class ExpenseRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.container.viewContext
    }

    init(persistenceController: PersistenceController = PersistenceController.shared) {
        self.persistenceController = persistenceController
    }

    // MARK: - Create

    func createExpense(
        amount: Decimal,
        date: Date,
        notes: String? = nil,
        title: String? = nil,
        color: String? = nil,
        icon: String? = nil,
        receiptImage: Data? = nil,
        isRecurring: Bool = false,
        category: Category? = nil,
        user: AppUser
    ) async -> Expense? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let expense = Expense(context: self.viewContext)
                expense.id = UUID()
                expense.amount = NSDecimalNumber(decimal: amount)
                expense.date = date
                expense.notes = notes
                expense.title = title
                expense.color = color
                expense.icon = icon
                expense.receiptImage = receiptImage
                expense.isRecurring = isRecurring
                expense.category = category
                expense.user = user
                expense.createdAt = Date()
                expense.updatedAt = Date()
                expense.syncStatus = "created"
                expense.softDeleted = false

                self.save()
                continuation.resume(returning: expense)
            }
        }
    }

    // MARK: - Read

    func fetchExpense(by id: UUID) async -> Expense? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1

                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses.first)
                } catch {
                    Logger.log("Error fetching expense by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    func fetchAllExpenses() async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]

                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching all expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Update

    func updateExpense(
        _ expense: Expense,
        amount: Decimal? = nil,
        date: Date? = nil,
        notes: String? = nil,
        title: String? = nil,
        color: String? = nil,
        icon: String? = nil,
        receiptImage: Data? = nil,
        category: Category? = nil
    ) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                if let amount = amount {
                    expense.amount = NSDecimalNumber(decimal: amount)
                }
                if let date = date {
                    expense.date = date
                }
                if let notes = notes {
                    expense.notes = notes
                }
                if let title = title {
                    expense.title = title
                }
                if let color = color {
                    expense.color = color
                }
                if let icon = icon {
                    expense.icon = icon
                }
                if let receiptImage = receiptImage {
                    expense.receiptImage = receiptImage
                }
                if let category = category {
                    expense.category = category
                }
                
                expense.updatedAt = Date()
                expense.syncStatus = "updated"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Soft Delete (Tombstone Pattern)

    /**
     * Soft delete expense using tombstone pattern
     * Marks as deleted instead of actually removing from database
     */
    func deleteExpense(_ expense: Expense, deletedBy userId: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Create tombstone instead of hard delete
                expense.softDeleted = true
                expense.deletedAt = Date()
                expense.deletedBy = userId
                expense.updatedAt = Date()
                expense.syncStatus = "deleted"
                
                // Handle expense-specific cleanup
                expense.handleCleanupAfterTombstone()
                expense.handleRecurringExpenseTombstone()
                expense.handleReceiptCleanupForTombstone()
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    /**
     * Restore expense from soft delete
     */
    func restoreExpense(_ expense: Expense) async throws {
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    try expense.restoreFromTombstone()
                    self.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /**
     * Fetch deleted expenses (tombstones) for user
     */
    func fetchDeletedExpenses(for user: AppUser) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.deletedAt, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching deleted expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch recently deleted expenses within specified days
     */
    func fetchRecentlyDeleted(for user: AppUser, within days: Int = 30) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt >= %@",
                                              user, cutoffDate as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.deletedAt, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching recently deleted expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch tombstones (deleted expenses) older than specified date for cleanup
     */
    func fetchTombstones(for user: AppUser, olderThan date: Date = Date()) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt < %@",
                                              user, date as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.deletedAt, ascending: true)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching expense tombstones: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Permanently delete old tombstones for cleanup
     */
    func cleanupOldTombstones(for user: AppUser, olderThan days: Int = 90) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let tombstones = await fetchTombstones(for: user, olderThan: cutoffDate)
        
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for tombstone in tombstones {
                    self.viewContext.delete(tombstone)
                }
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    /**
     * Fetch active expenses (excludes soft-deleted by default)
     */
    func fetchExpenses(for user: AppUser, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch expenses for date range (excludes soft-deleted by default)
     */
    func fetchExpenses(for user: AppUser, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND date >= %@ AND date <= %@",
                                                  user, startDate as NSDate, endDate as NSDate)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND date >= %@ AND date <= %@",
                                                  user, startDate as NSDate, endDate as NSDate)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching expenses for date range: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch expenses for category (excludes soft-deleted by default)
     */
    func fetchExpenses(for category: Category, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO", category)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching expenses for category: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch recurring expenses (excludes soft-deleted by default)
     */
    func fetchRecurringExpenses(for user: AppUser, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND isRecurring == YES", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND isRecurring == YES", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch uncategorized expenses (excludes soft-deleted by default)
     */
    func fetchUncategorizedExpenses(for user: AppUser, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND category == nil", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND category == nil", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching uncategorized expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Search expenses (excludes soft-deleted by default)
     */
    func searchExpenses(for user: AppUser, searchText: String, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND notes CONTAINS[cd] %@", user, searchText)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND notes CONTAINS[cd] %@", user, searchText)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error searching expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Sync Status Methods

    /**
     * Fetch pending sync expenses (created, updated, deleted)
     */
    func fetchPendingSyncExpenses(for user: AppUser) async -> [Expense] {
        async let createdExpenses = fetchExpensesWithSyncStatus("created", for: user)
        async let updatedExpenses = fetchExpensesWithSyncStatus("updated", for: user)
        async let deletedExpenses = fetchExpensesWithSyncStatus("deleted", for: user)
        
        return await createdExpenses + updatedExpenses + deletedExpenses
    }

    /**
     * Fetch expenses with specific sync status (excludes soft-deleted by default)
     */
    func fetchExpensesWithSyncStatus(_ status: String, for user: AppUser, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@", status, user)
                } else {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@ AND softDeleted == NO", status, user)
                }
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching expenses with sync status: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Mark expense as synced
     */
    func markExpenseAsSynced(_ expense: Expense) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                expense.syncStatus = "synced"
                expense.updatedAt = Date()
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Enhanced Analytics Methods (with tombstone awareness)

    /**
     * Get total expenses (excludes soft-deleted by default)
     */
    func getTotalExpenses(for user: AppUser, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> Decimal {
        let expenses = await fetchExpenses(for: user, from: startDate, to: endDate, includeDeleted: includeDeleted)
        return expenses.reduce(Decimal.zero) { total, expense in
            total + (expense.amount?.decimalValue ?? Decimal.zero)
        }
    }

    /**
     * Get total expenses for category (excludes soft-deleted by default)
     */
    func getTotalExpenses(for category: Category, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> Decimal {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@ AND date >= %@ AND date <= %@",
                                                  category, startDate as NSDate, endDate as NSDate)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO AND date >= %@ AND date <= %@",
                                                  category, startDate as NSDate, endDate as NSDate)
                }
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    let total = expenses.reduce(Decimal.zero) { total, expense in
                        total + (expense.amount?.decimalValue ?? Decimal.zero)
                    }
                    continuation.resume(returning: total)
                } catch {
                    Logger.log("Error calculating total expenses for category: \(error)", level: .error)
                    continuation.resume(returning: Decimal.zero)
                }
            }
        }
    }

    /**
     * Get total expenses for month (excludes soft-deleted by default)
     */
    func getTotalExpenses(for user: AppUser, in month: Date, includeDeleted: Bool = false) async -> Decimal {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: month)?.start ?? month
        let endOfMonth = calendar.dateInterval(of: .month, for: month)?.end ?? month
        
        return await getTotalExpenses(for: user, from: startOfMonth, to: endOfMonth, includeDeleted: includeDeleted)
    }

    /**
     * Get average monthly expenses (excludes soft-deleted by default)
     */
    func getAverageMonthlyExpenses(for user: AppUser, months: Int = 6, includeDeleted: Bool = false) async -> Decimal {
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .month, value: -months, to: endDate) ?? endDate
        
        let totalExpenses = await getTotalExpenses(for: user, from: startDate, to: endDate, includeDeleted: includeDeleted)
        return totalExpenses / Decimal(months)
    }

    /**
     * Get expenses by category (excludes soft-deleted by default)
     */
    func getExpensesByCategory(for user: AppUser, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> [String: Decimal] {
        let expenses = await fetchExpenses(for: user, from: startDate, to: endDate, includeDeleted: includeDeleted)
        var expensesByCategory: [String: Decimal] = [:]
        
        for expense in expenses {
            let categoryName = expense.category?.name ?? "Uncategorized"
            expensesByCategory[categoryName, default: Decimal.zero] += (expense.amount?.decimalValue ?? Decimal.zero)
        }
        
        return expensesByCategory
    }

    /**
     * Get daily expenses (excludes soft-deleted by default)
     */
    func getDailyExpenses(for user: AppUser, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> [Date: Decimal] {
        let expenses = await fetchExpenses(for: user, from: startDate, to: endDate, includeDeleted: includeDeleted)
        var dailyExpenses: [Date: Decimal] = [:]
        let calendar = Calendar.current
        
        for expense in expenses {
            guard let expenseDate = expense.date else { continue }
            let day = calendar.startOfDay(for: expenseDate)
            dailyExpenses[day, default: Decimal.zero] += (expense.amount?.decimalValue ?? Decimal.zero)
        }
        
        return dailyExpenses
    }

    /**
     * Get largest expenses (excludes soft-deleted by default)
     */
    func getLargestExpenses(for user: AppUser, limit: Int = 10, includeDeleted: Bool = false) async -> [Expense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.amount, ascending: false)]
                request.fetchLimit = limit
                
                do {
                    let expenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: expenses)
                } catch {
                    Logger.log("Error fetching largest expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Get expense count (excludes soft-deleted by default)
     */
    func getExpenseCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting expenses: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    /**
     * Get expense count for category (excludes soft-deleted by default)
     */
    func getExpenseCount(for category: Category, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO", category)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting expenses for category: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    /**
     * Check if category has expenses (excludes soft-deleted by default)
     */
    func hasExpenses(for category: Category, includeDeleted: Bool = false) async -> Bool {
        let count = await getExpenseCount(for: category, includeDeleted: includeDeleted)
        return count > 0
    }

    /**
     * Check if user has expenses with receipts (excludes soft-deleted by default)
     */
    func hasExpensesWithReceipts(for user: AppUser, includeDeleted: Bool = false) async -> Bool {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND receiptImage != nil", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND receiptImage != nil", user)
                }
                
                request.fetchLimit = 1
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    Logger.log("Error checking for expenses with receipts: \(error)", level: .error)
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    // MARK: - Hard Delete Methods (for permanent deletion)

    /**
     * Permanently delete expense (hard delete)
     */
    func deleteExpense(_ expense: Expense) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                self.viewContext.delete(expense)
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    /**
     * Permanently delete expense by ID (hard delete)
     */
    func deleteExpense(by id: UUID) async {
        if let expense = await fetchExpense(by: id) {
            await deleteExpense(expense)
        }
    }
    
    /**
     * Permanently delete all expenses for category (hard delete)
     */
    func deleteExpenses(for category: Category) async {
        let expenses = await fetchExpenses(for: category)
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for expense in expenses {
                    self.viewContext.delete(expense)
                }
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func save() {
        let result = persistenceController.save()
        switch result {
        case .success:
            break // Success - no action needed
        case .failure(let error):
            Logger.log("ExpenseRepository save failed: \(error.localizedDescription)", level: .error)
            // Repository-level error handling - could emit to error stream or delegate
        }
    }
}
