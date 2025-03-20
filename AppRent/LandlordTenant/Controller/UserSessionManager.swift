//
//  UserSessionManage.swift
//  LandlordTenant
//
//  Created by Henrique Machitte on 11/03/25.
//
import SwiftUI

class UserSessionManager: ObservableObject {
    @Published var isLogged: Bool
    @Published var userType: UserType
    
    init() {
        self.isLogged = false
        self.userType = .guest
    }
    
    func loginAs(_ userType: UserType) {
        self.isLogged = true
        self.userType = userType
    }
    
    func logout() {
        self.isLogged = false
        self.userType = .guest
    }
}

enum UserType {
    case landlord
    case tenant
    case guest
}

