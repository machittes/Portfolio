// StudentExpenseTracker/Core/Data/Sync/Services/SyncManager+Upload.swift
import Foundation
import CoreData

extension SyncManager {
    
    // MARK: - Private Debug Logging
    
    /**
     * Local debug logging method for upload operations
     */
    private func uploadDebugLog(_ message: String) {
        guard debugLoggingEnabled else { return }
        print("📤 SyncManager+Upload: \(message)")
        Logger.log("Upload: \(message)", level: .debug)
    }
    
    /**
     * Internal upload implementation with proper error handling and tombstone support
     */
    internal func uploadLocalChangesInternal() async throws {
        let context = persistenceController.viewContext
        
        await updateSyncState(operation: "Scanning local changes...", progress: 0.1)
        
        uploadDebugLog("🔍 Starting upload phase with tombstone support...")
        
        for (index, entityType) in syncOrder.enumerated() {
            let progressBase = 0.1 + (Double(index) / Double(syncOrder.count)) * 0.8
            
            await updateSyncState(
                operation: "Uploading \(entityType.collectionName)...",
                progress: progressBase
            )
            
            try await uploadEntitiesOfType(entityType, context: context)
            
            // Check for cancellation
            if Task.isCancelled {
                throw SyncError.networkUnavailable // Use as cancellation error
            }
        }
        
        await updateSyncState(operation: "Upload completed", progress: 0.9)
        uploadDebugLog("✅ Upload phase completed")
    }
    
    /**
     * Uploads entities of a specific type that need syncing - Enhanced with tombstone support
     */
    internal func uploadEntitiesOfType(_ entityType: any Syncable.Type, context: NSManagedObjectContext) async throws {
        
        // Fetch entities that need syncing (including tombstones)
        let entitiesToSync = await withCheckedContinuation { continuation in
            context.perform {
                let request = NSFetchRequest<NSManagedObject>(entityName: String(describing: entityType).components(separatedBy: ".").last!)
                
                // Include tombstones (softDeleted=true) that need syncing
                request.predicate = NSPredicate(format: "syncStatus IN %@", [
                    SyncState.created.rawValue,
                    SyncState.updated.rawValue,
                    SyncState.deleted.rawValue
                ])
                
                // Sort by priority: deletions first, then updates, then creates
                request.sortDescriptors = [
                    NSSortDescriptor(key: "softDeleted", ascending: false), // Deleted first
                    NSSortDescriptor(key: "syncStatus", ascending: true)
                ]
                
                do {
                    let results = try context.fetch(request)
                    continuation.resume(returning: results.compactMap { $0 as? Syncable })
                } catch {
                    Logger.log("Failed to fetch \(entityType) for upload: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
        
        guard !entitiesToSync.isEmpty else {
            uploadDebugLog("📝 No \(entityType.collectionName) entities to upload")
            Logger.log("No \(entityType.collectionName) entities to upload", level: .debug)
            return
        }
        
        uploadDebugLog("📤 Uploading \(entitiesToSync.count) \(entityType.collectionName) entities")
        Logger.log("Uploading \(entitiesToSync.count) \(entityType.collectionName) entities", level: .debug)
        
        // Separate entities by type for better logging
        var createCount = 0
        var updateCount = 0
        var deleteCount = 0
        var tombstoneCount = 0
        
        for entity in entitiesToSync {
            // Check if this is a soft-deleted entity (tombstone)
            if let softDeleted = entity.value(forKey: "softDeleted") as? Bool, softDeleted {
                tombstoneCount += 1
            } else {
                switch entity.currentSyncStatus {
                case .created:
                    createCount += 1
                case .updated:
                    updateCount += 1
                case .deleted:
                    deleteCount += 1
                default:
                    break
                }
            }
        }
        
        uploadDebugLog("📊 Upload breakdown: \(createCount) creates, \(updateCount) updates, \(deleteCount) hard deletes, \(tombstoneCount) tombstones")
        
        // Upload each entity
        var successCount = 0
        var errorCount = 0
        
        for entity in entitiesToSync {
            do {
                try await uploadSingleEntity(entity)
                
                // Mark as synced on successful upload
                await withCheckedContinuation { continuation in
                    context.perform {
                        entity.markAsSynced()
                        continuation.resume()
                    }
                }
                
                successCount += 1
                uploadDebugLog("✅ Uploaded \(entityType.collectionName) entity \(entity.syncableId)")
                
            } catch {
                Logger.log("Failed to upload \(entityType.collectionName) entity \(entity.syncableId): \(error)", level: .error)
                uploadDebugLog("❌ Failed to upload \(entityType.collectionName) entity \(entity.syncableId): \(error)")
                
                // Mark as failed but continue with other entities
                await withCheckedContinuation { continuation in
                    context.perform {
                        entity.currentSyncStatus = .failed
                        continuation.resume()
                    }
                }
                
                errorCount += 1
            }
        }
        
        uploadDebugLog("📊 Upload summary for \(entityType.collectionName): \(successCount) succeeded, \(errorCount) failed")
        
        // Save context after all uploads
        do {
            try await persistenceController.saveAsync()
            uploadDebugLog("💾 Saved \(entityType.collectionName) upload changes to CoreData")
        } catch {
            uploadDebugLog("❌ Failed to save upload changes: \(error)")
            throw SyncError.conflictResolution("Failed to save upload changes: \(error.localizedDescription)")
        }
    }
    
    /**
     * Uploads a single entity to Firestore - Enhanced with tombstone support
     */
    internal func uploadSingleEntity(_ entity: Syncable) async throws {
        let syncStatus = entity.currentSyncStatus
        let collectionName = type(of: entity).collectionName
        let documentId = entity.syncableId
        
        // Check if this is a tombstone entity (soft-deleted)
        if let softDeleted = entity.value(forKey: "softDeleted") as? Bool, softDeleted {
            uploadDebugLog("⚰️ Uploading tombstone for \(collectionName) \(documentId)")
            try await uploadTombstone(entity)
            return
        }
        
        switch syncStatus {
        case .created:
            uploadDebugLog("🆕 Creating new \(collectionName) document \(documentId)")
            try await uploadEntityData(entity, operation: "create")
            
        case .updated:
            uploadDebugLog("📝 Updating existing \(collectionName) document \(documentId)")
            try await uploadEntityData(entity, operation: "update")
            
        case .deleted:
            uploadDebugLog("🗑️ Hard deleting \(collectionName) document \(documentId)")
            try await uploadHardDeletion(entity)
            
        default:
            uploadDebugLog("⏭️ Skipping \(collectionName) entity \(documentId) (status: \(syncStatus))")
            // Skip entities that don't need syncing
            break
        }
    }
    
    /**
     * Upload entity data (create or update operations)
     */
    private func uploadEntityData(_ entity: Syncable, operation: String) async throws {
        let collectionName = type(of: entity).collectionName
        let documentId = entity.syncableId
        
        do {
            // Convert to Firestore data
            let firestoreData = try entity.toFirestoreData()
            
            uploadDebugLog("📤 \(operation.capitalized) data for \(collectionName) \(documentId):")
            uploadDebugLog("   Keys: \(firestoreData.keys.sorted())")
            if let name = firestoreData["name"] as? String {
                uploadDebugLog("   Name: \(name)")
            }
            if let amount = firestoreData["amount"] as? Double {
                uploadDebugLog("   Amount: \(amount)")
            }
            if let updatedAt = firestoreData["updatedAt"] {
                uploadDebugLog("   UpdatedAt: \(updatedAt)")
            }
            
            // Use the raw dictionary version of upsertDocument
            try await firebaseService.upsertDocument(
                collection: collectionName,
                documentId: documentId,
                data: firestoreData
            )
            
            uploadDebugLog("✅ Successfully uploaded \(operation) for \(collectionName) \(documentId)")
            
        } catch {
            uploadDebugLog("❌ Failed to upload \(operation) for \(collectionName) \(documentId): \(error)")
            throw error
        }
    }
    
    /**
     * Upload tombstone data to Firestore (soft deletion) - Enhanced for all entity types
     */
    private func uploadTombstone(_ entity: Syncable) async throws {
        let collectionName = type(of: entity).collectionName
        let documentId = entity.syncableId
        
        do {
            // Convert tombstone to Firestore data (includes deleted=true, deletedAt, deletedBy)
            let tombstoneData = try entity.toFirestoreData()
            
            uploadDebugLog("⚰️ Uploading tombstone data for \(collectionName) \(documentId):")
            uploadDebugLog("   Deleted: \(tombstoneData["deleted"] as? Bool ?? false)")
            if let deletedAt = tombstoneData["deletedAt"] {
                uploadDebugLog("   DeletedAt: \(deletedAt)")
            }
            if let deletedBy = tombstoneData["deletedBy"] as? String {
                uploadDebugLog("   DeletedBy: \(deletedBy)")
            }
            
            // Log entity-specific tombstone metadata
            switch collectionName {
            case "categories":
                if let deletedName = tombstoneData["deletedName"] as? String {
                    uploadDebugLog("   DeletedName: \(deletedName)")
                }
                if let deletedIcon = tombstoneData["deletedIcon"] as? String {
                    uploadDebugLog("   DeletedIcon: \(deletedIcon)")
                }
                
            case "budgets":
                if let deletedAmount = tombstoneData["deletedAmount"] as? Double {
                    uploadDebugLog("   DeletedAmount: \(deletedAmount)")
                }
                if let deletedPeriod = tombstoneData["deletedPeriod"] as? String {
                    uploadDebugLog("   DeletedPeriod: \(deletedPeriod)")
                }
                if let deletedCategoryId = tombstoneData["deletedCategoryId"] as? String {
                    uploadDebugLog("   DeletedCategoryId: \(deletedCategoryId)")
                }
                
            case "expenses":
                if let deletedAmount = tombstoneData["deletedAmount"] as? Double {
                    uploadDebugLog("   DeletedAmount: \(deletedAmount)")
                }
                if let deletedDate = tombstoneData["deletedDate"] {
                    uploadDebugLog("   DeletedDate: \(deletedDate)")
                }
                if let hadReceipt = tombstoneData["hadReceiptImage"] as? Bool {
                    uploadDebugLog("   HadReceiptImage: \(hadReceipt)")
                }
                
            case "income":
                if let deletedAmount = tombstoneData["deletedAmount"] as? Double {
                    uploadDebugLog("   DeletedAmount: \(deletedAmount)")
                }
                if let deletedSource = tombstoneData["deletedSource"] as? String {
                    uploadDebugLog("   DeletedSource: \(deletedSource)")
                }
                
            case "recurringExpenses":
                if let deletedTitle = tombstoneData["deletedTitle"] as? String {
                    uploadDebugLog("   DeletedTitle: \(deletedTitle)")
                }
                if let deletedAmount = tombstoneData["deletedAmount"] as? Double {
                    uploadDebugLog("   DeletedAmount: \(deletedAmount)")
                }
                if let deletedFrequency = tombstoneData["deletedFrequency"] as? String {
                    uploadDebugLog("   DeletedFrequency: \(deletedFrequency)")
                }
                
            case "recurringIncomes":
                if let deletedSource = tombstoneData["deletedSource"] as? String {
                    uploadDebugLog("   DeletedSource: \(deletedSource)")
                }
                if let deletedAmount = tombstoneData["deletedAmount"] as? Double {
                    uploadDebugLog("   DeletedAmount: \(deletedAmount)")
                }
                if let deletedFrequency = tombstoneData["deletedFrequency"] as? String {
                    uploadDebugLog("   DeletedFrequency: \(deletedFrequency)")
                }
                
            default:
                break
            }
            
            // Upload tombstone data to Firestore
            try await firebaseService.upsertDocument(
                collection: collectionName,
                documentId: documentId,
                data: tombstoneData
            )
            
            uploadDebugLog("✅ Successfully uploaded tombstone for \(collectionName) \(documentId)")
            
        } catch {
            uploadDebugLog("❌ Failed to upload tombstone for \(collectionName) \(documentId): \(error)")
            throw error
        }
    }
    
    /**
     * Upload hard deletion to Firestore (completely remove document)
     */
    private func uploadHardDeletion(_ entity: Syncable) async throws {
        let collectionName = type(of: entity).collectionName
        let documentId = entity.syncableId
        
        do {
            // Delete document from Firestore completely
            try await firebaseService.deleteDocument(
                collection: collectionName,
                documentId: documentId
            )
            
            uploadDebugLog("✅ Successfully hard deleted \(collectionName) \(documentId) from Firestore")
            
        } catch {
            uploadDebugLog("❌ Failed to hard delete \(collectionName) \(documentId): \(error)")
            throw error
        }
    }
    
    // MARK: - Entity-Specific Upload Methods
    
    /**
     * Upload Categories with enhanced tombstone logging
     */
    private func uploadCategories(for user: AppUser, context: NSManagedObjectContext) async throws {
        let categoryRepository = CategoryRepository(persistenceController: persistenceController)
        let pendingCategories = await categoryRepository.fetchPendingSyncCategories(for: user)
        
        uploadDebugLog("📂 Found \(pendingCategories.count) pending category changes")
        
        for category in pendingCategories {
            do {
                // Validate category before sync
                try category.validateCategoryForSync()
                
                let categoryData = try category.toFirestoreData()
                
                if category.softDeleted {
                    // Handle tombstone upload
                    uploadDebugLog("🪦 Uploading category tombstone: \(category.categoryDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Category.collectionName,
                        documentId: category.id?.uuidString ?? "",
                        data: categoryData
                    )
                } else {
                    // Handle regular category upload
                    uploadDebugLog("📂 Uploading category: \(category.categoryDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Category.collectionName,
                        documentId: category.id?.uuidString ?? "",
                        data: categoryData
                    )
                }
                
                // Mark as synced
                await categoryRepository.markCategoryAsSynced(category)
                uploadDebugLog("✅ Category synced successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload category \(category.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Budgets with enhanced tombstone logging
     */
    private func uploadBudgets(for user: AppUser, context: NSManagedObjectContext) async throws {
        let budgetRepository = BudgetRepository(persistenceController: persistenceController)
        let pendingBudgets = await budgetRepository.fetchPendingSyncBudgets(for: user)
        
        uploadDebugLog("📊 Found \(pendingBudgets.count) pending budget changes")
        
        for budget in pendingBudgets {
            do {
                // Validate budget before sync
                try budget.validateBudgetForSync()
                
                let budgetData = try budget.toFirestoreData()
                
                if budget.softDeleted {
                    // Handle tombstone upload
                    uploadDebugLog("🪦 Uploading budget tombstone: \(budget.budgetDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Budget.collectionName,
                        documentId: budget.id?.uuidString ?? "",
                        data: budgetData
                    )
                } else {
                    // Handle regular budget upload
                    uploadDebugLog("📊 Uploading budget: \(budget.budgetDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Budget.collectionName,
                        documentId: budget.id?.uuidString ?? "",
                        data: budgetData
                    )
                }
                
                // Mark as synced
                await budgetRepository.markBudgetAsSynced(budget)
                uploadDebugLog("✅ Budget synced successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload budget \(budget.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Expenses with enhanced tombstone logging
     */
    private func uploadExpenses(for user: AppUser, context: NSManagedObjectContext) async throws {
        let expenseRepository = ExpenseRepository(persistenceController: persistenceController)
        let pendingExpenses = await expenseRepository.fetchPendingSyncExpenses(for: user)
        
        uploadDebugLog("💰 Found \(pendingExpenses.count) pending expense changes")
        
        for expense in pendingExpenses {
            do {
                // Validate expense before sync
                try expense.validateExpenseForSync()
                
                let expenseData = try expense.toFirestoreData()
                
                if expense.softDeleted {
                    // Handle tombstone upload
                    uploadDebugLog("🪦 Uploading expense tombstone: \(expense.expenseDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Expense.collectionName,
                        documentId: expense.id?.uuidString ?? "",
                        data: expenseData
                    )
                } else {
                    // Handle regular expense upload
                    uploadDebugLog("💰 Uploading expense: \(expense.expenseDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Expense.collectionName,
                        documentId: expense.id?.uuidString ?? "",
                        data: expenseData
                    )
                }
                
                // Mark as synced
                await expenseRepository.markExpenseAsSynced(expense)
                uploadDebugLog("✅ Expense synced successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload expense \(expense.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Income records with enhanced tombstone logging
     */
    private func uploadIncome(for user: AppUser, context: NSManagedObjectContext) async throws {
        let incomeRepository = IncomeRepository(persistenceController: persistenceController)
        let pendingIncome = await incomeRepository.fetchPendingSyncIncome(for: user)
        
        uploadDebugLog("💵 Found \(pendingIncome.count) pending income changes")
        
        for income in pendingIncome {
            do {
                // Validate income before sync
                try income.validateIncomeForSync()
                
                let incomeData = try income.toFirestoreData()
                
                if income.softDeleted {
                    // Handle tombstone upload
                    uploadDebugLog("🪦 Uploading income tombstone: \(income.incomeDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Income.collectionName,
                        documentId: income.id?.uuidString ?? "",
                        data: incomeData
                    )
                } else {
                    // Handle regular income upload
                    uploadDebugLog("💵 Uploading income: \(income.incomeDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: Income.collectionName,
                        documentId: income.id?.uuidString ?? "",
                        data: incomeData
                    )
                }
                
                // Mark as synced
                await incomeRepository.markIncomeAsSynced(income)
                uploadDebugLog("✅ Income synced successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload income \(income.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Recurring Expenses with enhanced tombstone logging
     */
    private func uploadRecurringExpenses(for user: AppUser, context: NSManagedObjectContext) async throws {
        let recurringExpenseRepository = RecurringExpenseRepository(persistenceController: persistenceController)
        let pendingRecurringExpenses = await recurringExpenseRepository.fetchPendingSyncRecurringExpenses(for: user)
        
        uploadDebugLog("🔄 Found \(pendingRecurringExpenses.count) pending recurring expense changes")
        
        for recurringExpense in pendingRecurringExpenses {
            do {
                // Validate recurring expense before sync
                try recurringExpense.validateRecurringExpenseForSync()
                
                let recurringExpenseData = try recurringExpense.toFirestoreData()
                
                if recurringExpense.softDeleted {
                    // Handle tombstone upload
                    uploadDebugLog("🪦 Uploading recurring expense tombstone: \(recurringExpense.recurringExpenseDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: RecurringExpense.collectionName,
                        documentId: recurringExpense.id?.uuidString ?? "",
                        data: recurringExpenseData
                    )
                } else {
                    // Handle regular recurring expense upload
                    uploadDebugLog("🔄 Uploading recurring expense: \(recurringExpense.recurringExpenseDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: RecurringExpense.collectionName,
                        documentId: recurringExpense.id?.uuidString ?? "",
                        data: recurringExpenseData
                    )
                }
                
                // Mark as synced
                await recurringExpenseRepository.markRecurringExpenseAsSynced(recurringExpense)
                uploadDebugLog("✅ Recurring expense synced successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload recurring expense \(recurringExpense.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Recurring Incomes with enhanced tombstone logging
     */
    private func uploadRecurringIncomes(for user: AppUser, context: NSManagedObjectContext) async throws {
        let recurringIncomeRepository = RecurringIncomeRepository(persistenceController: persistenceController)
        let pendingRecurringIncomes = await recurringIncomeRepository.fetchPendingSyncRecurringIncomes(for: user)
        
        uploadDebugLog("💰 Found \(pendingRecurringIncomes.count) pending recurring income changes")
        
        for recurringIncome in pendingRecurringIncomes {
            do {
                // Validate recurring income before sync
                try recurringIncome.validateRecurringIncomeForSync()
                
                let recurringIncomeData = try recurringIncome.toFirestoreData()
                
                if recurringIncome.softDeleted {
                    // Handle tombstone upload
                    uploadDebugLog("🪦 Uploading recurring income tombstone: \(recurringIncome.recurringIncomeDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: RecurringIncome.collectionName,
                        documentId: recurringIncome.id?.uuidString ?? "",
                        data: recurringIncomeData
                    )
                } else {
                    // Handle regular recurring income upload
                    uploadDebugLog("💰 Uploading recurring income: \(recurringIncome.recurringIncomeDebugDescription)")
                    try await firebaseService.upsertDocument(
                        collection: RecurringIncome.collectionName,
                        documentId: recurringIncome.id?.uuidString ?? "",
                        data: recurringIncomeData
                    )
                }
                
                // Mark as synced
                await recurringIncomeRepository.markRecurringIncomeAsSynced(recurringIncome)
                uploadDebugLog("✅ Recurring income synced successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload recurring income \(recurringIncome.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    // MARK: - Debug and Statistics Methods
    
    /**
     * DEBUG: Count entities needing upload by type including tombstones for all entities
     */
    func debugCountPendingUploads() async -> [String: [String: Int]] {
        let context = persistenceController.viewContext
        
        return await withCheckedContinuation { continuation in
            context.perform {
                var result: [String: [String: Int]] = [:]
                
                for entityType in self.syncOrder {
                    let entityName = String(describing: entityType).components(separatedBy: ".").last!
                    let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                    
                    var counts: [String: Int] = [:]
                    
                    // Count by sync status
                    for status in [SyncState.created, SyncState.updated, SyncState.deleted] {
                        request.predicate = NSPredicate(format: "syncStatus == %@", status.rawValue)
                        do {
                            let count = try context.count(for: request)
                            counts[status.rawValue] = count
                        } catch {
                            counts[status.rawValue] = 0
                        }
                    }
                    
                    // Count tombstones (softDeleted=true entities)
                    request.predicate = NSPredicate(format: "softDeleted == YES")
                    do {
                        let tombstoneCount = try context.count(for: request)
                        counts["tombstones"] = tombstoneCount
                    } catch {
                        counts["tombstones"] = 0
                    }
                    
                    // Count active tombstones needing sync
                    request.predicate = NSPredicate(format: "softDeleted == YES AND syncStatus IN %@", [
                        SyncState.created.rawValue,
                        SyncState.updated.rawValue,
                        SyncState.deleted.rawValue
                    ])
                    do {
                        let activeTombstoneCount = try context.count(for: request)
                        counts["activeTombstones"] = activeTombstoneCount
                    } catch {
                        counts["activeTombstones"] = 0
                    }
                    
                    result[entityType.collectionName] = counts
                }
                
                continuation.resume(returning: result)
            }
        }
    }
    
    /**
     * DEBUG: Force upload all entities regardless of sync status
     */
    func debugForceUploadAll() async {
        uploadDebugLog("🚀 DEBUG: Force uploading all entities...")
        
        let context = persistenceController.viewContext
        
        // Mark all entities for sync
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
                        
                        self.uploadDebugLog("🔄 Marked \(entities.count) \(entityType.collectionName) entities for forced upload")
                    } catch {
                        self.uploadDebugLog("❌ Failed to mark \(entityType.collectionName) for upload: \(error)")
                    }
                }
                continuation.resume()
            }
        }
        
        // Save changes
        do {
            try await persistenceController.saveAsync()
            uploadDebugLog("💾 Saved force upload markings")
        } catch {
            uploadDebugLog("❌ Failed to save force upload markings: \(error)")
        }
        
        // Perform upload
        do {
            try await uploadLocalChangesInternal()
            uploadDebugLog("✅ Force upload completed")
        } catch {
            uploadDebugLog("❌ Force upload failed: \(error)")
        }
    }
    
    /**
     * DEBUG: Upload specific entity type only
     */
    func debugUploadEntityType<T: Syncable>(_ entityType: T.Type) async throws {
        uploadDebugLog("🚀 DEBUG: Uploading only \(entityType.collectionName) entities...")
        
        let context = persistenceController.viewContext
        
        try await uploadEntitiesOfType(entityType, context: context)
        
        uploadDebugLog("✅ DEBUG: \(entityType.collectionName) upload completed")
    }
    
    /**
     * Get upload statistics for debugging with tombstone details for all entities
     */
    func getUploadStatistics() async -> [String: Any] {
        let pendingCounts = await debugCountPendingUploads()
        
        var totalsByType: [String: Int] = [:]
        var grandTotals: [String: Int] = [
            "created": 0,
            "updated": 0,
            "deleted": 0,
            "tombstones": 0,
            "activeTombstones": 0
        ]
        
        for (collection, counts) in pendingCounts {
            var totalForCollection = 0
            for (type, count) in counts {
                totalForCollection += count
                grandTotals[type, default: 0] += count
            }
            totalsByType[collection] = totalForCollection
        }
        
        // Add entity-specific statistics
        var entitySpecific: [String: [String: Int]] = [:]
        for (collection, counts) in pendingCounts {
            let tombstones = counts["tombstones"] ?? 0
            let activeTombstones = counts["activeTombstones"] ?? 0
            
            entitySpecific[collection] = [
                "totalTombstones": tombstones,
                "activeTombstones": activeTombstones,
                "hasPendingDeletes": activeTombstones > 0 ? 1 : 0
            ]
        }
        
        return [
            "pendingByCollection": pendingCounts,
            "totalsByCollection": totalsByType,
            "grandTotals": grandTotals,
            "hasWork": grandTotals.values.reduce(0, +) > 0,
            "entitySpecific": entitySpecific
        ]
    }
    
    /**
     * Get tombstone statistics across all entity types
     */
    func getTombstoneStatistics() async -> [String: Any] {
        let context = persistenceController.viewContext
        
        return await withCheckedContinuation { continuation in
            context.perform {
                var result: [String: Any] = [:]
                var totalTombstones = 0
                var totalActiveTombstones = 0
                
                for entityType in self.syncOrder {
                    let entityName = String(describing: entityType).components(separatedBy: ".").last!
                    let request = NSFetchRequest<NSManagedObject>(entityName: entityName)
                    
                    // Count all tombstones
                    request.predicate = NSPredicate(format: "softDeleted == YES")
                    let tombstoneCount = (try? context.count(for: request)) ?? 0
                    totalTombstones += tombstoneCount
                    
                    // Count active tombstones needing sync
                    request.predicate = NSPredicate(format: "softDeleted == YES AND syncStatus IN %@", [
                        SyncState.created.rawValue,
                        SyncState.updated.rawValue,
                        SyncState.deleted.rawValue
                    ])
                    let activeTombstoneCount = (try? context.count(for: request)) ?? 0
                    totalActiveTombstones += activeTombstoneCount
                    
                    result[entityType.collectionName] = [
                        "tombstones": tombstoneCount,
                        "activeTombstones": activeTombstoneCount
                    ]
                }
                
                result["totals"] = [
                    "allTombstones": totalTombstones,
                    "activeTombstones": totalActiveTombstones,
                    "hasActiveTombstones": totalActiveTombstones > 0
                ]
                
                continuation.resume(returning: result)
            }
        }
    }
}

// MARK: - Upload Priority Extension

extension SyncState {
    /**
     * Get upload priority for sync states (lower number = higher priority)
     */
    var uploadPriority: Int {
        switch self {
        case .deleted:
            return 1  // Delete operations first (including tombstones)
        case .updated:
            return 2  // Updates second
        case .created:
            return 3  // Creates last
        default:
            return 4  // Others lowest priority
        }
    }
}

// MARK: - Entity-Specific Tombstone Upload Extensions

extension SyncManager {
    
    /**
     * Specialized method for handling all entity tombstone uploads with conflict resolution
     */
    func uploadAllTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting comprehensive tombstone upload for all entities...")
        
        // Upload tombstones for each entity type in dependency order
        for entityType in syncOrder {
            switch entityType {
            case is Category.Type:
                try await uploadCategoryTombstones(for: user)
            case is Budget.Type:
                try await uploadBudgetTombstones(for: user)
            case is Income.Type:
                try await uploadIncomeTombstones(for: user)
            case is RecurringExpense.Type:
                try await uploadRecurringExpenseTombstones(for: user)
            case is RecurringIncome.Type:
                try await uploadRecurringIncomeTombstones(for: user)
            case is Expense.Type:
                try await uploadExpenseTombstones(for: user)
            default:
                uploadDebugLog("⚠️ Unknown entity type: \(entityType)")
            }
        }
        
        uploadDebugLog("✅ Comprehensive tombstone upload completed")
    }
    
    /**
     * Upload Category tombstones specifically
     */
    func uploadCategoryTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting Category tombstone upload...")
        
        let categoryRepository = CategoryRepository(persistenceController: persistenceController)
        // Use fetchRecentlyDeleted instead of fetchDeletedCategories
        let deletedCategories = await categoryRepository.fetchRecentlyDeleted(for: user, within: 365) // Get all deleted in last year
        
        let pendingTombstones = deletedCategories.filter { category in
            [SyncState.created, SyncState.updated, SyncState.deleted].contains(category.currentSyncStatus)
        }
        
        uploadDebugLog("📂 Found \(pendingTombstones.count) pending category tombstones to upload")
        
        for category in pendingTombstones {
            do {
                try category.validateCategoryForSync()
                let tombstoneData = try category.toTombstoneData()
                
                uploadDebugLog("🪦 Uploading category tombstone: \(category.categoryDebugDescription)")
                uploadDebugLog("   Tombstone keys: \(tombstoneData.keys.sorted())")
                
                try await firebaseService.upsertDocument(
                    collection: Category.collectionName,
                    documentId: category.id?.uuidString ?? "",
                    data: tombstoneData
                )
                
                await categoryRepository.markCategoryAsSynced(category)
                uploadDebugLog("✅ Category tombstone uploaded successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload category tombstone \(category.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Budget tombstones specifically
     */
    func uploadBudgetTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting Budget tombstone upload...")
        
        let budgetRepository = BudgetRepository(persistenceController: persistenceController)
        let deletedBudgets = await budgetRepository.fetchDeletedBudgets(for: user)
        
        let pendingTombstones = deletedBudgets.filter { budget in
            [SyncState.created, SyncState.updated, SyncState.deleted].contains(budget.currentSyncStatus)
        }
        
        uploadDebugLog("📊 Found \(pendingTombstones.count) pending budget tombstones to upload")
        
        for budget in pendingTombstones {
            do {
                try budget.validateBudgetForSync()
                let tombstoneData = try budget.toTombstoneData()
                
                uploadDebugLog("🪦 Uploading budget tombstone: \(budget.budgetDebugDescription)")
                uploadDebugLog("   Tombstone keys: \(tombstoneData.keys.sorted())")
                
                try await firebaseService.upsertDocument(
                    collection: Budget.collectionName,
                    documentId: budget.id?.uuidString ?? "",
                    data: tombstoneData
                )
                
                await budgetRepository.markBudgetAsSynced(budget)
                uploadDebugLog("✅ Budget tombstone uploaded successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload budget tombstone \(budget.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Expense tombstones specifically
     */
    func uploadExpenseTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting Expense tombstone upload...")
        
        let expenseRepository = ExpenseRepository(persistenceController: persistenceController)
        let deletedExpenses = await expenseRepository.fetchDeletedExpenses(for: user)
        
        let pendingTombstones = deletedExpenses.filter { expense in
            [SyncState.created, SyncState.updated, SyncState.deleted].contains(expense.currentSyncStatus)
        }
        
        uploadDebugLog("💰 Found \(pendingTombstones.count) pending expense tombstones to upload")
        
        for expense in pendingTombstones {
            do {
                try expense.validateExpenseForSync()
                let tombstoneData = try expense.toTombstoneData()
                
                uploadDebugLog("🪦 Uploading expense tombstone: \(expense.expenseDebugDescription)")
                uploadDebugLog("   Tombstone keys: \(tombstoneData.keys.sorted())")
                
                try await firebaseService.upsertDocument(
                    collection: Expense.collectionName,
                    documentId: expense.id?.uuidString ?? "",
                    data: tombstoneData
                )
                
                await expenseRepository.markExpenseAsSynced(expense)
                uploadDebugLog("✅ Expense tombstone uploaded successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload expense tombstone \(expense.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload Income tombstones specifically
     */
    func uploadIncomeTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting Income tombstone upload...")
        
        let incomeRepository = IncomeRepository(persistenceController: persistenceController)
        let deletedIncome = await incomeRepository.fetchDeletedIncome(for: user)
        
        let pendingTombstones = deletedIncome.filter { income in
            [SyncState.created, SyncState.updated, SyncState.deleted].contains(income.currentSyncStatus)
        }
        
        uploadDebugLog("💵 Found \(pendingTombstones.count) pending income tombstones to upload")
        
        for income in pendingTombstones {
            do {
                try income.validateIncomeForSync()
                let tombstoneData = try income.toTombstoneData()
                
                uploadDebugLog("🪦 Uploading income tombstone: \(income.incomeDebugDescription)")
                uploadDebugLog("   Tombstone keys: \(tombstoneData.keys.sorted())")
                
                try await firebaseService.upsertDocument(
                    collection: Income.collectionName,
                    documentId: income.id?.uuidString ?? "",
                    data: tombstoneData
                )
                
                await incomeRepository.markIncomeAsSynced(income)
                uploadDebugLog("✅ Income tombstone uploaded successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload income tombstone \(income.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload RecurringExpense tombstones specifically
     */
    func uploadRecurringExpenseTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting RecurringExpense tombstone upload...")
        
        let recurringExpenseRepository = RecurringExpenseRepository(persistenceController: persistenceController)
        let deletedRecurringExpenses = await recurringExpenseRepository.fetchDeletedRecurringExpenses(for: user)
        
        let pendingTombstones = deletedRecurringExpenses.filter { recurringExpense in
            [SyncState.created, SyncState.updated, SyncState.deleted].contains(recurringExpense.currentSyncStatus)
        }
        
        uploadDebugLog("🔄 Found \(pendingTombstones.count) pending recurring expense tombstones to upload")
        
        for recurringExpense in pendingTombstones {
            do {
                try recurringExpense.validateRecurringExpenseForSync()
                let tombstoneData = try recurringExpense.toTombstoneData()
                
                uploadDebugLog("🪦 Uploading recurring expense tombstone: \(recurringExpense.recurringExpenseDebugDescription)")
                uploadDebugLog("   Tombstone keys: \(tombstoneData.keys.sorted())")
                
                try await firebaseService.upsertDocument(
                    collection: RecurringExpense.collectionName,
                    documentId: recurringExpense.id?.uuidString ?? "",
                    data: tombstoneData
                )
                
                await recurringExpenseRepository.markRecurringExpenseAsSynced(recurringExpense)
                uploadDebugLog("✅ Recurring expense tombstone uploaded successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload recurring expense tombstone \(recurringExpense.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
    
    /**
     * Upload RecurringIncome tombstones specifically
     */
    func uploadRecurringIncomeTombstones(for user: AppUser) async throws {
        uploadDebugLog("🪦 Starting RecurringIncome tombstone upload...")
        
        let recurringIncomeRepository = RecurringIncomeRepository(persistenceController: persistenceController)
        let deletedRecurringIncomes = await recurringIncomeRepository.fetchDeletedRecurringIncomes(for: user)
        
        let pendingTombstones = deletedRecurringIncomes.filter { recurringIncome in
            [SyncState.created, SyncState.updated, SyncState.deleted].contains(recurringIncome.currentSyncStatus)
        }
        
        uploadDebugLog("💰 Found \(pendingTombstones.count) pending recurring income tombstones to upload")
        
        for recurringIncome in pendingTombstones {
            do {
                try recurringIncome.validateRecurringIncomeForSync()
                let tombstoneData = try recurringIncome.toTombstoneData()
                
                uploadDebugLog("🪦 Uploading recurring income tombstone: \(recurringIncome.recurringIncomeDebugDescription)")
                uploadDebugLog("   Tombstone keys: \(tombstoneData.keys.sorted())")
                
                try await firebaseService.upsertDocument(
                    collection: RecurringIncome.collectionName,
                    documentId: recurringIncome.id?.uuidString ?? "",
                    data: tombstoneData
                )
                
                await recurringIncomeRepository.markRecurringIncomeAsSynced(recurringIncome)
                uploadDebugLog("✅ Recurring income tombstone uploaded successfully")
                
            } catch {
                uploadDebugLog("❌ Failed to upload recurring income tombstone \(recurringIncome.id?.uuidString ?? "unknown"): \(error)")
                throw error
            }
        }
    }
}
