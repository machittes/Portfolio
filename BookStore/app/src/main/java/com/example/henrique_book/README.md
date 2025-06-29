BookStore Inventory App

This is an Android application designed to manage a bookstore's inventory. It allows users to add, view, edit, and delete books with data persistence handled by Room Database.

Features

Add New Book
- Input details such as title, author, price, and quantity.
- Save the book to the database.
- 
View Books
- Display a list of all books in the inventory.
- Show key information like title, author, price, and quantity.

Edit Book Details
- Tap on a book to open the details screen.
- Update book information and save the changes.

Delete Book
- Remove books directly from the list using the "Delete" button.

Data Persistence
- All data is stored locally using Room Database.


Technology Stack

Kotlin: Primary language for app development.
Room Database: For data persistence.
RecyclerView: To display the list of books.
ConstraintLayout: For flexible and responsive layouts.


Code Structure

Book.kt: Data class representing a book.
BookDao.kt: Database access interface for CRUD operations.
BookDatabase.kt: Room database configuration.
BookAdapter.kt: Adapter for displaying books in the RecyclerView.
MainActivity.kt: Main screen displaying the list of books.
AddEditBookActivity.kt: Screen for adding or editing books.


How to Use

- Open the application.
- View the list of books in the inventory.
- Click the "+" button to add a new book.
- Tap on a book to edit its details.
- Use the "Delete" button to remove unwanted books.

Requirements

Android Studio Arctic Fox or higher.
Minimum SDK: 24.
Device or emulator running Android 7.0 (Nougat) or higher.