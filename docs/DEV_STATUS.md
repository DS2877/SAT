# Development Status

## CURRENT PHASE
Phase 2–4 — vertical slice (core treasure loop + PvP/PvE + first gadgets + basic Vault).

## CURRENT MILESTONE
M0–M7 implemented in code; awaiting first Roblox runtime playtest (M8 multiplayer loop).

## COMPLETED (code + static validation)
- Rojo project, server/client/shared architecture, remotes with per-player rate limiting
- Procedural Treasure Island: District (safe zone, spawn, training, shop, 10 vault plots, ascension altar),
  Wilds (trees, hills, trails, ravine bridge), Giant Waterfall + hidden cave, Ancient Temple + courtyard,
  Shipwreck Coast, Volcano + Lighthouse landmarks, 3 extraction zones (Safe / Dangerous / Secret)
- Player data: session-locked DataStore, versioned migration + reconcile, autosave, BindToClose
- Strength + timing-bar training (3 stations), server-graded
- 30 data-driven treasures, spawn budget + rarity caps, pickup validation, carry weld, carry speed formula
- Stability STABLE→SHAKEN→KNOCKED, knock immunity, reclaim protection, dropped timeout, theft detection
- Extraction (10 s, interruptible), Cash reward w/ zone bonus + Ascension multiplier, Collection, auto Vault placement
- PvP bonk (server hit detection), 3 Guardian types (Wolf, Goblin, Cave Spider), death/respawn
- Gadget framework (3 slots, server cooldowns): Speed Soda, Balloon, Bubble Blaster
- Physical Vault with pedestals + editor + tier upgrades; Ascension
- HUD (stats, objective/next treasure, carried treasure, nav arrow, extraction bar, danger states, action cluster),
  notifications (toast/banner/social/reward), Collection / Shop / Vault / Ascension menus, analytics wrapper
- CI: stylua, selene, lune tests (pure logic), compile check, rojo build, test-place publish

## VALIDATION LEVEL
- Static: stylua, selene (0 warnings), luau-lsp type check vs Roblox API (0 errors), compile check,
  201 unit assertions, place-structure check — all green locally and in GitHub Actions.
- Deployment: CI published the build to test place 75735389926017 (Open Cloud HTTP 200, version 4).
- NOT yet validated in a live Roblox server (no Studio in the dev environment). Needs a manual playtest.

## PLAYTEST 1 FIXES (mobile)
- HUD: objective, nav hint, banners and toasts share one top-centre stack (no overlap); smaller
  phone scale; reward popup smaller; round gadget cooldowns; strength requirement only when relevant.
- World signs near the District are sized in studs (shrink with distance) instead of fixed pixels.
- Training set closes as soon as the player walks away (client + server check).
- Successful extraction teleports the player to their Vault holding the treasure overhead.

## ADDED AFTER PLAYTEST 1
- Leaderboards (Richest, Strongest, Rarest Treasure, Most Extractions, Most Ascended): 5 physical
  boards behind the District fountain; global via OrderedDataStore + live in-server merge.
- Grapple Hook (gadget #4): aim with camera centre (reticle shown when equipped), server raycast,
  pull slowed by carried weight, usable while carrying.

- All 8 gadgets live: Speed Soda, Balloon, Bubble Blaster, Grapple Hook, Decoy Duck, Disguise,
  Bee Box (slow/sting zone), Boomerang (ranged bonk, counts as a hit).
- Event system + TREASURE RAIN: every 8–12 min (first after 4 min) treasures fall at one of
  4 sites for 60 s; HUD pill with countdown + nav arrow. Admin/Studio chat: `/event rain`.
- CURSED HOUR (2 min): Rare+ spawn weights x2–3, guardians x1.3 range/speed/damage, purple tint.
  Scheduler picks events by weight (Rain 2 : Cursed 1). Chat: `/event cursed`.

## WORLD POLISH PASS 1
- Noise heightmap island (src/server/World/TerrainGen.luau): rolling hills, noisy coastline,
  sloped beaches, rock/dirt on slopes, grass variation; gameplay areas kept flat at y=10 (unit-tested).
- Terrain grass decoration on (project file), animated clouds, warmer lighting, clearer water.
- Vegetation (src/server/World/Props.luau): curved palms on beaches, broadleaf groves, bushes,
  flowers, mossy rock clusters; trails kept clear.
- District: houses, paving rings, cobbled avenue with bunting + lamps, benches, planters, palms,
  fountain jets. Landmarks: temple vines/braziers/fallen pillars, layered waterfall + foam,
  shipwreck cargo + driftwood, furnished expedition camp, rope-bridge rails.

## KNOWN BUGS / RISKS
- Untested at runtime: NPC humanoid rigs (hip height), Balloon LinearVelocity feel, terrain ramp slopes.
- No server-side speed-hack detection yet (movement is client-authoritative in Roblox).
- Vault tiers 40/60 designed but disabled (physical layout supports 20).

## NEXT PRIORITY
1. Playtest the vertical slice in Studio / test place; fix runtime issues.
2. Tune first-10-minutes pacing (training gains, first treasure distance, prices).
3. Playtest gadgets/events; then Meteor Crash / Dragon Awakens / Ancient Vault events and world polish.

## OPEN DESIGN QUESTIONS
- Training style (timing bar) kept for now; revisit after more playtests.

## IMPORTANT ARCHITECTURE DECISIONS
- World is built procedurally at server start (code-only repo; swap build* functions for prefabs later).
- Movement.luau is the only writer of WalkSpeed/JumpPower (named multipliers + locks).
- Extraction auto-starts when a carrier stands in a zone (mobile-friendly, no extra button).
- Safe zone protects non-carriers only (carriers can't hide in the District).
- Carriers can't attack (CARRIER = RUN / CHASER = STOP); configurable.

## IMPORTANT BALANCE CHANGES
- Extraction also grants Strength = ceil(weight × 0.2).
- Training stations have Strength caps (diminishing gains) to slow the 1→100 climb.
