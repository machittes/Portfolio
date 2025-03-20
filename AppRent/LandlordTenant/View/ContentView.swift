//
//  ContentView.swift
//  LandlordTenant
//
//  Created by Henrique Machitte on 02/03/25.
//

import SwiftUI

struct ContentView: View {
  
    @State private var root: RootView = .Login
      @StateObject private var fireAuthHelper = FireAuthHelper.getInstance()
      @StateObject private var fireDBHelper = FireDBHelper.getInstance()
      @ObservedObject var userSessionManager = UserSessionManager()



    var body: some View {

        NavigationStack {

            switch root {
            case .Login:
                SignInView(rootScreen: self.$root)
                    .environmentObject(self.fireAuthHelper)
                    .environmentObject(userSessionManager)
            case .SignUp:
                SignUpView(rootScreen: self.$root)
                    .environmentObject(self.fireAuthHelper)
                    .environmentObject(userSessionManager)
                
            case .PropertyListGuest:
                PropertyListGuestView(rootScreen: self.$root)
                    .environmentObject(self.fireAuthHelper)
                    .environmentObject(self.fireDBHelper)
                    .environmentObject(userSessionManager)
            case .PropertyListLandlord:
                PropertyListLandlordView(rootScreen: self.$root)
                    .environmentObject(self.fireAuthHelper)
                    .environmentObject(self.fireDBHelper)
                    .environmentObject(userSessionManager)
            case .PropertyListTenant:
                PropertyListTenantView(rootScreen: self.$root)
                    .environmentObject(self.fireAuthHelper)
                    .environmentObject(self.fireDBHelper)
                    .environmentObject(userSessionManager)

            }
        
        }
    }
}

enum RootView {
    case Login, SignUp,PropertyListGuest,PropertyListLandlord,PropertyListTenant
}

