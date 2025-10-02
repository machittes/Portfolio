//
//  AddIncomeView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//

import SwiftUI

struct AddIncomeView: View {
    @Bindable var viewModel: IncomeViewModel
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
            .navigationTitle("Add Income")
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
                            await viewModel.addIncome(for: user)
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
        }
    }
    
    private var basicFieldsSection: some View {
        Section {
            VStack(alignment: .leading) {
                Text("Income Amount")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Enter income amount", text: $viewModel.incomeAmount)
                    .keyboardType(.decimalPad)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading) {
                Text("Source")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Enter source", text: $viewModel.incomeSource)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading) {
                Text("Notes")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                TextField("Enter notes", text: $viewModel.incomeNotes)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppSpacing.cornerRadius)
                            .stroke(AppColors.secondary.opacity(0.3), lineWidth: 1)
                    )
            }

            VStack(alignment: .leading) {
                Text("Date")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
                DatePicker("Select Date", selection: $viewModel.selectedDate, displayedComponents: .date)
                    .datePickerStyle(CompactDatePickerStyle())
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
                    ForEach(viewModel.availableIncomeIcons, id: \.self) { icon in
                        Button {
                            viewModel.selectedIcon = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title2)
                                .foregroundColor(viewModel.selectedIcon == icon ? .white : AppColors.textPrimary)
                                .frame(width: 44, height: 44)
                                .background(
                                    Circle()
                                        .fill(viewModel.selectedIcon == icon ? AppColors.primary : AppColors.backgroundLight)
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
                            viewModel.selectedColor = color
                        } label: {
                            Circle()
                                .fill(viewModel.getSystemColorForString(color))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            viewModel.selectedColor == color ? AppColors.primary : AppColors.secondary.opacity(0.3),
                                            lineWidth: viewModel.selectedColor == color ? 3 : 1
                                        )
                                )
                                .shadow(
                                    color: viewModel.selectedColor == color ? AppColors.primary.opacity(0.3) : .clear,
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
            Image(systemName: viewModel.selectedIcon)
                .font(.title2)
                .foregroundColor(viewModel.getSystemColorForString(viewModel.selectedColor))
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
            Text(viewModel.incomeSource.isEmpty ? "Income Source" : viewModel.incomeSource)
                .font(AppFonts.body)
                .foregroundColor(viewModel.incomeSource.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

            Text(viewModel.isRecurring ? "Recurring" : "One-time")
                .font(AppFonts.small)
                .foregroundColor(AppColors.textSecondary)
        }
    }
    
    private var previewAmountLine: some View {
        Text("$\(viewModel.incomeAmount)")
            .font(AppFonts.small)
            .foregroundColor(AppColors.textSecondary)
    }
    
    private var previewDetailsLine: some View {
        HStack(spacing: 12) {
            if !viewModel.incomeFrequency.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: frequencyIcon(for: viewModel.incomeFrequency))
                    Text(viewModel.incomeFrequency)
                }
                .font(AppFonts.small)
                .foregroundColor(AppColors.textSecondary)
            }

            if !viewModel.incomeNotes.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "note.text")
                    Text(viewModel.incomeNotes)
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

    private func frequencyIcon(for frequency: String) -> String {
        switch frequency.lowercased() {
        case "daily":
            return "calendar"
        case "weekly":
            return "calendar.circle"
        case "monthly":
            return "calendar.circle.fill"
        case "yearly":
            return "calendar.badge.clock"
        default:
            return "calendar"
        }
    }
}

