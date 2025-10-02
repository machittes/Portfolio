//  AddExpenseView.swift
//  StudentExpenseTracker

import SwiftUI

struct AddExpenseView: View {
    @Bindable var viewModel: ExpenseViewModel
    let user: AppUser

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                basicFieldsSection
                iconSelectionSection
                colorSelectionSection
                previewSection
                errorSection
            }
            .navigationTitle("Add Expense")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(AppColors.textSecondary)
                    .font(AppFonts.body)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        Task {
                            await viewModel.addExpense(for: user)
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
                    .background(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .fill(viewModel.isFormValid ? AppColors.primary.opacity(0.1) : Color.clear)
                    )
                }
            }
            .background(AppColors.backgroundDefault.ignoresSafeArea())
            .onDisappear {
                viewModel.resetForm()
            }
        }
    }

    private var basicFieldsSection: some View {
        Section {
            HStack {
                Menu {
                    Button("All Categories") {
                        viewModel.selectedCategoryId = nil
                    }

                    ForEach(viewModel.categories, id: \.id) { category in
                        Button {
                            viewModel.selectedCategoryId = category.id
                        } label: {
                            HStack {
                                if let icon = category.icon {
                                    Image(systemName: icon)
                                }
                                Text(category.name ?? "Unknown")
                                    .font(AppFonts.body)
                            }
                        }
                    }
                } label: {
                    HStack {
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
                            .font(AppFonts.small)
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
                Spacer()
            }

            VStack(alignment: .leading) {
                Text("Expense Amount")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Enter expense amount", text: $viewModel.expenseAmount)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .font(AppFonts.body)
            }

            VStack(alignment: .leading) {
                Text("Title")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Enter title", text: $viewModel.expenseTitle)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .font(AppFonts.body)
            }

            VStack(alignment: .leading) {
                Text("Notes")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Enter notes", text: $viewModel.expenseNotes)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
                    .font(AppFonts.body)
            }

            VStack(alignment: .leading) {
                Text("Date")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
                    .font(AppFonts.body)
            }
        }
    }

    private var iconSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Icon")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 12) {
                    ForEach(viewModel.availableExpenseIcons, id: \.self) { icon in
                        Button {
                            viewModel.expenseIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(viewModel.expenseIcon == icon ? .white : AppColors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(viewModel.expenseIcon == icon ? AppColors.primary : AppColors.backgroundLight)
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

    private var colorSelectionSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Color")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 12) {
                    ForEach(viewModel.availableColors, id: \.self) { color in
                        Button {
                            viewModel.expenseColor = color
                        } label: {
                            Circle()
                                .fill(getSystemColor(for: color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            viewModel.expenseColor == color ? AppColors.primary : AppColors.secondary.opacity(0.3),
                                            lineWidth: viewModel.expenseColor == color ? 3 : 1
                                        )
                                )
                                .shadow(
                                    color: viewModel.expenseColor == color ? AppColors.primary.opacity(0.3) : .clear,
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
            Image(systemName: viewModel.expenseIcon)
                .font(.title2)
                .foregroundColor(getSystemColor(for: viewModel.expenseColor))
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
            Text(viewModel.expenseTitle.isEmpty ? "Expense Title" : viewModel.expenseTitle)
                .font(AppFonts.body)
                .foregroundColor(viewModel.expenseTitle.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

            Text(viewModel.isRecurring ? "Recurring" : "One-time")
                .font(AppFonts.small)
                .foregroundColor(AppColors.textSecondary)
        }
    }

    private var previewAmountLine: some View {
        Text("$\(viewModel.expenseAmount)")
            .font(AppFonts.small)
            .foregroundColor(AppColors.textSecondary)
    }

    private var previewDetailsLine: some View {
        HStack(spacing: 12) {
            if !viewModel.expenseFrequency.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: frequencyIcon(for: viewModel.expenseFrequency))
                    Text(viewModel.expenseFrequency)
                }
                .font(AppFonts.small)
                .foregroundColor(AppColors.textSecondary)
            }

            if !viewModel.expenseNotes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                    Text(viewModel.expenseNotes)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .font(AppFonts.small)
                .foregroundColor(AppColors.textSecondary)
            }
        }
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

private func frequencyIcon(for frequency: String) -> String {
    switch frequency.lowercased() {
    case "monthly": return "calendar.badge.plus"
    case "weekly": return "calendar.circle"
    case "yearly": return "calendar.badge.clock"
    default: return "calendar"
    }
}
