//
//  IncomeRepository.swift
//  StudentExpenseTracker
//

import Foundation
import CoreData

@Observable
class IncomeRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create
    
    func createIncome(
        amount: Decimal,
        source: String? = nil,
        date: Date = Date(),
        notes: String? = nil,
        isRecurring: Bool = false,
        frequency: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        order: Int16 = 0,
        user: AppUser
    ) async -> Income? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let income = Income(context: self.viewContext)
                income.id = UUID()
                income.amount = NSDecimalNumber(decimal: amount)
                income.source = source
                income.date = date
                income.notes = notes
                income.isRecurring = isRecurring
                income.frequency = frequency
                income.icon = icon
                income.color = color
                income.user = user
                income.order = order
                income.createdAt = Date()
                income.updatedAt = Date()
                income.syncStatus = "created"
                income.softDeleted = false
                
                self.save()
                continuation.resume(returning: income)
            }
        }
    }
    
    // MARK: - Read
    
    func fetchIncomes(for user: AppUser) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
//                request.predicate = NSPredicate(format: "user == %@", user)
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Income.order, ascending: true),
                    NSSortDescriptor(keyPath: \Income.date, ascending: false)
                ]
                
                do {
                    let incomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: incomes)
                } catch {
                    Logger.log("Error fetching incomes: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchIncomes(for user: AppUser, from startDate: Date, to endDate: Date) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND date >= %@ AND date <= %@",
                                              user, startDate as NSDate, endDate as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.date, ascending: false)]
                
                do {
                    let incomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: incomes)
                } catch {
                    Logger.log("Error fetching incomes for date range: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchRecurringIncomes(for user: AppUser) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND isRecurring == YES", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.date, ascending: false)]
                
                do {
                    let incomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: incomes)
                } catch {
                    Logger.log("Error fetching recurring incomes: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchIncome(by id: UUID) async -> Income? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let incomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: incomes.first)
                } catch {
                    Logger.log("Error fetching income by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchIncomes(by source: String, for user: AppUser) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "source == %@ AND user == %@", source, user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.date, ascending: false)]
                
                do {
                    let incomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: incomes)
                } catch {
                    Logger.log("Error fetching incomes by source: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Update
    
    func updateIncome(
        _ income: Income,
        amount: Decimal? = nil,
        source: String? = nil,
        date: Date? = nil,
        notes: String? = nil,
        isRecurring: Bool? = nil,
        frequency: String? = nil,
        icon: String? = nil,
        color: String? = nil,
        order: Int16? = nil
    ) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                if let amount = amount {
                    income.amount = NSDecimalNumber(decimal: amount)
                }
                if let source = source {
                    income.source = source
                }
                if let date = date {
                    income.date = date
                }
                if let notes = notes {
                    income.notes = notes
                }
                if let isRecurring = isRecurring {
                    income.isRecurring = isRecurring
                }
                if let frequency = frequency {
                    income.frequency = frequency
                }
                if let icon = icon {
                    income.icon = icon
                }
                if let color = color {
                    income.color = color
                }
                if let order = order {
                    income.order = order
                }
                
                income.updatedAt = Date()
                income.syncStatus = "updated"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    
    
    func deleteIncome(_ income: Income, deletedBy userId: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Create tombstone instead of hard delete
                income.softDeleted = true
                income.deletedAt = Date()
                income.deletedBy = userId
                income.updatedAt = Date()
                income.syncStatus = "deleted"
                
                // Handle recurring income specific logic
                income.handleRecurringIncomeTombstone()
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    /**
     * Restore income from soft delete
     */
    func restoreIncome(_ income: Income) async throws {
        try await withCheckedThrowingContinuation { continuation in
            viewContext.perform {
                do {
                    try income.restoreFromTombstone()
                    self.save()
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /**
     * Fetch deleted income records (tombstones) for user
     */
    func fetchDeletedIncome(for user: AppUser) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.deletedAt, ascending: false)]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching deleted income: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch recently deleted income within specified days
     */
    func fetchRecentlyDeleted(for user: AppUser, within days: Int = 30) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt >= %@",
                                              user, cutoffDate as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.deletedAt, ascending: false)]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching recently deleted income: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch tombstones (deleted income) older than specified date for cleanup
     */
    func fetchTombstones(for user: AppUser, olderThan date: Date = Date()) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt < %@",
                                              user, date as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.deletedAt, ascending: true)]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching income tombstones: \(error)", level: .error)
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
     * Fetch active income records (excludes soft-deleted)
     */
    func fetchIncomes(for user: AppUser, includeDeleted: Bool = false) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Income.order, ascending: true),
                    NSSortDescriptor(keyPath: \Income.date, ascending: false)
                ]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching income: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch all income including deleted ones
     */
    func fetchAllIncome(for user: AppUser, includeDeleted: Bool = false) async -> [Income] {
        return await fetchIncomes(for: user, includeDeleted: includeDeleted)
    }

    /**
     * Fetch income records for date range (excludes soft-deleted by default)
     */
    func fetchIncomes(for user: AppUser, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND date >= %@ AND date <= %@",
                                                  user, startDate as NSDate, endDate as NSDate)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND date >= %@ AND date <= %@",
                                                  user, startDate as NSDate, endDate as NSDate)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.date, ascending: false)]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching income for date range: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch recurring income (excludes soft-deleted by default)
     */
    func fetchRecurringIncomes(for user: AppUser, includeDeleted: Bool = false) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND isRecurring == YES", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND isRecurring == YES", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.date, ascending: false)]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching recurring income: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch income by source (excludes soft-deleted by default)
     */
    func fetchIncomes(by source: String, for user: AppUser, includeDeleted: Bool = false) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "source == %@ AND user == %@", source, user)
                } else {
                    request.predicate = NSPredicate(format: "source == %@ AND user == %@ AND softDeleted == NO", source, user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Income.date, ascending: false)]
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching income by source: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    // MARK: - Sync Status Methods

    /**
     * Fetch income with specific sync status
     */
    func fetchIncomesWithSyncStatus(_ status: String, for user: AppUser, includeDeleted: Bool = false) async -> [Income] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                
                if includeDeleted {
                request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@", status, user)
                } else {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@ AND softDeleted == NO", status, user)
                }
                
                do {
                    let income = try self.viewContext.fetch(request)
                    continuation.resume(returning: income)
                } catch {
                    Logger.log("Error fetching income with sync status: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch pending sync income (created, updated, deleted)
     */
    func fetchPendingSyncIncome(for user: AppUser) async -> [Income] {
        async let createdIncome = fetchIncomesWithSyncStatus("created", for: user)
        async let updatedIncome = fetchIncomesWithSyncStatus("updated", for: user)
        async let deletedIncome = fetchIncomesWithSyncStatus("deleted", for: user)
        
        return await createdIncome + updatedIncome + deletedIncome
    }

    /**
     * Mark income as synced
     */
    func markIncomeAsSynced(_ income: Income) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                income.syncStatus = "synced"
                income.updatedAt = Date()
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Enhanced Statistics Methods

    /**
     * Get income count (excludes soft-deleted by default)
     */
    func getIncomeCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Income> = Income.fetchRequest()
                
                if includeDeleted {
                request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting income: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }

    /**
     * Get unique income sources (excludes soft-deleted by default)
     */
    func getUniqueIncomeSources(for user: AppUser, includeDeleted: Bool = false) async -> [String] {
        let incomes = await fetchIncomes(for: user, includeDeleted: includeDeleted)
        let sources = incomes.compactMap { $0.source }
        return Array(Set(sources)).sorted()
    }

    /**
     * Get total income amount for period (excludes soft-deleted by default)
     */
    func getTotalIncome(for user: AppUser, from startDate: Date, to endDate: Date, includeDeleted: Bool = false) async -> Decimal {
        let incomes = await fetchIncomes(for: user, from: startDate, to: endDate, includeDeleted: includeDeleted)
        return incomes.reduce(Decimal.zero) { total, income in
            total + (income.amount?.decimalValue ?? Decimal.zero)
        }
    }
    
    
    
    
    // MARK: - Delete

    func deleteIncome(_ income: Income) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                self.viewContext.delete(income)
                self.save()
                continuation.resume(returning: ())
            }
        }
    }

    func deleteIncome(by id: UUID) async {
        if let income = await fetchIncome(by: id) {
            await deleteIncome(income)
        }
    }

    // MARK: - Helper Methods

    private func save() {
        let result = persistenceController.save()
        switch result {
        case .success:
            break
        case .failure(let error):
            Logger.log("IncomeRepository save failed: \(error.localizedDescription)", level: .error)
        }
    }

    func reorderIncomes(_ incomes: [Income]) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for (index, income) in incomes.enumerated() {
                    income.order = Int16(index)
                    income.updatedAt = Date()
                    income.syncStatus = "updated"
                }
                self.save()
                continuation.resume()
            }
        }
    }

//    func getIncomeCount(for user: AppUser) async -> Int {
//        return await withCheckedContinuation { continuation in
//            viewContext.perform {
//                let request: NSFetchRequest<Income> = Income.fetchRequest()
//                request.predicate = NSPredicate(format: "user == %@", user)
//
//                do {
//                    let count = try self.viewContext.count(for: request)
//                    continuation.resume(returning: count)
//                } catch {
//                    Logger.log("Error counting incomes: \(error)", level: .error)
//                    continuation.resume(returning: 0)
//                }
//            }
//        }
//    }
    
    func getUniqueIncomeSources(for user: AppUser) async -> [String] {
        let incomes = await fetchIncomes(for: user)
        let sources = incomes.compactMap { $0.source }
        return Array(Set(sources)).sorted()
    }
}
