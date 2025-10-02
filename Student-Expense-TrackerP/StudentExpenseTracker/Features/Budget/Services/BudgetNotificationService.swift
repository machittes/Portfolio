//
//  BudgetNotificationService.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-06-25.
//

import Foundation
import UserNotifications

final class BudgetNotificationService {
    static let shared = BudgetNotificationService()

    private let budgetRepo = BudgetRepository()
    private let incomeRepo = IncomeRepository()
    private let expenseRepo = ExpenseRepository()

    private init() {}

    func evaluateBudgetLimit(for user: AppUser) async {
        let budgets = await budgetRepo.fetchActiveBudgets(for: user)
        guard let b = budgets.first, let rawStartDate = b.startDate else { return }
        let start = Calendar.current.startOfDay(for: rawStartDate)

     
        let incomeList = await incomeRepo.fetchIncomes(for: user, includeDeleted: false)
        let periodIncomes = incomeList.filter {
            guard let d = $0.date else { return false }
            return d >= start
        }
        let totalIncome = periodIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

   
        let threshold = Decimal(b.alertThreshold)
        let budgetAmount = totalIncome * threshold

      
        let expenseList = await expenseRepo.fetchExpenses(for: user, includeDeleted: false)
        let periodExpenses = expenseList.filter {
            guard let d = $0.date else { return false }
            return d >= start
        }
        let spent = periodExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

      
        let progress = budgetAmount > 0 ? (spent / budgetAmount) : 0
        if progress >= 1.0 {
            await scheduleNotification(period: b.period ?? "your")
        }
    }

    private func scheduleNotification(period: String) async {
        let content = UNMutableNotificationContent()
        content.title = "Budget Reached"
        content.body = "🚨 You have used 100% of your \(period) budget!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "budgetLimitReached", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Notification error:", error)
        }
    }
    
    func checkIfOverBudgetAndWarn(for user: AppUser) async {
        let budgets = await budgetRepo.fetchActiveBudgets(for: user)
        guard let b = budgets.first, let rawStartDate = b.startDate else { return }
        let start = Calendar.current.startOfDay(for: rawStartDate)

        // Sum live incomes
        let incomeList = await incomeRepo.fetchIncomes(for: user, includeDeleted: false)
        let periodIncomes = incomeList.filter {
            guard let d = $0.date else { return false }
            return d >= start
        }
        let totalIncome = periodIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

        // Compute budget amount from threshold
        let threshold = Decimal(b.alertThreshold)
        let budgetAmount = totalIncome * threshold

        // Sum live expenses in same period
        let expenseList = await expenseRepo.fetchExpenses(for: user, includeDeleted: false)
        let periodExpenses = expenseList.filter {
            guard let d = $0.date else { return false }
            return d >= start
        }
        let spent = periodExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

        // Warn if already over budget
        if spent > budgetAmount {
            await warnOverBudget(period: b.period ?? "your")
        }
    }

    private func warnOverBudget(period: String) async {
        let content = UNMutableNotificationContent()
        content.title = " ⚠️ Over Budget"
        content.body = "You've exceeded your \(period) budget. Still want to add more?"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "overBudgetWarning", content: content, trigger: trigger)

        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("Notification error:", error)
        }
    }
}
