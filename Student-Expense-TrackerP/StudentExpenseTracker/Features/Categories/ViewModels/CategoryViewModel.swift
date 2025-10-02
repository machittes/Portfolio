//
//  CategoryViewModel.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import Foundation
import SwiftUI

struct CategoryDependencyInfo {
    let expenseCount: Int
    let budgetCount: Int
    let recurringExpenseCount: Int
    
    var hasAnyDependencies: Bool {
        expenseCount > 0 || budgetCount > 0 || recurringExpenseCount > 0
    }
    
    var impactMessage: String {
        var messages: [String] = []
        
        if expenseCount > 0 {
            messages.append("• \(expenseCount) expense\(expenseCount == 1 ? "" : "s") will become 'Uncategorized'")
        }
        
        if budgetCount > 0 {
            messages.append("• \(budgetCount) budget\(budgetCount == 1 ? "" : "s") will be deleted")
        }
        
        if recurringExpenseCount > 0 {
            messages.append("• \(recurringExpenseCount) recurring transaction\(recurringExpenseCount == 1 ? "" : "s") will become 'Uncategorized'")
        }
        
        return messages.joined(separator: "\n")
    }
}

/**
 * Tombstone operation types for UI display
 */
enum TombstoneOperation: String, CaseIterable {
    case softDelete = "soft_delete"
    case hardDelete = "hard_delete"
    case restore = "restore"
    
    var displayName: String {
        switch self {
        case .softDelete:
            return "Soft Delete"
        case .hardDelete:
            return "Hard Delete"
        case .restore:
            return "Restore"
        }
    }
    
    var description: String {
        switch self {
        case .softDelete:
            return "Mark as deleted but keep for sync"
        case .hardDelete:
            return "Permanently remove from device"
        case .restore:
            return "Restore deleted category"
        }
    }
    
    var icon: String {
        switch self {
        case .softDelete:
            return "trash"
        case .hardDelete:
            return "trash.fill"
        case .restore:
            return "arrow.clockwise"
        }
    }
    
    var color: Color {
        switch self {
        case .softDelete:
            return .orange
        case .hardDelete:
            return .red
        case .restore:
            return .green
        }
    }
}

/**
 * Enhanced CategoryViewModel with tombstone pattern support
 *
 * Manages UI state for category lists, loading states, modal presentations,
 * and tombstone operations (soft delete, hard delete, restore).
 */
@Observable
class CategoryViewModel {
    private let categoryRepository: CategoryRepository
    private let userRepository: UserRepository
    private let expenseRepository: ExpenseRepository
    private let budgetRepository: BudgetRepository
    private let recurringExpenseRepository: RecurringExpenseRepository
    
    // MARK: - Published Properties for UI
    
    var categories: [Category] = []
    var deletedCategories: [Category] = [] // Tombstones for UI display
    var isLoading = false
    var errorMessage: String?
    var successMessage: String?
    var showingAddCategory = false
    var showingEditCategory = false
    var selectedCategory: Category?
    
    // MARK: - Form Properties
    
    var categoryName = ""
    var selectedIcon = "questionmark.circle.fill"
    var selectedColor = "blue"
    var isDefault = false
    
    // MARK: - Tombstone UI State
    
    var showingDeletedCategories = false
    var showTombstoneOperationSheet = false
    var selectedTombstoneOperation: TombstoneOperation = .softDelete
    var pendingOperationCategory: Category?
    
    // MARK: - Confirmation Dialog State
    
    var showDeletionConfirmation = false
    var showRestorationConfirmation = false
    var confirmationMessage = ""
    var pendingDeletionCategory: Category?
    var currentDependencyInfo: CategoryDependencyInfo?
    
    // MARK: - Filter and Display Options
    
    var includeDeletedInList = false
    var showDeletedBadges = true
    
    // MARK: - Constants
    
    // Available icons for categories
    let availableIcons = [
        "fork.knife", "car.fill", "bag.fill", "tv.fill", "bolt.fill",
        "book.fill", "heart.fill", "house.fill", "phone.fill", "gamecontroller.fill",
        "music.note", "camera.fill", "airplane", "bicycle", "tram.fill",
        "cart.fill", "creditcard.fill", "gift.fill", "sportscourt.fill",
        "questionmark.circle.fill"
    ]
    
    // Available colors for categories
    let availableColors = [
        "red", "blue", "green", "orange", "purple", "pink",
        "yellow", "indigo", "teal", "mint", "cyan", "brown", "gray"
    ]
    
    init(categoryRepository: CategoryRepository = CategoryRepository(),
         userRepository: UserRepository = UserRepository(),
         expenseRepository: ExpenseRepository = ExpenseRepository(),
         budgetRepository: BudgetRepository = BudgetRepository(),
         recurringExpenseRepository: RecurringExpenseRepository = RecurringExpenseRepository()) {
        self.categoryRepository = categoryRepository
        self.userRepository = userRepository
        self.expenseRepository = expenseRepository
        self.budgetRepository = budgetRepository
        self.recurringExpenseRepository = recurringExpenseRepository
    }
    
    // MARK: - Category Management
    
    @MainActor
    func loadCategories(for user: AppUser, includeDeleted: Bool = false) async {
        isLoading = true
        errorMessage = nil
        
        if includeDeleted {
            // Load both active and deleted categories
            let allCategories = await categoryRepository.fetchAllCategories(for: user, includeDeleted: true)
            categories = allCategories.filter { !($0.softDeleted) }
            deletedCategories = allCategories.filter { $0.softDeleted }
        } else {
            // Load only active categories
            categories = await categoryRepository.fetchCategories(for: user)
            deletedCategories = []
        }
        
        isLoading = false
    }
    
    @MainActor
    func loadDeletedCategories(for user: AppUser) async {
        let allCategories = await categoryRepository.fetchAllCategories(for: user, includeDeleted: true)
        deletedCategories = allCategories.filter { $0.softDeleted }
    }
    
    @MainActor
    func createDefaultCategories(for user: AppUser) async {
        await categoryRepository.createDefaultCategories(for: user)
    }
    
    @MainActor
    func addCategory(for user: AppUser) async {
        guard !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Category name cannot be empty"
            return
        }
        
        // Check if category already exists (including deleted ones)
        let exists = await categoryRepository.categoryExists(name: categoryName, for: user, includeDeleted: true)
        if exists {
            errorMessage = "A category with this name already exists"
            return
        }
        
        let newOrder = Int16(categories.count)
        
        let _ = await categoryRepository.createCategory(
            name: categoryName,
            icon: selectedIcon,
            color: selectedColor,
            isDefault: isDefault,
            order: newOrder,
            user: user
        )
        
        // Refresh categories
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
        
        // Reset form and show success
        resetForm()
        showingAddCategory = false
        showSuccessMessage("Category '\(categoryName)' created successfully")
    }
    
    @MainActor
    func updateCategory(for user: AppUser) async {
        guard let category = selectedCategory else { return }
        
        guard !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            errorMessage = "Category name cannot be empty"
            return
        }
        
        // Check if another category with this name exists
        if let existingCategory = await categoryRepository.fetchCategory(by: categoryName, for: user),
           existingCategory.id != category.id {
            errorMessage = "A category with this name already exists"
            return
        }
        
        await categoryRepository.updateCategory(
            category,
            name: categoryName,
            icon: selectedIcon,
            color: selectedColor
        )
        
        // Refresh categories
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
        
        // Reset form and show success
        let updatedName = categoryName
        resetForm()
        showingEditCategory = false
        selectedCategory = nil
        showSuccessMessage("Category '\(updatedName)' updated successfully")
    }
    
    // MARK: - Tombstone Operations
    
    @MainActor
    func deleteCategory(_ category: Category, for user: AppUser, operation: TombstoneOperation = .softDelete) async {
        // Get dependency information
        let dependencyInfo = await checkCategoryDependencies(category)
        
        if dependencyInfo.hasAnyDependencies && operation == .hardDelete {
            // Hard delete requires no dependencies
            errorMessage = "Cannot permanently delete this category because it is currently being used by:"
            if dependencyInfo.expenseCount > 0 {
                errorMessage! += "\n• \(dependencyInfo.expenseCount) expense\(dependencyInfo.expenseCount == 1 ? "" : "s")"
            }
            if dependencyInfo.budgetCount > 0 {
                errorMessage! += "\n• \(dependencyInfo.budgetCount) budget\(dependencyInfo.budgetCount == 1 ? "" : "s")"
            }
            if dependencyInfo.recurringExpenseCount > 0 {
                errorMessage! += "\n• \(dependencyInfo.recurringExpenseCount) recurring transaction\(dependencyInfo.recurringExpenseCount == 1 ? "" : "s")"
            }
            errorMessage! += "\n\nPlease reassign or delete these items first, or use soft delete instead."
            return
        }
        
        // Store operation info for confirmation
        pendingDeletionCategory = category
        currentDependencyInfo = dependencyInfo
        selectedTombstoneOperation = operation
        
        // Prepare confirmation message
        let categoryName = category.name ?? "Unknown"
        switch operation {
        case .softDelete:
            confirmationMessage = "Soft delete '\(categoryName)'?"
            if dependencyInfo.hasAnyDependencies {
                confirmationMessage += "\n\nThis will:\n\(dependencyInfo.impactMessage)\n\nThe category can be restored later."
            } else {
                confirmationMessage += "\n\nThe category will be marked as deleted and can be restored later."
            }
            
        case .hardDelete:
            confirmationMessage = "Permanently delete '\(categoryName)'?"
            confirmationMessage += "\n\nThis action cannot be undone. The category will be completely removed from all devices."
        
        case .restore:
            // This shouldn't happen in delete flow, but handle it
            confirmationMessage = "Restore '\(categoryName)'?"
        }
        
        showDeletionConfirmation = true
    }
    
    @MainActor
    func restoreCategory(_ category: Category, for user: AppUser) async {
        guard category.softDeleted else {
            errorMessage = "Category is not deleted"
            return
        }
        
        // Check if name conflicts with existing active category
        if let existingCategory = await categoryRepository.fetchCategory(by: category.name ?? "", for: user),
           !existingCategory.softDeleted && existingCategory.id != category.id {
            errorMessage = "Cannot restore: A category with this name already exists"
            return
        }
        
        pendingOperationCategory = category
        confirmationMessage = "Restore '\(category.name ?? "Unknown")'?\n\nThe category will be available for use again."
        showRestorationConfirmation = true
    }
    
    @MainActor
    func confirmCategoryDeletion(for user: AppUser) async {
        guard let category = pendingDeletionCategory else { return }
        
        let categoryName = category.name ?? "Unknown"
        
        switch selectedTombstoneOperation {
        case .softDelete:
            await performSoftDeletion(category, for: user)
            showSuccessMessage("'\(categoryName)' moved to deleted items")
            
        case .hardDelete:
            await performHardDeletion(category, for: user)
            showSuccessMessage("'\(categoryName)' permanently deleted")
            
        case .restore:
            // This shouldn't happen in deletion flow
            break
        }
        
        // Reset confirmation state
        resetConfirmationState()
    }
    
    @MainActor
    func confirmCategoryRestoration(for user: AppUser) async {
        guard let category = pendingOperationCategory else { return }
        
        await performRestoration(category, for: user)
        
        let categoryName = category.name ?? "Unknown"
        showSuccessMessage("'\(categoryName)' restored successfully")
        
        // Reset confirmation state
        showRestorationConfirmation = false
        pendingOperationCategory = nil
        confirmationMessage = ""
    }
    
    @MainActor
    private func performSoftDeletion(_ category: Category, for user: AppUser) async {
        await categoryRepository.deleteCategory(category, deletedBy: user.userId)
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
        
        // Update deleted categories list if shown
        if showingDeletedCategories {
            await loadDeletedCategories(for: user)
        }
    }
    
    @MainActor
    private func performHardDeletion(_ category: Category, for user: AppUser) async {
        await categoryRepository.deleteCategory(category)
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
        
        // Update deleted categories list if shown
        if showingDeletedCategories {
            await loadDeletedCategories(for: user)
        }
    }
    
    @MainActor
    private func performRestoration(_ category: Category, for user: AppUser) async {
        do {
            try await categoryRepository.restoreCategory(category)
            await loadCategories(for: user, includeDeleted: includeDeletedInList)
            
            // Update deleted categories list if shown
            if showingDeletedCategories {
                await loadDeletedCategories(for: user)
            }
        } catch {
            errorMessage = "Failed to restore category: \(error.localizedDescription)"
        }
    }
    
    @MainActor
    func cancelCategoryDeletion() {
        resetConfirmationState()
    }
    
    @MainActor
    func cancelCategoryRestoration() {
        showRestorationConfirmation = false
        pendingOperationCategory = nil
        confirmationMessage = ""
    }
    
    private func resetConfirmationState() {
        showDeletionConfirmation = false
        pendingDeletionCategory = nil
        currentDependencyInfo = nil
        confirmationMessage = ""
        selectedTombstoneOperation = .softDelete
    }
    
    // MARK: - UI State Management
    
    @MainActor
    func toggleDeletedCategoriesView(for user: AppUser) async {
        showingDeletedCategories.toggle()
        
        if showingDeletedCategories {
            await loadDeletedCategories(for: user)
        }
    }
    
    @MainActor
    func toggleIncludeDeletedInList(for user: AppUser) async {
        includeDeletedInList.toggle()
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
    }
    
    func showTombstoneOperationOptions(for category: Category) {
        pendingOperationCategory = category
        showTombstoneOperationSheet = true
    }
    
    @MainActor
    func performSelectedTombstoneOperation(for user: AppUser) async {
        guard let category = pendingOperationCategory else { return }
        
        switch selectedTombstoneOperation {
        case .softDelete:
            await deleteCategory(category, for: user, operation: .softDelete)
        case .hardDelete:
            await deleteCategory(category, for: user, operation: .hardDelete)
        case .restore:
            await restoreCategory(category, for: user)
        }
        
        showTombstoneOperationSheet = false
        pendingOperationCategory = nil
    }
    
    // MARK: - Dependency Checking
    
    @MainActor
    func checkCategoryDependencies(_ category: Category) async -> CategoryDependencyInfo {
        // Fast parallel existence checks using async let
        async let expenseCount = expenseRepository.getExpenseCount(for: category)
        async let budgetCount = budgetRepository.getBudgetCount(for: category)
        async let recurringCount = recurringExpenseRepository.getRecurringExpenseCount(for: category)
        
        return CategoryDependencyInfo(
            expenseCount: await expenseCount,
            budgetCount: await budgetCount,
            recurringExpenseCount: await recurringCount
        )
    }
    
    @MainActor
    func reorderCategories(_ categories: [Category], for user: AppUser) async {
        await categoryRepository.reorderCategories(categories)
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
    }
    
    // MARK: - Form Management
    
    func prepareForAdding() {
        resetForm()
        showingAddCategory = true
    }
    
    func prepareForEditing(_ category: Category) {
        selectedCategory = category
        categoryName = category.name ?? ""
        selectedIcon = category.icon ?? "questionmark.circle.fill"
        selectedColor = category.color ?? "blue"
        isDefault = category.isDefault
        showingEditCategory = true
    }
    
    func resetForm() {
        categoryName = ""
        selectedIcon = "questionmark.circle.fill"
        selectedColor = "blue"
        isDefault = false
        errorMessage = nil
        successMessage = nil
    }
    
    func cancelEditing() {
        resetForm()
        showingAddCategory = false
        showingEditCategory = false
        selectedCategory = nil
    }
    
    // MARK: - Message Management
    
    private func showSuccessMessage(_ message: String) {
        successMessage = message
        
        // Auto-clear success message after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.successMessage == message {
                self.successMessage = nil
            }
        }
    }
    
    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }
    
    // MARK: - Validation
    
    var isFormValid: Bool {
        !categoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Helper Methods
    
    func getDefaultCategories(for user: AppUser) async -> [Category] {
        return await categoryRepository.fetchDefaultCategories(for: user)
    }
    
    func getCategoryCount(for user: AppUser) async -> Int {
        return await categoryRepository.getCategoryCount(for: user)
    }
    
    func getDeletedCategoryCount(for user: AppUser) async -> Int {
        return await categoryRepository.getDeletedCategoryCount(for: user)
    }
    
    func getColorForCategory(_ category: Category) -> Color {
        return getSystemColorForString(category.color ?? "blue")
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
        case "gray": return .gray
        default: return .blue
        }
    }
    
    // MARK: - Category Status Helpers
    
    func isCategoryDeleted(_ category: Category) -> Bool {
        return category.softDeleted
    }
    
    func getCategoryStatusText(_ category: Category) -> String {
        if category.softDeleted {
            if let deletedAt = category.deletedAt {
                let formatter = RelativeDateTimeFormatter()
                return "Deleted \(formatter.localizedString(for: deletedAt, relativeTo: Date()))"
            } else {
                return "Deleted"
            }
        }
        return ""
    }
    
    func getCategoryStatusColor(_ category: Category) -> Color {
        return category.softDeleted ? .red : .primary
    }
    
    // MARK: - Computed Properties
    
    var activeCategoriesCount: Int {
        categories.count
    }
    
    var deletedCategoriesCount: Int {
        deletedCategories.count
    }
    
    var totalCategoriesCount: Int {
        activeCategoriesCount + deletedCategoriesCount
    }
    
    var hasDeletedCategories: Bool {
        deletedCategoriesCount > 0
    }
    
    // MARK: - Debug Helpers
    
    func debugGetCategoryInfo() -> [String: Any] {
        return [
            "activeCategoriesCount": activeCategoriesCount,
            "deletedCategoriesCount": deletedCategoriesCount,
            "totalCategoriesCount": totalCategoriesCount,
            "includeDeletedInList": includeDeletedInList,
            "showingDeletedCategories": showingDeletedCategories,
            "showDeletedBadges": showDeletedBadges
        ]
    }
}

// MARK: - CategoryViewModel Extensions for Repository Methods

extension CategoryViewModel {
    
    @MainActor
    func bulkDeleteCategories(_ categories: [Category], for user: AppUser, operation: TombstoneOperation = .softDelete) async {
        var successCount = 0
               
        for category in categories {
            switch operation {
            case .softDelete:
                await performSoftDeletion(category, for: user)
            case .hardDelete:
                await performHardDeletion(category, for: user)
            case .restore:
                await performRestoration(category, for: user)
            }
            successCount += 1
        }
        
        // Refresh lists
        await loadCategories(for: user, includeDeleted: includeDeletedInList)
        if showingDeletedCategories {
            await loadDeletedCategories(for: user)
        }
        
        // Show result message
        let operationName = operation.displayName.lowercased()
        showSuccessMessage("\(successCount) categories \(operationName)d successfully")
    }
    
    @MainActor
    func cleanupOldTombstones(for user: AppUser, olderThan days: Int = 30) async {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let oldTombstones = deletedCategories.filter { category in
            guard let deletedAt = category.deletedAt else { return false }
            return deletedAt < cutoffDate
        }
        
        if !oldTombstones.isEmpty {
            await bulkDeleteCategories(oldTombstones, for: user, operation: .hardDelete)
            showSuccessMessage("Cleaned up \(oldTombstones.count) old deleted categories")
        } else {
            showSuccessMessage("No old deleted categories to clean up")
        }
    }
}
