//
//  ProfileViewModel.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 02/06/25.
//

import Foundation
import Observation
import FirebaseAuth

@Observable
class ProfileViewModel {
    private let service = ProfileService()
    
    var fullName: String = ""
    var phoneNumber: String = ""
    var dateOfBirth: Date = Date()
    var email: String = ""
    
    var errorMessage: String?
    var successMessage: String?
    
    func loadProfile() {
        errorMessage = nil
        successMessage = nil
        
        service.fetchProfile { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    self?.fullName = profile.fullName
                    self?.phoneNumber = profile.phoneNumber
                    self?.dateOfBirth = profile.dateOfBirth
                    self?.email = profile.email
                case .failure:
                    // Fallback para usuários Apple ID sem Firestore doc
                    self?.fullName = "Apple ID User"
                    self?.phoneNumber = "Apple ID User"
                    self?.dateOfBirth = Date()
                    self?.email = Auth.auth().currentUser?.email ?? "Apple ID User"
                    self?.errorMessage = nil
                }
            }
        }
    }
    
    func updateProfile() {
        errorMessage = nil
        successMessage = nil

        if fullName == "Apple ID User" {
            errorMessage = "Your profile is managed through your Apple ID and cannot be edited here."
            return
        }
        
        let updatedProfile = UserProfile(
            fullName: fullName,
            phoneNumber: phoneNumber,
            dateOfBirth: dateOfBirth,
            email: email
        )
        
        service.updateProfile(updatedProfile) { [weak self] result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    self?.successMessage = "Profile updated successfully."
                case .failure(let error):
                    self?.errorMessage = "Failed to update profile: \(error.localizedDescription)"
                }
            }
        }
    }
}


