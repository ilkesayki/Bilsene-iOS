import SwiftUI

@main
struct BilseneApp: App {
    
    // --- BU KISIM LAUNCH SCREEN İÇİN BEKLETME YAPAR ---
    init() {
        // 2.0 saniye uyut (Logo görünsün diye)
        Thread.sleep(forTimeInterval: 2.0)
    }
    // --------------------------------------------------

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
