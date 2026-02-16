# Performance Issues

## Resolved

### AVAudioPlayer.play() blocking main thread (88% spike reduction)
- `AVAudioPlayer.play()` was taking 15-40ms per call on the main thread
- Replaced with `AVAudioEngine` + pre-loaded `AVAudioPCMBuffer` + `AVAudioPlayerNode` pools
- Play calls are now sub-millisecond (stop/scheduleBuffer/play round-robin)

### Shoot sound during rapid fire
- Added 0.15s minimum interval between playerShoot audio calls
- Normal fire (0.7s) unaffected, rapid fire plays ~every other shot
- Marginal improvement (~20% fewer spikes) since AVAudioEngine already made audio cheap

## Open

### SpriteKit physics contact handler overhead (primary remaining bottleneck)
- `didBegin(_ contact:)` spikes to 30-110ms, accounting for nearly all remaining frame spikes
- The time is spent *before* our handler code runs — it's SpriteKit's internal collision resolution/dispatch
- Correlates with contact count: 1 contact ~30-40ms, 3-4 contacts ~60-90ms
- Worse at higher levels where fire rate is faster (more simultaneous bullet-alien collisions)
- Our handler code itself (node removal, explosion spawn, score update) is <1ms

#### Possible approaches to investigate
- **Reduce physics body count**: Fewer active collision bodies = less work for SpriteKit's broadphase. Could batch-remove off-screen projectiles more aggressively
- **Simplify physics body shapes**: If any bodies use complex polygons, switch to circles/rectangles
- **Category bitmask tuning**: Ensure contactTestBitMask is as narrow as possible so SpriteKit skips unnecessary pair checks
- **Frame-rate-aware bullet spawning**: At high fire rates, consider whether every bullet needs a physics body or if raycasting could substitute
- **Move collision to manual checking**: Replace SKPhysicsContact with manual distance checks in update() — avoids SpriteKit's contact dispatch overhead entirely, but requires reimplementing broadphase

### captureImpactSnapshot() costs ~100ms (accepted, rare)
- `view.texture(from: self)` renders the entire scene to a texture
- Only fires on player hit (3-5 times per game)
- Testing confirmed removing it does NOT reduce overall spike count — contact handler dominates
- Kept as-is since it's infrequent and the visual is worth the cost


### From Codex
Best New Options (Prioritized)

  1. Replace only playerBullet -> enemy/ufo with manual collision, keep SpriteKit physics for enemyBullet -> player and
     powerups. This is the highest-leverage hybrid because your hottest contact type disappears while risk stays contained.
  2. Activate enemy colliders only for “frontline” aliens (lowest 1-2 alive per column), and promote next alien when one
     dies. You currently create bodies for every alien (Alien Barrage/Alien Barrage/Entities/AlienEntity.swift:83), but many
     are unreachable most of the time.
  3. Decouple alien visual animation from collider nodes. Right now each alien’s physics node is constantly moved/scaled by
     alive-motion (Alien Barrage/Alien Barrage/Entities/AlienEntity.swift:103); keep physics on a stable parent and animate
     only a child sprite.
  4. Smooth contact bursts from spread shot by staggering the 3 bullets by a few milliseconds instead of spawning all in the
     same step (Alien Barrage/Alien Barrage/GameScene.swift:262). If spikes are superlinear with contact count, this often
     reduces worst-frame jank.
  5. Add a hard cap on active bullets with gameplay compensation (higher bullet speed or damage). Projectiles are dynamic
     bodies moved by actions (Alien Barrage/Alien Barrage/Entities/ProjectileEntity.swift:41, Alien Barrage/Alien Barrage/
     Entities/EnemyProjectileEntity.swift:72), so bounding count gives predictable upper cost.
  6. Immediately zero a bullet’s physics masks/body on first hit before removal to prevent duplicate same-step callbacks.
     Low effort, usually modest gain.
  7. Add per-contact-type telemetry (playerBullet-enemy, enemyBullet-player, etc.) in logs so you can prove exactly which
     pair causes the 30-110ms spikes (Alien Barrage/Alien Barrage/PerformanceLog.swift:66).
  8. Add a “profile-light” mode that disables expensive per-frame debug counting during performance sessions (Alien Barrage/
     Alien Barrage/GameScene.swift:1690) so measurements focus on real gameplay bottlenecks.

  Why this matters now

  - Alien/body count can scale high (Alien Barrage/Alien Barrage/LevelManager.swift:45, plus extra columns on wide screens
    at Alien Barrage/Alien Barrage/GameScene.swift:197), so structural reductions beat micro-optimizations.

#### Progress Update

- ✅ `#1` Manual playerBullet -> enemy/ufo collisions implemented (hybrid model kept for enemyBullet/player + powerups).
- ✅ `#4` Spread-shot spawn staggering implemented.
- ✅ `#7` Per-contact-type telemetry implemented.
- ✅ `#2` Collider-count reduction implemented for the active manual-collision path:
  - Formation aliens and UFO no longer create physics bodies when manual player-bullet collision is enabled.
  - Swoopers explicitly enable collider behavior when they enter player-contact gameplay.
- ✅ `#5` Active-bullet caps implemented with gameplay compensation:
  - Player bullets are capped (`maxActivePlayerBullets`) with contextual eviction:
    - default path evicts far-travel bullets to keep firing responsive.
    - spread/UFO pressure path evicts near-player bullets first to preserve long-travel shots.
  - Enemy bullets are capped (`maxActiveEnemyBullets`) to bound late-level projectile churn.
  - Under rapid-fire/spread pressure, player bullets get a speed multiplier (`playerBulletCapSpeedMultiplier`) to offset cap pressure.
  - Per-level telemetry reports cap activity (`bulletCap playerEvict=... enemySkip=...`) and now includes player-eviction policy split (`near=... far=... spreadOrUFO=...`).
- ✅ Added startup warm-up for lazy-loaded combat assets:
  - Explosion frame sequences (`explosions.png`) are pre-decoded at scene start.
  - Powerup spin-sheet frames (`powerups.png`) are pre-decoded at scene start.
- ✅ Added per-hit manual resolve outlier logging:
  - New `manualResolve ...` event lines break down expensive resolve phases (`damage`, `audio`, `scoreFx`, `powerup`, `cleanup`, etc.) when a resolve exceeds threshold.
- ✅ Crash hardening for manual-hit queue:
  - Resolution loop now uses a safe optional pop (`popLast`) instead of forced front-removal to avoid `RangeReplaceableCollection` over-removal crashes.
- ✅ Additional diagnostics for next profiling pass:
  - Manual resolve outlier threshold lowered to `20ms` to emit more per-hit breakdowns.
  - Added `[FRAME_GAP]` logging for high-`dt` frames where `FrameTotal` time is comparatively low.
- ✅ Manual resolve outlier root cause identified and mitigated:
  - New logs show `manualResolve` outliers are dominated by enemy-death audio playback (`audio≈21ms` per hit).
  - Added enemy-death SFX throttling (`enemyDeathSoundMinInterval`) to prevent per-kill audio stalls.
  - Strengthened the mitigation for active perf testing:
    - Disabled enemy-death SFX while reduced-FX resolves are active (`enemyDeathSoundDuringReducedFX=false`).
    - Disabled enemy-death SFX during bonus rounds (`enemyDeathSoundDuringBonusRounds=false`).
- ✅ Candidate fix for repeatable early Level 1 frame-gap hitch:
  - Replaced first-use per-swooper `SKAudioNode(fileNamed:)` playback with preloaded `AudioManager` playback for `alienSwoop`.
  - Goal: avoid lazy `SKAudioNode` decode/attach stall around the first swoop event.
- ✅ Follow-up fix for remaining early-session hitch (often Level 2/3):
  - Replaced UFO ambience `SKAudioNode(fileNamed:)` loop with `AudioManager` loop playback (`playLoop/stopLoop`) and explicit stop on all UFO cleanup paths.
  - Goal: avoid first-use `SKAudioNode` loop initialization stalls when UFO ambience first starts.
  - Validation (latest run): no `[FRAME_GAP]` entries, no early-level pause repro, and session `worst_dt` reduced to ~`50ms` range.
- ✅ Spread-shot projectile longevity fix:
  - Player bullet cap now gives spread-shot extra headroom.
  - When spread/UFO pressure is active, cap eviction trims near-player bullets first so long-travel shots can still reach UFOs.
- 🔜 Next best candidates:
  - `#8` Add profile-light mode to reduce debug instrumentation overhead during perf sessions.
  - `#3` Decouple alien visual animation from collider nodes (larger refactor, still valuable).
  - `#6` Immediately zero physics masks/body on first hit before removal (small, low-risk win for non-manual contact paths).
