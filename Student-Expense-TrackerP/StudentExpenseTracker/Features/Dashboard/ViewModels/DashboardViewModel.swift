//
//  DashboardViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import Foundation
import SwiftUI

enum DashboardPeriod: Int, CaseIterable {
    case daily, weekly, monthly
    var title: String {
        switch self {
        case .daily: return "Daily"
        case .weekly: return "Weekly"
        case .monthly: return "Monthly"
        }
    }
}

@Observable
class DashboardViewModel {
    var transactions: [DashboardTransaction] = []
    var totalBalance: Decimal = 0
    var totalExpense: Decimal = 0
    var isLoading: Bool = false
    var selectedPeriod: DashboardPeriod = .monthly

    private let incomeRepo = IncomeRepository()
    private let expenseRepo = ExpenseRepository()

    func loadDashboardData(for user: AppUser) async {
        isLoading = true
        async let incomes = incomeRepo.fetchIncomes(for: user, includeDeleted: false)
        async let expenses = expenseRepo.fetchExpenses(for: user, includeDeleted: false)
        let (incomeList, expenseList) = await (incomes, expenses)

        // Map incomes and expenses to a common DashboardTransaction type
        let incomeTransactions = incomeList.map { DashboardTransaction.fromIncome($0) }
        let expenseTransactions = expenseList.map { DashboardTransaction.fromExpense($0) }
        let allTransactions = (incomeTransactions + expenseTransactions).sorted { $0.date > $1.date }
        self.transactions = allTransactions
        self.totalBalance = incomeList.reduce(0) { $0 + ($1.amount as Decimal? ?? 0) }
        self.totalExpense = expenseList.reduce(0) { $0 + ($1.amount as Decimal? ?? 0) }
        isLoading = false
    }

    var filteredTransactions: [DashboardTransaction] {
        let now = Date()
        let calendar = Calendar.current
        switch selectedPeriod {
        case .daily:
            return transactions.filter { calendar.isDate($0.date, inSameDayAs: now) }
        case .weekly:
            guard let weekAgo = calendar.date(byAdding: .day, value: -6, to: now) else { return transactions }
            return transactions.filter { $0.date >= weekAgo && $0.date <= now }
        case .monthly:
            guard let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) else { return transactions }
            return transactions.filter { $0.date >= monthAgo && $0.date <= now }
        }
    }

    var periodTotalBalance: Decimal {
        filteredTransactions.filter { !$0.isExpense }.reduce(0) { $0 + $1.amount }
    }
    var periodTotalExpense: Decimal {
        filteredTransactions.filter { $0.isExpense }.reduce(0) { $0 + $1.amount }
    }
}

struct DashboardTransaction: Identifiable {
    let id: UUID
    let icon: String
    let title: String
    let color: Color?
    let date: Date
    let amount: Decimal
    let isExpense: Bool
    let category: String?

    static func fromIncome(_ income: Income) -> DashboardTransaction {
        DashboardTransaction(
            id: income.id ?? UUID(),
            icon: income.icon ?? "dollarsign.circle.fill",
            title: income.source ?? "Income",
            color: getSystemColorForString(income.color ?? "gray"),
            date: income.date ?? Date(),
            amount: income.amount as Decimal? ?? 0,
            isExpense: false,
            category: nil
        )
    }
    static func fromExpense(_ expense: Expense) -> DashboardTransaction {
        DashboardTransaction(
            id: expense.id ?? UUID(),
            icon: expense.icon ?? "creditcard.fill",
            title: expense.title ?? "Expense",
            color: getSystemColorForString(expense.color ?? "gray"),
            date: expense.date ?? Date(),
            amount: expense.amount as Decimal? ?? 0,
            isExpense: true,
            category: expense.category?.name
        )
    }
    
    static func getSystemColorForString(_ colorString: String) -> Color {
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
        case "gray": return .gray
        default: return .blue
        }
    }
    
}

//#Preview {
//    DashboardViewModel()
//}
