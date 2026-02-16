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
