//
//  RecurringIncomeListView.swift
//  StudentExpenseTracker


import SwiftUI

struct RecurringIncomeListView: View {
    @Environment(AuthViewModel.self) private var authVM
    @State private var viewModel = RecurringIncomeViewModel()

    var body: some View {
        Group {
            if let appUser = authVM.currentAppUser {
                if viewModel.isLoading {
                    VStack {
                        ProgressView()
                            .tint(AppColors.primary)
                        Text("Loading recurring incomes...")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)
                            .padding(.top, AppSpacing.verticalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else if viewModel.recurringIncomes.isEmpty {
                    VStack(spacing: AppSpacing.verticalPadding) {
                        Image(systemName: "arrow.clockwise.circle")
                            .font(.system(size: 50))
                            .foregroundColor(AppColors.secondary)
                        Text("No recurring incomes found")
                            .font(AppFonts.subtitle)
                            .foregroundColor(AppColors.textPrimary)
                        Text("Set up recurring incomes to automate your budget")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppSpacing.horizontalPadding)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(AppColors.backgroundDefault)
                } else {
                    List {
                        ForEach(viewModel.recurringIncomes, id: \.id) { recurringIncome in
                            RecurringIncomeRowView(recurringIncome: recurringIncome, viewModel: viewModel)
                                .listRowBackground(AppColors.cardBackground)
                        }
                        .onDelete { indexSet in
                            Task {
                                for index in indexSet {
                                    let recurringIncome = viewModel.recurringIncomes[index]
                                    await viewModel.deleteRecurringIncome(recurringIncome, for: appUser)
                                }
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                    .background(AppColors.backgroundDefault)
                    .scrollContentBackground(.hidden)
                    .refreshable {
                        await viewModel.loadRecurringIncomes(for: appUser)
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
                    await viewModel.loadRecurringIncomes(for: appUser)
                }
            }
        }
        .navigationTitle("Recurring Incomes")
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
                        viewModel.showingAddRecurringIncome = true
                    } label: {
                        Image(systemName: "plus")
                            .foregroundColor(AppColors.primary)
                            .font(.title2)
                    }
                }
            }
        }

        .sheet(isPresented: $viewModel.showingAddRecurringIncome) {
            if let appUser = authVM.currentAppUser {
                AddRecurringIncomeView(viewModel: viewModel, user: appUser)
            }
        }
        .sheet(isPresented: $viewModel.showingEditRecurringIncome) {
            if let appUser = authVM.currentAppUser {
                EditRecurringIncomeView(viewModel: viewModel, user: appUser)
            }
        }
    }
}

// MARK: - RecurringIncomeRowView
struct RecurringIncomeRowView: View {
    let recurringIncome: RecurringIncome
    let viewModel: RecurringIncomeViewModel

    var body: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            Image(systemName: recurringIncome.icon ?? "dollarsign.circle")
                .font(.title2)
                .foregroundColor(getSystemColor(for: recurringIncome.color ?? "blue"))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(recurringIncome.source ?? "Recurring Income")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                    
                    Spacer()
                    
                    Text("$\(recurringIncome.amount?.doubleValue ?? 0, specifier: "%.2f")")
                        .font(AppFonts.body)
                        .fontWeight(.semibold)
                        .foregroundColor(AppColors.primary)
                }

                HStack(spacing: 8) {
                    Text(recurringIncome.isActive ? "Active" : "Inactive")
                        .font(AppFonts.small)
                        .foregroundColor(recurringIncome.isActive ? AppColors.primary : AppColors.textSecondary)
                    
                    if let frequency = recurringIncome.frequency {
                        Text("•")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(frequency.capitalized)
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    
                    if let category = recurringIncome.category {
                        Text("•")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        
                        Text(category.name ?? "Unknown")
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                    }
                }

                if let notes = recurringIncome.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }

            Spacer()

            Button {
                viewModel.setRecurringIncomeForEditing(recurringIncome)
                viewModel.showingEditRecurringIncome = true
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

// MARK: - DateFormatter Extension

extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        return formatter
    }()
}

//#Preview {
//    RecurringIncomeListView()
//        .environment(AuthViewModel())
//} 
