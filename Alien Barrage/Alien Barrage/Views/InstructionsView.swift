import SwiftUI

struct InstructionsView: View {
    let onBack: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
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
                .padding(.top, 20)

                Text("HOW TO PLAY")
                    .font(.system(size: 28, weight: .heavy, design: .monospaced))
                    .foregroundColor(.green)
                    .padding(.bottom, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        section("CONTROLS",
                            "Touch and drag to move your ship. Your ship fires automatically.")
                        section("OBJECTIVE",
                            "Destroy all aliens to advance to the next level. Don't let them reach the bottom!")
                        section("ENEMIES",
                            "Aliens shoot plasma balls downward. Watch out — aliens will swoop down at you! A UFO occasionally flies across the top for bonus points (500 pts, 3 hits to destroy).")
                        section("SCORING",
                            "Small aliens = 100 pts. Large aliens = 200 pts (take 2 hits). Collecting a powerup = 50 pts.")
                        section("LIVES",
                            "Start with 3 lives (varies by difficulty). Getting hit costs a life. Brief invulnerability after respawn.")

                        Text("POWERUPS")
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)

                        Text("Drop from destroyed aliens (~15% chance)")
                            .font(.system(size: 14, design: .monospaced))
                            .foregroundColor(.gray)

                        powerupRow(spriteName: "powerupRapidFire", name: "Rapid Fire",
                                   desc: "Doubles fire rate for 8 seconds")
                        powerupRow(spriteName: "powerupSpreadShot", name: "Spread Shot",
                                   desc: "Fires 3 bullets in a fan for 8 seconds")
                        powerupRow(spriteName: "powerupShield", name: "Shield",
                                   desc: "Absorbs one enemy hit")
                        powerupRow(spriteName: "powerupExtraLife", name: "Extra Life",
                                   desc: "Instantly adds one life")

                        section("DIFFICULTY",
                            "Each level adds more aliens, faster movement, and quicker enemy fire. Adjust difficulty and fire speed in Settings. Harder difficulty and slower fire speed increase your score multiplier.")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 40)
                }
            }
        }
    }

    private func section(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 16, weight: .bold, design: .monospaced))
                .foregroundColor(.green)
            Text(body)
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func powerupRow(spriteName: String, name: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if let uiImage = SpriteSheet.shared.uiImage(named: spriteName) {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 28, height: 28)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                Text(desc)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
    }
}
