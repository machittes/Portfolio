//
//  AuthViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import Foundation
import FirebaseAuth
import Observation
import FirebaseFirestore

import FirebaseAuth
import FirebaseFirestore
import Observation
import FirebaseCore

@Observable
class AuthViewModel {
    var user: User?  // Firebase User
    var isAuthenticated = false
    var errorMessage: String?
    var currentAppUser: AppUser? // Store the current AppUser

    private let userRepository = UserRepository()
    
    init() {
        DispatchQueue.main.async {
            guard FirebaseApp.app() != nil else {
                print("⚠️ FirebaseApp not configured yet")
                return
            }

            Auth.auth().addStateDidChangeListener { [weak self] _, user in
                self?.user = user
                self?.isAuthenticated = user != nil

                if user != nil {
                    _ = PersistenceController.shared.viewContext
                    Task {
                        await self?.loadCurrentAppUser()
                    }
                } else {
                    self?.currentAppUser = nil
                }
            }
        }
    }


    
    func loadCurrentAppUser() async {
        guard let firebaseUser = user else {
            currentAppUser = nil
            return
        }
        
        // Try to fetch existing AppUser
        if let existingUser = await userRepository.fetchUser(by: firebaseUser.uid) {
            currentAppUser = existingUser
            return
        }
        
        // Create new AppUser if doesn't exist
        currentAppUser = await userRepository.createUser(
            userId: firebaseUser.uid,
            email: firebaseUser.email ?? "",
            name: firebaseUser.displayName
        )
    }
    
    func signup(email: String, password: String, completion: @escaping () -> Void) {
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.user = result?.user
                self?.isAuthenticated = true
                
                // Load the AppUser after successful signup
                Task {
                    await self?.loadCurrentAppUser()
                    
                    

                    
                }
                
                completion()
            }
        }
    }

    func login(email: String, password: String) {
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] result, error in
            if let error = error {
                self?.errorMessage = error.localizedDescription
            } else {
                self?.user = result?.user
                self?.isAuthenticated = true
                self?.errorMessage = nil
                Task {
                    await self?.loadCurrentAppUser()
                    
          
                    
                }
            }
        }
    }

    func logout() {
        do {
            try Auth.auth().signOut()
            user = nil
            isAuthenticated = false
            currentAppUser = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveUserProfile(fullName: String, phoneNumber: String, dateOfBirth: Date) {
        guard let uid = Auth.auth().currentUser?.uid else {
            errorMessage = "User not logged in"
            return
        }

        let userData: [String: Any] = [
            "fullName": fullName,
            "phoneNumber": phoneNumber,
            "dateOfBirth": Timestamp(date: dateOfBirth),
            "email": Auth.auth().currentUser?.email ?? "",
            "createdAt": Timestamp(date: Date())
        ]

        Firestore.firestore().collection("users").document(uid).setData(userData) { [weak self] error in
            if let error = error {
                self?.errorMessage = "Failed to save profile: \(error.localizedDescription)"
            }
        }
    }
}
