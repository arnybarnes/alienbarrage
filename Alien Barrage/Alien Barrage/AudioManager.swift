import AVFoundation

class AudioManager {
    static let shared = AudioManager()

    /// Pool size per sound — allows overlapping playback
    private static let poolSize = 3

    /// Pre-loaded player pools keyed by sound name
    private var pools: [String: [AVAudioPlayer]] = [:]

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
        preloadAll()
    }

    private func preloadAll() {
        for soundName in Self.allSoundFiles where !soundName.isEmpty {
            guard let url = Bundle.main.url(forResource: soundName, withExtension: nil) else { continue }
            var pool: [AVAudioPlayer] = []
            for _ in 0..<Self.poolSize {
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    player.prepareToPlay()
                    pool.append(player)
                }
            }
            if !pool.isEmpty {
                pools[soundName] = pool
            }
        }
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
        guard let pool = pools[soundName] else {
            let msg = "AudioManager: no pool for — \(soundName)"
            print(msg)
            PerformanceLog.error(msg)
            return
        }

        // Find a player that isn't currently playing
        if let player = pool.first(where: { !$0.isPlaying }) {
            player.currentTime = 0
            player.play()
            return
        }

        // All busy — restart the first one (oldest playback)
        let player = pool[0]
        player.currentTime = 0
        player.play()
    }
}
