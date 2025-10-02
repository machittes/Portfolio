//
//  ExpenseViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import Foundation
import SwiftUI
import FirebaseFirestore
import FirebaseAuth

@Observable
class ExpenseViewModel {
    private let expenseRepository: ExpenseRepository
    private let categoryRepository: CategoryRepository
    private let userRepository: UserRepository
   
    private let db = Firestore.firestore()
    
    let availableExpenseIcons = [
        "creditcard.fill", "cart.fill", "fuelpump.fill", "house.fill",
        "car.fill", "gamecontroller.fill", "fork.knife", "pill.fill",
        "graduationcap.fill", "gift.fill"
    ]

    let availableColors = [
        "red", "blue", "green", "orange", "purple", "pink",
        "yellow", "indigo", "teal", "mint", "cyan", "brown"
    ]

    var expenseAmount = ""
    var expenseTitle = ""
    var expenseNotes = ""
    var expenseColor = ""
    var expenseIcon = ""
    var selectedDate = Date()
    var selectedCategoryId: UUID?
    var isRecurring = false
    var expenseFrequency = "Monthly"
    var receiptImage: Data?
    
    var expenses: [Expense] = []
    var deletedExpenses: [Expense] = []
    var categories: [Category] = []
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var showingAddExpense = false
    var showingEditExpense = false
    var selectedExpense: Expense?
    
    var showDeletionConfirmation = false
    var confirmationMessage = ""
    var pendingDeletionExpense: Expense?
    
    // Soft deletion properties
    var includeDeletedInList = false
    var showDeletedBadges = true
    var selectedTombstoneOperation: TombstoneOperation = .softDelete
    var pendingOperationExpense: Expense?
    
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
    
    init(expenseRepository: ExpenseRepository = ExpenseRepository(),
         categoryRepository: CategoryRepository = CategoryRepository(),
         userRepository: UserRepository = UserRepository()) {
        self.expenseRepository = expenseRepository
        self.categoryRepository = categoryRepository
        self.userRepository = userRepository
    }
    
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
    
    var selectedCategory: Category? {
        categories.first { $0.id == selectedCategoryId }
    }
    
    @MainActor
    func loadExpenses(for user: AppUser, includeDeleted: Bool = false) async {
        isLoading = true
        errorMessage = nil
        expenses = await expenseRepository.fetchExpenses(for: user, includeDeleted: includeDeleted)
        deletedExpenses = await expenseRepository.fetchDeletedExpenses(for: user)
        isLoading = false
        NotificationCenter.default.post(name: .didChangeExpenses, object: nil)
        Task {
            await BudgetNotificationService.shared.checkIfOverBudgetAndWarn(for: user)
        }


    }
    
    @MainActor
    func loadCategories(for user: AppUser) async {
        categories = await categoryRepository.fetchCategories(for: user)
    }
    
    @MainActor
    func addExpense(for user: AppUser) async {
        guard validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let amount = Decimal(string: expenseAmount) ?? Decimal.zero
        
        let expense = await expenseRepository.createExpense(
            amount: amount,
            date: selectedDate,
            notes: expenseNotes.isEmpty ? nil : expenseNotes,
            title: expenseTitle.isEmpty ? nil : expenseTitle,
            color: expenseColor,
            icon: expenseIcon,
            receiptImage: receiptImage,
            isRecurring: isRecurring,
            category: selectedCategory,
            user: user
        )

        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
        resetForm()
        showingAddExpense = false
        isLoading = false
        NotificationCenter.default.post(name: .didChangeExpenses, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }


    }
   
    @MainActor
    func setExpenseForEditing(_ expense: Expense) {
        selectedExpense = expense
        expenseAmount = "\(expense.amount?.doubleValue ?? 0.0)"
        expenseTitle = expense.title ?? ""
        expenseNotes = expense.notes ?? ""
        expenseColor = expense.color ?? ""
        expenseIcon = expense.icon ?? ""
        selectedDate = expense.date ?? Date()
        selectedCategoryId = expense.category?.id
        isRecurring = expense.isRecurring
        expenseFrequency = "Monthly"
        receiptImage = expense.receiptImage
        
    }
    
//    @MainActor
//    func updateExpense(for user: AppUser) async {
//        guard let expense = selectedExpense, validateForm() else { return }
//        
//        isLoading = true
//        errorMessage = nil
//        
//        let amount = Decimal(string: expenseAmount) ?? Decimal.zero
//        
//        await expenseRepository.updateExpense(
//            expense,
//            amount: amount,
//            date: selectedDate,
//            notes: expenseNotes.isEmpty ? nil : expenseNotes,
//            title: expenseTitle.isEmpty ? nil : expenseTitle,
//            color: expenseColor.isEmpty ? nil : expenseColor,
//            icon: expenseIcon.isEmpty ? nil : expenseIcon,
//            receiptImage: receiptImage,
//            category: selectedCategory
//        )
//
//        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
//        let updatedTitle = expenseTitle
//        resetForm()
//        showingEditExpense = false
//        isLoading = false
//        NotificationCenter.default.post(name: .didChangeExpenses, object: nil)
//
//        showSuccessMessage("Expense '\(updatedTitle)' updated successfully")
//        Task {
//            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
//        }
//
//    }

    @MainActor
    func updateExpense(for user: AppUser) async {
        guard let expense = selectedExpense, validateForm() else { return }
        
        isLoading = true
        errorMessage = nil
        
        let amount = Decimal(string: expenseAmount) ?? Decimal.zero
        
        await expenseRepository.updateExpense(
            expense,
            amount: amount,
            date: selectedDate,
            notes: expenseNotes.isEmpty ? nil : expenseNotes,
            title: expenseTitle.isEmpty ? nil : expenseTitle,
            color: expenseColor.isEmpty ? nil : expenseColor,
            icon: expenseIcon.isEmpty ? nil : expenseIcon,
            receiptImage: receiptImage,
            category: selectedCategory
        )

        // Refresh the expense list first
        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
        
        // CRITICAL FIX: Update selectedExpense to point to the refreshed object
        if let expenseId = expense.id {
            selectedExpense = expenses.first { $0.id == expenseId }
        }
        
        let updatedTitle = expenseTitle
        resetForm()
        showingEditExpense = false
        isLoading = false
        NotificationCenter.default.post(name: .didChangeExpenses, object: nil)

        showSuccessMessage("Expense '\(updatedTitle)' updated successfully")
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }
    }
    
    // MARK: - Soft Deletion Methods (Updated)
    
    @MainActor
    func deleteExpense(_ expense: Expense, for user: AppUser, operation: TombstoneOperation = .softDelete) async {
        // Store operation info for confirmation
        pendingDeletionExpense = expense
        selectedTombstoneOperation = operation
        
        // Prepare confirmation message
        let expenseName = expense.title ?? "Unknown Expense"
        switch operation {
        case .softDelete:
            confirmationMessage = "Soft delete expense '\(expenseName)'?\n\nThe expense will be marked as deleted and can be restored later."
            
        case .hardDelete:
            confirmationMessage = "Permanently delete expense '\(expenseName)'?\n\nThis action cannot be undone. The expense will be completely removed from all devices."
        
        case .restore:
            confirmationMessage = "Restore expense '\(expenseName)'?\n\nThe expense will be available again."
        }
        
        showDeletionConfirmation = true
        NotificationCenter.default.post(name: .didChangeExpenses, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }


    }
    
    @MainActor
    func restoreExpense(_ expense: Expense, for user: AppUser) async {
        guard expense.softDeleted else {
            errorMessage = "Expense is not deleted"
            return
        }
        
        pendingOperationExpense = expense
        confirmationMessage = "Restore expense '\(expense.title ?? "Unknown Expense")'?\n\nThe expense will be available for use again."
        selectedTombstoneOperation = .restore
        showDeletionConfirmation = true
        NotificationCenter.default.post(name: .didChangeExpenses, object: nil)
        Task {
            await BudgetNotificationService.shared.evaluateBudgetLimit(for: user)
        }

    }

//    @MainActor
//    func reorderExpenses(_ expenses: [Expense], for user: AppUser) async {
//        await expenseRepository.reorderExpenses(expenses)
//        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
//    }
    
    @MainActor
    func confirmExpenseDeletion(for user: AppUser) async {
        guard let expense = pendingDeletionExpense else { return }
        
        let operation = selectedTombstoneOperation
        let expenseName = expense.title ?? "Unknown Expense"
        
        switch operation {
        case .softDelete:
            // Soft delete using the correct method signature
            await expenseRepository.deleteExpense(expense, deletedBy: user.userId)
            showSuccessMessage("Expense '\(expenseName)' moved to trash")
            
        case .hardDelete:
            // Hard delete - completely remove from database
            await expenseRepository.deleteExpense(expense)
            showSuccessMessage("Expense '\(expenseName)' permanently deleted")
            
        case .restore:
            // This case handled by confirmExpenseOperation
            break
        }
        
        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
        
        showDeletionConfirmation = false
        pendingDeletionExpense = nil
        confirmationMessage = ""
    }
    
    @MainActor
    func confirmExpenseOperation(for user: AppUser) async {
        guard let expense = pendingOperationExpense else { return }
        
        let operation = selectedTombstoneOperation
        let expenseName = expense.title ?? "Unknown Expense"
        
        switch operation {
        case .restore:
            do {
                try await expenseRepository.restoreExpense(expense)
                showSuccessMessage("Expense '\(expenseName)' restored successfully")
            } catch {
                errorMessage = "Failed to restore expense: \(error.localizedDescription)"
            }
            
        case .softDelete, .hardDelete:
            // These cases handled by confirmExpenseDeletion
            break
        }
        
        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
        
        showDeletionConfirmation = false
        pendingOperationExpense = nil
        confirmationMessage = ""
    }

    @MainActor
    func cancelExpenseDeletion() {
        showDeletionConfirmation = false
        pendingDeletionExpense = nil
        pendingOperationExpense = nil
        confirmationMessage = ""
    }
    
    
    // MARK: - Helper Methods
    
    private func validateForm() -> Bool {
        if expenseAmount.isEmpty {
            errorMessage = "Expense amount cannot be empty"
            return false
        }
        
        if expenseTitle.isEmpty {
            errorMessage = "Expense title cannot be empty"
            return false
        }
        
        let amount = Decimal(string: expenseAmount) ?? Decimal.zero
        if amount <= Decimal.zero {
            errorMessage = "Invalid expense amount"
            return false
        }
        
        return true
    }
    
    var isFormValid: Bool {
        return !expenseAmount.isEmpty &&
               !expenseTitle.isEmpty &&
               (Decimal(string: expenseAmount) ?? Decimal.zero) > Decimal.zero
    }
    
    func resetForm() {
        expenseAmount = ""
        expenseTitle = ""
        expenseNotes = ""
        expenseColor = "blue"
        expenseIcon = "creditcard.fill"
        selectedDate = Date()
        selectedCategoryId = nil
        isRecurring = false
        expenseFrequency = "Monthly"
        receiptImage = nil
        errorMessage = nil
        selectedExpense = nil
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
        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
    }
    
    @MainActor
    func permanentlyDeleteAllTombstones(for user: AppUser) async {
        let tombstones = deletedExpenses
        guard !tombstones.isEmpty else { return }
        
        for expense in tombstones {
            await expenseRepository.deleteExpense(expense)
        }
        
        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
        showSuccessMessage("All deleted expenses permanently removed")
    }
    
    @MainActor
    func restoreAllTombstones(for user: AppUser) async {
        let tombstones = deletedExpenses
        guard !tombstones.isEmpty else { return }
        
        for expense in tombstones {
            do {
                try await expenseRepository.restoreExpense(expense)
            } catch {
                errorMessage = "Failed to restore some expenses: \(error.localizedDescription)"
                return
            }
        }
        
        await loadExpenses(for: user, includeDeleted: includeDeletedInList)
        showSuccessMessage("All deleted expenses restored")
    }
    
    // MARK: - Additional Methods (keeping existing implementation)
    
//    @MainActor
//    func reorderExpenses(_ reorderedExpenses: [Expense], for user: AppUser) async {
//        expenses = reorderedExpenses
//        
//        for (index, expense) in reorderedExpenses.enumerated() {
//            await updateExpenseOrderInFirebase(expense: expense, order: index)
//        }
//    }

//    private func updateExpenseOrderInFirebase(expense: Expense, order: Int) async {
//        guard let expenseId = expense.id?.uuidString else { return }
//        
//        let updateData: [String: Any] = [
//            "displayOrder": order,
//            "updatedAt": FieldValue.serverTimestamp()
//        ]
//        
//        do {
//            try await db.collection("expenses").document(expenseId).updateData(updateData)
//        } catch {
//            await MainActor.run {
//                errorMessage = "Failed to update order in cloud: \(error.localizedDescription)"
//            }
//        }
//    }
    
    func getSystemColorForString(_ colorString: String) -> Color {
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
