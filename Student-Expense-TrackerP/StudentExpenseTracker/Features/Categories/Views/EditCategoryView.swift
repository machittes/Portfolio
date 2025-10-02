//
//  EditCategoryView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct EditCategoryView: View {
    @Bindable var viewModel: CategoryViewModel
    let user: AppUser

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
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

                        if let selectedCategory = viewModel.selectedCategory {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Default Category")
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.textPrimary)
                                    Text("Cannot be changed for existing categories")
                                        .font(AppFonts.small)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                Spacer()

                                Text(selectedCategory.isDefault ? "Yes" : "No")
                                    .font(AppFonts.body)
                                    .foregroundColor(selectedCategory.isDefault ? AppColors.primary : AppColors.textSecondary)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius / 2)
                                            .fill(selectedCategory.isDefault ? AppColors.primary.opacity(0.1) : AppColors.backgroundLight)
                                    )
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Category Details")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.textPrimary)
                }
                .listRowBackground(AppColors.cardBackground)

                Section {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        if let selectedCategory = viewModel.selectedCategory {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Current")
                                    .font(AppFonts.small)
                                    .foregroundColor(AppColors.textSecondary)

                                HStack(spacing: AppSpacing.horizontalPadding) {
                                    Image(systemName: selectedCategory.icon ?? "questionmark.circle.fill")
                                        .font(.title2)
                                        .foregroundColor(viewModel.getColorForCategory(selectedCategory))
                                        .frame(width: 30)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(selectedCategory.name ?? "Unknown")
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.textPrimary)

                                        if selectedCategory.isDefault {
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

                            Divider()
                                .background(AppColors.secondary.opacity(0.3))
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Updated")
                                .font(AppFonts.small)
                                .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: AppSpacing.horizontalPadding) {
                                Image(systemName: viewModel.selectedIcon)
                                    .font(.title2)
                                    .foregroundColor(viewModel.getSystemColorForString(viewModel.selectedColor))
                                    .frame(width: 30)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(viewModel.categoryName.isEmpty ? "Category Name" : viewModel.categoryName)
                                        .font(AppFonts.body)
                                        .foregroundColor(viewModel.categoryName.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

                                    if viewModel.selectedCategory?.isDefault == true {
                                        Text("Default Category")
                                            .font(AppFonts.small)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }

                                Spacer()

                                if hasChanges {
                                    Text("Modified")
                                        .font(AppFonts.small)
                                        .foregroundColor(AppColors.primary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(AppColors.primary.opacity(0.1))
                                        .cornerRadius(AppSpacing.cornerRadius / 2)
                                }
                            }
                            .padding()
                            .background(hasChanges ? AppColors.primary.opacity(0.05) : AppColors.backgroundLight)
                            .cornerRadius(AppSpacing.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                    .stroke(hasChanges ? AppColors.primary.opacity(0.3) : Color.clear, lineWidth: 2)
                            )
                        }
                    }
                } header: {
                    Text("Preview")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.textPrimary)
                }
                .listRowBackground(AppColors.cardBackground)

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

                if let selectedCategory = viewModel.selectedCategory, !selectedCategory.isDefault {
                    Section {
                        VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
                            if let dependencyInfo = viewModel.currentDependencyInfo {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Category Usage")
                                        .font(AppFonts.body)
                                        .foregroundColor(AppColors.textPrimary)

                                    if dependencyInfo.hasAnyDependencies {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if dependencyInfo.expenseCount > 0 {
                                                HStack {
                                                    Image(systemName: "creditcard.fill")
                                                        .foregroundColor(AppColors.secondary)
                                                    Text("\(dependencyInfo.expenseCount) expenses")
                                                        .font(AppFonts.body)
                                                }
                                            }

                                            if dependencyInfo.budgetCount > 0 {
                                                HStack {
                                                    Image(systemName: "chart.pie.fill")
                                                        .foregroundColor(AppColors.secondary)
                                                    Text("\(dependencyInfo.budgetCount) budgets")
                                                        .font(AppFonts.body)
                                                }
                                            }

                                            if dependencyInfo.recurringExpenseCount > 0 {
                                                HStack {
                                                    Image(systemName: "repeat")
                                                        .foregroundColor(AppColors.secondary)
                                                    Text("\(dependencyInfo.recurringExpenseCount) recurring transactions")
                                                        .font(AppFonts.body)
                                                }
                                            }
                                        }
                                        .foregroundColor(AppColors.textSecondary)

                                        Text("These will be moved to 'Uncategorized' or deleted when you delete this category.")
                                            .font(AppFonts.small)
                                            .foregroundColor(AppColors.textSecondary)
                                            .padding(.top, 4)
                                    } else {
                                        Text("This category is not used by any expenses, budgets, or recurring transactions.")
                                            .font(AppFonts.body)
                                            .foregroundColor(AppColors.textSecondary)
                                    }
                                }
                                .padding()
                                .background(AppColors.backgroundLight)
                                .cornerRadius(AppSpacing.cornerRadius)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Delete Category")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.error)
                                Text("This action cannot be undone.")
                                    .font(AppFonts.small)
                                    .foregroundColor(AppColors.textSecondary)
                            }

                            Button("Delete Category") {
                                Task {
                                    await viewModel.deleteCategory(selectedCategory, for: user)
                                    if !viewModel.showDeletionConfirmation {
                                        dismiss()
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: AppSpacing.fieldHeight)
                            .background(AppColors.error)
                            .foregroundColor(.white)
                            .cornerRadius(AppSpacing.cornerRadius)
                            .font(AppFonts.body)
                        }
                    } header: {
                        Text("Danger Zone")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.error)
                    }
                    .listRowBackground(AppColors.error.opacity(0.05))
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppColors.backgroundDefault)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Edit Category")
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
                            await viewModel.updateCategory(for: user)
                            if viewModel.errorMessage == nil {
                                dismiss()
                            }
                        }
                    }
                    .disabled(!viewModel.isFormValid || !hasChanges)
                    .foregroundColor((viewModel.isFormValid && hasChanges) ? AppColors.primary : AppColors.textSecondary)
                    .font(AppFonts.body)
                    .padding(.horizontal, AppSpacing.horizontalPadding)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .fill((viewModel.isFormValid && hasChanges) ? AppColors.primary.opacity(0.1) : Color.clear)
                    )
                }
            }
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: $viewModel.showDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.confirmCategoryDeletion(for: user)
                    dismiss()
                }
            }

            Button("Cancel", role: .cancel) {
                viewModel.cancelCategoryDeletion()
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
        .onAppear {
            if let selectedCategory = viewModel.selectedCategory {
                Task {
                    let dependencyInfo = await viewModel.checkCategoryDependencies(selectedCategory)
                    await MainActor.run {
                        viewModel.currentDependencyInfo = dependencyInfo
                    }
                }
            }
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
    }

    private var hasChanges: Bool {
        guard let selectedCategory = viewModel.selectedCategory else { return false }

        return viewModel.categoryName != (selectedCategory.name ?? "") ||
               viewModel.selectedIcon != (selectedCategory.icon ?? "questionmark.circle.fill") ||
               viewModel.selectedColor != (selectedCategory.color ?? "blue")
    }
}
