import SwiftUI

struct MenuView: View {
    let onStart: () -> Void
    let onSettings: () -> Void
    let onInstructions: () -> Void
    let lastScore: Int

    @State private var titlePulse = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            GeometryReader { geo in
                VStack(spacing: 12) {
                    Text("ALIEN\nBARRAGE")
                        .font(.custom("Nosifer-Regular", size: 42))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color.green, Color.green.opacity(0.6)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: .green.opacity(0.6), radius: titlePulse ? 20 : 10)
                        .scaleEffect(titlePulse ? 1.03 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true),
                                   value: titlePulse)
                        .onAppear { titlePulse = true }
                        .padding(.top, geo.size.height * 0.04)

                    // App icon
                    Image("AppIcon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width * 0.65)
                        .frame(maxHeight: geo.size.height * 0.30)

                    Text("HIGH SCORE: \(HighScoreManager.shared.highScore)")
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundColor(.green.opacity(0.7))

                    if lastScore > 0 {
                        Text("LAST SCORE: \(lastScore)")
                            .font(.system(size: 16, weight: .medium, design: .monospaced))
                            .foregroundColor(.gray)
                    }

                    Spacer()

                    menuButton("START GAME", action: onStart)
                    menuButton("HOW TO PLAY", action: onInstructions)
                    menuButton("SETTINGS", action: onSettings)

                    Spacer().frame(height: 60)
                }
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
    }

    private func menuButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
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
    }
}
