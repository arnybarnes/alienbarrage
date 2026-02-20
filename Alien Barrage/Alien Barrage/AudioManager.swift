import AVFoundation

class AudioManager {
    static let shared = AudioManager()

    /// Pool size per sound — allows overlapping playback
    private static let poolSize = 3

    /// Pre-loaded PCM buffers and player node pools, keyed by sound name
    private let engine = AVAudioEngine()
    private var pools: [String: SoundPool] = [:]
    private var loopNodes: [String: AVAudioPlayerNode] = [:]

    private class SoundPool {
        let buffer: AVAudioPCMBuffer
        let nodes: [AVAudioPlayerNode]
        var index: Int = 0

        init(buffer: AVAudioPCMBuffer, nodes: [AVAudioPlayerNode]) {
            self.buffer = buffer
            self.nodes = nodes
        }
    }

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
        GameConstants.Sound.bonusComplete,
        GameConstants.Sound.gameOver,
        GameConstants.Sound.highScore,
    ]

    private(set) var mutedSounds: Set<String>

    private init() {
        let saved = UserDefaults.standard.stringArray(forKey: "mutedSounds") ?? []
        mutedSounds = Set(saved)
        preloadAll()
        do {
            try engine.start()
        } catch {
            print("AudioManager: engine start failed — \(error)")
        }
    }

    private func preloadAll() {
        for soundName in Self.allSoundFiles where !soundName.isEmpty {
            guard let url = Bundle.main.url(forResource: soundName, withExtension: nil),
                  let file = try? AVAudioFile(forReading: url) else { continue }

            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { continue }
            do {
                try file.read(into: buffer)
            } catch {
                continue
            }

            var nodes: [AVAudioPlayerNode] = []
            for _ in 0..<Self.poolSize {
                let node = AVAudioPlayerNode()
                engine.attach(node)
                engine.connect(node, to: engine.mainMixerNode, format: format)
                nodes.append(node)
            }

            pools[soundName] = SoundPool(buffer: buffer, nodes: nodes)
        }
    }

    private func saveMutedSounds() {
        UserDefaults.standard.set(Array(mutedSounds), forKey: "mutedSounds")
    }

    private func ensureEngineRunning() {
        if !engine.isRunning {
            try? engine.start()
        }
    }

    func isMuted(_ soundName: String) -> Bool {
        mutedSounds.contains(soundName)
    }

    func setMuted(_ soundName: String, muted: Bool) {
        if muted {
            mutedSounds.insert(soundName)
            stopLoop(soundName)
        } else {
            mutedSounds.remove(soundName)
        }
        saveMutedSounds()
    }

    func muteAll() {
        for sound in Self.allSoundFiles where !sound.isEmpty {
            mutedSounds.insert(sound)
            stopLoop(sound)
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

        // Restart engine if interrupted (e.g., phone call)
        ensureEngineRunning()

        // Round-robin through player nodes
        let node = pool.nodes[pool.index]
        pool.index = (pool.index + 1) % pool.nodes.count

        node.stop()
        node.scheduleBuffer(pool.buffer, at: nil, options: [], completionHandler: nil)
        node.play()
    }

    func playLoop(_ soundName: String) {
        guard !soundName.isEmpty else { return }
        guard !mutedSounds.contains(soundName) else { return }
        guard let pool = pools[soundName] else {
            let msg = "AudioManager: no pool for loop — \(soundName)"
            print(msg)
            PerformanceLog.error(msg)
            return
        }

        ensureEngineRunning()

        let loopNode: AVAudioPlayerNode
        if let existing = loopNodes[soundName] {
            loopNode = existing
        } else {
            let node = AVAudioPlayerNode()
            engine.attach(node)
            engine.connect(node, to: engine.mainMixerNode, format: pool.buffer.format)
            loopNodes[soundName] = node
            loopNode = node
        }

        if loopNode.isPlaying { return }

        loopNode.stop()
        loopNode.scheduleBuffer(pool.buffer, at: nil, options: [.loops], completionHandler: nil)
        loopNode.play()
    }

    func stopLoop(_ soundName: String) {
        guard let node = loopNodes[soundName] else { return }
        node.stop()
    }
}
