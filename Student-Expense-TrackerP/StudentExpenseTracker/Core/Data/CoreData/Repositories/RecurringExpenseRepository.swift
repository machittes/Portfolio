//
//  RecurringExpenseRepository.swift
//  StudentExpenseTracker
//

import Foundation
import CoreData

@Observable
class RecurringExpenseRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create
    
    func createRecurringExpense(title: String, amount: Decimal, frequency: String,
                               startDate: Date = Date(), endDate: Date? = nil,
                               dayOfMonthWeek: Int16? = nil, notes: String? = nil,
                               isActive: Bool = true, category: Category? = nil,
                               color: String? = nil, icon: String? = nil,
                               user: AppUser) async -> RecurringExpense? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let recurringExpense = RecurringExpense(context: self.viewContext)
                recurringExpense.id = UUID()
                recurringExpense.title = title
                recurringExpense.amount = NSDecimalNumber(decimal: amount)
                recurringExpense.frequency = frequency
                recurringExpense.startDate = startDate
                recurringExpense.endDate = endDate
                recurringExpense.dayOfMonthWeek = dayOfMonthWeek ?? 0
                recurringExpense.notes = notes
                recurringExpense.isActive = isActive
                recurringExpense.category = category
                recurringExpense.color = color
                recurringExpense.icon = icon
                recurringExpense.user = user
                recurringExpense.createdAt = Date()
                recurringExpense.updatedAt = Date()
                recurringExpense.syncStatus = "created"
                
                // Initialize tombstone fields
                recurringExpense.softDeleted = false
                recurringExpense.deletedAt = nil
                recurringExpense.deletedBy = nil
                
                self.save()
                continuation.resume(returning: recurringExpense)
            }
        }
    }
    
    // MARK: - Read (Tombstone-Aware)
    
    /**
     * Fetch recurring expenses for user (excludes soft-deleted by default)
     */
    func fetchRecurringExpenses(for user: AppUser, includeDeleted: Bool = false) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \RecurringExpense.isActive, ascending: false),
                    NSSortDescriptor(keyPath: \RecurringExpense.startDate, ascending: false)
                ]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch active recurring expenses (excludes soft-deleted by default)
     */
    func fetchActiveRecurringExpenses(for user: AppUser, includeDeleted: Bool = false) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND isActive == YES", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND isActive == YES", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.startDate, ascending: false)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching active recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch recurring expenses for category (excludes soft-deleted by default)
     */
    func fetchRecurringExpenses(for category: Category, includeDeleted: Bool = false) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO", category)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.startDate, ascending: false)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching recurring expenses for category: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchRecurringExpense(by id: UUID) async -> RecurringExpense? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses.first)
                } catch {
                    Logger.log("Error fetching recurring expense by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchRecurringExpenses(by frequency: String, for user: AppUser, includeDeleted: Bool = false) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND frequency == %@", user, frequency)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND frequency == %@ AND softDeleted == NO", user, frequency)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.startDate, ascending: false)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching recurring expenses by frequency: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchDueRecurringExpenses(for user: AppUser, on date: Date = Date()) async -> [RecurringExpense] {
        let activeExpenses = await fetchActiveRecurringExpenses(for: user)
        return activeExpenses.filter { recurringExpense in
            isDue(recurringExpense: recurringExpense, on: date)
        }
    }
    
    // MARK: - Tombstone-Specific Read Methods
    
    /**
     * Fetch deleted recurring expenses (tombstones) for user
     */
    func fetchDeletedRecurringExpenses(for user: AppUser) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.deletedAt, ascending: false)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching deleted recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch recently deleted recurring expenses within specified days
     */
    func fetchRecentlyDeleted(for user: AppUser, within days: Int = 30) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt >= %@",
                                              user, cutoffDate as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.deletedAt, ascending: false)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching recently deleted recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch tombstones (deleted recurring expenses) older than specified date for cleanup
     */
    func fetchTombstones(for user: AppUser, olderThan date: Date = Date()) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt < %@",
                                              user, date as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.deletedAt, ascending: true)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching recurring expense tombstones: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Update
    
    func updateRecurringExpense(_ recurringExpense: RecurringExpense, title: String? = nil,
                               amount: Decimal? = nil, frequency: String? = nil,
                               startDate: Date? = nil, endDate: Date? = nil,
                               dayOfMonthWeek: Int16? = nil, notes: String? = nil,
                               isActive: Bool? = nil, category: Category? = nil,
                               color: String? = nil, icon: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                if let title = title {
                    recurringExpense.title = title
                }
                if let amount = amount {
                    recurringExpense.amount = NSDecimalNumber(decimal: amount)
                }
                if let frequency = frequency {
                    recurringExpense.frequency = frequency
                }
                if let startDate = startDate {
                    recurringExpense.startDate = startDate
                }
                if let endDate = endDate {
                    recurringExpense.endDate = endDate
                }
                if let dayOfMonthWeek = dayOfMonthWeek {
                    recurringExpense.dayOfMonthWeek = dayOfMonthWeek
                }
                if let notes = notes {
                    recurringExpense.notes = notes
                }
                if let isActive = isActive {
                    recurringExpense.isActive = isActive
                }
                if let category = category {
                    recurringExpense.category = category
                }
                if let color = color {
                    recurringExpense.color = color
                }
                if let icon = icon {
                    recurringExpense.icon = icon
                }
                
                recurringExpense.updatedAt = Date()
                recurringExpense.syncStatus = "updated"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    func activateRecurringExpense(_ recurringExpense: RecurringExpense) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                recurringExpense.isActive = true
                recurringExpense.updatedAt = Date()
                recurringExpense.syncStatus = "updated"
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    func deactivateRecurringExpense(_ recurringExpense: RecurringExpense) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                recurringExpense.isActive = false
                recurringExpense.updatedAt = Date()
                recurringExpense.syncStatus = "updated"
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Soft Delete (Tombstone Pattern)
    
    /**
     * Soft delete recurring expense using tombstone pattern
     * Marks as deleted instead of actually removing from database
     */
    func deleteRecurringExpense(_ recurringExpense: RecurringExpense, deletedBy userId: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Create tombstone instead of hard delete
                recurringExpense.softDeleted = true
                recurringExpense.deletedAt = Date()
                recurringExpense.deletedBy = userId
                recurringExpense.updatedAt = Date()
                recurringExpense.syncStatus = "deleted"
                
                // Recurring expense-specific cleanup
                recurringExpense.isActive = false
                recurringExpense.handleDependenciesAfterTombstone()
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    /**
     * Restore recurring expense from soft delete
     */
    func restoreRecurringExpense(_ recurringExpense: RecurringExpense) async throws {
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    try recurringExpense.restoreFromTombstone()
                    self.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
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
        
        Logger.log("Cleaned up \(tombstones.count) old recurring expense tombstones", level: .info)
    }
    
    // MARK: - Validation and Dependency Checking
    
    /**
     * Check if recurring expense title exists for user (excluding soft-deleted)
     */
    func recurringExpenseExists(title: String, for user: AppUser, includeDeleted: Bool = false) async -> Bool {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "title ==[c] %@ AND user == %@", title, user)
                } else {
                    request.predicate = NSPredicate(format: "title ==[c] %@ AND user == %@ AND softDeleted == NO", title, user)
                }
                
                request.fetchLimit = 1
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    Logger.log("Error checking recurring expense existence: \(error)", level: .error)
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /**
     * Get count of dependencies for recurring expense (generated expenses)
     */
    func getRecurringExpenseDependencyInfo(_ recurringExpense: RecurringExpense) async -> RecurringExpenseDependencyInfo {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                // Count generated expenses that are not soft-deleted
                let expenseRequest: NSFetchRequest<Expense> = Expense.fetchRequest()
                expenseRequest.predicate = NSPredicate(format: "recurringExpense == %@ AND softDeleted == NO", recurringExpense)
                
                let generatedExpenseCount = (try? self.viewContext.count(for: expenseRequest)) ?? 0
                
                let dependencyInfo = RecurringExpenseDependencyInfo(
                    generatedExpenseCount: generatedExpenseCount
                )
                
                continuation.resume(returning: dependencyInfo)
            }
        }
    }
    
    /**
     * Check if recurring expense can be safely deleted (tombstone-aware)
     */
    func canSafelyDelete(_ recurringExpense: RecurringExpense) async -> (canDelete: Bool, reason: String?) {
        let dependencyInfo = await getRecurringExpenseDependencyInfo(recurringExpense)
        
        // For recurring expenses, we allow deletion even with generated expenses
        // because they represent historical data that should be preserved
        if dependencyInfo.hasAnyDependencies {
            let warningMessage = "This recurring expense has \(dependencyInfo.generatedExpenseCount) generated expenses. They will be marked as orphaned but preserved."
            return (true, warningMessage)
        }
        
        return (true, nil)
    }
    
    // MARK: - Hard Delete (Legacy Support for Category Deletion)
    
    func deleteRecurringExpense(by id: UUID) async {
        if let recurringExpense = await fetchRecurringExpense(by: id) {
            await deleteRecurringExpense(recurringExpense)
        }
    }
    
    func deleteRecurringExpenses(for category: Category) async {
        let recurringExpenses = await fetchRecurringExpenses(for: category)
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for recurringExpense in recurringExpenses {
                    // Use soft delete for category deletion
                    recurringExpense.softDeleted = true
                    recurringExpense.deletedAt = Date()
                    recurringExpense.deletedBy = "system_category_deletion"
                    recurringExpense.syncStatus = "deleted"
                    recurringExpense.isActive = false
                    recurringExpense.handleDependenciesAfterTombstone()
                }
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Recurring Logic (Tombstone-Aware)
    
    func isDue(recurringExpense: RecurringExpense, on date: Date) -> Bool {
        guard let startDate = recurringExpense.startDate,
              startDate <= date,
              !recurringExpense.softDeleted else { return false }
        
        // Check if expired
        if let endDate = recurringExpense.endDate, date > endDate {
            return false
        }
        
        let calendar = Calendar.current
        
        switch recurringExpense.frequency?.lowercased() {
        case "daily":
            return true
            
        case "weekly":
            if recurringExpense.dayOfMonthWeek > 0 {
                let currentWeekday = calendar.component(.weekday, from: date)
                return currentWeekday == recurringExpense.dayOfMonthWeek
            }
            return calendar.component(.weekday, from: date) == calendar.component(.weekday, from: startDate)
            
        case "monthly":
            if recurringExpense.dayOfMonthWeek > 0 {
                let currentDay = calendar.component(.day, from: date)
                return currentDay == recurringExpense.dayOfMonthWeek
            }
            return calendar.component(.day, from: date) == calendar.component(.day, from: startDate)
            
        case "yearly":
            let startComponents = calendar.dateComponents([.month, .day], from: startDate)
            let currentComponents = calendar.dateComponents([.month, .day], from: date)
            return startComponents.month == currentComponents.month && startComponents.day == currentComponents.day
            
        default:
            return false
        }
    }
    
    func getNextDueDate(for recurringExpense: RecurringExpense, after date: Date = Date()) -> Date? {
        guard let startDate = recurringExpense.startDate,
              !recurringExpense.softDeleted else { return nil }
        
        // Check if expired
        if let endDate = recurringExpense.endDate, date > endDate {
            return nil
        }
        
        let calendar = Calendar.current
        var nextDate = date
        
        switch recurringExpense.frequency?.lowercased() {
        case "daily":
            nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            
        case "weekly":
            if recurringExpense.dayOfMonthWeek > 0 {
                nextDate = calendar.nextDate(after: date, matching: DateComponents(weekday: Int(recurringExpense.dayOfMonthWeek)), matchingPolicy: .nextTime) ?? date
            } else {
                nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? date
            }

        case "monthly":
            if recurringExpense.dayOfMonthWeek > 0 {
                nextDate = calendar.nextDate(after: date, matching: DateComponents(day: Int(recurringExpense.dayOfMonthWeek)), matchingPolicy: .nextTime) ?? date
            } else {
                nextDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? date
            }
            
        case "yearly":
            nextDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? date
            
        default:
            return nil
        }
        
        // Ensure next date doesn't exceed end date
        if let endDate = recurringExpense.endDate, nextDate > endDate {
            return nil
        }
        
        return nextDate
    }
    
//    func generateExpense(from recurringExpense: RecurringExpense, on date: Date, expenseRepository: ExpenseRepository) async -> Expense? {
//        guard let user = recurringExpense.user,
//              let amount = recurringExpense.amount?.decimalValue,
//              !recurringExpense.softDeleted else { return nil }
//
//        let expense = await expenseRepository.createExpense(
//            amount: amount,
//            date: date,
//            notes: recurringExpense.notes,
//            isRecurring: true,
//            category: recurringExpense.category,
//            recurringExpense: recurringExpense,
//            user: user
//        )
//
//        return expense
//    }

    func generateExpense(from recurringExpense: RecurringExpense, on date: Date, expenseRepository: ExpenseRepository) async -> Expense? {
        guard let user = recurringExpense.user,
              let amount = recurringExpense.amount?.decimalValue,
              !recurringExpense.softDeleted else { return nil }
        
        let expense = await expenseRepository.createExpense(
            amount: amount,
            date: date,
            notes: recurringExpense.notes,
            title: recurringExpense.title,
            color: recurringExpense.color,
            icon: recurringExpense.icon,
            isRecurring: true,
            category: recurringExpense.category,
            user: user
        )
        
        // Set the recurring expense relationship after creation
        if let expense = expense {
            await withCheckedContinuation { continuation in
                viewContext.perform {
                    expense.recurringExpense = recurringExpense
                    expense.updatedAt = Date()
                    self.save()
                    continuation.resume(returning: ())
                }
            }
        }
        
        return expense
    }
    
    // MARK: - Analytics (Tombstone-Aware)
    
    func getTotalMonthlyRecurringAmount(for user: AppUser) async -> Decimal {
        let activeRecurring = await fetchActiveRecurringExpenses(for: user)
        var totalMonthly: Decimal = 0
        
        for recurringExpense in activeRecurring {
            guard let amount = recurringExpense.amount?.decimalValue else { continue }
            
            switch recurringExpense.frequency?.lowercased() {
            case "daily":
                totalMonthly += amount * 30 // Approximate
            case "weekly":
                totalMonthly += amount * 4.33 // Approximate weeks per month
            case "monthly":
                totalMonthly += amount
            case "yearly":
                totalMonthly += amount / 12
            default:
                break
            }
        }
        
        return totalMonthly
    }
    
    func getRecurringExpensesByCategory(for user: AppUser) async -> [String: Decimal] {
        let activeRecurring = await fetchActiveRecurringExpenses(for: user)
        var expensesByCategory: [String: Decimal] = [:]
        
        for recurringExpense in activeRecurring {
            let categoryName = recurringExpense.category?.name ?? "Uncategorized"
            let monthlyAmount = getMonthlyEquivalent(for: recurringExpense)
            expensesByCategory[categoryName, default: Decimal.zero] += monthlyAmount
        }
        
        return expensesByCategory
    }
    
    private func getMonthlyEquivalent(for recurringExpense: RecurringExpense) -> Decimal {
        guard let amount = recurringExpense.amount?.decimalValue else { return Decimal.zero }
        
        switch recurringExpense.frequency?.lowercased() {
        case "daily":
            return amount * 30
        case "weekly":
            return amount * 4.33
        case "monthly":
            return amount
        case "yearly":
            return amount / 12
        default:
            return Decimal.zero
        }
    }
    
    // MARK: - Sync Support Methods
    
    /**
     * Fetch recurring expenses with specific sync status for user
     */
//    func fetchRecurringExpensesWithSyncStatus(_ status: String, for user: AppUser) async -> [RecurringExpense] {
//        return await withCheckedContinuation { continuation in
//            viewContext.perform {
//                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
//                request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@", status, user)
//                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.updatedAt, ascending: true)]
//
//                do {
//                    let recurringExpenses = try self.viewContext.fetch(request)
//                    continuation.resume(returning: recurringExpenses)
//                } catch {
//                    Logger.log("Error fetching recurring expenses with sync status: \(error)", level: .error)
//                    continuation.resume(returning: [])
//                }
//            }
//        }
//    }

    func fetchRecurringExpensesWithSyncStatus(_ status: String, for user: AppUser, includeDeleted: Bool = false) async -> [RecurringExpense] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@", status, user)
                } else {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@ AND softDeleted == NO", status, user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringExpense.updatedAt, ascending: true)]
                
                do {
                    let recurringExpenses = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringExpenses)
                } catch {
                    Logger.log("Error fetching recurring expenses with sync status: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch all pending sync recurring expenses (created, updated, deleted)
     */
    func fetchPendingSyncRecurringExpenses(for user: AppUser) async -> [RecurringExpense] {
        async let createdRecurringExpenses = fetchRecurringExpensesWithSyncStatus("created", for: user)
        async let updatedRecurringExpenses = fetchRecurringExpensesWithSyncStatus("updated", for: user)
        async let deletedRecurringExpenses = fetchRecurringExpensesWithSyncStatus("deleted", for: user)
        
        return await createdRecurringExpenses + updatedRecurringExpenses + deletedRecurringExpenses
    }
    
    func markRecurringExpenseAsSynced(_ recurringExpense: RecurringExpense) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                recurringExpense.syncStatus = "synced"
                recurringExpense.updatedAt = Date()
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Helper Methods (Tombstone-Aware)
    
    private func save() {
        let result = persistenceController.save()
        switch result {
        case .success:
            break // Success - no action needed
        case .failure(let error):
            Logger.log("RecurringExpenseRepository save failed: \(error.localizedDescription)", level: .error)
            // Repository-level error handling - could emit to error stream or delegate
        }
    }
    
    func getRecurringExpenseCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func getActiveRecurringExpenseCount(for user: AppUser) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND isActive == YES AND softDeleted == NO", user)
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting active recurring expenses: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    func getRecurringExpenseCount(for category: Category, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringExpense> = RecurringExpense.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO", category)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting recurring expenses for category: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    func hasRecurringExpenses(for category: Category, includeDeleted: Bool = false) async -> Bool {
        let count = await getRecurringExpenseCount(for: category, includeDeleted: includeDeleted)
        return count > 0
    }
}

// MARK: - Supporting Structures

struct RecurringExpenseDependencyInfo {
    let generatedExpenseCount: Int
    
    var hasAnyDependencies: Bool {
        generatedExpenseCount > 0
    }
    
    var impactMessage: String {
        var messages: [String] = []
        
        if generatedExpenseCount > 0 {
            messages.append("• \(generatedExpenseCount) generated expense\(generatedExpenseCount == 1 ? "" : "s") will be marked as orphaned")
        }
        
        return messages.joined(separator: "\n")
    }
}
