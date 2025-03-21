//
//  CriptoResponse.swift
//  CriptoCurrency
//
//  Created by Henrique Machitte on 06/03/25.
//
import Foundation

struct CriptoResponse: Codable {
    let cripto: [Cripto]
}

struct Cripto: Identifiable, Codable {
    let id: String
    let name: String
    let symbol: String
    
}
