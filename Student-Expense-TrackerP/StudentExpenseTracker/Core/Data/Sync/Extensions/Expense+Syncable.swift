// StudentExpenseTracker/Core/Data/Sync/Extensions/Expense+Syncable.swift
import Foundation
import CoreData

extension Expense: UserOwnedEntity {
    
    static var collectionName: String {
        return "expenses"
    }
    
    func toFirestoreData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Expense missing required fields: id or user")
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
            
            // Include expense-specific metadata for audit trail
            if let amount = self.amount {
                data["deletedAmount"] = amount.doubleValue
            }
            
            if let date = self.date {
                data["deletedDate"] = date
            }
            
            data["deletedIsRecurring"] = self.isRecurring
            
            if let notes = self.notes {
                data["deletedNotes"] = notes
            }
            
            // Include relationship IDs for audit trail
            if let categoryId = self.category?.id?.uuidString {
                data["deletedCategoryId"] = categoryId
            }
            
            if let recurringExpenseId = self.recurringExpense?.id?.uuidString {
                data["deletedRecurringExpenseId"] = recurringExpenseId
            }
            
            // Include receipt info for audit (but not the actual data for privacy/storage)
            if self.receiptImage != nil {
                data["hadReceiptImage"] = true
            }
            
        } else {
            // Full entity data for active expenses
            data["amount"] = self.amount?.doubleValue ?? 0.0
            data["date"] = self.date ?? Date()
            data["isRecurring"] = self.isRecurring
            data["createdAt"] = self.createdAt ?? Date()
            
            // Optional fields
            if let notes = self.notes {
                data["notes"] = notes
            }
            
            // Category reference (normalized - store ID only)
            if let categoryId = self.category?.id?.uuidString {
                data["categoryId"] = categoryId
            }
            
            // Recurring expense reference
            if let recurringExpenseId = self.recurringExpense?.id?.uuidString {
                data["recurringExpenseId"] = recurringExpenseId
            }
            
            // Handle receipt image - store as base64 string or Cloud Storage URL
            // For now, storing as base64 (consider Cloud Storage for production)
            if let receiptImageData = self.receiptImage {
                data["receiptImageBase64"] = receiptImageData.base64EncodedString()
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
        guard let amountValue = data["amount"] as? Double else {
            throw SyncError.dataCorruption("Expense data missing required 'amount' field")
        }
        
        self.amount = NSDecimalNumber(value: amountValue)
        self.notes = data["notes"] as? String
        self.isRecurring = data["isRecurring"] as? Bool ?? false
        
        // Handle date parsing with multiple formats
        if let dateValue = data["date"] {
            if let dateString = dateValue as? String,
               let date = ISO8601DateFormatter().date(from: dateString) {
                self.date = date
            } else if let date = dateValue as? Date {
                self.date = date
            }
        }
        
        // Handle receipt image
        if let receiptBase64 = data["receiptImageBase64"] as? String {
            self.receiptImage = Data(base64Encoded: receiptBase64)
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
        
        // Note: Category and RecurringExpense relationships are handled separately
        // during relationship sync to maintain referential integrity
    }
    
    static func createFromFirestoreData(_ data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = data["userId"] as? String else {
            throw SyncError.dataCorruption("Invalid expense data structure")
        }
        
        // Find the user entity
        let userRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        guard let user = try context.fetch(userRequest).first else {
            throw SyncError.dataCorruption("User not found for expense: \(userId)")
        }
        
        let expense = Expense(context: context)
        expense.id = id
        expense.user = user
        
        // Initialize with defaults before applying data
        expense.softDeleted = false
        expense.deletedAt = nil
        expense.deletedBy = nil
        
        // Use the updateFromFirestoreData method for consistency
        try expense.updateFromFirestoreData(data)
        
        // Set sync status to synced since this is coming from Firestore
        expense.currentSyncStatus = .synced
        
        return expense
    }
    
    // MARK: - Enhanced Tombstone Support
    
    /**
     * Expense-specific tombstone data creation
     * Overrides default implementation to include expense-specific fields
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("Expense missing required fields for tombstone: id or user")
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
        
        // Include expense-specific metadata that might be useful for recovery/audit
        if let amount = self.amount {
            tombstoneData["deletedAmount"] = amount.doubleValue
        }
        
        if let date = self.date {
            tombstoneData["deletedDate"] = date
        }
        
        tombstoneData["deletedIsRecurring"] = self.isRecurring
        
        if let notes = self.notes {
            tombstoneData["deletedNotes"] = notes
        }
        
        // Include relationship metadata for audit trail
        if let categoryId = self.category?.id?.uuidString {
            tombstoneData["deletedCategoryId"] = categoryId
            tombstoneData["deletedCategoryName"] = self.category?.name
        }
        
        if let recurringExpenseId = self.recurringExpense?.id?.uuidString {
            tombstoneData["deletedRecurringExpenseId"] = recurringExpenseId
            tombstoneData["deletedRecurringExpenseTitle"] = self.recurringExpense?.title
        }
        
        // Include receipt metadata (but not actual image data for privacy/storage efficiency)
        if self.receiptImage != nil {
            tombstoneData["hadReceiptImage"] = true
            tombstoneData["receiptImageSize"] = self.receiptImage?.count ?? 0
        } else {
            tombstoneData["hadReceiptImage"] = false
        }
        
        return tombstoneData
    }
    
    /**
     * Expense-specific tombstone application
     * Handles expense-specific fields when applying remote tombstone
     */
    func applyTombstone(_ data: [String: Any]) throws {
        // Extract deletion timestamp with format support
        guard let deletedAtValue = data["deletedAt"] else {
            throw SyncError.dataCorruption("Expense tombstone missing deletedAt")
        }
        
        let deletedAtDate: Date
        if let deletedAtString = deletedAtValue as? String {
            deletedAtDate = ISO8601DateFormatter().date(from: deletedAtString) ?? Date()
        } else if let deletedAtDirectDate = deletedAtValue as? Date {
            deletedAtDate = deletedAtDirectDate
        } else {
            throw SyncError.dataCorruption("Invalid deletedAt format in expense tombstone")
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
        
        // Clear receipt image data for privacy and storage efficiency in tombstones
        // (We preserve metadata about whether it existed for audit purposes)
        self.receiptImage = nil
        
        // Optionally preserve some metadata for potential recovery
        // For audit trail purposes, we keep the basic expense data
    }
    
    /**
     * Expense-specific restoration from tombstone
     * Restores a deleted expense with proper validation
     */
    func restoreFromTombstone() throws {
        guard self.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted expense")
        }
        
        // Restore deleted state
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
        self.updatedAt = Date()
        self.currentSyncStatus = .updated
        
        // Validate that we have minimum required data for an expense
        guard let amount = self.amount, amount.doubleValue > 0 else {
            throw SyncError.dataCorruption("Cannot restore expense without valid amount")
        }
        
        guard self.date != nil else {
            throw SyncError.dataCorruption("Cannot restore expense without date")
        }
        
        // Ensure we have a valid user relationship
        guard self.user != nil else {
            throw SyncError.dataCorruption("Cannot restore expense without user relationship")
        }
        
        // Note: Receipt image cannot be restored from tombstone (was cleared for privacy)
        // Category and RecurringExpense relationships may need to be re-established
    }
    
    // MARK: - Expense-Specific Validation
    
    /**
     * Validates expense-specific data for sync operations
     */
    func validateExpenseForSync() throws {
        // Call base validation
        try validateForSync()
        
        // Expense-specific validations
        if !softDeleted {
            // Active expenses must have valid amount
            guard let amount = self.amount, amount.doubleValue > 0 else {
                throw SyncError.dataCorruption("Active expense missing valid amount")
            }
            
            // Active expenses must have date
            guard self.date != nil else {
                throw SyncError.dataCorruption("Active expense missing date")
            }
            
            // Validate recurring expense consistency
            if self.isRecurring && self.recurringExpense == nil {
                // This might be okay if it's a standalone recurring expense
                // Or it might indicate a data integrity issue
                Logger.log("Warning: Expense marked as recurring but no recurringExpense relationship", level: .warning)
            }
            
            // Validate receipt image size if present (to prevent oversized uploads)
            if let receiptImage = self.receiptImage {
                let maxReceiptSize = 10 * 1024 * 1024 // 10MB limit
                if receiptImage.count > maxReceiptSize {
                    throw SyncError.dataCorruption("Receipt image too large for sync: \(receiptImage.count) bytes")
                }
            }
        }
        
        // Validate user relationship exists
        guard self.user != nil else {
            throw SyncError.dataCorruption("Expense missing user relationship")
        }
        
        // Validate tombstone consistency
        if softDeleted {
            guard deletedAt != nil else {
                throw SyncError.dataCorruption("Deleted expense missing deletedAt timestamp")
            }
        }
    }
    
    // MARK: - Expense-Specific Helper Methods
    
    /**
     * Checks if expense can be safely deleted
     */
    var canBeDeleted: Bool {
        // Expenses typically don't have hard dependencies that prevent deletion
        // However, you might want to add business logic here, such as:
        // - Don't delete if it's part of a recurring series that's still active
        // - Don't delete if it's referenced in reports or budget calculations
        // - Don't delete recent transactions without confirmation
        
        return true
    }
    
    /**
     * Gets expense information for UI display
     */
    var expenseSummary: String {
        let amountStr = amount?.stringValue ?? "0"
        let categoryStr = category?.name ?? "Uncategorized"
        let dateStr = date?.formatted(date: .abbreviated, time: .omitted) ?? "No Date"
        
        return "\(amountStr) in \(categoryStr) on \(dateStr)"
    }
    
    /**
     * Gets expense type description
     */
    var expenseTypeDescription: String {
        if isRecurring {
            if let recurringExpense = self.recurringExpense {
                return "Recurring (\(recurringExpense.frequency ?? "Unknown"))"
            } else {
                return "Recurring (Standalone)"
            }
        } else {
            return "One-time"
        }
    }
    
    /**
     * Gets receipt status description
     */
    var receiptStatusDescription: String {
        return receiptImage != nil ? "Has Receipt" : "No Receipt"
    }
    
    /**
     * Expense-specific debug description
     */
    var expenseDebugDescription: String {
        let baseDescription = syncDebugDescription
        let summary = expenseSummary
        let typeDesc = expenseTypeDescription
        let receiptDesc = receiptStatusDescription
        
        return "\(baseDescription) | \(summary) | \(typeDesc) | \(receiptDesc)"
    }
}

// MARK: - Expense-Specific Sync Extensions

extension Expense {
    
    /**
     * Safely creates tombstone with business rule validation
     */
    func createTombstoneWithValidation(by userId: String? = nil) throws {
        // Expense-specific validation before deletion
        // Add any business rules here, such as:
        // - Can't delete recent expenses (within last hour for fraud prevention)
        // - Can't delete if it's part of active recurring series
        // - Can't delete if referenced in budget calculations
        
        // For now, expenses can be freely deleted
        // But you might want to add validation like:
        /*
        if let date = self.date, Date().timeIntervalSince(date) < 3600 {
            throw SyncError.conflictResolution("Cannot delete expense recorded less than 1 hour ago")
        }
        
        if isRecurring, let recurringExpense = self.recurringExpense, recurringExpense.isActive {
            throw SyncError.conflictResolution("Cannot delete expense from active recurring series. Deactivate recurring expense first.")
        }
        */
        
        // Create tombstone
        createTombstone(by: userId)
    }
    
    /**
     * Handles any cleanup needed after tombstone creation
     */
    func handleCleanupAfterTombstone() {
        // Expense-specific cleanup logic
        // For example, you might want to:
        // - Update budget calculations
        // - Update category spending totals
        // - Notify financial tracking services
        // - Log the deletion for audit purposes
        // - Update recurring expense schedules if applicable
        
        // Clear receipt image immediately for privacy and storage efficiency
        self.receiptImage = nil
        
        // For now, no special cleanup is needed beyond the above
        // CoreData relationships are handled automatically
    }
    
    /**
     * Handles recurring expense tombstone logic
     */
    func handleRecurringExpenseTombstone() {
        if isRecurring && recurringExpense != nil {
            // Special handling for recurring expense deletions
            // You might want to:
            // - Update the recurring expense's generated expense count
            // - Check if this affects future recurring schedules
            // - Notify users about impact on recurring expense patterns
        }
    }
    
    /**
     * Handles receipt image cleanup for tombstones
     */
    func handleReceiptCleanupForTombstone() {
        // Clear receipt image data when creating tombstone
        // This is important for:
        // - Privacy (don't keep receipt images of deleted expenses)
        // - Storage efficiency (receipt images can be large)
        // - GDPR compliance (right to be forgotten)
        
        if self.receiptImage != nil {
            Logger.log("Clearing receipt image for expense tombstone: \(self.id?.uuidString ?? "unknown")", level: .debug)
            self.receiptImage = nil
        }
    }
    
    /**
     * Gets related entities that might be affected by deletion
     */
    var relatedEntitiesDescription: String {
        var related: [String] = []
        
        if let category = self.category {
            related.append("Category: \(category.name ?? "Unknown")")
        }
        
        if let recurringExpense = self.recurringExpense {
            related.append("Recurring: \(recurringExpense.title ?? "Unknown")")
        }
        
        if receiptImage != nil {
            related.append("Has Receipt")
        }
        
        return related.isEmpty ? "No related entities" : related.joined(separator: ", ")
    }
}
