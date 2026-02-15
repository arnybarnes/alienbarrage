# Alien Barrage In-App Purchase Strategy

Suggested Prompt:
`Create a concrete StoreKit product ID table and matching paywall copy strings for all IAPs in this doc, including game over, pre-run, and pre-bonus-round placements.`

## Why These IAPs Fit This Game

This plan is based on how Alien Barrage currently plays:

- Runs are high-score focused and session-based (menu shows high score/last score): `Alien Barrage/Alien Barrage/Views/MenuView.swift:61`
- Core pressure point is survival: default 3 lives (difficulty can raise/lower this): `Alien Barrage/Alien Barrage/Constants.swift:52`, `Alien Barrage/Alien Barrage/GameSettings.swift:24`
- Death ends the run and returns player to menu (strong emotional monetization moment): `Alien Barrage/Alien Barrage/GameScene.swift:737`, `Alien Barrage/Alien Barrage/GameScene.swift:763`
- Powerups are strong but RNG-gated (~15% drop chance, 8s duration): `Alien Barrage/Alien Barrage/Constants.swift:82`, `Alien Barrage/Alien Barrage/Constants.swift:84`
- Powerups already map cleanly to player-facing value (rapid fire, spread shot, shield, extra life): `Alien Barrage/Alien Barrage/Views/InstructionsView.swift:50`
- Bonus rounds now occur every 4th level and are high-score moments with “perfect” rewards: `specs/bonusrounds.md`
- Bonus rounds are non-lethal and disable drops/spawns (no enemy fire, no swoop, no UFO, no powerup drops), so monetization should focus on pre-bonus prep, not in-round prompts: `specs/bonusrounds.md`

## Monetization Principles

- Sell recovery and convenience, not raw score inflation.
- Keep a fair competitive lane for high-score players.
- Price for impulse first (`$0.99-$4.99`) with 1-2 whale bundles.
- Use contextual offers only at high-intent moments (game over, pre-run, pre-bonus-round).
- Do not interrupt active bonus-round play or bonus tally screens with purchase prompts.

## Recommended IAP Catalog

### 1) Emergency Continue Tokens (consumable)

Most likely top earner for this game.

- `continue_1` — `$0.99` (1 token)
- `continue_5` — `$3.99` (5 tokens)
- `continue_20` — `$12.99` (20 tokens)

Use:
- At game over, offer “Continue Run” before returning to menu.
- Limit to 1 continue per run to protect balance and reduce pay-to-win feel.

Why it should convert:
- Player has immediate loss aversion at death.
- You already have a game-over overlay where this can be inserted: `Alien Barrage/Alien Barrage/GameScene.swift:763`.

### 2) Pre-Run Loadout Boosters (consumable)

Give controlled access to current powerups without waiting for RNG drops.

- `booster_shield_3` — `$1.99` (3 Shield starts)
- `booster_rapidfire_5` — `$2.99` (5 Rapid Fire starts)
- `booster_spreadshot_5` — `$2.99` (5 Spread Shot starts)
- `booster_mixed_15` — `$6.99` (15 mixed starts)
- `booster_bonus_hunter_5` — `$3.99` (5 bonus-round prep charges; offensive-only)

Use:
- Player selects one booster before a run.
- Booster applies at spawn (uses existing powerup behavior in `PlayerEntity`): `Alien Barrage/Alien Barrage/Entities/PlayerEntity.swift:196`.
- For bonus-round-focused users, allow equipping `bonus_hunter` during the “BONUS ROUND” transition overlay.

Why it should convert:
- Powerups are already desirable and understood.
- Removes frustration from RNG drop timing.
- Bonus rounds are score-rich and reward accuracy, so offensive booster demand should be higher than defensive booster demand.

### 3) Starter Bundle (one-time, high conversion)

`starter_bundle` — `$4.99`

Includes:
- 5 Continue tokens
- 3 mixed pre-run boosters
- 3 bonus-hunter charges
- 1 exclusive ship skin

Use:
- Show once after first 2-3 sessions or after first game over above a score threshold.

Why it should convert:
- Combines immediate utility + cosmetic ownership.
- Strong first-purchase anchor.

### 4) Cosmetic Packs (non-consumable)

Low-risk monetization that preserves score fairness.

- `neon_ship_pack` — `$2.99` (4 ship skins)
- `laser_fx_pack` — `$2.99` (projectile VFX variants)
- `retro_arcade_pack` — `$4.99` (skins + FX + explosion palette)

Use:
- Cosmetic-only store section from menu.
- Optional “new skin unlocked in pack” teaser on high-score screen.

Why it should convert:
- Current game has strong visual identity; cosmetics fit naturally.
- Broadens revenue beyond only high-friction moments.

### 5) Supporter Pack (tip-style, non-consumable)

`supporter_pack` — `$9.99`

Includes:
- Exclusive badge/title in menu
- 1 premium skin
- No gameplay advantage

Why:
- Captures goodwill spend from top fans without balance risk.

## High-Score Fairness Rules

To avoid “pay-to-win” backlash:

- Create two score lanes:
- `Classic`: no purchased continues/boosters used in run.
- `Assisted`: any purchased utility used.

Notes:
- Cosmetics never affect lane.
- Keep both visible in menu to avoid punishing spenders.
- Any paid booster consumed in or before a bonus round also marks the run as `Assisted`.

## Offer Placement (Where Revenue Happens)

- Game over overlay:
- Primary CTA: `Continue (1 token)` if inventory > 0.
- Secondary CTA: `Buy 5 Tokens`.
- Pre-run screen:
- Small “Loadout” panel with equipped booster + inventory count.
- Pre-bonus-round overlay:
- If next level is bonus round, show a compact “Prep for Bonus Round” utility panel.
- Recommended CTA: `Activate Bonus Hunter (1)` if inventory > 0.
- Secondary CTA: `Get 5 Bonus Hunter`.
- Menu:
- Add `Store` button near score block (`HIGH SCORE` is already prominent): `Alien Barrage/Alien Barrage/Views/MenuView.swift:61`.

## Rollout Order

1. Continue tokens + game-over upsell
2. Starter bundle
3. Pre-run loadout boosters
4. Pre-bonus-round prep offer (`bonus_hunter`)
5. Cosmetics + supporter pack

This sequence should maximize early revenue while keeping implementation scope manageable.

## KPI Targets (First 30 Days)

- First purchase conversion: `>3%`
- Continue offer take rate (shown -> bought/used): `>8%`
- Starter bundle conversion (new users): `2-5%`
- Pre-bonus offer take rate (shown -> activated or purchased): `>10%`
- Bonus-round perfect rate lift in `Assisted` vs `Classic`: monitor for balance health, target `<2.0x`
- ARPPU target: `$8-$15`
- D7 retention impact: no worse than `-3%` after monetization launch

## Instrumentation Events To Add

- `run_started`
- `run_ended` (score, level reached, cause of death)
- `offer_shown` (placement, sku list)
- `offer_clicked` (sku)
- `purchase_completed` (sku, price_usd)
- `continue_used`
- `booster_equipped` / `booster_consumed`
- `score_lane` (`classic` or `assisted`)
- `bonus_round_started` (level)
- `bonus_round_completed` (hits, perfect, per_kill_score, bonus_score)
- `pre_bonus_offer_shown`
- `pre_bonus_offer_activated`

## Analytics for Monetization Optimization

Track analytics with one goal: identify where intent is high, where conversion breaks, and which offers improve LTV without harming retention.

Core event schema (attach to all monetization/game-economy events):

- `user_id`
- `session_id`
- `timestamp`
- `app_version`
- `build_type` (`debug`, `testflight`, `release`)
- `country_code`
- `storefront`
- `payer_state` (`never_paid`, `active_payer`, `lapsed_payer`)
- `lifetime_value_usd`
- `ab_experiment_id` / `ab_variant`

Suggested monetization event set:

| Event | When to fire | Key properties |
|---|---|---|
| `store_opened` | Player enters store screen | `entry_point` (`menu`, `game_over`, `pre_bonus`) |
| `paywall_viewed` | Any offer modal/panel is shown | `placement`, `sku_list`, `run_score`, `current_level` |
| `paywall_closed` | Offer dismissed without purchase | `placement`, `dismiss_reason` (`close`, `back`, `timeout`) |
| `sku_selected` | Player taps a specific product | `sku_id`, `placement`, `price_usd` |
| `purchase_started` | StoreKit purchase flow begins | `sku_id`, `placement`, `price_usd` |
| `purchase_completed` | Purchase succeeds | `sku_id`, `placement`, `price_usd`, `is_intro_offer` |
| `purchase_failed` | Purchase fails/cancelled | `sku_id`, `placement`, `failure_reason` |
| `purchase_restored` | Restore succeeds | `sku_id`, `entitlement_type` |
| `entitlement_granted` | Inventory/entitlement is applied | `sku_id`, `grant_type` (`consumable`, `non_consumable`) |
| `inventory_balance_changed` | Token/booster balance changes | `item_id`, `delta`, `new_balance`, `reason` (`purchase`, `consume`, `grant`) |
| `continue_offer_shown` | Game-over continue prompt appears | `run_score`, `level_reached`, `tokens_balance` |
| `continue_used` | Player uses a continue token | `source` (`paid`, `free_grant`), `run_score`, `level_reached` |
| `pre_bonus_offer_shown` | Bonus prep offer appears | `level`, `is_bonus_round`, `bonus_hunter_balance` |
| `pre_bonus_offer_activated` | Bonus prep item is consumed | `item_id`, `level`, `run_score` |
| `run_ended` | Run ends | `final_score`, `level_reached`, `cause_of_death`, `paid_utility_used` |
| `bonus_round_completed` | Bonus round ends | `level`, `hits`, `perfect`, `bonus_score`, `paid_utility_used` |

Recommended dashboard slices:

- Funnel by placement: `paywall_viewed -> sku_selected -> purchase_started -> purchase_completed`
- Revenue by SKU and placement
- Conversion by player state: `never_paid` vs `active_payer` vs `lapsed_payer`
- Retention guardrail: D1/D7 retention split by `paid_utility_used`
- Fairness guardrail: `Classic` vs `Assisted` score and perfect-rate deltas

Discovery analyses to find new monetization opportunities:

- Identify the highest-frequency death windows (level bands and causes) before level 4 and level 8, then test targeted utility bundles.
- Compare pre-bonus offer conversion by prior-run performance (`hits` in last bonus round).
- Find high-intent non-buyers (`paywall_viewed` with repeated `sku_selected` but no `purchase_completed`) and test lower-friction bundles.
- Track post-purchase engagement lift (sessions/run count in 7 days after first purchase).

## Event Mapping (Change-Resilient)

Because code will likely evolve before implementation, wire analytics to stable product behaviors (state transitions and user intents), not specific files or methods.

Implementation approach:

- Create a single analytics facade (for example, `Analytics.log(event:properties:)`).
- Emit events from domain/state boundaries (run lifecycle, purchase lifecycle, offer lifecycle).
- Keep event names and property contracts versioned in one schema file.
- Add a lightweight QA mode that prints every event payload for validation.

Suggested mapping by behavior:

| Behavior boundary (stable) | Fire events |
|---|---|
| Run enters active play | `run_started` |
| Run ends (death, exit, abandon) | `run_ended` |
| Store surface is entered | `store_opened` |
| Any monetization panel appears/disappears | `paywall_viewed`, `paywall_closed` |
| Product is tapped | `sku_selected` |
| Purchase flow begins/succeeds/fails | `purchase_started`, `purchase_completed`, `purchase_failed` |
| Entitlement/inventory is granted or consumed | `entitlement_granted`, `inventory_balance_changed` |
| Continue prompt shown and accepted | `continue_offer_shown`, `continue_used` |
| Bonus round starts/ends | `bonus_round_started`, `bonus_round_completed` |
| Bonus prep offer shown/consumed | `pre_bonus_offer_shown`, `pre_bonus_offer_activated` |

Required properties by event group:

- Run lifecycle:
- `run_id`, `session_id`, `current_level`, `score_lane`, `paid_utility_used`
- Offer lifecycle:
- `placement`, `sku_list`, `current_level`, `run_score`
- Purchase lifecycle:
- `sku_id`, `price_usd`, `currency`, `storefront`, `transaction_id` (when available)
- Bonus lifecycle:
- `level`, `hits`, `perfect`, `bonus_score`, `paid_utility_used`

Versioning and migration guardrails:

- Add `event_schema_version` to every event.
- Never repurpose an existing event name for different meaning; create a new event instead.
- If properties change, keep old keys for one release with dual-write where possible.
- Maintain an analytics changelog section in this doc for schema edits.

## Implementation Notes For Current Codebase

- Add purchase/state manager (StoreKit 2 + local inventory cache).
- Integrate continue prompt into game-over flow: `Alien Barrage/Alien Barrage/GameScene.swift:763`.
- Apply pre-run boosters via existing powerup APIs: `Alien Barrage/Alien Barrage/Entities/PlayerEntity.swift:188`.
- Hook pre-bonus offer into the existing bonus transition overlay path (`BONUS ROUND` / `Take them out!`): `Alien Barrage/Alien Barrage/GameScene.swift:1131`.
- Add store entry point in menu UI: `Alien Barrage/Alien Barrage/Views/MenuView.swift:73`.
- Remove debug start level before live monetization launch: `Alien Barrage/Alien Barrage/GameScene.swift:48`.

## What Not To Sell

- Direct score multipliers for cash
- Permanent higher powerup drop chance
- Unlimited continues in a single run

These will damage long-term trust and reduce meaningful competition.

## IAP Testing Before Launch (General)

Use a staged flow before pushing purchases live:

1. Local logic testing in Xcode with a `.storekit` configuration file.
2. Product setup in App Store Connect (IDs, pricing, metadata, agreements).
3. Sandbox device testing with Sandbox Apple Accounts.
4. TestFlight pass to validate full UX and transaction handling.
5. Backend/receipt validation testing against sandbox endpoints.
6. Final pre-release gate to confirm products are approved and mapped correctly.

Practical checklist:

- Product IDs in code exactly match App Store Connect.
- Entitlements unlock only after verified transaction.
- Purchase restore path works correctly.
- Purchase state survives reinstall/sign-in changes.
- Failed/cancelled purchase flows are handled and messaged cleanly.
- Analytics events fire for offer shown, start purchase, success/failure, restore.
