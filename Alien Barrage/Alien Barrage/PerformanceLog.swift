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

    private static var frameCounter = 0
    private static var fileHandle: FileHandle?
    private static var logURL: URL?

    static func begin(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.begin, log: signpostLog, name: name)
    }

    static func end(_ name: StaticString) {
        guard enabled else { return }
        os_signpost(.end, log: signpostLog, name: name)
    }

    static func event(_ name: StaticString, _ message: String) {
        guard enabled else { return }
        os_log("%{public}s", log: log, type: .info, message)
        writeLine("[Event] \(message)")
    }

    static func error(_ message: String) {
        guard enabled else { return }
        os_log("[Error] %{public}s", log: log, type: .error, message)
        writeLine("[ERROR] \(message)")
    }

    static func frameSummary(
        dt: TimeInterval,
        entityCount: Int,
        nodeCount: Int,
        aliveAliens: Int,
        level: Int,
        fireInterval: TimeInterval,
        isBonus: Bool,
        swoopCount: Int,
        spriteCount: Int,
        emitterCount: Int
    ) {
        guard enabled else { return }
        frameCounter += 1
        guard frameCounter >= 60 else { return }
        frameCounter = 0
        let ms = String(format: "%.1f", dt * 1000)
        let fire = String(format: "%.2f", fireInterval)
        let mode = isBonus ? "BONUS" : "lvl"
        let line = "dt=\(ms)ms entities=\(entityCount) nodes=\(nodeCount) sprites=\(spriteCount) emitters=\(emitterCount) aliens=\(aliveAliens) swoop=\(swoopCount) \(mode)=\(level) fire=\(fire)s"
        os_log("[Perf] %{public}s", log: log, type: .info, line)
        writeLine(line)
    }

    // MARK: - File Logging

    static func openLog() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let url = docs.appendingPathComponent("perf_log.txt")
        logURL = url

        // Start fresh each session
        FileManager.default.createFile(atPath: url.path, contents: nil)
        fileHandle = try? FileHandle(forWritingTo: url)

        let header = "=== Perf session \(Date()) ===\n"
        fileHandle?.write(header.data(using: .utf8)!)
    }

    static func closeLog() {
        fileHandle?.closeFile()
        fileHandle = nil
        if let url = logURL {
            os_log("[Perf] Log saved to %{public}s", log: log, type: .info, url.path)
        }
    }

    private static func writeLine(_ line: String) {
        guard let fh = fileHandle else { return }
        let data = (line + "\n").data(using: .utf8)!
        fh.write(data)
    }
}

#else

// Release builds: all calls compile to nothing
enum PerformanceLog {
    @inlinable static func begin(_ name: StaticString) {}
    @inlinable static func end(_ name: StaticString) {}
    @inlinable static func event(_ name: StaticString, _ message: String) {}
    @inlinable static func error(_ message: String) {}
    @inlinable static func frameSummary(dt: TimeInterval, entityCount: Int, nodeCount: Int, aliveAliens: Int, level: Int, fireInterval: TimeInterval, isBonus: Bool, swoopCount: Int, spriteCount: Int, emitterCount: Int) {}
    @inlinable static func openLog() {}
    @inlinable static func closeLog() {}
}

#endif
