package com.example.henrique_book

import androidx.lifecycle.LiveData

class BookRepository(private val bookDao: BookDao) {

    val allBooks: LiveData<List<Book>> = bookDao.getAllBooks()

    suspend fun insertOrUpdate(book: Book) {
        bookDao.insertOrUpdate(book)
    }

    suspend fun update(book: Book) {
        bookDao.update(book)
    }

    suspend fun delete(book: Book) {
        bookDao.delete(book)
    }

    suspend fun getBookById(id: Int): Book? {
        return bookDao.getBookById(id)
    }
}
