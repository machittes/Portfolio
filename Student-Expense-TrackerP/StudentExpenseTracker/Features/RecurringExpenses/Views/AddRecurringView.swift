//
//  AddRecurringView.swift
//  StudentExpenseTracker


import SwiftUI

struct AddRecurringView: View {
    @Bindable var viewModel: RecurringExpenseViewModel
    let user: AppUser
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
                basicFieldsSection
                frequencySection
                dateSection
                iconSelectionSection
                colorSelectionSection
                statusSection
                previewSection
                errorSection
            }
            .navigationTitle("Add Recurring Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    cancelButton
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    saveButton
                }
            }
            .background(AppColors.backgroundDefault.ignoresSafeArea())
            .onDisappear {
                viewModel.resetForm()
            }
        }
        .onAppear {
            Task {
                await viewModel.loadCategories(for: user)
            }
        }
    }
    
    // MARK: - Toolbar Buttons
    
    private var cancelButton: some View {
        Button("Cancel") {
            dismiss()
        }
        .foregroundColor(AppColors.textSecondary)
        .font(AppFonts.body)
    }
    
    private var saveButton: some View {
        Button("Save") {
            Task {
                await viewModel.addRecurringExpense(for: user)
                if viewModel.errorMessage == nil {
                    dismiss()
                }
            }
        }
        .disabled(!viewModel.isFormValid)
        .foregroundColor(viewModel.isFormValid ? AppColors.primary : AppColors.textSecondary)
        .font(AppFonts.body)
        .padding(.horizontal, AppSpacing.horizontalPadding)
        .padding(.vertical, 8)
        .background(saveButtonBackground)
    }
    
    private var saveButtonBackground: some View {
        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
            .fill(viewModel.isFormValid ? AppColors.primary.opacity(0.1) : Color.clear)
    }
    
    // MARK: - Form Sections
    
    private var basicFieldsSection: some View {
        Section {
            categoryRow
//            categoryPicker
            amountField
            titleField
            notesField
        }
    }
    
    private var categoryRow: some View {
        HStack {
            Menu {
                Button("All Categories") {
                    viewModel.selectedCategoryId = nil
                }
                
                ForEach(viewModel.categories, id: \.id) { category in
                    Button(action: {
                        viewModel.selectedCategoryId = category.id
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
                    if let selectedCategory = viewModel.categories.first(where: { $0.id == viewModel.selectedCategoryId }) {
                        if let icon = selectedCategory.icon {
                            Image(systemName: icon)
                        }
                        Text(selectedCategory.name ?? "Unknown")
                    } else {
                        Text("All Categories")
                    }
                    
                    Image(systemName: "chevron.down")
                        .foregroundColor(AppColors.textSecondary)
                        .font(.caption)
                }
                .foregroundColor(AppColors.textPrimary)
                .font(AppFonts.subtitle)
                //.frame(maxWidth: .infinity)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppColors.cardBackground)
                .cornerRadius(AppSpacing.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                )
            }
            
            Spacer()
        }
    }
    
//    private var categoryPicker: some View {
//        Picker("", selection: $viewModel.selectedCategoryId) {
//            Text("All Categories").tag(UUID?.none)
//            ForEach(viewModel.categories, id: \.id) { category in
//                HStack {
//                    if let icon = category.icon {
//                        Image(systemName: icon)
//                    }
//                    Text(category.name ?? "Unknown")
//                }
//                .tag(UUID?.some(category.id ?? UUID()))
//            }
//        }
//        .pickerStyle(.menu)
//        .tint(AppColors.textPrimary)
//        .font(AppFonts.subtitle)
//        .padding(.horizontal, 4)
//        .background(AppColors.cardBackground)
//        .cornerRadius(AppSpacing.cornerRadius)
//        .overlay(
//            RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
//                .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
//        )
//    }
    
    private var amountField: some View {
        VStack(alignment: .leading) {
            Text("Recurring Amount")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            TextField("Enter recurring amount", text: $viewModel.amount)
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
    
    private var titleField: some View {
        VStack(alignment: .leading) {
            Text("Title")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            TextField("Enter title", text: $viewModel.title)
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(AppSpacing.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var notesField: some View {
        VStack(alignment: .leading) {
            Text("Notes")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            TextField("Enter notes", text: $viewModel.notes)
                .padding()
                .background(AppColors.cardBackground)
                .cornerRadius(AppSpacing.cornerRadius)
                .overlay(
                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    private var frequencySection: some View {
        Section {
            frequencyPicker
            
            if viewModel.frequency == "Weekly" || viewModel.frequency == "Monthly" {
                daySelector
            }
        }
    }
    
    private var frequencyPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Frequency")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            
            Picker("Frequency", selection: $viewModel.frequency) {
                ForEach(viewModel.availableFrequencies, id: \.self) { frequency in
                    Text(frequency).tag(frequency)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
    }
    
    private var daySelector: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.frequency == "Weekly" ? "Day of Week" : "Day of Month")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            
            HStack {
                Stepper(value: $viewModel.dayOfMonthWeek, 
                       in: viewModel.frequency == "Weekly" ? 1...7 : 1...31) {
                    Text("\(viewModel.dayOfMonthWeek)")
                        .font(AppFonts.body)
                        .foregroundColor(AppColors.textPrimary)
                }
                
                Spacer()
                
                Text(dayDescription)
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
        }
    }
    
    private var dateSection: some View {
        Section {
            startDatePicker
            endDateSection
        }
    }
    
    private var startDatePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
//            Text("Start Date")
//                .font(AppFonts.body)
//                .foregroundColor(AppColors.textPrimary)
            
            DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                .datePickerStyle(CompactDatePickerStyle())
        }
    }
    
    private var endDateSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Has End Date", isOn: $viewModel.hasEndDate)
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            
            if viewModel.hasEndDate {
                endDatePicker
            }
        }
    }
    
    private var endDatePicker: some View {
        DatePicker("End Date", selection: Binding(
            get: { viewModel.endDate ?? Date() },
            set: { viewModel.endDate = $0 }
        ), displayedComponents: .date)
        .datePickerStyle(CompactDatePickerStyle())
    }
    

    
    private var iconSelectionSection: some View {
        Section {
            iconSelectionContent
        }
    }
    
    private var iconSelectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Icon")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)

            iconGrid
        }
        .padding(.vertical, 8)
    }
    
    private var iconGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
            ForEach(viewModel.availableIcons, id: \.self) { icon in
                iconButton(for: icon)
            }
        }
    }
    
    private func iconButton(for icon: String) -> some View {
        Button {
            viewModel.icon = icon
        } label: {
            iconButtonContent(for: icon)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func iconButtonContent(for icon: String) -> some View {
        Image(systemName: icon)
            .font(.title2)
            .foregroundColor(viewModel.icon == icon ? .white : AppColors.textPrimary)
            .frame(width: 44, height: 44)
            .background(iconButtonBackground(for: icon))
            .overlay(iconButtonOverlay)
    }
    
    private func iconButtonBackground(for icon: String) -> some View {
        Circle()
            .fill(viewModel.icon == icon ? AppColors.primary : AppColors.backgroundLight)
    }
    
    private var iconButtonOverlay: some View {
        Circle()
            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
    }
    
    private var colorSelectionSection: some View {
        Section {
            colorSelectionContent
        }
    }
    
    private var colorSelectionContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Color")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)

            colorGrid
        }
        .padding(.vertical, 8)
    }
    
    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
            ForEach(viewModel.availableColors, id: \.self) { color in
                colorButton(for: color)
            }
        }
    }
    
    private func colorButton(for color: String) -> some View {
        Button {
            viewModel.color = color
        } label: {
            colorButtonContent(for: color)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func colorButtonContent(for color: String) -> some View {
        Circle()
            .fill(viewModel.getSystemColor(for: color))
            .frame(width: 32, height: 32)
            .overlay(colorButtonOverlay(for: color))
            .shadow(
                color: viewModel.color == color ? AppColors.primary.opacity(0.3) : .clear,
                radius: 4, x: 0, y: 2
            )
    }
    
    private func colorButtonOverlay(for color: String) -> some View {
        Circle()
            .stroke(
                viewModel.color == color ? AppColors.primary : AppColors.secondary.opacity(0.3),
                lineWidth: viewModel.color == color ? 3 : 1
            )
    }
    
    private var statusSection: some View {
        Section {
            Toggle("Active", isOn: $viewModel.isActive)
                .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            
            Text("Inactive recurring expenses won't generate new transactions")
                .font(AppFonts.small)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var previewSection: some View {
        Section {
            previewContent
        }
        .listRowBackground(AppColors.cardBackground)
    }
    
    private var previewContent: some View {
        VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
            Text("Preview")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textSecondary)

            previewCard
        }
    }
    
    private var previewCard: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            Image(systemName: viewModel.icon)
                .font(.title2)
                .foregroundColor(viewModel.getSystemColor(for: viewModel.color))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 6) {
                previewTitleLine
                previewAmountLine
                previewDetailsLine
            }

            Spacer()
        }
        .padding()
        .background(AppColors.backgroundLight)
        .cornerRadius(AppSpacing.cornerRadius)
    }
    
    private var previewTitleLine: some View {
        HStack(spacing: 8) {
            Text(viewModel.title.isEmpty ? "Recurring Expense" : viewModel.title)
                .font(AppFonts.body)
                .foregroundColor(viewModel.title.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

            Text(viewModel.isActive ? "Active" : "Inactive")
                .font(AppFonts.small)
                .foregroundColor(viewModel.isActive ? AppColors.primary : AppColors.textSecondary)
        }
    }
    
    private var previewAmountLine: some View {
        Text("$\(viewModel.amount.isEmpty ? "0.00" : viewModel.amount)")
            .font(AppFonts.small)
            .foregroundColor(AppColors.textSecondary)
    }
    
    private var previewDetailsLine: some View {
        HStack(spacing: 12) {
            if !viewModel.frequency.isEmpty {
                frequencyDisplay
            }

            if !viewModel.notes.isEmpty {
                notesDisplay
            }
        }
    }
    
    private var frequencyDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: frequencyIcon(for: viewModel.frequency))
            Text(viewModel.frequency)
        }
        .font(AppFonts.small)
        .foregroundColor(AppColors.textSecondary)
    }
    
    private var notesDisplay: some View {
        HStack(spacing: 4) {
            Image(systemName: "note.text")
            Text(viewModel.notes)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(AppFonts.small)
        .foregroundColor(AppColors.textSecondary)
    }
    
    @ViewBuilder
    private var errorSection: some View {
        if let errorMessage = viewModel.errorMessage {
            Section {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(AppColors.error)
                    Text(errorMessage)
                        .font(AppFonts.small)
                        .foregroundColor(AppColors.error)
                }
                .padding()
                .background(AppColors.error.opacity(0.1))
                .cornerRadius(AppSpacing.cornerRadius)
            }
            .listRowBackground(Color.clear)
        }
    }
    
    // MARK: - Computed Properties
    
    private var dayDescription: String {
        if viewModel.frequency == "Weekly" {
            let weekdays = ["", "Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
            return weekdays[min(viewModel.dayOfMonthWeek, 7)]
        } else {
            let ordinal = viewModel.dayOfMonthWeek
            switch ordinal {
            case 1: return "1st"
            case 2: return "2nd"
            case 3: return "3rd"
            case 21: return "21st"
            case 22: return "22nd"
            case 23: return "23rd"
            case 31: return "31st"
            default: return "\(ordinal)th"
            }
        }
    }
    
    private func frequencyIcon(for frequency: String) -> String {
        switch frequency.lowercased() {
        case "daily": return "calendar.badge.plus"
        case "weekly": return "calendar.circle"
        case "monthly": return "calendar.badge.plus"
        case "yearly": return "calendar.badge.clock"
        default: return "calendar"
        }
    }
    
    private func getSystemColor(for colorString: String) -> Color {
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
}

//#Preview {
//    AddRecurringView(viewModel: RecurringExpenseViewModel(), user: AppUser())
//}
