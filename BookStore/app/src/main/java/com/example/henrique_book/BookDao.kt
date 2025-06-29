package com.example.henrique_book

import androidx.lifecycle.LiveData
import androidx.room.Dao
import androidx.room.Delete
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Update

@Dao
interface BookDao {

    // Inserir ou atualizar um livro
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insertOrUpdate(book: Book)

    // Atualizar detalhes de um livro
    @Update
    suspend fun update(book: Book)

    // Deletar um livro
    @Delete
    suspend fun delete(book: Book)

    // Obter todos os livros
    @Query("SELECT * FROM books ORDER BY title ASC")
    fun getAllBooks(): LiveData<List<Book>>

    // Obter um livro pelo ID
    @Query("SELECT * FROM books WHERE id = :id")
    suspend fun getBookById(id: Int): Book?
}
