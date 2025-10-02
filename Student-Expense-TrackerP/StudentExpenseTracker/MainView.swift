//
//  MainView.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 08/06/25.
//

import SwiftUI

struct MainView: View {
    @Bindable var authVM: AuthViewModel
    @Environment(SyncManager.self) private var syncManager
    @State private var selectedTab = 0
    @State private var recurringExpenseGenerationService: RecurringExpenseGenerationService
    @State private var recurringIncomeGenerationService: RecurringIncomeGenerationService
    
    init(authVM: AuthViewModel) {
        self.authVM = authVM
        self.recurringExpenseGenerationService = RecurringExpenseGenerationService(
            recurringExpenseRepository: RecurringExpenseRepository(),
            expenseRepository: ExpenseRepository(),
            authViewModel: authVM
        )
        self.recurringIncomeGenerationService = RecurringIncomeGenerationService(
                    recurringIncomeRepository: RecurringIncomeRepository(),
                    incomeRepository: IncomeRepository(),
                    authViewModel: authVM
        )
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // Sync Status Bar at the top
                if syncManager.isSyncing || syncManager.lastSyncError != nil {
                    SyncStatusView()
                        .transition(.move(edge: .top).combined(with: .opacity))
                }

                // Main Content
                Group {
                    switch selectedTab {
                    case 0:
                        DashboardView(authVM: authVM)
                    case 1:
                        IncomeExpenseView()
                    case 2:
                        Charts(authVM: authVM)
                    case 3:
                        SearchFilterView()
                    default:
                        DashboardView(authVM: authVM)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(AppColors.backgroundDefault)
            }

            // Bottom Navigation
            HStack(spacing: 40) {
                TabButton(
                    icon: "house.fill",
                    isSelected: selectedTab == 0,
                    action: { selectedTab = 0 }
                )
                
                TabButton(
                    icon: "arrow.up.arrow.down",
                    isSelected: selectedTab == 1,
                    action: { selectedTab = 1 }
                )
                
                TabButton(
                    icon: "chart.bar.fill",
                    isSelected: selectedTab == 2,
                    action: { selectedTab = 2 }
                )
                
                TabButton(
                    icon: "magnifyingglass",
                    isSelected: selectedTab == 3,
                    action: { selectedTab = 3 }
                )
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.vertical, AppSpacing.verticalPadding)
            //.background(AppColors.cardBackground)
            .background(Color.white)
            .cornerRadius(AppSpacing.cornerRadius * 2.5)
            .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 10, x: 0, y: 5)
            .padding(.horizontal, AppSpacing.horizontalPadding)
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
        .onAppear {
            handleAppLaunch()
        }
        .environment(recurringExpenseGenerationService)
        .environment(recurringIncomeGenerationService)
//        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
//            print("🔍 DEBUG: willEnterForegroundNotification fired!")
//            print("🔍 DEBUG: App is actually in foreground: \(UIApplication.shared.applicationState == .active)")
//            // Auto-sync when app comes to foreground
//            Task {
//                await syncManager.performFullSync()
//            }
//        }
        
        .animation(.easeInOut(duration: 0.3), value: syncManager.isSyncing)
        .animation(.easeInOut(duration: 0.3), value: syncManager.lastSyncError != nil)
    }
    
    private func handleAppLaunch() {
        Task {
            await recurringExpenseGenerationService.generateDueExpenses()
            await recurringIncomeGenerationService.generateDueIncomes()
        }
    }
}

// MARK: - Tab Button Component
struct TabButton: View {
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(isSelected ? AppColors.primary : AppColors.textSecondary)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? AppColors.primary.opacity(0.1) : Color.clear)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Preview
#Preview {
    MainView(authVM: AuthViewModel())
        .environment(SyncManager(authViewModel: AuthViewModel()))
}
