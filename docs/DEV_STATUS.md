# Development Status

## CURRENT PHASE
Roadmap phase 1 — STABILISE the current build (see docs/ROADMAP.md). No big new features
until the whole core loop passes the mobile checklist (docs/PLAYTEST_CHECKLIST.md).

## CURRENT MILESTONE
Full core loop + economy + day/night implemented; phase-1 static audit fixes shipped;
awaiting the phase-1 mobile playtest.

## COMPLETED (code + static validation)
- Rojo project, server/client/shared architecture, remotes with per-player rate limiting
- Procedural Treasure Island: District (safe zone, spawn, training, shop, 10 vault plots, ascension altar),
  Wilds (trees, hills, trails, ravine bridge), Giant Waterfall + hidden cave, Ancient Temple + courtyard,
  Shipwreck Coast, Volcano + Lighthouse landmarks, 3 extraction zones (Safe / Dangerous / Secret)
- Player data: session-locked DataStore, versioned migration + reconcile, autosave, BindToClose
- Strength + AFK bench-press training (see REWARDING TRAINING below)
- 30 data-driven treasures, spawn budget + rarity caps, pickup validation, carry weld, carry speed formula
- Stability STABLE→SHAKEN→KNOCKED, knock immunity, reclaim protection, dropped timeout, theft detection
- Extraction (10 s, interruptible), finder's fee w/ zone bonus + Ascension multiplier, Collection, auto Vault placement
- PvP bonk (server hit detection), 3 Guardian types (Wolf, Goblin, Cave Spider), death/respawn
- Gadget framework (3 slots, server cooldowns): Speed Soda, Balloon, Bubble Blaster
- Physical Vault with pedestals that earn $/s, sell, tier upgrades; Ascension
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

## PLAYTEST 2 CHANGES
- District wall (radius 150) with one gatehouse = the only route to the Wilds; invisible barrier
  above the wall stops Balloon/Grapple shortcuts.
- Spawn pavilion (marble dais, pillars, dome + spinning crown, welcome arch that teaches the loop).
- Vaults grow UP: 20 pedestals per floor, 3 floors (tiers 5/10/20/40/60 all enabled), ghost
  pedestals + locked-floor outlines show room to grow, lift pads between floors, new gallery design.
- Treasures ~1.5x bigger with glowing rarity ground rings and light beams (Rare+).
- Grass-free terrain under the District/camp/courtyard/beach (grass no longer pokes through floors).
- AFK bench-press gym (4 tiers) replaces the timing-bar training; much slower Strength; 2x pass hook.
  Every client animates bench users locally (arms + barbell) from the "Bench" attribute.
- Objective card is now a slim collapsible tracker under the stats.
- Gadget prices raised ~7-10x ($12K–$120K); Speed Soda stays cheap ($600) as the first gadget.

## PROGRESSION REDESIGN (uncapped Strength)
- Strength has no cap. Past 1x weight a carry is "OVERPOWERED" (up to +10% speed) - capped so
  whales can't outrun guardians forever. HUD shows big numbers as K/M/B.
- Ascension requirement grows x2.5 per level (10K, 25K, 62.5K, 156K, 391K...).
- Each Ascension multiplies training speed x1.6 forever, so every climb stays ~8-50 AFK minutes
  (unit test enforces this for levels 0-6).
- Benches are gated by ASCENSION (not Strength, which resets): Wooden free, Iron $5K, Golden
  Asc 1, Diamond Asc 2, Mythic Asc 4 (5th gym row).

## REWARDING TRAINING (rep-based)
- Strength + treasure Weight moved to a x100 scale (start 1,000; Commons weigh 100-500). Save v4
  migrates old Strength x100.
- Benches pay out per REP (1.6s, 2x faster while PUSH-boosting): +5 / +12 / +30 / +75 / +180 base.
- Boosted reps build a COMBO (+10% per stack, max x10 = +100%); 8% of reps are MEGA REPs (x5).
- Panel: floating +N pops (pitch rises with combo), combo meter, "NEXT LIFT" goal bar.
- "NEW LIFT!" banner whenever Strength lets you carry a heavier treasure at full speed.
- All prompts hidden while lying on a bench; occupied benches hide their prompt for everyone.
- Strength pill shows full numbers with separators below 1M so it visibly ticks every rep.

## PLAYTEST 3 FIXES
- Spawn dais: bottom step is now a deep plinth sunk into the ground (no terrain clipping).
- Lighting retuned: earlier sun, less haze/glare, higher bloom threshold (neon no longer smears).
- Bench animation no longer depends on Motor6D arms: the bar is driven from the lying root and
  IKControls pull the hands onto it (works with R6, R15 and AnimationConstraint rigs).
- Rep gains: big centre-screen "+N 💪" pops, "+N" flying out of the Strength pill for any gain,
  and "+N" over other lifters' heads for everyone nearby.
- Vault pedestal names are plaques on the pedestal front (floating labels overlapped).

## ECONOMY OVERHAUL (vault income)
- Treasures on Vault pedestals EARN $/s = Value / 100 x mutation x Ascension (x3 at night):
  Common $1-5/s, Rare $30-95/s, Legendary $650-2.1K/s, Secret $25K/s (Steal a Brainrot bands).
- Earnings pile up on the green COLLECT pad in your Vault (persisted as Vault.Stored).
- Extraction pays only a finder's fee (20 s of income x zone bonus); the treasure lands on a
  free pedestal. Full Vault = auto-sold. Sell = 60 s of income (pedestal prompt or Vault menu).
- Prices raised to match: gadgets $500 / $20K-$600K, vault $30K/$400K/$6M/$60M, benches
  $12K/$200K/$2.5M/$40M, Ascension $150K/$1.5M/$15M/$100M (x3 after).
- Mutations (Silver x1.5, Gold x2, Diamond x3, Moonlit x4 night-only, Rainbow x6) re-skin the
  treasure; stored in vault slots as "id|Mutation".

## TREASURE LOOK
- Bigger (and bigger with rarity), no sky beams; rarity aura particles + glow; mutation skins.
- Steal-a-Brainrot style tag (mutation / name / rarity / $/s), visible within 40 studs only.
- Rarity palette: Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold,
  Mythic red, Secret black text with white outline.

## REGIONAL EVENTS + DAY/NIGHT
- Treasure Rain, Cursed Hour and the new Gold Rush (mutations x6) each hit ONE region; guardian
  rage and the purple tint only apply inside it.
- 5-minute DAY, 30-second NIGHT. Loot ONLY spawns at night (one wave of 20, fully spawned
  after ~18 s); Treasure Rain is the only daytime loot. At nightfall all loot left in the world
  (including CARRIED treasure) is lost and players outside the District are sent to their
  Vault (DayCycle). Warnings at 60/30/10 s. Vaults earn x3 at night; Moonlit (x4) only spawns
  on night waves. Cursed Hour / Gold Rush are night modifiers rolled at nightfall (40%).
  Clock comes from server time (Logic/DayNight), lighting is client-side (Ambience).
- Collect pad + sign board moved OUTSIDE the Vault entrance (text was cut by the gate posts).

## PHASE 1 AUDIT FIXES
- Starter loot: spawn points with MaxRarity <= Uncommon (near the gate) refill during the day.
- Tutorial step 4 "COLLECT YOUR CASH" until the first collect.
- Vault sell prompt on E / ButtonX (was F = BONK, ButtonY = gadget 3).
- "Next treasure" goal: "ONE IS OUT NOW IN X" vs "SPAWNS AT NIGHT IN X".
- Funnel: Joined, FirstTraining, FirstTreasure, FirstExtraction, FirstCollect, FirstGadget,
  FirstVaultUpgrade, FirstTheft, FirstAscension + FunnelTime_<step> (seconds since join).

## PHASE 2 (core loop) - see docs/ROADMAP.md
- Risky extraction mutation blessing, day run streak, Epic+ extraction broadcast + marker,
  extraction heartbeat, heavy-carry sway/footsteps (GameFeel), night-wave reveal flashes,
  Epic+ pickup jackpot, vault-upgrade / bench-unlock goals.

## FEEL + WORLD PASS
- Spawn dais clipping, root cause: terrain at y=10 (half-filled voxels) poked through the
  District slab. Terrain under the District is now sunk to y=8 (TerrainGen.SUNKEN) and the
  slab is 6 studs thick.
- Vault gallery: 4 columns with a central aisle + red runner, 16 per floor, 14-stud floors,
  lift pad at the far end of the aisle.
- WorldLife (client): bird flocks + gulls by day, fireflies by night, butterflies at flower
  beds (tag Flowerbed), falling leaves, jumping fish, street lamps (tag NightLamp) lit at night,
  campfire smoke.
- Music (Config/Music + MusicController): shuffled playlist with crossfades; carry theme on
  pickup (optional per-rarity), playlist resumes where it paused; 🔊 toggle saved in
  data.Settings.Music. Needs uploaded asset ids.
- Onboarding (phase 3): intro card + just-in-time tips.

## KNOWN BUGS / RISKS
- Untested at runtime: NPC humanoid rigs (hip height), Balloon LinearVelocity feel, terrain ramp
  slopes, IK arms on the bench, nightfall teleport, collect board placement on every plot.
- No server-side speed-hack detection yet (movement is client-authoritative in Roblox).
- Camera sway uses Humanoid.CameraOffset (yields to hit shakes via the "Shaking" attribute).

## NEXT PRIORITY
See docs/ROADMAP.md: 1 stabilise → 2 addictive core loop → 3 first 10 minutes →
4 treasure content → 5 world → 6 social.

## OPEN DESIGN QUESTIONS
- Is the Ascension cash cost curve right once Mythic Bench players appear? Needs playtest data.
- Day length (5 min) and nightfall loot loss: fair or too harsh? Needs playtest data.

## IMPORTANT ARCHITECTURE DECISIONS
- World is built procedurally at server start (code-only repo; swap build* functions for prefabs later).
- Movement.luau is the only writer of WalkSpeed/JumpPower (named multipliers + locks).
- Extraction auto-starts when a carrier stands in a zone (mobile-friendly, no extra button).
- Safe zone protects non-carriers only (carriers can't hide in the District).
- Carriers can't attack (CARRIER = RUN / CHASER = STOP); configurable.

## IMPORTANT BALANCE CHANGES
- Extraction grants Strength = weight × 0.1.
- Strength uncapped; ascension requirement x2.5/level, training speed x1.6/level.
