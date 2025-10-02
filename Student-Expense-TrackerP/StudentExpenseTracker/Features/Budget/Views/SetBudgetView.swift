//
//  SetBudgetView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-06-18.
//

import SwiftUI

struct SetBudgetView: View {
    @Bindable var viewModel: BudgetViewModel
    let user: AppUser
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(
                    header: Text("Define your budget")
                        .font(AppFonts.subtitle)
                        .foregroundColor(AppColors.textPrimary)
                ) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("% of Income")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                        TextField("Enter %", text: $viewModel.budgetPercent)
                            .keyboardType(.decimalPad)
                            .font(AppFonts.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Period")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                        Picker("", selection: $viewModel.budgetPeriod) {
                            Text("Daily").tag("Daily")
                            Text("Weekly").tag("Weekly")
                            Text("Monthly").tag("Monthly")
                            Text("Yearly").tag("Yearly")
                        }
                        .pickerStyle(.segmented)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Start Date")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                        DatePicker("", selection: $viewModel.startDate, displayedComponents: .date)
                            .labelsHidden()
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("End Date")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                        DatePicker("", selection: $viewModel.endDate, displayedComponents: .date)
                            .labelsHidden()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(viewModel.selectedBudget == nil ? "Add Budget" : "Edit Budget")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(AppColors.textSecondary)
                        .font(AppFonts.body)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            if viewModel.selectedBudget == nil {
                                await viewModel.addBudget(for: user)
                            } else {
                                await viewModel.updateBudget(for: user)
                            }
                            dismiss()
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
                    )                }
            }
            .background(AppColors.backgroundDefault.ignoresSafeArea())
        }
        .onAppear {
            if let b = viewModel.selectedBudget {
                viewModel.setBudgetForEditing(b)
            }
        }
    }
}
