import SwiftUI
import CoreMotion
import Combine
import AudioToolbox
import UIKit

// --- VERİ MODELİ ---
struct Kategori: Codable, Identifiable, Equatable {
    var id: String
    var baslik: String
    var kelimeler: [String]
    var renkKodu: String?
    var isCustom: Bool?
}

// --- OYUN GEÇMİŞİ İÇİN YENİ YAPI ---
struct OyunSonucu: Identifiable {
    let id = UUID()
    let kelime: String
    let dogruMu: Bool // true: Doğru, false: Pas
}

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
        // GEÇMİŞE KAYDETME İŞLEMİ (Ekranda yazı değişmeden önce!)
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

// --- ANA ARAYÜZ (ContentView) ---
struct ContentView: View {
    @StateObject var motor = GameEngine()
    
    var body: some View {
        ZStack {
            if motor.oyunAktif {
                GradientBackground(durum: motor.durumRengi)
            } else {
                LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            }
            
            if motor.oyunAktif {
                // --- OYUN EKRANI ---
                GeometryReader { geometry in
                    HStack {
                        VStack(spacing: 15) {
                            Text(motor.takimModuAcik ? motor.suankiTakim : "SOLO")
                                .font(.system(.headline, design: .rounded))
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(10)
                                .foregroundColor(.white)
                            VStack {
                                Text("SÜRE").font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.8))
                                Text("\(motor.kalanSure)").font(.system(size: 45, weight: .black, design: .rounded))
                                    .foregroundColor(motor.kalanSure < 10 ? .red : .white).shadow(radius: 2)
                            }
                            VStack {
                                Text("PUAN").font(.caption2).fontWeight(.bold).foregroundColor(.white.opacity(0.8))
                                Text("\(motor.anlikPuan)").font(.system(size: 45, weight: .black, design: .rounded))
                                    .foregroundColor(.white).shadow(radius: 2)
                            }
                            Spacer()
                        }
                        .padding(.leading, 30).frame(width: 120)
                        
                        VStack {
                            Spacer()
                            ZStack {
                                RoundedRectangle(cornerRadius: 25).fill(Color.white)
                                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 10)
                                Text(motor.suankiKelime)
                                    .font(.system(size: 60, weight: .heavy, design: .rounded))
                                    .foregroundColor(.black)
                                    .multilineTextAlignment(.center)
                                    .minimumScaleFactor(0.4)
                                    .padding(20)
                                    .id(motor.suankiKelime)
                                    .transition(.opacity.combined(with: .scale))
                            }
                            .frame(height: geometry.size.width * 0.6)
                            .padding(.horizontal, 20)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack {
                            Button(action: { motor.oyunuBitir() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 40)).foregroundColor(.white.opacity(0.8)).shadow(radius: 3)
                            }
                            .padding()
                            Spacer()
                        }
                    }
                    .frame(width: geometry.size.height, height: geometry.size.width)
                    .rotationEffect(.degrees(90))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                }
                .ignoresSafeArea()
                
            } else if motor.araEkranAktif {
                // --- ARA EKRAN ---
                ZStack {
                    LinearGradient(gradient: Gradient(colors: [Color.purple, Color.indigo]), startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                    VStack(spacing: 30) {
                        Text("SÜRE BİTTİ!").font(.system(size: 30, weight: .bold, design: .rounded)).foregroundColor(.white.opacity(0.8))
                        Text("\(motor.takimAPuani)").font(.system(size: 80, weight: .heavy, design: .rounded)).foregroundColor(.white).shadow(radius: 10)
                        Text("Sıra Takım B'de").font(.title).fontWeight(.bold).foregroundColor(.yellow)
                        Button(action: { motor.turuBaslat() }) {
                            Text("BAŞLAT").font(.title2).fontWeight(.bold).padding()
                                .frame(width: 200).background(Color.white).foregroundColor(.purple).cornerRadius(20).shadow(radius: 5)
                        }
                    }
                }
            } else if motor.sonucEkraniAktif {
                // --- SONUÇ EKRANI (LİSTE EKLENDİ) ---
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 20) {
                        Text(motor.kazananMesaji.isEmpty ? "OYUN BİTTİ" : motor.kazananMesaji)
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .multilineTextAlignment(.center).foregroundColor(.yellow).padding(.top, 40)
                        
                        // SKOR TABLOSU
                        if motor.takimModuAcik {
                            HStack(spacing: 50) {
                                SkorKutusu(baslik: "Takım A", puan: motor.takimAPuani)
                                SkorKutusu(baslik: "Takım B", puan: motor.takimBPuani)
                            }
                        } else {
                            SkorKutusu(baslik: "Puan", puan: motor.anlikPuan)
                        }
                        
                        // KELİME LİSTESİ (BURASI YENİ)
                        VStack(alignment: .leading) {
                            Text("Oynanan Kelimeler:").font(.headline).foregroundColor(.gray).padding(.leading)
                            
                            ScrollView {
                                VStack(spacing: 10) {
                                    ForEach(motor.oyunGecmisi) { sonuc in
                                        HStack {
                                            Text(sonuc.kelime)
                                                .font(.system(size: 18, weight: .medium, design: .rounded))
                                                .foregroundColor(.white)
                                            Spacer()
                                            if sonuc.dogruMu {
                                                HStack {
                                                    Text("DOĞRU").font(.caption).bold()
                                                    Image(systemName: "checkmark.circle.fill")
                                                }
                                                .foregroundColor(.green)
                                            } else {
                                                HStack {
                                                    Text("PAS").font(.caption).bold()
                                                    Image(systemName: "minus.circle.fill")
                                                }
                                                .foregroundColor(.red)
                                            }
                                        }
                                        .padding()
                                        .background(Color.white.opacity(0.1))
                                        .cornerRadius(10)
                                    }
                                }
                                .padding(.horizontal)
                            }
                            .frame(maxHeight: 300) // Listenin boyunu sınırladık
                        }
                        
                        Button(action: { motor.menuyeDon() }) {
                            Text("MENÜYE DÖN").font(.headline).fontWeight(.bold).padding()
                                .frame(width: 220).background(LinearGradient(colors: [.blue, .purple], startPoint: .leading, endPoint: .trailing))
                                .foregroundColor(.white).cornerRadius(15)
                        }
                        .padding(.bottom, 20)
                    }
                }
            } else {
                // --- ANA MENÜ ---
                NavigationStack {
                    ZStack {
                        LinearGradient(gradient: Gradient(colors: [Color.blue, Color.cyan]), startPoint: .top, endPoint: .bottom).ignoresSafeArea()
                        VStack {
                            HStack {
                                Button(action: { motor.yeniKategoriEkleAcik = true }) {
                                    Image(systemName: "plus.circle.fill").font(.system(size: 30)).foregroundColor(.white)
                                        .padding().background(.ultraThinMaterial).clipShape(Circle())
                                }
                                .sheet(isPresented: $motor.yeniKategoriEkleAcik) { YeniKategoriView(motor: motor) }
                                Spacer()
                                Text("BİLSENE!").font(.system(size: 35, weight: .black, design: .rounded)).foregroundColor(.white).shadow(color: .black.opacity(0.3), radius: 5, x: 0, y: 5)
                                Spacer()
                                Button(action: { motor.ayarlarAcik = true }) {
                                    Image(systemName: "gearshape.fill").font(.system(size: 30)).foregroundColor(.white)
                                        .padding().background(.ultraThinMaterial).clipShape(Circle())
                                }
                                .sheet(isPresented: $motor.ayarlarAcik) { AyarlarView(motor: motor) }
                            }
                            .padding(.horizontal).padding(.top, 40)
                            
                            HStack {
                                Text("🏆 Takım Modu").fontWeight(.bold).foregroundColor(.white)
                                Spacer()
                                Toggle("", isOn: $motor.takimModuAcik).labelsHidden()
                            }
                            .padding().background(.ultraThinMaterial).cornerRadius(15).padding(.horizontal, 30)
                            
                            ScrollView {
                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                                    ForEach(motor.tumKategoriler) { kategori in
                                        ZStack(alignment: .topTrailing) {
                                            Button(action: { motor.oyunuBaslat(kategori: kategori) }) {
                                                VStack {
                                                    Image(systemName: (kategori.isCustom ?? false) ? "person.crop.circle.fill" : "gamecontroller.fill")
                                                        .font(.system(size: 40)).foregroundColor(.white).padding(.bottom, 5)
                                                    Text(kategori.baslik).font(.headline).fontWeight(.bold).foregroundColor(.white).multilineTextAlignment(.center)
                                                }
                                                .frame(height: 140).frame(maxWidth: .infinity)
                                                .background(
                                                    (kategori.isCustom ?? false) ?
                                                    LinearGradient(colors: [.purple, .blue], startPoint: .top, endPoint: .bottom) :
                                                    LinearGradient(gradient: Gradient(colors: [.orange, .pink]), startPoint: .topLeading, endPoint: .bottomTrailing)
                                                )
                                                .cornerRadius(20).shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 5)
                                            }
                                            
                                            if (kategori.isCustom ?? false) == true {
                                                Button(action: { motor.ozelKategoriSil(kategori: kategori) }) {
                                                    Image(systemName: "trash.circle.fill").foregroundColor(.white).font(.title)
                                                        .background(Color.red.clipShape(Circle()))
                                                }
                                                .offset(x: 10, y: -10)
                                            }
                                        }
                                    }
                                }
                                .padding(30)
                            }
                        }
                    }
                }
            }
        }
    }
}
