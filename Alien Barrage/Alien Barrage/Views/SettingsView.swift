import SwiftUI

struct SettingsView: View {
    let onBack: () -> Void
    @EnvironmentObject var gameSettings: GameSettings
    @State private var mutedSounds: Set<String> = AudioManager.shared.mutedSounds

    private static let soundEntries: [(name: String, file: String)] = [
        ("Player Shoot",    GameConstants.Sound.playerShoot),
        ("Player Hit",      GameConstants.Sound.playerHit),
        ("Player Death",    GameConstants.Sound.playerDeath),
        ("Enemy Death",     GameConstants.Sound.enemyDeath),
        ("Alien Swoop",     GameConstants.Sound.alienSwoop),
        ("Powerup Collect", GameConstants.Sound.powerupCollect),
        ("Rapid Fire",      GameConstants.Sound.powerupRapidFire),
        ("Spread Shot",     GameConstants.Sound.powerupSpreadShot),
        ("Shield",          GameConstants.Sound.powerupShield),
        ("Extra Life",      GameConstants.Sound.powerupExtraLife),
        ("Powerup Expire",  GameConstants.Sound.powerupExpire),
        ("UFO Appear",      GameConstants.Sound.ufoAppear),
        ("UFO Ambience",    GameConstants.Sound.ufoAmbience),
        ("UFO Destroyed",   GameConstants.Sound.ufoDestroyed),
        ("Level Start",     GameConstants.Sound.levelStart),
        ("Game Over",       GameConstants.Sound.gameOver),
        ("High Score",      GameConstants.Sound.highScore),
    ]

    private var allMuted: Bool {
        Self.soundEntries.allSatisfy { mutedSounds.contains($0.file) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
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

                    // Sound section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("SOUND")
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundColor(.green.opacity(0.7))

                        Button {
                            if allMuted {
                                AudioManager.shared.unmuteAll()
                            } else {
                                AudioManager.shared.muteAll()
                            }
                            mutedSounds = AudioManager.shared.mutedSounds
                        } label: {
                            Text(allMuted ? "ALL ON" : "ALL OFF")
                                .font(.system(size: 20, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                                .frame(maxWidth: 250)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.green.opacity(0.5), lineWidth: 1)
                                        .background(Color.green.opacity(0.08).clipShape(RoundedRectangle(cornerRadius: 8)))
                                )
                        }
                        .frame(maxWidth: .infinity)

                        ForEach(Self.soundEntries, id: \.file) { entry in
                            Toggle(entry.name, isOn: Binding(
                                get: { !mutedSounds.contains(entry.file) },
                                set: { enabled in
                                    AudioManager.shared.setMuted(entry.file, muted: !enabled)
                                    mutedSounds = AudioManager.shared.mutedSounds
                                }
                            ))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundColor(.green)
                            .tint(.green)
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.05))
                    )
                    .padding(.horizontal)

                    Spacer().frame(height: 40)
                }
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding(.top, 20)
            }
        }
    }
}
