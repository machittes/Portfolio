//
//  CategoryRepository.swift
//  StudentExpenseTracker
//

import Foundation
import CoreData

@Observable
class CategoryRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create
    
    func createCategory(name: String, icon: String? = nil, color: String? = nil,
                       isDefault: Bool = false, order: Int16 = 0, user: AppUser) async -> Category {
        
        // withCheckedContinuation is needed here because the viewContext.perform is Callback-Based and doesn't work with async/await
        // The withCheckedContinuation suspends the async function,
        // waits for the Core Data operation to complete on the correct queue and
        // resumes with the result when continuation.resume() is called

        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let category = Category(context: self.viewContext)
                category.id = UUID()
                category.name = name
                category.icon = icon
                category.color = color
                category.isDefault = isDefault
                category.order = order
                category.user = user
                category.createdAt = Date()
                category.updatedAt = Date()
                category.syncStatus = "created"
                
                // Initialize tombstone fields
                category.softDeleted = false
                category.deletedAt = nil
                category.deletedBy = nil
                
                self.save()
                continuation.resume(returning: category)
            }
        }
    }
    
    // MARK: - Read (Enhanced with Soft Delete Support)
    
    /// Fetch only active (non-deleted) categories - this replaces the original fetchCategories
    func fetchCategories(for user: AppUser) async -> [Category] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                // Filter out deleted categories by default
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.order, ascending: true),
                    NSSortDescriptor(keyPath: \Category.name, ascending: true)
                ]
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    Logger.log("Error fetching active categories: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Fetch all categories including deleted ones (for admin/debug purposes)
    func fetchAllCategories(for user: AppUser, includeDeleted: Bool = false) async -> [Category] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.softDeleted, ascending: true), // Active categories first
                    NSSortDescriptor(keyPath: \Category.order, ascending: true),
                    NSSortDescriptor(keyPath: \Category.name, ascending: true)
                ]
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    Logger.log("Error fetching categories (includeDeleted=\(includeDeleted)): \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchDefaultCategories(for user: AppUser) async -> [Category] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                // Only fetch active default categories
                request.predicate = NSPredicate(format: "user == %@ AND isDefault == YES AND softDeleted == NO", user)
                request.sortDescriptors = [NSSortDescriptor(keyPath: \Category.order, ascending: true)]
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    Logger.log("Error fetching default categories: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func fetchCategory(by id: UUID) async -> Category? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                // Fetch regardless of deleted status (for internal operations)
                request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories.first)
                } catch {
                    Logger.log("Error fetching category by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchActiveCategory(by id: UUID) async -> Category? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                // Only fetch active categories for UI operations
                request.predicate = NSPredicate(format: "id == %@ AND softDeleted == NO", id as CVarArg)
                request.fetchLimit = 1
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories.first)
                } catch {
                    Logger.log("Error fetching active category by ID: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchCategory(by name: String, for user: AppUser) async -> Category? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                // Only search among active categories
                request.predicate = NSPredicate(format: "name == %@ AND user == %@ AND softDeleted == NO", name, user)
                request.fetchLimit = 1
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories.first)
                } catch {
                    Logger.log("Error fetching category by name: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    // MARK: - Update (Enhanced)
    
    func updateCategory(_ category: Category, name: String? = nil, icon: String? = nil,
                       color: String? = nil, order: Int16? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Prevent updating deleted categories
                guard !category.softDeleted else {
                    Logger.log("Attempted to update deleted category: \(category.id?.uuidString ?? "unknown")", level: .warning)
                    continuation.resume()
                    return
                }
                
                if let name = name {
                    category.name = name
                }
                if let icon = icon {
                    category.icon = icon
                }
                if let color = color {
                    category.color = color
                }
                if let order = order {
                    category.order = order
                }
                
                category.updatedAt = Date()
                category.syncStatus = "updated"
                
                self.save()
                continuation.resume()
            }
        }
    }
    
    func reorderCategories(_ categories: [Category]) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for (index, category) in categories.enumerated() {
                    // Only reorder active categories
                    guard !category.softDeleted else { continue }
                    
                    category.order = Int16(index)
                    category.updatedAt = Date()
                    category.syncStatus = "updated"
                }
                self.save()
                continuation.resume()
            }
        }
    }
    
    // MARK: - Delete (Enhanced with Soft Delete)
    
    /// Soft delete with tombstone creation
    func deleteCategory(_ category: Category, deletedBy userId: String? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                // Validate category can be deleted (check dependencies)
                let dependencyCount = self.getDependencyCountSync(for: category)
                
                if dependencyCount.total > 0 {
                    Logger.log("Cannot delete category '\(category.name ?? "unknown")' - has \(dependencyCount.total) dependencies", level: .warning)
                    continuation.resume()
                    return
                }
                
                // Create tombstone instead of hard delete
                category.softDeleted = true
                category.deletedAt = Date()
                category.deletedBy = userId
                category.syncStatus = "deleted"
                category.updatedAt = Date()
                
                // DON'T call viewContext.delete(category) - keep the tombstone
                self.save()
                
                Logger.log("Category soft deleted: \(category.name ?? "unknown") by \(userId ?? "system")", level: .info)
                continuation.resume()
            }
        }
    }
    
    func deleteCategory(by id: UUID, deletedBy userId: String? = nil) async {
        if let category = await fetchCategory(by: id) {
            await deleteCategory(category, deletedBy: userId)
        }
    }
    
    /// Force delete with dependency validation
    func deleteCategoryWithValidation(_ category: Category, deletedBy userId: String? = nil) async throws {
        let dependencyInfo = await getCategoryDependencies(category)
        
        guard dependencyInfo.total == 0 else {
            throw SyncError.conflictResolution(
                "Cannot delete category '\(category.name ?? "unknown")'. It has \(dependencyInfo.expenses) expenses, \(dependencyInfo.budgets) budgets, and \(dependencyInfo.recurringExpenses) recurring expenses."
            )
        }
        
        await deleteCategory(category, deletedBy: userId)
    }
    
    // MARK: - Tombstone Management
    
    /// Fetch deleted categories (tombstones)
    func fetchTombstones(for user: AppUser, olderThan date: Date = Date()) async -> [Category] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                request.predicate = NSPredicate(
                    format: "user == %@ AND softDeleted == YES AND deletedAt < %@",
                    user, date as NSDate
                )
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.deletedAt, ascending: false) // Newest deletions first
                ]
                
                do {
                    let tombstones = try self.viewContext.fetch(request)
                    continuation.resume(returning: tombstones)
                } catch {
                    Logger.log("Error fetching category tombstones: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Fetch recently deleted categories (for "Recently Deleted" UI)
    func fetchRecentlyDeleted(for user: AppUser, within days: Int = 30) async -> [Category] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                request.predicate = NSPredicate(
                    format: "user == %@ AND softDeleted == YES AND deletedAt >= %@",
                    user, cutoffDate as NSDate
                )
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.deletedAt, ascending: false)
                ]
                
                do {
                    let recentlyDeleted = try self.viewContext.fetch(request)
                    continuation.resume(returning: recentlyDeleted)
                } catch {
                    Logger.log("Error fetching recently deleted categories: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Clean up old tombstones (physically delete them)
    func cleanupOldTombstones(for user: AppUser, olderThan days: Int = 30) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let tombstones = await fetchTombstones(for: user, olderThan: cutoffDate)
        
        guard !tombstones.isEmpty else {
            Logger.log("No category tombstones to clean up", level: .debug)
            return
        }
        
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for tombstone in tombstones {
                    // Now safe to physically delete old tombstones
                    self.viewContext.delete(tombstone)
                }
                
                self.save()
                continuation.resume()
            }
        }
        
        Logger.log("Cleaned up \(tombstones.count) old category tombstones for user: \(user.userId ?? "unknown")", level: .info)
    }
    
    /// Restore a deleted category
    func restoreCategory(_ category: Category) async throws {
        guard category.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted category")
        }
        
        await withCheckedContinuation { continuation in
            viewContext.perform {
                category.softDeleted = false
                category.deletedAt = nil
                category.deletedBy = nil
                category.updatedAt = Date()
                category.syncStatus = "updated"
                
                self.save()
                continuation.resume()
            }
        }
        
        Logger.log("Category restored: \(category.name ?? "unknown")", level: .info)
    }
    
    /// Permanently delete a category (use with caution)
    func permanentlyDeleteCategory(_ category: Category) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                self.viewContext.delete(category)
                self.save()
                continuation.resume()
            }
        }
        
        Logger.log("Category permanently deleted: \(category.name ?? "unknown")", level: .warning)
    }
    
    // MARK: - Default Categories Setup (Enhanced)
    
    func createDefaultCategories(for user: AppUser) async {
        let defaultCategories = [
            ("Food & Dining", "fork.knife", "red"),
            ("Transportation", "car.fill", "blue"),
            ("Shopping", "bag.fill", "green"),
            ("Entertainment", "tv.fill", "purple"),
            ("Bills & Utilities", "bolt.fill", "orange"),
            ("Education", "book.fill", "indigo"),
            ("Health & Fitness", "heart.fill", "pink"),
            ("Other", "questionmark.circle.fill", "gray")
        ]
        
        for (index, (name, icon, color)) in defaultCategories.enumerated() {
            let category = await createCategory(
                name: name,
                icon: icon,
                color: color,
                isDefault: true,
                order: Int16(index),
                user: user
            )
            await withCheckedContinuation { continuation in
                viewContext.perform {
                    category.syncStatus = "created"
                    continuation.resume()
                }
            }
        }
        
        Logger.log("Created \(defaultCategories.count) default categories for user: \(user.userId ?? "unknown")", level: .info)
    }
    
    // MARK: - Sync Status (Enhanced)
    
    func fetchCategoriesWithSyncStatus(_ status: String, for user: AppUser, includeDeleted: Bool = true) async -> [Category] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                
                var predicateFormat = "syncStatus == %@ AND user == %@"
                var predicateArgs: [Any] = [status, user]
                
                if !includeDeleted {
                    predicateFormat += " AND softDeleted == NO"
                }
                
                request.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    Logger.log("Error fetching categories with sync status '\(status)': \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func markCategoryAsSynced(_ category: Category) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                category.syncStatus = "synced"
                category.updatedAt = Date()
                self.save()
                continuation.resume()
            }
        }
    }
 
    func categoryExists(name: String, for user: AppUser, includeDeleted: Bool = false) async -> Bool {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                
                var predicateFormat = "name == %@ AND user == %@"
                var predicateArgs: [Any] = [name, user]
                
                if !includeDeleted {
                    predicateFormat += " AND softDeleted == NO"
                }
                
                request.predicate = NSPredicate(format: predicateFormat, argumentArray: predicateArgs)
                request.fetchLimit = 1
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count > 0)
                } catch {
                    Logger.log("Error checking if category exists: \(error)", level: .error)
                    continuation.resume(returning: false)
                }
            }
        }
    }
    
//    func fetchPendingSyncCategories(for user: AppUser) async -> [Category] {
//        return await fetchCategoriesWithSyncStatus("created", for: user) +
//               await fetchCategoriesWithSyncStatus("updated", for: user) +
//               await fetchCategoriesWithSyncStatus("deleted", for: user)
//    }

    func fetchPendingSyncCategories(for user: AppUser) async -> [Category] {
        async let createdCategories = fetchCategoriesWithSyncStatus("created", for: user)
        async let updatedCategories = fetchCategoriesWithSyncStatus("updated", for: user)
        async let deletedCategories = fetchCategoriesWithSyncStatus("deleted", for: user)
        
        return await createdCategories + updatedCategories + deletedCategories
    }
    
    // MARK: - Dependency Management
    
    /// Get detailed dependency information for a category
    func getCategoryDependencies(_ category: Category) async -> (expenses: Int, budgets: Int, recurringExpenses: Int, total: Int) {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let dependencyInfo = self.getDependencyCountSync(for: category)
                continuation.resume(returning: dependencyInfo)
            }
        }
    }
    
    /// Internal sync version of dependency check
    private func getDependencyCountSync(for category: Category) -> (expenses: Int, budgets: Int, recurringExpenses: Int, total: Int) {
        let expenseCount = category.expenses?.count ?? 0
        let budgetCount = category.budgets?.count ?? 0
        let recurringExpenseCount = category.recurringExpenses?.count ?? 0
        let total = expenseCount + budgetCount + recurringExpenseCount
        
        return (expenses: expenseCount, budgets: budgetCount, recurringExpenses: recurringExpenseCount, total: total)
    }
    
    /// Check if category can be safely deleted
    func canCategoryBeDeleted(_ category: Category) async -> Bool {
        let dependencies = await getCategoryDependencies(category)
        return dependencies.total == 0
    }
    
    // MARK: - Helper Methods (Enhanced)
    
    private func save() {
        let result = persistenceController.save()
        switch result {
        case .success:
            break // Success - no action needed
        case .failure(let error):
            Logger.log("CategoryRepository save failed: \(error.localizedDescription)", level: .error)
            // Repository-level error handling - could emit to error stream or delegate
        }
    }
    
    func categoryExists(name: String, for user: AppUser) async -> Bool {
        let category = await fetchCategory(by: name, for: user)
        return category != nil
    }
    
    func getCategoryCount(for user: AppUser, includeDeleted: Bool = false) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                
                if includeDeleted {
                    request.predicate = NSPredicate(format: "user == %@", user)
                } else {
                    request.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                }
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting categories: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    func getActiveCategoryCount(for user: AppUser) async -> Int {
        return await getCategoryCount(for: user, includeDeleted: false)
    }
    
    func getDeletedCategoryCount(for user: AppUser) async -> Int {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                request.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                
                do {
                    let count = try self.viewContext.count(for: request)
                    continuation.resume(returning: count)
                } catch {
                    Logger.log("Error counting deleted categories: \(error)", level: .error)
                    continuation.resume(returning: 0)
                }
            }
        }
    }
    
    // MARK: - Advanced Query Methods
    
    /// Find categories that need sync (created, updated, or deleted)
    func fetchCategoriesNeedingSync(for user: AppUser) async -> [Category] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<Category> = Category.fetchRequest()
                request.predicate = NSPredicate(
                    format: "user == %@ AND syncStatus IN %@",
                    user, ["created", "updated", "deleted"]
                )
                request.sortDescriptors = [
                    NSSortDescriptor(keyPath: \Category.updatedAt, ascending: true) // Oldest changes first
                ]
                
                do {
                    let categories = try self.viewContext.fetch(request)
                    continuation.resume(returning: categories)
                } catch {
                    Logger.log("Error fetching categories needing sync: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    /// Bulk update sync status for multiple categories
    func bulkUpdateSyncStatus(_ categories: [Category], to status: String) async {
        guard !categories.isEmpty else { return }
        
        await withCheckedContinuation { continuation in
            viewContext.perform {
                for category in categories {
                    category.syncStatus = status
                    if status == "synced" {
                        category.updatedAt = Date()
                    }
                }
                
                self.save()
                continuation.resume()
            }
        }
        
        Logger.log("Bulk updated \(categories.count) categories to sync status: \(status)", level: .debug)
    }
    
    // MARK: - Statistics and Analytics
    
    func getCategoryStatistics(for user: AppUser) async -> (active: Int, deleted: Int, needingSync: Int, defaultCategories: Int) {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                // Active categories
                let activeRequest: NSFetchRequest<Category> = Category.fetchRequest()
                activeRequest.predicate = NSPredicate(format: "user == %@ AND softDeleted == NO", user)
                let activeCount = (try? self.viewContext.count(for: activeRequest)) ?? 0
                
                // Deleted categories
                let deletedRequest: NSFetchRequest<Category> = Category.fetchRequest()
                deletedRequest.predicate = NSPredicate(format: "user == %@ AND softDeleted == YES", user)
                let deletedCount = (try? self.viewContext.count(for: deletedRequest)) ?? 0
                
                // Categories needing sync
                let syncRequest: NSFetchRequest<Category> = Category.fetchRequest()
                syncRequest.predicate = NSPredicate(
                    format: "user == %@ AND syncStatus IN %@",
                    user, ["created", "updated", "deleted"]
                )
                let syncCount = (try? self.viewContext.count(for: syncRequest)) ?? 0
                
                // Default categories
                let defaultRequest: NSFetchRequest<Category> = Category.fetchRequest()
                defaultRequest.predicate = NSPredicate(format: "user == %@ AND isDefault == YES AND softDeleted == NO", user)
                let defaultCount = (try? self.viewContext.count(for: defaultRequest)) ?? 0
                
                continuation.resume(returning: (active: activeCount, deleted: deletedCount, needingSync: syncCount, defaultCategories: defaultCount))
            }
        }
    }
}

// MARK: - CategoryRepository Extensions for Debugging

extension CategoryRepository {
    
    /// Debug method to list all categories with their sync status
    func debugListAllCategories(for user: AppUser) async -> [(name: String, deleted: Bool, syncStatus: String, id: String)] {
        let allCategories = await fetchAllCategories(for: user, includeDeleted: true)
        
        return allCategories.map { category in
            (
                name: category.name ?? "NO_NAME",
                deleted: category.softDeleted,
                syncStatus: category.syncStatus ?? "NO_STATUS",
                id: category.id?.uuidString ?? "NO_ID"
            )
        }
    }
    
    /// Debug method to validate category data integrity
    func debugValidateCategoryIntegrity(for user: AppUser) async -> [String] {
        var issues: [String] = []
        let allCategories = await fetchAllCategories(for: user, includeDeleted: true)
        
        for category in allCategories {
            // Check for missing required fields
            if category.id == nil {
                issues.append("Category missing ID: \(category.name ?? "unknown")")
            }
            
            if category.name == nil || category.name?.isEmpty == true {
                if !category.softDeleted {
                    issues.append("Active category missing name: \(category.id?.uuidString ?? "unknown")")
                }
            }
            
            if category.user == nil {
                issues.append("Category missing user relationship: \(category.name ?? category.id?.uuidString ?? "unknown")")
            }
            
            // Check tombstone consistency
            if category.softDeleted && category.deletedAt == nil {
                issues.append("Deleted category missing deletedAt: \(category.name ?? category.id?.uuidString ?? "unknown")")
            }
            
            if !category.softDeleted && category.deletedAt != nil {
                issues.append("Active category has deletedAt: \(category.name ?? category.id?.uuidString ?? "unknown")")
            }
        }
        
        return issues
    }
}
