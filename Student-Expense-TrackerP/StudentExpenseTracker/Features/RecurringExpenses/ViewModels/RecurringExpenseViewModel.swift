//
//  RecurringExpenseViewModel.swift
//  StudentExpenseTracker


import Foundation
import SwiftUI

@Observable
class RecurringExpenseViewModel {
    private let recurringExpenseRepository: RecurringExpenseRepository
    private let categoryRepository: CategoryRepository
    private let userRepository: UserRepository
    
    // MARK: - Properties
    
    var recurringExpenses: [RecurringExpense] = []
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    
    // MARK: - UI State
    
    var showingAddRecurringExpense = false
    var showingEditRecurringExpense = false
    var selectedRecurringExpense: RecurringExpense?
    
    // MARK: - Form Fields
    
    var title = ""
    var amount = ""
    var frequency = "Monthly"
    var startDate = Date()
    var endDate: Date?
    var hasEndDate = false
    var dayOfMonthWeek: Int = 0
    var notes = ""
    var isActive = true
    var selectedCategoryId: UUID?
    var color = "blue"
    var icon = "arrow.clockwise.circle"
    
    // MARK: - Available Options
    
    let availableFrequencies = ["Daily", "Weekly", "Monthly", "Yearly"]
    let availableIcons = [
        "arrow.clockwise.circle", "creditcard.fill", "house.fill", "car.fill",
        "gamecontroller.fill", "fork.knife", "pill.fill", "graduationcap.fill",
        "gift.fill", "fuelpump.fill"
    ]
    let availableColors = [
        "red", "blue", "green", "orange", "purple", "pink",
        "yellow", "indigo", "teal", "mint", "cyan", "brown"
    ]
    
    // MARK: - Computed Properties
    
    var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryId }
    }
    
    var formattedEndDate: Date {
        endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? Date()
    }
    
    var isFormValid: Bool {
        return !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !amount.isEmpty &&
               Double(amount) != nil &&
               Double(amount)! > 0 &&
               (!hasEndDate || endDate == nil || endDate! > startDate)
    }
    
    // MARK: - Initialization
    
    init(recurringExpenseRepository: RecurringExpenseRepository = RecurringExpenseRepository(),
         categoryRepository: CategoryRepository = CategoryRepository(),
         userRepository: UserRepository = UserRepository()) {
        self.recurringExpenseRepository = recurringExpenseRepository
        self.categoryRepository = categoryRepository
        self.userRepository = userRepository
    }
    
    // MARK: - Data Loading
    
    @MainActor
    func loadRecurringExpenses(for user: AppUser) async {
        isLoading = true
        errorMessage = nil
        
        recurringExpenses = await recurringExpenseRepository.fetchRecurringExpenses(for: user)
        
        isLoading = false
    }
    
    @MainActor
    func loadCategories(for user: AppUser) async {
        categories = await categoryRepository.fetchCategories(for: user)
    }
    
    // MARK: - CRUD Operations
    
    @MainActor
    func addRecurringExpense(for user: AppUser) async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let amountDecimal = Decimal(string: amount) ?? Decimal.zero
        let finalEndDate = hasEndDate ? endDate : nil
        
        let recurringExpense = await recurringExpenseRepository.createRecurringExpense(
            title: title,
            amount: amountDecimal,
            frequency: frequency.lowercased(),
            startDate: startDate,
            endDate: finalEndDate,
            dayOfMonthWeek: Int16(dayOfMonthWeek),
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive,
            category: selectedCategory,
            color: color,
            icon: icon,
            user: user
        )
        
        if recurringExpense != nil {
            await loadRecurringExpenses(for: user)
            resetForm()
            showingAddRecurringExpense = false
            showSuccessMessage("Recurring expense created successfully")
        } else {
            errorMessage = "Failed to create recurring expense"
        }
        
        isLoading = false
    }
    
    @MainActor
    func updateRecurringExpense(for user: AppUser) async {
        guard let recurringExpense = selectedRecurringExpense, validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let amountDecimal = Decimal(string: amount) ?? Decimal.zero
        let finalEndDate = hasEndDate ? endDate : nil
        
        await recurringExpenseRepository.updateRecurringExpense(
            recurringExpense,
            title: title,
            amount: amountDecimal,
            frequency: frequency.lowercased(),
            startDate: startDate,
            endDate: finalEndDate,
            dayOfMonthWeek: Int16(dayOfMonthWeek),
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive,
            category: selectedCategory,
            color: color,
            icon: icon
        )
        
        await loadRecurringExpenses(for: user)
        let updatedTitle = title
        resetForm()
        showingEditRecurringExpense = false
        showSuccessMessage("Recurring expense '\(updatedTitle)' updated successfully")
        
        isLoading = false
    }
    
    @MainActor
    func deleteRecurringExpense(_ recurringExpense: RecurringExpense, for user: AppUser) async {
        await recurringExpenseRepository.deleteRecurringExpense(recurringExpense)
        await loadRecurringExpenses(for: user)
        showSuccessMessage("Recurring expense deleted successfully")
    }
    
    @MainActor
    func setRecurringExpenseForEditing(_ recurringExpense: RecurringExpense) {
        selectedRecurringExpense = recurringExpense
        title = recurringExpense.title ?? ""
        amount = "\(recurringExpense.amount?.doubleValue ?? 0.0)"
        frequency = recurringExpense.frequency?.capitalized ?? "Monthly"
        startDate = recurringExpense.startDate ?? Date()
        endDate = recurringExpense.endDate
        hasEndDate = recurringExpense.endDate != nil
        dayOfMonthWeek = Int(recurringExpense.dayOfMonthWeek)
        notes = recurringExpense.notes ?? ""
        isActive = recurringExpense.isActive
        selectedCategoryId = recurringExpense.category?.id
        color = recurringExpense.color ?? "blue"
        icon = recurringExpense.icon ?? "arrow.clockwise.circle"
    }
    
    // MARK: - Form Validation
    
    private func validateForm() -> Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Title is required"
            return false
        }
        
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Valid amount is required"
            return false
        }
        
        if hasEndDate, let endDate = endDate, endDate <= startDate {
            errorMessage = "End date must be after start date"
            return false
        }
        
        errorMessage = nil
        return true
    }
    
    // MARK: - Form Management
    
    func resetForm() {
        title = ""
        amount = ""
        frequency = "Monthly"
        startDate = Date()
        endDate = nil
        hasEndDate = false
        dayOfMonthWeek = 0
        notes = ""
        isActive = true
        selectedCategoryId = nil
        color = "blue"
        icon = "arrow.clockwise.circle"
        errorMessage = nil
        selectedRecurringExpense = nil
    }
    
    // MARK: - UI Helpers
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
    
    func getSystemColor(for colorString: String) -> Color {
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
    
    // MARK: - Recurring Expense Utilities
    
    func getNextDueDate(for recurringExpense: RecurringExpense) -> Date? {
        return recurringExpenseRepository.getNextDueDate(for: recurringExpense)
    }
    
    func isDue(_ recurringExpense: RecurringExpense, on date: Date = Date()) -> Bool {
        return recurringExpenseRepository.isDue(recurringExpense: recurringExpense, on: date)
    }
    
    func getMonthlyEquivalent(for recurringExpense: RecurringExpense) -> Decimal {
        guard let amount = recurringExpense.amount?.decimalValue else { return Decimal.zero }
        
        switch recurringExpense.frequency?.lowercased() {
        case "daily":
            return amount * 30
        case "weekly":
            return amount * 4.33
        case "monthly":
            return amount
        case "yearly":
            return amount / 12
        default:
            return Decimal.zero
        }
    }
} 
