//
//  CategoryListView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct CategoryListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = CategoryViewModel()

    var body: some View {
        Group {
            if let appUser = authVM.currentAppUser {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Loading categories...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, AppSpacing.verticalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else if viewModel.categories.isEmpty {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Image(systemName: "folder")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondary)
                        Text("No categories found")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Categories will be created automatically")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else {
                    List {
                        ForEach(viewModel.categories, id: \.id) { category in
                            CategoryRowView(category: category, viewModel: viewModel)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 14)
                                .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                                .listRowBackground(AppColors.backgroundDefault)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let category = viewModel.categories[index]
                                    await viewModel.deleteCategory(category, for: appUser)
                                }
                            }
                        }
                        .onMove { source, destination in
                            Task {
                                var updatedCategories = viewModel.categories
                                updatedCategories.move(fromOffsets: source, toOffset: destination)
                                await viewModel.reorderCategories(updatedCategories, for: appUser)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(AppColors.backgroundDefault)
                    .refreshable {
                        await viewModel.loadCategories(for: appUser)
                    }
                }

                if let errorMessage = viewModel.errorMessage {
                    VStack {
                        Text(errorMessage)
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.error)
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppSpacing.cornerRadius)
                            .padding(.horizontal, AppSpacing.horizontalPadding)
                    }
                }
            } else {
                VStack {
                    ProgressView()
                        .tint(AppColors.primary)
                    Text("Loading user...")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, AppSpacing.verticalPadding)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundDefault)
            }
        }
        .onAppear {
            if let appUser = authVM.currentAppUser {
                Task {
                    await viewModel.loadCategories(for: appUser)
                }
            }
        }
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
    
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 30) {
                    Button {
                        viewModel.prepareForAdding()
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)
                    }
                }
            }
        }

        .sheet(isPresented: $viewModel.showingAddCategory) {
            if let appUser = authVM.currentAppUser {
                AddCategoryView(viewModel: viewModel, user: appUser)
            }
        }
        .sheet(isPresented: $viewModel.showingEditCategory) {
            if let appUser = authVM.currentAppUser {
                EditCategoryView(viewModel: viewModel, user: appUser)
            }
        }
        .confirmationDialog(
            "Delete Category",
            isPresented: $viewModel.showDeletionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let appUser = authVM.currentAppUser {
                    Task {
                        await viewModel.confirmCategoryDeletion(for: appUser)
                    }
                }
            }

            Button("Cancel", role: .cancel) {
                viewModel.cancelCategoryDeletion()
            }
        } message: {
            Text(viewModel.confirmationMessage)
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
    }
}

// MARK: - Category Row View
struct CategoryRowView: View {
    let category: Category
    let viewModel: CategoryViewModel

    var body: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            // Category Icon
            Image(systemName: category.icon ?? "questionmark.circle.fill")
                .font(.title2)
                .foregroundColor(viewModel.getColorForCategory(category))
                .frame(width: 30)

            // Category Info
            VStack(alignment: .leading, spacing: 4) {
                Text(category.name ?? "Unknown")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)

                if category.isDefault {
                    Text("Default Category")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            // Edit Button
            Button {
                viewModel.prepareForEditing(category)
            }  label: {
                Image(systemName: AppIcons.pencilIcon)
                    .foregroundColor(AppColors.secondary)
                    .font(.system(size: 28, weight: .medium))
                    .padding(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.vertical, AppSpacing.verticalPadding)
        .padding(.horizontal, AppSpacing.horizontalPadding)
        .background(Color.white)
        .cornerRadius(AppSpacing.cornerRadius)
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}
