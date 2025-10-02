//
//  AppStyle.swift
//  StudentExpenseTracker
//
//  Created by Henrique Machitte on 28/05/25.
//
import SwiftUI

// MARK: - Color Palette

struct AppColors {
    static let primary = Color("Primary") // Main green: used for headers, buttons
    static let secondary = Color("Secondary") // Blue: used for category icons
    static let backgroundLight = Color("BackgroundLight") // Light background for highlights
    static let backgroundDefault = Color("BackgroundDefault") // Default screen background
    static let cardBackground = Color("CardBackground") // Background for cards and containers
    static let expenseNegative = Color("ExpenseNegative") // Dark blue: used for negative expenses
    static let textPrimary = Color("TextPrimary") // Main text color
    static let textSecondary = Color("TextSecondary") // Secondary text and descriptions
    static let error = Color("Error") // Red: used for error messages and invalid fields
}

// MARK: - Font Styles

struct AppFonts {
    static let title = Font.system(size: 28, weight: .bold) // Titles and headers
    static let subtitle = Font.system(size: 20, weight: .medium) // Section subtitles
    static let body = Font.system(size: 16, weight: .regular) // General text content
    static let small = Font.system(size: 14, weight: .light) // Small text, helper labels
}

// MARK: - Layout Spacing & Styling

struct AppSpacing {
    static let horizontalPadding: CGFloat = 16 // Standard horizontal padding
    static let verticalPadding: CGFloat = 12 // Standard vertical padding
    static let cornerRadius: CGFloat = 12 // Rounded corners for buttons/cards
    static let fieldHeight: CGFloat = 48 // Height for input fields and buttons
}

struct AppIcons {
    static let pencilIcon: String = "square.and.pencil"
}
