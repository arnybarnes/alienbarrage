import SwiftUI
import SpriteKit
import AVKit

struct MenuView: View {
    let onStart: () -> Void
    let onSettings: () -> Void
    let onInstructions: () -> Void
    let lastScore: Int

    @State private var titlePulse = false
    @State private var player: AVPlayer?
    @State private var isPressing = false

    var body: some View {
        ZStack {
            StarfieldView()
                .ignoresSafeArea()

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

                    // Video — plays only while pressing and holding
                    AlienVideoView(player: player, isPressing: $isPressing)
                        .frame(width: geo.size.width * 0.65)
                        .frame(maxHeight: geo.size.height * 0.30)
                        .clipped()
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { _ in
                                    if !isPressing {
                                        isPressing = true
                                        player?.isMuted = false
                                        player?.seek(to: .zero)
                                        player?.play()
                                    }
                                }
                                .onEnded { _ in
                                    isPressing = false
                                    player?.pause()
                                    player?.isMuted = true
                                    player?.seek(to: .zero)
                                }
                        )

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
                .frame(maxWidth: 500)
                .frame(maxWidth: .infinity)
                .padding()
            }
        }
        .onAppear {
            if player == nil, let url = Bundle.main.url(forResource: "alien", withExtension: "mp4") {
                let avPlayer = AVPlayer(url: url)
                avPlayer.isMuted = true
                player = avPlayer
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

// MARK: - Starfield Background

struct StarfieldView: View {
    @State private var scene: SKScene?

    var body: some View {
        GeometryReader { geo in
            if let scene = scene {
                SpriteView(scene: scene)
            }
            Color.clear.onAppear {
                if scene == nil {
                    let s = SKScene(size: geo.size)
                    s.backgroundColor = .black
                    s.scaleMode = .resizeFill
                    s.anchorPoint = CGPoint(x: 0, y: 0)
                    let emitter = ParticleEffects.createStarfield(sceneSize: geo.size)
                    s.addChild(emitter)
                    scene = s
                }
            }
        }
    }
}

/// UIViewRepresentable wrapper for AVPlayerLayer — no controls, aspect-fill
struct AlienVideoView: UIViewRepresentable {
    let player: AVPlayer?
    @Binding var isPressing: Bool

    func makeUIView(context: Context) -> UIView {
        let view = PlayerUIView()
        view.backgroundColor = .black
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let view = uiView as? PlayerUIView {
            view.playerLayer.player = player
        }
    }

    class PlayerUIView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
