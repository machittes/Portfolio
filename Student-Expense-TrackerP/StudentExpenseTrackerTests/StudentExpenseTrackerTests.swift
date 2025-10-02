//
//  StudentExpenseTrackerTests.swift
//  StudentExpenseTrackerTests
//
//  Created by Hasan Rahmeh on 2025-07-16.
//



//✅ Checked if the form is valid when the name is filled or empty
//🔁 Tested that resetForm() clears all fields correctly
//✏️ Verified that prepareForEditing() fills the form with category values
//🎨 Tested getSystemColorForString() returns the right SwiftUI color

import Testing
@testable import StudentExpenseTracker

struct CategoryViewModelTests {
    
    @Test
    func isFormValid_shouldReturnTrue_whenNameIsNotEmpty() {
        let viewModel = CategoryViewModel()
        viewModel.categoryName = "Food"
        #expect(viewModel.isFormValid == true)
    }

    @Test
    func isFormValid_shouldReturnFalse_whenNameIsEmpty() {
        let viewModel = CategoryViewModel()
        viewModel.categoryName = "   " // just spaces
        #expect(viewModel.isFormValid == false)
    }

    @Test
    func resetForm_shouldClearAllFields() {
        var viewModel = CategoryViewModel()
        viewModel.categoryName = "Rent"
        viewModel.selectedColor = "red"
        viewModel.selectedIcon = "car.fill"
        viewModel.isDefault = true

        viewModel.resetForm()

        #expect(viewModel.categoryName == "")
        #expect(viewModel.selectedIcon == "questionmark.circle.fill")
        #expect(viewModel.selectedColor == "blue")
        #expect(viewModel.isDefault == false)
    }
    
    @Test
    func prepareForEditing_shouldFillFormWithCategoryValues() {
        let viewModel = CategoryViewModel()
        let context = PersistenceController(inMemory: true).viewContext
        let category = Category(context: context)
        category.name = "Fitness"
        category.icon = "heart.fill"
        category.color = "pink"
        category.isDefault = true

        viewModel.prepareForEditing(category)

        #expect(viewModel.categoryName == "Fitness")
        #expect(viewModel.selectedIcon == "heart.fill")
        #expect(viewModel.selectedColor == "pink")
        #expect(viewModel.isDefault == true)
    }
    
    @Test
    func getSystemColorForString_shouldReturnCorrectColor() {
        let viewModel = CategoryViewModel()

        #expect(viewModel.getSystemColorForString("red") == .red)
        #expect(viewModel.getSystemColorForString("mint") == .mint)
        #expect(viewModel.getSystemColorForString("unknown") == .blue) // default
    }
}
