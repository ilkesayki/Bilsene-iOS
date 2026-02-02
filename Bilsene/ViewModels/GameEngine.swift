//
//  GameEngine.swift
//  Bilsene
//
//  Created by İlke Saykı on 01.02.26.
//

import SwiftUI
import CoreMotion
import Combine
import AudioToolbox
import UIKit

// --- OYUN MOTORU ---
class GameEngine: ObservableObject {
    private var motionManager = CMMotionManager()
    private var timer: Timer?
    
    // --- KALICI AYARLAR ---
    @AppStorage("oyunSuresi") var secilenSure: Int = 60
    @AppStorage("sesAcik") var sesAcik: Bool = true
    @AppStorage("titresimAcik") var titresimAcik: Bool = true
    
    // UI Değişkenleri
    @Published var seciliKategori: Kategori?
    @Published var jsonKategoriler: [Kategori] = []
    @Published var ozelKategoriler: [Kategori] = []
    
    // Akıllı Torba Sistemi
    @Published var akilliTorbalar: [String: [String]] = [:]
    
    // --- YENİ EKLENDİ: OYUN GEÇMİŞİ ---
    @Published var oyunGecmisi: [OyunSonucu] = []
    
    var tumKategoriler: [Kategori] {
        return ozelKategoriler + jsonKategoriler
    }
    
    // Ekran Durumları
    @Published var oyunAktif = false
    @Published var sonucEkraniAktif = false
    @Published var araEkranAktif = false
    @Published var ayarlarAcik = false
    @Published var yeniKategoriEkleAcik = false
    
    // Takım Modu
    @Published var takimModuAcik = false
    @Published var suankiTakim = "Takım A"
    @Published var takimAPuani = 0
    @Published var takimBPuani = 0
    @Published var kazananMesaji = ""
    
    // Oyun İçi Veriler
    @Published var suankiKelime = "Hazır mısın?"
    @Published var durumRengi: Durum = .notr
    @Published var kalanSure = 60
    @Published var anlikPuan = 0
    
    enum Durum {
        case notr, dogru, pas, hazir
    }
    
    private var kelimeHavuzu: [String] = []
    private var islemKilitli = false
    
    init() {
        verileriYukle()
        ozelKategorileriYukle()
    }
    
    // --- TORBA YÖNETİMİ ---
    func torbayiHazirla(kategori: Kategori) {
        if akilliTorbalar[kategori.id] == nil {
            akilliTorbalar[kategori.id] = kategori.kelimeler.shuffled()
        }
        
        if let kalanlar = akilliTorbalar[kategori.id], kalanlar.count < 5 {
            let yeniDeste = kategori.kelimeler.shuffled()
            let eklenecekler = yeniDeste.filter { !kalanlar.contains($0) }
            akilliTorbalar[kategori.id]?.append(contentsOf: eklenecekler)
        }
        
        if let guncelTorba = akilliTorbalar[kategori.id] {
            kelimeHavuzu = guncelTorba
        }
    }
    
    func torbadanKelimeDus() {
        guard let katID = seciliKategori?.id else { return }
        if var torba = akilliTorbalar[katID] {
            if let index = torba.firstIndex(of: suankiKelime) {
                torba.remove(at: index)
            } else if !torba.isEmpty {
                torba.removeFirst()
            }
            akilliTorbalar[katID] = torba
        }
    }
    
    // --- KATEGORİ YÖNETİMİ ---
    func ozelKategoriEkle(baslik: String, kelimeler: [String]) {
        let yeniKategori = Kategori(id: UUID().uuidString, baslik: baslik, kelimeler: kelimeler, isCustom: true)
        ozelKategoriler.insert(yeniKategori, at: 0)
        kaydet()
    }
    
    func ozelKategoriSil(kategori: Kategori) {
        if let index = ozelKategoriler.firstIndex(of: kategori) {
            ozelKategoriler.remove(at: index)
            kaydet()
        }
    }
    
    func kaydet() {
        if let encoded = try? JSONEncoder().encode(ozelKategoriler) {
            UserDefaults.standard.set(encoded, forKey: "ozelKategoriler")
        }
    }
    
    func ozelKategorileriYukle() {
        if let data = UserDefaults.standard.data(forKey: "ozelKategoriler") {
            if let decoded = try? JSONDecoder().decode([Kategori].self, from: data) {
                ozelKategoriler = decoded
                return
            }
        }
        ozelKategoriler = []
    }
    
    // --- OYUN MANTIĞI ---
    func geriBildirimVer(tip: String) {
        let generator = UINotificationFeedbackGenerator()
        if titresimAcik { generator.prepare() }
        switch tip {
        case "DOGRU":
            if titresimAcik { generator.notificationOccurred(.success) }
            if sesAcik { AudioServicesPlaySystemSound(1057) }
        case "PAS":
            if titresimAcik { generator.notificationOccurred(.error) }
            if sesAcik { AudioServicesPlaySystemSound(1053) }
        case "BITTI":
            if titresimAcik { generator.notificationOccurred(.warning) }
            if sesAcik { AudioServicesPlaySystemSound(1005) }
        default: break
        }
    }
    
    func verileriYukle() {
        yerelVeriyiYukle()
        guncelVeriyiIndir()
    }
    
    func yerelVeriyiYukle() {
        if let kayitliData = UserDefaults.standard.data(forKey: "cachedKategoriler") {
            if let decoded = try? JSONDecoder().decode([Kategori].self, from: kayitliData) {
                self.jsonKategoriler = decoded
                return
            }
        }
        if let dosyaYolu = Bundle.main.url(forResource: "data", withExtension: "json") {
            do {
                let data = try Data(contentsOf: dosyaYolu)
                self.jsonKategoriler = try JSONDecoder().decode([Kategori].self, from: data)
            } catch {
                print("Hata: Bundle okunamadı.")
            }
        }
    }
    
    func guncelVeriyiIndir() {
        let urlString = "https://gist.githubusercontent.com/ilkesayki/a2e0231d3c444708de3bd8bae4b408ad/raw/data.json"
        let urlWithCacheBust = urlString + "?v=\(UUID().uuidString)"
        
        guard let url = URL(string: urlWithCacheBust) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, error == nil else { return }
            if let decoded = try? JSONDecoder().decode([Kategori].self, from: data) {
                DispatchQueue.main.async {
                    self.jsonKategoriler = decoded
                    UserDefaults.standard.set(data, forKey: "cachedKategoriler")
                }
            }
        }.resume()
    }
    
    func oyunuBaslat(kategori: Kategori) {
        seciliKategori = kategori
        if takimModuAcik {
            suankiTakim = "Takım A"
            takimAPuani = 0
            takimBPuani = 0
        } else {
            suankiTakim = "Solo"
        }
        turuBaslat()
    }
    
    func turuBaslat() {
        guard let kat = seciliKategori else { return }
        torbayiHazirla(kategori: kat)
        
        // Yeni tur başlayınca geçmişi ve puanı temizle
        oyunGecmisi.removeAll()
        anlikPuan = 0
        kalanSure = secilenSure
        araEkranAktif = false
        sonucEkraniAktif = false
        oyunAktif = true
        yeniKelimeGetir()
        sensoruBaslat()
        zamanlayiciyiBaslat()
    }
    
    func oyunuBitir() {
        motionManager.stopDeviceMotionUpdates()
        timer?.invalidate()
        timer = nil
        oyunAktif = false
        geriBildirimVer(tip: "BITTI")
        
        if takimModuAcik {
            if suankiTakim == "Takım A" {
                takimAPuani = anlikPuan
                suankiTakim = "Takım B"
                araEkranAktif = true
                return
            } else if suankiTakim == "Takım B" {
                takimBPuani = anlikPuan
                sonucEkraniAktif = true
                kazananBelirle()
                return
            }
        }
        sonucEkraniAktif = true
    }
    
    func kazananBelirle() {
        if takimAPuani > takimBPuani {
            kazananMesaji = "🏆 KAZANAN:\nTAKIM A!"
        } else if takimBPuani > takimAPuani {
            kazananMesaji = "🏆 KAZANAN:\nTAKIM B!"
        } else {
            kazananMesaji = "🤝 BERABERE!"
        }
    }
    
    func menuyeDon() {
        sonucEkraniAktif = false
        araEkranAktif = false
        oyunAktif = false
    }
    
    private func zamanlayiciyiBaslat() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            if self.kalanSure > 0 {
                self.kalanSure -= 1
            } else {
                self.oyunuBitir()
            }
        }
    }
    
    private func yeniKelimeGetir() {
        if kelimeHavuzu.isEmpty {
            guard let kat = seciliKategori else { oyunuBitir(); return }
            akilliTorbalar[kat.id] = nil
            torbayiHazirla(kategori: kat)
            if kelimeHavuzu.isEmpty { oyunuBitir(); return }
        }
        
        suankiKelime = kelimeHavuzu.removeFirst()
        torbadanKelimeDus()
        durumRengi = .hazir
        islemKilitli = false
    }
    
    private func sensoruBaslat() {
        guard motionManager.isDeviceMotionAvailable else { return }
        motionManager.deviceMotionUpdateInterval = 0.1
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let data = data else { return }
            if !self.oyunAktif { return }
            let zEkseni = data.gravity.z
            if self.islemKilitli {
                if zEkseni > -0.2 && zEkseni < 0.2 {
                    self.durumRengi = .hazir
                    self.islemKilitli = false
                }
                return
            }
            if zEkseni > 0.8 {
                self.sonucIsle(durum: "DOĞRU!", yeniDurum: .dogru, isCorrect: true)
                self.geriBildirimVer(tip: "DOGRU")
            }
            if zEkseni < -0.8 {
                self.sonucIsle(durum: "PAS", yeniDurum: .pas, isCorrect: false)
                self.geriBildirimVer(tip: "PAS")
            }
        }
    }
    
    private func sonucIsle(durum: String, yeniDurum: Durum, isCorrect: Bool) {
        // GEÇMİŞE KAYDETME İŞLEMİ
        let yeniSonuc = OyunSonucu(kelime: suankiKelime, dogruMu: isCorrect)
        oyunGecmisi.append(yeniSonuc)
        
        islemKilitli = true
        durumRengi = yeniDurum
        suankiKelime = durum
        if isCorrect { anlikPuan += 1 }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if self.oyunAktif { self.yeniKelimeGetir() }
        }
    }
}
