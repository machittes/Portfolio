import Foundation
import FirebaseFirestore

struct UserModel: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var email: String
    var address: String
    var phoneNumber: String
    var typeOfUser: String // "Landlord" or "Tenant"
    var creditCard: String? // Optional
    var propertyIDs: [String] // List of property IDs associated with the user
    var requestpropertyIDs: [String]

    init(id: String? = nil, name: String, email: String, address: String, phoneNumber: String, typeOfUser: String, creditCard: String? = nil) {
        self.id = id
        self.name = name
        self.email = email
        self.address = address
        self.phoneNumber = phoneNumber
        self.typeOfUser = typeOfUser
        self.creditCard = creditCard
        self.propertyIDs = []
        self.requestpropertyIDs = []
    }
}
