//
//  SearchFilterView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-28.
//

import SwiftUI

struct SearchFilterView: View {
    @State private var viewModel = SearchViewModel()
    @Environment(AuthViewModel.self) private var authVM
    @State private var categories: [Category] = []
    @State private var showResultsSheet = false  // Sheet presentation
    
    // Add focus management
    @FocusState private var focusedField: FocusedField?
    
    enum FocusedField: Hashable {
        case searchKeyword
        case minAmount
        case maxAmount
    }

//    var body: some View {
//        NavigationStack {
//            Form {
//                searchSection
//                filtersSection
//                searchButtonSection
//            }
//            .navigationTitle("Search")
//            .navigationBarTitleDisplayMode(.inline)
//            .background(AppColors.backgroundDefault.ignoresSafeArea())
//            .task {
//                await loadCategories()
//            }
//            .sheet(isPresented: $showResultsSheet) {
//                SearchResultsSheet(viewModel: viewModel)
//                    .presentationDetents([.medium, .large])
//                    .presentationDragIndicator(.visible)
//            }
//        }
//    }
  
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Add custom header like Charts.swift
                headerView
                    .padding()
                    .background(AppColors.backgroundLight)
                
                Form {
                    searchSection
                    filtersSection
                    searchButtonSection
                }
                // Remove: .navigationTitle("Search")
                // Remove: .navigationBarTitleDisplayMode(.inline)
                .background(AppColors.backgroundDefault.ignoresSafeArea())
            }
            .task {
                await loadCategories()
            }
            .sheet(isPresented: $showResultsSheet) {
                SearchResultsSheet(viewModel: viewModel)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - View Components

    private var searchSection: some View {
        Section {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColors.textPrimary)
  
                TextField("Type something...", text: $viewModel.keyword)
                    .focused($focusedField, equals: .searchKeyword)
 
            }
            
            .padding()
            .background(AppColors.cardBackground)
            .cornerRadius(AppSpacing.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                    .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
            )
           
        }
 
    }
     
    private var filtersSection: some View {
        Section("Filters") {
            VStack(spacing: 20) {
                dateRangePickers
                categoryPicker
                amountRangeFields
                expenseTypeSegmentedControl
            }
        }
    }
    
    private var dateRangePickers: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("From")
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                    DatePicker(
                        "From",
                        selection: Binding(
                            get: { viewModel.dateFrom ?? Date() },
                            set: { viewModel.dateFrom = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("To")
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                    DatePicker(
                        "To",
                        selection: Binding(
                            get: { viewModel.dateTo ?? Date() },
                            set: { viewModel.dateTo = $0 }
                        ),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
            }
        }
    }
 
    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu {
                    Button("All Categories") {
                        viewModel.selectedCategory = nil
                    }
                    
                    ForEach(categories, id: \.id) { category in
                        Button(action: {
                            viewModel.selectedCategory = category
                        }) {
                            HStack {
                                if let icon = category.icon {
                                    Image(systemName: icon)
                                }
                                Text(category.name ?? "Unknown")
                            }
                        }
                    }
                } label: {
                    HStack {
                        // Show selected category or default
                        if let selectedCategory = viewModel.selectedCategory {
                            if let icon = selectedCategory.icon {
                                Image(systemName: icon)
                            }
                            Text(selectedCategory.name ?? "Unknown")
                        } else {
                            Text("All Categories")
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.down")
                            .foregroundColor(AppColors.textSecondary)
                            .font(.caption)
                    }
                    .foregroundColor(AppColors.textPrimary)
                    .font(AppFonts.subtitle)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
                }
            }
        }
    }
      
    private var amountRangeFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Amount Range")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textPrimary)

            HStack(spacing: 12) {
                TextField("Min.", value: $viewModel.minAmount, format: .number)
                            .keyboardType(.decimalPad)
                            .padding()
                            .background(AppColors.cardBackground)
                            .cornerRadius(AppSpacing.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                                    .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                            )
                
                TextField("Max.", value: $viewModel.maxAmount, format: .number)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }
        
    private var expenseTypeSegmentedControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Type Filter")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textPrimary)
            
            Picker("Type Filter", selection: $viewModel.filterRecurring) {
                ForEach(SearchViewModel.RecurringExpenseFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var searchButtonSection: some View {
        Section {
            Button {
                // Dismiss keyboard before searching
                focusedField = nil
                Task {
                    await performSearch()
                }
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text("Search")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.primary)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: AppSpacing.cornerRadius))
            }
            .listRowBackground(Color.clear)
            .buttonStyle(PlainButtonStyle())
        }
    }
    
    // MARK: - Methods
    
    private func loadCategories() async {
        guard let user = authVM.currentAppUser else { return }
        categories = await viewModel.categoryRepository.fetchCategories(for: user)
    }
    
    private func performSearch() async {
        guard let user = authVM.currentAppUser else { return }
        await viewModel.performSearch(for: user)
        showResultsSheet = true
    }
    
    private var headerView: some View {
        HStack {
            Spacer()
            Text("Search")
                .font(AppFonts.title)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
        }
    }
    
}

// MARK: - Search Results Sheet
struct SearchResultsSheet: View {
    let viewModel: SearchViewModel
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ContentUnavailableView {
                        ProgressView()
                    } description: {
                        Text("Searching...")
                    }
                } else if let error = viewModel.errorMessage {
                    ContentUnavailableView {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Try Again") {
                            // Retry logic
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if viewModel.budgetResults.isEmpty && viewModel.expenseResults.isEmpty && viewModel.incomeResults.isEmpty {
                    ContentUnavailableView {
                        Image(systemName: "magnifyingglass")
                    } description: {
                        Text("No results found")
                    } actions: {
                        Button("Adjust Filters") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    resultsScrollView
                }
            }
            .navigationTitle("Search Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                }
            }
            .background(AppColors.backgroundDefault.ignoresSafeArea())
        }
    }
    
    private var resultsScrollView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                if !viewModel.budgetResults.isEmpty {
                    budgetResultsSection
                }
                
                if !viewModel.expenseResults.isEmpty {
                    expenseResultsSection
                }
                
                if !viewModel.incomeResults.isEmpty {
                    incomeResultsSection
                }
            }
            .padding()
        }
    }
    
    private var budgetResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Budgets")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textPrimary)
            
            ForEach(viewModel.budgetResults, id: \.id) { budget in
                BudgetRowView(budget: budget)
            }
        }
    }
    
    private var expenseResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expenses")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textPrimary)
            
            ForEach(viewModel.expenseResults, id: \.id) { expense in
                ExpenseSearchRowView(expense: expense)
            }
        }
    }
    
    private var incomeResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Incomes")
                .font(AppFonts.subtitle)
                .foregroundStyle(AppColors.textPrimary)
            
            ForEach(viewModel.incomeResults, id: \.id) { income in
                IncomeSearchRowView(income: income)
            }
        }
    }
}

// MARK: - Row Views

struct BudgetRowView: View {
    let budget: Budget
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            Text(budget.period ?? "Budget")
                .font(AppFonts.body)
            
            if let startDate = budget.startDate, let endDate = budget.endDate {
                Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            HStack {
                if let category = budget.category {
                    Text(category.name ?? "")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if let amnt = budget.amount {
                    Text(amnt.doubleValue.formatted(.currency(code: "USD").presentation(.narrow)))
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius)
        .padding(.horizontal)
    }
}

struct ExpenseSearchRowView: View {
    let expense: Expense
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            Text(expense.notes ?? "Expense")
                .font(AppFonts.body)
            
            if let date = expense.date {
                Text("\(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            HStack {
                if let category = expense.category {
                    Text(category.name ?? "")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
                if let amount = expense.amount {
                    Text(amount.doubleValue.formatted(.currency(code: "USD").presentation(.narrow)))
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            
            if let recurringExpense = expense.recurringExpense {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                    Text("Recurring")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius)
        .padding(.horizontal)
    }
}

struct IncomeSearchRowView: View {
    let income: Income
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            
            Text(income.source ?? "Income")
                .font(AppFonts.body)
            
            if let date = income.date {
                Text("\(date.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            
            HStack {
                if let notes = income.notes, !notes.isEmpty {
                    Text(notes)
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
                if let amount = income.amount {
                    Text(amount.doubleValue.formatted(.currency(code: "USD").presentation(.narrow)))
                        .font(AppFonts.small)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            
            if income.isRecurring {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                    Text(income.frequency ?? "Recurring")
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.textSecondary)
                }
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius)
        .padding(.horizontal)
    }
}
