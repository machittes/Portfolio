//  DashboardView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.

import SwiftUI

struct DashboardView: View {
    @Bindable var authVM: AuthViewModel
    @Environment(SyncManager.self) private var syncManager
    @State private var viewModel = DashboardViewModel()
    @State private var isSideMenuShowing = false

    // Helper computed properties for summary card
    private var balanceValue: Double {
        NSDecimalNumber(decimal: viewModel.periodTotalBalance).doubleValue
    }
    private var expenseValue: Double {
        NSDecimalNumber(decimal: viewModel.periodTotalExpense).doubleValue
    }
    private var percent: Decimal {
        let balance = viewModel.periodTotalBalance
        let expense = viewModel.periodTotalExpense
        return balance > 0 ? min(100, (expense / balance) * 100) : 0
    }
    private var percentInt: Int {
        Int(NSDecimalNumber(decimal: percent).doubleValue)
    }
    private var instruction: String {
        let balance = viewModel.periodTotalBalance
        let expense = viewModel.periodTotalExpense
        if expense >= balance && balance > 0 {
            return "Overspending alert!"
        } else if balance == 0 {
            return "No balance left, be careful!"
        } else {
            return "Looks Good."
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                ZStack(alignment: .bottom) {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Button(action: {
                                    withAnimation {
                                        isSideMenuShowing.toggle()
                                    }
                                }) {
                                    Image(systemName: "line.3.horizontal")
                                        .font(.title2)
                                        .foregroundColor(.blue)
                                }
                                VStack(alignment: .leading) {
                                    Text("Ready to go?")
                                        .padding(.leading, 16)
                                        .font(AppFonts.title)
                                    Text("Smart choices start here 💰")
                                        .padding(.leading, 16)
                                        .font(AppFonts.subtitle)
                                        .opacity(0.8)
                                }
                                Spacer()
                            }
                            .padding(.bottom)

                            VStack(spacing: 20) {
                                HStack(spacing: 30) {
                                    VStack(alignment: .leading) {
                                        Text("Total Balance")
                                            .font(AppFonts.body)
                                            .opacity(0.8)
                                        Text("$\(String(format: "%.2f", balanceValue))")
                                            .font(AppFonts.subtitle)
                                    }
                                    VStack(alignment: .leading) {
                                        Text("Total Expense")
                                            .font(AppFonts.body)
                                            .opacity(0.8)
                                        Text("-$\(String(format: "%.2f", expenseValue))")
                                            .font(AppFonts.subtitle)
                                            .foregroundColor(.blue)
                                    }
                                }
                                VStack(alignment: .leading, spacing: 8) {
                                    GeometryReader { geometry in
                                        let progressWidth = geometry.size.width * (NSDecimalNumber(decimal: percent).doubleValue / 100)
                                        ZStack(alignment: .leading) {
                                            Rectangle()
                                                .frame(width: geometry.size.width, height: 8)
                                                .opacity(0.1)
                                                .foregroundColor(.white)
                                            Rectangle()
                                                .frame(width: progressWidth, height: 8)
                                                .foregroundColor(.black)
                                        }
                                        .cornerRadius(4)
                                    }
                                    .frame(height: 8)
                                    HStack {
                                        Text("\(percentInt)% Of Your Expenses, \(instruction)")
                                            .font(AppFonts.body)
                                        Spacer()
                                        Text("$\(String(format: "%.2f", balanceValue))")
                                            .font(AppFonts.body)
                                    }
                                }
                            }
                            .padding()
                            .background(Color.white)
                            .cornerRadius(20)
                        }
                        .padding()
                        .background(AppColors.backgroundLight)
                        HStack {
                            ForEach(DashboardPeriod.allCases, id: \.rawValue) { period in
                                Button(action: {
                                    viewModel.selectedPeriod = period
                                }) {
                                    Text(period.title)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(viewModel.selectedPeriod == period ? AppColors.backgroundLight : Color.gray.opacity(0.1))
                                        .foregroundColor(viewModel.selectedPeriod == period ? .white : .black)
                                        .cornerRadius(20)
                                }
                            }
                        }
                        .padding()
                        ScrollView {
                            if viewModel.isLoading {
                                ProgressView()
                                    .padding()
                            } else if viewModel.filteredTransactions.isEmpty {
                                Text("No transactions found.")
                                    .foregroundColor(.gray)
                                    .padding()
                            } else {
                                VStack(spacing: 15) {
                                    ForEach(viewModel.filteredTransactions) { transaction in
                                        TransactionRow(transaction: transaction)
                                    }
                                }
                                .padding()
                            }
                        }
                        .background(AppColors.backgroundDefault)
                        .padding(.bottom, 80)
                    }
                }
                .disabled(isSideMenuShowing)
                .blur(radius: isSideMenuShowing ? 5 : 0)

                if isSideMenuShowing {
                    VStack(alignment: .leading, spacing: 30) {
                        Text("Buckit")
                            .font(AppFonts.title)
                            .padding(.top, 60)

                        NavigationLink(destination: CategoryListView()) {
                            Label("Category Manager", systemImage: "folder")
                                .foregroundColor(.black)
                        }

                        NavigationLink(destination: BudgetListView()) {
                            Label("Budget Notification", systemImage: "bell")
                                .foregroundColor(.black)
                        }

                        NavigationLink(destination: ProfileView(authVM: authVM)) {
                            Label("Profile Settings", systemImage: "person.crop.circle")
                                .foregroundColor(.black)
                        }

                        Divider()

                        Button {
                            Task {
                                if authVM.isAuthenticated {
                                    await syncManager.performFullSync()
                                }
                            }
                        } label: {
                            Label("Sync Data", systemImage: "arrow.triangle.2.circlepath")
                                .foregroundColor(.black)
                        }

                        Button {
                            Task {
                                do {
                                    try await syncManager.debugCompleteFirestoreReset()
                                } catch {
                                    print("Error deleting all data: \(error)")
                                }
                            }
                        } label: {
                            Label("Delete Remote Data", systemImage: "minus.circle.fill")
                                .foregroundColor(.red)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)
                    .frame(width: 250)
                    .background(AppColors.backgroundLight)
                    .edgesIgnoringSafeArea(.all)
                    .transition(.move(edge: .leading))
                }
            }
            .onTapGesture {
                if isSideMenuShowing {
                    withAnimation {
                        isSideMenuShowing = false
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            if let appUser = authVM.currentAppUser {
                await viewModel.loadDashboardData(for: appUser)
            }
        }
        .onChange(of: authVM.currentAppUser) { oldValue, newValue in
            if let appUser = newValue {
                Task {
                    await viewModel.loadDashboardData(for: appUser)
                }
            }
        }
        .refreshable {
            if let appUser = authVM.currentAppUser {
                await viewModel.loadDashboardData(for: appUser)
            }
        }
    }
}

struct TransactionRow: View {
    let transaction: DashboardTransaction

    var amountValue: Double {
        NSDecimalNumber(decimal: transaction.amount).doubleValue
    }
    var amountText: String {
        transaction.isExpense ? "-$\(String(format: "%.2f", amountValue))" : "$\(String(format: "%.2f", amountValue))"
    }
    var body: some View {
        HStack {
            Image(systemName: transaction.icon)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(transaction.color)
                .cornerRadius(10)
            VStack(alignment: .leading) {
                Text(transaction.title)
                    .font(AppFonts.body)
                Text(transaction.date, style: .date)
                    .font(AppFonts.small)
                    .foregroundColor(.gray)
            }
            Spacer()
            Text(amountText)
                .font(AppFonts.body)
                .foregroundColor(transaction.isExpense ? .red : .green)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}