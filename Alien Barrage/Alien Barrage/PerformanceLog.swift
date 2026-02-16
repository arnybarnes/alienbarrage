//
//  PerformanceLog.swift
//  Alien Barrage
//

import Foundation

#if DEBUG

import QuartzCore
import os.log
import os.signpost

enum PerformanceLog {

    static var enabled = false

    private static let log = OSLog(subsystem: "com.alienbarrage", category: "Performance")
    private static let signpostLog = OSLog(subsystem: "com.alienbarrage", category: .pointsOfInterest)

    // Per-level tracking
    private static var frameCount = 0
    private static var dtSum: Double = 0
    private static var dtMax: Double = 0
    private static var peakEntities = 0
    private static var peakNodes = 0
    private static var peakSprites = 0
    private static var peakEmitters = 0
    private static var peakSwoop = 0
    private static var errorMessages: [String] = []
    private static var spikeCount = 0

    // Session tracking
    private static var worstLevel = 0
    private static var worstLevelDt: Double = 0
    private static var sessionPeakNodes = 0
    private static var sessionErrors: [String] = []

    // File logging
    private static var fileHandle: FileHandle?

    // Spike timing — section durations within a single frame
    private static let spikeThresholdMs: Double = 50.0
    private static var sectionStarts: [String: Double] = [:]
    private static var sectionDurations: [String: Double] = [:]
    private static var sectionOrder: [String] = []

    // Inter-frame contact tracking (contacts fire between update() calls)
    private static var contactTimeMs: Double = 0
    private static var contactCount: Int = 0
    private static var frameContactTypeCounts: [String: Int] = [:]
    private static var levelContactTypeCounts: [String: Int] = [:]

    // Manual player-bullet collision telemetry
    private static var manualSweepFrames = 0
    private static var manualSweepTimeMs: Double = 0
    private static var manualSweepMaxMs: Double = 0
    private static var manualSweepBullets = 0
    private static var manualSweepTargets = 0
    private static var manualSweepCandidateRefs = 0
    private static var manualSweepOverlapChecks = 0
    private static var manualSweepQueuedHits = 0
    private static var manualSweepResolvedHits = 0
    private static var manualSweepReducedFXHits = 0
    private static var manualSweepQueueDepthSum = 0
    private static var manualSweepQueueDepthMax = 0
    private static var manualSweepDetectMs: Double = 0
    private static var manualSweepResolveMs: Double = 0
    private static var manualSweepOutlierCount = 0
    private static var manualHitTypeCounts: [String: Int] = [:]
    private static var bulletCapPlayerEvictions = 0
    private static var bulletCapPlayerNearEvictions = 0
    private static var bulletCapPlayerFarEvictions = 0
    private static var bulletCapPlayerSpreadOrUFOEvictions = 0
    private static var bulletCapEnemySkips = 0

    // MARK: - Signposts

    static func begin(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.begin, log: signpostLog, name: name)
        let key = "\(name)"
        sectionStarts[key] = CACurrentMediaTime()
    }

    static func end(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.end, log: signpostLog, name: name)
        let key = "\(name)"
        if let start = sectionStarts.removeValue(forKey: key) {
            let duration = (CACurrentMediaTime() - start) * 1000.0
            // ContactHandler fires multiple times between frames — accumulate
            if key == "ContactHandler" {
                contactTimeMs += duration
                contactCount += 1
            } else {
                sectionDurations[key] = duration
                if !sectionOrder.contains(key) {
                    sectionOrder.append(key)
                }
            }
        }
    }

    // MARK: - Events & Errors

    static func event(_ name: StaticString, _ message: String) {
        guard enabled else { return }
        writeLine("[Event] \(message)")
    }

    static func error(_ message: String) {
        guard enabled else { return }
        writeLine("[ERROR] \(message)")
        errorMessages.append(message)
        sessionErrors.append(message)
    }

    static func contactType(_ type: String) {
        guard enabled else { return }
        frameContactTypeCounts[type, default: 0] += 1
        levelContactTypeCounts[type, default: 0] += 1
    }

    static func manualBulletSweep(
        bullets: Int,
        targets: Int,
        candidateRefs: Int,
        overlapChecks: Int,
        queuedHits: Int,
        resolvedHits: Int,
        reducedFXHits: Int,
        queueDepth: Int,
        detectMs: Double,
        resolveMs: Double,
        durationMs: Double
    ) {
        guard enabled else { return }
        manualSweepFrames += 1
        manualSweepBullets += bullets
        manualSweepTargets += targets
        manualSweepCandidateRefs += candidateRefs
        manualSweepOverlapChecks += overlapChecks
        manualSweepQueuedHits += queuedHits
        manualSweepResolvedHits += resolvedHits
        manualSweepReducedFXHits += reducedFXHits
        manualSweepQueueDepthSum += queueDepth
        if queueDepth > manualSweepQueueDepthMax { manualSweepQueueDepthMax = queueDepth }
        manualSweepDetectMs += detectMs
        manualSweepResolveMs += resolveMs
        manualSweepTimeMs += durationMs
        if durationMs > manualSweepMaxMs { manualSweepMaxMs = durationMs }
        if durationMs >= GameConstants.Performance.manualSweepOutlierThresholdMs {
            manualSweepOutlierCount += 1
            writeLine("[MANUAL_SPIKE] sweep=\(String(format: "%.3f", durationMs))ms detect=\(String(format: "%.3f", detectMs))ms resolve=\(String(format: "%.3f", resolveMs))ms bullets=\(bullets) targets=\(targets) candidates=\(candidateRefs) checks=\(overlapChecks) queued=\(queuedHits) resolved=\(resolvedHits) reducedFX=\(reducedFXHits) queueDepth=\(queueDepth)")
        }
    }

    static func manualCollisionType(_ type: String) {
        guard enabled else { return }
        manualHitTypeCounts[type, default: 0] += 1
    }

    static func bulletCap(
        playerEvictions: Int = 0,
        enemySkips: Int = 0,
        playerNearEvictions: Int = 0,
        playerFarEvictions: Int = 0,
        playerSpreadOrUFOEvictions: Int = 0
    ) {
        guard enabled else { return }
        if playerEvictions > 0 { bulletCapPlayerEvictions += playerEvictions }
        if playerNearEvictions > 0 { bulletCapPlayerNearEvictions += playerNearEvictions }
        if playerFarEvictions > 0 { bulletCapPlayerFarEvictions += playerFarEvictions }
        if playerSpreadOrUFOEvictions > 0 { bulletCapPlayerSpreadOrUFOEvictions += playerSpreadOrUFOEvictions }
        if enemySkips > 0 { bulletCapEnemySkips += enemySkips }
    }

    // MARK: - Per-Frame Sampling

    static func recordFrame(
        dt: TimeInterval,
        entityCount: Int,
        nodeCount: Int,
        spriteCount: Int,
        emitterCount: Int,
        swoopCount: Int
    ) {
        guard enabled else { return }
        frameCount += 1
        dtSum += dt
        if dt > dtMax { dtMax = dt }
        if entityCount > peakEntities { peakEntities = entityCount }
        if nodeCount > peakNodes { peakNodes = nodeCount }
        if spriteCount > peakSprites { peakSprites = spriteCount }
        if emitterCount > peakEmitters { peakEmitters = emitterCount }
        if swoopCount > peakSwoop { peakSwoop = swoopCount }

        let dtMs = dt * 1000.0
        let frameTotalMs = sectionDurations["FrameTotal"] ?? 0
        let unexplainedGapMs = max(0, dtMs - frameTotalMs)

        // Log large frame gaps where measured frame work does not explain dt.
        if GameConstants.Performance.frameGapLogging &&
            dtMs >= GameConstants.Performance.frameGapThresholdMs &&
            unexplainedGapMs >= GameConstants.Performance.frameGapUnexplainedThresholdMs {
            var parts: [String] = []
            if contactCount > 0 {
                var contactPart = "Contacts(\(contactCount))=\(String(format: "%.1f", contactTimeMs))ms"
                if !frameContactTypeCounts.isEmpty {
                    contactPart += " [\(formattedCounts(frameContactTypeCounts, limit: 4))]"
                }
                parts.append(contactPart)
            }
            for key in sectionOrder where key != "FrameTotal" {
                if let dur = sectionDurations[key], dur > 0 {
                    parts.append("\(key)=\(String(format: "%.1f", dur))ms")
                }
            }
            let breakdown = parts.isEmpty ? "no-sections" : parts.joined(separator: " ")
            writeLine("[FRAME_GAP] dt=\(String(format: "%.1f", dtMs))ms frameTotal=\(String(format: "%.1f", frameTotalMs))ms gap=\(String(format: "%.1f", unexplainedGapMs))ms entities=\(entityCount) nodes=\(nodeCount) sprites=\(spriteCount) emitters=\(emitterCount) swoop=\(swoopCount) | \(breakdown)")
        }

        // Log spike breakdown when frame exceeds threshold.
        if dtMs >= spikeThresholdMs {
            spikeCount += 1
            var parts: [String] = []
            // Contact handler time (accumulated between frames)
            if contactCount > 0 {
                var contactPart = "Contacts(\(contactCount))=\(String(format: "%.1f", contactTimeMs))ms"
                if !frameContactTypeCounts.isEmpty {
                    contactPart += " [\(formattedCounts(frameContactTypeCounts, limit: 4))]"
                }
                parts.append(contactPart)
            }
            // update() subsections
            for key in sectionOrder {
                if let dur = sectionDurations[key] {
                    parts.append("\(key)=\(String(format: "%.1f", dur))ms")
                }
            }
            let breakdown = parts.isEmpty ? "no-sections" : parts.joined(separator: " ")
            writeLine("[SPIKE] dt=\(String(format: "%.1f", dtMs))ms entities=\(entityCount) nodes=\(nodeCount) sprites=\(spriteCount) emitters=\(emitterCount) swoop=\(swoopCount) | \(breakdown)")
        }

        sectionDurations.removeAll(keepingCapacity: true)
        sectionOrder.removeAll(keepingCapacity: true)
        contactTimeMs = 0
        contactCount = 0
        frameContactTypeCounts.removeAll(keepingCapacity: true)
    }

    // MARK: - Level Summary

    static func levelComplete(level: Int, isBonus: Bool, aliveAliens: Int, fireInterval: TimeInterval) {
        guard enabled else { return }
        let avgDt = frameCount > 0 ? dtSum / Double(frameCount) : 0
        let avgMs = String(format: "%.1f", avgDt * 1000)
        let maxMs = String(format: "%.1f", dtMax * 1000)
        let fire = String(format: "%.2f", fireInterval)
        let mode = isBonus ? "BONUS" : "Level"

        var msg = "\(mode) \(level) done | frames=\(frameCount) avg_dt=\(avgMs)ms max_dt=\(maxMs)ms spikes=\(spikeCount) | peak: entities=\(peakEntities) nodes=\(peakNodes) sprites=\(peakSprites) emitters=\(peakEmitters) swoop=\(peakSwoop) | fire=\(fire)s errors=\(errorMessages.count)"
        if !levelContactTypeCounts.isEmpty {
            msg += " | contacts=[\(formattedCounts(levelContactTypeCounts, limit: 8))]"
        }
        if manualSweepFrames > 0 {
            let frames = Double(max(1, manualSweepFrames))
            let avgSweepMs = manualSweepTimeMs / frames
            let avgDetectMs = manualSweepDetectMs / frames
            let avgResolveMs = manualSweepResolveMs / frames
            let avgBullets = Double(manualSweepBullets) / frames
            let avgTargets = Double(manualSweepTargets) / frames
            let avgCandidates = Double(manualSweepCandidateRefs) / frames
            let avgQueueDepth = Double(manualSweepQueueDepthSum) / frames
            msg += " | manualPB avg=\(String(format: "%.3f", avgSweepMs))ms (detect=\(String(format: "%.3f", avgDetectMs)) resolve=\(String(format: "%.3f", avgResolveMs))) max=\(String(format: "%.3f", manualSweepMaxMs))ms bullets=\(String(format: "%.1f", avgBullets)) targets=\(String(format: "%.1f", avgTargets)) candidates=\(String(format: "%.1f", avgCandidates)) checks=\(manualSweepOverlapChecks) queued=\(manualSweepQueuedHits) resolved=\(manualSweepResolvedHits) reducedFX=\(manualSweepReducedFXHits) queueAvg=\(String(format: "%.2f", avgQueueDepth)) queueMax=\(manualSweepQueueDepthMax) outliers=\(manualSweepOutlierCount)"
            if !manualHitTypeCounts.isEmpty {
                msg += " [\(formattedCounts(manualHitTypeCounts, limit: 6))]"
            }
        }
        if bulletCapPlayerEvictions > 0 || bulletCapEnemySkips > 0 {
            msg += " | bulletCap playerEvict=\(bulletCapPlayerEvictions) enemySkip=\(bulletCapEnemySkips)"
            if bulletCapPlayerNearEvictions > 0 || bulletCapPlayerFarEvictions > 0 || bulletCapPlayerSpreadOrUFOEvictions > 0 {
                msg += " (near=\(bulletCapPlayerNearEvictions) far=\(bulletCapPlayerFarEvictions) spreadOrUFO=\(bulletCapPlayerSpreadOrUFOEvictions))"
            }
        }
        writeLine(msg)

        // Track worst level for session summary
        if dtMax > worstLevelDt {
            worstLevelDt = dtMax
            worstLevel = level
        }
        if peakNodes > sessionPeakNodes { sessionPeakNodes = peakNodes }

        resetLevelStats()
    }

    // MARK: - Session Lifecycle

    static func sessionStart() {
        guard enabled else { return }
        openFile()
        resetLevelStats()
        worstLevel = 0
        worstLevelDt = 0
        sessionPeakNodes = 0
        sessionErrors.removeAll()
        writeLine("=== Session started \(Date()) ===")
    }

    static func sessionEnd(finalLevel: Int, score: Int) {
        guard enabled else { return }
        let worstMs = String(format: "%.1f", worstLevelDt * 1000)
        var msg = "Session over | levels=\(finalLevel) score=\(score) | worst_dt=\(worstMs)ms (lvl \(worstLevel)) | peak_nodes=\(sessionPeakNodes) | errors=\(sessionErrors.count)"
        if !sessionErrors.isEmpty {
            let unique = Array(Set(sessionErrors))
            msg += " [\(unique.joined(separator: "; "))]"
        }
        writeLine(msg)
        closeFile()
    }

    // MARK: - File I/O

    private static func openFile() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("perf_log.txt")
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)
    }

    private static func closeFile() {
        fileHandle?.closeFile()
        fileHandle = nil
    }

    private static func writeLine(_ line: String) {
        guard let fh = fileHandle else { return }
        fh.write((line + "\n").data(using: .utf8)!)
    }

    // MARK: - Private

    private static func resetLevelStats() {
        frameCount = 0
        dtSum = 0
        dtMax = 0
        peakEntities = 0
        peakNodes = 0
        peakSprites = 0
        peakEmitters = 0
        peakSwoop = 0
        spikeCount = 0
        errorMessages.removeAll()
        sectionStarts.removeAll(keepingCapacity: true)
        sectionDurations.removeAll(keepingCapacity: true)
        sectionOrder.removeAll(keepingCapacity: true)
        contactTimeMs = 0
        contactCount = 0
        frameContactTypeCounts.removeAll(keepingCapacity: true)
        levelContactTypeCounts.removeAll(keepingCapacity: true)
        manualSweepFrames = 0
        manualSweepTimeMs = 0
        manualSweepMaxMs = 0
        manualSweepBullets = 0
        manualSweepTargets = 0
        manualSweepCandidateRefs = 0
        manualSweepOverlapChecks = 0
        manualSweepQueuedHits = 0
        manualSweepResolvedHits = 0
        manualSweepReducedFXHits = 0
        manualSweepQueueDepthSum = 0
        manualSweepQueueDepthMax = 0
        manualSweepDetectMs = 0
        manualSweepResolveMs = 0
        manualSweepOutlierCount = 0
        manualHitTypeCounts.removeAll(keepingCapacity: true)
        bulletCapPlayerEvictions = 0
        bulletCapPlayerNearEvictions = 0
        bulletCapPlayerFarEvictions = 0
        bulletCapPlayerSpreadOrUFOEvictions = 0
        bulletCapEnemySkips = 0
    }

    private static func formattedCounts(_ counts: [String: Int], limit: Int) -> String {
        let sorted = counts.sorted { lhs, rhs in
            if lhs.value == rhs.value { return lhs.key < rhs.key }
            return lhs.value > rhs.value
        }
        return sorted.prefix(limit).map { "\($0.key)=\($0.value)" }.joined(separator: " ")
    }
}

#else

// Release builds: all calls compile to nothing
enum PerformanceLog {
    @inlinable static func begin(_ name: StaticString) {}
    @inlinable static func end(_ name: StaticString) {}
    @inlinable static func event(_ name: StaticString, _ message: String) {}
    @inlinable static func error(_ message: String) {}
    @inlinable static func contactType(_ type: String) {}
    @inlinable static func manualBulletSweep(
        bullets: Int,
        targets: Int,
        candidateRefs: Int,
        overlapChecks: Int,
        queuedHits: Int,
        resolvedHits: Int,
        reducedFXHits: Int,
        queueDepth: Int,
        detectMs: Double,
        resolveMs: Double,
        durationMs: Double
    ) {}
    @inlinable static func manualCollisionType(_ type: String) {}
    @inlinable static func bulletCap(
        playerEvictions: Int = 0,
        enemySkips: Int = 0,
        playerNearEvictions: Int = 0,
        playerFarEvictions: Int = 0,
        playerSpreadOrUFOEvictions: Int = 0
    ) {}
    @inlinable static func recordFrame(dt: TimeInterval, entityCount: Int, nodeCount: Int, spriteCount: Int, emitterCount: Int, swoopCount: Int) {}
    @inlinable static func levelComplete(level: Int, isBonus: Bool, aliveAliens: Int, fireInterval: TimeInterval) {}
    @inlinable static func sessionStart() {}
    @inlinable static func sessionEnd(finalLevel: Int, score: Int) {}
}

#endif
