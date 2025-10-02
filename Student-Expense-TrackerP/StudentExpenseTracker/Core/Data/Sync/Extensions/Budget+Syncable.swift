// StudentExpenseTracker/Core/Data/Sync/Extensions/Budget+Syncable.swift
import Foundation
import CoreData

extension Budget: UserOwnedEntity {
    
    static var collectionName: String {
        return "budgets"
    }
    
    func toFirestoreData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Budget missing required fields: id or user")
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
            
            // Include creation timestamp for complete audit trail
            if let createdAt = self.createdAt {
                data["createdAt"] = createdAt
            }
            
            // Include budget-specific metadata for audit trail
            if let amount = self.amount {
                data["deletedAmount"] = amount.doubleValue
            }
            
            if let period = self.period {
                data["deletedPeriod"] = period
            }
            
            if let categoryId = self.category?.id?.uuidString {
                data["deletedCategoryId"] = categoryId
            }
            
        } else {
            // Full entity data for active budgets
            guard let period = self.period else {
                throw SyncError.dataCorruption("Active budget missing period")
            }
            
            data["amount"] = self.amount?.doubleValue ?? 0.0
            data["period"] = period
            data["startDate"] = self.startDate ?? Date()
            data["endDate"] = self.endDate ?? Date()
            data["alertThreshold"] = self.alertThreshold
            data["isActive"] = self.isActive
            data["createdAt"] = self.createdAt ?? Date()
            
            // Category reference (normalized - store ID only, nil for overall budgets)
            if let categoryId = self.category?.id?.uuidString {
                data["categoryId"] = categoryId
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
        guard let amountValue = data["amount"] as? Double,
              let period = data["period"] as? String else {
            throw SyncError.dataCorruption("Budget data missing required fields: amount or period")
        }
        
        self.amount = NSDecimalNumber(value: amountValue)
        self.period = period
        self.alertThreshold = data["alertThreshold"] as? Double ?? 0.8
        self.isActive = data["isActive"] as? Bool ?? true
        
        // Handle date parsing with multiple formats
        if let startDateValue = data["startDate"] {
            if let startDateString = startDateValue as? String,
               let startDate = ISO8601DateFormatter().date(from: startDateString) {
                self.startDate = startDate
            } else if let startDate = startDateValue as? Date {
                self.startDate = startDate
            }
        }
        
        if let endDateValue = data["endDate"] {
            if let endDateString = endDateValue as? String,
               let endDate = ISO8601DateFormatter().date(from: endDateString) {
                self.endDate = endDate
            } else if let endDate = endDateValue as? Date {
                self.endDate = endDate
            }
        }
        
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
        
        // Note: Category relationship is handled separately during relationship sync
    }
    
    static func createFromFirestoreData(_ data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = data["userId"] as? String else {
            throw SyncError.dataCorruption("Invalid budget data structure")
        }
        
        // Find the user entity
        let userRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        guard let user = try context.fetch(userRequest).first else {
            throw SyncError.dataCorruption("User not found for budget: \(userId)")
        }
        
        let budget = Budget(context: context)
        budget.id = id
        budget.user = user
        
        // Initialize with defaults before applying data
        budget.softDeleted = false
        budget.deletedAt = nil
        budget.deletedBy = nil
        
        // Use the updateFromFirestoreData method for consistency
        try budget.updateFromFirestoreData(data)
        
        // Set sync status to synced since this is coming from Firestore
        budget.currentSyncStatus = .synced
        
        return budget
    }
    
    // MARK: - Enhanced Tombstone Support
    
    /**
     * Budget-specific tombstone data creation
     * Overrides default implementation to include budget-specific fields
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Budget missing required fields for tombstone: id or user")
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
        
        // Include original creation timestamp for complete audit trail
        if let createdAt = self.createdAt {
            tombstoneData["createdAt"] = createdAt
        }
        
        // Include budget-specific metadata that might be useful for recovery/audit
        if let amount = self.amount {
            tombstoneData["deletedAmount"] = amount.doubleValue
        }
        
        if let period = self.period {
            tombstoneData["deletedPeriod"] = period
        }
        
        tombstoneData["deletedIsActive"] = self.isActive
        tombstoneData["deletedAlertThreshold"] = self.alertThreshold
        
        if let startDate = self.startDate {
            tombstoneData["deletedStartDate"] = startDate
        }
        
        if let endDate = self.endDate {
            tombstoneData["deletedEndDate"] = endDate
        }
        
        // Include category relationship for audit trail
        if let categoryId = self.category?.id?.uuidString {
            tombstoneData["deletedCategoryId"] = categoryId
        }
        
        return tombstoneData
    }
    
    /**
     * Budget-specific tombstone application
     * Handles budget-specific fields when applying remote tombstone
     */
    func applyTombstone(_ data: [String: Any]) throws {
        // Extract deletion timestamp with format support
        guard let deletedAtValue = data["deletedAt"] else {
            throw SyncError.dataCorruption("Budget tombstone missing deletedAt")
        }
        
        let deletedAtDate: Date
        if let deletedAtString = deletedAtValue as? String {
            deletedAtDate = ISO8601DateFormatter().date(from: deletedAtString) ?? Date()
        } else if let deletedAtDirectDate = deletedAtValue as? Date {
            deletedAtDate = deletedAtDirectDate
        } else {
            throw SyncError.dataCorruption("Invalid deletedAt format in budget tombstone")
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
        
        // Clear active budget data to hide from UI while preserving metadata for audit
        // (Optional: could preserve data for "Recently Deleted" UI or recovery features)
        self.isActive = false
    }
    
    /**
     * Budget-specific restoration from tombstone
     * Restores a deleted budget with proper validation
     */
    func restoreFromTombstone() throws {
        guard self.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted budget")
        }
        
        // Restore deleted state
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
        self.updatedAt = Date()
        self.currentSyncStatus = .updated
        
        // Validate that we have minimum required data for a budget
        guard let amount = self.amount, amount.doubleValue > 0 else {
            throw SyncError.dataCorruption("Cannot restore budget without valid amount")
        }
        
        guard let period = self.period, !period.isEmpty else {
            throw SyncError.dataCorruption("Cannot restore budget without period")
        }
        
        // Ensure we have valid dates
        guard self.startDate != nil, self.endDate != nil else {
            throw SyncError.dataCorruption("Cannot restore budget without valid dates")
        }
        
        // Ensure we have a valid user relationship
        guard self.user != nil else {
            throw SyncError.dataCorruption("Cannot restore budget without user relationship")
        }
        
        // Restore active state
        self.isActive = true
    }
    
    // MARK: - Budget-Specific Validation
    
    /**
     * Validates budget-specific data for sync operations
     */
    func validateBudgetForSync() throws {
        // Call base validation
        try validateForSync()
        
        // Budget-specific validations
        if !softDeleted {
            // Active budgets must have valid amount
            guard let amount = self.amount, amount.doubleValue > 0 else {
                throw SyncError.dataCorruption("Active budget missing valid amount")
            }
            
            // Active budgets must have period
            guard let period = self.period, !period.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncError.dataCorruption("Active budget missing period")
            }
            
            // Validate dates
            guard let startDate = self.startDate, let endDate = self.endDate else {
                throw SyncError.dataCorruption("Active budget missing start or end date")
            }
            
            guard startDate <= endDate else {
                throw SyncError.dataCorruption("Budget start date must be before end date")
            }
            
            // Validate alert threshold
            if alertThreshold < 0 || alertThreshold > 1 {
                throw SyncError.dataCorruption("Budget alert threshold must be between 0 and 1")
            }
        }
        
        // Validate user relationship exists
        guard self.user != nil else {
            throw SyncError.dataCorruption("Budget missing user relationship")
        }
        
        // Validate tombstone consistency
        if softDeleted {
            guard deletedAt != nil else {
                throw SyncError.dataCorruption("Deleted budget missing deletedAt timestamp")
            }
        }
    }
    
    // MARK: - Budget-Specific Helper Methods
    
    /**
     * Checks if budget can be safely deleted (no dependencies or constraints)
     */
    var canBeDeleted: Bool {
        // Budgets typically don't have hard dependencies that prevent deletion
        // Unlike categories which have expenses/budgets/recurring expenses
        // However, you might want to add business logic here, such as:
        // - Don't delete if it's the only budget for a category
        // - Don't delete if it has recent activity
        // - Don't delete if it's a template budget
        
        return true
    }
    
    /**
     * Gets budget information for UI display
     */
    var budgetSummary: String {
        let amountStr = amount?.stringValue ?? "0"
        let periodStr = period ?? "unknown"
        let categoryStr = category?.name ?? "Overall"
        
        return "\(amountStr) per \(periodStr) - \(categoryStr)"
    }
    
    /**
     * Budget-specific debug description
     */
    var budgetDebugDescription: String {
        let baseDescription = syncDebugDescription
        let summary = budgetSummary
        let activeStr = isActive ? "ACTIVE" : "INACTIVE"
        
        return "\(baseDescription) | \(summary) | \(activeStr)"
    }
}

// MARK: - Budget-Specific Sync Extensions

extension Budget {
    
    /**
     * Safely creates tombstone with business rule validation
     */
    func createTombstoneWithValidation(by userId: String? = nil) throws {
        // Budget-specific validation before deletion
        // Add any business rules here, such as:
        // - Can't delete the last budget
        // - Can't delete active budgets with recent transactions
        // - Can't delete system/template budgets
        
        // For now, budgets can be freely deleted
        // But you might want to add validation like:
        /*
        if self.isActive && Date().timeIntervalSince(self.startDate ?? Date()) < 86400 {
            throw SyncError.conflictResolution("Cannot delete budget that started less than 24 hours ago")
        }
        */
        
        // Create tombstone
        createTombstone(by: userId)
    }
    
    /**
     * Handles any cleanup needed after tombstone creation
     */
    func handleCleanupAfterTombstone() {
        // Budget-specific cleanup logic
        // For example, you might want to:
        // - Notify related services about budget deletion
        // - Update any cached budget calculations
        // - Log the deletion for audit purposes
        
        // For now, no special cleanup is needed
        // CoreData relationships are handled automatically
    }
}
