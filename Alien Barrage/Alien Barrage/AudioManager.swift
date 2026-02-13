import SpriteKit

class AudioManager {
    static let shared = AudioManager()
    private init() {}

    func play(_ soundName: String) {
        guard !soundName.isEmpty else { return }
        // Future: play via AVAudioPlayer or SKAction.playSoundFileNamed
    }
}
