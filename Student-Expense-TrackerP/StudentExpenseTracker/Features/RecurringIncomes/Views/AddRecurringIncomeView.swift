//
//  AddRecurringIncomeView.swift
//  StudentExpenseTracker


import SwiftUI

struct AddRecurringIncomeView: View {
    @State var viewModel: RecurringIncomeViewModel
    let user: AppUser
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
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
            .navigationTitle("Add Recurring Income")
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
                await viewModel.addRecurringIncome(for: user)
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
            amountField
            sourceField
            notesField
        }
    }
    
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
    
    private var sourceField: some View {
        VStack(alignment: .leading) {
            Text("Source")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
            TextField("Enter income source", text: $viewModel.source)
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
    
    // MARK: - Frequency Section
    
    private var frequencySection: some View {
        Section("Frequency") {
            Picker("Frequency", selection: $viewModel.frequency) {
                ForEach(viewModel.availableFrequencies, id: \.self) { frequency in
                    Text(frequency).tag(frequency)
                }
            }
            .pickerStyle(.segmented)
            .padding(.vertical, 4)
            
            if viewModel.frequency == "Weekly" || viewModel.frequency == "Monthly" {
                dayOfWeekMonthPicker
            }
        }
    }
    
    private var dayOfWeekMonthPicker: some View {
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
    
    // MARK: - Date Section
    
    private var dateSection: some View {
        Section("Schedule") {
            DatePicker("Start Date", selection: $viewModel.startDate, displayedComponents: .date)
                .datePickerStyle(.compact)
            
            Toggle("Has End Date", isOn: $viewModel.hasEndDate)
                .toggleStyle(.switch)
                .tint(AppColors.primary)
            
            if viewModel.hasEndDate {
                DatePicker("End Date", selection: Binding(
                    get: { viewModel.endDate ?? Date() },
                    set: { viewModel.endDate = $0 }
                ), displayedComponents: .date)
                .datePickerStyle(.compact)
            }
        }
    }
    
    // MARK: - Icon Selection Section
    
    private var iconSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(viewModel.availableIcons, id: \.self) { icon in
                        Button {
                            viewModel.icon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(viewModel.icon == icon ? .white : AppColors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(viewModel.icon == icon ? AppColors.primary : AppColors.backgroundLight)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Color Selection Section
    
    private var colorSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(viewModel.availableColors, id: \.self) { color in
                        Button {
                            viewModel.color = color
                        } label: {
                            Circle()
                                .fill(viewModel.getSystemColorForString(color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            viewModel.color == color ? AppColors.primary : AppColors.secondary.opacity(0.3),
                                            lineWidth: viewModel.color == color ? 3 : 1
                                        )
                                )
                                .shadow(
                                    color: viewModel.color == color ? AppColors.primary.opacity(0.3) : .clear,
                                    radius: 4, x: 0, y: 2
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }
    
    // MARK: - Status Section
    
    private var statusSection: some View {
        Section("Status") {
            Toggle("Active", isOn: $viewModel.isActive)
                .toggleStyle(.switch)
                .tint(AppColors.primary)
        }
    }
    
    // MARK: - Preview Section
    
    private var previewSection: some View {
        Section {
            VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
                Text("Preview")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)

                HStack(spacing: AppSpacing.horizontalPadding) {
                    Image(systemName: viewModel.icon)
                        .font(.title2)
                        .foregroundColor(viewModel.getSystemColorForString(viewModel.color))
                        .frame(width: 30)

                    VStack(alignment: .leading, spacing: 6) {
                        // Line 1: Source + Status
                        HStack(spacing: 8) {
                            Text(viewModel.source.isEmpty ? "Income Source" : viewModel.source)
                                .font(AppFonts.body)
                                .foregroundColor(viewModel.source.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

                            Text(viewModel.isActive ? "Active" : "Inactive")
                                .font(AppFonts.small)
                                .foregroundColor(viewModel.isActive ? .green : .red)
                        }

                        // Line 2: Amount + Frequency
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "dollarsign.circle")
                                Text("$\(viewModel.amount)")
                            }
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)

                            HStack(spacing: 4) {
                                Image(systemName: viewModel.frequencyIcon(for: viewModel.frequency))
                                Text(viewModel.frequency)
                            }
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        }

                        // Line 3: Notes only (category removed)
                        if !viewModel.notes.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "note.text")
                                Text(viewModel.notes)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            }
                            .font(AppFonts.small)
                            .foregroundColor(AppColors.textSecondary)
                        }
                    }

                    Spacer()
                }
                .padding()
                .background(AppColors.backgroundLight)
                .cornerRadius(AppSpacing.cornerRadius)
            }
        }
    }
    
    // MARK: - Error Section
    
    private var errorSection: some View {
        Group {
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
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func weekdayName(for day: Int) -> String {
        let weekdays = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
        return weekdays[day - 1]
    }
    
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
}
