package com.example.pizza_henrique

import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.pizza_henrique.databinding.ActivityPizzaReceiptBinding

class PizzaReceipt : AppCompatActivity() {


    lateinit var binding: ActivityPizzaReceiptBinding


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityPizzaReceiptBinding.inflate(layoutInflater)
        setContentView(binding.root)

        val pizzaOrder = intent.getSerializableExtra("EXTRA_PIZZA_ORDER") as? Order

        binding.tvReceipt.text = pizzaOrder.toString()


        binding.btnBack.setOnClickListener {
            //go back to main screen
            finish()

        }

    }
}