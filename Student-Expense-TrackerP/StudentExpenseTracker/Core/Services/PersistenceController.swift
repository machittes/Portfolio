//
//  PersistenceController.swift
//  StudentExpenseTracker
//
//  Created by George Potakis on 2025-05-25.
//

import Foundation
import CoreData
import SwiftUI
import os.log

// MARK: - Logging System
enum LogLevel {
    case debug, info, warning, error
}

struct Logger {
    private static let subsystem = "com.group10.StudentExpenseTracker"
    private static let category = "CoreData"
    
    static func log(_ message: String, level: LogLevel = .info, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        let fileName = (file as NSString).lastPathComponent
        let emoji = logEmoji(for: level)
        print("\(emoji) [\(fileName):\(line)] \(function) - \(message)")
        #endif
        
        // For production, use os.log for proper logging
        let logger = os.Logger(subsystem: subsystem, category: category)
        switch level {
        case .debug:
            logger.debug("\(message, privacy: .public)")
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warning:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }
    
    private static func logEmoji(for level: LogLevel) -> String {
        switch level {
        case .debug: return "🔍"
        case .info: return "ℹ️"
        case .warning: return "⚠️"
        case .error: return "❌"
        }
    }
}

// MARK: - Core Data Errors
enum CoreDataError: LocalizedError {
    case storeLoadingFailed(Error)
    case saveFailed(Error)
    case contextCreationFailed
    case migrationFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .storeLoadingFailed(let error):
            return "Failed to load data store: \(error.localizedDescription)"
        case .saveFailed(let error):
            return "Failed to save data: \(error.localizedDescription)"
        case .contextCreationFailed:
            return "Failed to create data context"
        case .migrationFailed(let error):
            return "Data migration failed: \(error.localizedDescription)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .storeLoadingFailed:
            return "Try restarting the app. If the problem persists, contact support."
        case .saveFailed:
            return "Your changes could not be saved. Please try again."
        case .contextCreationFailed:
            return "Unable to access data. Please restart the app."
        case .migrationFailed:
            return "Data update failed. The app may need to be reinstalled."
        }
    }
}

@Observable
class PersistenceController {
    // Shared instance for the app
    static let shared = PersistenceController()
    
    // Storage for Core Data
    let container: NSPersistentContainer
    
    // Error handling
    var lastError: CoreDataError?
    var isStoreLoaded = false
    var isInitializing = true
    
    // Convenience access to the viewContext
    var viewContext: NSManagedObjectContext {
        return container.viewContext
    }
    
    // Initialize with an optional in-memory store
    init(inMemory: Bool = false) {
        // Create the Core Data stack
        container = NSPersistentContainer(name: "StudentExpenseTracker")
        
        // When true, creates a temporary store (useful for testing/previews)
        if inMemory {
            container.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        }
        
        // Configure store descriptions for better error handling
        if let storeDescription = container.persistentStoreDescriptions.first {
            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true
            
            // Add more timeout for network stores if using CloudKit
            storeDescription.timeout = 30
        }

        // Load data model and prepare the persistent store with proper error handling
        loadPersistentStores()
        
        // Configure viewContext
        setupViewContext()
    }
    
    // MARK: - Store Loading with Proper Error Handling
    
    private func loadPersistentStores() {
        container.loadPersistentStores { [weak self] (storeDescription, error) in
            DispatchQueue.main.async {
                self?.isInitializing = false
                
                if let error = error {
                    // Handle different types of Core Data errors gracefully
                    self?.handleStoreLoadingError(error, storeDescription: storeDescription)
                } else {
                    self?.isStoreLoaded = true
                    self?.lastError = nil
                    Logger.log("Core Data store loaded successfully: \(storeDescription.url?.lastPathComponent ?? "Unknown")", level: .info)
                }
            }
        }
    }
    
    private func handleStoreLoadingError(_ error: Error, storeDescription: NSPersistentStoreDescription) {
        Logger.log("Core Data store loading failed: \(error)", level: .error)
        
        let coreDataError = CoreDataError.storeLoadingFailed(error)
        lastError = coreDataError
        
        // Attempt recovery strategies
        attemptStoreRecovery(error: error, storeDescription: storeDescription)
    }
    
    private func attemptStoreRecovery(error: Error, storeDescription: NSPersistentStoreDescription) {
        let nsError = error as NSError
        
        // Strategy 1: Migration issues - try to rebuild
        if nsError.code == NSPersistentStoreIncompatibleVersionHashError ||
           nsError.code == NSMigrationMissingSourceModelError {
            Logger.log("Attempting to recover from migration error...", level: .warning)
            recreateStore(storeDescription: storeDescription)
            return
        }
        
        // Strategy 2: Corrupted store - try to rebuild
        if nsError.code == NSSQLiteError {
            Logger.log("Attempting to recover from corrupted store...", level: .warning)
            recreateStore(storeDescription: storeDescription)
            return
        }
        
        // Strategy 3: Disk space issues
        if nsError.code == NSFileWriteFileExistsError || 
           nsError.code == NSFileWriteNoPermissionError {
            Logger.log("Disk space or permission issue detected", level: .warning)
            // Could implement cache cleanup here
        }
        
        // If all recovery attempts fail, we'll work with in-memory store
        Logger.log("Using in-memory fallback store", level: .warning)
        createFallbackInMemoryStore()
    }
    
    private func recreateStore(storeDescription: NSPersistentStoreDescription) {
        guard let storeURL = storeDescription.url else { return }
        
        do {
            // Remove the corrupted store file
            try FileManager.default.removeItem(at: storeURL)
            Logger.log("Removed corrupted store file", level: .info)
            
            // Try loading again
            loadPersistentStores()
        } catch {
            Logger.log("Failed to remove corrupted store: \(error)", level: .error)
            createFallbackInMemoryStore()
        }
    }
    
    private func createFallbackInMemoryStore() {
        // Create an in-memory store as fallback
        let fallbackDescription = NSPersistentStoreDescription()
        fallbackDescription.type = NSInMemoryStoreType
        
        container.persistentStoreDescriptions = [fallbackDescription]
        
        container.loadPersistentStores { [weak self] (_, error) in
            DispatchQueue.main.async {
                if let error = error {
                    Logger.log("Even fallback store failed: \(error)", level: .error)
                    // At this point, we have a serious problem
                    self?.lastError = CoreDataError.storeLoadingFailed(error)
                } else {
                    Logger.log("Fallback in-memory store created successfully", level: .info)
                    self?.isStoreLoaded = true
                    // Note: Data will not persist, but app won't crash
                }
            }
        }
    }
    
    private func setupViewContext() {
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
        
        // Add undo manager for better UX
        container.viewContext.undoManager = UndoManager()
        
        // Configure for better performance
        container.viewContext.shouldDeleteInaccessibleFaults = true
    }
    
    // MARK: - Safe Save with Result Type
    
    func save() -> Result<Void, CoreDataError> {
        let context = container.viewContext
        Logger.log("Saving context: \(context)", level: .debug)
        Logger.log("Context has changes: \(context.hasChanges)", level: .debug)
        
        guard context.hasChanges else {
            Logger.log("No changes to save", level: .debug)
            return .success(())
        }
        
        do {
            try context.save()
            Logger.log("Context saved successfully", level: .debug)
            return .success(())
        } catch {
            let nsError = error as NSError
            Logger.log("Save error: \(nsError), \(nsError.userInfo)", level: .error)
            
            let coreDataError = CoreDataError.saveFailed(error)
            lastError = coreDataError
            
            // Attempt to recover from save errors
            return attemptSaveRecovery(context: context, originalError: error)
        }
    }
    
    private func attemptSaveRecovery(context: NSManagedObjectContext, originalError: Error) -> Result<Void, CoreDataError> {
        
        
        //return .success(())
        
        let nsError = originalError as NSError
        
        // Strategy 1: Merge conflicts - try to refresh and save again
        if nsError.code == NSManagedObjectMergeError {
            Logger.log("Attempting to resolve merge conflicts...", level: .warning)
            context.refreshAllObjects()
            
            do {
                try context.save()
                Logger.log("Save successful after conflict resolution", level: .info)
                return .success(())
            } catch {
                Logger.log("Save failed even after conflict resolution", level: .error)
                return .failure(CoreDataError.saveFailed(error))
            }
        }
        
        // Strategy 2: Validation errors - rollback changes
        if nsError.code == NSValidationMissingMandatoryPropertyError ||
           nsError.code == NSValidationRelationshipLacksMinimumCountError {
            Logger.log("Rolling back invalid changes...", level: .warning)
            context.rollback()
            return .failure(CoreDataError.saveFailed(originalError))
        }
        
        // Strategy 3: Disk full - try to clean up space
        if nsError.code == NSFileWriteOutOfSpaceError {
            Logger.log("Disk space issue - attempting cleanup...", level: .warning)
            // Could implement cache cleanup here
        }
        
        return .failure(CoreDataError.saveFailed(originalError))
    }
    
    // MARK: - Async Save Methods
    
    @MainActor
    func saveAsync() async throws {
        let result = save()
        switch result {
        case .success:
            break
        case .failure(let error):
            throw error
        }
    }
    
    func saveInBackground() async -> Result<Void, CoreDataError> {
        return await withCheckedContinuation { continuation in
            container.performBackgroundTask { context in
                do {
                    try context.save()
                    continuation.resume(returning: .success(()))
                } catch {
                    let coreDataError = CoreDataError.saveFailed(error)
                    continuation.resume(returning: .failure(coreDataError))
                }
            }
        }
    }
    
    // MARK: - Preview Support
    
    // Preview instance with sample data
    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        
        // Wait for store to load before creating sample data
        if controller.isStoreLoaded {
            let viewContext = controller.container.viewContext
            _ = createSampleData(in: viewContext)
        }
        
        return controller
    }()
    
    // Create sample data for previews
    @discardableResult
    static func createSampleData(in context: NSManagedObjectContext) -> Result<Void, CoreDataError> {
        // Sample User
        let user = AppUser(context: context)
        user.userId = "sample-user-id"
        user.email = "student@example.com"
        user.name = "Sample Student"
        //user.prefersDarkMode = false
        user.defaultCurrency = "USD"
        user.notificationsEnabled = true
        user.createdAt = Date()
        user.updatedAt = Date()
        user.syncStatus = "synced"
        
        // Sample Categories
        let foodCategory = Category(context: context)
        foodCategory.id = UUID()
        foodCategory.name = "Food"
        foodCategory.icon = "fork.knife"
        foodCategory.color = "red"
        foodCategory.isDefault = true
        foodCategory.order = 0
        foodCategory.createdAt = Date()
        foodCategory.updatedAt = Date()
        foodCategory.syncStatus = "synced"
        foodCategory.user = user
        
        let transportCategory = Category(context: context)
        transportCategory.id = UUID()
        transportCategory.name = "Transportation"
        transportCategory.icon = "car.fill"
        transportCategory.color = "blue"
        transportCategory.isDefault = true
        transportCategory.order = 1
        transportCategory.createdAt = Date()
        transportCategory.updatedAt = Date()
        transportCategory.syncStatus = "synced"
        transportCategory.user = user
        
        // Sample Expenses
        let expense1 = Expense(context: context)
        expense1.id = UUID()
        expense1.amount = 15.50
        expense1.date = Date().addingTimeInterval(-86400) // Yesterday
        expense1.notes = "Lunch at campus cafe"
        expense1.isRecurring = false
        expense1.category = foodCategory
        expense1.user = user
        expense1.createdAt = Date()
        expense1.updatedAt = Date()
        expense1.syncStatus = "synced"
        
        let expense2 = Expense(context: context)
        expense2.id = UUID()
        expense2.amount = 25.00
        expense2.date = Date().addingTimeInterval(-172800) // 2 days ago
        expense2.notes = "Uber to downtown"
        expense2.isRecurring = false
        expense2.category = transportCategory
        expense2.user = user
        expense2.createdAt = Date()
        expense2.updatedAt = Date()
        expense2.syncStatus = "synced"
        
        // Sample Budget
        let budget = Budget(context: context)
        budget.id = UUID()
        budget.amount = 500.00
        budget.period = "monthly"
        budget.startDate = Date().startOfMonth()
        budget.endDate = Date().endOfMonth() // Added this line for the non-optional endDate
        budget.alertThreshold = 0.8
        budget.isActive = true
        budget.category = foodCategory
        budget.user = user
        budget.createdAt = Date()
        budget.updatedAt = Date()
        budget.syncStatus = "synced"
        
        // Save the context with proper error handling
        do {
            try context.save()
            Logger.log("Sample data created successfully", level: .info)
            return .success(())
        } catch {
            let nsError = error as NSError
            Logger.log("Failed to create sample data: \(nsError), \(nsError.userInfo)", level: .error)
            
            // Rollback the changes instead of crashing
            context.rollback()
            return .failure(CoreDataError.saveFailed(error))
        }
    }
    
    // MARK: - Health Check Methods
    
    var isHealthy: Bool {
        return isStoreLoaded && lastError == nil
    }
    
    func performHealthCheck() -> Result<String, CoreDataError> {
        guard isStoreLoaded else {
            return .failure(CoreDataError.storeLoadingFailed(NSError(domain: "PersistenceController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Store not loaded"])))
        }
        
        // Test basic operations
        let testContext = container.newBackgroundContext()
        let testRequest: NSFetchRequest<AppUser> = AppUser.fetchRequest()
        testRequest.fetchLimit = 1
        
        do {
            _ = try testContext.fetch(testRequest)
            return .success("Core Data is functioning normally")
        } catch {
            return .failure(CoreDataError.contextCreationFailed)
        }
    }
}

// MARK: - Helper Extensions

extension Date {
    func startOfMonth() -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: self)
        return calendar.date(from: components) ?? self
    }
}

extension Date {
    func endOfMonth() -> Date {
        let calendar = Calendar.current
        let components = DateComponents(month: 1, day: -1)
        return calendar.date(byAdding: components, to: startOfMonth()) ?? self
    }
}
