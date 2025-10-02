// StudentExpenseTracker/Core/Data/Sync/Models/SyncStatus.swift
import Foundation

enum SyncOperation {
    case create
    case update
    case delete
}

enum SyncState: String, CaseIterable {
    case created = "created"
    case updated = "updated"
    case deleted = "deleted"
    case synced = "synced"
    case syncing = "syncing"
    case conflict = "conflict"
    case failed = "failed"
}

struct SyncMetadata {
    let lastSyncAt: Date
    let deviceId: String
    let version: Int
    let checksum: String?
    
    init(lastSyncAt: Date = Date(), deviceId: String = Self.generateDeviceId(), version: Int = 1, checksum: String? = nil) {
        self.lastSyncAt = lastSyncAt
        self.deviceId = deviceId
        self.version = version
        self.checksum = checksum
    }
    
    private static func generateDeviceId() -> String {
        // Use a more appropriate approach for sync context
        if let existingId = UserDefaults.standard.string(forKey: "SyncDeviceId") {
            return existingId
        }
        
        let newId = UUID().uuidString
        UserDefaults.standard.set(newId, forKey: "SyncDeviceId")
        return newId
    }
}

@Observable
class SyncStatusTracker {
    var isOnline = false
    var isSyncing = false
    var lastSyncAt: Date?
    var pendingOperations = 0
    var lastError: SyncError?
    var syncProgress: Double = 0.0
    
    // Collection-specific status
    var categoriesLastSync: Date?
    var expensesLastSync: Date?
    var budgetsLastSync: Date?
    var incomeLastSync: Date?
    var recurringExpensesLastSync: Date?
    var recurringIncomesLastSync: Date?
    
    func updateSyncProgress(_ progress: Double) {
        Task { @MainActor in
            self.syncProgress = progress
        }
    }
    
    func recordSuccessfulSync(for collection: String) {
        Task { @MainActor in
            let now = Date()
            self.lastSyncAt = now
            
            switch collection {
            case "categories": self.categoriesLastSync = now
            case "expenses": self.expensesLastSync = now
            case "budgets": self.budgetsLastSync = now
            case "income": self.incomeLastSync = now
            case "recurringExpenses": self.recurringExpensesLastSync = now
            case "recurringIncomes": self.recurringIncomesLastSync = now
            default: break
            }
        }
    }
    
    func recordError(_ error: SyncError) {
        Task { @MainActor in
            self.lastError = error
            self.isSyncing = false
        }
    }
}
