import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var players: [String: AVAudioPlayer] = [:]
    private init() {}

    func play(_ soundName: String) {
        guard !soundName.isEmpty else { return }
        guard let url = Bundle.main.url(forResource: soundName, withExtension: nil) else {
            print("AudioManager: file not found — \(soundName)")
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            players[soundName] = player  // retain until playback finishes
        } catch {
            print("AudioManager: failed to play \(soundName) — \(error)")
        }
    }
}
