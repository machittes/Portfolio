// StudentExpenseTracker/Core/Data/Sync/Extensions/RecurringExpense+Syncable.swift
import Foundation
import CoreData

extension RecurringExpense: UserOwnedEntity {
    
    static var collectionName: String {
        return "recurringExpenses"
    }
    
    func toFirestoreData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("RecurringExpense missing required fields: id or user")
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
            
            // Optionally include title for audit trail and debugging
            if let title = self.title {
                data["deletedTitle"] = title
            }
            
            // Include creation timestamp for complete audit trail
            if let createdAt = self.createdAt {
                data["createdAt"] = createdAt
            }
            
            // Include recurring expense-specific metadata for recovery
            if let frequency = self.frequency {
                data["deletedFrequency"] = frequency
            }
            
            if let amount = self.amount {
                data["deletedAmount"] = amount.doubleValue
            }
        } else {
            // Full entity data for active recurring expenses
            guard let title = self.title,
                  let frequency = self.frequency else {
                throw SyncError.dataCorruption("Active recurring expense missing title or frequency")
            }
            
            data["title"] = title
            data["amount"] = self.amount?.doubleValue ?? 0.0
            data["frequency"] = frequency
            data["startDate"] = self.startDate ?? Date()
            data["dayOfMonthWeek"] = self.dayOfMonthWeek
            data["isActive"] = self.isActive
            data["createdAt"] = self.createdAt ?? Date()
            
            // Optional fields
            if let endDate = self.endDate {
                data["endDate"] = endDate
            }
            
            if let notes = self.notes {
                data["notes"] = notes
            }
            
            if let color = self.color {
                data["color"] = color
            }
            
            if let icon = self.icon {
                data["icon"] = icon
            }
            
            // Category reference (normalized - store ID only)
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
        guard let title = data["title"] as? String,
              let amountValue = data["amount"] as? Double,
              let frequency = data["frequency"] as? String else {
            throw SyncError.dataCorruption("RecurringExpense data missing required fields: title, amount, or frequency")
        }
        
        self.title = title
        self.amount = NSDecimalNumber(value: amountValue)
        self.frequency = frequency
        self.notes = data["notes"] as? String
        self.color = data["color"] as? String
        self.icon = data["icon"] as? String
        self.dayOfMonthWeek = Int16(data["dayOfMonthWeek"] as? Int ?? 0)
        self.isActive = data["isActive"] as? Bool ?? true
        
        // Handle start date parsing
        if let startDateValue = data["startDate"] {
            if let startDateString = startDateValue as? String,
               let startDate = ISO8601DateFormatter().date(from: startDateString) {
                self.startDate = startDate
            } else if let startDateDate = startDateValue as? Date {
                self.startDate = startDateDate
            }
        }
        
        // Handle end date parsing
        if let endDateValue = data["endDate"] {
            if let endDateString = endDateValue as? String,
               let endDate = ISO8601DateFormatter().date(from: endDateString) {
                self.endDate = endDate
            } else if let endDateDate = endDateValue as? Date {
                self.endDate = endDateDate
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
            throw SyncError.dataCorruption("Invalid recurring expense data structure")
        }
        
        // Find the user entity
        let userRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        guard let user = try context.fetch(userRequest).first else {
            throw SyncError.dataCorruption("User not found for recurring expense: \(userId)")
        }
        
        let recurringExpense = RecurringExpense(context: context)
        recurringExpense.id = id
        recurringExpense.user = user
        
        // Initialize with defaults before applying data
        recurringExpense.softDeleted = false
        recurringExpense.deletedAt = nil
        recurringExpense.deletedBy = nil
        
        // Use the updateFromFirestoreData method for consistency
        try recurringExpense.updateFromFirestoreData(data)
        
        // Set sync status to synced since this is coming from Firestore
        recurringExpense.currentSyncStatus = .synced
        
        return recurringExpense
    }
    
    // MARK: - Enhanced Tombstone Support
    
    /**
     * RecurringExpense-specific tombstone data creation
     * Overrides default implementation to include recurring expense-specific fields
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("RecurringExpense missing required fields for tombstone: id or user")
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
        
        // Include recurring expense title for audit trail (optional but helpful for debugging)
        if let title = self.title {
            tombstoneData["deletedTitle"] = title
        }
        
        // Include original creation timestamp for complete audit trail
        if let createdAt = self.createdAt {
            tombstoneData["createdAt"] = createdAt
        }
        
        // Include recurring expense-specific metadata that might be useful for recovery
        if let frequency = self.frequency {
            tombstoneData["deletedFrequency"] = frequency
        }
        
        if let amount = self.amount {
            tombstoneData["deletedAmount"] = amount.doubleValue
        }
        
        tombstoneData["isActive"] = self.isActive
        tombstoneData["dayOfMonthWeek"] = self.dayOfMonthWeek
        
        if let startDate = self.startDate {
            tombstoneData["deletedStartDate"] = startDate
        }
        
        if let endDate = self.endDate {
            tombstoneData["deletedEndDate"] = endDate
        }
        
        if let notes = self.notes {
            tombstoneData["deletedNotes"] = notes
        }
        
        if let color = self.color {
            tombstoneData["deletedColor"] = color
        }
        
        if let icon = self.icon {
            tombstoneData["deletedIcon"] = icon
        }
        
        return tombstoneData
    }
    
    /**
     * RecurringExpense-specific tombstone application
     * Handles recurring expense-specific fields when applying remote tombstone
     */
    func applyTombstone(_ data: [String: Any]) throws {
        // Extract deletion timestamp with format support
        guard let deletedAtValue = data["deletedAt"] else {
            throw SyncError.dataCorruption("RecurringExpense tombstone missing deletedAt")
        }
        
        let deletedAtDate: Date
        if let deletedAtString = deletedAtValue as? String {
            deletedAtDate = ISO8601DateFormatter().date(from: deletedAtString) ?? Date()
        } else if let deletedAtDirectDate = deletedAtValue as? Date {
            deletedAtDate = deletedAtDirectDate
        } else {
            throw SyncError.dataCorruption("Invalid deletedAt format in recurring expense tombstone")
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
        
        // Recurring expense-specific tombstone handling
        // Deactivate when deleted to prevent further generation
        self.isActive = false
        
        // Optionally preserve some metadata for potential recovery
        // (This is optional - you might want to clear all data for privacy)
        if let deletedTitle = data["deletedTitle"] as? String {
            // Store in a way that indicates this is historical data
            // Could be used for "Recently Deleted" UI or recovery features
            // For now, we'll clear the title to hide deleted recurring expenses from UI
            self.title = nil // Clear title so deleted recurring expenses don't appear in lists
        }
    }
    
    /**
     * RecurringExpense-specific restoration from tombstone
     * Restores a deleted recurring expense with proper validation
     */
    func restoreFromTombstone() throws {
        guard self.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted recurring expense")
        }
        
        // Restore deleted state
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
        self.updatedAt = Date()
        self.currentSyncStatus = .updated
        
        // Validate that we have minimum required data for a recurring expense
        if self.title == nil || self.title?.isEmpty == true {
            throw SyncError.dataCorruption("Cannot restore recurring expense without title")
        }
        
        if self.frequency == nil || self.frequency?.isEmpty == true {
            throw SyncError.dataCorruption("Cannot restore recurring expense without frequency")
        }
        
        // Ensure we have a valid user relationship
        guard self.user != nil else {
            throw SyncError.dataCorruption("Cannot restore recurring expense without user relationship")
        }
        
        // Recurring expense-specific restoration
        self.isActive = true // Reactivate on restore
        
        // Clean up any orphan markings from generated expenses
        if let expenses = self.expenses?.allObjects as? [Expense] {
            for expense in expenses {
                if let notes = expense.notes, notes.contains("[Source recurring expense deleted]") {
                    expense.notes = notes.replacingOccurrences(of: " [Source recurring expense deleted]", with: "")
                    expense.syncStatus = "updated"
                }
            }
        }
    }
    
    // MARK: - RecurringExpense-Specific Validation
    
    /**
     * Validates recurring expense-specific data for sync operations
     */
    func validateRecurringExpenseForSync() throws {
        // Call base validation
        try validateForSync()
        
        // RecurringExpense-specific validations
        if !softDeleted {
            // Active recurring expenses must have a title
            guard let title = self.title, !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncError.dataCorruption("Active recurring expense missing valid title")
            }
            
            // Active recurring expenses must have a frequency
            guard let frequency = self.frequency, !frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncError.dataCorruption("Active recurring expense missing valid frequency")
            }
            
            // Validate frequency is one of expected values
            let validFrequencies = ["daily", "weekly", "monthly", "yearly"]
            guard validFrequencies.contains(frequency.lowercased()) else {
                throw SyncError.dataCorruption("Invalid recurring expense frequency: \(frequency)")
            }
            
            // Validate amount is positive
            guard let amount = self.amount, amount.decimalValue > 0 else {
                throw SyncError.dataCorruption("Recurring expense amount must be positive")
            }
            
            // Validate dayOfMonthWeek is reasonable
            if self.dayOfMonthWeek < 0 || self.dayOfMonthWeek > 31 {
                throw SyncError.dataCorruption("Recurring expense dayOfMonthWeek must be between 0 and 31")
            }
            
            // Validate dates
            if let endDate = self.endDate, let startDate = self.startDate, endDate < startDate {
                throw SyncError.dataCorruption("Recurring expense end date cannot be before start date")
            }
        }
        
        // Validate user relationship exists
        guard self.user != nil else {
            throw SyncError.dataCorruption("RecurringExpense missing user relationship")
        }
        
        // Validate tombstone consistency
        if softDeleted {
            guard deletedAt != nil else {
                throw SyncError.dataCorruption("Deleted recurring expense missing deletedAt timestamp")
            }
        }
    }
    
    // MARK: - RecurringExpense-Specific Helper Methods
    
    /**
     * Checks if recurring expense can be safely deleted (considers generated expenses)
     */
    var canBeDeleted: Bool {
        // Check if recurring expense has any generated expenses that are not deleted
        if let expenses = self.expenses?.allObjects as? [Expense] {
            let activeExpenses = expenses.filter { !$0.softDeleted }
            return activeExpenses.isEmpty
        }
        
        return true
    }
    
    /**
     * Gets dependency count for UI display
     */
    var dependencyCount: Int {
        let expenseCount = self.expenses?.count ?? 0
        return expenseCount
    }
    
    /**
     * RecurringExpense-specific debug description
     */
    var recurringExpenseDebugDescription: String {
        let baseDescription = syncDebugDescription
        let title = self.title ?? "NO_TITLE"
        let frequency = self.frequency ?? "NO_FREQ"
        let dependencies = dependencyCount
        let depString = "GE:\(dependencies)"
        
        return "\(baseDescription) | \(title) (\(frequency)) | \(depString)"
    }
}

// MARK: - RecurringExpense-Specific Sync Extensions

extension RecurringExpense {
    
    /**
     * Safely creates tombstone with dependency validation
     */
    func createTombstoneWithValidation(by userId: String? = nil) throws {
        // Note: For recurring expenses, we might want to allow deletion even with generated expenses
        // since those expenses are historical data that should be preserved independently
        
        // Warn about dependencies but allow deletion
        let dependencyInfo = dependencyCount
        if dependencyInfo > 0 {
            Logger.log("RecurringExpense '\(title ?? "Unknown")' has \(dependencyInfo) generated expenses. These will be marked as orphaned.", level: .warning)
        }
        
        // Create tombstone
        createTombstone(by: userId)
    }
    
    /**
     * Handles dependency cleanup when creating tombstone
     * Marks generated expenses as orphaned but preserves them
     */
    func handleDependenciesAfterTombstone() {
        // Mark all generated expenses as orphaned but don't delete them
        // This preserves historical data while indicating the source is deleted
        if let expenses = self.expenses?.allObjects as? [Expense] {
            for expense in expenses {
                // Add a note to indicate the source recurring expense was deleted
                let orphanNote = " [Source recurring expense deleted]"
                if let existingNotes = expense.notes {
                    if !existingNotes.contains(orphanNote) {
                        expense.notes = existingNotes + orphanNote
                    }
                } else {
                    expense.notes = "Generated from recurring expense" + orphanNote
                }
                expense.syncStatus = "updated"
            }
        }
    }
}

// MARK: - TombstoneCapable Conformance

extension RecurringExpense: TombstoneCapable {
    
    var isMarkedAsDeleted: Bool {
        return self.softDeleted
    }
    
    func markAsDeleted(at date: Date, by userId: String) {
        self.softDeleted = true
        self.deletedAt = date
        self.deletedBy = userId
        self.updatedAt = date
        self.currentSyncStatus = .deleted
        
        // Recurring expense-specific deletion handling
        self.isActive = false
        handleDependenciesAfterTombstone()
    }
    
    func unmarkAsDeleted() {
        do {
            try restoreFromTombstone()
        } catch {
            Logger.log("Failed to restore recurring expense from tombstone: \(error)", level: .error)
        }
    }
}

// MARK: - Enhanced Syncable Conformance

extension RecurringExpense {
    
    /**
     * Check if recurring expense is a tombstone (soft deleted)
     */
    var isTombstone: Bool {
        return self.softDeleted
    }
    
    /**
     * Get tombstone age in days
     */
    var tombstoneAge: Int? {
        guard let deletedAt = self.deletedAt else { return nil }
        return Calendar.current.dateComponents([.day], from: deletedAt, to: Date()).day
    }
    
    /**
     * Create tombstone with proper recurring expense handling
     */
    func createTombstone(by userId: String? = nil) {
        let deletionDate = Date()
        
        // Create tombstone
        self.softDeleted = true
        self.deletedAt = deletionDate
        self.deletedBy = userId ?? "unknown"
        self.updatedAt = deletionDate
        self.currentSyncStatus = .deleted
        
        // Recurring expense-specific cleanup
        self.isActive = false
        handleDependenciesAfterTombstone()
        
        Logger.log("Created tombstone for recurring expense: \(self.title ?? "Unknown")", level: .info)
    }
    
    /**
     * Enhanced validation including recurring expense-specific checks
     */
    func validateForSync() throws {
        try validateRecurringExpenseForSync()
    }
}
