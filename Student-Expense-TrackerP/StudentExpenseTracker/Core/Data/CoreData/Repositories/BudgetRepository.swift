//
//  BudgetRepository.swift
//  StudentExpenseTracker
//

import Foundation
import CoreData

@Observable
class BudgetRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create
    
    func createBudget(
        amount: Decimal,
        period: String,
        startDate: Date,
        endDate: Date,
        alertThreshold: Double? = nil,
        isActive: Bool = true,
        category: Category? = nil,
        user: AppUser
    ) async -> Budget? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let budget = Budget(context: self.viewContext)
                budget.id = UUID()
                budget.amount = NSDecimalNumber(decimal: amount)
                budget.period = period
                budget.startDate = startDate
                budget.endDate = endDate
                budget.alertThreshold = alertThreshold ?? 0.8
                budget.isActive = isActive
                budget.category = category
                budget.user = user
                budget.createdAt = Date()
                budget.updatedAt = Date()
                budget.syncStatus = "created"
                budget.softDeleted = false
                
                self.save()
                continuation.resume(returning: budget)
            }
        }
    }
    
    // MARK: - Read (Tombstone-Aware)
    
    func fetchBudgets(for user: AppUser, includeDeleted: Bool = false) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Budget.startDate, ascending: false),
                    NSSortDescriptor(keyPath: \Budget.amount, ascending: false)
                ]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching budgets: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchActiveBudgets(for user: AppUser, includeDeleted: Bool = false) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND isActive == YES", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND isActive == YES", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching active budgets: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchBudgets(for category: Category, includeDeleted: Bool = false) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO", category)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching budgets for category: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchOverallBudgets(for user: AppUser, includeDeleted: Bool = false) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND category == nil", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND category == nil AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching overall budgets: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchBudget(by id: UUID) async -> Budget? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets.first)
                } catch {
                    Logger.log("Error fetching budget by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchCurrentBudget(for category: Category? = nil, user: AppUser, includeDeleted: Bool = false) async -> Budget? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let currentDate = Date()
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if let category = category {
                    if includeDeleted {
                        request.predicate = NSPredicate(format: "user == %@ AND category == %@ AND isActive == YES AND startDate <= %@",
                                                      user, category, currentDate as NSDate)
                    } else {
                        request.predicate = NSPredicate(format: "user == %@ AND category == %@ AND softDeleted == NO AND isActive == YES AND startDate <= %@",
                                                      user, category, currentDate as NSDate)
                    }
                } else {
                    if includeDeleted {
                        request.predicate = NSPredicate(format: "user == %@ AND category == nil AND isActive == YES AND startDate <= %@",
                                                      user, currentDate as NSDate)
                    } else {
                        request.predicate = NSPredicate(format: "user == %@ AND category == nil AND softDeleted == NO AND isActive == YES AND startDate <= %@",
                                                      user, currentDate as NSDate)
                    }
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
                request.fetchLimit = 1
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets.first)
                } catch {
                    Logger.log("Error fetching current budget: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchBudgets(by period: String, for user: AppUser, includeDeleted: Bool = false) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND period == %@", user, period)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND period == %@ AND softDeleted == NO", user, period)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.startDate, ascending: false)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching budgets by period: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Update
    
    func updateBudget(
        _ budget: Budget,
        amount: Decimal? = nil,
        period: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        alertThreshold: Double? = nil,
        isActive: Bool? = nil,
        category: Category? = nil
    ) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                if let amount = amount {
                    budget.amount = NSDecimalNumber(decimal: amount)
                }
                if let period = period {
                    budget.period = period
                }
                if let startDate = startDate {
                    budget.startDate = startDate
                }
                if let endDate = endDate {
                    budget.endDate = endDate
                }
                if let alertThreshold = alertThreshold {
                    budget.alertThreshold = alertThreshold
                }
                if let isActive = isActive {
                    budget.isActive = isActive
                }
                if let category = category {
                    budget.category = category
                }
                
                budget.updatedAt = Date()
                budget.syncStatus = "updated"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    func activateBudget(_ budget: Budget) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                budget.isActive = true
                budget.updatedAt = Date()
                budget.syncStatus = "updated"
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    func deactivateBudget(_ budget: Budget) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                budget.isActive = false
                budget.updatedAt = Date()
                budget.syncStatus = "updated"
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    // MARK: - Soft Delete Methods (Tombstone Pattern)

    /**
     * Soft delete budget using tombstone pattern
     */
    func deleteBudget(_ budget: Budget, deletedBy userId: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Create tombstone instead of hard delete
                budget.softDeleted = true
                budget.deletedAt = Date()
                budget.deletedBy = userId
                budget.updatedAt = Date()
                budget.syncStatus = "deleted"
                budget.isActive = false // Deactivate when deleted
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    /**
     * Restore budget from soft delete
     */
    func restoreBudget(_ budget: Budget) async throws {
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    try budget.restoreFromTombstone()
                    self.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /**
     * Fetch deleted budgets (tombstones) for user
     */
    func fetchDeletedBudgets(for user: AppUser) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.deletedAt, ascending: false)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching deleted budgets: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch recently deleted budgets within specified days
     */
    func fetchRecentlyDeleted(for user: AppUser, within days: Int = 30) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt >= %@",
                                              user, cutoffDate as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.deletedAt, ascending: false)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching recently deleted budgets: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch tombstones (deleted budgets) older than specified date for cleanup
     */
    func fetchTombstones(for user: AppUser, olderThan date: Date = Date()) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt < %@",
                                              user, date as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Budget.deletedAt, ascending: true)]
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching budget tombstones: \(error)", level: .error)
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
     * Fetch all budgets including deleted ones
     */
    func fetchAllBudgets(for user: AppUser, includeDeleted: Bool = false) async -> [Budget] {
        return await fetchBudgets(for: user, includeDeleted: includeDeleted)
    }

    /**
     * Fetch pending sync budgets (created, updated, deleted)
     */
    func fetchPendingSyncBudgets(for user: AppUser) async -> [Budget] {
        async let createdBudgets = fetchBudgetsWithSyncStatus("created", for: user)
        async let updatedBudgets = fetchBudgetsWithSyncStatus("updated", for: user)
        async let deletedBudgets = fetchBudgetsWithSyncStatus("deleted", for: user)
        
        return await createdBudgets + updatedBudgets + deletedBudgets
    }
    
    // MARK: - Budget Analysis (Tombstone-Aware)
    
    func getBudgetProgress(for budget: Budget, expenseRepository: ExpenseRepository) async -> (spent: Decimal, remaining: Decimal, percentage: Double) {
        let budgetAmount = budget.amount?.decimalValue ?? Decimal.zero
        let startDate = budget.startDate ?? Date()
        let endDate = getBudgetEndDate(for: budget)
        
        var spent: Decimal = Decimal.zero
        
        if let category = budget.category {
            spent = await expenseRepository.getTotalExpenses(for: category, from: startDate, to: endDate, includeDeleted: false)
        } else if let user = budget.user {
            spent = await expenseRepository.getTotalExpenses(for: user, from: startDate, to: endDate, includeDeleted: false)
        }
        
        let remaining = max(budgetAmount - spent, Decimal.zero)
        let percentage = budgetAmount > 0 ? Double(truncating: NSDecimalNumber(decimal: spent / budgetAmount)) : 0.0
        
        return (spent: spent, remaining: remaining, percentage: percentage)
    }
    
    func getBudgetEndDate(for budget: Budget) -> Date {
        guard let startDate = budget.startDate else { return Date() }
        let calendar = Calendar.current
        
        switch budget.period?.lowercased() {
        case "daily":
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case "weekly":
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case "monthly":
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case "yearly":
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        default:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        }
    }
    
    func getBudgetsExceedingThreshold(for user: AppUser, expenseRepository: ExpenseRepository) async -> [Budget] {
        let activeBudgets = await fetchActiveBudgets(for: user, includeDeleted: false)
        var exceedingBudgets: [Budget] = []
        
        for budget in activeBudgets {
            let progress = await getBudgetProgress(for: budget, expenseRepository: expenseRepository)
            if progress.percentage >= budget.alertThreshold {
                exceedingBudgets.append(budget)
            }
        }
        
        return exceedingBudgets
    }
    
    func getBudgetUtilization(for user: AppUser, expenseRepository: ExpenseRepository) async -> [String: Double] {
        let activeBudgets = await fetchActiveBudgets(for: user, includeDeleted: false)
        var utilization: [String: Double] = [:]
        
        for budget in activeBudgets {
            let categoryName = budget.category?.name ?? "Overall"
            let progress = await getBudgetProgress(for: budget, expenseRepository: expenseRepository)
            utilization[categoryName] = progress.percentage
        }
        
        return utilization
    }
    
    // MARK: - Sync Status (Tombstone-Aware)
    
    func fetchBudgetsWithSyncStatus(_ status: String, for user: AppUser, includeDeleted: Bool = false) async -> [Budget] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@", status, user)
                } else {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@ AND softDeleted == NO", status, user)
                }
                
                do {
                    let budgets = try self.viewContext.fetch(request)
                    continuation.resume(returning: budgets)
                } catch {
                    Logger.log("Error fetching budgets with sync status: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func markBudgetAsSynced(_ budget: Budget) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                budget.syncStatus = "synced"
                budget.updatedAt = Date()
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
            Logger.log("BudgetRepository save failed: \(error.localizedDescription)", level: .error)
            // Repository-level error handling - could emit to error stream or delegate
        }
    }
    
    func getBudgetCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting budgets: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func getActiveBudgetCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND isActive == YES", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND isActive == YES AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting active budgets: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func hasActiveBudget(for category: Category, includeDeleted: Bool = false) async -> Bool {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@ AND isActive == YES", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND isActive == YES AND softDeleted == NO", category)
                }
                
                request.fetchLimit = 1
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    Logger.log("Error checking for budget: \(error)", level: .error)
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    func getBudgetCount(for category: Category, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Budget> = Budget.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "category == %@", category)
                } else {
                    request.predicate = NSPredicate(format: "category == %@ AND softDeleted == NO", category)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting budgets for category: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    func hasBudgets(for category: Category, includeDeleted: Bool = false) async -> Bool {
        let count = await getBudgetCount(for: category, includeDeleted: includeDeleted)
        return count > 0
    }
    
//    // MARK: - Legacy Hard Delete Methods (Deprecated - Use Soft Delete Instead)
//
//    @available(*, deprecated, message: "Use deleteBudget(_:deletedBy:) for tombstone pattern instead")
//    func permanentlyDeleteBudget(_ budget: Budget) async {
//        await withCheckedContinuation { continuation in
//            viewContext.perform {
//                self.viewContext.delete(budget)
//                self.save()
//                continuation.resume(returning: ())
//            }
//        }
//    }
//
//    @available(*, deprecated, message: "Use deleteBudget(_:deletedBy:) for tombstone pattern instead")
//    func permanentlyDeleteBudget(by id: UUID) async {
//        if let budget = await fetchBudget(by: id) {
//            await permanentlyDeleteBudget(budget)
//        }
//    }
//
//    @available(*, deprecated, message: "Use deleteBudget(_:deletedBy:) for tombstone pattern instead")
//    func permanentlyDeleteBudgets(for category: Category) async {
//        let budgets = await fetchBudgets(for: category, includeDeleted: true)
//        await withCheckedContinuation { continuation in
//            viewContext.perform {
//                for budget in budgets {
//                    self.viewContext.delete(budget)
//                }
//                self.save()
//                continuation.resume(returning: ())
//            }
//        }
//    }
}
