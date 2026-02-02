//
//  HelperViews.swift
//  Bilsene
//
//  Created by İlke Saykı on 01.02.26.
//

import SwiftUI

// --- TASARIM YARDIMCILARI ---

struct GradientBackground: View {
    var durum: GameEngine.Durum
    var body: some View {
        LinearGradient(gradient: Gradient(colors: renkleriGetir()), startPoint: .topLeading, endPoint: .bottomTrailing)
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.3), value: durum)
    }
    func renkleriGetir() -> [Color] {
        switch durum {
        case .notr: return [Color.blue, Color.cyan]
        case .hazir: return [Color.orange, Color.red]
        case .dogru: return [Color.green, Color(red: 0.0, green: 0.5, blue: 0.0)]
        case .pas: return [Color.red, Color(red: 0.5, green: 0.0, blue: 0.0)]
        }
    }
}

// --- EKRANLAR: EKLEME VE AYARLAR ---
struct YeniKategoriView: View {
    @ObservedObject var motor: GameEngine
    @Environment(\.dismiss) var dismiss
    @State private var baslik = ""
    @State private var kelimelerText = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("KATEGORİ BİLGİLERİ")) {
                    TextField("Kategori Adı (Örn: Bizim Sınıf)", text: $baslik)
                }
                Section(header: Text("KELİMELER (Alt alta yazın)")) {
                    TextEditor(text: $kelimelerText).frame(height: 200)
                }
            }
            .navigationTitle("Yeni Kategori")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("İptal") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { kaydetVeCik() }
                    .disabled(baslik.isEmpty || kelimelerText.isEmpty)
                }
            }
        }
    }
    
    func kaydetVeCik() {
        let kelimelerDizisi = kelimelerText.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if !kelimelerDizisi.isEmpty {
            motor.ozelKategoriEkle(baslik: baslik, kelimeler: kelimelerDizisi)
            dismiss()
        }
    }
}

struct AyarlarView: View {
    @ObservedObject var motor: GameEngine
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("OYUN AYARLARI")) {
                    Picker("Süre", selection: $motor.secilenSure) {
                        Text("30 Saniye").tag(30)
                        Text("60 Saniye").tag(60)
                        Text("90 Saniye").tag(90)
                        Text("120 Saniye").tag(120)
                    }
                    .pickerStyle(.segmented)
                }
                Section(header: Text("SES VE TİTREŞİM")) {
                    Toggle("Ses Efektleri", isOn: $motor.sesAcik)
                    Toggle("Titreşim", isOn: $motor.titresimAcik)
                }
            }
            .navigationTitle("Ayarlar")
            .toolbar { Button("Tamam") { dismiss() } }
        }
    }
}

struct SkorKutusu: View {
    var baslik: String
    var puan: Int
    var body: some View {
        VStack {
            Text(baslik).font(.headline).foregroundColor(.white.opacity(0.7))
            Text("\(puan)").font(.system(size: 60, weight: .bold, design: .rounded)).foregroundColor(.white)
        }
    }
}
