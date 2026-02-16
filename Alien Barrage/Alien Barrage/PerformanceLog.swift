//
//  PerformanceLog.swift
//  Alien Barrage
//

#if DEBUG

import Foundation
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

    // Session tracking
    private static var worstLevel = 0
    private static var worstLevelDt: Double = 0
    private static var sessionPeakNodes = 0
    private static var sessionErrors: [String] = []

    // File logging
    private static var fileHandle: FileHandle?

    // MARK: - Signposts

    static func begin(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.begin, log: signpostLog, name: name)
    }

    static func end(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.end, log: signpostLog, name: name)
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
    }

    // MARK: - Level Summary

    static func levelComplete(level: Int, isBonus: Bool, aliveAliens: Int, fireInterval: TimeInterval) {
        guard enabled else { return }
        let avgDt = frameCount > 0 ? dtSum / Double(frameCount) : 0
        let avgMs = String(format: "%.1f", avgDt * 1000)
        let maxMs = String(format: "%.1f", dtMax * 1000)
        let fire = String(format: "%.2f", fireInterval)
        let mode = isBonus ? "BONUS" : "Level"

        let msg = "\(mode) \(level) done | frames=\(frameCount) avg_dt=\(avgMs)ms max_dt=\(maxMs)ms | peak: entities=\(peakEntities) nodes=\(peakNodes) sprites=\(peakSprites) emitters=\(peakEmitters) swoop=\(peakSwoop) | fire=\(fire)s errors=\(errorMessages.count)"
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
        errorMessages.removeAll()
    }
}

#else

// Release builds: all calls compile to nothing
enum PerformanceLog {
    @inlinable static func begin(_ name: StaticString) {}
    @inlinable static func end(_ name: StaticString) {}
    @inlinable static func event(_ name: StaticString, _ message: String) {}
    @inlinable static func error(_ message: String) {}
    @inlinable static func recordFrame(dt: TimeInterval, entityCount: Int, nodeCount: Int, spriteCount: Int, emitterCount: Int, swoopCount: Int) {}
    @inlinable static func levelComplete(level: Int, isBonus: Bool, aliveAliens: Int, fireInterval: TimeInterval) {}
    @inlinable static func sessionStart() {}
    @inlinable static func sessionEnd(finalLevel: Int, score: Int) {}
}

#endif
