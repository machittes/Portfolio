//
//  ContentView.swift
//  CriptoCurrency
//
//  Created by Henrique Machitte on 06/03/25.
//

import SwiftUI

struct ContentView: View {
    
    @ObservedObject var criptoViewModel = CriptoViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                Text("Most common Cripto Coins")
                    .font(.title2)
                    .padding(.top)
                
                List(self.criptoViewModel.criptos) { cripto in
                    NavigationLink(destination: CriptoDetailView(id: cripto.id)) {
                        VStack(alignment: .leading) {
                            Text(cripto.name)
                                .font(.headline)
                            Text(cripto.symbol)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .onAppear {
                self.criptoViewModel.fetchCripto()
            }
            .navigationTitle("Coins")
        }
    }
}

