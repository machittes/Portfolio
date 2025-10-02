//
//  AddCategoryView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct AddCategoryView: View {
    @Bindable var viewModel: CategoryViewModel
    let user: AppUser

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
                        // Category Name
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Category Name")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textPrimary)

                            TextField("Enter category name", text: $viewModel.categoryName)
                                .padding()
                                .frame(height: AppSpacing.fieldHeight)
                                .background(AppColors.cardBackground)
                                .cornerRadius(AppSpacing.cornerRadius)
                                .foregroundColor(AppColors.textPrimary)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }

                        // Icon Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Icon")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textPrimary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                                ForEach(viewModel.availableIcons, id: \.self) { icon in
                                    Button {
                                        viewModel.selectedIcon = icon
                                    } label: {
                                        Image(systemName: icon)
                                            .font(.title2)
                                            .foregroundColor(viewModel.selectedIcon == icon ? .white : AppColors.textPrimary)
                                            .frame(width: 44, height: 44)
                                            .background(
                                                Circle()
                                                    .fill(viewModel.selectedIcon == icon ? AppColors.primary : AppColors.backgroundLight)
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        // Color Selection
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Color")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textPrimary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                                ForEach(viewModel.availableColors, id: \.self) { color in
                                    Button {
                                        viewModel.selectedColor = color
                                    } label: {
                                        Circle()
                                            .fill(viewModel.getSystemColorForString(color))
                                            .frame(width: 32, height: 32)
                                            .overlay(
                                                Circle()
                                                    .stroke(
                                                        viewModel.selectedColor == color ? AppColors.primary : AppColors.secondary.opacity(0.3),
                                                        lineWidth: viewModel.selectedColor == color ? 3 : 1
                                                    )
                                            )
                                            .shadow(
                                                color: viewModel.selectedColor == color ? AppColors.primary.opacity(0.3) : .clear,
                                                radius: 4, x: 0, y: 2
                                            )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.vertical, 8)

                        // Default Category Toggle
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Default Category")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.textPrimary)
                                Text("Make this a default category")
                                    .font(AppFonts.small)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Spacer()

                            Toggle("", isOn: $viewModel.isDefault)
                                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Category Details")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.textPrimary)
                }
                .listRowBackground(AppColors.cardBackground)

                // Preview Section
                Section {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Text("Preview")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        HStack(spacing: AppSpacing.horizontalPadding) {
                            Image(systemName: viewModel.selectedIcon)
                                .font(.title2)
                                .foregroundColor(viewModel.getSystemColorForString(viewModel.selectedColor))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.categoryName.isEmpty ? "Category Name" : viewModel.categoryName)
                                    .font(AppFonts.body)
                                    .foregroundColor(viewModel.categoryName.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

                                if viewModel.isDefault {
                                    Text("Default Category")
                                        .font(AppFonts.small)
                                        .foregroundColor(AppColors.textSecondary)
                                }
                            }

                            Spacer()
                        }
                        .padding()
                        .background(AppColors.backgroundLight)
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                }
                .listRowBackground(AppColors.cardBackground)

                // Error Message
                if let errorMessage = viewModel.errorMessage {
                    Section {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.error)
                            Text(errorMessage)
                                .font(AppFonts.small)
                                .foregroundColor(AppColors.error)
                        }
                        .padding()
                        .background(AppColors.error.opacity(0.1))
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                    .listRowBackground(Color.clear)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundDefault)
            // Removed .navigationTitle
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Add Category")
                        .font(AppFonts.body) 
                        .foregroundColor(AppColors.textPrimary)
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.cancelEditing()
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .font(AppFonts.body)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addCategory(for: user)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid)
                    .foregroundColor(viewModel.isFormValid ? AppColors.primary : AppColors.textSecondary)
                    .font(AppFonts.body)
                    .padding(.horizontal, AppSpacing.horizontalPadding)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .fill(viewModel.isFormValid ? AppColors.primary.opacity(0.1) : Color.clear)
                    )
                }
            }
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
    }
}
