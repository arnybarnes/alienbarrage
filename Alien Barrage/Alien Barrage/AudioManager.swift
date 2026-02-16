import AVFoundation

class AudioManager {
    static let shared = AudioManager()
    private var players: [String: AVAudioPlayer] = [:]

    /// All sound file constants for muteAll/unmuteAll
    static let allSoundFiles: [String] = [
        GameConstants.Sound.playerShoot,
        GameConstants.Sound.playerHit,
        GameConstants.Sound.playerDeath,
        GameConstants.Sound.enemyDeath,
        GameConstants.Sound.alienSwoop,
        GameConstants.Sound.powerupCollect,
        GameConstants.Sound.powerupRapidFire,
        GameConstants.Sound.powerupSpreadShot,
        GameConstants.Sound.powerupShield,
        GameConstants.Sound.powerupExtraLife,
        GameConstants.Sound.powerupExpire,
        GameConstants.Sound.ufoAppear,
        GameConstants.Sound.ufoAmbience,
        GameConstants.Sound.ufoDestroyed,
        GameConstants.Sound.levelStart,
        GameConstants.Sound.gameOver,
        GameConstants.Sound.highScore,
    ]

    private(set) var mutedSounds: Set<String>

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: "mutedSounds") ?? []
        mutedSounds = Set(saved)
    }

    private func saveMutedSounds() {
        UserDefaults.standard.set(Array(mutedSounds), forKey: "mutedSounds")
    }

    func isMuted(_ soundName: String) -> Bool {
        mutedSounds.contains(soundName)
    }

    func setMuted(_ soundName: String, muted: Bool) {
        if muted {
            mutedSounds.insert(soundName)
        } else {
            mutedSounds.remove(soundName)
        }
        saveMutedSounds()
    }

    func muteAll() {
        for sound in Self.allSoundFiles where !sound.isEmpty {
            mutedSounds.insert(sound)
        }
        saveMutedSounds()
    }

    func unmuteAll() {
        mutedSounds.removeAll()
        saveMutedSounds()
    }

    func play(_ soundName: String) {
        guard !soundName.isEmpty else { return }
        guard !mutedSounds.contains(soundName) else { return }
        guard let url = Bundle.main.url(forResource: soundName, withExtension: nil) else {
            let msg = "AudioManager: file not found — \(soundName)"
            print(msg)
            PerformanceLog.error(msg)
            return
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.play()
            players[soundName] = player  // retain until playback finishes
        } catch {
            let msg = "AudioManager: failed to play \(soundName) — \(error)"
            print(msg)
            PerformanceLog.error(msg)
        }
    }
}
