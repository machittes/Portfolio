//
//  ExpenseListView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct ExpenseListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = ExpenseViewModel()

    var body: some View {
        VStack {
            if let appUser = authVM.currentAppUser {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Loading expenses...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, AppSpacing.verticalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else if viewModel.expenses.isEmpty {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondary)
                        Text("No expenses found")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Start tracking your expenses by adding your first one!")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.horizontalPadding * 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else {
                    List {
                        ForEach(viewModel.expenses, id: \.id) { expense in
                            ExpenseRowView(expense: expense, viewModel: viewModel)
                                .listRowBackground(AppColors.cardBackground)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let expense = viewModel.expenses[index]
                                    await viewModel.deleteExpense(expense, for: appUser)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(AppColors.backgroundDefault)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.loadExpenses(for: appUser)
                        await viewModel.loadCategories(for: appUser)
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
                    await viewModel.loadExpenses(for: appUser)
                    await viewModel.loadCategories(for: appUser)
                }
            }
        }
        .navigationTitle("Expenses")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 30) {
                    Button {
                        viewModel.showingAddExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showingAddExpense) {
            if let appUser = authVM.currentAppUser {
                AddExpenseView(viewModel: viewModel, user: appUser)
            }
        }
        .sheet(isPresented: $viewModel.showingEditExpense) {
            if let appUser = authVM.currentAppUser {
                EditExpenseView(viewModel: viewModel, user: appUser)
            }
        }
        .alert(isPresented: $viewModel.showDeletionConfirmation) {
            Alert(
                title: Text("Delete Expense").font(AppFonts.subtitle),
                message: Text(viewModel.confirmationMessage).font(AppFonts.body),
                primaryButton: .destructive(Text("Delete").font(AppFonts.body)) {
                    if let appUser = authVM.currentAppUser {
                        Task {
                            await viewModel.confirmExpenseDeletion(for: appUser)
                        }
                    }
                },
                secondaryButton: .cancel {
                    viewModel.cancelExpenseDeletion()
                }
            )
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage).font(AppFonts.body)
            }
        }
    }
}

struct ExpenseRowView: View {
    let expense: Expense
    let viewModel: ExpenseViewModel

    var body: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            Image(systemName: expense.icon ?? "creditcard.fill")
                .font(.title2)
                .foregroundColor(viewModel.getSystemColorForString(expense.color ?? "gray"))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(expense.title ?? "Expense")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text("$\(expense.amount?.doubleValue ?? 0, specifier: "%.2f")")
                        .font(AppFonts.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.error)
                }

                HStack(spacing: 8) {
                    Text(expense.isRecurring ? "Recurring" : "One-time")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                    
                    if let date = expense.date {
                        Text("•")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(date, style: .date)
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let category = expense.category {
                        Text("•")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(category.name ?? "Unknown")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }
            }

            Spacer()

            Button {
                viewModel.setExpenseForEditing(expense)
                viewModel.showingEditExpense = true
            } label: {
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
