//
//  RecurringExpenseListView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct RecurringExpenseListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = RecurringExpenseViewModel()

    var body: some View {
        Group {
            if let appUser = authVM.currentAppUser {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Loading recurring expenses...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, AppSpacing.verticalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else if viewModel.recurringExpenses.isEmpty {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondary)
                        Text("No recurring expenses found")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Set up recurring expenses to automate your budget")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.horizontalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else {
                    List {
                        ForEach(viewModel.recurringExpenses, id: \.id) { recurringExpense in
                            RecurringExpenseRowView(recurringExpense: recurringExpense, viewModel: viewModel)
                                .listRowBackground(AppColors.cardBackground)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let recurringExpense = viewModel.recurringExpenses[index]
                                    await viewModel.deleteRecurringExpense(recurringExpense, for: appUser)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(AppColors.backgroundDefault)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.loadRecurringExpenses(for: appUser)
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
                    await viewModel.loadRecurringExpenses(for: appUser)
                }
            }
        }
        .navigationTitle("Recurring Expenses")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 30) {
//                    EditButton()
//                        .foregroundColor(AppColors.primary)
//                        .font(.title2)

                    Button {
                        viewModel.showingAddRecurringExpense = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)
                    }
                }
            }
        }

        .sheet(isPresented: $viewModel.showingAddRecurringExpense) {
            if let appUser = authVM.currentAppUser {
                AddRecurringView(viewModel: viewModel, user: appUser)
            }
        }
        .sheet(isPresented: $viewModel.showingEditRecurringExpense) {
            if let appUser = authVM.currentAppUser {
                EditRecurringView(viewModel: viewModel, user: appUser)
            }
        }
    }
}

// MARK: - RecurringExpenseRowView
struct RecurringExpenseRowView: View {
    let recurringExpense: RecurringExpense
    let viewModel: RecurringExpenseViewModel

    var body: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            Image(systemName: recurringExpense.icon ?? "arrow.clockwise.circle")
                .font(.title2)
                .foregroundColor(getSystemColor(for: recurringExpense.color ?? "blue"))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recurringExpense.title ?? "Recurring Expense")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text("$\(recurringExpense.amount?.doubleValue ?? 0, specifier: "%.2f")")
                        .font(AppFonts.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.error)
                }

                HStack(spacing: 8) {
                    Text(recurringExpense.isActive ? "Active" : "Inactive")
                        .font(AppFonts.small)
                        .foregroundColor(recurringExpense.isActive ? AppColors.primary : AppColors.textSecondary)
                    
                    if let frequency = recurringExpense.frequency {
                        Text("•")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(frequency.capitalized)
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let category = recurringExpense.category {
                        Text("•")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(category.name ?? "Unknown")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if let notes = recurringExpense.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            Button {
                viewModel.setRecurringExpenseForEditing(recurringExpense)
                viewModel.showingEditRecurringExpense = true
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
    
    private func getSystemColor(for colorString: String) -> Color {
        switch colorString.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "orange": return .orange
        case "purple": return .purple
        case "pink": return .pink
        case "yellow": return .yellow
        case "indigo": return .indigo
        case "teal": return .teal
        case "mint": return .mint
        case "cyan": return .cyan
        case "brown": return .brown
        default: return .blue
        }
    }
}

#Preview {
    RecurringExpenseListView()
        .environment(AuthViewModel())
}
