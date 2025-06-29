package com.example.pizza_henrique

import android.content.Intent
import android.os.Bundle
import androidx.appcompat.app.AppCompatActivity
import com.example.pizza_henrique.databinding.ActivityMainBinding

class MainActivity : AppCompatActivity() {


    lateinit var binding: ActivityMainBinding


    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        binding = ActivityMainBinding.inflate(layoutInflater)
        setContentView(binding.root)

//check if it is an entire pizza and change it dynamically
        binding.sPizza.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) {
                // if on, set to 8
                binding.etSlices.setText("8")
            } else {
                // if off, set to 0
                binding.etSlices.setText("0")
            }
        }

        //check if customer needs delivery
        var deliveryOn = false

        binding.sDelivery.setOnCheckedChangeListener { _, isChecked ->
            if (isChecked) {
                // deliveryChoice it is true
                deliveryOn = true
            } else {
                // deliveryChoice it is false
                deliveryOn = false
            }
        }


        binding.btnSubmit.setOnClickListener {

            //get the quantity of slices
            var quantityFromUI:Int = binding.etSlices.text.toString().toInt()

            //get the Pizza Type
            var selectedRadioButtonId = binding.rgPizzaSelector.checkedRadioButtonId
            var pizzaTypeFromUI: PizzaType = PizzaType.MEAT

            if (selectedRadioButtonId == R.id.rbMeat) {
                pizzaTypeFromUI = PizzaType.MEAT
            } else if (selectedRadioButtonId == R.id.rbVeg) {
                pizzaTypeFromUI = PizzaType.VEGETARIAN
            }

            //creating the order
            var pizzaOrder = Order (pizzaTypeFromUI, quantityFromUI, deliveryOn)

            //passing to the second screen


            //go to another screen
            val intent: Intent = Intent(this@MainActivity, PizzaReceipt::class.java)
            //passing to the second screen
            intent.putExtra("EXTRA_PIZZA_ORDER", pizzaOrder)
            startActivity(intent)




        }
    }
}
