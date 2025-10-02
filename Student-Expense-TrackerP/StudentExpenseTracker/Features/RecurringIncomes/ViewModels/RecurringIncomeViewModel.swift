//
//  RecurringIncomeViewModel.swift
//  StudentExpenseTracker


import Foundation
import SwiftUI

@Observable
class RecurringIncomeViewModel {
    private let recurringIncomeRepository: RecurringIncomeRepository
    private let userRepository: UserRepository
    
    // MARK: - Properties
    
    var recurringIncomes: [RecurringIncome] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    
    // MARK: - UI State
    
    var showingAddRecurringIncome = false
    var showingEditRecurringIncome = false
    var selectedRecurringIncome: RecurringIncome?
    
    // MARK: - Form Fields
    
    var source = ""
    var amount = ""
    var frequency = "Monthly"
    var startDate = Date()
    var endDate: Date?
    var hasEndDate = false
    var dayOfMonthWeek: Int = 0
    var notes = ""
    var isActive = true
    var color = "blue"
    var icon = "dollarsign.circle"
    
    // MARK: - Available Options
    
    let availableFrequencies = ["Daily", "Weekly", "Monthly", "Yearly"]
    let availableIcons = [
        "dollarsign.circle", "briefcase.fill", "gift.fill", "banknote.fill",
        "building.columns.fill", "person.2.fill", "chart.bar.fill", "checkmark.seal.fill",
        "creditcard.fill", "doc.text.fill"
    ]
    let availableColors = [
        "red", "blue", "green", "orange", "purple", "pink",
        "yellow", "indigo", "teal", "mint", "cyan", "brown"
    ]
    
    // MARK: - Computed Properties
    
    var formattedEndDate: Date {
        endDate ?? Calendar.current.date(byAdding: .year, value: 1, to: startDate) ?? Date()
    }
    
    var isFormValid: Bool {
        return !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
               !amount.isEmpty &&
               Double(amount) != nil &&
               Double(amount)! > 0 &&
               (!hasEndDate || endDate == nil || endDate! > startDate)
    }
    
    // MARK: - Color Helper
    
    func getSystemColorForString(_ colorString: String) -> Color {
        switch colorString {
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
    
    // MARK: - Initialization
    
    init(recurringIncomeRepository: RecurringIncomeRepository = RecurringIncomeRepository(),
         userRepository: UserRepository = UserRepository()) {
        self.recurringIncomeRepository = recurringIncomeRepository
        self.userRepository = userRepository
    }
    
    // MARK: - Data Loading
    
    @MainActor
    func loadRecurringIncomes(for user: AppUser) async {
        isLoading = true
        errorMessage = nil
        
        recurringIncomes = await recurringIncomeRepository.fetchRecurringIncomes(for: user)
        
        isLoading = false
    }
    
    // MARK: - CRUD Operations
    
    @MainActor
    func addRecurringIncome(for user: AppUser) async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let amountDecimal = Decimal(string: amount) ?? Decimal.zero
        let finalEndDate = hasEndDate ? endDate : nil
        
        let recurringIncome = await recurringIncomeRepository.createRecurringIncome(
            source: source,
            amount: amountDecimal,
            frequency: frequency.lowercased(),
            startDate: startDate,
            endDate: finalEndDate,
            dayOfMonthWeek: Int16(dayOfMonthWeek),
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive,
//            category: nil,
            color: color,
            icon: icon,
            user: user
        )
        
        if recurringIncome != nil {
            await loadRecurringIncomes(for: user)
            resetForm()
            showingAddRecurringIncome = false
            showSuccessMessage("Recurring income created successfully")
        } else {
            errorMessage = "Failed to create recurring income"
        }
        
        isLoading = false
    }
    
    @MainActor
    func updateRecurringIncome(for user: AppUser) async {
        guard let recurringIncome = selectedRecurringIncome, validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let amountDecimal = Decimal(string: amount) ?? Decimal.zero
        let finalEndDate = hasEndDate ? endDate : nil
        
        await recurringIncomeRepository.updateRecurringIncome(
            recurringIncome,
            source: source,
            amount: amountDecimal,
            frequency: frequency.lowercased(),
            startDate: startDate,
            endDate: finalEndDate,
            dayOfMonthWeek: Int16(dayOfMonthWeek),
            notes: notes.isEmpty ? nil : notes,
            isActive: isActive,
//            category: nil,
            color: color,
            icon: icon
        )
        
        await loadRecurringIncomes(for: user)
        let updatedSource = source
        resetForm()
        showingEditRecurringIncome = false
        showSuccessMessage("Recurring income '\(updatedSource)' updated successfully")
        
        isLoading = false
    }
    
    @MainActor
    func deleteRecurringIncome(_ recurringIncome: RecurringIncome, for user: AppUser) async {
        await recurringIncomeRepository.deleteRecurringIncome(recurringIncome)
        await loadRecurringIncomes(for: user)
        showSuccessMessage("Recurring income deleted successfully")
    }
    
    @MainActor
    func setRecurringIncomeForEditing(_ recurringIncome: RecurringIncome) {
        selectedRecurringIncome = recurringIncome
        source = recurringIncome.source ?? ""
        amount = "\(recurringIncome.amount?.doubleValue ?? 0.0)"
        frequency = recurringIncome.frequency?.capitalized ?? "Monthly"
        startDate = recurringIncome.startDate ?? Date()
        endDate = recurringIncome.endDate
        hasEndDate = recurringIncome.endDate != nil
        dayOfMonthWeek = Int(recurringIncome.dayOfMonthWeek)
        notes = recurringIncome.notes ?? ""
        isActive = recurringIncome.isActive
        color = recurringIncome.color ?? "blue"
        icon = recurringIncome.icon ?? "dollarsign.circle"
    }
    
    // MARK: - Form Validation & Helpers
    
    private func validateForm() -> Bool {
        errorMessage = nil
        
        if source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errorMessage = "Source cannot be empty"
            return false
        }
        
        if amount.isEmpty {
            errorMessage = "Amount cannot be empty"
            return false
        }
        
        guard let amountValue = Double(amount), amountValue > 0 else {
            errorMessage = "Amount must be a positive number"
            return false
        }
        
        if hasEndDate, let endDate = endDate, endDate <= startDate {
            errorMessage = "End date must be after start date"
            return false
        }
        
        return true
    }
    
    func resetForm() {
        source = ""
        amount = ""
        frequency = "Monthly"
        startDate = Date()
        endDate = nil
        hasEndDate = false
        dayOfMonthWeek = 0
        notes = ""
        isActive = true
        color = "blue"
        icon = "dollarsign.circle"
        errorMessage = nil
        selectedRecurringIncome = nil
    }
    
    // MARK: - Success Message
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        
        // Clear success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
    
    // MARK: - Frequency Icon Helper
    
    func frequencyIcon(for frequency: String) -> String {
        switch frequency.lowercased() {
        case "daily":
            return "calendar"
        case "weekly":
            return "calendar.badge.clock"
        case "monthly":
            return "calendar.badge.plus"
        case "yearly":
            return "calendar.badge.exclamationmark"
        default:
            return "calendar"
        }
    }
    
    // MARK: - Format Amount Helper
    
    func formatAmount(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: amount)) ?? "$0"
    }
}
