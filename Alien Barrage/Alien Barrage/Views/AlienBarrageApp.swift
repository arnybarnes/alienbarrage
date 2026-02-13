import SwiftUI

@main
struct AlienBarrageApp: App {
    @StateObject private var gameSettings = GameSettings()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(gameSettings)
                .preferredColorScheme(.dark)
                .statusBarHidden(true)
        }
    }
}
