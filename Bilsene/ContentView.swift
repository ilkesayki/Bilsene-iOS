import SwiftUI

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
                        
                        // KELİME LİSTESİ
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
                            .frame(maxHeight: 300)
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
