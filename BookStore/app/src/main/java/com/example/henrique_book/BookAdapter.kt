package com.example.henrique_book

import android.view.LayoutInflater
import android.view.ViewGroup
import androidx.recyclerview.widget.DiffUtil
import androidx.recyclerview.widget.ListAdapter
import androidx.recyclerview.widget.RecyclerView
import com.example.henrique_book.databinding.ItemBookBinding

class BookAdapter(
    private val onEditClick: (Book) -> Unit,
    private val onDeleteClick: (Book) -> Unit
) : ListAdapter<Book, BookAdapter.BookViewHolder>(DiffCallback()) {

    class BookViewHolder(private val binding: ItemBookBinding) : RecyclerView.ViewHolder(binding.root) {
        fun bind(book: Book, onEditClick: (Book) -> Unit, onDeleteClick: (Book) -> Unit) {
            binding.tvTitle.text = book.title
            binding.tvAuthor.text = book.author
            binding.tvPrice.text = "Price: $${book.price}"
            binding.tvQuantity.text = "Qty: ${book.quantity}"
            binding.root.setOnClickListener { onEditClick(book) }
            binding.btnDelete.setOnClickListener { onDeleteClick(book) }
        }
    }

    override fun onCreateViewHolder(parent: ViewGroup, viewType: Int): BookViewHolder {
        val binding = ItemBookBinding.inflate(LayoutInflater.from(parent.context), parent, false)
        return BookViewHolder(binding)
    }

    override fun onBindViewHolder(holder: BookViewHolder, position: Int) {
        val book = getItem(position)
        holder.bind(book, onEditClick, onDeleteClick)
    }

    class DiffCallback : DiffUtil.ItemCallback<Book>() {
        override fun areItemsTheSame(oldItem: Book, newItem: Book): Boolean = oldItem.id == newItem.id
        override fun areContentsTheSame(oldItem: Book, newItem: Book): Boolean = oldItem == newItem
    }
}

