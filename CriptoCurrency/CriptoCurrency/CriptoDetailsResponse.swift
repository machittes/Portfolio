//
//  CriptoDetailsResponse.swift
//  CriptoCurrency
//
//  Created by Henrique Machitte on 06/03/25.
//

import Foundation

struct CriptoDetailsResponse: Codable {
    let criptoDetails: [CriptoDetails]
}

struct CriptoDetails: Identifiable, Codable {
    let id: String
    let name: String
    let symbol: String
    let logo: String?
    let started_at: String?
    let hash_algorithm: String?
    
    var logoURL: URL? {
            return URL(string: logo ?? "")
        }
    
}


