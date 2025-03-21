//
//  CriptoViewModel.swift
//  CriptoCurrency
//
//  Created by Henrique Machitte on 06/03/25.
//

// Source for URL API
// First Page: https://api.coinpaprika.com/v1/coins
// Second Page: https://api.coinpaprika.com/v1/coins/btc-bitcoin
// Second Page: https://api.coinpaprika.com/v1/tickers/btc-bitcoin

//api with price for first page (optional) https://api.coinlore.net/api/tickers/

import Foundation
import Alamofire

class CriptoViewModel: ObservableObject {
    @Published var criptos: [Cripto] = []
    @Published var criptodetails: [CriptoDetails] = []
    
    func fetchCripto() {
        let apiURL = "https://api.coinpaprika.com/v1/coins"
        
        AF.request(apiURL)
            .validate()
            .response { resp in
                switch resp.result {
                case .success(let apiResponse):
                    do {
                        let jsonData = try JSONDecoder().decode([Cripto].self, from: apiResponse!)
                        self.criptos = jsonData.map { cripto in
                            return Cripto(id: cripto.id, name: cripto.name, symbol: cripto.symbol)
                        }
                    } catch {
                        print("Decoding cripto Failed: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    print("Fetching cripto Failed: \(error.localizedDescription)")
                }
            }
    }
    
    func fetchCriptoDetails (id: String) {
        let apiURL = "https://api.coinpaprika.com/v1/coins/\(id)"
        
        AF.request(apiURL)
            .validate()
            .response { resp in
                switch resp.result {
                case .success(let apiResponse):
                    do {
                        let jsonData = try JSONDecoder().decode(CriptoDetails.self, from: apiResponse!)
                        self.criptodetails = [jsonData] // Transformar o objeto em um array para exibição
                    } catch {
                        print("Decoding cripto details Failed: \(error.localizedDescription)")
                    }
                case .failure(let error):
                    print("Fetching cripto details Failed: \(error.localizedDescription)")
                }
            }
    }

    
    
}
