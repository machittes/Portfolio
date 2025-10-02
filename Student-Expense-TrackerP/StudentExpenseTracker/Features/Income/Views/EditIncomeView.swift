//
//  EditIncomeView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//



import SwiftUI

struct EditIncomeView: View {
    @Bindable var viewModel: IncomeViewModel
    let user: AppUser
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            Form {
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

//                    Toggle("Recurring", isOn: $viewModel.isRecurring)
//                        .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
//
//                    Picker("Frequency", selection: $viewModel.incomeFrequency) {
//                        Text("Monthly").tag("Monthly")
//                        Text("Weekly").tag("Weekly")
//                        Text("Yearly").tag("Yearly")
//                    }
//                    .pickerStyle(SegmentedPickerStyle())
                }

                Section {
                    VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
                        Text("Preview")
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textSecondary)

                        HStack(spacing: AppSpacing.horizontalPadding) {
                            Image(systemName: viewModel.selectedIcon)
                                .font(.title2)
                                .foregroundColor(viewModel.getSystemColorForString(viewModel.selectedColor))
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 6) {
                                // Line 1: Source + Recurring
                                HStack(spacing: 8) {
                                    Text(viewModel.incomeSource.isEmpty ? "Income Source" : viewModel.incomeSource)
                                        .font(AppFonts.body)
                                        .foregroundColor(viewModel.incomeSource.isEmpty ? AppColors.textSecondary : AppColors.textPrimary)

                                    Text(viewModel.isRecurring ? "Recurring" : "One-time")
                                        .font(AppFonts.small)
                                        .foregroundColor(AppColors.textSecondary)
                                }

                                // Line 2: Amount
                                Text("$\(viewModel.incomeAmount)")
                                    .font(AppFonts.small)
                                    .foregroundColor(AppColors.textSecondary)

                                // Line 3: Frequency + Notes
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

                            Spacer()
                        }
                        .padding()
                        .background(AppColors.backgroundLight)
                        .cornerRadius(AppSpacing.cornerRadius)
                    }
                }
                .listRowBackground(AppColors.cardBackground)

            }
            .navigationTitle("Edit Income")
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
                            await viewModel.updateIncome(for: user)
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
        .onAppear {
            if let income = viewModel.selectedIncome {
                viewModel.incomeAmount = "\(income.amount?.doubleValue ?? 0.0)"
                viewModel.incomeSource = income.source ?? ""
                viewModel.incomeNotes = income.notes ?? ""
                viewModel.isRecurring = income.isRecurring
                viewModel.incomeFrequency = income.frequency ?? "Monthly"
            }
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

