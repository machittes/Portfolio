package com.example.henrique_book

import android.os.Bundle
import android.widget.Toast
import androidx.appcompat.app.AppCompatActivity
import com.example.henrique_book.databinding.ActivityAddEditBookBinding
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch

class AddEditBookActivity : AppCompatActivity() {

    private lateinit var binding: ActivityAddEditBookBinding
    private var currentBook: Book? = null
    private val bookDao by lazy {
        BookDatabase.getDatabase(this).bookDao()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityAddEditBookBinding.inflate(layoutInflater)
        setContentView(binding.root)


        currentBook = intent.getParcelableExtra("BOOK")

        // Preencher os campos se for edição
        currentBook?.let { book ->
            binding.etTitle.setText(book.title)
            binding.etAuthor.setText(book.author)
            binding.etPrice.setText(book.price.toString())
            binding.etQuantity.setText(book.quantity.toString())
        }

        // Configurar o botão "Salvar"
        binding.btnSave.setOnClickListener {
            val title = binding.etTitle.text.toString()
            val author = binding.etAuthor.text.toString()
            val price = binding.etPrice.text.toString().toDoubleOrNull() ?: 0.0
            val quantity = binding.etQuantity.text.toString().toIntOrNull() ?: 0

            if (title.isEmpty() || author.isEmpty()) {
                Toast.makeText(this, "Title and Author cannot be empty", Toast.LENGTH_SHORT).show()
                return@setOnClickListener
            }

            CoroutineScope(Dispatchers.IO).launch {
                if (currentBook == null) {
                    // Adicionar novo livro
                    val newBook = Book(title = title, author = author, price = price, quantity = quantity)
                    bookDao.insertOrUpdate(newBook)
                } else {
                    // Atualizar livro existente
                    val updatedBook = currentBook!!.copy(title = title, author = author, price = price, quantity = quantity)
                    bookDao.update(updatedBook)
                }
                finish() // Voltar para a tela principal
            }
        }
    }
}
