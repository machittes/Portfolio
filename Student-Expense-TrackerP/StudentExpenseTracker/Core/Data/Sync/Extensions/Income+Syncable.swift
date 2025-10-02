// StudentExpenseTracker/Core/Data/Sync/Extensions/Income+Syncable.swift
import Foundation
import CoreData

extension Income: UserOwnedEntity {
    
    static var collectionName: String {
        return "incomes"
    }
    
    func toFirestoreData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Income missing required fields: id or user")
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
            
            // Include income-specific metadata for audit trail
            if let amount = self.amount {
                data["deletedAmount"] = amount.doubleValue
            }
            
            if let source = self.source {
                data["deletedSource"] = source
            }
            
            if let date = self.date {
                data["deletedDate"] = date
            }
            
            data["deletedIsRecurring"] = self.isRecurring
            
            if let frequency = self.frequency {
                data["deletedFrequency"] = frequency
            }
            
        } else {
            // Full entity data for active income records
            data["amount"] = self.amount?.doubleValue ?? 0.0
            data["date"] = self.date ?? Date()
            data["isRecurring"] = self.isRecurring
            data["createdAt"] = self.createdAt ?? Date()
            data["order"] = self.order
            
            // Optional fields
            if let source = self.source {
                data["source"] = source
            }
            
            if let notes = self.notes {
                data["notes"] = notes
            }
            
            if let frequency = self.frequency {
                data["frequency"] = frequency
            }
            
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
        
//        // Regular update for active entity
//        guard let amountValue = data["amount"] as? Double else {
//            throw SyncError.dataCorruption("Income data missing required 'amount' field")
//        }

        // Accept Double, Int, or NSNumber for the "amount" field
        let amountValue: Double
        if let v = data["amount"] as? Double {
            amountValue = v
        } else if let v = data["amount"] as? Int {
            amountValue = Double(v)
        } else if let v = data["amount"] as? NSNumber {
            amountValue = v.doubleValue
        } else {
            throw SyncError.dataCorruption("Income data missing or invalid 'amount' field")
        }

        self.amount = NSDecimalNumber(value: amountValue)
        self.source = data["source"] as? String
        self.notes = data["notes"] as? String
        self.frequency = data["frequency"] as? String
        self.isRecurring = data["isRecurring"] as? Bool ?? false
        self.order = Int16(data["order"] as? Int ?? 0)
        
        // Optional display fields
        self.icon = data["icon"] as? String
        self.color = data["color"] as? String
        
        // Handle date parsing with multiple formats
        if let dateValue = data["date"] {
            if let dateString = dateValue as? String,
               let date = ISO8601DateFormatter().date(from: dateString) {
                self.date = date
            } else if let date = dateValue as? Date {
                self.date = date
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
    }
    
    static func createFromFirestoreData(_ data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = data["userId"] as? String else {
            throw SyncError.dataCorruption("Invalid income data structure")
        }
        
        // Find the user entity
        let userRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        guard let user = try context.fetch(userRequest).first else {
            throw SyncError.dataCorruption("User not found for income: \(userId)")
        }
        
        let income = Income(context: context)
        income.id = id
        income.user = user
        
        // Initialize with defaults before applying data
        income.softDeleted = false
        income.deletedAt = nil
        income.deletedBy = nil
        
        // Use the updateFromFirestoreData method for consistency
        try income.updateFromFirestoreData(data)
        
        // Set sync status to synced since this is coming from Firestore
        income.currentSyncStatus = .synced
        
        return income
    }
    
    // MARK: - Enhanced Tombstone Support
    
    /**
     * Income-specific tombstone data creation
     * Overrides default implementation to include income-specific fields
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Income missing required fields for tombstone: id or user")
        }
        
        var tombstoneData: [String: Any] = [
            "id": id,
            "deleted": true,
            "isDeleted": true, // Include both for compatibility
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
        
        // Include income-specific metadata that might be useful for recovery/audit
        if let amount = self.amount {
            tombstoneData["deletedAmount"] = amount.doubleValue
        }
        
        if let source = self.source {
            tombstoneData["deletedSource"] = source
        }
        
        if let date = self.date {
            tombstoneData["deletedDate"] = date
        }
        
        tombstoneData["deletedIsRecurring"] = self.isRecurring
        tombstoneData["deletedOrder"] = self.order
        
        if let frequency = self.frequency {
            tombstoneData["deletedFrequency"] = frequency
        }
        
        if let notes = self.notes {
            tombstoneData["deletedNotes"] = notes
        }
        
        if let icon = self.icon {
            tombstoneData["deletedIcon"] = icon
        }
        
        if let color = self.color {
            tombstoneData["deletedColor"] = color
        }
        
        return tombstoneData
    }
    
    /**
     * Income-specific tombstone application
     * Handles income-specific fields when applying remote tombstone
     */
    func applyTombstone(_ data: [String: Any]) throws {
        // Extract deletion timestamp with format support
        guard let deletedAtValue = data["deletedAt"] else {
            throw SyncError.dataCorruption("Income tombstone missing deletedAt")
        }
        
        let deletedAtDate: Date
        if let deletedAtString = deletedAtValue as? String {
            deletedAtDate = ISO8601DateFormatter().date(from: deletedAtString) ?? Date()
        } else if let deletedAtDirectDate = deletedAtValue as? Date {
            deletedAtDate = deletedAtDirectDate
        } else {
            throw SyncError.dataCorruption("Invalid deletedAt format in income tombstone")
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
        // For now, we'll keep the data for audit trail but mark as deleted
    }
    
    /**
     * Income-specific restoration from tombstone
     * Restores a deleted income record with proper validation
     */
    func restoreFromTombstone() throws {
        guard self.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted income")
        }
        
        // Restore deleted state
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
        self.updatedAt = Date()
        self.currentSyncStatus = .updated
        
        // Validate that we have minimum required data for an income record
        guard let amount = self.amount, amount.doubleValue > 0 else {
            throw SyncError.dataCorruption("Cannot restore income without valid amount")
        }
        
        guard self.date != nil else {
            throw SyncError.dataCorruption("Cannot restore income without date")
        }
        
        // Ensure we have a valid user relationship
        guard self.user != nil else {
            throw SyncError.dataCorruption("Cannot restore income without user relationship")
        }
    }
    
    // MARK: - Income-Specific Validation
    
    /**
     * Validates income-specific data for sync operations
     */
    func validateIncomeForSync() throws {
        // Call base validation
        try validateForSync()
        
        // Income-specific validations
        if !softDeleted {
            // Active income records must have valid amount
            guard let amount = self.amount, amount.doubleValue > 0 else {
                throw SyncError.dataCorruption("Active income missing valid amount")
            }
            
            // Active income records must have date
            guard self.date != nil else {
                throw SyncError.dataCorruption("Active income missing date")
            }
            
            // Validate order is reasonable
            if self.order < 0 {
                throw SyncError.dataCorruption("Income order cannot be negative")
            }
            
            // Validate recurring income has frequency
            if self.isRecurring && (self.frequency == nil || self.frequency?.isEmpty == true) {
                throw SyncError.dataCorruption("Recurring income missing frequency")
            }
        }
        
        // Validate user relationship exists
        guard self.user != nil else {
            throw SyncError.dataCorruption("Income missing user relationship")
        }
        
        // Validate tombstone consistency
        if softDeleted {
            guard deletedAt != nil else {
                throw SyncError.dataCorruption("Deleted income missing deletedAt timestamp")
            }
        }
    }
    
    // MARK: - Income-Specific Helper Methods
    
    /**
     * Checks if income can be safely deleted (no dependencies or constraints)
     */
    var canBeDeleted: Bool {
        // Income records typically don't have hard dependencies that prevent deletion
        // However, you might want to add business logic here, such as:
        // - Don't delete if it's part of a recurring series
        // - Don't delete if it's referenced in reports or budgets
        // - Don't delete recent transactions
        
        return true
    }
    
    /**
     * Gets income information for UI display
     */
    var incomeSummary: String {
        let amountStr = amount?.stringValue ?? "0"
        let sourceStr = source ?? "Unknown Source"
        let dateStr = date?.formatted(date: .abbreviated, time: .omitted) ?? "No Date"
        
        return "\(amountStr) from \(sourceStr) on \(dateStr)"
    }
    
    /**
     * Gets income type description
     */
    var incomeTypeDescription: String {
        if isRecurring {
            let freq = frequency ?? "Unknown"
            return "Recurring (\(freq))"
        } else {
            return "One-time"
        }
    }
    
    /**
     * Income-specific debug description
     */
    var incomeDebugDescription: String {
        let baseDescription = syncDebugDescription
        let summary = incomeSummary
        let typeDesc = incomeTypeDescription
        
        return "\(baseDescription) | \(summary) | \(typeDesc)"
    }
}

// MARK: - Income-Specific Sync Extensions

extension Income {
    
    /**
     * Safely creates tombstone with business rule validation
     */
    func createTombstoneWithValidation(by userId: String? = nil) throws {
        // Income-specific validation before deletion
        // Add any business rules here, such as:
        // - Can't delete recent income (within last 24 hours)
        // - Can't delete if it's part of active recurring series
        // - Can't delete if referenced in budget calculations
        
        // For now, income can be freely deleted
        // But you might want to add validation like:
        /*
        if let date = self.date, Date().timeIntervalSince(date) < 86400 {
            throw SyncError.conflictResolution("Cannot delete income recorded less than 24 hours ago")
        }
        
        if isRecurring && frequency != nil {
            throw SyncError.conflictResolution("Cannot delete active recurring income. Deactivate first.")
        }
        */
        
        // Create tombstone
        createTombstone(by: userId)
    }
    
    /**
     * Handles any cleanup needed after tombstone creation
     */
    func handleCleanupAfterTombstone() {
        // Income-specific cleanup logic
        // For example, you might want to:
        // - Update budget calculations
        // - Notify financial tracking services
        // - Log the deletion for audit purposes
        // - Update recurring income schedules
        
        // For now, no special cleanup is needed
        // CoreData relationships are handled automatically
    }
    
    /**
     * Handles recurring income tombstone logic
     */
    func handleRecurringIncomeTombstone() {
        if isRecurring {
            // Special handling for recurring income deletions
            // You might want to:
            // - Mark future occurrences as cancelled
            // - Update recurring schedules
            // - Notify users about impact on future income projections
        }
    }
}
