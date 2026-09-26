# Development Status

## LAUNCH READINESS (see docs/LAUNCH_PLAN.md)
- Economy rebalanced with a progression simulation (tools/balance): real vault / bench / gadget /
  Ascension price curve; Ascension = rebirth keeping one Heirloom treasure; x1.5+ per level
- Monetisation live in code (Services/MonetizationService, Config/Monetization, 💎 STORE):
  5 passes, 6 products (incl. server-wide Treasure Rain / Gold Rush gifts), free boosts
  (friends, Premium, group, daily streak). Pass/product ids still 0 until created on Roblox.

- Menus restyled (accent header band per menu, glossy buttons, rarity-tinted Vault cards, store
  ribbons). Gadget Shop, Vault management and Ascension open ONLY at their place in the world
  (shop counter, your Vault terminal, the altar) and close when you walk away.
- Music mix: playlist 25% under master; Mountain King +10% and starts 15 s in (also on loop).

## BATS + SLAP COMBAT (replaces Bonk)
- Everyone holds a bat (Config/Bats, Shared/BatModels, Services/BatService, Controllers/BatFx).
  Not carrying: a slap flings you (the attacker's bat sets how far). Carrying: slap 1 slows you
  (Shaken, x0.55 speed), slap 2 throws you further and you drop the treasure.
- 11 bats: free Wooden Bat, 3 Cash upgrades, 7 more gated by Ascension 1-7. Bat Shop in the
  District (menu with 3D previews, every bat on the display wall). Bats survive Ascension.
- Vaults are deeper (30 x 44) with wide switchback stairs between floors (no more lift pads);
  unbuilt floors are only a glowing outline so labels below stay readable.

## DEEP SOUTH EXPANSION (docs/EXPANSION_PLAN.md) - built, awaiting a live playtest
- Three Ascension-gated regions south of the Waterfall Mountain: Emberfall (Asc 1, danger 5),
  Rimeheart (Asc 2, danger 6), Starfall Isles (Asc 3, danger 7). World code in
  `src/server/World/DeepSouth/`, gates in `Services/RegionGates`, hazards in
  `Services/HazardService`, client effects (gate colours, low gravity, blizzard) in
  `Controllers/DeepSouth`.
- 20 treasures + models, 6 guardians, 6 secrets, 4 exits, launch pads and boost rings.
- Waystones (`World/Waystones`, `Services/WaystoneService`) and storms
  (`Services/RegionStorms`: Eruption / Blizzard / Meteor Shower, admin `/event eruption`,
  `/event blizzard`, `/event meteor`).
- Map board: 900 x 405 canvas with a Deep South strip; locked regions are veiled per player.
- Risks to check live: phone performance on the bigger world (StreamingEnabled is still off),
  lava and crevasse hit boxes, the isles' updraft arcs, waystone landing spots.

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
- Strength + bench-press training as a pure waiting game (Logic/Lifting): no tapping; a PUMP
  multiplier that heats up while you stay, set bonuses every 10 reps, MEGA / GOLDEN REP
  jackpots, rolling counter, confetti, pump aura visible to the whole gym, next-lift ETA
- Ascension is a real fresh start: Strength, ALL Cash (incl. uncollected) and every gadget are
  wiped (Logic/AscensionReset); Vault, treasures, Collection, benches and titles are kept
- 30 data-driven treasures, spawn budget + rarity caps, pickup validation, carry weld, carry speed formula
- Manual drop (📦 button while carrying, G / D-pad down)
- Offline income: full rate while in a server (AFK / benching included); while offline the
  Vault earns 50% for at most 30 min, paid onto the collect pad with a "welcome back" banner
- Stability STABLE→SHAKEN→KNOCKED, knock immunity, reclaim protection, dropped timeout, theft detection
- Extraction (10 s, interruptible), finder's fee w/ zone bonus + Ascension multiplier, Collection, auto Vault placement
- PvP bonk (server hit detection), 4 Guardian types (Dire Wolf, Goblin Brute, Stone Golem, Giant
  Cave Spider; scaled-up models, eyes flare while hunting), death/respawn
- World overhaul (roadmap phase 5, slice 1): per-region biomes (terrain, flora, colour grading),
  region gates with danger stars + recommended strength, discovery rewards (Services/Exploration),
  secrets (Old Mine tunnel, Sky Ruins parkour, Catacombs) with hidden spawn points, balloon + smoke
  extraction markers
- Music: APM licensed-library classical playlist + Mountain King carry theme (our own uploads of
  the playlist were rejected by Roblox moderation; the player now skips any track that fails to
  load). Earlier: public-domain classical playlist (Grieg, Tchaikovsky, Saint-Saens, Mozart, Beethoven,
  Chopin, Joplin), "In the Hall of the Mountain King" while carrying, original success/fail
  stings; fetched + uploaded by .github/workflows/music.yml (credits in music/CREDITS.md)
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

## NIGHT LOCKDOWN + DAWN
- Night: the gate is sealed by fog (tag NightGate, solid via DayCycle) with a "DAWN IN 0:23"
  countdown on both sides; anyone outside the District at night is sent home.
- Dawn: server banner "A NEW DAY BEGINS • All treasures reset", then up to 3 banners for
  Legendary+ (and Diamond/Rainbow) spawns with their region.
- Extraction points: shrine design (dais, glowing ring, obelisks with runes + crystals, soft
  Beam light column, rising motes, sign with fee + mutation chance).
- Vault marker: thin fading beam + small tag, hidden up close.

## ADVENTURE UPDATE (bigger world, same island)
- Two new regions in the unused land beside the District: **Glowshroom Marsh** (danger 2,
  between Coast and Ruins) and **Frostpeak** (danger 3, between Ruins and Falls). Region
  order: Wilds > Coast > Marsh > Ruins > Frost > Falls.
- Marsh: bog pools, lily pads, boardwalks, glow mushrooms, spores; Bog Spiders; secret
  Witch Hut on stilts. Frostpeak: ring of peaks around a frozen lake, pines, ice crystals,
  snowfall; Ice Golems; secret Frozen Grotto (tunnel in the ice). 10 new treasures.
- **Boost rings** (Sonic style): spinning blue-and-gold hoops over a glowing plate, scattered
  at RANDOM open, flat, dry spots (new layout every server, max 6 per region, 55 studs apart).
  +45% speed for 4 s, ring burst, FOV kick + trail. Server-authoritative (BoostService).
- Carried treasure: the tag is hidden from the carrier (PlayerToHideFrom) and shown on top to
  everyone within 75 studs. The carrier's HUD shows weight/speed/route, not name/rarity/$.
- **Geysers** (launch pads): Cliff Geyser -> cliff top, Temple Geyser -> temple top,
  Witch Geyser -> the witch hut. Balance in GameConfig.Boost / GameConfig.Launch.
- Validation: static + unit tests only; NOT yet playtested in a live server.

## RARITY PALETTE (official)
- Common #9E9E9E, Uncommon #4CAF50, Rare #2196F3, Epic #9C27B0, Legendary #FFC107,
  Mythic #F44336, Divine #00E5FF, Secret #111111 (black/white animated gradient),
  OG #FFD700 (gold shimmer). Source of truth: Config/Rarities.luau (test-locked).
- New tiers: Divine (Aurora Crystal - Frostpeak; Seraph Feather - Falls) and OG
  (The First Doubloon - Falls waterfall cave, weight 0.012, cap 1).
- Animated names: TreasureLabel.StyleRarity + UIGradients tagged "RarityShimmer",
  animated per frame by Controllers/Ambience (name tags, Collection, Vault).

## LIVING WORLD 2 (settlements, secrets, loot by danger)
- Loot follows danger (GameConfig.Treasure.RarityByDanger, per ~100 rolls):
  danger 1 Wilds ~58% Common / 1.7% Epic; danger 2 Coast+Marsh; danger 3 Ruins+Frost
  (~63% Rare/Epic); danger 4 Falls (no Commons, 12% Uncommon, 40% Epic, 15% Legendary).
  Mythic/Divine/Secret/OG roam: same small odds in EVERY region (AnywhereWeights).
  Caps: Epic 3, Legendary 2; MaxActive 30. Spawn clamps only on starter + secret spots.
- 57 spawn points (was 33), several inside buildings (RayFrom under the roof).
- World/Settlements: farmstead + windmill, watchtower, campsite (Wilds); fishing village +
  pier (Coast); stilt village + rope bridge, drowned chapel (Marsh); aqueduct, obelisk
  circle (Ruins); trapper's cabin, mining outpost, ice-fishing huts (Frost); hermit's hut
  on the cliff (Falls). Chimney smoke, lanterns (NightLamp), turning sails/wheel ("Spinner").
- New secrets: Hollow Oak (Wilds), Smugglers' Den (Coast, trapdoor cellar), Eagle's Nest
  (Falls, ledge climb up a rock spire). New treasures: Oak King's Chest (Wilds Epic), Mist
  Flask + River Stone Charm (Falls Uncommon), Storm Eagle Feather + Cliffside Tablet (Falls Rare).
- Client Critters: rabbits / crabs / frogs / lizards / penguins by region, flee from you.
- Validation: static + unit tests only; NOT yet walked through in a live server.

## ISLAND MAP BOARD (by the Wilds gate)
- World/MapBoard: a 16x9-stud framed board just inside the gate beside the avenue
  (WorldLayout.MapBoard), facing players on their way out; prompt "Open Map".
- UI/MapView draws it from config (never stale): regions with danger stars, typical loot,
  recommended strength with YOUR check (✔ / orange), trails, exits (+cash %, mutation %),
  geysers, secrets you found, pulsing YOU ARE HERE. Side panel: loot mix per danger level
  (stacked rarity bars), "Mythic+ anywhere", exit payouts, night rule.
- Map "up" = into the Wilds, so left/right match what you see at the gate.
- Full screen via Menus/Map (world-anchored: closes when you walk away).

## RETENTION + GROWTH PASS
- Guided first run (Controllers/Guide): until the first Vault collect, glowing footprints
  lead from you to the objective's target plus a gold beacon on it; the very first bank is
  a full-screen "BANKED IT!" moment (fee, $/s, go collect, then train).
- Invites (Controllers/Invites): a small card with one "INVITE FRIENDS" button (Roblox's own
  dialog) at share-worthy moments: Legendary+ pickup, Epic+ or first bank, server events,
  secrets. 6 min apart, max 3 per session, never once the friend bonus is full.
- Feedback (💬 next to the music toggle): 👍/👎 + up to 280 chars -> FeedbackService ->
  DataStore "PlayerFeedback", one key per UTC day, no user ids/names stored. Read it with the
  "Read player feedback" workflow (edit tools/feedback/request.txt = days, or run manually).
  NOTE: the repo is public, so workflow output is public too - that's why no ids are kept.
- Phones: small parts (< 6 studs) no longer cast shadows, boost rings lost their 24
  PointLights and half their sparkles, Lighting.Technology Future -> ShadowMap.

## TREASURE LOOK 2 (bespoke models)
- Shared/TreasureModels: one hand-built, exaggerated model per treasure (all 52, test-locked),
  built with a small kit (ellipsoids via SpecialMesh, rings, cones, coins). Rendered offline
  with three.js to check the look (not yet seen in Roblox itself).
- Size grows +12% per rarity tier (was 7%): an OG is ~2x a Common of the same kind.
- Rarity flair: Epic/Legendary orbiting gems, Legendary+ golden halo, Mythic dark shards +
  flames, Divine wings + white halo, Secret black/white orbit rings, OG crown + coin ring.
- Mutations: re-skin + sparks, star glints, coloured PointLight, outline (Highlight, world
  treasure only), Moonlit motes, Rainbow sparks. Showcase copies (Vault, Collection,
  trophies) pass { Display = true } for lighter effects.
- Controllers/TreasureMotion: world/dropped treasure spins and bobs (rarer = livelier);
  the camera starts zoomed out (26 studs) on the first spawn.

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

## Live ops: Heist Hour tooling
- Admins can run `/event all <name>` (or `/event global <name>`) to start an event on every live server through MessagingService. Each server shows the "🎙 HEIST HOUR IS LIVE!" banner, waits `GameConfig.Events.Hosted.Lead` seconds, then starts the event.
- A server with an event already running waits up to 45s. Broadcasts older than 60s are ignored. In Studio the command runs locally.
- The parser lives in `Shared/Logic/AdminCommand` and is unit-tested.
- The full event strategy, the 12 answers and the backlog are in `docs/LIVE_OPS_PLAN.md`.

## Bat hold, reach and sound (standard Roblox melee feel)
- The bat is a real Roblox **Tool**: Roblox handles the hand grip and the arm-out hold pose. The swing is our own fast horizontal swat (`Bats.Swing`, `Controllers/BatFx`): the arm and waist wind up right and whip across left. Every client animates it for every player, and your own swing starts on the button press.
- `Bats.Grip` is the Tool.Grip: held just above the knob, standing up and tipped 20° forward (70° above level) (`Bats.GripElevation`).
- The Backpack hotbar is turned off. While you carry treasure the bat moves to your Backpack, then comes back to your hand.
- Reach is a generous melee hitbox: 11 studs for the Wooden Bat, up to 13.5 for The Big Bang, in a wide arc (about 100° either side of where you face).
- Sounds: a wooden whoosh when you swing, and a bat whack plus a hand slap where it lands (ProSoundEffects, see `music/CREDITS.md`).

## Info Board (news, roadmap, announcements, event sign-ups)
- A lit notice board sits beside the spawn pavilion (`WorldLayout.InfoBoard`). It has a red marquee with chasing bulbs, lanterns, and a live face showing the latest post, the next event's countdown and sign-up count, and a roadmap ticker.
- Walking up and pressing **Read & Sign Up** opens a menu with three tabs:
  - **NEWS:** the live announcement, pinned announcements and news.
  - **ROADMAP:** done / now / next / later.
  - **EVENTS:** your local time, a countdown, the sign-up count, and a **SIGN UP** button.
- **Posting news, the roadmap or events:** edit `src/shared/Config/News.luau` and push.
  - Posts go newest first.
  - An event with `StartsAt = nil` shows "date coming soon". Players can still sign up for it.
- **Live announcement from inside the game:** owners and admins type `/announce <text>` in chat.
  - The text goes through Roblox's text filter, then appears on every server as a banner and pinned on the board for 24h.
  - `/announce clear` takes it down.
- **Sign-ups:** the global count per event is kept in the `SATEventSignups` DataStore. Signed-up players who are online get a heads-up 10 minutes before the start and a banner when it goes live, including if they join while it's on.
- **Unread posts:** returning players get one toast about a post they haven't read. Opening the board marks it read.
- **Joints:** the swing drives both avatar joint types, the classic Motor6D (via C0) and the new upgraded AnimationConstraint (via its parent attachment). The bat itself also tips back and chops through level in the hand, so the swing shows on every avatar. The slap is sent to the server before any visuals run.
- **Sheathe:** its own round BAT button on the arc above SLAP (HIDE ↔ DRAW, or **H** on PC) straps the bat across your back (setting `SheatheBat`). SLAP draws it again and swings in the same press. The bat also rides on your back while you carry treasure.

## Guardians throw, they don't hurt
- PvE guardians never deal damage or kill.
- **One hit throws you back, low and long:** 90 studs/s horizontal, plus 30 per point of the guardian's Knockback above 1 (Cursed Hour rage adds to it). The upward speed is 38 studs/s, a hop of about 4 studs.
- **Carrying?** The treasure drops right where you were hit (with the Knocked tumble and reclaim protection), then you fly.
- **Not carrying?** You just fly back, with a "💥 THROWN!" line.
- After any throw the guardian backs off for its `RetreatAfterKnock`. The unused guardian `Damage` values were removed.

## Sound (SFX remake)
- **One coherent, soft set** (`UI/Sounds.luau`, credits in `music/CREDITS.md`). It replaces the stock "electronic ping" pitched up and down for everything.
- **Mixed under the music:** every effect plays through the `SFX` SoundGroup at 0.75, with each sound at 0.6 or below. A test enforces this.
- **One sound per action:**
  - Buttons whose action makes its own sound are `Silent` (SLAP = just the swoosh, gadgets, DROP, bat HIDE/DRAW).
  - "Moments" (chimes/stingers) have priorities, so a big bank's fanfare swallows the banner ding that arrives with it.
  - Each sound has a restart guard.
- **Premium details:**
  - Slight random pitch on repeating sounds (swings, reps, hits).
  - Every sound is preloaded at start.
  - Positional sounds roll off naturally.
  - Warning toasts are silent; only danger ones blip.
- A test checks that every `Sounds.Play("X")` in the client exists in the library.

## Trophy pedestal = an extra pedestal you choose
- The treasure on the pedestal outside the vault is stored as `Displays.Trophy` (`Economy.TrophyKey`). It moves OUT of the vault, freeing its slot inside, and keeps earning exactly as before, because `VaultIncome` sums every entry, offline earnings included. Ascension heirlooms consider it like any pedestal.
- **Vault menu:**
  - a gold TROPHY card comes first, with **BRING INSIDE**
  - every treasure has a 🏆 button that puts it outside, swapping with whatever is there now
  - selling works from inside the vault only
- **One-time move:** returning players with 3 or more treasures get their best one moved out to the pedestal once (milestone `TrophyPedestal`).
- **Stairs:** floors hold 16 pedestals, so floor 2 and its stairs appear at the 20-pedestal upgrade. Locked floors now say "🔒 FLOOR 2 • UPGRADE TO 20 PEDESTALS".

## Trophy sign, Bat Shop lights, Ascension Shop building, codes
- **Trophy sign:** the pedestal's floating text is replaced by a premium wooden sign in front of the plinth: a dark wood board with a gold trim showing whose trophy, the treasure, its mutation and rarity, and $/s.
- **Bat Shop:**
  - three hanging warm lanterns with shadows, plus a soft wall wash, giving a calm glow that shows at night
  - the floating per-bat tags are replaced by wooden plaques under each bat
- **Ascension Shop building:** a marble-and-gold boutique with a purple crystal roof across the pavilion from the Info Board (`WorldLayout.AscensionShop`). It's sealed by a violet barrier ("Opening soon") until `GameConfig.AscensionShop.Enabled` is true and its Items are filled in.
- **Codes:** the Info Board's CODES tab feeds `Config/Codes` and `Services/CodeService`. Codes are case-insensitive, and `Once` codes are remembered in the save.
  - `Devdev` (admins only): Ascension 3 and 140,000 Strength.
  - `NoDev` (admins only): the save becomes a brand-new account, with purchase receipts kept so products are never granted twice, and the character respawns.

## Pre-launch audit (Sep 27)
- **Remotes:** all 19 client→server handlers validate their arguments, and ownership, prices and cooldowns are checked on the server. Gadget aim vectors are sanitised, NaN included.
  - Fixed: vault rebuilds (hundreds of parts) could be spammed through sell or trophy swaps. They're now coalesced to at most one every 0.5 s per player (`RENDER_GAP`), and the last change always lands.
- **Saving:** session-locked `UpdateAsync`, retries with backoff (about 22 s), autosave every 120 s, and a `BindToClose` flush.
  - Stale-lock timeout lowered from 300 to 180 s, so a crashed server blocks rejoining for 3 minutes instead of 5.
- **Purchases:** `ProcessReceipt` is idempotent, retries when the player isn't loaded, and saves before `PurchaseGranted`. All pass and product IDs are live; `GroupId` is still 0.
- **Performance:** the new shop lanterns no longer cast shadows (point-light shadows are expensive on phones).
- **Content:** launch posts added to the Info Board and the roadmap refreshed.
- **Note:** `tools/balance/sim.py` uses its own simplified loot table. It does not reflect the Sep 26 rarity rebalance.

## Community (group 414389809)
- `Monetization.Free.GroupId` is set, so members get +10% Vault income.
- Membership is checked on join and exposed as the player attribute `InCommunity`.
- **Info Board NEWS tab:** a "JOIN THE CREW • +10% INCOME" card opens Roblox's join prompt (`GroupService:PromptJoinAsync`), then the server re-checks (`RecheckGroup`, rate-limited). The bonus and a welcome banner apply at once. Members see "✔ COMMUNITY BONUS ACTIVE" instead.
