// StudentExpenseTracker/Core/Data/Sync/Services/SyncManager.swift
import Foundation
import CoreData

/**
 * Wrapper for raw Firestore document data to work with Codable APIs
 */
private struct FirestoreDocument: Codable {
    let data: [String: Any]
    
    init(data: [String: Any]) {
        self.data = data
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.data = try container.decode([String: AnyCodable].self).mapValues { $0.value }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        let codableData = data.mapValues { AnyCodable($0) }
        try container.encode(codableData)
    }
}

/**
 * Helper for encoding/decoding Any values in Codable contexts
 */
private struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(Any.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let string as String:
            try container.encode(string)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let bool as Bool:
            try container.encode(bool)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dict as [String: Any]:
            try container.encode(dict.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

/**
 * Conflict resolution strategy options for handling sync conflicts
 */
public enum ConflictResolutionStrategy: String, CaseIterable {
    case remoteWins = "remoteWins"
    case localWins = "localWins"
    case newestWins = "newestWins"
    case userChoice = "userChoice"
    
    var description: String {
        switch self {
        case .remoteWins:
            return "Remote data always wins (server authoritative)"
        case .localWins:
            return "Local data always wins (client authoritative)"
        case .newestWins:
            return "Most recently updated data wins (last-writer-wins)"
        case .userChoice:
            return "Prompt user to choose which version to keep"
        }
    }
}

/**
 * Main synchronization coordinator for CoreData ↔ Firestore operations
 *
 * Orchestrates bidirectional sync between local CoreData and remote Firestore,
 * ensuring data consistency, handling conflicts, and providing progress feedback.
 *
 * Features:
 * - Delta sync for efficiency (only changed data)
 * - Dependency-aware sync order (categories → dependent entities)
 * - Configurable conflict resolution with multiple strategies
 * - Network-aware operations with retry logic
 * - Comprehensive progress tracking and error handling
 * - User-scoped data isolation for security
 * - Tombstone pattern for deletion conflict resolution
 * - Debug logging for troubleshooting sync issues
 *
 * Note: AppUser is NOT synced - it's managed by Firebase Auth and serves as a local cache.
 * All other entities reference AppUser but don't sync the user data itself.
 */
@Observable
class SyncManager {
    
    // MARK: - Dependencies
    
    internal let persistenceController: PersistenceController
    internal let firebaseService: FirebaseService
    internal let networkMonitor: NetworkMonitor
    internal let syncStatusTracker: SyncStatusTracker
    private let authViewModel: AuthViewModel
    
    // MARK: - Sync Configuration
    
    /// Current conflict resolution strategy
    var conflictResolutionStrategy: ConflictResolutionStrategy = .newestWins
    
    // MARK: - Sync State Properties
    
    /// Current sync operation description
    private(set) var currentOperation: String = "Ready"
    
    /// Current sync progress (0.0 to 1.0)
    private(set) var syncProgress: Double = 0.0
    
    /// Whether sync is currently in progress
    var isSyncing: Bool {
        syncStatusTracker.isSyncing
    }
    
    /// Whether network is available for sync operations
    var canSync: Bool {
        return networkMonitor.isConnected && authViewModel.user != nil && firebaseService.isConfigured
    }
    
    /// Last sync error if any
    var lastSyncError: SyncError? {
        syncStatusTracker.lastError
    }
    
    /// Last successful sync timestamp
    var lastSyncAt: Date? {
        syncStatusTracker.lastSyncAt
    }
    
    // MARK: - Sync Order Constants
    
    /// Entity sync order respecting dependencies
    /// Note: AppUser excluded - managed by Firebase Auth, not synced
    internal let syncOrder: [any Syncable.Type] = [
        Category.self          // Categories first (references local AppUser)
        ,Budget.self           // Budgets (user + category dependent)
        ,Income.self           // Income (references local AppUser)
        ,RecurringExpense.self // Recurring expenses (user + category dependent)
        ,RecurringIncome.self  // Recurring incomes (user + category dependent)
        ,Expense.self          // Expenses last (user + category + recurring dependent)
    ]
    
    // MARK: - Debug Properties
    
    /// Enable detailed debug logging for sync operations
    var debugLoggingEnabled: Bool = true
    
    // MARK: - Initialization
    
    init(authViewModel: AuthViewModel,
         persistenceController: PersistenceController = PersistenceController.shared,
         firebaseService: FirebaseService? = nil,
         networkMonitor: NetworkMonitor = NetworkMonitor.shared,
         conflictStrategy: ConflictResolutionStrategy = .newestWins) {
        
        self.authViewModel = authViewModel
        self.persistenceController = persistenceController
        self.firebaseService = firebaseService ?? FirebaseService(authViewModel: authViewModel)
        self.networkMonitor = networkMonitor
        self.syncStatusTracker = SyncStatusTracker()
        self.conflictResolutionStrategy = conflictStrategy
        
//        setupMonitoring()
//        debugLog("🔧 SyncManager initialized with conflict strategy: \(conflictStrategy.description)")
    }

    
    
    
    
    /**
     * DEBUG: Complete Firestore reset - deletes all user data from Firestore
     * WARNING: This is destructive and cannot be undone!
     */
    func debugCompleteFirestoreReset() async throws {
        debugLog("🚨 DEBUG: Starting complete Firestore reset...")
        
        guard canSync else {
            throw determinePrerequisiteError()
        }
        
        try await firebaseService.initialize()
        try await firebaseService.deleteAllUserData()
        
        // Reset local sync state since remote data is gone
        await debugResetSyncState()
        
        // Mark all local entities for sync since remote data is gone
        await markAllEntitiesForSync()
        
        debugLog("✅ DEBUG: Complete Firestore reset completed")
    }
    
    
    
    
    
    
    // MARK: - Public Sync Operations
    
    /**
     * Perform full bidirectional synchronization with tombstone handling
     * Download first to detect conflicts, then upload with conflict resolution
     */
    func performFullSync() async {
        debugLog("🚀 Starting full sync with tombstone support...")
        debugLog("📊 Sync prerequisites: canSync=\(canSync), connected=\(networkMonitor.isConnected), authenticated=\(authViewModel.user != nil), configured=\(firebaseService.isConfigured)")
        
        guard canSync else {
            await handleSyncPrerequisiteFailure()
            return
        }
        
        await startSyncOperation("Starting full sync...")
        
        do {
            // Initialize Firebase service if needed
            try await firebaseService.initialize()
            
            // Phase 1: Download remote changes first to detect conflicts
            await updateSyncState(operation: "Checking for remote updates...", progress: 0.1)
            try await downloadRemoteChangesInternal()
            
            // Phase 2: Clean up local tombstones (delete expired ones)
            await updateSyncState(operation: "Cleaning up old tombstones...", progress: 0.3)
            try await cleanupExpiredTombstones()
            
            // Phase 3: Detect and resolve conflicts (including deletion conflicts)
            await updateSyncState(operation: "Resolving conflicts...", progress: 0.4)
            try await resolveConflicts()
            
            // Phase 4: Upload local changes (after conflict resolution)
            await updateSyncState(operation: "Uploading local changes...", progress: 0.7)
            try await uploadLocalChangesInternal()
            
            // Complete sync
            await completeSyncOperation("Sync completed successfully")
            
        } catch let error as SyncError {
            await handleSyncError(error)
        } catch {
            await handleSyncError(.firestoreError(error))
        }
    }
    
    /**
     * Upload only local changes to remote
     */
    func uploadLocalChanges() async throws {
        guard canSync else {
            throw determinePrerequisiteError()
        }
        
        try await firebaseService.initialize()
        try await uploadLocalChangesInternal()
    }
    
    /**
     * Download only remote changes to local
     */
    func downloadRemoteChanges() async throws {
        guard canSync else {
            throw determinePrerequisiteError()
        }
        
        try await firebaseService.initialize()
        try await downloadRemoteChangesInternal()
    }
    
    /**
     * Force sync specific entity type
     */
    func syncEntityType<T: Syncable>(_ entityType: T.Type) async throws {
        guard canSync else {
            throw determinePrerequisiteError()
        }
        
        await startSyncOperation("Syncing \(entityType.collectionName)...")
        
        do {
            try await firebaseService.initialize()
            
            // Upload local changes for this entity type
            try await uploadEntitiesOfType(entityType, context: persistenceController.viewContext)
            
            // Download remote changes for this entity type
            try await downloadEntitiesOfType(entityType)
            
            await completeSyncOperation("Synced \(entityType.collectionName)")
            
        } catch {
            await handleSyncError(.firestoreError(error))
            throw error
        }
    }
    
    // MARK: - Internal Sync Implementation
    
    /**
     * Download remote changes and merge with local data - Enhanced with tombstone handling
     */
    private func downloadRemoteChangesInternal() async throws {
        debugLog("⬇️ Starting download phase with tombstone support...")
        
        for (index, entityType) in syncOrder.enumerated() {
            let progressBase = 0.5 + (Double(index) / Double(syncOrder.count)) * 0.4
            
            await updateSyncState(
                operation: "Downloading \(entityType.collectionName)...",
                progress: progressBase
            )
            
            try await downloadEntitiesOfType(entityType)
            
            // Check for cancellation
            if Task.isCancelled {
                throw SyncError.networkUnavailable
            }
        }
        
        debugLog("✅ Download phase completed")
    }
    
    /**
     * Download entities of a specific type from Firestore - Enhanced with tombstone handling
     */
    private func downloadEntitiesOfType(_ entityType: any Syncable.Type) async throws {
        let context = persistenceController.viewContext
        let lastSync = getLastSyncDate(for: entityType.collectionName)
        
        debugLog("🔍 Downloading \(entityType.collectionName) with tombstone support...")
        debugLog("📅 Last sync for \(entityType.collectionName): \(lastSync)")
        
        // Get remote documents
        let remoteDocuments: [String: FirestoreDocument]
        
        do {
            remoteDocuments = try await firebaseService.getChangedDocuments(
                collection: entityType.collectionName,
                since: lastSync,
                type: FirestoreDocument.self
            )
        } catch {
            debugLog("❌ Failed to get changed documents for \(entityType.collectionName): \(error)")
            Logger.log("Failed to get changed documents for \(entityType.collectionName): \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
        
        debugLog("📦 Found \(remoteDocuments.count) remote \(entityType.collectionName) documents")
        
        if remoteDocuments.isEmpty {
            debugLog("📝 No remote \(entityType.collectionName) documents to download")
            return
        }
        
        var processedCount = 0
        var errorCount = 0
        
        // Process each remote document with tombstone handling
        for (documentId, firestoreDoc) in remoteDocuments {
            await withCheckedContinuation { continuation in
                context.perform {
                    do {
                        let documentData = firestoreDoc.data
                        let isRemoteDeleted = (documentData["deleted"] as? Bool) ?? false
                        
                        self.debugLog("🔄 Processing document \(documentId) (deleted: \(isRemoteDeleted))...")
                        
                        // Check if entity already exists locally
                        let existingEntity = try self.findExistingEntity(
                            ofType: entityType,
                            withId: documentId,
                            in: context
                        )
                        
                        if let existing = existingEntity {
                            if isRemoteDeleted {
                                // Handle remote deletion vs local entity
                                try self.handleRemoteDeletion(existing, with: documentData)
                            } else {
                                // Handle normal update
                                try self.updateEntityIfNewer(existing, with: documentData)
                            }
                        } else {
                            if !isRemoteDeleted {
                                // Create new entity only if not deleted
                                self.debugLog("🆕 Creating new entity \(documentId)")
                                let newEntity = try entityType.createFromFirestoreData(documentData, context: context)
                                if let syncableEntity = newEntity as? any Syncable {
                                    syncableEntity.markAsSynced()
                                }
                            } else {
                                self.debugLog("⚰️ Skipping creation of deleted entity \(documentId)")
                            }
                        }
                        
                        processedCount += 1
                        continuation.resume()
                    } catch {
                        self.debugLog("❌ Failed to process document \(documentId): \(error)")
                        Logger.log("Failed to process remote \(entityType.collectionName) document: \(error)", level: .error)
                        errorCount += 1
                        continuation.resume()
                    }
                }
            }
        }
        
        debugLog("📊 Processing summary for \(entityType.collectionName): \(processedCount) processed, \(errorCount) errors")
        
        // Save changes
        do {
            try await persistenceController.saveAsync()
            debugLog("💾 Successfully saved \(entityType.collectionName) changes to CoreData")
        } catch {
            debugLog("❌ Failed to save \(entityType.collectionName) changes: \(error)")
            throw SyncError.dataCorruption("Failed to save downloaded data: \(error.localizedDescription)")
        }
        
        // Record successful sync for this collection
        syncStatusTracker.recordSuccessfulSync(for: entityType.collectionName)
        debugLog("✅ Recorded successful sync for \(entityType.collectionName)")
    }
    
    /**
     * Handle remote deletion conflict with local entity using Newest Wins strategy
     */
    private func handleRemoteDeletion(_ localEntity: any Syncable, with remoteData: [String: Any]) throws {
        let remoteDeletedAt = extractDateFromFirestoreData(remoteData, key: "deletedAt") ?? Date.distantPast
        let localUpdatedAt = localEntity.lastUpdated
        let localSyncStatus = localEntity.currentSyncStatus
        
        debugLog("⚰️ Remote Deletion Conflict Analysis:")
        debugLog("   Remote deleted at: \(remoteDeletedAt)")
        debugLog("   Local updated at:  \(localUpdatedAt)")
        debugLog("   Local status:      \(localSyncStatus)")
        debugLog("   Remote deletion is newer: \(remoteDeletedAt > localUpdatedAt)")
        
        // Check for DELETE vs UPDATE conflict
        if (localSyncStatus == .updated || localSyncStatus == .created) && remoteDeletedAt > localUpdatedAt {
            debugLog("⚠️ DELETE vs UPDATE CONFLICT: Remote deletion is newer than local update!")
            
            // Apply Newest Wins strategy - Remote deletion wins
            if let tombstoneEntity = localEntity as? TombstoneCapable {
                tombstoneEntity.markAsDeleted(
                    at: remoteDeletedAt,
                    by: remoteData["deletedBy"] as? String ?? "remote"
                )
                localEntity.markAsSynced() // Mark conflict as resolved
                debugLog("⚰️ Applied remote deletion (newest wins)")
            } else {
                // Fallback: Mark as conflict for manual resolution
                localEntity.markAsConflicted()
                debugLog("⚠️ Entity doesn't support tombstones, marked as conflict")
            }
            
        } else if remoteDeletedAt > localUpdatedAt {
            debugLog("⚰️ Remote deletion is newer, applying deletion")
            
            // No conflict, remote deletion is simply newer
            if let tombstoneEntity = localEntity as? TombstoneCapable {
                tombstoneEntity.markAsDeleted(
                    at: remoteDeletedAt,
                    by: remoteData["deletedBy"] as? String ?? "remote"
                )
                localEntity.markAsSynced()
                debugLog("⚰️ Applied remote deletion")
            } else {
                // Remove entity entirely if no tombstone support
                localEntity.managedObjectContext?.delete(localEntity as! NSManagedObject)
                debugLog("🗑️ Deleted local entity (no tombstone support)")
            }
            
        } else {
            debugLog("⬆️ Local changes are newer, keeping local version")
            // Local update is newer than remote deletion, keep local changes
            // Mark for upload to override remote deletion
            localEntity.markForSync()
        }
    }
    
    /**
     * Enhanced conflict resolution with tombstone pattern support
     */
    private func resolveConflicts() async throws {
        let context = persistenceController.viewContext
        
        debugLog("🔄 Checking for sync conflicts (including deletion conflicts)...")
        
        let conflictedEntities = await withCheckedContinuation { continuation in
            context.perform {
                var conflicts: [any Syncable] = []
                
                for entityType in self.syncOrder {
                    let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entityType).components(separatedBy: ".").last!)
                    request.predicate = NSPredicate(format: "syncStatus == %@", SyncState.conflict.rawValue)
                    
                    do {
                        let results = try context.fetch(request)
                        conflicts.append(contentsOf: results.compactMap { $0 as? any Syncable })
                    } catch {
                        Logger.log("Failed to fetch conflicts for \(entityType): \(error)", level: .error)
                    }
                }
                
                continuation.resume(returning: conflicts)
            }
        }
        
        if !conflictedEntities.isEmpty {
            debugLog("⚠️ Found \(conflictedEntities.count) conflicted entities, resolving with strategy: \(conflictResolutionStrategy.rawValue)")
            Logger.log("Resolving \(conflictedEntities.count) sync conflicts using \(conflictResolutionStrategy.description)", level: .warning)
            
            await withCheckedContinuation { continuation in
                context.perform {
                    for entity in conflictedEntities {
                        self.debugLog("🔄 Resolving conflict for entity \(entity.syncableId) using \(self.conflictResolutionStrategy.rawValue)")
                        
                        // Check if this is a deletion conflict
                        if let tombstoneEntity = entity as? TombstoneCapable,
                           tombstoneEntity.isMarkedAsDeleted {
                            self.debugLog("⚰️ Resolving deletion conflict for \(entity.syncableId)")
                            self.resolveDeletionConflict(tombstoneEntity, entity: entity)
                        } else {
                            // Regular update conflict
                            self.resolveUpdateConflict(entity)
                        }
                    }
                    continuation.resume()
                }
            }
            
            do {
                try await persistenceController.saveAsync()
                debugLog("✅ Successfully resolved \(conflictedEntities.count) conflicts using \(conflictResolutionStrategy.description)")
                Logger.log("✅ Conflicts resolved using \(conflictResolutionStrategy.description)", level: .info)
            } catch {
                debugLog("❌ Failed to save conflict resolution: \(error)")
                throw SyncError.conflictResolution("Failed to save conflict resolution: \(error.localizedDescription)")
            }
        } else {
            debugLog("✅ No conflicts found")
        }
    }
    
    /**
     * Resolve deletion conflicts using configured strategy
     */
    private func resolveDeletionConflict(_ tombstoneEntity: TombstoneCapable, entity: any Syncable) {
        switch conflictResolutionStrategy {
        case .remoteWins:
            // Keep the deletion (tombstone is already applied)
            entity.markAsSynced()
            debugLog("✅ Remote deletion wins for \(entity.syncableId)")
            
        case .localWins:
            // Resurrect the entity by unmarking deletion
            tombstoneEntity.unmarkAsDeleted()
            entity.markForSync()
            debugLog("✅ Local wins: Resurrected entity \(entity.syncableId)")
            
        case .newestWins:
            // This was already handled in handleRemoteDeletion based on timestamps
            entity.markAsSynced()
            debugLog("✅ Newest wins: Deletion conflict resolved for \(entity.syncableId)")
            
        case .userChoice:
            // For now, default to remote wins (deletion)
            // TODO: Implement user choice UI
            entity.markAsSynced()
            debugLog("⚠️ User choice not implemented, defaulting to remote deletion for \(entity.syncableId)")
        }
    }
    
    /**
     * Resolve regular update conflicts using configured strategy
     */
    private func resolveUpdateConflict(_ entity: any Syncable) {
        switch conflictResolutionStrategy {
        case .remoteWins:
            // Remote data was already applied in updateEntityIfNewer
            entity.markAsSynced()
            debugLog("✅ Remote wins: Applied remote changes for \(entity.syncableId)")
            
        case .localWins:
            // Keep local changes, mark for upload
            entity.markForSync()
            debugLog("✅ Local wins: Keeping local changes for \(entity.syncableId)")
            
        case .newestWins:
            // This was already handled in updateEntityIfNewer based on timestamps
            entity.markAsSynced()
            debugLog("✅ Newest wins: Applied most recent changes for \(entity.syncableId)")
            
        case .userChoice:
            // For now, default to remote wins
            // TODO: Implement user choice UI
            entity.markAsSynced()
            debugLog("⚠️ User choice not implemented, defaulting to remote wins for \(entity.syncableId)")
        }
    }
    
    /**
     * Clean up expired tombstones (older than 30 days)
     */
    private func cleanupExpiredTombstones() async throws {
        let context = persistenceController.viewContext
        let expirationDate = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        
        debugLog("🧹 Cleaning up tombstones older than \(expirationDate)")
        
        await withCheckedContinuation { continuation in
            context.perform {
                var deletedCount = 0
                
                for entityType in self.syncOrder {
                    let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entityType).components(separatedBy: ".").last!)
                    request.predicate = NSPredicate(format: "softDeleted == YES AND deletedAt < %@", expirationDate as NSDate)
                    
                    do {
                        let expiredTombstones = try context.fetch(request)
                        for tombstone in expiredTombstones {
                            context.delete(tombstone)
                            deletedCount += 1
                        }
                        
                        if !expiredTombstones.isEmpty {
                            self.debugLog("🧹 Cleaned up \(expiredTombstones.count) expired \(entityType.collectionName) tombstones")
                        }
                    } catch {
                        Logger.log("Failed to cleanup expired tombstones for \(entityType): \(error)", level: .error)
                    }
                }
                
                if deletedCount > 0 {
                    self.debugLog("🧹 Total expired tombstones cleaned up: \(deletedCount)")
                }
                
                continuation.resume()
            }
        }
        
        // Save cleanup changes
        if context.hasChanges {
            try await persistenceController.saveAsync()
            debugLog("💾 Saved tombstone cleanup changes")
        }
    }
    
    // MARK: - Helper Methods
    
    private func findExistingEntity(ofType entityType: any Syncable.Type, withId id: String, in context: NSManagedObjectContext) throws -> (any Syncable)? {
        let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entityType).components(separatedBy: ".").last!)
        request.predicate = NSPredicate(format: "id == %@", id)
        request.fetchLimit = 1
        
        let results = try context.fetch(request)
        return results.first as? any Syncable
    }
    
    /**
     * Enhanced updateEntityIfNewer with tombstone support
     */
    private func updateEntityIfNewer(_ entity: any Syncable, with remoteData: [String: Any]) throws {
        let remoteLastUpdate = extractDateFromFirestoreData(remoteData, key: "updatedAt") ?? Date.distantPast
        let localLastUpdate = entity.lastUpdated
        let localSyncStatus = entity.currentSyncStatus
        
        // Check if remote entity is marked as deleted
        let isRemoteDeleted = (remoteData["deleted"] as? Bool) ?? false
        
        debugLog("📅 Conflict Detection:")
        debugLog("   Remote: \(remoteLastUpdate) (deleted: \(isRemoteDeleted))")
        debugLog("   Local:  \(localLastUpdate)")
        debugLog("   Local Status: \(localSyncStatus)")
        debugLog("   Remote > Local: \(remoteLastUpdate > localLastUpdate)")
        
        // Handle deletion conflicts separately
        if isRemoteDeleted {
            try handleRemoteDeletion(entity, with: remoteData)
            return
        }
        
        // Regular update conflict detection
        if (localSyncStatus == .created || localSyncStatus == .updated) && remoteLastUpdate > localLastUpdate {
            debugLog("⚠️ UPDATE CONFLICT: Local has pending changes but remote is newer!")
            
            // Mark as conflict for resolution
            entity.markAsConflicted()
            
            // Store remote data for conflict resolution
            try entity.updateFromFirestoreData(remoteData)
            
        } else if remoteLastUpdate > localLastUpdate {
            debugLog("⬇️ Remote is newer, updating local entity")
            // Remote is newer and no local changes, safe to update
            try entity.updateFromFirestoreData(remoteData)
            entity.markAsSynced()
            
        } else {
            debugLog("⬆️ Local is newer or equal, keeping local version")
            // Local is newer or equal, keep local version
        }
    }
    
    /**
     * Extract Date from Firestore data, handling both string and Date formats
     */
    private func extractDateFromFirestoreData(_ data: [String: Any], key: String) -> Date? {
        if let dateString = data[key] as? String {
            let formatter = ISO8601DateFormatter()
            return formatter.date(from: dateString)
        } else if let date = data[key] as? Date {
            return date
        }
        return nil
    }
    
    private func getLastSyncDate(for collection: String) -> Date {
        // Firebase supports dates from January 1, 1970 onwards
        let firebaseSafeEarliestDate = Date(timeIntervalSince1970: 0)
        
        let lastSyncDate: Date
        switch collection {
        case "categories":
            lastSyncDate = syncStatusTracker.categoriesLastSync ?? firebaseSafeEarliestDate
        case "expenses":
            lastSyncDate = syncStatusTracker.expensesLastSync ?? firebaseSafeEarliestDate
        case "budgets":
            lastSyncDate = syncStatusTracker.budgetsLastSync ?? firebaseSafeEarliestDate
        case "income":
            lastSyncDate = syncStatusTracker.incomeLastSync ?? firebaseSafeEarliestDate
        case "recurringExpenses":
            lastSyncDate = syncStatusTracker.recurringExpensesLastSync ?? firebaseSafeEarliestDate
        case "recurringIncomes":
            lastSyncDate = syncStatusTracker.recurringIncomesLastSync ?? firebaseSafeEarliestDate
        default:
            lastSyncDate = firebaseSafeEarliestDate
        }
        
        debugLog("📅 Last sync date for \(collection): \(lastSyncDate)")
        return lastSyncDate
    }
    
    private func determinePrerequisiteError() -> SyncError {
        if !networkMonitor.isConnected {
            return .networkUnavailable
        } else if authViewModel.user == nil {
            return .userNotAuthenticated
        } else {
            return .firebaseNotConfigured
        }
    }
    
    private func debugLog(_ message: String) {
        guard debugLoggingEnabled else { return }
        print("🔄 SyncManager: \(message)")
        Logger.log(message, level: .debug)
    }
    
    // MARK: - State Management
    
    internal func updateSyncState(operation: String, progress: Double) async {
        await MainActor.run {
            self.currentOperation = operation
            self.syncProgress = min(max(progress, 0.0), 1.0)
            self.syncStatusTracker.updateSyncProgress(self.syncProgress)
        }
        debugLog("📊 Sync state: \(operation) (\(Int(progress * 100))%)")
    }
    
    private func startSyncOperation(_ operation: String) async {
        await MainActor.run {
            self.currentOperation = operation
            self.syncProgress = 0.0
            self.syncStatusTracker.isSyncing = true
            self.syncStatusTracker.lastError = nil
        }
        
        debugLog("🚀 Started: \(operation)")
    }
    
    private func completeSyncOperation(_ operation: String) async {
        await MainActor.run {
            self.currentOperation = operation
            self.syncProgress = 1.0
            self.syncStatusTracker.isSyncing = false
            self.syncStatusTracker.lastSyncAt = Date()
        }
        
        debugLog("✅ Completed: \(operation)")
        Logger.log("✅ Sync completed successfully", level: .info)
    }
    
    private func handleSyncError(_ error: SyncError) async {
        await MainActor.run {
            self.currentOperation = "Sync failed"
            self.syncProgress = 0.0
            self.syncStatusTracker.isSyncing = false
            self.syncStatusTracker.recordError(error)
        }
        
        debugLog("❌ Sync error: \(error.localizedDescription)")
        Logger.log("🔴 Sync failed: \(error.localizedDescription)", level: .error)
    }
    
    private func handleSyncPrerequisiteFailure() async {
        let error = determinePrerequisiteError()
        debugLog("⚠️ Sync prerequisites not met: \(error.localizedDescription)")
        await handleSyncError(error)
    }
    
    // MARK: - Public State Queries
    
    /**
     * Get human-readable sync status description
     */
    var syncStatusDescription: String {
        if isSyncing {
            return currentOperation
        } else if let error = lastSyncError {
            return "Failed: \(error.localizedDescription)"
        } else if let lastSync = lastSyncAt {
            let formatter = RelativeDateTimeFormatter()
            return "Last synced \(formatter.localizedString(for: lastSync, relativeTo: Date()))"
        } else {
            return "Ready to sync"
        }
    }
    
    /**
     * Get detailed sync progress information
     */
    var syncProgressInfo: (description: String, percentage: Int) {
        let percentage = Int(syncProgress * 100)
        return (syncStatusDescription, percentage)
    }
    
    /**
     * Get pending operations count for each entity type (including tombstones)
     */
    func getPendingOperationsCount() async -> [String: Int] {
        let context = persistenceController.viewContext
        
        return await withCheckedContinuation { continuation in
            context.perform {
                var counts: [String: Int] = [:]
                
                for entityType in self.syncOrder {
                    let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entityType).components(separatedBy: ".").last!)
                    request.predicate = NSPredicate(format: "syncStatus IN %@", [
                        SyncState.created.rawValue,
                        SyncState.updated.rawValue,
                        SyncState.deleted.rawValue
                    ])
                    
                    do {
                        let count = try context.count(for: request)
                        counts[entityType.collectionName] = count
                    } catch {
                        Logger.log("Failed to count pending \(entityType.collectionName): \(error)", level: .error)
                        counts[entityType.collectionName] = 0
                    }
                }
                
                continuation.resume(returning: counts)
            }
        }
    }
    
    // MARK: - Debug Methods
    
    /**
     * DEBUG: Reset all sync state to force fresh sync
     */
    func debugResetSyncState() async {
        debugLog("🔄 Resetting all sync state...")
        
        await MainActor.run {
            syncStatusTracker.categoriesLastSync = nil
            syncStatusTracker.expensesLastSync = nil
            syncStatusTracker.budgetsLastSync = nil
            syncStatusTracker.incomeLastSync = nil
            syncStatusTracker.recurringExpensesLastSync = nil
            syncStatusTracker.recurringIncomesLastSync = nil
            syncStatusTracker.lastSyncAt = nil
            syncStatusTracker.lastError = nil
        }
        
        // Clear device ID to force fresh sync
        UserDefaults.standard.removeObject(forKey: "SyncDeviceId")
        
        debugLog("✅ Sync state reset complete")
    }
    
    /**
     * Mark all local entities for sync after remote data deletion
     */
    private func markAllEntitiesForSync() async {
        debugLog("🔄 Marking all local entities for sync...")
        
        let context = persistenceController.viewContext
        
        await withCheckedContinuation { continuation in
            context.perform {
                for entityType in self.syncOrder {
                    let entityName = String(describing: entityType).components(separatedBy: ".").last!
                    let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                    
                    do {
                        let entities = try context.fetch(request)
                        for entity in entities {
                            if let syncableEntity = entity as? Syncable {
                                // Mark tombstones as deleted, others as updated
                                if let softDeleted = entity.value(forKey: "softDeleted") as? Bool, softDeleted {
                                    syncableEntity.currentSyncStatus = .deleted
                                } else {
                                    syncableEntity.currentSyncStatus = .updated
                                }
                            }
                        }
                        
                        self.debugLog("🔄 Marked \(entities.count) \(entityType.collectionName) entities for sync")
                    } catch {
                        self.debugLog("❌ Failed to mark \(entityType.collectionName) for sync: \(error)")
                    }
                }
                continuation.resume()
            }
        }
        
        // Save changes
        do {
            try await persistenceController.saveAsync()
            debugLog("💾 Saved entity sync markings")
        } catch {
            debugLog("❌ Failed to save entity sync markings: \(error)")
        }
        
        debugLog("✅ All entities marked for sync")
    }
    
    /**
     * DEBUG: Force fresh sync ignoring last sync dates
     */
    func debugFreshSync() async {
        debugLog("🆕 Starting fresh sync (ignoring last sync dates)")
        
        // Temporarily clear last sync dates
        await debugResetSyncState()
        
        // Perform full sync
        await performFullSync()
    }
    
    /**
     * DEBUG: Get detailed sync status information
     */
    func debugGetSyncStatus() -> [String: Any] {
        return [
            "isSyncing": isSyncing,
            "canSync": canSync,
            "isConnected": networkMonitor.isConnected,
            "isAuthenticated": authViewModel.user != nil,
            "isConfigured": firebaseService.isConfigured,
            "currentOperation": currentOperation,
            "syncProgress": syncProgress,
            "lastSyncAt": lastSyncAt?.description ?? "Never",
            "lastError": lastSyncError?.localizedDescription ?? "None",
            "categoriesLastSync": syncStatusTracker.categoriesLastSync?.description ?? "Never",
            "expensesLastSync": syncStatusTracker.expensesLastSync?.description ?? "Never",
            "budgetsLastSync": syncStatusTracker.budgetsLastSync?.description ?? "Never",
            "incomeLastSync": syncStatusTracker.incomeLastSync?.description ?? "Never",
            "recurringExpensesLastSync": syncStatusTracker.recurringExpensesLastSync?.description ?? "Never",
            "recurringIncomesLastSync": syncStatusTracker.recurringIncomesLastSync?.description ?? "Never",
            "conflictStrategy": conflictResolutionStrategy.rawValue
        ]
    }
}

// MARK: - TombstoneCapable Protocol (referenced in enhanced methods)

/**
 * Protocol for entities that support tombstone pattern for deletion conflicts
 */
protocol TombstoneCapable {
    var isMarkedAsDeleted: Bool { get }
    func markAsDeleted(at date: Date, by userId: String)
    func unmarkAsDeleted()
}
