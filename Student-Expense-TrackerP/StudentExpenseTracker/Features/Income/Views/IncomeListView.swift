//
//  IncomeListView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct IncomeListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = IncomeViewModel()

    var body: some View {
        VStack {
            if let appUser = authVM.currentAppUser {  // Ensure appUser is fetched correctly
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Loading incomes...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, AppSpacing.verticalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else if viewModel.incomes.isEmpty {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Image(systemName: "creditcard.fill")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondary)
                        Text("No incomes found")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Start tracking your incomes by adding your first one!")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.horizontalPadding * 2)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else {
                    List {
                        ForEach(viewModel.incomes, id: \.id) { income in
                            IncomeRowView(income: income, viewModel: viewModel)
                                .listRowBackground(AppColors.cardBackground)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let income = viewModel.incomes[index]
                                    await viewModel.deleteIncome(income, for: appUser)
                                }
                            }
                        }
                        
                        .onMove { source, destination in
                            Task {
                                var updatedIncomes = viewModel.incomes
                                updatedIncomes.move(fromOffsets: source, toOffset: destination)
                                await viewModel.reorderIncomes(updatedIncomes, for: appUser)
                            }
                        }

                    }
                    .listStyle(PlainListStyle())
                    .background(AppColors.backgroundDefault)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.loadIncomes(for: appUser)
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
            if let appUser = authVM.currentAppUser {  // Ensure appUser is available
                Task {
                    await viewModel.loadIncomes(for: appUser)
                }
            }
        }
        .navigationTitle("Incomes")
        .navigationBarTitleDisplayMode(.large)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 30) {
//                    EditButton()
//                        .foregroundColor(AppColors.primary)
//                        .font(.title2)

                    // Plus button
                    Button {
                        viewModel.showingAddIncome = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)
                    }
                }
            }
        }

      
        .sheet(isPresented: $viewModel.showingAddIncome) {
            // Passing appUser to AddIncomeView
            if let appUser = authVM.currentAppUser {
                AddIncomeView(viewModel: viewModel, user: appUser)
            }
        }
        .sheet(isPresented: $viewModel.showingEditIncome) {
            // Passing appUser to EditIncomeView
            if let appUser = authVM.currentAppUser {
                EditIncomeView(viewModel: viewModel, user: appUser)
            }
        }
        .alert(isPresented: $viewModel.showDeletionConfirmation) {
            Alert(
                title: Text("Delete Income"),
                message: Text(viewModel.confirmationMessage),
                primaryButton: .destructive(Text("Delete")) {
                    if let appUser = authVM.currentAppUser {
                        Task {
                            await viewModel.confirmIncomeDeletion(for: appUser)
                        }
                    }
                },
                secondaryButton: .cancel {
                    viewModel.cancelIncomeDeletion()
                }
            )
        }
        
        

    }
}





struct IncomeRowView: View {
    let income: Income
    let viewModel: IncomeViewModel

    var body: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            Image(systemName: income.icon ?? "creditcard.fill")
                .font(.title2)
                .foregroundColor(viewModel.getSystemColorForString(income.color ?? "blue"))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(income.source ?? "Unknown")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)

                    Text(income.isRecurring ? "Recurring" : "One-time")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                }

                HStack(spacing: 8) {
                

                    if let amount = income.amount?.doubleValue {
                        HStack(spacing: 4) {
                            Image(systemName: "dollarsign.circle")
                            Text(formatAmount(amount))
                        }
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let frequency = income.frequency, !frequency.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: frequencyIcon(for: frequency))
                            Text(frequency)
                        }
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                    }
                }

             
                if let notes = income.notes, !notes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                        Text(notes)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
                }
            }

            Spacer()

            Button {
                viewModel.setIncomeForEditing(income)
                viewModel.showingEditIncome = true
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

    private func frequencyIcon(for frequency: String) -> String {
        switch frequency.lowercased() {
        case "monthly": return "calendar.badge.plus"
        case "weekly": return "calendar.circle"
        case "yearly": return "calendar.badge.clock"
        default: return "calendar"
        }
    }
    
    private func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "\(amount)"
    }

}
