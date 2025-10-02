import SwiftUI

struct IncomeExpenseView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
            // Title
            VStack(alignment: .leading, spacing: 8) {
                Text("Income & Expenses")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.textPrimary)

                Text("Choose a category below")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.top, AppSpacing.verticalPadding)

            // Card 1 - Income
            NavigationLink(destination: IncomeListView()) {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Income")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.textPrimary)

                            Text("Track all your income sources")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.white)
                .cornerRadius(AppSpacing.cornerRadius)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }

            // Card 2 - Recurring Incomes
            NavigationLink(destination: RecurringIncomeListView()) {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recurring Incomes")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.textPrimary)

                            Text("Set up automatic income sources")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.white)
                .cornerRadius(AppSpacing.cornerRadius)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }

            // Card 3 - Expense
            NavigationLink(destination: ExpenseListView()) {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Expense")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.textPrimary)

                            Text("Review your spending habits")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.down.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.white)
                .cornerRadius(AppSpacing.cornerRadius)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }

            // Card 4 - Recurring Expenses
            NavigationLink(destination: RecurringExpenseListView()) {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Recurring Expenses")
                                .font(AppFonts.title)
                                .foregroundColor(AppColors.textPrimary)

                            Text("Set up automatic expenses")
                                .font(AppFonts.body)
                                .foregroundColor(AppColors.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .frame(height: 140)
                .background(Color.white)
                .cornerRadius(AppSpacing.cornerRadius)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }

            Spacer()
        }
        .padding(.horizontal, AppSpacing.horizontalPadding)
        .background(AppColors.backgroundLight.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
