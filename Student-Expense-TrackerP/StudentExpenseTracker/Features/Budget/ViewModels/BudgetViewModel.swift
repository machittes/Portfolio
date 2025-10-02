import Foundation
import SwiftUI
import UserNotifications

// MARK: – Notifications Extension
extension Notification.Name {
    static let didChangeIncomes = Notification.Name("didChangeIncomes")
    static let didChangeExpenses = Notification.Name("didChangeExpenses")
}

@Observable
class BudgetViewModel {
    private let budgetRepository: BudgetRepository
    private let incomeRepository: IncomeRepository
    private let expenseRepository: ExpenseRepository
    private var currentUser: AppUser?

    // MARK: – UI State
    var budgets: [Budget] = []
    var isLoading = false
    var errorMessage: String?

    var showingAddBudget = false
    var showDeletionConfirmation = false
    var confirmationMessage = ""
    private var pendingDeletionBudget: Budget?

    var budgetPercent = ""
    var budgetPeriod = "Monthly"
    var startDate = Date()
    var endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
    var selectedBudget: Budget?

    var spent: Decimal = .zero
    var remaining: Decimal = .zero
    var progress: Double = 0.0

    // MARK: – Init
    init(
        budgetRepository: BudgetRepository = BudgetRepository(),
        incomeRepository: IncomeRepository = IncomeRepository(),
        expenseRepository: ExpenseRepository = ExpenseRepository()
    ) {
        self.budgetRepository = budgetRepository
        self.incomeRepository = incomeRepository
        self.expenseRepository = expenseRepository

        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if let error = error {
                    print("Notification permission error:", error)
                }
            }

        NotificationCenter.default.addObserver(
            forName: .didChangeIncomes,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, let user = self.currentUser else { return }
            Task {
                await self.loadBudgets(for: user)
                await self.loadProgress(for: user)
            }
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: – Budget Management
    @MainActor
    func loadBudgets(for user: AppUser) async {
        currentUser = user
        isLoading = true
        errorMessage = nil
        budgets = await budgetRepository.fetchActiveBudgets(for: user)
        isLoading = false
    }

    @MainActor
    func setBudgetForEditing(_ budget: Budget) {
        selectedBudget = budget
        budgetPeriod  = budget.period ?? "Monthly"
        startDate     = budget.startDate ?? Date()
        endDate       = budget.endDate ?? Calendar.current.date(byAdding: .month, value: 1, to: startDate)!
        let pct       = budget.alertThreshold * 100
        budgetPercent = String(format: "%.0f", pct)
    }

    @MainActor
    func addBudget(for user: AppUser) async {
        currentUser = user
        guard let pct = Double(budgetPercent), pct > 0 else {
            errorMessage = "Please enter a valid percentage"
            return
        }

        async let incomes = incomeRepository.fetchIncomes(for: user, includeDeleted: false)
        let incomeList = await incomes
        let totalIncome = incomeList.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

        let factorDecimal = Decimal(pct) / Decimal(100)
        let amountDecimal = totalIncome * factorDecimal

        if let d = Calendar.current.date(byAdding: component(for: budgetPeriod), value: 1, to: startDate) {
            endDate = d
        }

        _ = await budgetRepository.createBudget(
            amount: amountDecimal,
            period: budgetPeriod,
            startDate: startDate,
            endDate: endDate,
            alertThreshold: pct/100,
            user: user
        )

        await loadBudgets(for: user)
        resetForm()
        showingAddBudget = false
    }

    @MainActor
    func updateBudget(for user: AppUser) async {
        currentUser = user
        guard let b = selectedBudget, let pct = Double(budgetPercent), pct > 0 else {
            errorMessage = "Please enter a valid percentage"
            return
        }

        async let incomes = incomeRepository.fetchIncomes(for: user, includeDeleted: false)
        let incomeList = await incomes
        let totalIncome = incomeList.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

        let factorDecimal = Decimal(pct) / Decimal(100)
        let amountDecimal = totalIncome * factorDecimal

        if let d = Calendar.current.date(byAdding: component(for: budgetPeriod), value: 1, to: startDate) {
            endDate = d
        }

        await budgetRepository.updateBudget(
            b,
            amount: amountDecimal,
            period: budgetPeriod,
            startDate: startDate,
            endDate: endDate,
            alertThreshold: pct/100
        )

        await loadBudgets(for: user)
        resetForm()
        showingAddBudget = false
    }

    @MainActor
    func deleteBudget(_ budget: Budget) {
        pendingDeletionBudget = budget
        confirmationMessage = "Delete this budget?"
        showDeletionConfirmation = true
    }

    @MainActor
    func confirmDeletion(for user: AppUser) async {
        guard let b = pendingDeletionBudget else { return }
        await budgetRepository.deleteBudget(b, deletedBy: user.userId)
        await loadBudgets(for: user)
        showDeletionConfirmation = false
        pendingDeletionBudget = nil
    }

    // MARK: – Budget Progress
    @MainActor
    func loadProgress(for user: AppUser) async {
        guard let b = budgets.first, let rawStartDate = b.startDate else { return }
        let start = Calendar.current.startOfDay(for: rawStartDate)

        async let incomes = incomeRepository.fetchIncomes(for: user, includeDeleted: false)
        let incomeList = await incomes
        let periodIncomes = incomeList.filter {
            guard let d = $0.date else { return false }
            return d >= start
        }
        let totalIncome = periodIncomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

        let threshold = Decimal(b.alertThreshold)
        let budgetAmount = totalIncome * threshold

        async let expenses = expenseRepository.fetchExpenses(for: user, includeDeleted: false)
        let expenseList = await expenses
        let periodExpenses = expenseList.filter {
            guard let d = $0.date else { return false }
            return d >= start
        }
        spent = periodExpenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? .zero) }

        remaining = budgetAmount - spent
        progress = budgetAmount > 0 ? NSDecimalNumber(decimal: spent / budgetAmount).doubleValue : 0

        b.amount = NSDecimalNumber(decimal: remaining)

        if progress >= 1.0 {
            scheduleBudgetLimitReachedNotification()
        }
    }

    // MARK: – Notification
    private func scheduleBudgetLimitReachedNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Budget Reached"
        content.body = "🚨 You have used 100% of your \(budgets.first?.period ?? "") budget!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "budgetLimitReached", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let err = error {
                print("Notification Error:", err)
            }
        }
    }

    // MARK: – Helpers
    private func component(for period: String) -> Calendar.Component {
        switch period.lowercased() {
        case "daily": return .day
        case "weekly": return .weekOfYear
        case "monthly": return .month
        case "yearly": return .year
        default: return .month
        }
    }

    private func resetForm() {
        budgetPercent = ""
        budgetPeriod = "Monthly"
        startDate = Date()
        endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date())!
        selectedBudget = nil
        errorMessage = nil
    }

    var isFormValid: Bool {
        Double(budgetPercent) != nil
    }
}
