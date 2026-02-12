# Alien Barrage — Apple Intelligence Enhancement Ideas

These features would enhance the game on devices with Apple Intelligence while keeping the base game running identically on all iOS 17.6+ devices. All would be gated behind `#available` checks.

---

## 1. Dynamic Alien Taunts via On-Device LLM
Use the on-device language model to generate contextual alien taunts during gameplay — e.g., mocking the player after a death, trash-talking when aliens reach a lower row, or warning of incoming attacks. Keeps the tone fresh since messages are generated rather than scripted.

## 2. Adaptive Difficulty via Core ML Player Skill Modeling
Train a lightweight Core ML model on player metrics (accuracy, survival time, level reached, powerup usage) to adjust difficulty in real time. Could soften fire rates for struggling players or ramp up alien HP for veterans — all invisible and seamless.

## 3. Siri Shortcuts Integration
- "Start Alien Barrage" — launches directly into gameplay
- "What's my high score in Alien Barrage?" — reads back high score
- "Continue Alien Barrage" — resumes from last session
Could use App Intents framework for deep Siri integration.

## 4. Image Playground for Custom Alien Skins
Let players use Image Playground to generate custom alien skin variants from text prompts. The generated images could be applied as texture overlays on the standard alien sprites, giving each player a unique visual experience.

## 5. Writing Tools for Procedural Lore
Between levels, generate short narrative snippets about the alien invasion using Writing Tools. Could describe the alien race's backstory, mission briefings, or intercepted alien communications — adding story depth without pre-written content.

## 6. Smart Re-engagement Notifications
Use on-device intelligence to determine optimal times to send re-engagement notifications. Instead of fixed schedules, the system learns when the player typically plays and sends contextual messages like "The aliens have regrouped — Level 7 awaits, Commander."

---

## Implementation Notes
- All features require `#available` checks — base game must be fully functional without them
- On-device processing only — no cloud dependencies for gameplay features
- Consider privacy: player skill data stays on-device, never uploaded
- Start with Siri Shortcuts (lowest effort, high value) then explore LLM features
