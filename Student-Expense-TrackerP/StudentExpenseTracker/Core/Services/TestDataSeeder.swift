//
//  TestDataSeeder.swift
//  StudentExpenseTracker
//
//  Created for development testing purposes
//

import Foundation

#if DEBUG
@MainActor
class TestDataSeeder {
    static let shared = TestDataSeeder()
    private let persistenceController: PersistenceController
    
    private init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
    }
    
    // MARK: - Public Interface
    
    func seedDataIfNeeded(for user: AppUser) async {
        guard await shouldSeedData(for: user) else {
            Logger.log("Test data already exists, skipping seed", level: .debug)
            return
        }
        
        Logger.log("Creating comprehensive test data for development", level: .info)
        await createTestData(for: user)
        Logger.log("Test data seeding completed", level: .info)
    }
    
    // MARK: - Private Methods
    
    private func shouldSeedData(for user: AppUser) async -> Bool {
        let categoryRepo = CategoryRepository(persistenceController: persistenceController)
        let categories = await categoryRepo.fetchCategories(for: user)
        return categories.isEmpty
    }
    
    private func createTestData(for user: AppUser) async {
        // Create repositories
        let categoryRepo = CategoryRepository(persistenceController: persistenceController)
        let expenseRepo = ExpenseRepository(persistenceController: persistenceController)
        let budgetRepo = BudgetRepository(persistenceController: persistenceController)
        let incomeRepo = IncomeRepository(persistenceController: persistenceController)
        let recurringRepo = RecurringExpenseRepository(persistenceController: persistenceController)
        
        // Create data in logical order
        let categories = await createTestCategories(for: user, using: categoryRepo)
        await createTestIncome(for: user, using: incomeRepo)
        await createTestExpenses(for: user, categories: categories, using: expenseRepo)
        await createTestBudgets(for: user, categories: categories, using: budgetRepo)
        await createTestRecurringExpenses(for: user, categories: categories, using: recurringRepo)
        await createTestRecurringIncomes(for: user, using: RecurringIncomeRepository(persistenceController: persistenceController))
    }
    
    // MARK: - Test Categories Creation
    
    private func createTestCategories(for user: AppUser, using repo: CategoryRepository) async -> [Category] {
        Logger.log("Creating test categories", level: .debug)
        
        let categoryData: [(name: String, icon: String, color: String, isDefault: Bool)] = [
            ("Food & Dining", "fork.knife", "red", true),
            ("Transportation", "car.fill", "blue", true),
            ("Shopping", "bag.fill", "purple", true),
            ("Entertainment", "tv.fill", "orange", true),
            ("Bills & Utilities", "bolt.fill", "yellow", true),
            ("Health & Fitness", "heart.fill", "pink", true),
            ("Education", "book.fill", "green", true),
            ("Travel", "airplane", "cyan", false),
            ("Gifts & Donations", "gift.fill", "brown", false),
            ("Personal Care", "scissors", "indigo", false)
        ]
        
        var createdCategories: [Category] = []
        
        for (index, data) in categoryData.enumerated() {
            let category = await repo.createCategory(
                name: data.name,
                icon: data.icon,
                color: data.color,
                isDefault: data.isDefault,
                order: Int16(index),
                user: user
            )
                createdCategories.append(category)
        }
        
        Logger.log("Created \(createdCategories.count) test categories", level: .debug)
        return createdCategories
    }
    
    // MARK: - Test Income Creation
    
    private func createTestIncome(for user: AppUser, using repo: IncomeRepository) async {
        Logger.log("Creating test income records", level: .debug)
        
        let incomeData: [(source: String, amount: Double, notes: String, isRecurring: Bool, frequency: String?)] = [
            ("Part-time Job", 2500.00, "Monthly salary from campus job", true, "monthly"),
            ("Scholarship", 1000.00, "Academic scholarship payment", true, "monthly"),
            ("Family Support", 800.00, "Monthly allowance from family", true, "monthly"),
            ("Freelance Work", 450.00, "Web design project", false, nil),
            ("Tutoring", 200.00, "Math tutoring sessions", false, nil),
            ("Gift Money", 100.00, "Birthday gift from grandparents", false, nil),
            ("Summer Internship", 3200.00, "Previous summer internship", false, nil),
            ("Tax Refund", 750.00, "Annual tax refund", false, nil)
        ]
        
        let calendar = Calendar.current
        
        for (index, data) in incomeData.enumerated() {
            let date = calendar.date(byAdding: .day, value: -index * 5, to: Date()) ?? Date()
            
            _ = await repo.createIncome(
                amount: Decimal(data.amount),
                source: data.source,
                date: date,
                notes: data.notes,
                isRecurring: data.isRecurring,
                frequency: data.frequency,
                user: user
            )
        }
        
        Logger.log("Created \(incomeData.count) test income records", level: .debug)
    }
    
    // MARK: - Test Expenses Creation
    
    private func createTestExpenses(for user: AppUser, categories: [Category], using repo: ExpenseRepository) async {
        Logger.log("Creating test expenses", level: .debug)
        
        let expenseData: [(notes: String, amount: Double, categoryIndex: Int, daysBack: Int, hasReceipt: Bool)] = [
            // Food & Dining (index 0)
            ("Lunch at campus cafe", 12.50, 0, 1, false),
            ("Grocery shopping at Walmart", 85.30, 0, 3, true),
            ("Pizza delivery", 22.99, 0, 2, false),
            ("Coffee shop study session", 5.75, 0, 1, false),
            ("Dinner with friends", 34.80, 0, 5, true),
            ("Campus meal plan", 450.00, 0, 7, true),
            
            // Transportation (index 1)
            ("Gas fill-up", 45.00, 1, 5, true),
            ("Monthly bus pass", 25.00, 1, 7, false),
            ("Uber ride to airport", 18.50, 1, 2, false),
            ("Bike repair", 67.25, 1, 12, true),
            ("Parking permit", 120.00, 1, 15, true),
            
            // Shopping (index 2)
            ("Textbooks for semester", 245.00, 2, 14, true),
            ("Winter jacket", 89.99, 2, 10, true),
            ("School supplies", 32.45, 2, 6, false),
            ("Laptop accessories", 156.78, 2, 20, true),
            ("Dorm room decorations", 78.50, 2, 8, false),
            
            // Entertainment (index 3)
            ("Movie tickets", 28.00, 3, 4, false),
            ("Concert tickets", 75.00, 3, 8, true),
            ("Video games", 59.99, 3, 11, false),
            ("Streaming services", 25.97, 3, 13, false),
            
            // Bills & Utilities (index 4)
            ("Phone bill", 55.00, 4, 30, false),
            ("Internet service", 39.99, 4, 30, false),
            ("Electricity bill", 67.50, 4, 25, true),
            ("Dorm insurance", 89.00, 4, 35, true),
            
            // Health & Fitness (index 5)
            ("Gym membership", 35.00, 5, 30, false),
            ("Vitamins and supplements", 24.99, 5, 12, true),
            ("Doctor visit copay", 25.00, 5, 20, true),
            ("Running shoes", 120.00, 5, 18, true),
            
            // Education (index 6)
            ("Online course", 199.00, 6, 22, true),
            ("Lab fees", 45.00, 6, 16, false),
            ("Study materials", 67.50, 6, 9, false)
        ]
        
        let calendar = Calendar.current
        
        for (_, data) in expenseData.enumerated() {
            let date = calendar.date(byAdding: .day, value: -data.daysBack, to: Date()) ?? Date()
            let category = data.categoryIndex < categories.count ? categories[data.categoryIndex] : nil
            
            // Create mock receipt data for some expenses
            var receiptImage: Data?
            if data.hasReceipt {
                receiptImage = "Receipt for \(data.notes) - Amount: $\(data.amount)".data(using: .utf8)
            }
            
            _ = await repo.createExpense(
                amount: Decimal(data.amount),
                date: date,
                notes: data.notes,
                receiptImage: receiptImage,
                isRecurring: false,
                category: category,
                user: user
            )
        }
        
        Logger.log("Created \(expenseData.count) test expenses", level: .debug)
    }
    
    // MARK: - Test Budgets Creation
    
    private func createTestBudgets(for user: AppUser, categories: [Category], using repo: BudgetRepository) async {
        Logger.log("Creating test budgets", level: .debug)
        
        // Create overall monthly budget
        let startDate = Calendar.current.startOfDay(for: Date())
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        _ = await repo.createBudget(
            amount: Decimal(2500.00),
            period: "monthly",
            startDate: startDate,
            endDate: endDate,
            alertThreshold: 0.8,
            isActive: true,
            category: nil,
            user: user
        )
        
        // Category-specific budgets
        let budgetData: [(categoryIndex: Int, amount: Double, period: String, threshold: Double)] = [
            (0, 500.00, "monthly", 0.8), // Food & Dining
            (1, 200.00, "monthly", 0.75), // Transportation
            (2, 400.00, "monthly", 0.9), // Shopping
            (3, 150.00, "monthly", 0.7), // Entertainment
            (4, 300.00, "monthly", 0.85), // Bills & Utilities
            (5, 100.00, "monthly", 0.8), // Health & Fitness
            (6, 250.00, "monthly", 0.9) // Education
        ]
        
        for data in budgetData {
            if data.categoryIndex < categories.count {
                let catStartDate = startDate
                let catEndDate = Calendar.current.date(byAdding: .month, value: 1, to: catStartDate) ?? catStartDate
                _ = await repo.createBudget(
                    amount: Decimal(data.amount),
                    period: data.period,
                    startDate: catStartDate,
                    endDate: catEndDate,
                    alertThreshold: data.threshold,
                    isActive: true,
                    category: categories[data.categoryIndex],
                    user: user
                )
            }
        }
        
        Logger.log("Created test budgets (overall + category-specific)", level: .debug)
    }
    
    // MARK: - Test Recurring Expenses Creation
    
    private func createTestRecurringExpenses(for user: AppUser, categories: [Category], using repo: RecurringExpenseRepository) async {
        Logger.log("Creating test recurring expenses", level: .debug)
        
        let recurringData: [(title: String, amount: Double, frequency: String, dayOfMonth: Int, categoryIndex: Int, notes: String, color: String, icon: String)] = [
            ("Netflix Subscription", 15.99, "monthly", 15, 3, "Entertainment streaming service", "red", "tv.fill"),
            ("Spotify Premium", 9.99, "monthly", 10, 3, "Music streaming service", "green", "music.note"),
            ("Gym Membership", 35.00, "monthly", 1, 5, "Campus fitness center", "orange", "figure.run"),
            ("Phone Bill", 55.00, "monthly", 25, 4, "Mobile phone service", "blue", "phone.fill"),
            ("Cloud Storage", 2.99, "monthly", 5, 4, "Google Drive storage", "cyan", "icloud.fill"),
            ("Bus Pass", 75.00, "monthly", 1, 1, "Monthly transportation pass", "yellow", "bus.fill"),
            ("Coffee Subscription", 12.99, "monthly", 12, 0, "Coffee delivery service", "brown", "cup.and.saucer.fill"),
            ("Study App Premium", 6.99, "monthly", 8, 6, "Educational app subscription", "purple", "graduationcap.fill"),
            ("Daily Coffee", 4.50, "daily", 0, 0, "Regular coffee shop visit", "brown", "mug.fill"),
            ("Campus Parking", 120.00, "monthly", 1, 1, "Monthly parking permit", "indigo", "car.fill")
        ]
        
        for data in recurringData {
            let category = data.categoryIndex < categories.count ? categories[data.categoryIndex] : nil
            
            _ = await repo.createRecurringExpense(
                title: data.title,
                amount: Decimal(data.amount),
                frequency: data.frequency,
                startDate: Date(),
                endDate: nil,
                dayOfMonthWeek: Int16(data.dayOfMonth),
                notes: data.notes,
                isActive: true,
                category: category,
                color: data.color,
                icon: data.icon,
                user: user
            )
        }
        
        Logger.log("Created \(recurringData.count) test recurring expenses", level: .debug)
    }
    
    // MARK: - Test Recurring Incomes Creation
    
    private func createTestRecurringIncomes(for user: AppUser, using repo: RecurringIncomeRepository) async {
        Logger.log("Creating test recurring incomes", level: .debug)
        
        let recurringIncomeData: [(source: String, amount: Double, frequency: String, dayOfMonth: Int, notes: String, color: String, icon: String)] = [
            ("Part-time Job", 2500.00, "monthly", 1, "Monthly salary from campus job", "green", "briefcase.fill"),
            ("Academic Scholarship", 1000.00, "monthly", 15, "Merit-based scholarship payment", "blue", "graduationcap.fill"),
            ("Family Support", 800.00, "monthly", 10, "Monthly allowance from family", "purple", "person.2.fill"),
            ("Freelance Projects", 300.00, "weekly", 5, "Weekly freelance income", "orange", "laptopcomputer"),
            ("Tutoring Sessions", 150.00, "weekly", 3, "Math and science tutoring", "teal", "book.fill"),
            ("Investment Dividends", 50.00, "monthly", 20, "Stock portfolio dividends", "mint", "chart.bar.fill"),
            ("Side Business", 200.00, "weekly", 1, "Small online business", "cyan", "storefront.fill"),
            ("Research Stipend", 500.00, "monthly", 5, "Graduate research assistant stipend", "indigo", "doc.text.fill")
        ]
        
        for data in recurringIncomeData {
            _ = await repo.createRecurringIncome(
                source: data.source,
                amount: Decimal(data.amount),
                frequency: data.frequency,
                startDate: Date(),
                endDate: nil,
                dayOfMonthWeek: Int16(data.dayOfMonth),
                notes: data.notes,
                isActive: true,
                color: data.color,
                icon: data.icon,
                user: user
            )
        }
        
        Logger.log("Created \(recurringIncomeData.count) test recurring incomes", level: .debug)
    }
}
#endif
