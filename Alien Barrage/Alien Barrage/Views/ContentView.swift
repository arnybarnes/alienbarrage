import SwiftUI

enum AppScreen {
    case menu
    case playing
    case settings
    case instructions
}

struct ContentView: View {
    @EnvironmentObject var gameSettings: GameSettings
    @State private var currentScreen: AppScreen = .menu
    @State private var lastScore: Int = 0

    var body: some View {
        switch currentScreen {
        case .menu:
            MenuView(
                onStart: { currentScreen = .playing },
                onSettings: { currentScreen = .settings },
                onInstructions: { currentScreen = .instructions },
                lastScore: lastScore
            )
            .transition(.opacity)
        case .playing:
            GameContainerView(onGameOver: { score in
                lastScore = score
                currentScreen = .menu
            })
            .transition(.opacity)
        case .settings:
            SettingsView(onBack: { currentScreen = .menu })
                .transition(.opacity)
        case .instructions:
            InstructionsView(onBack: { currentScreen = .menu })
                .transition(.opacity)
        }
    }
}
