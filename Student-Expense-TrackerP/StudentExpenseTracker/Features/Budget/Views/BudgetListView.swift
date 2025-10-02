//
//  BudgetListView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-06-18.
//

import SwiftUI

struct BudgetListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = BudgetViewModel()

    var body: some View {
        VStack {
            if let user = authVM.currentAppUser {
                if viewModel.isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(AppColors.primary)
                        Text("Loading budget…")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.primary)
                    .cornerRadius(30)
                    .padding(.horizontal, AppSpacing.horizontalPadding)
                    .padding(.vertical)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                } else if viewModel.budgets.isEmpty {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondary)
                        Text("No Budget Yet")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Tap the '+' icon to set your first budget.")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }

                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .cornerRadius(30)
                    .padding(.horizontal, AppSpacing.horizontalPadding)
                    .padding(.vertical)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                } else {
                    let budget = viewModel.budgets[0]
                    VStack(spacing: 30) {
                        Text(budget.budgetSummary)
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)

                        ProgressView(value: viewModel.progress) {
                            Text("\(Int(viewModel.progress * 100))% used")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textSecondary)
                        }
                        .scaleEffect(1.1)
                        .tint(AppColors.secondary)

                        HStack {
                            Text("Spent: $\(viewModel.spent.description)")
                            Spacer()
                            Text("Left: $\(viewModel.remaining.description)")
                        }
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textSecondary)

                        HStack {
                            Button(role: .destructive) {
                                viewModel.deleteBudget(budget)
                            } label: {
                                Label("Delete", systemImage: "trash")
                                    .font(AppFonts.body)
                            }

                            Spacer()

                            Button {
                                viewModel.setBudgetForEditing(budget)
                                viewModel.showingAddBudget = true
                            } label: {
                                Label("Edit", systemImage: AppIcons.pencilIcon)
                                    .font(AppFonts.body)
                            }
                        }
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white)
                    .cornerRadius(30)
                    .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
                    .padding(.horizontal, AppSpacing.horizontalPadding)
                    .padding(.vertical)
                    .alert(viewModel.confirmationMessage, isPresented: $viewModel.showDeletionConfirmation) {
                        Button("Delete", role: .destructive) {
                            Task { await viewModel.confirmDeletion(for: user) }
                        }
                        Button("Cancel", role: .cancel) {
                            viewModel.showDeletionConfirmation = false
                        }
                    }
                    .task {
                        await viewModel.loadProgress(for: user)
                    }
                }
            } else {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(Color.white)
                    Text("Loading user…")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.primary)
                .cornerRadius(30)
                .padding(.horizontal, AppSpacing.horizontalPadding)
                .padding(.vertical)
                .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
            }
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
        .onAppear {
            if let user = authVM.currentAppUser {
                Task {
                    await viewModel.loadBudgets(for: user)
                    await viewModel.loadProgress(for: user)
                }
            }
        }
        .navigationTitle("Budget")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
        
            ToolbarItem(placement: .navigationBarTrailing) {
                if viewModel.budgets.isEmpty {
                    Button {
                        viewModel.selectedBudget = nil
                        viewModel.showingAddBudget = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)
                    }
                } else {
                    Button {
                        if let existing = viewModel.budgets.first {
                            viewModel.setBudgetForEditing(existing)
                            viewModel.showingAddBudget = true
                        }
                    } label: {
                        Image(systemName: AppIcons.pencilIcon)
                            .foregroundColor(AppColors.secondary)
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddBudget) {
            if let user = authVM.currentAppUser {
                SetBudgetView(viewModel: viewModel, user: user)
            }
        }
    }
}
