//
//  AuthenticationView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct AuthenticationView: View {
    @Bindable var authVM: AuthViewModel
    @State private var isLogin = true

    var body: some View {
        VStack(spacing: AppSpacing.verticalPadding) {
            
            Image("BuckitLogoApp")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .padding(.bottom, 8)
            
            VStack(spacing: 4) {
                Text(isLogin ? "Login" : "Sign Up")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.textPrimary)

                Text("Welcome to Buckit")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.bottom, AppSpacing.verticalPadding)
            
            if isLogin {
                LoginView(authVM: authVM)
            } else {
                SignupView(authVM: authVM)
            }

            Button(action: {
                isLogin.toggle()
            }) {
                Text(isLogin ? "Don't have an account? Sign Up" : "Already have an account? Login")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(AppSpacing.horizontalPadding)
        .background(AppColors.backgroundLight.ignoresSafeArea())
    }
}
