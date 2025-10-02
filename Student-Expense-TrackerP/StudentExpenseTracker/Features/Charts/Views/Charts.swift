import SwiftUI
import Charts
import UIKit

struct Charts: View {
    @Bindable var authVM: AuthViewModel
    @State private var viewModel = ChartViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 20) {
                    headerView
                    balanceCardsView
                }
                .padding()
                .background(AppColors.backgroundLight)

                ScrollView {
                    VStack(spacing: 20) {
                        periodSelectorView
                        chartSectionView
                        summaryCardsView
                        categoryBreakdownView
                        Spacer(minLength: 100)
                    }
                    .padding(.horizontal, 20)
                }
                .background(AppColors.backgroundDefault)
                .padding(.bottom, 80)
            }
        }
        .task {
            if let appUser = authVM.currentAppUser {
                await viewModel.loadData(for: appUser)
            }
        }
        .refreshable {
            if let appUser = authVM.currentAppUser {
                await viewModel.refreshData(for: appUser)
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView("Loading chart data...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.black.opacity(0.3))
            }
        }
        .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") {
                viewModel.errorMessage = nil
            }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var headerView: some View {
        HStack {
            Spacer()
            Text("Analysis")
                .font(AppFonts.title)
                .foregroundColor(AppColors.textPrimary)
            Spacer()
            NavigationLink(destination: CSVExportView(authVM: authVM)) {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(.blue)
                    .font(.title2)
            }
        }
    }

    private var balanceCardsView: some View {
        VStack(spacing: 20) {
            HStack(spacing: 30) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.caption)
                        Text("Total Balance")
                            .font(AppFonts.small)
                    }
                    Text(viewModel.formattedTotalBalance)
                        .font(AppFonts.subtitle)
                        .fontWeight(.bold)
                    HStack {
                        Text(viewModel.periodSummary.balanceChangeText)
                            .font(AppFonts.small)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .clipShape(Capsule())
                        Text("from last period")
                            .font(AppFonts.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                        Text("Total Expenses")
                            .font(AppFonts.small)
                    }
                    Text(viewModel.formattedTotalExpenses)
                        .font(AppFonts.subtitle)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                    Text("")
                        .font(AppFonts.small)
                        .frame(height: 20)
                        .opacity(0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 8) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .frame(width: geometry.size.width, height: 8)
                            .opacity(0.1)
                        Rectangle()
                            .frame(width: geometry.size.width * expenseProgressPercentage, height: 8)
                            .foregroundColor(.black)
                    }
                    .cornerRadius(4)
                }
                .frame(height: 8)

                HStack {
                    Text("\(Int(expenseProgressPercentage * 100))% of your expenses")
                        .font(AppFonts.body)
                        .foregroundColor(.white)
                    Spacer()
                    Text(viewModel.formattedTotalIncome)
                        .font(AppFonts.body)
                }
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(20)
    }

    private var expenseProgressPercentage: CGFloat {
        let income = viewModel.periodSummary.totalIncome.doubleValue
        let expenses = viewModel.periodSummary.totalExpenses.doubleValue
        guard income > 0 else { return 0 }
        return min(CGFloat(expenses / income), 1.0)
    }

    private var periodSelectorView: some View {
        HStack {
            ForEach(ChartPeriod.allCases, id: \.rawValue) { period in
                Button(action: {
                    viewModel.updateSelectedPeriod(period)
                }) {
                    Text(period.title)
                        .font(AppFonts.body)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(viewModel.selectedPeriod == period ? AppColors.backgroundLight : Color.gray.opacity(0.1))
                        .foregroundColor(viewModel.selectedPeriod == period ? .white : .black)
                        .cornerRadius(20)
                }
            }
        }
        .padding(.top)
    }

    private var chartSectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Income & Expenses")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                HStack(spacing: 12) {
                    Button(action: {
                        viewModel.selectedChartType = .bar
                    }) {
                        Circle()
                            .fill(viewModel.selectedChartType == .bar ? AppColors.backgroundLight : .gray.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "chart.bar.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(viewModel.selectedChartType == .bar ? .white : .gray)
                            )
                    }
                    Button(action: {
                        viewModel.selectedChartType = .line
                    }) {
                        Circle()
                            .fill(viewModel.selectedChartType == .line ? AppColors.backgroundLight : .gray.opacity(0.2))
                            .frame(width: 28, height: 28)
                            .overlay(
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 12))
                                    .foregroundColor(viewModel.selectedChartType == .line ? .white : .gray)
                            )
                    }
                }
            }

            if viewModel.chartData.isEmpty {
                VStack {
                    Image(systemName: "chart.bar")
                        .font(.system(size: 50))
                        .foregroundColor(.gray.opacity(0.5))
                    Text("No data available for selected period")
                        .font(AppFonts.small)
                        .foregroundColor(.gray)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            } else {
                Chart(viewModel.chartData) { item in
                    if viewModel.selectedChartType == .bar {
                        BarMark(
                            x: .value("Period", item.day),
                            y: .value("Amount", item.amount)
                        )
                        .foregroundStyle(item.isIncome ? AppColors.primary : AppColors.secondary)
                    } else {
                        LineMark(
                            x: .value("Period", item.day),
                            y: .value("Amount", item.amount),
                            series: .value("Type", item.isIncome ? "Income" : "Expense")
                        )
                        .foregroundStyle(item.isIncome ? AppColors.primary : AppColors.secondary)
                        .symbol(Circle().strokeBorder(lineWidth: 2))
                    }
                }
                .chartLegend(.visible)
                .frame(height: 150)
                .chartXAxis {
                    AxisMarks(values: .automatic) { _ in
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.gray)
                        AxisTick(stroke: StrokeStyle(lineWidth: 0))
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0))
                    }
                }
                .chartYAxis {
                    AxisMarks { _ in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [2]))
                            .foregroundStyle(.gray.opacity(0.3))
                        AxisTick(stroke: StrokeStyle(lineWidth: 0))
                        AxisValueLabel()
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }

    private var summaryCardsView: some View {
        HStack(spacing: 15) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.primary)
                Text("Income")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
                Text(viewModel.formattedTotalIncome)
                    .font(AppFonts.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text("\(viewModel.periodSummary.incomeCount) transactions")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppColors.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)

            VStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.title2)
                    .foregroundColor(AppColors.secondary)
                Text("Expense")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
                Text("$\(String(format: "%.2f", viewModel.periodSummary.totalExpenses.doubleValue))")
                    .font(AppFonts.body)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Text("\(viewModel.periodSummary.expenseCount) transactions")
                    .font(AppFonts.small)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(AppColors.backgroundDefault)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.05), radius: 3, x: 0, y: 1)
        }
    }

    private var categoryBreakdownView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Top Categories")
                    .font(AppFonts.subtitle)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }

            let topCategories = viewModel.getExpensesByCategory().prefix(5)

            if topCategories.isEmpty {
                Text("No expense categories for this period")
                    .font(AppFonts.small)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                ForEach(Array(topCategories.enumerated()), id: \.offset) { index, categoryData in
                    let (category, amount) = categoryData
                    HStack {
                        Image(systemName: category.icon ?? "questionmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(viewModel.getColorForCategory(category))
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(category.name ?? "Unknown")
                                .font(AppFonts.body)
                                .fontWeight(.medium)
                            Text("$\(String(format: "%.2f", amount.doubleValue))")
                                .font(AppFonts.small)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("#\(index + 1)")
                            .font(AppFonts.small)
                            .foregroundColor(.gray)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding(16)
        .background(AppColors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
    }
}
