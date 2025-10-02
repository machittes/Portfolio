import SwiftUI
import PDFKit
import CoreData
import MessageUI
import UIKit

struct CSVExportView: View {
    @Bindable var authVM: AuthViewModel
    @State private var email: String = ""
    @State private var useMyEmail: Bool = true
    @State private var startDate: Date = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate: Date = Date()
    @State private var selectedCategory: Category? = nil
    @State private var useAllCategories: Bool = true
    @State private var isExporting = false
    @State private var showErrorAlert = false
    @State private var errorMessage = ""
    @State private var showMailView = false
    @State private var pdfData: Data? = nil
    @State private var showShareSheet = false
    @State private var pdfURL: URL? = nil

    private let expenseRepository = ExpenseRepository()
    private let incomeRepository = IncomeRepository()
    private let categoryRepository = CategoryRepository()
    private let pdfExportService = PDFExportService()

    @State private var categories: [Category] = []
    @State private var showCannotSendMailAlert = false

    var body: some View {
        ZStack {
            AppColors.backgroundDefault.ignoresSafeArea() // Gray background outside the form
            
            Form {
                // Email Section
                Section(header: Text("Email")) {
                    HStack {
                        Image(systemName: "envelope")
                            .foregroundColor(AppColors.secondary)
                        TextField("Email To Send Report", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                            .font(AppFonts.body)
                            .foregroundColor(AppColors.textPrimary)
                    }
                    
                    Toggle("Use My Email", isOn: $useMyEmail)
                        .toggleStyle(.switch)
                        .tint(AppColors.primary)
                    
                    
                }
                
                // Date Range Section
                Section(header: Text("Date Range")) {
                    HStack(spacing: AppSpacing.horizontalPadding) {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(AppColors.secondary)
                            DatePicker("", selection: $startDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(AppColors.secondary)
                            DatePicker("", selection: $endDate, displayedComponents: .date)
                                .labelsHidden()
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                // Category Section
                Section(header: Text("Category")) {
                    HStack {
                        Image(systemName: "tag")
                            .foregroundColor(AppColors.secondary)
                        Menu {
                            Button("All Categories") { selectedCategory = nil }
                            ForEach(categories, id: \.id) { category in
                                Button(category.name ?? "Unknown") {
                                    selectedCategory = category
                                }
                            }
                        } label: {
                            HStack {
                                Text(selectedCategory?.name ?? "All Categories")
                                    .font(AppFonts.body)
                                    .foregroundColor(AppColors.textPrimary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                    }
                    
                    Toggle("Include All Categories", isOn: $useAllCategories)
                        .toggleStyle(.switch)
                        .tint(AppColors.primary)
                }
                
                // Export Button Section
                Section {
                    Button(action: exportPDF) {
                        Text(isExporting ? "Generating PDF..." : "Export to PDF")
                            .font(AppFonts.body)
                            .frame(maxWidth: .infinity, minHeight: AppSpacing.fieldHeight)
                            .background(isExporting ? AppColors.secondary : AppColors.primary)
                            .foregroundColor(.white)
                            .cornerRadius(AppSpacing.cornerRadius)
                    }
                    .disabled(isExporting)
                }
            }
            .scrollContentBackground(.hidden) // Hide default form background
            .background(Color.white) // Set white background for the form
        }
            .navigationTitle("Export Report")
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(AppColors.backgroundLight, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)

            .task { await loadData()
            }
        .alert("Export Failed", isPresented: $showErrorAlert) {
            Button("OK") {}
        } message: {
            Text(errorMessage).font(AppFonts.body)
        }
        .alert("Cannot Send Email", isPresented: $showCannotSendMailAlert) {
            Button("OK") {}
        } message: {
            Text("No mail account is set up on this device. Please configure Mail or use the share sheet.")
                .font(AppFonts.body)
        }
        .sheet(isPresented: $showMailView) { mailSheet }
        .sheet(isPresented: $showShareSheet) { shareSheet }
    }



    @ViewBuilder
    private var mailSheet: some View {
        if let pdfData = pdfData {
            MailView(
                recipient: useMyEmail ? (authVM.currentAppUser?.email ?? email) : email,
                subject: "Your Expense Report",
                body: "Please find attached your exported expense report.",
                attachmentData: pdfData,
                attachmentMimeType: "application/pdf",
                attachmentFileName: "ExpenseReport.pdf",
                isShowing: $showMailView
            )
        } else {
            EmptyView()
        }
    }

    @ViewBuilder
    private var shareSheet: some View {
        if let pdfURL = pdfURL {
            ShareSheet(activityItems: [pdfURL])
        } else {
            EmptyView()
        }
    }





    private func loadData() async {
        guard let currentUser = authVM.currentAppUser else { return }
        do {
            categories = try await categoryRepository.fetchCategories(for: currentUser)
        } catch {
            print("Failed to load categories: \(error)")
        }
    }





    
    private func exportPDF() {
        guard !email.isEmpty || useMyEmail else {
            errorMessage = "Please enter an email address"
            showErrorAlert = true
            return
        }
        
        isExporting = true
        
        Task {
            do {
                guard let currentUser = authVM.currentAppUser else {
                    await MainActor.run {
                        isExporting = false
                        errorMessage = "No user found. Please log in again."
                        showErrorAlert = true
                    }
                    return
                }
                
                let finalEmail = useMyEmail ? (currentUser.email ?? email) : email
                
                // Fetch data based on filters
                let expenses = try await fetchFilteredExpenses()
                let incomes = try await fetchFilteredIncomes()
                let categories = try await categoryRepository.fetchCategories(for: currentUser)
                
                // Generate PDF
                let pdfData = try await pdfExportService.generatePDF(
                    expenses: expenses,
                    incomes: incomes,
                    categories: categories,
                    startDate: startDate,
                    endDate: endDate,
                    userEmail: finalEmail
                )
                
                await MainActor.run {
                    self.pdfData = pdfData
                    self.isExporting = false
                    if MFMailComposeViewController.canSendMail() {
                        self.showMailView = true
                    } else {
                        // Save PDF to temp file and show share sheet
                        let tempDirectory = FileManager.default.temporaryDirectory
                        let fileName = "ExpenseReport.pdf"
                        let fileURL = tempDirectory.appendingPathComponent(fileName)
                        do {
                            try pdfData.write(to: fileURL)
                            self.pdfURL = fileURL
                            self.showShareSheet = true
                        } catch {
                            self.errorMessage = "Failed to save PDF for sharing."
                            self.showErrorAlert = true
                        }
                    }
                }
                
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = "Failed to generate PDF: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func fetchFilteredExpenses() async throws -> [Expense] {
        guard let currentUser = authVM.currentAppUser else { return [] }
        var expenses = try await expenseRepository.fetchExpenses(for: currentUser, includeDeleted: false)
        
        // Filter by date range
        expenses = expenses.filter { expense in
            guard let expenseDate = expense.date else { return false }
            return expenseDate >= startDate && expenseDate <= endDate
        }
        
        // Filter by category if specified
        if let selectedCategory = selectedCategory, !useAllCategories {
            expenses = expenses.filter { expense in
                expense.category?.id == selectedCategory.id
            }
        }
        
        return expenses
    }
    
    private func fetchFilteredIncomes() async throws -> [Income] {
        guard let currentUser = authVM.currentAppUser else { return [] }
        var incomes = try await incomeRepository.fetchIncomes(for: currentUser, includeDeleted: false)
        
        // Filter by date range
        incomes = incomes.filter { income in
            guard let incomeDate = income.date else { return false }
            return incomeDate >= startDate && incomeDate <= endDate
        }
        
        return incomes
    }
    
    private func savePDFToFiles(pdfData: Data) async throws -> URL {
        // Create a temporary file in the app's temporary directory
        let tempDirectory = FileManager.default.temporaryDirectory
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm"
        let fileName = "ExpenseReport_\(dateFormatter.string(from: Date())).pdf"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        try pdfData.write(to: fileURL)
        return fileURL
    }
    
    // MARK: - Additional Email Functions
    
    /// Send an existing PDF file via email
    func sendExistingPDF(pdfURL: URL, recipient: String, subject: String = "PDF Document") {
        do {
            let pdfData = try Data(contentsOf: pdfURL)
            self.pdfData = pdfData
            self.showMailView = true
        } catch {
            self.errorMessage = "Failed to read PDF file: \(error.localizedDescription)"
            self.showErrorAlert = true
        }
    }
    
    /// Send PDF data directly via email
    func sendPDFData(pdfData: Data, recipient: String, subject: String = "PDF Document", fileName: String = "Document.pdf") {
        self.pdfData = pdfData
        self.showMailView = true
    }
    
    // Example usage functions
    private func sendSamplePDFFromBundle() {
        // Try to find a sample PDF in the bundle
        if let pdfURL = Bundle.main.url(forResource: "SamplePDF", withExtension: "pdf") {
            sendExistingPDF(pdfURL: pdfURL, recipient: authVM.currentAppUser?.email ?? "test@example.com")
        } else {
            // Create a simple PDF if no sample exists
            createAndSendSamplePDF()
        }
    }
    
    private func sendPDFFromURL() {
        // Create a temporary PDF file and send it
        createAndSendSamplePDF()
    }
    
    private func sendPDFDataExample() {
        // Generate a simple PDF and send it as data
        let pdfData = generateSamplePDFData()
        
        if MFMailComposeViewController.canSendMail() {
            sendPDFData(
                pdfData: pdfData,
                recipient: authVM.currentAppUser?.email ?? "test@example.com",
                subject: "Sample PDF from App",
                fileName: "SampleDocument.pdf"
            )
        } else {
            // Fallback to share sheet
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileName = "SampleDocument.pdf"
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try pdfData.write(to: fileURL)
                self.pdfURL = fileURL
                self.showShareSheet = true
            } catch {
                errorMessage = "Failed to create sample PDF: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
    }
    
    private func createAndSendSamplePDF() {
        let pdfData = generateSamplePDFData()
        let tempDirectory = FileManager.default.temporaryDirectory
        let fileName = "SamplePDF.pdf"
        let fileURL = tempDirectory.appendingPathComponent(fileName)
        
        do {
            try pdfData.write(to: fileURL)
            
            if MFMailComposeViewController.canSendMail() {
                sendExistingPDF(
                    pdfURL: fileURL,
                    recipient: authVM.currentAppUser?.email ?? "test@example.com",
                    subject: "Sample PDF from App"
                )
            } else {
                // Fallback to share sheet
                self.pdfURL = fileURL
                self.showShareSheet = true
            }
        } catch {
            errorMessage = "Failed to create sample PDF: \(error.localizedDescription)"
            showErrorAlert = true
        }
    }
    
    private func generateSamplePDFData() -> Data {
        let pdfMetaData = [
            kCGPDFContextCreator: "Student Expense Tracker",
            kCGPDFContextAuthor: authVM.currentAppUser?.email ?? "User",
            kCGPDFContextTitle: "Sample PDF"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            let cgContext = context.cgContext
            let pageBounds = context.pdfContextBounds
            
            // Draw sample content
            let titleFont = UIFont.boldSystemFont(ofSize: 24)
            let bodyFont = UIFont.systemFont(ofSize: 14)
            
            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .foregroundColor: UIColor.black
            ]
            
            let bodyAttributes: [NSAttributedString.Key: Any] = [
                .font: bodyFont,
                .foregroundColor: UIColor.black
            ]
            
            let title = "Sample PDF Document"
            let subtitle = "Generated by Student Expense Tracker"
            let content = "This is a sample PDF document that demonstrates how to send PDFs via email from your app. You can customize this content as needed."
            
            title.draw(in: CGRect(x: 50, y: 50, width: pageBounds.width - 100, height: 30), withAttributes: titleAttributes)
            subtitle.draw(in: CGRect(x: 50, y: 90, width: pageBounds.width - 100, height: 20), withAttributes: bodyAttributes)
            content.draw(in: CGRect(x: 50, y: 130, width: pageBounds.width - 100, height: 100), withAttributes: bodyAttributes)
            
            // Add some sample data
            let sampleData = [
                "Date: \(Date().formatted(date: .abbreviated, time: .shortened))",
                "User: \(authVM.currentAppUser?.email ?? "Unknown")",
                "App Version: 1.0.0"
            ]
            
            var yPosition: CGFloat = 250
            for data in sampleData {
                data.draw(in: CGRect(x: 50, y: yPosition, width: pageBounds.width - 100, height: 20), withAttributes: bodyAttributes)
                yPosition += 25
            }
        }
        
        return pdfData
    }
}

// MARK: - PDF Export Service

class PDFExportService {
    func generatePDF(
        expenses: [Expense],
        incomes: [Income],
        categories: [Category],
        startDate: Date,
        endDate: Date,
        userEmail: String
    ) async throws -> Data {
        
        let pdfMetaData = [
            kCGPDFContextCreator: "Student Expense Tracker",
            kCGPDFContextAuthor: userEmail,
            kCGPDFContextTitle: "Financial Report"
        ]
        
        let format = UIGraphicsPDFRendererFormat()
        format.documentInfo = pdfMetaData as [String: Any]
        
        let pageRect = CGRect(x: 0, y: 0, width: 595.2, height: 841.8) // A4 size
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect, format: format)
        
        let pdfData = renderer.pdfData { context in
            context.beginPage()
            
            let cgContext = context.cgContext
            let pageBounds = context.pdfContextBounds
            
            // Calculate totals
            let totalExpenses = expenses.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }
            let totalIncome = incomes.reduce(Decimal.zero) { $0 + ($1.amount?.decimalValue ?? Decimal.zero) }
            let netBalance = totalIncome - totalExpenses
            
            // Header
            drawHeader(cgContext: cgContext, pageBounds: pageBounds, userEmail: userEmail)
            
            // Date Range
            drawDateRange(cgContext: cgContext, pageBounds: pageBounds, startDate: startDate, endDate: endDate)
            
            // Summary Section
            drawSummary(cgContext: cgContext, pageBounds: pageBounds, totalIncome: totalIncome, totalExpenses: totalExpenses, netBalance: netBalance)
            
            // Transactions Section
            drawTransactions(cgContext: cgContext, pageBounds: pageBounds, expenses: expenses, incomes: incomes)
            
            // Category Breakdown
            drawCategoryBreakdown(cgContext: cgContext, pageBounds: pageBounds, expenses: expenses, categories: categories)
        }
        
        return pdfData
    }
    
    private func drawHeader(cgContext: CGContext, pageBounds: CGRect, userEmail: String) {
        let titleFont = UIFont.boldSystemFont(ofSize: 24)
        let subtitleFont = UIFont.systemFont(ofSize: 14)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let subtitleAttributes: [NSAttributedString.Key: Any] = [
            .font: subtitleFont,
            .foregroundColor: UIColor.gray
        ]
        
        let title = "Financial Report"
        let subtitle = "Generated for: \(userEmail)"
        
        let titleRect = CGRect(x: 50, y: 50, width: pageBounds.width - 100, height: 30)
        let subtitleRect = CGRect(x: 50, y: 80, width: pageBounds.width - 100, height: 20)
        
        title.draw(in: titleRect, withAttributes: titleAttributes)
        subtitle.draw(in: subtitleRect, withAttributes: subtitleAttributes)
    }
    
    private func drawDateRange(cgContext: CGContext, pageBounds: CGRect, startDate: Date, endDate: Date) {
        let font = UIFont.systemFont(ofSize: 12)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.black
        ]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        
        let dateRangeText = "Period: \(dateFormatter.string(from: startDate)) - \(dateFormatter.string(from: endDate))"
        let dateRect = CGRect(x: 50, y: 120, width: pageBounds.width - 100, height: 20)
        
        dateRangeText.draw(in: dateRect, withAttributes: attributes)
    }
    
    private func drawSummary(cgContext: CGContext, pageBounds: CGRect, totalIncome: Decimal, totalExpenses: Decimal, netBalance: Decimal) {
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let valueFont = UIFont.systemFont(ofSize: 14)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let valueAttributes: [NSAttributedString.Key: Any] = [
            .font: valueFont,
            .foregroundColor: UIColor.black
        ]
        
        let yStart: CGFloat = 160
        let lineHeight: CGFloat = 25
        
        "Summary".draw(in: CGRect(x: 50, y: yStart, width: 200, height: 20), withAttributes: titleAttributes)
        
        let incomeText = "Total Income: $\(String(format: "%.2f", totalIncome.doubleValue))"
        let expenseText = "Total Expenses: $\(String(format: "%.2f", totalExpenses.doubleValue))"
        let balanceText = "Net Balance: $\(String(format: "%.2f", netBalance.doubleValue))"
        
        incomeText.draw(in: CGRect(x: 50, y: yStart + lineHeight, width: 300, height: 20), withAttributes: valueAttributes)
        expenseText.draw(in: CGRect(x: 50, y: yStart + lineHeight * 2, width: 300, height: 20), withAttributes: valueAttributes)
        balanceText.draw(in: CGRect(x: 50, y: yStart + lineHeight * 3, width: 300, height: 20), withAttributes: valueAttributes)
    }
    
    private func drawTransactions(cgContext: CGContext, pageBounds: CGRect, expenses: [Expense], incomes: [Income]) {
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let headerFont = UIFont.boldSystemFont(ofSize: 12)
        let dataFont = UIFont.systemFont(ofSize: 10)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let headerAttributes: [NSAttributedString.Key: Any] = [
            .font: headerFont,
            .foregroundColor: UIColor.black
        ]
        
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: dataFont,
            .foregroundColor: UIColor.black
        ]
        
        let yStart: CGFloat = 280
        let lineHeight: CGFloat = 20
        
        "Recent Transactions".draw(in: CGRect(x: 50, y: yStart, width: 200, height: 20), withAttributes: titleAttributes)
        
        // Headers
        let headers = ["Date", "Type", "Category", "Description", "Amount"]
        let columnWidths: [CGFloat] = [80, 60, 80, 200, 80]
        var xOffset: CGFloat = 50
        
        for (index, header) in headers.enumerated() {
            header.draw(in: CGRect(x: xOffset, y: yStart + lineHeight, width: columnWidths[index], height: 20), withAttributes: headerAttributes)
            xOffset += columnWidths[index]
        }
        
        // Draw transactions (limit to first 20 to fit on page)
        let expenseTransactions = expenses.map { (AnyHashable($0), "Expense") }
        let incomeTransactions = incomes.map { (AnyHashable($0), "Income") }
        let allTransactions = (expenseTransactions + incomeTransactions)
            .sorted {
                let date1 = ($0.0.base as? Expense)?.date ?? ($0.0.base as? Income)?.date ?? Date.distantPast
                let date2 = ($1.0.base as? Expense)?.date ?? ($1.0.base as? Income)?.date ?? Date.distantPast
                return date1 > date2
            }
            .prefix(20)
        
        var currentY = yStart + lineHeight * 2
        
        for (transaction, type) in allTransactions {
            guard currentY < pageBounds.height - 100 else { break }
            
            let date: Date
            let category: String
            let description: String
            let amount: Double
            
            if let expense = transaction.base as? Expense {
                date = expense.date ?? Date()
                category = expense.category?.name ?? "N/A"
                description = expense.notes ?? "No description"
                amount = expense.amount?.doubleValue ?? 0.0
            } else if let income = transaction.base as? Income {
                date = income.date ?? Date()
                category = income.source ?? "N/A"
                description = income.notes ?? "No description"
                amount = income.amount?.doubleValue ?? 0.0
            } else {
                date = Date()
                category = "N/A"
                description = "No description"
                amount = 0.0
            }
            
            let dateFormatter = DateFormatter()
            dateFormatter.dateStyle = .short
            
            let rowData = [
                dateFormatter.string(from: date),
                type,
                category,
                description,
                String(format: "$%.2f", amount)
            ]
            
            xOffset = 50
            for (index, data) in rowData.enumerated() {
                data.draw(in: CGRect(x: xOffset, y: currentY, width: columnWidths[index], height: 20), withAttributes: dataAttributes)
                xOffset += columnWidths[index]
            }
            
            currentY += lineHeight
        }
    }
    
    private func drawCategoryBreakdown(cgContext: CGContext, pageBounds: CGRect, expenses: [Expense], categories: [Category]) {
        let titleFont = UIFont.boldSystemFont(ofSize: 16)
        let dataFont = UIFont.systemFont(ofSize: 12)
        
        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: titleFont,
            .foregroundColor: UIColor.black
        ]
        
        let dataAttributes: [NSAttributedString.Key: Any] = [
            .font: dataFont,
            .foregroundColor: UIColor.black
        ]
        
        let yStart: CGFloat = 600
        let lineHeight: CGFloat = 20
        
        "Expense by Category".draw(in: CGRect(x: 50, y: yStart, width: 200, height: 20), withAttributes: titleAttributes)
        
        // Calculate category totals
        var categoryTotals: [String: Decimal] = [:]
        for expense in expenses {
            let categoryName = expense.category?.name ?? "Uncategorized"
            categoryTotals[categoryName, default: Decimal.zero] += expense.amount?.decimalValue ?? Decimal.zero
        }
        
        let sortedCategories = categoryTotals.sorted { $0.value > $1.value }
        var currentY = yStart + lineHeight
        
        for (categoryName, total) in sortedCategories.prefix(10) {
            guard currentY < pageBounds.height - 50 else { break }
            
            let categoryText = "\(categoryName): $\(String(format: "%.2f", total.doubleValue))"
            categoryText.draw(in: CGRect(x: 50, y: currentY, width: 300, height: 20), withAttributes: dataAttributes)
            
            currentY += lineHeight
        }
    }
}

// MARK: - MailView

struct MailView: UIViewControllerRepresentable {
    let recipient: String
    let subject: String
    let body: String
    let attachmentData: Data
    let attachmentMimeType: String
    let attachmentFileName: String
    @Binding var isShowing: Bool
    var resultHandler: ((Result<MFMailComposeResult, Error>) -> Void)? = nil
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailView
        init(_ parent: MailView) { self.parent = parent }
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            controller.dismiss(animated: true) {
                self.parent.isShowing = false
                if let error = error {
                    self.parent.resultHandler?(.failure(error))
                } else {
                    self.parent.resultHandler?(.success(result))
                }
            }
        }
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let vc = MFMailComposeViewController()
        vc.setToRecipients([recipient])
        vc.setSubject(subject)
        vc.setMessageBody(body, isHTML: false)
        vc.addAttachmentData(attachmentData, mimeType: attachmentMimeType, fileName: attachmentFileName)
        vc.mailComposeDelegate = context.coordinator
        return vc
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    static func dismantleUIViewController(_ uiViewController: MFMailComposeViewController, coordinator: Coordinator) {
        uiViewController.dismiss(animated: true)
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    let applicationActivities: [UIActivity]? = nil

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: applicationActivities)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - PDF Email Utility

class PDFEmailUtility {
    static func sendPDF(pdfData: Data,
                       recipient: String,
                       subject: String = "PDF Document",
                       fileName: String = "Document.pdf",
                       from viewController: UIViewController) {
        
        guard MFMailComposeViewController.canSendMail() else {
            // Fallback to share sheet if mail is not available
            let tempDirectory = FileManager.default.temporaryDirectory
            let fileURL = tempDirectory.appendingPathComponent(fileName)
            
            do {
                try pdfData.write(to: fileURL)
                let activityViewController = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                viewController.present(activityViewController, animated: true)
            } catch {
                print("Failed to save PDF for sharing: \(error)")
            }
            return
        }
        
        let mailComposer = MFMailComposeViewController()
        mailComposer.setToRecipients([recipient])
        mailComposer.setSubject(subject)
        mailComposer.setMessageBody("Please find the attached PDF document.", isHTML: false)
        mailComposer.addAttachmentData(pdfData, mimeType: "application/pdf", fileName: fileName)
        
        mailComposer.mailComposeDelegate = MailComposeDelegate.shared
        viewController.present(mailComposer, animated: true)
    }
    
    static func sendPDFFromURL(pdfURL: URL,
                              recipient: String,
                              subject: String = "PDF Document",
                              from viewController: UIViewController) {
        do {
            let pdfData = try Data(contentsOf: pdfURL)
            sendPDF(pdfData: pdfData, recipient: recipient, subject: subject, fileName: pdfURL.lastPathComponent, from: viewController)
        } catch {
            print("Failed to read PDF from URL: \(error)")
        }
    }
}

// MARK: - Mail Compose Delegate

class MailComposeDelegate: NSObject, MFMailComposeViewControllerDelegate {
    static let shared = MailComposeDelegate()
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        controller.dismiss(animated: true)
    }
}

#Preview {
    CSVExportView(authVM: AuthViewModel())
} 
