// StudentExpenseTracker/Features/ReusableViews/SyncStatusView.swift
import SwiftUI

struct SyncStatusView: View {
    @Environment(SyncManager.self) private var syncManager
    @State private var isExpanded = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Main Status Bar
            HStack(spacing: AppSpacing.horizontalPadding) {
                // Status Icon
                Group {
                    if syncManager.isSyncing {
                        ProgressView()
                            .scaleEffect(0.8)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else if syncManager.lastSyncError != nil {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                .frame(width: 24, height: 24)
                
                // Status Text
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStatusTitle)
                        .font(AppFonts.body)
                        .foregroundColor(.white)
                        .fontWeight(.medium)
                    
                    if syncManager.isSyncing {
                        Text("\(Int(syncManager.syncProgress * 100))% complete")
                            .font(AppFonts.small)
                            .foregroundColor(.white.opacity(0.8))
                    } else if let lastSync = syncManager.lastSyncAt {
                        Text("Last synced \(formatLastSyncTime(lastSync))")
                            .font(AppFonts.small)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Action Buttons
                HStack(spacing: 12) {
                    // Expand/Collapse Button
                    if syncManager.lastSyncError != nil || syncManager.isSyncing {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white)
                                .font(.system(size: 12, weight: .medium))
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Manual Sync Button
                    if !syncManager.isSyncing {
                        Button(action: {
                            Task {
                                await syncManager.performFullSync()
                            }
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.white)
                                .font(.system(size: 14, weight: .medium))
                                .frame(width: 28, height: 28)
                                .background(
                                    Circle()
                                        .fill(.white.opacity(0.2))
                                )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(.horizontal, AppSpacing.horizontalPadding)
            .padding(.vertical, AppSpacing.verticalPadding)
            .background(syncStatusColor)
            
            // Expanded Content
            if isExpanded {
                VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
                    if syncManager.isSyncing {
                        // Progress Details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Sync Progress")
                                    .font(AppFonts.small)
                                    .foregroundColor(.white.opacity(0.9))
                                
                                Spacer()
                                
                                Text(syncManager.currentOperation)
                                    .font(AppFonts.small)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            
                            ProgressView(value: syncManager.syncProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .background(.white.opacity(0.3))
                        }
                    } else if let error = syncManager.lastSyncError {
                        // Error Details
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.circle.fill")
                                    .foregroundColor(.white)
                                    .font(AppFonts.small)
                                
                                Text("Sync Failed")
                                    .font(AppFonts.body)
                                    .foregroundColor(.white)
                                    .fontWeight(.medium)
                            }
                            
                            Text(error.localizedDescription)
                                .font(AppFonts.small)
                                .foregroundColor(.white.opacity(0.9))
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if let suggestion = error.recoverySuggestion {
                                Text(suggestion)
                                    .font(AppFonts.small)
                                    .foregroundColor(.white.opacity(0.8))
                                    .italic()
                            }
                            
                            // Retry Button
                            Button(action: {
                                Task {
                                    await syncManager.performFullSync()
                                }
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 12, weight: .medium))
                                    Text("Try Again")
                                        .font(AppFonts.small)
                                        .fontWeight(.medium)
                                }
                                .foregroundColor(AppColors.error)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: AppSpacing.cornerRadius / 2)
                                        .fill(.white)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.horizontalPadding)
                .padding(.bottom, AppSpacing.verticalPadding)
                .background(syncStatusColor.opacity(0.9))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .cornerRadius(0) // Keep square for status bar
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 2)
    }
    
    // MARK: - Computed Properties
    
    private var syncStatusTitle: String {
        if syncManager.isSyncing {
            return "Syncing..."
        } else if syncManager.lastSyncError != nil {
            return "Sync Failed"
        } else {
            return "Synced"
        }
    }
    
    private var syncStatusColor: Color {
        if syncManager.lastSyncError != nil {
            return AppColors.error
        } else if syncManager.isSyncing {
            return AppColors.primary
        } else {
            return AppColors.secondary
        }
    }
    
    private func formatLastSyncTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Preview
#Preview("Syncing State") {
    VStack {
        SyncStatusView()
            .environment({
                let manager = SyncManager(authViewModel: AuthViewModel())
                // Simulate syncing state
                return manager
            }())
        
        Spacer()
    }
    .background(AppColors.backgroundDefault)
}

#Preview("Error State") {
    VStack {
        SyncStatusView()
            .environment({
                let manager = SyncManager(authViewModel: AuthViewModel())
                // Simulate error state
                return manager
            }())
        
        Spacer()
    }
    .background(AppColors.backgroundDefault)
}
