// StudentExpenseTracker/Core/Data/Sync/Extensions/Category+Syncable.swift
import Foundation
import CoreData

extension Category: UserOwnedEntity {
    
    static var collectionName: String {
        return "categories"
    }
    
    func toFirestoreData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Category missing required fields: id or user")
        }
        
        var data: [String: Any] = [
            "id": id,
            "deleted": self.softDeleted, // Use existing CoreData field name
            //"isDeleted": self.softDeleted, // Also include for compatibility
            "updatedAt": self.updatedAt ?? Date(),
            "userId": userId
        ]
        
        if softDeleted {
            // Tombstone data - minimal fields for deleted entities
            data["deletedAt"] = self.deletedAt ?? Date()
            
            if let deletedBy = self.deletedBy {
                data["deletedBy"] = deletedBy
            }
            
            // Optionally include name for audit trail and debugging
            if let name = self.name {
                data["deletedName"] = name
            }
            
            // Include creation timestamp for complete audit trail
            if let createdAt = self.createdAt {
                data["createdAt"] = createdAt
            }
        } else {
            // Full entity data for active categories
            guard let name = self.name else {
                throw SyncError.dataCorruption("Active category missing name")
            }
            
            data["name"] = name
            data["isDefault"] = self.isDefault
            data["order"] = self.order
            data["createdAt"] = self.createdAt ?? Date()
            
            // Optional fields
            if let icon = self.icon {
                data["icon"] = icon
            }
            
            if let color = self.color {
                data["color"] = color
            }
        }
        
        return data
    }
    
    func updateFromFirestoreData(_ data: [String: Any]) throws {
        // Check if this is tombstone data (check both field names for compatibility)
        let isDeleted = (data["deleted"] as? Bool) ?? (data["isDeleted"] as? Bool) ?? false
        
        if isDeleted {
            // Apply tombstone data
            try applyTombstone(data)
            return
        }
        
        // Regular update for active entity
        guard let name = data["name"] as? String else {
            throw SyncError.dataCorruption("Category data missing required 'name' field")
        }
        
        self.name = name
        self.icon = data["icon"] as? String
        self.color = data["color"] as? String
        self.isDefault = data["isDefault"] as? Bool ?? false
        self.order = Int16(data["order"] as? Int ?? 0)
        
        // Update timestamps from server - handle multiple formats
        if let createdAtValue = data["createdAt"] {
            if let createdAtString = createdAtValue as? String,
               let createdAt = ISO8601DateFormatter().date(from: createdAtString) {
                self.createdAt = createdAt
            } else if let createdAtDate = createdAtValue as? Date {
                self.createdAt = createdAtDate
            }
        }
        
        if let updatedAtValue = data["updatedAt"] {
            if let updatedAtString = updatedAtValue as? String,
               let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) {
                self.updatedAt = updatedAt
            } else if let updatedAtDate = updatedAtValue as? Date {
                self.updatedAt = updatedAtDate
            }
        }
        
        // Mark as not deleted (in case it was a tombstone before and is being restored)
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
    }
    
    static func createFromFirestoreData(_ data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = data["userId"] as? String else {
            throw SyncError.dataCorruption("Invalid category data structure")
        }
        
        // Find the user entity
        let userRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        guard let user = try context.fetch(userRequest).first else {
            throw SyncError.dataCorruption("User not found for category: \(userId)")
        }
        
        let category = Category(context: context)
        category.id = id
        category.user = user
        
        // Initialize with defaults before applying data
        category.softDeleted = false
        category.deletedAt = nil
        category.deletedBy = nil
        
        // Use the updateFromFirestoreData method for consistency
        try category.updateFromFirestoreData(data)
        
        // Set sync status to synced since this is coming from Firestore
        category.currentSyncStatus = .synced
        
        return category
    }
    
    // MARK: - Enhanced Tombstone Support
    
    /**
     * Category-specific tombstone data creation
     * Overrides default implementation to include category-specific fields
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Category missing required fields for tombstone: id or user")
        }
        
        var tombstoneData: [String: Any] = [
            "id": id,
            "deleted": true,
            //"isDeleted": true, // Include both for compatibility
            "deletedAt": self.deletedAt ?? Date(),
            "updatedAt": self.updatedAt ?? Date(),
            "userId": userId
        ]
        
        // Include deletedBy if available
        if let deletedBy = self.deletedBy {
            tombstoneData["deletedBy"] = deletedBy
        }
        
        // Include category name for audit trail (optional but helpful for debugging)
        if let name = self.name {
            tombstoneData["deletedName"] = name
        }
        
        // Include original creation timestamp for complete audit trail
        if let createdAt = self.createdAt {
            tombstoneData["createdAt"] = createdAt
        }
        
        // Include category-specific metadata that might be useful for recovery
        tombstoneData["isDefault"] = self.isDefault
        tombstoneData["order"] = self.order
        
        if let icon = self.icon {
            tombstoneData["deletedIcon"] = icon
        }
        
        if let color = self.color {
            tombstoneData["deletedColor"] = color
        }
        
        return tombstoneData
    }
    
    /**
     * Category-specific tombstone application
     * Handles category-specific fields when applying remote tombstone
     */
    func applyTombstone(_ data: [String: Any]) throws {
        // Extract deletion timestamp with format support
        guard let deletedAtValue = data["deletedAt"] else {
            throw SyncError.dataCorruption("Category tombstone missing deletedAt")
        }
        
        let deletedAtDate: Date
        if let deletedAtString = deletedAtValue as? String {
            deletedAtDate = ISO8601DateFormatter().date(from: deletedAtString) ?? Date()
        } else if let deletedAtDirectDate = deletedAtValue as? Date {
            deletedAtDate = deletedAtDirectDate
        } else {
            throw SyncError.dataCorruption("Invalid deletedAt format in category tombstone")
        }
        
        // Apply tombstone state
        self.softDeleted = true
        self.deletedAt = deletedAtDate
        self.deletedBy = data["deletedBy"] as? String
        
        // Update the overall timestamp
        if let updatedAtValue = data["updatedAt"] {
            if let updatedAtString = updatedAtValue as? String,
               let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) {
                self.updatedAt = updatedAt
            } else if let updatedAtDate = updatedAtValue as? Date {
                self.updatedAt = updatedAtDate
            } else {
                self.updatedAt = deletedAtDate
            }
        } else {
            self.updatedAt = deletedAtDate
        }
        
        // Mark as synced since this tombstone came from remote
        self.currentSyncStatus = .synced
        
        // Optionally preserve some metadata for potential recovery
        // (This is optional - you might want to clear all data for privacy)
        if let deletedName = data["deletedName"] as? String {
            // Store in a way that indicates this is historical data
            // Could be used for "Recently Deleted" UI or recovery features
            // For now, we'll clear the name to hide deleted categories from UI
            self.name = nil // Clear name so deleted categories don't appear in lists
        }
    }
    
    /**
     * Category-specific restoration from tombstone
     * Restores a deleted category with proper validation
     */
    func restoreFromTombstone() throws {
        guard self.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted category")
        }
        
        // Restore deleted state
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
        self.updatedAt = Date()
        self.currentSyncStatus = .updated
        
        // Validate that we have minimum required data for a category
        if self.name == nil || self.name?.isEmpty == true {
            throw SyncError.dataCorruption("Cannot restore category without name")
        }
        
        // Ensure we have a valid user relationship
        guard self.user != nil else {
            throw SyncError.dataCorruption("Cannot restore category without user relationship")
        }
    }
    
    // MARK: - Category-Specific Validation
    
    /**
     * Validates category-specific data for sync operations
     */
    func validateCategoryForSync() throws {
        // Call base validation
        try validateForSync()
        
        // Category-specific validations
        if !softDeleted {
            // Active categories must have a name
            guard let name = self.name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncError.dataCorruption("Active category missing valid name")
            }
            
            // Validate order is reasonable
            if self.order < 0 {
                throw SyncError.dataCorruption("Category order cannot be negative")
            }
        }
        
        // Validate user relationship exists
        guard self.user != nil else {
            throw SyncError.dataCorruption("Category missing user relationship")
        }
        
        // Validate tombstone consistency
        if softDeleted {
            guard deletedAt != nil else {
                throw SyncError.dataCorruption("Deleted category missing deletedAt timestamp")
            }
        }
    }
    
    // MARK: - Category-Specific Helper Methods
    
    /**
     * Checks if category can be safely deleted (no dependencies)
     */
    var canBeDeleted: Bool {
        // Check if category has any expenses
        if let expenses = self.expenses, expenses.count > 0 {
            return false
        }
        
        // Check if category has any budgets
        if let budgets = self.budgets, budgets.count > 0 {
            return false
        }
        
        // Check if category has any recurring expenses
        if let recurringExpenses = self.recurringExpenses, recurringExpenses.count > 0 {
            return false
        }
        
        return true
    }
    
    /**
     * Gets dependency count for UI display
     */
    var dependencyCount: (expenses: Int, budgets: Int, recurringExpenses: Int) {
        let expenseCount = self.expenses?.count ?? 0
        let budgetCount = self.budgets?.count ?? 0
        let recurringExpenseCount = self.recurringExpenses?.count ?? 0
        
        return (expenses: expenseCount, budgets: budgetCount, recurringExpenses: recurringExpenseCount)
    }
    
    /**
     * Category-specific debug description
     */
    var categoryDebugDescription: String {
        let baseDescription = syncDebugDescription
        let name = self.name ?? "NO_NAME"
        let dependencies = dependencyCount
        let depString = "E:\(dependencies.expenses) B:\(dependencies.budgets) R:\(dependencies.recurringExpenses)"
        
        return "\(baseDescription) | \(name) | \(depString)"
    }
}

// MARK: - Category-Specific Sync Extensions

extension Category {
    
    /**
     * Safely creates tombstone with dependency validation
     */
    func createTombstoneWithValidation(by userId: String? = nil) throws {
        // Validate that category can be safely deleted
        guard canBeDeleted else {
            let deps = dependencyCount
            var errorMessage = "Cannot delete category '\(name ?? "Unknown")' - it has dependencies: "
            var depParts: [String] = []
            
            if deps.expenses > 0 {
                depParts.append("\(deps.expenses) expense\(deps.expenses == 1 ? "" : "s")")
            }
            if deps.budgets > 0 {
                depParts.append("\(deps.budgets) budget\(deps.budgets == 1 ? "" : "s")")
            }
            if deps.recurringExpenses > 0 {
                depParts.append("\(deps.recurringExpenses) recurring expense\(deps.recurringExpenses == 1 ? "" : "s")")
            }
            
            errorMessage += depParts.joined(separator: ", ")
            throw SyncError.conflictResolution(errorMessage)
        }
        
        // Create tombstone
        createTombstone(by: userId)
    }
    
    /**
     * Handles dependency nullification when creating tombstone
     * Call this AFTER creating tombstone to clean up references
     */
    func handleDependenciesAfterTombstone() {
        // Note: CoreData's nullify deletion rule should handle this automatically
        // But we can add explicit handling if needed for sync purposes
        
        // The relationships will be automatically nullified by CoreData
        // when this category is eventually physically deleted during cleanup
    }
}
