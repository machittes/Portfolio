// StudentExpenseTracker/Core/Data/Sync/Services/BackgroundSyncManager.swift
import Foundation
import BackgroundTasks

class BackgroundSyncManager {
    static let shared = BackgroundSyncManager()
    private let syncManager: SyncManager
    
    private init() {
        // This will be injected from the main app
        self.syncManager = SyncManager(authViewModel: AuthViewModel())
    }
    
    func configure(with syncManager: SyncManager) {
        // Update reference when app initializes
    }
    
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: "com.group10.StudentExpenseTracker.sync",
            using: nil
        ) { task in
            self.handleBackgroundSync(task: task as! BGAppRefreshTask)
        }
    }
    
    func scheduleBackgroundSync() {
        let request = BGAppRefreshTaskRequest(identifier: "com.group10.StudentExpenseTracker.sync")
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60) // 15 minutes
        
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Logger.log("Failed to schedule background sync: \(error)", level: .error)
        }
    }
    
    private func handleBackgroundSync(task: BGAppRefreshTask) {
        task.expirationHandler = {
            task.setTaskCompleted(success: false)
        }
        
        Task {
            await syncManager.performFullSync()
            task.setTaskCompleted(success: true)
            
            // Schedule next background sync
            scheduleBackgroundSync()
        }
    }
}
