package com.example.henrique_book

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import androidx.lifecycle.lifecycleScope
import androidx.recyclerview.widget.LinearLayoutManager
import com.example.henrique_book.databinding.ActivityMainBinding
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class MainActivity : AppCompatActivity() {

    private lateinit var binding: ActivityMainBinding
    private lateinit var bookAdapter: BookAdapter
    private val bookDao by lazy {
        BookDatabase.getDatabase(this).bookDao()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

        bookAdapter = BookAdapter(
            onEditClick = { selectedBook ->
                openAddEditBookActivity(selectedBook)
            },
            onDeleteClick = { bookToDelete ->
                deleteBook(bookToDelete)
            }
        )

        binding.recyclerView.apply {
            adapter = bookAdapter
            layoutManager = LinearLayoutManager(this@MainActivity)
        }

        observeBooks()
        binding.fabAddBook.setOnClickListener {
            openAddEditBookActivity(null)
        }
    }

    private fun observeBooks() {
        bookDao.getAllBooks().observe(this) { books ->
            bookAdapter.submitList(books)
        }
    }

    private fun deleteBook(book: Book) {
        lifecycleScope.launch(Dispatchers.IO) {
            bookDao.delete(book)
        }
    }

    private fun openAddEditBookActivity(book: Book?) {
        val intent = Intent(this, AddEditBookActivity::class.java)
        intent.putExtra("BOOK", book)
        startActivity(intent)
    }
}

