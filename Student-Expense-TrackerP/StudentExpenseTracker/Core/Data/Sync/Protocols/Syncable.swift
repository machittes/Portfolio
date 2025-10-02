// StudentExpenseTracker/Core/Data/Sync/Protocols/Syncable.swift
import Foundation
import CoreData

/**
 * Protocol for CoreData entities that can be synchronized with Firestore
 *
 * Provides a standardized interface for converting between CoreData entities
 * and Firestore-compatible data structures while maintaining data integrity
 * and handling sync-specific metadata.
 *
 * Conforming types must implement bidirectional conversion methods and
 * provide sync status management for reliable cloud synchronization.
 *
 * Enhanced with tombstone pattern support for proper deletion sync with
 * conflict resolution capabilities.
 */
protocol Syncable: NSManagedObject {
    /// The Firestore collection name for this entity type
    static var collectionName: String { get }
    
    /// Unique identifier used as Firestore document ID
    var syncableId: String { get }
    
    /// Current sync status for tracking sync operations
    var currentSyncStatus: SyncState { get set }
    
    /// Last update timestamp for conflict resolution
    var lastUpdated: Date { get set }
    
    /// User reference for data scoping (nil for user entity itself)
    var ownerUserId: String? { get }
    
    // MARK: - Conversion Methods
    
    /**
     * Converts the CoreData entity to Firestore-compatible dictionary
     *
     * - Returns: Dictionary containing all necessary data for Firestore storage
     * - Throws: SyncError if conversion fails due to data corruption or missing required fields
     *
     * This method should include all entity properties except relationships,
     * which should be represented as references (IDs) to maintain normalization.
     */
    func toFirestoreData() throws -> [String: Any]
    
    /**
     * Updates the CoreData entity from Firestore data
     *
     * - Parameter data: Dictionary from Firestore document
     * - Throws: SyncError if data is invalid or incompatible
     *
     * This method should update all entity properties from the provided data
     * while preserving existing relationships until they are separately synced.
     */
    func updateFromFirestoreData(_ data: [String: Any]) throws
    
    /**
     * Creates a new instance from Firestore data
     *
     * - Parameters:
     *   - data: Dictionary from Firestore document
     *   - context: CoreData managed object context for entity creation
     * - Returns: Newly created entity instance
     * - Throws: SyncError if entity creation fails
     *
     * This static method creates new entities during sync operations
     * when remote data doesn't exist locally.
     */
    static func createFromFirestoreData(_ data: [String: Any], context: NSManagedObjectContext) throws -> NSManagedObject
    
    // MARK: - Sync Status Management
    
    /// Marks entity as needing sync (created/updated locally)
    func markForSync()
    
    /// Marks entity as successfully synced
    func markAsSynced()
    
    /// Marks entity as having sync conflicts
    func markAsConflicted()
    
    /// Marks entity as deleted (soft delete for sync)
    func markAsDeleted()
    
    // MARK: - Tombstone Methods
    
    /**
     * Creates tombstone data for Firestore upload during deletion sync
     *
     * - Returns: Dictionary containing minimal tombstone data for Firestore
     * - Throws: SyncError if tombstone creation fails
     *
     * Used when uploading deletion information to preserve conflict resolution capability.
     */
    func toTombstoneData() throws -> [String: Any]
    
    /**
     * Applies tombstone data from remote source
     *
     * - Parameter data: Tombstone data from Firestore
     * - Throws: SyncError if tombstone application fails
     *
     * Used when processing remote deletions during sync operations.
     */
    func applyTombstone(_ data: [String: Any]) throws
    
    /**
     * Creates a tombstone instead of hard delete
     *
     * - Parameter userId: ID of user performing the deletion (optional)
     *
     * Marks entity as deleted while preserving it for sync conflict resolution.
     */
    func createTombstone(by userId: String?)
}

// MARK: - Default Implementations

extension Syncable {
    
    /// Default implementation using UUID as syncable ID
    var syncableId: String {
        // Cast to UUID first, then get uuidString
        if let uuid = self.value(forKey: "id") as? UUID {
            return uuid.uuidString
        }
        // Fallback to generating new UUID if id is missing
        return UUID().uuidString
    }
    
    /// Default implementation for getting current sync status
    var currentSyncStatus: SyncState {
        get {
            guard let statusString = self.value(forKey: "syncStatus") as? String else {
                return .created
            }
            return SyncState(rawValue: statusString) ?? .created
        }
        set {
            self.setValue(newValue.rawValue, forKey: "syncStatus")
        }
    }
    
    /// Default implementation for last updated timestamp
    var lastUpdated: Date {
        get {
            return self.value(forKey: "updatedAt") as? Date ?? Date()
        }
        set {
            self.setValue(newValue, forKey: "updatedAt")
        }
    }
    
    // MARK: - Tombstone Properties (using existing CoreData fields)
    
    /// Whether entity is deleted (tombstone)
    var isDeleted: Bool {
        get { self.value(forKey: "deleted") as? Bool ?? false }
        set { self.setValue(newValue, forKey: "deleted") }
    }
    
    /// When entity was deleted
    var deletedAt: Date? {
        get { self.value(forKey: "deletedAt") as? Date }
        set { self.setValue(newValue, forKey: "deletedAt") }
    }
    
    /// Who deleted the entity
    var deletedBy: String? {
        get { self.value(forKey: "deletedBy") as? String }
        set { self.setValue(newValue, forKey: "deletedBy") }
    }
    
    // MARK: - Default Sync Status Management
    
    /// Default sync status management implementations
    func markForSync() {
        currentSyncStatus = .updated
        lastUpdated = Date()
    }
    
    func markAsSynced() {
        currentSyncStatus = .synced
    }
    
    func markAsConflicted() {
        currentSyncStatus = .conflict
    }
    
    func markAsDeleted() {
        currentSyncStatus = .deleted
        lastUpdated = Date()
    }
    
    // MARK: - Default Tombstone Implementations
    
    /**
     * Creates a tombstone instead of hard delete
     */
    func createTombstone(by userId: String? = nil) {
        isDeleted = true
        deletedAt = Date()
        deletedBy = userId
        currentSyncStatus = .deleted
        lastUpdated = Date()
    }
    
    /**
     * Enhanced markAsDeleted with tombstone support
     */
    func markAsDeletedWithTombstone(by userId: String? = nil) {
        createTombstone(by: userId)
    }
    
    /**
     * Default implementation for creating tombstone data
     */
    func toTombstoneData() throws -> [String: Any] {
        guard let id = self.value(forKey: "id") as? UUID else {
            throw SyncError.dataCorruption("Entity missing ID for tombstone")
        }
        
        var tombstoneData: [String: Any] = [
            "id": id.uuidString,
            "deleted": true,
            "isDeleted": true, // Include both for compatibility
            "deletedAt": deletedAt ?? Date(),
            "updatedAt": lastUpdated,
            "userId": ownerUserId ?? ""
        ]
        
        // Include deletedBy if available
        if let deletedBy = deletedBy {
            tombstoneData["deletedBy"] = deletedBy
        }
        
        return tombstoneData
    }
    
    /**
     * Default implementation for applying tombstone data
     */
    func applyTombstone(_ data: [String: Any]) throws {
        // Extract deletion timestamp with format support
        guard let deletedAtValue = data["deletedAt"] else {
            throw SyncError.dataCorruption("Tombstone missing deletedAt")
        }
        
        let deletedAtDate: Date
        if let dateString = deletedAtValue as? String {
            deletedAtDate = ISO8601DateFormatter().date(from: dateString) ?? Date()
        } else if let date = deletedAtValue as? Date {
            deletedAtDate = date
        } else {
            throw SyncError.dataCorruption("Invalid deletedAt format in tombstone")
        }
        
        // Apply tombstone state
        isDeleted = true
        deletedAt = deletedAtDate
        deletedBy = data["deletedBy"] as? String
        lastUpdated = deletedAtDate
        currentSyncStatus = .synced
    }
    
    /**
     * Restores entity from tombstone state
     */
    func restoreFromTombstone() {
        isDeleted = false
        deletedAt = nil
        deletedBy = nil
        currentSyncStatus = .updated
        lastUpdated = Date()
    }
    
    /**
     * Checks if entity is a tombstone
     */
    var isTombstone: Bool {
        return isDeleted
    }
    
    /**
     * Gets the effective operation timestamp (deletion or update)
     */
    var effectiveTimestamp: Date {
        if isDeleted, let deletedAt = deletedAt {
            return deletedAt
        }
        return lastUpdated
    }
}

/**
 * Helper protocol for entities that have user ownership
 */
protocol UserOwnedEntity: Syncable {
    var user: AppUser? { get }
}

extension UserOwnedEntity {
    var ownerUserId: String? {
        return user?.userId
    }
}

// MARK: - Tombstone Conflict Resolution Helpers

extension Syncable {
    
    /**
     * Determines if this entity's operation is newer than remote data
     */
    func isNewerThan(remoteData: [String: Any]) -> Bool {
        let remoteTimestamp = extractRemoteTimestamp(from: remoteData)
        return effectiveTimestamp > remoteTimestamp
    }
    
    /**
     * Extracts timestamp from remote data with multiple format support
     */
    private func extractRemoteTimestamp(from data: [String: Any]) -> Date {
        // Try updatedAt first
        if let updatedAtValue = data["updatedAt"] {
            if let date = convertToDate(updatedAtValue) {
                return date
            }
        }
        
        // If remote is deleted, try deletedAt
        let remoteIsDeleted = (data["deleted"] as? Bool) ?? (data["isDeleted"] as? Bool) ?? false
        if remoteIsDeleted, let deletedAtValue = data["deletedAt"] {
            if let date = convertToDate(deletedAtValue) {
                return date
            }
        }
        
        return Date.distantPast
    }
    
    /**
     * Converts various timestamp formats to Date
     */
    private func convertToDate(_ value: Any) -> Date? {
        if let dateString = value as? String {
            return ISO8601DateFormatter().date(from: dateString)
        } else if let date = value as? Date {
            return date
        }
        return nil
    }
}

// MARK: - Debug and Utility Extensions

extension Syncable {
    
    /**
     * Debug description of sync state
     */
    var syncDebugDescription: String {
        let entityName = String(describing: type(of: self))
        let id = syncableId
        let status = currentSyncStatus.rawValue
        let deleted = isDeleted ? "DELETED" : "ACTIVE"
        let timestamp = DateFormatter.localizedString(from: effectiveTimestamp, dateStyle: .short, timeStyle: .medium)
        
        return "\(entityName)[\(id)]: \(status) | \(deleted) | \(timestamp)"
    }
    
    /**
     * Validates entity state for sync operations
     */
    func validateForSync() throws {
        // Ensure entity has required ID
        guard self.value(forKey: "id") as? UUID != nil else {
            throw SyncError.dataCorruption("Entity missing required ID field")
        }
        
        // Ensure user ownership for user-owned entities
        if let userOwnedEntity = self as? UserOwnedEntity {
            guard userOwnedEntity.user != nil else {
                throw SyncError.dataCorruption("User-owned entity missing user relationship")
            }
        }
        
        // Validate tombstone state consistency
        if isDeleted && deletedAt == nil {
            throw SyncError.dataCorruption("Deleted entity missing deletedAt timestamp")
        }
    }
}
