//
//  SplashView.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 25/06/25.
//

import SwiftUI

struct SplashView: View {
    @State private var isActive = false

    var authVM: AuthViewModel
    var syncManager: SyncManager

    var body: some View {
        ZStack {
            if isActive {
                NavigationStack {
                    if authVM.isAuthenticated {
                        MainView(authVM: authVM)
                    } else {
                        AuthenticationView(authVM: authVM)
                    }
                }
                .environment(authVM)
                .environment(syncManager)
                .task {
                    // Only sync when user becomes authenticated
                    if authVM.isAuthenticated {
                        await syncManager.performFullSync()
                    }
                }
            } else {
                GeometryReader { geometry in
                    ZStack {
                        Color.white
                            .ignoresSafeArea()

                        Image("BuckitSplash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: geometry.size.width * 0.85)
                            .accessibilityLabel("Buckit splash screen")
                    }
                }


                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation {
                            isActive = true
                        }
                    }
                }
            }
        }
    }
}



