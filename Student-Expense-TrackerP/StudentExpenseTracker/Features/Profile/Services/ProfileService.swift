//
//  ProfileService.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 02/06/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

struct UserProfile {
    var fullName: String
    var phoneNumber: String
    var dateOfBirth: Date
    var email: String
}

class ProfileService {
    private let db = Firestore.firestore()

    func fetchProfile(completion: @escaping (Result<UserProfile, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."])))
            return
        }

        db.collection("users").document(uid).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = snapshot?.data(),
                  let fullName = data["fullName"] as? String,
                  let phoneNumber = data["phoneNumber"] as? String,
                  let timestamp = data["dateOfBirth"] as? Timestamp,
                  let email = data["email"] as? String
            else {
                completion(.failure(NSError(domain: "Parse", code: 422, userInfo: [NSLocalizedDescriptionKey: "Invalid user data."])))
                return
            }

            let profile = UserProfile(
                fullName: fullName,
                phoneNumber: phoneNumber,
                dateOfBirth: timestamp.dateValue(),
                email: email
            )

            completion(.success(profile))
        }
    }

    func updateProfile(_ profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let uid = Auth.auth().currentUser?.uid else {
            completion(.failure(NSError(domain: "Auth", code: 401, userInfo: [NSLocalizedDescriptionKey: "User not authenticated."])))
            return
        }

        let userData: [String: Any] = [
            "fullName": profile.fullName,
            "phoneNumber": profile.phoneNumber,
            "dateOfBirth": Timestamp(date: profile.dateOfBirth),
            "email": profile.email,
            "updatedAt": Timestamp(date: Date())
        ]

        db.collection("users").document(uid).setData(userData, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}
