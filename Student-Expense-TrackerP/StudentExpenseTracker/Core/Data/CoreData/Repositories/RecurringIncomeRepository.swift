//
//  RecurringIncomeRepository.swift
//  StudentExpenseTracker


import Foundation
import CoreData

@Observable
class RecurringIncomeRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create
    
    func createRecurringIncome(source: String, amount: Decimal, frequency: String,
                              startDate: Date = Date(), endDate: Date? = nil,
                              dayOfMonthWeek: Int16? = nil, notes: String? = nil,
                              isActive: Bool = true,
                              color: String? = nil, icon: String? = nil,
                              user: AppUser) async -> RecurringIncome? {
        
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let recurringIncome = RecurringIncome(context: self.viewContext)
                recurringIncome.id = UUID()
                recurringIncome.source = source
                recurringIncome.amount = NSDecimalNumber(decimal: amount)
                recurringIncome.frequency = frequency
                recurringIncome.startDate = startDate
                recurringIncome.endDate = endDate
                recurringIncome.dayOfMonthWeek = dayOfMonthWeek ?? 0
                recurringIncome.notes = notes
                recurringIncome.isActive = isActive
                // Removed: recurringIncome.category = category
                recurringIncome.color = color
                recurringIncome.icon = icon
                recurringIncome.user = user
                recurringIncome.createdAt = Date()
                recurringIncome.updatedAt = Date()
                recurringIncome.syncStatus = "created"
                
                // Initialize tombstone fields
                recurringIncome.softDeleted = false
                recurringIncome.deletedAt = nil
                recurringIncome.deletedBy = nil
                
                self.save()
                continuation.resume(returning: recurringIncome)
            }
        }
    }
    
    // MARK: - Read (Tombstone-Aware)
    
    /**
     * Fetch recurring incomes for user (excludes soft-deleted by default)
     */
    func fetchRecurringIncomes(for user: AppUser, includeDeleted: Bool = false) async -> [RecurringIncome] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \RecurringIncome.isActive, ascending: false),
                    NSSortDescriptor(keyPath: \RecurringIncome.startDate, ascending: false)
                ]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching recurring incomes: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch active recurring incomes (excludes soft-deleted by default)
     */
    func fetchActiveRecurringIncomes(for user: AppUser, includeDeleted: Bool = false) async -> [RecurringIncome] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND isActive == YES", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO AND isActive == YES", user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringIncome.startDate, ascending: false)]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching active recurring incomes: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchRecurringIncome(by id: UUID) async -> RecurringIncome? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes.first)
                } catch {
                    Logger.log("Error fetching recurring income by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchRecurringIncomes(by frequency: String, for user: AppUser, includeDeleted: Bool = false) async -> [RecurringIncome] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@ AND frequency == %@", user, frequency)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND frequency == %@ AND softDeleted == NO", user, frequency)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringIncome.startDate, ascending: false)]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching recurring incomes by frequency: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchDueRecurringIncomes(for user: AppUser, on date: Date = Date()) async -> [RecurringIncome] {
        let activeIncomes = await fetchActiveRecurringIncomes(for: user)
        return activeIncomes.filter { recurringIncome in
            isDue(recurringIncome: recurringIncome, on: date)
        }
    }
    
    // MARK: - Tombstone-Specific Read Methods
    
    /**
     * Fetch deleted recurring incomes (tombstones) for user
     */
    func fetchDeletedRecurringIncomes(for user: AppUser) async -> [RecurringIncome] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringIncome.deletedAt, ascending: false)]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching deleted recurring incomes: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch recently deleted recurring incomes within specified days
     */
    func fetchRecentlyDeletedRecurringIncomes(for user: AppUser, withinDays days: Int = 30) async -> [RecurringIncome] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt >= %@",
                                              user, cutoffDate as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringIncome.deletedAt, ascending: false)]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching recently deleted recurring incomes: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /**
     * Fetch tombstones older than specified date for cleanup
     */
    func fetchTombstones(for user: AppUser, olderThan date: Date = Date()) async -> [RecurringIncome] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES AND deletedAt < %@",
                                              user, date as NSDate)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringIncome.deletedAt, ascending: true)]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching recurring income tombstones: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Update
    
    func updateRecurringIncome(_ recurringIncome: RecurringIncome, source: String? = nil,
                              amount: Decimal? = nil, frequency: String? = nil,
                              startDate: Date? = nil, endDate: Date? = nil,
                              dayOfMonthWeek: Int16? = nil, notes: String? = nil,
                              isActive: Bool? = nil,
                              color: String? = nil, icon: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                if let source = source {
                    recurringIncome.source = source
                }
                if let amount = amount {
                    recurringIncome.amount = NSDecimalNumber(decimal: amount)
                }
                if let frequency = frequency {
                    recurringIncome.frequency = frequency
                }
                if let startDate = startDate {
                    recurringIncome.startDate = startDate
                }
                if let endDate = endDate {
                    recurringIncome.endDate = endDate
                }
                if let dayOfMonthWeek = dayOfMonthWeek {
                    recurringIncome.dayOfMonthWeek = dayOfMonthWeek
                }
                if let notes = notes {
                    recurringIncome.notes = notes
                }
                if let isActive = isActive {
                    recurringIncome.isActive = isActive
                }
                // Removed: category parameter and assignment
                if let color = color {
                    recurringIncome.color = color
                }
                if let icon = icon {
                    recurringIncome.icon = icon
                }
                
                recurringIncome.updatedAt = Date()
                recurringIncome.syncStatus = "updated"
                
                self.save()
                continuation.resume()
            }
        }
    }
    
    // MARK: - Delete (Tombstone-Aware)
    
    /**
     * Soft delete recurring income (create tombstone)
     */
    func deleteRecurringIncome(_ recurringIncome: RecurringIncome, deletedBy: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                recurringIncome.softDeleted = true
                recurringIncome.deletedAt = Date()
                recurringIncome.deletedBy = deletedBy
                recurringIncome.updatedAt = Date()
                recurringIncome.syncStatus = "deleted"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    /**
     * Hard delete recurring income (permanent removal)
     */
    func deleteRecurringIncome(_ recurringIncome: RecurringIncome) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                self.viewContext.delete(recurringIncome)
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    /**
     * Restore soft-deleted recurring income
     */
    func restoreRecurringIncome(_ recurringIncome: RecurringIncome) async throws {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                recurringIncome.softDeleted = false
                recurringIncome.deletedAt = nil
                recurringIncome.deletedBy = nil
                recurringIncome.updatedAt = Date()
                recurringIncome.syncStatus = "updated"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    func deleteRecurringIncome(by id: UUID) async {
        if let recurringIncome = await fetchRecurringIncome(by: id) {
            await deleteRecurringIncome(recurringIncome)
        }
    }
    
    // MARK: - Utility Methods
    
    private func isDue(recurringIncome: RecurringIncome, on date: Date) -> Bool {
        guard let startDate = recurringIncome.startDate,
              !recurringIncome.softDeleted else { return false }
        
        // Check if expired
        if let endDate = recurringIncome.endDate, date > endDate {
            return false
        }
        
        // Check if started
        if date < startDate {
            return false
        }
        
        let calendar = Calendar.current
        
        switch recurringIncome.frequency?.lowercased() {
        case "daily":
            return true
            
        case "weekly":
            if recurringIncome.dayOfMonthWeek > 0 {
                let weekday = calendar.component(.weekday, from: date)
                return weekday == recurringIncome.dayOfMonthWeek
            } else {
                let daysSinceStart = calendar.dateComponents([.day], from: startDate, to: date).day ?? 0
                return daysSinceStart % 7 == 0
            }
            
        case "monthly":
            if recurringIncome.dayOfMonthWeek > 0 {
                let day = calendar.component(.day, from: date)
                return day == recurringIncome.dayOfMonthWeek
            } else {
                let startDay = calendar.component(.day, from: startDate)
                let currentDay = calendar.component(.day, from: date)
                return currentDay == startDay
            }
            
        case "yearly":
            let startComponents = calendar.dateComponents([.month, .day], from: startDate)
            let currentComponents = calendar.dateComponents([.month, .day], from: date)
            return startComponents.month == currentComponents.month && startComponents.day == currentComponents.day
            
        default:
            return false
        }
    }
    
    func getNextDueDate(for recurringIncome: RecurringIncome, after date: Date = Date()) -> Date? {
        guard let startDate = recurringIncome.startDate,
              !recurringIncome.softDeleted else { return nil }
        
        // Check if expired
        if let endDate = recurringIncome.endDate, date > endDate {
            return nil
        }
        
        let calendar = Calendar.current
        var nextDate = date
        
        switch recurringIncome.frequency?.lowercased() {
        case "daily":
            nextDate = calendar.date(byAdding: .day, value: 1, to: date) ?? date
            
        case "weekly":
            if recurringIncome.dayOfMonthWeek > 0 {
                nextDate = calendar.nextDate(after: date, matching: DateComponents(weekday: Int(recurringIncome.dayOfMonthWeek)), matchingPolicy: .nextTime) ?? date
            } else {
                nextDate = calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? date
            }

        case "monthly":
            if recurringIncome.dayOfMonthWeek > 0 {
                nextDate = calendar.nextDate(after: date, matching: DateComponents(day: Int(recurringIncome.dayOfMonthWeek)), matchingPolicy: .nextTime) ?? date
            } else {
                nextDate = calendar.date(byAdding: .month, value: 1, to: startDate) ?? date
            }
            
        case "yearly":
            nextDate = calendar.date(byAdding: .year, value: 1, to: startDate) ?? date
            
        default:
            return nil
        }
        
        // Ensure next date doesn't exceed end date
        if let endDate = recurringIncome.endDate, nextDate > endDate {
            return nil
        }
        
        return nextDate
    }

    func generateIncome(from recurringIncome: RecurringIncome, on date: Date, incomeRepository: IncomeRepository) async -> Income? {
        guard let user = recurringIncome.user,
              let amount = recurringIncome.amount?.decimalValue,
              !recurringIncome.softDeleted else { return nil }
        
        let income = await incomeRepository.createIncome(
            amount: amount,
            source: recurringIncome.source,
            date: date,
            notes: recurringIncome.notes,
            isRecurring: true,
            frequency: recurringIncome.frequency,
            icon: recurringIncome.icon,
            color: recurringIncome.color,
            user: user
        )
        
        // Set the recurring income relationship after creation
        if let income = income {
            await withCheckedContinuation { continuation in
                viewContext.perform {
                    income.recurringIncome = recurringIncome
                    income.updatedAt = Date()
                    self.save()
                    continuation.resume(returning: ())
                }
            }
        }
        
        return income
    }
    
    // MARK: - Analytics (Tombstone-Aware)
    
    func getTotalMonthlyRecurringAmount(for user: AppUser) async -> Decimal {
        let activeRecurring = await fetchActiveRecurringIncomes(for: user)
        var totalMonthly: Decimal = 0
        
        for recurringIncome in activeRecurring {
            guard let amount = recurringIncome.amount?.decimalValue else { continue }
            
            switch recurringIncome.frequency?.lowercased() {
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
    
    // MARK: - Sync Support Methods
    
    /**
     * Fetch recurring incomes with specific sync status for user
     */
    func fetchRecurringIncomesWithSyncStatus(_ status: String, for user: AppUser, includeDeleted: Bool = false) async -> [RecurringIncome] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@", status, user)
                } else {
                    request.predicate = NSPredicate(format: "syncStatus == %@ AND user == %@ AND softDeleted == NO", status, user)
                }
                
                request.sortDescriptors = [NSSortDescriptor(keyPath: \RecurringIncome.updatedAt, ascending: true)]
                
                do {
                    let recurringIncomes = try self.viewContext.fetch(request)
                    continuation.resume(returning: recurringIncomes)
                } catch {
                    Logger.log("Error fetching recurring incomes with sync status: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }

    /**
     * Fetch all pending sync recurring incomes (created, updated, deleted)
     */
    func fetchPendingSyncRecurringIncomes(for user: AppUser) async -> [RecurringIncome] {
        async let createdRecurringIncomes = fetchRecurringIncomesWithSyncStatus("created", for: user)
        async let updatedRecurringIncomes = fetchRecurringIncomesWithSyncStatus("updated", for: user)
        async let deletedRecurringIncomes = fetchRecurringIncomesWithSyncStatus("deleted", for: user)
        
        return await createdRecurringIncomes + updatedRecurringIncomes + deletedRecurringIncomes
    }
    
    func markRecurringIncomeAsSynced(_ recurringIncome: RecurringIncome) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                recurringIncome.syncStatus = "synced"
                recurringIncome.updatedAt = Date()
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
            Logger.log("RecurringIncomeRepository save failed: \(error.localizedDescription)", level: .error)
            // Repository-level error handling - could emit to error stream or delegate
        }
    }
    
    func getRecurringIncomeCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting recurring incomes: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func recurringIncomeExists(source: String, for user: AppUser, includeDeleted: Bool = false) async -> Bool {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<RecurringIncome> = RecurringIncome.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "source ==[c] %@ AND user == %@", source, user)
                } else {
                    request.predicate = NSPredicate(format: "source ==[c] %@ AND user == %@ AND softDeleted == NO", source, user)
                }
                
                request.fetchLimit = 1
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    Logger.log("Error checking recurring income existence: \(error)", level: .error)
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
    /**
     * Get count of dependencies for recurring income (generated incomes)
     */
    func getRecurringIncomeDependencyInfo(_ recurringIncome: RecurringIncome) async -> RecurringIncomeDependencyInfo {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                // Count generated incomes that are not soft-deleted
                let incomeRequest: NSFetchRequest<Income> = Income.fetchRequest()
                incomeRequest.predicate = NSPredicate(format: "recurringIncome == %@ AND softDeleted == NO", recurringIncome)
                
                let generatedIncomeCount = (try? self.viewContext.count(for: incomeRequest)) ?? 0
                
                let dependencyInfo = RecurringIncomeDependencyInfo(
                    generatedIncomeCount: generatedIncomeCount
                )
                
                continuation.resume(returning: dependencyInfo)
            }
        }
    }
    
    /**
     * Check if recurring income can be safely deleted (tombstone-aware)
     */
    func canSafelyDelete(_ recurringIncome: RecurringIncome) async -> (canDelete: Bool, reason: String?) {
        let dependencyInfo = await getRecurringIncomeDependencyInfo(recurringIncome)
        
        // For recurring incomes, we allow deletion even with generated incomes
        // because they represent historical data that should be preserved
        if dependencyInfo.hasAnyDependencies {
            let warningMessage = "This recurring income has \(dependencyInfo.generatedIncomeCount) generated incomes. They will be marked as orphaned but preserved."
            return (true, warningMessage)
        }
        
        return (true, nil)
    }
}

// MARK: - Dependency Info Structure

struct RecurringIncomeDependencyInfo {
    let generatedIncomeCount: Int
    
    var hasAnyDependencies: Bool {
        return generatedIncomeCount > 0
    }
    
    var totalDependencies: Int {
        return generatedIncomeCount
    }
} 
