package com.example.pizza_henrique

import java.io.Serializable
import java.util.concurrent.ThreadLocalRandom

enum class PizzaType{
    MEAT, VEGETARIAN
}

class Order: Serializable {
    var confirmationNumber: Int
    var pizzaChoice: PizzaType
    var numSlices: Int
    var pricePerSlice: Double
    var deliveryChoice: Boolean
    var deliveryCost: Double
    var subTotal: Double
    var tax: Double
    var total: Double

    constructor(pizzaChoice: PizzaType,numSlices: Int, deliveryChoice: Boolean) {
        this.pizzaChoice = pizzaChoice
        this.numSlices = numSlices

        this.confirmationNumber = ThreadLocalRandom.current().nextInt(1000, 10000)


        this.deliveryChoice = deliveryChoice
        this.deliveryCost = 0.0
        if (deliveryChoice == true){
            deliveryCost = 5.50
        }else if (deliveryChoice == false){
            deliveryCost = 0.0
        }

        this.pricePerSlice = 0.0
        if (pizzaChoice == PizzaType.MEAT) {
            pricePerSlice = 6.70
        } else if (pizzaChoice == PizzaType.VEGETARIAN) {
            pricePerSlice = 4.25
        }
        this.subTotal = (pricePerSlice * numSlices) + deliveryCost
        this.tax = subTotal * 0.13
        this.total = subTotal + tax


    }

    override fun toString(): String {
        return String.format(
            "Order Confirmed! Confirmation # %d\nYour Receipt:\nPizza Choice = %s\nNumber of Slices = %d\nPrice per Slice = $%.2f\nDelivery Cost = $%.2f\nSubTotal = $%.2f\nTax = $%.2f\nTotal = $%.2f",
            confirmationNumber,
            pizzaChoice,
            numSlices,
            pricePerSlice,
            deliveryCost,
            subTotal,
            tax,
            total
        )
    }


}