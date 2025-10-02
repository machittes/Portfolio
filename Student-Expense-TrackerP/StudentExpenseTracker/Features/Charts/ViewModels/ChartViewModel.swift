//
//  ChartViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-28.
//

import Foundation
import SwiftUI

// MARK: - Chart Data Models

struct ChartDataPoint: Identifiable {
    let id = UUID()
    let day: String
    let amount: Double
    let isIncome: Bool
    let date: Date
}

struct PeriodSummary {
    let totalIncome: Decimal
    let totalExpenses: Decimal
    let totalBalance: Decimal
    let incomeCount: Int
    let expenseCount: Int
    let netFlow: Decimal
    
    var balanceChange: Double {
        let previous = Decimal(20000) // Mock previous balance
        return ((totalBalance - previous) / previous * 100).doubleValue
    }
    
    var balanceChangeText: String {
        let change = balanceChange
        let sign = change >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.0f", change))%"
    }
}

enum ChartPeriod: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"
    case yearly = "Year"
    
    var title: String {
        return self.rawValue
    }
}

enum ChartType: String, CaseIterable {
    case bar = "bar"
    case line = "line"
    case pie = "pie"
    
    var displayName: String {
        switch self {
        case .bar: return "Bar Chart"
        case .line: return "Line Chart"
        case .pie: return "Pie Chart"
        }
    }
    
    var icon: String {
        switch self {
        case .bar: return "chart.bar.fill"
        case .line: return "chart.line.uptrend.xyaxis"
        case .pie: return "chart.pie.fill"
        }
    }
}

// MARK: - ChartViewModel

@Observable
class ChartViewModel {
    private let expenseRepository: ExpenseRepository
    private let incomeRepository: IncomeRepository
    private let categoryRepository: CategoryRepository
    private let userRepository: UserRepository
    
    // MARK: - Published Properties for UI
    
    var expenses: [Expense] = []
    var incomes: [Income] = []
    var categories: [Category] = []
    var chartData: [ChartDataPoint] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    
    // MARK: - Chart Configuration
    
    var selectedPeriod: ChartPeriod = .daily
    var selectedChartType: ChartType = .bar
    var dateRange = Calendar.current.dateInterval(of: .weekOfYear, for: Date()) ?? DateInterval(start: Date(), end: Date())
    
    // MARK: - Computed Properties
    
    var periodSummary: PeriodSummary {
        let filteredExpenses = getFilteredExpenses()
        let filteredIncomes = getFilteredIncomes()
        
        let totalExpenses = filteredExpenses.reduce(Decimal.zero) { sum, expense in
            sum + (expense.amount?.decimalValue ?? Decimal.zero)
        }

        let totalIncome = filteredIncomes.reduce(Decimal.zero) { sum, income in
            sum + (income.amount?.decimalValue ?? Decimal.zero)
        }
        
        let totalBalance = totalIncome - totalExpenses
        let netFlow = totalIncome - totalExpenses
        
        return PeriodSummary(
            totalIncome: totalIncome,
            totalExpenses: totalExpenses,
            totalBalance: totalBalance,
            incomeCount: filteredIncomes.count,
            expenseCount: filteredExpenses.count,
            netFlow: netFlow
        )
    }
    
    var formattedTotalBalance: String {
        return "$\(String(format: "%.2f", periodSummary.totalBalance.doubleValue))"
    }
    
    var formattedTotalExpenses: String {
        return "-$\(String(format: "%.2f", periodSummary.totalExpenses.doubleValue))"
    }
    
    var formattedTotalIncome: String {
        return "$\(String(format: "%.2f", periodSummary.totalIncome.doubleValue))"
    }
    
    // MARK: - Initialization
    
    init(expenseRepository: ExpenseRepository = ExpenseRepository(),
         incomeRepository: IncomeRepository = IncomeRepository(),
         categoryRepository: CategoryRepository = CategoryRepository(),
         userRepository: UserRepository = UserRepository()) {
        self.expenseRepository = expenseRepository
        self.incomeRepository = incomeRepository
        self.categoryRepository = categoryRepository
        self.userRepository = userRepository
        
        updateDateRangeForPeriod()
    }
    
    // MARK: - Data Loading
    
    @MainActor
    func loadData(for user: AppUser) async {
        isLoading = true
        errorMessage = nil
        
        async let expensesTask = expenseRepository.fetchExpenses(for: user, includeDeleted: false)
        async let incomesTask = incomeRepository.fetchIncomes(for: user, includeDeleted: false)
        async let categoriesTask = categoryRepository.fetchCategories(for: user)
        
        do {
            expenses = await expensesTask
            incomes = await incomesTask
            categories = await categoriesTask
            
            generateChartData()
        } catch {
            errorMessage = "Failed to load chart data: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    @MainActor
    func refreshData(for user: AppUser) async {
        await loadData(for: user)
    }
    
    // MARK: - Period Management
    
    func updateSelectedPeriod(_ period: ChartPeriod) {
        selectedPeriod = period
        updateDateRangeForPeriod()
        generateChartData()
    }
    
    private func updateDateRangeForPeriod() {
        let calendar = Calendar.current
        let now = Date()
        
        switch selectedPeriod {
        case .daily:
            dateRange = calendar.dateInterval(of: .weekOfYear, for: now) ?? DateInterval(start: now, end: now)
        case .weekly:
            dateRange = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, end: now)
        case .monthly:
            let startOfYear = calendar.dateInterval(of: .year, for: now)?.start ?? now
            dateRange = DateInterval(start: startOfYear, end: now)
        case .yearly:
            let startDate = calendar.date(byAdding: .year, value: -3, to: now) ?? now
            dateRange = DateInterval(start: startDate, end: now)
        }
    }
    
    // MARK: - Data Filtering
    
    private func getFilteredExpenses() -> [Expense] {
        return expenses.filter { expense in
            guard let expenseDate = expense.date else { return false }
            return dateRange.contains(expenseDate)
        }
    }
    
    private func getFilteredIncomes() -> [Income] {
        return incomes.filter { income in
            guard let incomeDate = income.date else { return false }
            return dateRange.contains(incomeDate)
        }
    }
    
    // MARK: - Chart Data Generation
    
    private func generateChartData() {
        let calendar = Calendar.current
        var dataPoints: [ChartDataPoint] = []
        
        switch selectedPeriod {
        case .daily:
            dataPoints = generateDailyData(calendar: calendar)
        case .weekly:
            dataPoints = generateWeeklyData(calendar: calendar)
        case .monthly:
            dataPoints = generateMonthlyData(calendar: calendar)
        case .yearly:
            dataPoints = generateYearlyData(calendar: calendar)
        }
        
        chartData = dataPoints
    }
    
    private func generateDailyData(calendar: Calendar) -> [ChartDataPoint] {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "EEE"
        
        var dataPoints: [ChartDataPoint] = []
        var currentDate = dateRange.start
        
        while currentDate <= dateRange.end {
            let dayExpenses = getFilteredExpenses().filter { expense in
                guard let expenseDate = expense.date else { return false }
                return calendar.isDate(expenseDate, inSameDayAs: currentDate)
            }
            
            let dayIncomes = getFilteredIncomes().filter { income in
                guard let incomeDate = income.date else { return false }
                return calendar.isDate(incomeDate, inSameDayAs: currentDate)
            }
            
            let expenseTotal = dayExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }
            let incomeTotal = dayIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }

            let dayLabel = dateFormatter.string(from: currentDate)
            
            if incomeTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: dayLabel,
                    amount: incomeTotal.doubleValue,
                    isIncome: true,
                    date: currentDate
                ))
            }
            
            if expenseTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: dayLabel,
                    amount: expenseTotal.doubleValue,
                    isIncome: false,
                    date: currentDate
                ))
            }
            
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
    }
    
    private func generateWeeklyData(calendar: Calendar) -> [ChartDataPoint] {
        var dataPoints: [ChartDataPoint] = []
        var currentDate = dateRange.start
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM dd"
        
        while currentDate <= dateRange.end {
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: currentDate) else {
                currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
                continue
            }
            
            let weekExpenses = getFilteredExpenses().filter { expense in
                guard let expenseDate = expense.date else { return false }
                return weekInterval.contains(expenseDate)
            }
            
            let weekIncomes = getFilteredIncomes().filter { income in
                guard let incomeDate = income.date else { return false }
                return weekInterval.contains(incomeDate)
            }
            
            let expenseTotal = weekExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }
            let incomeTotal = weekIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }

            let weekLabel = dateFormatter.string(from: weekInterval.start)
            
            if incomeTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: weekLabel,
                    amount: incomeTotal.doubleValue,
                    isIncome: true,
                    date: weekInterval.start
                ))
            }
            
            if expenseTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: weekLabel,
                    amount: expenseTotal.doubleValue,
                    isIncome: false,
                    date: weekInterval.start
                ))
            }
            
            currentDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
    }
    
    private func generateMonthlyData(calendar: Calendar) -> [ChartDataPoint] {
        var dataPoints: [ChartDataPoint] = []
        var currentDate = dateRange.start
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MMM"
        
        while currentDate <= dateRange.end {
            guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else {
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
                continue
            }
            
            let monthExpenses = getFilteredExpenses().filter { expense in
                guard let expenseDate = expense.date else { return false }
                return monthInterval.contains(expenseDate)
            }
            
            let monthIncomes = getFilteredIncomes().filter { income in
                guard let incomeDate = income.date else { return false }
                return monthInterval.contains(incomeDate)
            }
            
            let expenseTotal = monthExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }
            let incomeTotal = monthIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }

            let monthLabel = dateFormatter.string(from: monthInterval.start)
            
            if incomeTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: monthLabel,
                    amount: incomeTotal.doubleValue,
                    isIncome: true,
                    date: monthInterval.start
                ))
            }
            
            if expenseTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: monthLabel,
                    amount: expenseTotal.doubleValue,
                    isIncome: false,
                    date: monthInterval.start
                ))
            }
            
            currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
    }
    
    private func generateYearlyData(calendar: Calendar) -> [ChartDataPoint] {
        var dataPoints: [ChartDataPoint] = []
        var currentDate = dateRange.start
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy"
        
        while currentDate <= dateRange.end {
            guard let yearInterval = calendar.dateInterval(of: .year, for: currentDate) else {
                currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
                continue
            }
            
            let yearExpenses = getFilteredExpenses().filter { expense in
                guard let expenseDate = expense.date else { return false }
                return yearInterval.contains(expenseDate)
            }
            
            let yearIncomes = getFilteredIncomes().filter { income in
                guard let incomeDate = income.date else { return false }
                return yearInterval.contains(incomeDate)
            }
            
            let expenseTotal = yearExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }
            let incomeTotal = yearIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }

            let yearLabel = dateFormatter.string(from: yearInterval.start)
            
            if incomeTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: yearLabel,
                    amount: incomeTotal.doubleValue,
                    isIncome: true,
                    date: yearInterval.start
                ))
            }
            
            if expenseTotal > 0 {
                dataPoints.append(ChartDataPoint(
                    day: yearLabel,
                    amount: expenseTotal.doubleValue,
                    isIncome: false,
                    date: yearInterval.start
                ))
            }
            
            currentDate = calendar.date(byAdding: .year, value: 1, to: currentDate) ?? currentDate
        }
        
        return dataPoints
    }
    
    // MARK: - Category Analysis
    
    func getExpensesByCategory() -> [(Category, Decimal)] {
        let filteredExpenses = getFilteredExpenses()
        var categoryTotals: [UUID: Decimal] = [:]
        var categoryMap: [UUID: Category] = [:]
        
        for expense in filteredExpenses {
            guard let category = expense.category else { continue }
            let categoryId = category.id ?? UUID()
            
            categoryTotals[categoryId, default: Decimal.zero] += expense.amount?.decimalValue ?? Decimal.zero
            categoryMap[categoryId] = category
        }
        
        return categoryTotals.compactMap { (categoryId, total) in
            guard let category = categoryMap[categoryId] else { return nil }
            return (category, total)
        }.sorted { $0.1 > $1.1 }
    }
    
    // MARK: - Utility Methods
    
    func getColorForCategory(_ category: Category) -> Color {
        switch category.color {
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
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
    
    private func showErrorMessage(_ message: String) {
        errorMessage = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.errorMessage = nil
        }
    }
}

// MARK: - Extensions

extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}
