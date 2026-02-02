//
//  GameModels.swift
//  Bilsene
//
//  Created by İlke Saykı on 01.02.26.
//

import Foundation
import SwiftUI

// --- VERİ MODELİ ---
struct Kategori: Codable, Identifiable, Equatable {
    var id: String
    var baslik: String
    var kelimeler: [String]
    var renkKodu: String?
    var isCustom: Bool?
}

// --- OYUN GEÇMİŞİ MODELİ ---
struct OyunSonucu: Identifiable {
    let id = UUID()
    let kelime: String
    let dogruMu: Bool // true: Doğru, false: Pas
}
