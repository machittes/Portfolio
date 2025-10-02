//
//  AppleSignInButton.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 09/07/25.
//

import SwiftUI
import AuthenticationServices
import FirebaseAuth

struct AppleSignInButton: View {
    var body: some View {
        SignInWithAppleButton()
            .frame(height: 50)
            .onTapGesture {
                SignInWithAppleCoordinator().startSignInWithAppleFlow()
            }
    }
}

struct SignInWithAppleButton: UIViewRepresentable {
    func makeUIView(context: Context) -> ASAuthorizationAppleIDButton {
        return ASAuthorizationAppleIDButton()
    }

    func updateUIView(_ uiView: ASAuthorizationAppleIDButton, context: Context) {}
}
