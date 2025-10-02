// StudentExpenseTracker/Core/Data/Sync/Services/FirebaseService.swift
import Foundation
import FirebaseFirestore
import FirebaseAuth


/**
 * Production Firebase service implementing SyncServiceProtocol
 *
 * Provides secure, efficient Firestore operations for CoreData sync.
 * All operations are user-scoped for security and data isolation.
 *
 * Integrates with AuthViewModel for consistent authentication state management
 * across the application, ensuring single source of truth for user authentication.
 *
 * Features:
 * - Automatic retry logic with exponential backoff
 * - Batch operations for efficiency
 * - Comprehensive error handling
 * - User-scoped data access
 * - AuthViewModel integration for consistent auth state
 */
@Observable
class FirebaseService: SyncServiceProtocol {
    
    // MARK: - Private Properties
    
    /// Firestore database instance
    private let firestore = Firestore.firestore()
    
    /// AuthViewModel for consistent authentication state management
    private let authViewModel: AuthViewModel
    
    /// Current authentication state listener (kept for Firebase internal consistency)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    
    /// Retry configuration for failed operations
    private let maxRetries = 3
    private let baseRetryDelay: TimeInterval = 1.0
    
    // MARK: - Public Observable Properties
    
    /// Whether Firebase is properly configured and ready for operations
    /// Uses AuthViewModel as the source of truth for authentication state
    var isConfigured: Bool {
        return currentUserId != nil
    }
    
    /// Current authenticated user ID from AuthViewModel
    /// Ensures consistent authentication state across the application
    var currentUserId: String? {
        authViewModel.user?.uid  // Use Firebase User from AuthViewModel
    }
    
    // MARK: - Initialization
    
    /**
     * Initialize FirebaseService with AuthViewModel dependency
     *
     * - Parameter authViewModel: The app's authentication view model for consistent auth state
     *
     * This ensures FirebaseService uses the same authentication state as the rest of the app,
     * preventing inconsistencies between different authentication sources.
     */
    init(authViewModel: AuthViewModel) {
        self.authViewModel = authViewModel
        configureFirestore()
        setupAuthStateListener()
    }
    
    /**
     * Initialize Firebase connection and verify authentication through AuthViewModel
     *
     * - Throws: SyncError if Firebase is not configured or user not authenticated via AuthViewModel
     *
     * Validates that the user is authenticated through our AuthViewModel before allowing
     * any sync operations to proceed.
     */
    func initialize() async throws {
        guard authViewModel.isAuthenticated, let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        // Test Firestore connectivity using the authenticated user
        do {
            _ = try await firestore.collection("users").document("test").getDocument()
            Logger.log("Firebase service initialized successfully for user: \(userId)", level: .info)
        } catch {
            Logger.log("Firebase initialization failed: \(error)", level: .error)
            throw SyncError.firebaseNotConfigured
        }
    }
    
    // MARK: - Private Setup Methods
    
    /**
     * Configures Firestore settings for optimal performance
     * Uses modern cache settings API for iOS 17+ compatibility
     */
    private func configureFirestore() {
        let settings = FirestoreSettings()
        
        // Use modern cache settings for iOS 15+
        if #available(iOS 15.0, *) {
            let cacheSettings = PersistentCacheSettings(sizeBytes: NSNumber(value: FirestoreCacheSizeUnlimited))
            settings.cacheSettings = cacheSettings
        }
        
        firestore.settings = settings
        Logger.log("Firestore configured with cache settings", level: .debug)
    }
    
    /**
     * Sets up Firebase authentication state monitoring
     *
     * This listener provides additional validation that Firebase Auth state
     * remains consistent with our AuthViewModel. While AuthViewModel is the
     * primary source of truth, this ensures Firebase internal state alignment.
     */
    private func setupAuthStateListener() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                // Log any discrepancies between Firebase Auth and AuthViewModel
                let firebaseUserId = user?.uid
                let authViewModelUserId = self?.authViewModel.user?.uid
                
                if firebaseUserId != authViewModelUserId {
                    Logger.log("Auth state mismatch - Firebase: \(firebaseUserId ?? "nil"), AuthViewModel: \(authViewModelUserId ?? "nil")", level: .warning)
                }
                
                if let userId = firebaseUserId {
                    Logger.log("Firebase auth state updated for user: \(userId)", level: .debug)
                } else {
                    Logger.log("Firebase user signed out", level: .debug)
                }
            }
        }
    }
    
    // MARK: - SyncServiceProtocol Implementation

    
    
    func upsertDocument(
        collection: String,
        documentId: String,
        data: [String: Any]
    ) async throws {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        let documentRef = userScopedDocument(userId: userId, collection: collection, documentId: documentId)
        
        do {
            // Convert Date objects to Firestore Timestamps before storing
            let processedData = convertDatesToFirestoreTimestamps(data)
            
            try await performWithRetry {
                try await documentRef.setData(processedData, merge: true)
            }
            
            Logger.log("Document upserted: \(collection)/\(documentId) for user: \(userId)", level: .debug)
        } catch {
            Logger.log("Failed to upsert document \(collection)/\(documentId): \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
    }



    /**
     * Creates or updates a document in Firestore
     *
     * - Parameters:
     *   - collection: Collection name under user's document
     *   - documentId: Unique document identifier
     *   - data: Codable object to store
     *
     * All documents are automatically scoped under users/{userId}/{collection}
     * where userId comes from the injected AuthViewModel for consistency.
     */
    func upsertDocument<T: Codable>(
        collection: String,
        documentId: String,
        data: T
    ) async throws {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        let documentRef = userScopedDocument(userId: userId, collection: collection, documentId: documentId)
        
        do {
            let encodedData = try encodeToFirestoreData(data)
            try await performWithRetry {
                try await documentRef.setData(encodedData, merge: true)
            }
            
            Logger.log("Document upserted: \(collection)/\(documentId) for user: \(userId)", level: .debug)
        } catch {
            Logger.log("Failed to upsert document \(collection)/\(documentId): \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
    }
    
    /**
     * Retrieves a specific document from Firestore
     *
     * - Parameters:
     *   - collection: Collection name under user's document
     *   - documentId: Document identifier to retrieve
     *   - type: Expected Codable type for decoding
     *
     * - Returns: Decoded object or nil if document doesn't exist
     *
     * Uses AuthViewModel's current user to ensure proper data scoping.
     */
    func getDocument<T: Codable>(
        collection: String,
        documentId: String,
        type: T.Type
    ) async throws -> T? {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        let documentRef = userScopedDocument(userId: userId, collection: collection, documentId: documentId)
        
        do {
            let document = try await performWithRetry {
                try await documentRef.getDocument()
            }
            
            guard document.exists, let data = document.data() else {
                return nil
            }
            
            return try decodeFromFirestoreData(data, to: type)
        } catch {
            Logger.log("Failed to get document \(collection)/\(documentId): \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
    }
    
    /**
     * Retrieves documents modified since a specific timestamp
     *
     * - Parameters:
     *   - collection: Collection to query
     *   - since: Timestamp to filter changes after
     *   - type: Expected Codable type for decoding
     *
     * - Returns: Dictionary mapping document IDs to decoded objects
     *
     * Queries are automatically scoped to the current user from AuthViewModel.
     */
    func getChangedDocuments<T: Codable>(
        collection: String,
        since: Date,
        type: T.Type
    ) async throws -> [String: T] {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        let collectionRef = userScopedCollection(userId: userId, collection: collection)
        
        do {
            let query = collectionRef.whereField("updatedAt", isGreaterThan: Timestamp(date: since))
            let snapshot = try await performWithRetry {
                try await query.getDocuments()
            }
            
            var results: [String: T] = [:]
            
            for document in snapshot.documents {
                do {
                    let decodedObject = try decodeFromFirestoreData(document.data(), to: type)
                    results[document.documentID] = decodedObject
                } catch {
                    Logger.log("Failed to decode document \(document.documentID): \(error)", level: .warning)
                    // Continue processing other documents
                }
            }
            
            Logger.log("Retrieved \(results.count) changed documents from \(collection) for user: \(userId)", level: .debug)
            return results
        } catch {
            Logger.log("Failed to get changed documents from \(collection): \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
    }
    
    /**
     * Deletes a document from Firestore
     *
     * - Parameters:
     *   - collection: Collection name under user's document
     *   - documentId: Document identifier to delete
     *
     * Uses AuthViewModel's current user to ensure proper data scoping.
     */
    func deleteDocument(
        collection: String,
        documentId: String
    ) async throws {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        let documentRef = userScopedDocument(userId: userId, collection: collection, documentId: documentId)
        
        do {
            try await performWithRetry {
                try await documentRef.delete()
            }
            
            Logger.log("Document deleted: \(collection)/\(documentId) for user: \(userId)", level: .debug)
        } catch {
            Logger.log("Failed to delete document \(collection)/\(documentId): \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
    }
    
    /**
     * Executes multiple operations as an atomic Firestore transaction
     *
     * - Parameter operations: Array of FirestoreBatchOperation to execute atomically
     *
     * All operations succeed or fail together, ensuring data consistency.
     * Uses AuthViewModel's current user for proper data scoping.
     */
    func executeTransaction(operations: [FirestoreBatchOperation]) async throws {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        do {
            _ = try await firestore.runTransaction { transaction, errorPointer in
                for operation in operations {
                    let documentRef = self.userScopedDocument(
                        userId: userId,
                        collection: operation.collection,
                        documentId: operation.documentId
                    )
                    
                    switch operation.type {
                    case .create, .update:
                        if let data = operation.data {
                            transaction.setData(data, forDocument: documentRef, merge: true)
                        }
                    case .delete:
                        transaction.deleteDocument(documentRef)
                    }
                }
                return nil
            }
            
            Logger.log("Transaction completed with \(operations.count) operations for user: \(userId)", level: .debug)
        } catch {
            Logger.log("Transaction failed: \(error)", level: .error)
            throw SyncError.firestoreError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    /**
     * Creates a user-scoped document reference
     * Format: users/{userId}/{collection}/{documentId}
     *
     * This ensures all data is isolated per user for security and privacy.
     * Uses the userId from AuthViewModel for consistency.
     */
    private func userScopedDocument(userId: String, collection: String, documentId: String) -> DocumentReference {
        return firestore.collection("users").document(userId).collection(collection).document(documentId)
    }
    
    /**
     * Creates a user-scoped collection reference
     * Format: users/{userId}/{collection}
     *
     * This ensures queries are automatically scoped to the current user's data
     * as determined by AuthViewModel.
     */
    private func userScopedCollection(userId: String, collection: String) -> CollectionReference {
        return firestore.collection("users").document(userId).collection(collection)
    }
    
    /**
     * Encodes a Codable object to Firestore-compatible dictionary
     *
     * - Parameter object: Any Codable object to encode
     * - Returns: Dictionary suitable for Firestore storage
     * - Throws: SyncError.dataCorruption if encoding fails
     */
    private func encodeToFirestoreData<T: Codable>(_ object: T) throws -> [String: Any] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970  // Use timestamp format
        
        let jsonData = try encoder.encode(object)
        let jsonObject = try JSONSerialization.jsonObject(with: jsonData)
        
        guard var dictionary = jsonObject as? [String: Any] else {
            throw SyncError.dataCorruption("Failed to convert to dictionary")
        }
        
        // Convert numeric timestamps to proper Firestore Timestamps
        dictionary = convertDatesToFirestoreTimestamps(dictionary)
        
        return dictionary
    }

    private func convertDatesToFirestoreTimestamps(_ data: [String: Any]) -> [String: Any] {
        var result = data
        
        // Convert known date fields to Firestore Timestamps
        let dateFields = ["createdAt", "updatedAt", "lastSyncAt", "date", "startDate", "endDate"]
        
        for field in dateFields {
            if let timestamp = data[field] as? Double {
                // Convert from seconds since 1970 to Firestore Timestamp
                let date = Date(timeIntervalSince1970: timestamp)
                result[field] = Timestamp(date: date)
            } else if let date = data[field] as? Date {
                // Convert Date objects directly to Firestore Timestamp
                result[field] = Timestamp(date: date)
            }
        }
        
        return result
    }

    /**
     * Decodes Firestore data to a Codable object
     *
     * - Parameters:
     *   - data: Firestore document data dictionary
     *   - type: Target Codable type to decode to
     * - Returns: Decoded object of the specified type
     * - Throws: DecodingError or SyncError if decoding fails
     */
    private func decodeFromFirestoreData<T: Codable>(_ data: [String: Any], to type: T.Type) throws -> T {
        // Convert Firestore Timestamps to ISO8601 strings for JSON serialization
        var processedData = data
        
        // Convert known timestamp fields back to ISO8601 strings
        let dateFields = ["createdAt", "updatedAt", "lastSyncAt", "date", "startDate", "endDate"]
        
        for field in dateFields {
            if let timestamp = data[field] as? Timestamp {
                // Convert Firestore Timestamp to ISO8601 string
                let date = timestamp.dateValue()
                processedData[field] = ISO8601DateFormatter().string(from: date)
            }
        }
        
        // Convert any remaining Timestamp objects to ISO8601 strings
        processedData = convertAnyTimestampsToStrings(processedData)
        
        let jsonData = try JSONSerialization.data(withJSONObject: processedData)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(type, from: jsonData)
    }
    
    /**
     * Recursively converts any Firestore Timestamps in a dictionary to ISO8601 strings
     */
    private func convertAnyTimestampsToStrings(_ data: [String: Any]) -> [String: Any] {
        var result = data
        
        for (key, value) in data {
            if let timestamp = value as? Timestamp {
                // Convert Firestore Timestamp to ISO8601 string
                let date = timestamp.dateValue()
                result[key] = ISO8601DateFormatter().string(from: date)
            } else if let dict = value as? [String: Any] {
                // Recursively process nested dictionaries
                result[key] = convertAnyTimestampsToStrings(dict)
            } else if let array = value as? [Any] {
                // Process arrays
                result[key] = array.map { element -> Any in
                    if let dict = element as? [String: Any] {
                        return convertAnyTimestampsToStrings(dict)
                    } else if let timestamp = element as? Timestamp {
                        let date = timestamp.dateValue()
                        return ISO8601DateFormatter().string(from: date)
                    }
                    return element
                }
            }
        }
        
        return result
    }

    /**
     * Performs an operation with exponential backoff retry logic
     *
     * - Parameter operation: Async operation to retry on failure
     * - Returns: Result of the operation if successful
     * - Throws: Last encountered error if all retries fail
     *
     * Retry delays: 1s, 2s, 4s for robust network error handling.
     */
    private func performWithRetry<T>(operation: @Sendable () async throws -> T) async throws -> T {
        var lastError: Error?
        
        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                
                if attempt < maxRetries - 1 {
                    let delay = baseRetryDelay * pow(2.0, Double(attempt))
                    Logger.log("Retry attempt \(attempt + 1) after \(delay)s delay", level: .debug)
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }
        
        throw lastError ?? SyncError.firestoreError(NSError(domain: "RetryFailed", code: -1))
    }
    
    // MARK: - Cleanup
    
    /**
     * Cleanup method called when service is deallocated
     * Ensures proper cleanup of Firebase listeners and resources
     */
    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        Logger.log("FirebaseService deallocated", level: .debug)
    }

    
    
    
    
    
    /**
     * Deletes all user data from Firestore (categories, expenses, budgets, income, recurringExpenses)
     * WARNING: This is destructive and cannot be undone!
     */
    func deleteAllUserData() async throws {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        Logger.log("🗑️ Starting deletion of all user data for user: \(userId)", level: .warning)

        let collections = ["categories", "expenses", "budgets", "incomes", "recurringExpenses", "recurringIncomes"]
        var totalDeleted = 0
        
        for collectionName in collections {
            do {
                let collectionRef = userScopedCollection(userId: userId, collection: collectionName)
                
                // Get all documents in the collection
                let snapshot = try await performWithRetry {
                    try await collectionRef.getDocuments()
                }
                
                Logger.log("🗑️ Found \(snapshot.documents.count) documents in \(collectionName)", level: .info)
                
                // Delete documents in batches of 10 (Firestore batch limit is 500, but we'll be conservative)
                let batchSize = 10
                let documents = snapshot.documents
                
                for i in stride(from: 0, to: documents.count, by: batchSize) {
                    let endIndex = min(i + batchSize, documents.count)
                    let batch = Array(documents[i..<endIndex])
                    
                    // Create batch operations
                    let operations = batch.map { document in
                        FirestoreBatchOperation(
                            type: .delete,
                            collection: collectionName,
                            documentId: document.documentID
                        )
                    }
                    
                    // Execute batch deletion
                    try await executeTransaction(operations: operations)
                    totalDeleted += batch.count
                    
                    Logger.log("🗑️ Deleted batch of \(batch.count) documents from \(collectionName)", level: .debug)
                    
                    // Small delay to avoid rate limiting
                    if endIndex < documents.count {
                        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                    }
                }
                
                Logger.log("✅ Completed deletion of \(snapshot.documents.count) documents from \(collectionName)", level: .info)
                
            } catch {
                Logger.log("❌ Failed to delete documents from \(collectionName): \(error)", level: .error)
                throw SyncError.firestoreError(error)
            }
        }
        
        Logger.log("🗑️ Successfully deleted \(totalDeleted) documents total from Firestore for user: \(userId)", level: .warning)
    }

    /**
     * Deletes all documents from a specific collection for the current user
     */
    func deleteAllDocumentsFromCollection(_ collectionName: String) async throws {
        guard let userId = currentUserId else {
            throw SyncError.userNotAuthenticated
        }
        
        Logger.log("🗑️ Deleting all documents from \(collectionName) for user: \(userId)", level: .warning)
        
        let collectionRef = userScopedCollection(userId: userId, collection: collectionName)
        
        // Get all documents in the collection
        let snapshot = try await performWithRetry {
            try await collectionRef.getDocuments()
        }
        
        Logger.log("🗑️ Found \(snapshot.documents.count) documents in \(collectionName)", level: .info)
        
        // Delete documents in batches
        let batchSize = 10
        let documents = snapshot.documents
        
        for i in stride(from: 0, to: documents.count, by: batchSize) {
            let endIndex = min(i + batchSize, documents.count)
            let batch = Array(documents[i..<endIndex])
            
            // Create batch operations
            let operations = batch.map { document in
                FirestoreBatchOperation(
                    type: .delete,
                    collection: collectionName,
                    documentId: document.documentID
                )
            }
            
            // Execute batch deletion
            try await executeTransaction(operations: operations)
            
            Logger.log("🗑️ Deleted batch of \(batch.count) documents from \(collectionName)", level: .debug)
            
            // Small delay to avoid rate limiting
            if endIndex < documents.count {
                try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
        }
        
        Logger.log("✅ Completed deletion of \(snapshot.documents.count) documents from \(collectionName)", level: .info)
    }
    
    
    
}
