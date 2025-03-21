//
//  CriptoDetailView.swift
//  CriptoCurrency
//
//  Created by Henrique Machitte on 21/03/25.
//

import SwiftUI
import Alamofire

struct CriptoDetailView: View {
    let id: String
    @State private var criptoDetails: CriptoDetails?
    
    var body: some View {
        VStack(spacing: 16) {
            if let details = criptoDetails {
                if let imageURL = details.logoURL {
                    AsyncImage(url: imageURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                        default:
                            Image(systemName: "bitcoinsign.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                        }
                    }
                }
                
                Text(details.name)
                    .font(.title)
                    .bold()
                
                Text(details.symbol)
                    .font(.title2)
                    .foregroundColor(.gray)
                
                if let startedAt = details.started_at {
                    Text("Started at: \(startedAt)")
                }
                
                if let hashAlgorithm = details.hash_algorithm {
                    Text("Hash algorithm: \(hashAlgorithm)")
                }
            } else {
                ProgressView("Loading details...")
            }
        }
        .padding()
        .navigationTitle("Coin Details")
        .onAppear {
            fetchDetails()
        }
    }
    
    func fetchDetails() {
        let apiURL = "https://api.coinpaprika.com/v1/coins/\(id)"
        
        AF.request(apiURL)
            .validate()
            .response { resp in
                switch resp.result {
                case .success(let apiResponse):
                    do {
                        let jsonData = try JSONDecoder().decode(CriptoDetails.self, from: apiResponse!)
                        self.criptoDetails = jsonData
                    } catch {
                        print("Decoding cripto details Failed: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    print("Fetching cripto details Failed: \(error.localizedDescription)")
                }
            }
    }
}

