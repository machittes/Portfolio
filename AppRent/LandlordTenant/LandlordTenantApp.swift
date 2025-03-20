//
//  LandlordTenantApp.swift
//  LandlordTenant
//
//  Created by Henrique Machitte on 02/03/25.
//

import SwiftUI
import Firebase
import FirebaseAuth

@main
struct LandlordTenantApp: App {
    
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
