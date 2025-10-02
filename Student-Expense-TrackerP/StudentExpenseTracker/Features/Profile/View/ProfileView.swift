//  ProfileView.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 02/06/25.

import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @State private var viewModel = ProfileViewModel()
    @Bindable var authVM: AuthViewModel
    @Environment(\.dismiss) var dismiss
    @State private var showSignOutAlert = false

    var body: some View {
        ZStack {
            AppColors.backgroundDefault
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: AppSpacing.verticalPadding) {
                    Text("My Profile")
                        .font(AppFonts.title)
                        .foregroundColor(AppColors.textPrimary)
                        .padding(.top, AppSpacing.verticalPadding)

                    // Oval white container with all fields inside
                    VStack(spacing: AppSpacing.verticalPadding) {
                        HStack {
                            Image(systemName: "person")
                                .foregroundColor(AppColors.secondary)
                            TextField("Full Name", text: $viewModel.fullName)
                        }
                        .padding()
                        .frame(height: AppSpacing.fieldHeight)
                        .background(Color.white)
                        .cornerRadius(AppSpacing.cornerRadius)

                        HStack {
                            Image(systemName: "envelope")
                                .foregroundColor(AppColors.secondary)
                            TextField("Email", text: .constant(viewModel.email))
                                .disabled(true)
                        }
                        .padding()
                        .frame(height: AppSpacing.fieldHeight)
                        .background(Color.white)
                        .cornerRadius(AppSpacing.cornerRadius)

                        HStack {
                            Image(systemName: "phone")
                                .foregroundColor(AppColors.secondary)
                            TextField("Phone Number", text: $viewModel.phoneNumber)
                                .keyboardType(.phonePad)
                        }
                        .padding()
                        .frame(height: AppSpacing.fieldHeight)
                        .background(Color.white)
                        .cornerRadius(AppSpacing.cornerRadius)

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(AppColors.secondary)
                            DatePicker("Date of Birth", selection: $viewModel.dateOfBirth, displayedComponents: .date)
                        }
                        .padding()
                        .background(Color.white)
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 0.5)
                    )
                    .padding(.horizontal)

                    // Save Changes Button
                    Button("Save Changes") {
                        viewModel.updateProfile()
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.fieldHeight)
                    .background(AppColors.primary)
                    .foregroundColor(.white)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .font(AppFonts.body)

                    // Log Out Button
                    Button("Log out") {
                        showSignOutAlert = true
                    }
                    .alert("Log out of your account?", isPresented: $showSignOutAlert) {
                        Button("Cancel", role: .cancel) {}
                        Button("Log out", role: .destructive) {
                            authVM.logout()
                            dismiss()
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: AppSpacing.fieldHeight)
                    .background(Color.white)
                    .foregroundColor(.red)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(Color.red, lineWidth: 1)
                    )
                    .cornerRadius(AppSpacing.cornerRadius)
                    .font(AppFonts.body)

                    // Messages
                    if let message = viewModel.successMessage {
                        Text(message)
                            .foregroundColor(AppColors.textPrimary)
                            .font(AppFonts.small)
                    }

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(AppColors.error)
                            .font(AppFonts.small)
                    }
                }
                .padding(AppSpacing.horizontalPadding)
            }
        }
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            viewModel.loadProfile()
        }
    }
}
