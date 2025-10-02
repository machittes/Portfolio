import Foundation
import SwiftUI
import CoreData
import Observation

@MainActor
@Observable
class RecurringExpenseGenerationService {
    
    // MARK: - Properties
    
    var isGenerating = false
    var lastGenerationResult: GenerationResult?
    
    private let recurringExpenseRepository: RecurringExpenseRepository
    private let expenseRepository: ExpenseRepository
    private let authViewModel: AuthViewModel
    
    // MARK: - Initialization
    
    init(
        recurringExpenseRepository: RecurringExpenseRepository,
        expenseRepository: ExpenseRepository,
        authViewModel: AuthViewModel
    ) {
        self.recurringExpenseRepository = recurringExpenseRepository
        self.expenseRepository = expenseRepository
        self.authViewModel = authViewModel
    }
    
    // MARK: - Public Methods
    
    /// Generates due recurring expenses since last check
    func generateDueExpenses(force: Bool = false) async {
        guard !isGenerating else { 
            print("🔄 Recurring expense generation already in progress")
            return 
        }
        
        print("🚀 Starting recurring expense generation (force: \(force))")
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let result = try await performGeneration(force: force)
            lastGenerationResult = result
            
            if result.totalGenerated > 0 {
                print("✅ Generated \(result.totalGenerated) recurring expenses")
            } else {
                print("ℹ️ No recurring expenses needed generation")
            }
            
            if result.hasErrors {
                print("⚠️ Generation completed with errors: \(result.errors)")
            }
            
        } catch {
            let errorResult = GenerationResult(
                totalGenerated: 0,
                templateResults: [],
                errors: [error.localizedDescription]
            )
            lastGenerationResult = errorResult
            print("❌ Recurring expense generation failed: \(error)")
        }
    }
    
    /// Gets the last generation timestamp for a specific template
    func getLastGenerationDate(for template: RecurringExpense) -> Date? {
        let key = userDefaultsKey(for: template)
        let timestamp = UserDefaults.standard.double(forKey: key)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    /// Clears the last generation timestamp for a specific template (for testing/debugging)
    func clearLastGenerationTimestamp(for template: RecurringExpense) {
        let key = userDefaultsKey(for: template)
        UserDefaults.standard.removeObject(forKey: key)
        print("🔍 Cleared last generation timestamp for template: \(template.title ?? "Unknown")")
    }
    
    /// Clears all last generation timestamps (for testing/debugging)
    func clearAllLastGenerationTimestamps() {
        let userPrefix = "lastRecurringExpenseGeneration_\(authViewModel.user?.uid ?? "anonymous")_"
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(userPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        print("🔍 Cleared all last generation timestamps")
    }
    
    // MARK: - Private Methods
    
    private func userDefaultsKey(for template: RecurringExpense) -> String {
        let userId = authViewModel.user?.uid ?? "anonymous"
        let templateId = template.id?.uuidString ?? "unknown"
        return "lastRecurringExpenseGeneration_\(userId)_\(templateId)"
    }
    
    private func performGeneration(force: Bool) async throws -> GenerationResult {
        let currentDate = Date()
        
        // Get current user
        guard let currentUser = authViewModel.currentAppUser else {
            throw SyncError.userNotAuthenticated
        }
        
        // Get all active recurring expenses
        let activeRecurringExpenses = await recurringExpenseRepository.fetchActiveRecurringExpenses(for: currentUser)
        print("📋 Found \(activeRecurringExpenses.count) active recurring expenses")
        
        var templateResults: [TemplateGenerationResult] = []
        var totalGenerated = 0
        var allErrors: [String] = []
        
        for template in activeRecurringExpenses {
            do {
                let result = try await generateExpensesForTemplate(
                    template: template,
                    currentDate: currentDate,
                    force: force
                )
                templateResults.append(result)
                totalGenerated += result.generatedCount
                
                if !result.errors.isEmpty {
                    allErrors.append(contentsOf: result.errors)
                }
                
            } catch {
                let errorResult = TemplateGenerationResult(
                    templateId: template.id?.uuidString ?? "unknown",
                    templateTitle: template.title ?? "Untitled",
                    generatedCount: 0,
                    errors: [error.localizedDescription]
                )
                templateResults.append(errorResult)
                allErrors.append("Template '\(template.title ?? "Untitled")': \(error.localizedDescription)")
            }
        }
        
        return GenerationResult(
            totalGenerated: totalGenerated,
            templateResults: templateResults,
            errors: allErrors
        )
    }
    
    private func generateExpensesForTemplate(
        template: RecurringExpense,
        currentDate: Date,
        force: Bool
    ) async throws -> TemplateGenerationResult {
        
        var errors: [String] = []
        var generatedCount = 0
        
        // Get last generation timestamp for this specific template
        let lastGeneration = force ? nil : getLastGenerationDate(for: template)
        
        // Determine the start date for generation
        print("🔍 Template startDate: \(template.startDate?.description ?? "nil")")
        print("🔍 Last generation: \(lastGeneration?.description ?? "nil")")
        let startDate = determineStartDate(
            template: template,
            lastGeneration: lastGeneration,
            currentDate: currentDate
        )
        print("🔍 Calculated startDate: \(startDate)")
        
        // Get due dates since start date
        let dueDates = calculateDueDates(
            template: template,
            startDate: startDate,
            currentDate: currentDate
        )
        
        print("📅 Template '\(template.title ?? "Unknown")': startDate=\(startDate), currentDate=\(currentDate), frequency=\(template.frequency ?? "none"), dueDates=\(dueDates.count)")
        
        // Safety check
        if dueDates.count > 100 {
            errors.append("Too many due dates (\(dueDates.count)). Limited to 100 for safety.")
        }
        
        let limitedDueDates = Array(dueDates.prefix(100))
        
        // Generate expenses for each due date
        for dueDate in limitedDueDates {
            do {
                // Check if expense already exists for this date
                let existingExpense = try await checkForExistingExpense(
                    template: template,
                    date: dueDate
                )
                
                if existingExpense == nil {
                    try await createExpenseFromTemplate(template: template, date: dueDate)
                    generatedCount += 1
                    print("💰 Created expense for '\(template.title ?? "Unknown")' on \(dueDate)")
                } else {
                    print("⏭️ Skipped duplicate expense for '\(template.title ?? "Unknown")' on \(dueDate)")
                }
                
            } catch {
                errors.append("Failed to generate expense for \(dueDate): \(error.localizedDescription)")
            }
        }
        
        // Update last generation timestamp for this specific template if we generated expenses
        if generatedCount > 0 {
            let key = userDefaultsKey(for: template)
            UserDefaults.standard.set(currentDate.timeIntervalSince1970, forKey: key)
            print("🔍 Updated last generation timestamp for '\(template.title ?? "Unknown")' to: \(currentDate)")
        } else {
            print("🔍 No expenses generated for '\(template.title ?? "Unknown")', keeping existing timestamp")
        }
        
        return TemplateGenerationResult(
            templateId: template.id?.uuidString ?? "unknown",
            templateTitle: template.title ?? "Untitled",
            generatedCount: generatedCount,
            errors: errors
        )
    }
    
    private func determineStartDate(
        template: RecurringExpense,
        lastGeneration: Date?,
        currentDate: Date
    ) -> Date {
        let templateStartDate = template.startDate ?? currentDate
        
        guard let lastGeneration = lastGeneration else {
            print("🔍 determineStartDate: No last generation, using template.startDate -> \(templateStartDate)")
            return templateStartDate
        }
        
        let dayAfterLastGeneration = Calendar.current.date(byAdding: .day, value: 1, to: lastGeneration) ?? currentDate
        
        // Use the LATER of template start date or day after last generation
        let result = max(templateStartDate, dayAfterLastGeneration)
        print("🔍 determineStartDate: templateStartDate=\(templateStartDate), dayAfterLastGeneration=\(dayAfterLastGeneration) -> using \(result)")
        return result
    }
    
    private func calculateDueDates(
        template: RecurringExpense,
        startDate: Date,
        currentDate: Date
    ) -> [Date] {
        var dueDates: [Date] = []
        let calendar = Calendar.current
        
        let endDate = template.endDate ?? currentDate
        let effectiveEndDate = min(endDate, currentDate)
        
        print("🔍 calculateDueDates: startDate=\(startDate), currentDate=\(currentDate)")
        print("🔍 calculateDueDates: template.endDate=\(template.endDate?.description ?? "nil"), effectiveEndDate=\(effectiveEndDate)")
        
        var currentDueDate = startDate
        
        while currentDueDate <= effectiveEndDate {
            print("🔍 Adding due date: \(currentDueDate)")
            dueDates.append(currentDueDate)
            
            switch template.frequency?.lowercased() {
            case "daily":
                currentDueDate = calendar.date(byAdding: .day, value: 1, to: currentDueDate) ?? currentDueDate
            case "weekly":
                currentDueDate = calendar.date(byAdding: .weekOfYear, value: 1, to: currentDueDate) ?? currentDueDate
            case "monthly":
                currentDueDate = calendar.date(byAdding: .month, value: 1, to: currentDueDate) ?? currentDueDate
            case "yearly":
                currentDueDate = calendar.date(byAdding: .year, value: 1, to: currentDueDate) ?? currentDueDate
            default:
                break
            }
            
            if dueDates.count > 1000 {
                print("🔍 Breaking due to safety limit (1000 dates)")
                break
            }
        }
        
        print("🔍 Final dueDates count: \(dueDates.count)")
        if dueDates.isEmpty {
            print("🔍 No due dates because startDate (\(startDate)) > effectiveEndDate (\(effectiveEndDate))")
        }
        
        return dueDates
    }
    
    private func checkForExistingExpense(
        template: RecurringExpense,
        date: Date
    ) async throws -> Expense? {
        guard let currentUser = authViewModel.currentAppUser else {
            throw SyncError.userNotAuthenticated
        }
        
        let allExpenses = await expenseRepository.fetchExpenses(for: currentUser)
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return allExpenses.first { expense in
            guard let expenseDate = expense.date else { return false }
            let expenseDay = calendar.startOfDay(for: expenseDate)
            
            return expenseDay == targetDate &&
                   expense.title == template.title &&
                   expense.amount == template.amount &&
                   expense.category == template.category
        }
    }
    
    private func createExpenseFromTemplate(
        template: RecurringExpense,
        date: Date
    ) async throws {
        guard let currentUser = authViewModel.currentAppUser else {
            throw SyncError.userNotAuthenticated
        }
        
        guard let amount = template.amount?.decimalValue else {
            throw SyncError.dataCorruption("Invalid template amount")
        }
        
        _ = await expenseRepository.createExpense(
            amount: amount,
            date: date,
            notes: template.notes,
            title: template.title,
            color: template.color,
            icon: template.icon,
            isRecurring: true,
            category: template.category,
            user: currentUser
        )
    }
}

// MARK: - Supporting Types

struct GenerationResult {
    let totalGenerated: Int
    let templateResults: [TemplateGenerationResult]
    let errors: [String]
    
    var hasErrors: Bool {
        !errors.isEmpty || templateResults.contains { !$0.errors.isEmpty }
    }
    
    var isSuccess: Bool {
        !hasErrors && totalGenerated > 0
    }
}

struct TemplateGenerationResult {
    let templateId: String
    let templateTitle: String
    let generatedCount: Int
    let errors: [String]
} 