//
//  ExpenseDetailView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-17.
//


import SwiftUI

struct ExpenseDetailView_NotInUse: View {
    let expense: Expense
    @Bindable var viewModel: ExpenseViewModel
    let user: AppUser
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false
    @State private var showingReceiptFullScreen = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.verticalPadding * 2) {
                headerSection
                amountSection
                detailsSection
                categorySection
                dateSection
                
                if let notes = expense.notes, !notes.isEmpty {
                    notesSection
                }
                
                if expense.receiptImage != nil {
                    receiptSection
                }
                
                if expense.isRecurring {
                    recurringSection
                }
                
                metadataSection
                actionButtonsSection
            }
            .padding(AppSpacing.horizontalPadding)
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
        .navigationTitle("Expense Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        viewModel.setExpenseForEditing(expense)
                        viewModel.showingEditExpense = true
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(AppColors.primary)
                        .font(.title2)
                }
            }
        }
        .sheet(isPresented: $viewModel.showingEditExpense) {
            EditExpenseView(viewModel: viewModel, user: user)
        }
        .sheet(isPresented: $showingReceiptFullScreen) {
            if let receiptData = expense.receiptImage,
               let uiImage = UIImage(data: receiptData) {
                ReceiptFullScreenView(image: uiImage)
            }
        }
        .alert("Delete Expense", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteExpense(expense, for: user)
                    dismiss()
                }
            }
        } message: {
            Text("Are you sure you want to delete this expense? This action cannot be undone.")
        }
    }
    
    
    private var headerSection: some View {
        VStack(spacing: AppSpacing.verticalPadding) {
           
            ZStack {
                Circle()
                    .fill(categoryColor.opacity(0.2))
                    .frame(width: 80, height: 80)
                
                Image(systemName: expense.category?.icon ?? "creditcard.fill")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundColor(categoryColor)
            }
            
            
            Text(expense.category?.name ?? "Uncategorized")
                .font(AppFonts.title)
                .fontWeight(.bold)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.verticalPadding)
    }
    
    
    private var amountSection: some View {
        VStack(spacing: 8) {
            Text("\(expense.amount?.doubleValue ?? 0, specifier: "%.2f")")


                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(AppColors.error)
            
            HStack(spacing: 8) {
                Image(systemName: expense.isRecurring ? "arrow.clockwise" : "minus.circle")
                    .font(.caption)
                Text(expense.isRecurring ? "Recurring Expense" : "One-time Expense")
                    .font(AppFonts.small)
            }
            .foregroundColor(AppColors.textSecondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius * 2)
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
   
    private var detailsSection: some View {
        VStack(spacing: AppSpacing.verticalPadding) {
            if let notes = expense.notes, !notes.isEmpty {
                DetailRowView(
                    icon: "note.text",
                    title: "Description",
                    value: notes,
                    color: AppColors.secondary
                )
            }
        }
    }
    
   
    private var categorySection: some View {
        DetailRowView(
            icon: "folder.fill",
            title: "Category",
            value: expense.category?.name ?? "Uncategorized",
            color: categoryColor
        )
    }
    
    
    private var dateSection: some View {
        DetailRowView(
            icon: "calendar",
            title: "Date",
            value: expense.date?.formatted(date: .complete, time: .omitted) ?? "Unknown",
            color: AppColors.primary
        )
    }
    
   
    private var notesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
            HStack {
                Image(systemName: "note.text")
                    .foregroundColor(AppColors.secondary)
                Text("Notes")
                    .font(AppFonts.subtitle)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            Text(expense.notes ?? "")
                .font(AppFonts.body)
                .foregroundColor(AppColors.textPrimary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(AppColors.backgroundLight)
                .cornerRadius(AppSpacing.cornerRadius)
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius * 1.5)
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
   
    private var receiptSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
            HStack {
                Image(systemName: "paperclip")
                    .foregroundColor(AppColors.secondary)
                Text("Receipt")
                    .font(AppFonts.subtitle)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
                
                Button("View Full Size") {
                    showingReceiptFullScreen = true
                }
                .font(AppFonts.small)
                .foregroundColor(AppColors.primary)
            }
            
            if let receiptData = expense.receiptImage,
               let uiImage = UIImage(data: receiptData) {
                Button {
                    showingReceiptFullScreen = true
                } label: {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .cornerRadius(AppSpacing.cornerRadius)
                        .shadow(color: AppColors.textSecondary.opacity(0.2), radius: 4, x: 0, y: 2)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius * 1.5)
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
   
    private var recurringSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.verticalPadding) {
            HStack {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(AppColors.primary)
                Text("Recurring Details")
                    .font(AppFonts.subtitle)
                    .fontWeight(.semibold)
                    .foregroundColor(AppColors.textPrimary)
                Spacer()
            }
            
            VStack(spacing: 12) {
                DetailRowView(
                    icon: "calendar.badge.plus",
                    title: "Frequency",
                    value: "Monthly",
                    color: AppColors.primary,
                    isCompact: true
                )
                
                DetailRowView(
                    icon: "calendar.badge.clock",
                    title: "Next Payment",
                    value: nextPaymentDate,
                    color: AppColors.secondary,
                    isCompact: true
                )
            }
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius * 1.5)
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
   
    private var metadataSection: some View {
        VStack(spacing: 12) {
            if let createdAt = expense.createdAt {
                DetailRowView(
                    icon: "plus.circle",
                    title: "Created",
                    value: createdAt.formatted(date: .abbreviated, time: .shortened),
                    color: AppColors.textSecondary,
                    isCompact: true
                )
            }
            
            if let updatedAt = expense.updatedAt,
               let createdAt = expense.createdAt,
               updatedAt != createdAt {
                DetailRowView(
                    icon: "pencil.circle",
                    title: "Last Modified",
                    value: updatedAt.formatted(date: .abbreviated, time: .shortened),
                    color: AppColors.textSecondary,
                    isCompact: true
                )
            }
            
            DetailRowView(
                icon: "icloud",
                title: "Sync Status",
                value: syncStatusText,
                color: syncStatusColor,
                isCompact: true
            )
        }
        .padding()
        .background(AppColors.cardBackground)
        .cornerRadius(AppSpacing.cornerRadius * 1.5)
        .shadow(color: AppColors.textSecondary.opacity(0.1), radius: 2, x: 0, y: 1)
    }
    
   
    private var actionButtonsSection: some View {
        VStack(spacing: AppSpacing.verticalPadding) {
            
            Button {
                viewModel.setExpenseForEditing(expense)
                viewModel.showingEditExpense = true
            } label: {
                HStack {
                    Image(systemName: "pencil")
                    Text("Edit Expense")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.primary)
                .cornerRadius(AppSpacing.cornerRadius * 1.5)
            }
            
          
            Button {
                showingDeleteConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("Delete Expense")
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(AppColors.error)
                .cornerRadius(AppSpacing.cornerRadius * 1.5)
            }
        }
        .padding(.top, AppSpacing.verticalPadding)
    }
    
    
    private var categoryColor: Color {
        if let category = expense.category {
            return viewModel.getColorForCategory(category)
        } else {
            return Color.gray
        }
    }
    
    private var nextPaymentDate: String {
        guard let date = expense.date else { return "Unknown" }
        let calendar = Calendar.current
        let nextDate = calendar.date(byAdding: .month, value: 1, to: date) ?? date
        return nextDate.formatted(date: .abbreviated, time: .omitted)
    }
    
    private var syncStatusText: String {
        switch expense.syncStatus {
        case "synced": return "Synced"
        case "created": return "Pending Upload"
        case "updated": return "Pending Update"
        default: return "Unknown"
        }
    }
    
    private var syncStatusColor: Color {
        switch expense.syncStatus {
        case "synced": return .green
        case "created", "updated": return .orange
        default: return .red
        }
    }
}


struct DetailRowView: View {
    let icon: String
    let title: String
    let value: String
    let color: Color
    var isCompact: Bool = false
    
    var body: some View {
        HStack(spacing: AppSpacing.horizontalPadding) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: isCompact ? 20 : 24)
                .font(isCompact ? .body : .title3)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isCompact ? AppFonts.small : AppFonts.body)
                    .foregroundColor(AppColors.textSecondary)
                
                Text(value)
                    .font(isCompact ? AppFonts.body : AppFonts.subtitle)
                    .fontWeight(isCompact ? .medium : .semibold)
                    .foregroundColor(AppColors.textPrimary)
            }
            
            Spacer()
        }
        .padding(isCompact ? 12 : 16)
        .background(AppColors.backgroundLight)
        .cornerRadius(AppSpacing.cornerRadius)
    }
}


struct ReceiptFullScreenView: View {
    let image: UIImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ZoomableImageView(image: image)
                .background(Color.black)
                .navigationTitle("Receipt")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                        .foregroundColor(.white)
                    }
                }
                .preferredColorScheme(.dark)
        }
    }
}


struct ZoomableImageView: UIViewRepresentable {
    let image: UIImage
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = UIImageView(image: image)
        
        scrollView.delegate = context.coordinator
        scrollView.maximumZoomScale = 3.0
        scrollView.minimumZoomScale = 0.5
        scrollView.showsVerticalScrollIndicator = false
        scrollView.showsHorizontalScrollIndicator = false
        
        imageView.contentMode = .scaleAspectFit
        scrollView.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: scrollView.centerXAnchor),
            imageView.centerYAnchor.constraint(equalTo: scrollView.centerYAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.heightAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        let parent: ZoomableImageView
        
        init(_ parent: ZoomableImageView) {
            self.parent = parent
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.subviews.first
        }
    }
}


