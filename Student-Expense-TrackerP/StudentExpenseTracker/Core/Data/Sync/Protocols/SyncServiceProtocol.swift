// StudentExpenseTracker/Core/Data/Sync/Protocols/SyncServiceProtocol.swift
import Foundation

/**
 * Protocol defining the contract for sync services
 *
 * This protocol abstracts sync operations to enable:
 * - Unit testing with mock implementations
 * - Potential future migration to different backend services
 * - Clean separation of concerns
 */
protocol SyncServiceProtocol {
    /// Initialize connection and authenticate user
    func initialize() async throws
    
    /// Check if service is properly configured and ready
    var isConfigured: Bool { get }
    
    /// Current authenticated user ID
    var currentUserId: String? { get }
    
    // MARK: - Generic CRUD Operations
    
    /// Create or update a document in the specified collection
    func upsertDocument<T: Codable>(
        collection: String,
        documentId: String,
        data: T
    ) async throws
    
    /// Retrieve a specific document from a collection
    func getDocument<T: Codable>(
        collection: String,
        documentId: String,
        type: T.Type
    ) async throws -> T?
    
    /// Retrieve documents modified after a specific timestamp
    func getChangedDocuments<T: Codable>(
        collection: String,
        since: Date,
        type: T.Type
    ) async throws -> [String: T]
    
    /// Delete a document from a collection
    func deleteDocument(
        collection: String,
        documentId: String
    ) async throws
    
    /// Execute multiple operations as an atomic transaction
    func executeTransaction(
        operations: [FirestoreBatchOperation]
    ) async throws
}

/**
 * Represents a single Firestore operation for batch/transaction processing
 *
 * Used to group multiple database operations into atomic transactions
 * for consistency and performance optimization.
 */
struct FirestoreBatchOperation {
    enum OperationType {
        case create
        case update
        case delete
    }
    
    let type: OperationType
    let collection: String
    let documentId: String
    let data: [String: Any]?
    
    init(type: OperationType, collection: String, documentId: String, data: [String: Any]? = nil) {
        self.type = type
        self.collection = collection
        self.documentId = documentId
        self.data = data
    }
}
