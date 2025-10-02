//
//  RecurringIncomeGenerationService.swift
//  StudentExpenseTracker


import Foundation
import SwiftUI
import CoreData
import Observation

@MainActor
@Observable
class RecurringIncomeGenerationService {
    
    // MARK: - Properties
    
    var isGenerating = false
    var lastGenerationResult: IncomeGenerationResult?
    
    private let recurringIncomeRepository: RecurringIncomeRepository
    private let incomeRepository: IncomeRepository
    private let authViewModel: AuthViewModel
    
    // MARK: - Initialization
    
    init(
        recurringIncomeRepository: RecurringIncomeRepository,
        incomeRepository: IncomeRepository,
        authViewModel: AuthViewModel
    ) {
        self.recurringIncomeRepository = recurringIncomeRepository
        self.incomeRepository = incomeRepository
        self.authViewModel = authViewModel
    }
    
    // MARK: - Public Methods
    
    /// Generates due recurring incomes since last check
    func generateDueIncomes(force: Bool = false) async {
        guard !isGenerating else {
            print("🔄 Recurring income generation already in progress")
            return
        }
        
        print("🚀 Starting recurring income generation (force: \(force))")
        isGenerating = true
        defer { isGenerating = false }
        
        do {
            let result = try await performGeneration(force: force)
            lastGenerationResult = result
            
            if result.totalGenerated > 0 {
                print("✅ Generated \(result.totalGenerated) recurring incomes")
            } else {
                print("ℹ️ No recurring incomes needed generation")
            }
            
            if result.hasErrors {
                print("⚠️ Generation completed with errors: \(result.errors)")
            }
            
        } catch {
            let errorResult = IncomeGenerationResult(
                totalGenerated: 0,
                templateResults: [],
                errors: [error.localizedDescription]
            )
            lastGenerationResult = errorResult
            print("❌ Recurring income generation failed: \(error)")
        }
    }
    
    /// Gets the last generation timestamp for a specific template
    func getLastGenerationDate(for template: RecurringIncome) -> Date? {
        let key = userDefaultsKey(for: template)
        let timestamp = UserDefaults.standard.double(forKey: key)
        return timestamp > 0 ? Date(timeIntervalSince1970: timestamp) : nil
    }
    
    /// Clears the last generation timestamp for a specific template (for testing/debugging)
    func clearLastGenerationTimestamp(for template: RecurringIncome) {
        let key = userDefaultsKey(for: template)
        UserDefaults.standard.removeObject(forKey: key)
        print("🔍 Cleared last generation timestamp for template: \(template.source ?? "Unknown")")
    }
    
    /// Clears all last generation timestamps (for testing/debugging)
    func clearAllLastGenerationTimestamps() {
        let userPrefix = "lastRecurringIncomeGeneration_\(authViewModel.user?.uid ?? "anonymous")_"
        let defaults = UserDefaults.standard
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix(userPrefix) {
                defaults.removeObject(forKey: key)
            }
        }
        print("🔍 Cleared all last generation timestamps")
    }
    
    // MARK: - Private Methods
    
    private func userDefaultsKey(for template: RecurringIncome) -> String {
        let userId = authViewModel.user?.uid ?? "anonymous"
        let templateId = template.id?.uuidString ?? "unknown"
        return "lastRecurringIncomeGeneration_\(userId)_\(templateId)"
    }
    
    private func performGeneration(force: Bool) async throws -> IncomeGenerationResult {
        let currentDate = Date()
        
        // Get current user
        guard let currentUser = authViewModel.currentAppUser else {
            throw SyncError.userNotAuthenticated
        }
        
        // Get all active recurring incomes
        let activeRecurringIncomes = await recurringIncomeRepository.fetchActiveRecurringIncomes(for: currentUser)
        print("📋 Found \(activeRecurringIncomes.count) active recurring incomes")
        
        var templateResults: [IncomeTemplateGenerationResult] = []
        var totalGenerated = 0
        var allErrors: [String] = []
        
        for template in activeRecurringIncomes {
            do {
                let result = try await generateIncomesForTemplate(
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
                let errorResult = IncomeTemplateGenerationResult(
                    templateId: template.id?.uuidString ?? "unknown",
                    templateTitle: template.source ?? "Untitled",
                    generatedCount: 0,
                    errors: [error.localizedDescription]
                )
                templateResults.append(errorResult)
                allErrors.append("Template '\(template.source ?? "Untitled")': \(error.localizedDescription)")
            }
        }
        
        return IncomeGenerationResult(
            totalGenerated: totalGenerated,
            templateResults: templateResults,
            errors: allErrors
        )
    }
    
    private func generateIncomesForTemplate(
        template: RecurringIncome,
        currentDate: Date,
        force: Bool
    ) async throws -> IncomeTemplateGenerationResult {
        
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
        
        print("📅 Template '\(template.source ?? "Unknown")': startDate=\(startDate), currentDate=\(currentDate), frequency=\(template.frequency ?? "none"), dueDates=\(dueDates.count)")
        
        // Safety check
        if dueDates.count > 100 {
            errors.append("Too many due dates (\(dueDates.count)). Limited to 100 for safety.")
        }
        
        let limitedDueDates = Array(dueDates.prefix(100))
        
        // Generate incomes for each due date
        for dueDate in limitedDueDates {
            do {
                // Check if income already exists for this date
                let existingIncome = try await checkForExistingIncome(
                    template: template,
                    date: dueDate
                )
                
                if existingIncome == nil {
                    try await createIncomeFromTemplate(template: template, date: dueDate)
                    generatedCount += 1
                    print("💰 Created income for '\(template.source ?? "Unknown")' on \(dueDate)")
                } else {
                    print("⏭️ Skipped duplicate income for '\(template.source ?? "Unknown")' on \(dueDate)")
                }
                
            } catch {
                let errorMessage = "Failed to generate income for \(dueDate): \(error.localizedDescription)"
                errors.append(errorMessage)
                print("❌ \(errorMessage)")
            }
        }
        
        // Update last generation timestamp for this template if we generated incomes
        if generatedCount > 0 {
            updateLastGenerationDate(for: template, date: currentDate)
            print("🔍 Updated last generation timestamp for '\(template.source ?? "Unknown")' to: \(currentDate)")
        } else {
            print("🔍 No incomes generated for '\(template.source ?? "Unknown")', keeping existing timestamp")
        }
        
        return IncomeTemplateGenerationResult(
            templateId: template.id?.uuidString ?? "unknown",
            templateTitle: template.source ?? "Untitled",
            generatedCount: generatedCount,
            errors: errors
        )
    }
    
    private func determineStartDate(
        template: RecurringIncome,
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
        template: RecurringIncome,
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
    
    private func checkForExistingIncome(
        template: RecurringIncome,
        date: Date
    ) async throws -> Income? {
        guard let currentUser = authViewModel.currentAppUser else {
            throw SyncError.userNotAuthenticated
        }
        
        let allIncomes = await incomeRepository.fetchIncomes(for: currentUser)
        
        let calendar = Calendar.current
        let targetDate = calendar.startOfDay(for: date)
        
        return allIncomes.first { income in
            guard let incomeDate = income.date else { return false }
            let incomeDay = calendar.startOfDay(for: incomeDate)
            
            return incomeDay == targetDate &&
                   income.source == template.source &&
                   income.amount == template.amount &&
                   income.isRecurring == true
        }
    }
    
    private func createIncomeFromTemplate(
        template: RecurringIncome,
        date: Date
    ) async throws {
        guard let currentUser = authViewModel.currentAppUser else {
            throw SyncError.userNotAuthenticated
        }
        
        guard let amount = template.amount?.decimalValue else {
            throw SyncError.dataCorruption("Invalid template amount")
        }
        
        _ = await incomeRepository.createIncome(
            amount: amount,
            source: template.source ?? "Recurring Income",
            date: date,
            notes: template.notes,
            isRecurring: true,
            frequency: template.frequency,
            icon: template.icon,
            color: template.color,
            user: currentUser
        )
    }
    
    private func updateLastGenerationDate(for template: RecurringIncome, date: Date) {
        let key = userDefaultsKey(for: template)
        UserDefaults.standard.set(date.timeIntervalSince1970, forKey: key)
    }
}

// MARK: - Supporting Types

struct IncomeGenerationResult {
    let totalGenerated: Int
    let templateResults: [IncomeTemplateGenerationResult]
    let errors: [String]
    
    var hasErrors: Bool {
        !errors.isEmpty || templateResults.contains { !$0.errors.isEmpty }
    }
    
    var isSuccess: Bool {
        !hasErrors && totalGenerated > 0
    }
}

struct IncomeTemplateGenerationResult {
    let templateId: String
    let templateTitle: String
    let generatedCount: Int
    let errors: [String]
}
