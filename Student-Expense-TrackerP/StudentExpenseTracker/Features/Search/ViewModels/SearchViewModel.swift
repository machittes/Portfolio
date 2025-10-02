//
//  SearchViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-28.
//

import Foundation
import SwiftUI

@Observable
class SearchViewModel {
    // Search filters
    var keyword: String = ""
    var selectedDate: Date? = nil
    var selectedCategory: Category? = nil
    var minAmount: Double? = nil
    var maxAmount: Double? = nil
    var filterRecurring: RecurringExpenseFilter = .all
    var dateFrom: Date? = nil
    var dateTo: Date? = nil

    // Results
    var budgetResults: [Budget] = []
    var expenseResults: [Expense] = []
    var incomeResults: [Income] = []

    // Loading state
    var isLoading: Bool = false
    var errorMessage: String? = nil

    // Recurring filter options
    enum RecurringExpenseFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case recurring = "Recurring Only"
        case oneTime = "One-Time Only"
        var id: String { self.rawValue }
    }

    // Repositories (assume injected or accessible)
    var budgetRepository: BudgetRepository = BudgetRepository()
    var expenseRepository: ExpenseRepository = ExpenseRepository()
    var incomeRepository: IncomeRepository = IncomeRepository()
    var recurringExpenseRepository: RecurringExpenseRepository = RecurringExpenseRepository()
    var categoryRepository: CategoryRepository = CategoryRepository()

    // Search function
    func performSearch(for user: AppUser) async {
        isLoading = true
        errorMessage = nil
        
        // Fetch all budgets and filter in Swift
        let allBudgets = await budgetRepository.fetchBudgets(for: user)
        budgetResults = allBudgets.filter { budget in
            // Keyword filter (period or category name)
            let matchesKeyword = keyword.isEmpty ||
                (budget.period?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (budget.category?.name?.localizedCaseInsensitiveContains(keyword) ?? false)
            // Date range filter (startDate and endDate)
            let matchesDateFrom = dateFrom == nil || 
                ((budget.startDate != nil && budget.startDate! >= dateFrom!) ||
                 (budget.endDate != nil && budget.endDate! >= dateFrom!))
            let matchesDateTo = dateTo == nil || 
                ((budget.startDate != nil && budget.startDate! <= dateTo!) ||
                 (budget.endDate != nil && budget.endDate! <= dateTo!))
            // Category filter
            let matchesCategory = selectedCategory == nil || budget.category == selectedCategory
            // Amount range filter
            let amount = budget.amount?.doubleValue ?? 0.0
            let matchesMin = minAmount == nil || amount >= minAmount!
            let matchesMax = maxAmount == nil || amount <= maxAmount!
            return matchesKeyword && matchesDateFrom && matchesDateTo && matchesCategory && matchesMin && matchesMax
        }

        // Fetch all expenses and filter in Swift
        var allExpenses = await expenseRepository.fetchExpenses(for: user)
        allExpenses = allExpenses.filter { expense in
            // Keyword filter (title, notes, or category name)
            let matchesKeyword = keyword.isEmpty ||
                (expense.title?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (expense.notes?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (expense.category?.name?.localizedCaseInsensitiveContains(keyword) ?? false)
            // Date range filter
            let matchesDateFrom = dateFrom == nil || (expense.date != nil && expense.date! >= dateFrom!)
            let matchesDateTo = dateTo == nil || (expense.date != nil && expense.date! <= dateTo!)
            // Category filter
            let matchesCategory = selectedCategory == nil || expense.category == selectedCategory
            // Amount range filter
            let amount = expense.amount?.doubleValue ?? 0.0
            let matchesMin = minAmount == nil || amount >= minAmount!
            let matchesMax = maxAmount == nil || amount <= maxAmount!
            return matchesKeyword && matchesDateFrom && matchesDateTo && matchesCategory && matchesMin && matchesMax
        }
        // Recurring filter
        switch filterRecurring {
        case .recurring:
            allExpenses = allExpenses.filter { $0.recurringExpense != nil }
        case .oneTime:
            allExpenses = allExpenses.filter { $0.recurringExpense == nil }
        case .all:
            break
        }
        expenseResults = allExpenses

        // Fetch all incomes and filter in Swift
        var allIncomes = await incomeRepository.fetchIncomes(for: user)
        allIncomes = allIncomes.filter { income in
            // Keyword filter (source or notes)
            let matchesKeyword = keyword.isEmpty ||
                (income.source?.localizedCaseInsensitiveContains(keyword) ?? false) ||
                (income.notes?.localizedCaseInsensitiveContains(keyword) ?? false)
            // Date range filter
            let matchesDateFrom = dateFrom == nil || (income.date != nil && income.date! >= dateFrom!)
            let matchesDateTo = dateTo == nil || (income.date != nil && income.date! <= dateTo!)
            // Amount range filter
            let amount = income.amount?.doubleValue ?? 0.0
            let matchesMin = minAmount == nil || amount >= minAmount!
            let matchesMax = maxAmount == nil || amount <= maxAmount!
            return matchesKeyword && matchesDateFrom && matchesDateTo && matchesMin && matchesMax
        }
        // Recurring filter for incomes
        switch filterRecurring {
        case .recurring:
            allIncomes = allIncomes.filter { $0.isRecurring }
        case .oneTime:
            allIncomes = allIncomes.filter { !$0.isRecurring }
        case .all:
            break
        }
        incomeResults = allIncomes
        
        isLoading = false
    }
}
