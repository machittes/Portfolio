//
//  RecurringIncome+Syncable.swift
//  StudentExpenseTracker

import Foundation
import CoreData

extension RecurringIncome: UserOwnedEntity {
    
    static var collectionName: String {
        return "recurringIncomes"
    }
    
    func toFirestoreData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("RecurringIncome missing required fields: id or user")
        }
        
        var data: [String: Any] = [
            "id": id,
            "deleted": self.softDeleted, // Use existing CoreData field name
            "updatedAt": self.updatedAt ?? Date(),
            "userId": userId
        ]
        
        if softDeleted {
            // Tombstone data - minimal fields for deleted entities
            data["deletedAt"] = self.deletedAt ?? Date()
            
            if let deletedBy = self.deletedBy {
                data["deletedBy"] = deletedBy
            }
            
            // Optionally include source for audit trail and debugging
            if let source = self.source {
                data["deletedSource"] = source
            }
            
            // Include creation timestamp for complete audit trail
            if let createdAt = self.createdAt {
                data["createdAt"] = createdAt
            }
            
            // Include recurring income-specific metadata for recovery
            if let frequency = self.frequency {
                data["deletedFrequency"] = frequency
            }
            
            if let amount = self.amount {
                data["deletedAmount"] = amount.doubleValue
            }
        } else {
            // Full entity data for active recurring incomes
            guard let source = self.source,
                  let frequency = self.frequency else {
                throw SyncError.dataCorruption("Active recurring income missing source or frequency")
            }
            
            data["source"] = source
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
            
            // Category reference removed - no longer syncing category information
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
        guard let source = data["source"] as? String,
              let amountValue = data["amount"] as? Double,
              let frequency = data["frequency"] as? String else {
            throw SyncError.dataCorruption("RecurringIncome data missing required fields: source, amount, or frequency")
        }
        
        self.source = source
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
                self.endDate = endDate
            }
        }
        
        // Category handling removed - no longer resolving category from sync data
        
        // Update timestamps
        if let updatedAtValue = data["updatedAt"] {
            if let updatedAtString = updatedAtValue as? String,
               let updatedAt = ISO8601DateFormatter().date(from: updatedAtString) {
                self.updatedAt = updatedAt
            } else if let updatedAtDate = updatedAtValue as? Date {
                self.updatedAt = updatedAtDate
            }
        }
        
        // Update sync status
        self.currentSyncStatus = .synced
    }
    
    static func createFromFirestoreData(_ data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let userId = data["userId"] as? String else {
            throw SyncError.dataCorruption("Invalid recurring income data structure")
        }
        
        // Find the user entity
        let userRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        userRequest.predicate = NSPredicate(format: "userId == %@", userId)
        
        guard let user = try context.fetch(userRequest).first else {
            throw SyncError.dataCorruption("User not found for recurring income: \(userId)")
        }
        
        let recurringIncome = RecurringIncome(context: context)
        recurringIncome.id = id
        recurringIncome.user = user
        
        // Initialize with defaults before applying data
        recurringIncome.softDeleted = false
        recurringIncome.deletedAt = nil
        recurringIncome.deletedBy = nil
        
        // Use the updateFromFirestoreData method for consistency
        try recurringIncome.updateFromFirestoreData(data)
        
        // Set sync status to synced since this is coming from Firestore
        recurringIncome.currentSyncStatus = .synced
        
        return recurringIncome
    }
    
    // MARK: - Enhanced Tombstone Support
    
    /**
     * RecurringIncome-specific tombstone data creation
     * Overrides default implementation to include recurring income-specific fields
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.id?.uuidString,
              let userId = self.user?.userId else {
            throw SyncError.dataCorruption("RecurringIncome missing required fields for tombstone")
        }
        
        var tombstoneData: [String: Any] = [
            "id": id,
            "userId": userId,
            "deleted": true,
            "deletedAt": self.deletedAt ?? Date(),
            "updatedAt": self.updatedAt ?? Date()
        ]
        
        // Optional tombstone metadata
        if let deletedBy = self.deletedBy {
            tombstoneData["deletedBy"] = deletedBy
        }
        
        // Include source for audit trail
        if let source = self.source {
            tombstoneData["deletedSource"] = source
        }
        
        // Include creation timestamp for complete audit trail
        if let createdAt = self.createdAt {
            tombstoneData["createdAt"] = createdAt
        }
        
        // Include recurring income-specific metadata for recovery
        if let frequency = self.frequency {
            tombstoneData["deletedFrequency"] = frequency
        }
        
        if let amount = self.amount {
            tombstoneData["deletedAmount"] = amount.doubleValue
        }
        
        return tombstoneData
    }
    
    /**
     * Applies tombstone data to mark recurring income as deleted
     */
    func applyTombstone(_ data: [String: Any]) throws {
        self.softDeleted = true
        
        // Apply tombstone timestamps
        if let deletedAtValue = data["deletedAt"] {
            if let deletedAtString = deletedAtValue as? String,
               let deletedAt = ISO8601DateFormatter().date(from: deletedAtString) {
                self.deletedAt = deletedAt
            } else if let deletedAtDate = deletedAtValue as? Date {
                self.deletedAt = deletedAtDate
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
        
        // Apply deletion metadata
        self.deletedBy = data["deletedBy"] as? String
        
        // Set sync status
        self.currentSyncStatus = .synced
        
        // RecurringIncome-specific tombstone handling
        self.isActive = false
        handleDependenciesAfterTombstone()
    }
    
    /**
     * Restores recurring income from tombstone state
     */
    func restoreFromTombstone() throws {
        guard self.softDeleted else {
            throw SyncError.dataCorruption("Attempting to restore non-deleted recurring income")
        }
        
        self.softDeleted = false
        self.deletedAt = nil
        self.deletedBy = nil
        self.updatedAt = Date()
        self.currentSyncStatus = .updated
        
        // RecurringIncome-specific restoration
        self.isActive = true
        
        Logger.log("Restored recurring income from tombstone: \(self.source ?? "Unknown")", level: .info)
    }
}

// MARK: - RecurringIncome-Specific Extensions

extension RecurringIncome {
    
    /**
     * Debug description for recurring income with sync status
     */
    var recurringIncomeDebugDescription: String {
        let syncStatus = self.currentSyncStatus.rawValue
        let deletedFlag = self.softDeleted ? " [DELETED]" : ""
        let activeFlag = self.isActive ? " [ACTIVE]" : " [INACTIVE]"
        
        return "\(self.source ?? "Unknown") - \(self.frequency ?? "Unknown") - $\(self.amount?.doubleValue ?? 0.0) (\(syncStatus))\(deletedFlag)\(activeFlag)"
    }
    
    /**
     * RecurringIncome-specific validation for sync operations
     * This calls the base validateForSync() method and adds specific validations
     */
    func validateRecurringIncomeForSync() throws {
        // Call base validation from Syncable protocol
        try validateForSync()
        
        // RecurringIncome-specific validations
        if !softDeleted {
            // Active recurring incomes must have a source
            guard let source = self.source, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncError.dataCorruption("Active recurring income missing valid source")
            }
            
            // Active recurring incomes must have a frequency
            guard let frequency = self.frequency, !frequency.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SyncError.dataCorruption("Active recurring income missing valid frequency")
            }
            
            // Validate frequency is one of expected values
            let validFrequencies = ["daily", "weekly", "monthly", "yearly"]
            guard validFrequencies.contains(frequency.lowercased()) else {
                throw SyncError.dataCorruption("Invalid recurring income frequency: \(frequency)")
            }
            
            // Validate amount is positive
            guard let amount = self.amount, amount.decimalValue > 0 else {
                throw SyncError.dataCorruption("Recurring income amount must be positive")
            }
            
            // Validate start date exists
            guard self.startDate != nil else {
                throw SyncError.dataCorruption("Active recurring income missing start date")
            }
            
            // Validate end date is after start date if present
            if let startDate = self.startDate, let endDate = self.endDate {
                guard endDate > startDate else {
                    throw SyncError.dataCorruption("Recurring income end date must be after start date")
                }
            }
        }
    }
    
    /**
     * Handles post-deletion cleanup for dependencies
     */
    func handleDependenciesAfterTombstone() {
        // Recurring income-specific cleanup logic
        // For example:
        // - Mark generated income records with a reference to this deleted recurring income
        // - Update income generation schedules
        // - Notify users about impact on future income projections
        
        // For now, no special cleanup is needed
        // CoreData relationships are handled automatically
    }
    
    /**
     * Check for conflicts during sync
     */
    func hasConflictsWith(_ otherData: [String: Any]) -> Bool {
        // Get remote updated timestamp
        guard let remoteUpdatedAtValue = otherData["updatedAt"] else { return false }
        
        let remoteUpdatedAt: Date
        if let remoteUpdatedAtString = remoteUpdatedAtValue as? String,
           let parsedDate = ISO8601DateFormatter().date(from: remoteUpdatedAtString) {
            remoteUpdatedAt = parsedDate
        } else if let remoteUpdatedAtDate = remoteUpdatedAtValue as? Date {
            remoteUpdatedAt = remoteUpdatedAtDate
        } else {
            return false
        }
        
        // Compare with local timestamp
        let localUpdatedAt = self.updatedAt ?? Date.distantPast
        
        // Conflict if remote is newer and local has changes
        return remoteUpdatedAt > localUpdatedAt && self.currentSyncStatus != .synced
    }
    
    /**
     * Enhanced sync metadata
     */
    var syncMetadata: [String: Any] {
        var metadata: [String: Any] = [
            "entityType": "RecurringIncome",
            "id": self.id?.uuidString ?? "unknown",
            "syncStatus": self.currentSyncStatus.rawValue,
            "softDeleted": self.softDeleted,
            "lastUpdated": self.updatedAt ?? Date()
        ]
        
        if self.softDeleted {
            metadata["deletedAt"] = self.deletedAt
            metadata["deletedBy"] = self.deletedBy
        }
        
        return metadata
    }
    
    /**
     * Related entities description (category removed)
     */
    var relatedEntitiesDescription: String {
        var related: [String] = []
        
        let incomeCount = self.incomes?.count ?? 0
        if incomeCount > 0 {
            related.append("Generated Incomes: \(incomeCount)")
        }
        
        return related.isEmpty ? "No related entities" : related.joined(separator: ", ")
    }
}

// MARK: - TombstoneCapable Protocol Conformance

extension RecurringIncome: TombstoneCapable {
    
    var isMarkedAsDeleted: Bool {
        return self.softDeleted
    }
    
    func markAsDeleted(at date: Date, by userId: String) {
        self.softDeleted = true
        self.deletedAt = date
        self.deletedBy = userId
        self.updatedAt = date
        self.currentSyncStatus = .deleted
        
        // RecurringIncome-specific deletion handling
        self.isActive = false
        handleDependenciesAfterTombstone()
    }
    
    func unmarkAsDeleted() {
        do {
            try restoreFromTombstone()
        } catch {
            Logger.log("Failed to restore recurring income from tombstone: \(error)", level: .error)
        }
    }
}

// MARK: - Enhanced Syncable Conformance

extension RecurringIncome {
    
    /**
     * Check if recurring income is a tombstone (soft deleted)
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
     * Create tombstone with proper recurring income handling
     */
    func createTombstone(by userId: String? = nil) {
        let deletionDate = Date()
        
        // Create tombstone
        self.softDeleted = true
        self.deletedAt = deletionDate
        self.deletedBy = userId ?? "unknown"
        self.updatedAt = deletionDate
        self.currentSyncStatus = .deleted
        
        // RecurringIncome-specific cleanup
        self.isActive = false
        handleDependenciesAfterTombstone()
        
        Logger.log("Created tombstone for recurring income: \(self.source ?? "Unknown")", level: .info)
    }
}
