import SwiftUI
import SpriteKit

struct GameContainerView: View {
    @EnvironmentObject var gameSettings: GameSettings
    let onGameOver: (Int) -> Void

    @State private var scene: GameScene?

    var body: some View {
        GeometryReader { geo in
            let sceneSize = geo.size

            ZStack(alignment: .bottomTrailing) {
                Color.black.ignoresSafeArea()

                if let scene = scene {
                    SpriteView(scene: scene)
                        .ignoresSafeArea()
                }

                // Exit button
                Button {
                    let score = scene?.currentScore ?? 0
                    scene?.isPaused = true
                    HighScoreManager.shared.submit(score: score)
                    onGameOver(score)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14 * GameConstants.hudScale, weight: .bold))
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 30 * GameConstants.hudScale, height: 30 * GameConstants.hudScale)
                        .background(Circle().fill(Color.black.opacity(0.4)))
                }
                .padding(.bottom, 10)
                .padding(.trailing, 12)
            }
            .onAppear {
                let newScene = GameScene(size: sceneSize, settings: gameSettings)
                newScene.scaleMode = .resizeFill
                newScene.anchorPoint = CGPoint(x: 0, y: 0)
                newScene.onGameOver = { score in
                    onGameOver(score)
                }
                scene = newScene
            }
        }
        .ignoresSafeArea()
        .onDisappear {
            scene = nil
        }
        .statusBarHidden(true)
        .defersSystemGestures(on: .bottom)
        .persistentSystemOverlays(.hidden)
    }
}
