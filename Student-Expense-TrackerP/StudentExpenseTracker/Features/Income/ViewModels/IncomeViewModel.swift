//  IncomeViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-06-04.
//

import Foundation
import SwiftUI

@Observable
class IncomeViewModel {
    private let incomeRepository: IncomeRepository
    private let userRepository: UserRepository
   
    var selectedIcon = "dollarsign.circle.fill"
    var selectedColor = "blue"
 
    let availableIncomeIcons = [
        "dollarsign.circle.fill", "briefcase.fill", "gift.fill", "banknote.fill",
        "building.columns.fill", "person.2.fill", "chart.bar.fill", "checkmark.seal.fill",
        "creditcard.fill", "doc.text.fill"
    ]

    let availableColors = [
        "red", "blue", "green", "orange", "purple", "pink",
        "yellow", "indigo", "teal", "mint", "cyan", "brown"
    ]
    
    var incomes: [Income] = []
    var deletedIncomes: [Income] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var showingAddIncome = false
    var showingEditIncome = false
    var selectedIncome: Income?
   
    var incomeAmount = ""
    var incomeSource = ""
    var incomeNotes = ""
    var isRecurring = false
    var incomeFrequency = "Monthly"
    var selectedDate = Date()
   
    var showDeletionConfirmation = false
    var confirmationMessage = ""
    var pendingDeletionIncome: Income?
    
    // Soft deletion properties
    var includeDeletedInList = false
    var showDeletedBadges = true
    var selectedTombstoneOperation: TombstoneOperation = .softDelete
    var pendingOperationIncome: Income?
    
    // Tombstone operation types
    enum TombstoneOperation: String, CaseIterable {
        case softDelete = "soft"
        case hardDelete = "hard"
        case restore = "restore"
        
        var displayName: String {
            switch self {
            case .softDelete: return "Soft Delete"
            case .hardDelete: return "Permanent Delete"
            case .restore: return "Restore"
            }
        }
    }
   
    init(incomeRepository: IncomeRepository = IncomeRepository(), userRepository: UserRepository = UserRepository()) {
        self.incomeRepository = incomeRepository
        self.userRepository = userRepository
    }
    
    func getColorForIncome(_ income: Income) -> Color {
        switch income.color {
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
   
    // MARK: - Income Management
    @MainActor
    func loadIncomes(for user: AppUser, includeDeleted: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        if includeDeleted {
            // Load both active and deleted incomes
            let allIncomes = await incomeRepository.fetchAllIncome(for: user, includeDeleted: true)
            incomes = allIncomes.filter { !($0.softDeleted) }
            deletedIncomes = allIncomes.filter { $0.softDeleted }
            NotificationCenter.default.post(name: .didChangeIncomes, object: nil)

        } else {
            // Load only active incomes
            incomes = await incomeRepository.fetchIncomes(for: user, includeDeleted: false)
            deletedIncomes = []
            NotificationCenter.default.post(name: .didChangeIncomes, object: nil)

        }
        
        isLoading = false
    }
    
    @MainActor
    func loadDeletedIncomes(for user: AppUser) async {
        deletedIncomes = await incomeRepository.fetchDeletedIncome(for: user)
    }
    
    @MainActor
    func setIncomeForEditing(_ income: Income) {
        selectedIncome = income
        incomeAmount = "\(income.amount?.doubleValue ?? 0.0)"
        incomeSource = income.source ?? ""
        incomeNotes = income.notes ?? ""
        isRecurring = income.isRecurring
        incomeFrequency = income.frequency ?? "Monthly"
        selectedDate = income.date ?? Date()
        selectedIcon = income.icon ?? "dollarsign.circle.fill"
        selectedColor = income.color ?? "blue"
    }
   
    @MainActor
    func addIncome(for user: AppUser) async {
        guard !incomeAmount.isEmpty else {
            errorMessage = "Income amount cannot be empty"
            return
        }
       
        let amount = Decimal(string: incomeAmount) ?? Decimal.zero
        if amount == Decimal.zero {
            errorMessage = "Invalid income amount"
            return
        }
       
        let newOrder = Int16(incomes.count)

        let _ = await incomeRepository.createIncome(
            amount: amount,
            source: incomeSource,
            date: selectedDate,
            notes: incomeNotes,
            isRecurring: isRecurring,
            frequency: incomeFrequency,
            icon: selectedIcon,
            color: selectedColor,
            order: newOrder,
            user: user
        )
       
        // Refresh income list
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
        resetForm()
        showingAddIncome = false
        showSuccessMessage("Income added successfully")
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }

    }
   
    @MainActor
    func updateIncome(for user: AppUser) async {
        guard let income = selectedIncome else { return }
       
        let amount = Decimal(string: incomeAmount) ?? Decimal.zero
        if amount == Decimal.zero {
            errorMessage = "Invalid income amount"
            return
        }
       
        await incomeRepository.updateIncome(
            income,
            amount: amount,
            source: incomeSource,
            date: Date(),
            notes: incomeNotes,
            isRecurring: isRecurring,
            frequency: incomeFrequency,
            icon: selectedIcon,
            color: selectedColor
        )
       
        // Refresh income list
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
        let updatedSource = incomeSource
        resetForm()
        showingEditIncome = false
        showSuccessMessage("Income '\(updatedSource)' updated successfully")
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }


    }
    
    // MARK: - Soft Deletion Methods (Updated)
    
    @MainActor
    func deleteIncome(_ income: Income, for user: AppUser, operation: TombstoneOperation = .softDelete) async {
        // Store operation info for confirmation
        pendingDeletionIncome = income
        selectedTombstoneOperation = operation
        
        // Prepare confirmation message
        let incomeName = income.source ?? "Unknown Source"
        switch operation {
        case .softDelete:
            confirmationMessage = "Soft delete income from '\(incomeName)'?\n\nThe income will be marked as deleted and can be restored later."
            
        case .hardDelete:
            confirmationMessage = "Permanently delete income from '\(incomeName)'?\n\nThis action cannot be undone. The income will be completely removed from all devices."
        
        case .restore:
            confirmationMessage = "Restore income from '\(incomeName)'?\n\nThe income will be available again."
        }
        
        showDeletionConfirmation = true
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }


    }
    
    @MainActor
    func restoreIncome(_ income: Income, for user: AppUser) async {
        guard income.softDeleted else {
            errorMessage = "Income is not deleted"
            return
        }
        
        pendingOperationIncome = income
        confirmationMessage = "Restore income from '\(income.source ?? "Unknown Source")'?\n\nThe income will be available for use again."
        selectedTombstoneOperation = .restore
        showDeletionConfirmation = true
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }


    }

    @MainActor
    func reorderIncomes(_ incomes: [Income], for user: AppUser) async {
        await incomeRepository.reorderIncomes(incomes)
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
    }
    
    @MainActor
    func confirmIncomeDeletion(for user: AppUser) async {
        guard let income = pendingDeletionIncome else { return }
        
        let operation = selectedTombstoneOperation
        let incomeName = income.source ?? "Unknown Source"
        
        switch operation {
        case .softDelete:
            // Soft delete using the correct method signature
            await incomeRepository.deleteIncome(income, deletedBy: user.userId)
            showSuccessMessage("Income from '\(incomeName)' moved to trash")
            
        case .hardDelete:
            // Hard delete - completely remove from database
            await incomeRepository.deleteIncome(income)
            showSuccessMessage("Income from '\(incomeName)' permanently deleted")
            
        case .restore:
            // This case handled by confirmIncomeOperation
            break
        }
        
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
        
        showDeletionConfirmation = false
        pendingDeletionIncome = nil
        confirmationMessage = ""
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)

    }
    
    @MainActor
    func confirmIncomeOperation(for user: AppUser) async {
        guard let income = pendingOperationIncome else { return }
        
        let operation = selectedTombstoneOperation
        let incomeName = income.source ?? "Unknown Source"
        
        switch operation {
        case .restore:
            do {
                try await incomeRepository.restoreIncome(income)
                showSuccessMessage("Income from '\(incomeName)' restored successfully")
            } catch {
                errorMessage = "Failed to restore income: \(error.localizedDescription)"
            }
            
        case .softDelete, .hardDelete:
            // These cases handled by confirmIncomeDeletion
            break
        }
        
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
        
        showDeletionConfirmation = false
        pendingOperationIncome = nil
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)

        confirmationMessage = ""
    }

    @MainActor
    func cancelIncomeDeletion() {
        showDeletionConfirmation = false
        pendingDeletionIncome = nil
        pendingOperationIncome = nil
        confirmationMessage = ""
    }
    
    // MARK: - Helper Methods
    func resetForm() {
        incomeAmount = ""
        incomeSource = ""
        incomeNotes = ""
        isRecurring = false
        incomeFrequency = "Monthly"
        selectedDate = Date()
        errorMessage = nil
        selectedIncome = nil
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)

    }
   
    var isFormValid: Bool {
        return !incomeAmount.isEmpty && Decimal(string: incomeAmount) != Decimal.zero
    }
    
    @MainActor
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            self.successMessage = nil
        }
    }
    
    // MARK: - Tombstone Management
    
    @MainActor
    func toggleIncludeDeleted(for user: AppUser) async {
        includeDeletedInList.toggle()
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
    }
    
    @MainActor
    func permanentlyDeleteAllTombstones(for user: AppUser) async {
        let tombstones = deletedIncomes
        guard !tombstones.isEmpty else { return }
        
        for income in tombstones {
            await incomeRepository.deleteIncome(income)
        }
        
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
        NotificationCenter.default.post(name: .didChangeIncomes, object: nil)

        showSuccessMessage("All deleted incomes permanently removed")
    }
    
    @MainActor
    func restoreAllTombstones(for user: AppUser) async {
        let tombstones = deletedIncomes
        guard !tombstones.isEmpty else { return }
        
        for income in tombstones {
            do {
                try await incomeRepository.restoreIncome(income)
            } catch {
                errorMessage = "Failed to restore some incomes: \(error.localizedDescription)"
                return
            }
        }
        
        await loadIncomes(for: user, includeDeleted: includeDeletedInList)
       

        showSuccessMessage("All deleted incomes restored")
    }
}
