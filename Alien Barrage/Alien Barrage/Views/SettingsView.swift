import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @EnvironmentObject var gameSettings: GameSettings

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Button(action: onBack) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("BACK")
                        }
                        .foregroundColor(.green)
                        .font(.system(size: 16, weight: .semibold, design: .monospaced))
                    }
                    Spacer()
                }
                .padding(.horizontal)

                Text("SETTINGS")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)

                VStack(alignment: .leading, spacing: 20) {
                    // Difficulty
                    VStack(alignment: .leading, spacing: 8) {
                        Text("DIFFICULTY")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))

                        Picker("Difficulty", selection: $gameSettings.difficulty) {
                            Text("EASY").tag(Difficulty.easy)
                            Text("NORMAL").tag(Difficulty.normal)
                            Text("HARD").tag(Difficulty.hard)
                        }
                        .pickerStyle(.segmented)
                    }

                    // Fire speed
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FIRE SPEED")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))

                        HStack {
                            Text("SLOW")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Slider(value: Binding(
                                get: { 1.2 - gameSettings.autofireSpeed },
                                set: { gameSettings.autofireSpeed = 1.2 - $0 }
                            ), in: 0.2...1.0, step: 0.05)
                            .tint(.green)
                            Text("FAST")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }

                    // Score multiplier
                    HStack {
                        Text("SCORE MULTIPLIER")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))
                        Spacer()
                        Text(String(format: "%.2fx", gameSettings.scoreMultiplier))
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 20)
        }
    }
}
