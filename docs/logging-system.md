# Performance Logging & Debug System

## Overview

Debug-only instrumentation using Apple's `os_log` + `os_signpost`. Logs are retrievable from a connected physical iPhone via the macOS `log` CLI tool. Zero overhead in release builds — the `#else` branch provides empty `@inlinable` stubs that the compiler eliminates entirely.

## How It Works

### What Gets Logged

At each **level transition** (normal or bonus), a summary line is emitted via `os_log`:

```
[Perf] Level 2 done | frames=1204 avg_dt=16.5ms max_dt=28.3ms | peak: entities=42 nodes=71 sprites=52 emitters=11 swoop=2 | fire=1.30s errors=0
```

At **game over**, both a final level summary and a session summary are emitted:

```
[Perf] Level 5 done | frames=600 avg_dt=16.8ms max_dt=34.2ms | peak: entities=45 nodes=68 sprites=50 emitters=12 swoop=3 | fire=0.90s errors=0
[Perf] Session over | levels=5 score=8200 | worst_dt=34.2ms (lvl 5) | peak_nodes=71 | errors=0
```

### Metrics Tracked Per Level

| Metric | Description |
|--------|-------------|
| `frames` | Total frames rendered during the level |
| `avg_dt` | Average frame time (target: 16.7ms for 60fps) |
| `max_dt` | Worst single frame time (spikes = jank) |
| `entities` | Peak GKEntity count (bullets, aliens, player, powerups) |
| `nodes` | Peak SKNode children in worldNode |
| `sprites` | Peak SKSpriteNode count (subset of nodes) |
| `emitters` | Peak SKEmitterNode count (particles — sparks, trails, explosions) |
| `swoop` | Peak simultaneous swooping aliens |
| `fire` | Enemy fire interval in seconds |
| `errors` | Audio or other runtime errors during the level |

### Session Summary

| Metric | Description |
|--------|-------------|
| `levels` | How many levels were reached |
| `score` | Final score |
| `worst_dt` | Worst frame time across all levels and which level |
| `peak_nodes` | Highest node count across all levels |
| `errors` | Total errors with unique messages listed |

### Signpost Intervals (Instruments)

The following code sections have `os_signpost` begin/end markers, visible in Instruments > Points of Interest:

- `FrameTotal` — entire `update()` method
- `EntityUpdates` — `entities.forEach { update(deltaTime:) }`
- `FormationUpdate` — `alienFormation.update(deltaTime:)`
- `CheckBottom` — `checkAliensReachedBottom()`
- `CheckComplete` — `checkLevelComplete()`
- `EntityCleanup` — dead entity removal loop
- `ContactHandler` — physics contact resolution
- `ReverseCheck` — `shouldReverseDirection()` in AlienFormation

### Events & Errors

One-shot events and errors are also logged via `os_log`:

- `[Event] BonusSpawn wave=2 index=5` — bonus alien spawned
- `[ERROR] AudioManager: file not found — boom.wav` — audio failure

## Retrieving Logs from iPhone

### Prerequisites

- iPhone connected to Mac (USB or WiFi)
- App was run from Xcode in Debug configuration

### After a Play Session

```bash
# Collect recent logs from the connected device (adjust time window as needed)
/usr/bin/log collect --device --last 10m --output /tmp/perf.logarchive

# Show only Alien Barrage perf logs
/usr/bin/log show /tmp/perf.logarchive \
  --predicate 'subsystem == "com.alienbarrage"' \
  --style compact
```

### Other Useful Queries

```bash
# Errors only
/usr/bin/log show /tmp/perf.logarchive \
  --predicate 'subsystem == "com.alienbarrage" AND messageType == error' \
  --style compact

# Live streaming while playing (real-time)
/usr/bin/log stream --device \
  --predicate 'subsystem == "com.alienbarrage"' \
  --style compact

# Longer session (30 minutes)
/usr/bin/log collect --device --last 30m --output /tmp/perf.logarchive
```

## Source Files

### `PerformanceLog.swift`

The entire logging system. Key API:

```swift
// Signpost intervals (for Instruments)
PerformanceLog.begin("SectionName")
PerformanceLog.end("SectionName")

// One-shot event
PerformanceLog.event("Name", "key=value details")

// Error (also accumulated for level/session summaries)
PerformanceLog.error("what went wrong")

// Called every frame — tracks peaks internally
PerformanceLog.recordFrame(dt:entityCount:nodeCount:spriteCount:emitterCount:swoopCount:)

// Called at level transitions
PerformanceLog.levelComplete(level:isBonus:aliveAliens:fireInterval:)

// Session lifecycle
PerformanceLog.sessionStart()
PerformanceLog.sessionEnd(finalLevel:score:)
```

### Call Sites in GameScene.swift

| Location | Call |
|----------|------|
| `didMove(to:)` | `sessionStart()` inside `#if DEBUG` |
| `willMove(from:)` | `sessionEnd()` |
| `update(_:)` | signpost begin/end around subsections + `recordFrame()` |
| `didBegin(_:)` | signpost around contact handler |
| `checkLevelComplete()` | `levelComplete()` |
| `checkBonusRoundComplete()` | `levelComplete(isBonus: true)` |
| `handlePlayerDeath()` | `levelComplete()` + `sessionEnd()` |
| `spawnBonusAlien()` | `event()` |

### Call Sites in Other Files

| File | Call |
|------|------|
| `AlienFormation.swift` | signpost around `shouldReverseDirection()` |
| `AudioManager.swift` | `error()` on file-not-found or playback failure |

## Adding New Instrumentation

### New event type
```swift
PerformanceLog.event("SpawnName", "details=\(value)")
```

### New error source
```swift
PerformanceLog.error("SomeSystem: what failed — \(error)")
```

### New per-level metric
1. Add a tracking var in the per-level section of `PerformanceLog`
2. Update `recordFrame()` or add a new recording method
3. Include in `levelComplete()` output string
4. Optionally add to session-level tracking
5. Reset in `resetLevelStats()`
6. Add matching no-op parameter to the `#else` release stub

## Release Build Behavior

In release builds (`#else` branch), all methods are empty `@inlinable` functions:

```swift
enum PerformanceLog {
    @inlinable static func begin(_ name: StaticString) {}
    @inlinable static func end(_ name: StaticString) {}
    // ... etc
}
```

The compiler inlines these to nothing — no function call overhead, no dead code, no binary size impact.
