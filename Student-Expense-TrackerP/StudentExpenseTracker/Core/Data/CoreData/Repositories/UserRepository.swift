//
//  UserRepository.swift
//  StudentExpenseTracker
//
//  Created by George Potakis on 2025-05-25.
//

import Foundation
import CoreData

@Observable
class UserRepository {
    private let persistenceController: PersistenceController
    private var viewContext: NSManagedObjectContext {
        persistenceController.viewContext
    }
    
    // allow dependency injection for testing
    init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Create
    
    // In UserRepository.createUser method, add debugging
    func createUser(userId: String, email: String, name: String? = nil) async -> AppUser? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                Logger.log("Creating user with ID: \(userId)", level: .debug)
                Logger.log("ViewContext: \(self.viewContext)", level: .debug)
                Logger.log("ViewContext.persistentStoreCoordinator: \(String(describing: self.viewContext.persistentStoreCoordinator))", level: .debug)
                Logger.log("PersistenceController: \(self.persistenceController)", level: .debug)

                // Check if the context is properly set up
                if let coordinator = self.viewContext.persistentStoreCoordinator {
                    Logger.log("Persistent store coordinator exists", level: .debug)
                    Logger.log("Persistent stores: \(coordinator.persistentStores)", level: .debug)
                } else {
                    Logger.log("No persistent store coordinator!", level: .error)
                }

                // Check if AppUser entity description exists
                if let entityDescription = NSEntityDescription.entity(forEntityName: "AppUser", in: self.viewContext) {
                    Logger.log("AppUser entity description found: \(entityDescription)", level: .debug)
                    Logger.log("Entity name: \(entityDescription.name ?? "nil")", level: .debug)
                    Logger.log("Managed object class name: \(entityDescription.managedObjectClassName ?? "nil")", level: .debug)
                } else {
                    Logger.log("AppUser entity description NOT found!", level: .error)
                    Logger.log("Available entities: \(String(describing: self.viewContext.persistentStoreCoordinator?.managedObjectModel.entities.map { $0.name }))", level: .debug)
                }
                
                // This line will crash if there's an issue
                Logger.log("About to create AppUser...", level: .debug)
                let user = AppUser(context: self.viewContext)  // Crash happens here
                Logger.log("AppUser created successfully", level: .debug)
                
                user.userId = userId
                user.email = email
                user.name = name
                user.defaultCurrency = nil
                user.notificationsEnabled = false
                user.createdAt = Date()
                user.updatedAt = Date()
                user.syncStatus = "created"
                
                self.save()
                continuation.resume(returning: user)
            }
        }
    }
    
    // MARK: - Read
    
    func fetchUser(by userId: String) async -> AppUser? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<AppUser> = AppUser.fetchRequest()
                request.predicate = NSPredicate(format: "userId == %@", userId)
                request.fetchLimit = 1
                
                do {
                    let users = try self.viewContext.fetch(request)
                    continuation.resume(returning: users.first)
                } catch {
                    Logger.log("Error fetching user: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchUser(byEmail email: String) async -> AppUser? {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<AppUser> = AppUser.fetchRequest()
                request.predicate = NSPredicate(format: "email == %@", email)
                request.fetchLimit = 1
                
                do {
                    let users = try self.viewContext.fetch(request)
                    continuation.resume(returning: users.first)
                } catch {
                    Logger.log("Error fetching user by email: \(error)", level: .error)
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    func fetchAllUsers() async -> [AppUser] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<AppUser> = AppUser.fetchRequest()
                request.sortDescriptors = [NSSortDescriptor(keyPath: \AppUser.createdAt, ascending: true)]
                
                do {
                    let users = try self.viewContext.fetch(request)
                    continuation.resume(returning: users)
                } catch {
                    Logger.log("Error fetching all users: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    // MARK: - Update
    
    func updateUser(_ user: AppUser, name: String? = nil, prefersDarkMode: Bool? = nil,
                   defaultCurrency: String? = nil, notificationsEnabled: Bool? = nil) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                if let name = name {
                    user.name = name
                }
                //if let prefersDarkMode = prefersDarkMode {
                    //user.prefersDarkMode = prefersDarkMode
                //}
                if let defaultCurrency = defaultCurrency {
                    user.defaultCurrency = defaultCurrency
                }
                if let notificationsEnabled = notificationsEnabled {
                    user.notificationsEnabled = notificationsEnabled
                }
                
                user.updatedAt = Date()
                user.syncStatus = "updated"
                
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Delete
    
    func deleteUser(_ user: AppUser) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                self.viewContext.delete(user)
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    func deleteUser(by userId: String) async {
        if let user = await fetchUser(by: userId) {
            await deleteUser(user)
        }
    }
    
    // MARK: - Sync Status
    
    func fetchUsersWithSyncStatus(_ status: String) async -> [AppUser] {
        return await withCheckedContinuation { continuation in
            viewContext.perform {
                let request: NSFetchRequest<AppUser> = AppUser.fetchRequest()
                request.predicate = NSPredicate(format: "syncStatus == %@", status)
                
                do {
                    let users = try self.viewContext.fetch(request)
                    continuation.resume(returning: users)
                } catch {
                    Logger.log("Error fetching users with sync status: \(error)", level: .error)
                    continuation.resume(returning: [])
                }
            }
        }
    }
    
    func markUserAsSynced(_ user: AppUser) async {
        await withCheckedContinuation { continuation in
            viewContext.perform {
                user.syncStatus = "synced"
                user.updatedAt = Date()
                self.save()
                continuation.resume(returning: ())
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func save() {
        let result = persistenceController.save()
        switch result {
        case .success:
            break // Success - no action needed
        case .failure(let error):
            Logger.log("UserRepository save failed: \(error.localizedDescription)", level: .error)
            // Repository-level error handling - could emit to error stream or delegate
        }
    }
    
    // MARK: - User Existence Check
    
    func userExists(userId: String) async -> Bool {
        let user = await fetchUser(by: userId)
        return user != nil
    }
    
    func userExists(email: String) async -> Bool {
        let user = await fetchUser(by: email)
        return user != nil
    }
}
