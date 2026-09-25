# Expansion plan: the Deep South (beyond the Waterfall Mountain)

Status: PLAN ONLY (not built). Written 2026-09-25.

## 1. Goal and shape

Make the island **longer, not wider**: a spine of three new late-game biomes running south
from the top of the Waterfall Mountain, each harder and richer than the last. It becomes the
"endgame journey" after Frostpeak/Falls.

```
 N  District (safe) z +250
 |  Wilds / Coast / Marsh / Ruins / Frost          danger 1-3   (unchanged)
 |  The Falls + Waterfall Mountain (cliff top y 90) danger 4     z -240 .. -385
 |  ---------------------------------------------------------------- new ----
 |  THE ASHEN PASS   (transition, cliff top -> down)              z -385 .. -480
 |  1. EMBERFALL     red lava basin, Mount Cinder     danger 5     z -480 .. -700
 |     Steamfields   (lava meets ice: hot springs)                 z -700 .. -760
 |  2. RIMEHEART     total ice glacier                danger 6     z -760 .. -960
 |  3. STARFALL ISLES floating islands over the sea   danger 7     z -980 .. -1120
 S
```

- **Width:** the new land stays within about x -260..260 (the island today is about 940 wide).
  It's a long peninsula, so the silhouette changes from a round island to a round island
  with a long tail.
- **Length:** about +700 studs of new land, from z -450 (today's south shore) to about -1120.
  Total island length grows from about 950 to about 1650 studs.
- **Why this size:** a day is 300 s. At 18 studs/s, walking empty from the gate to the far
  end takes about 65 s. Carrying heavy loot (55-70% speed) the trip back takes about 100 s.
  With the travel aids and deep exits in section 5, a deep run still fits inside one day,
  and going deeper is a real, planned risk rather than impossible.

## 2. The three new biomes

### 1. EMBERFALL, the Red Lava Basin (danger 5)
- **Look:** red and black rock, glowing lava rivers, obsidian spires, ash falling, a red sky
  haze (ColorCorrection tint), heat shimmer. At the centre is **Mount Cinder**, an active
  volcano. The existing SW volcano (`WorldLayout.Volcano`, already marked "future late-game
  zone") becomes its older sister and the visual gateway (lava glow, smoke column).
- **Terrain:** a basin sloping down from the Ashen Pass. Materials are Basalt, CrackedLava,
  Rock and Slate. Lava rivers are neon parts in carved channels, with obsidian stepping
  stones and chain bridges across them.
- **Mechanic, "The floor is lava":** touching lava knocks you back and makes you DROP what
  you carry, the same way a guardian hit does. It's server-authoritative (the BoostService
  pattern: a zone check every 0.1 s against lava channel rectangles).
- **Event, Eruption:** Mount Cinder erupts. Lava bombs land in marked circles (a 2 s warning
  ring first), and afterwards rare treasure lands where the bombs fell.
- **Guardians:** the **Magma Golem** (slow, huge, leaves burning footprints) and **Cinder
  Salamanders** (fast, in packs).
- **Treasures (6):** Obsidian Shard (Uncommon), Ember Lantern (Rare), Salamander Scale (Rare),
  Molten Crown (Epic), Heart of Cinder (Legendary, pulses and drips lava), Phoenix Egg (Mythic).
- **Secrets:** the **Caldera Vault** (jump down into the crater via a spiral of cooling rock)
  and the **Forge of the Old King** (a lava-lit dwarven forge in a lava tube).
- **Settlements:** an abandoned mining camp, a collapsed obsidian temple, and a lava-crossing
  outpost with a Dangerous exit.

### 2. RIMEHEART, the Total Ice Glacier (danger 6)
- **Look:** everything is ice and snow: blue-white glacier ice, frozen waterfalls, a
  frozen shipwreck stuck in the ice, aurora in the sky at night, blowing snow and pale blue
  fog. Frostpeak is snowy forest; Rimeheart is a dead white world, much harsher.
- **Terrain:** a high glacier plateau with **crevasses** (deep cracks you jump across; fall
  in and you lose the loot but can climb out via ice ledges) and **ice caves**. Materials are
  Glacier, Ice and Snow.
- **Mechanic, slippery ice:** on Ice you slide (low friction) and turning is slower, which
  makes chases wild. Heavy loot slides even more, and Strength helps grip.
- **Event, Blizzard:** fog closes in (visibility about 40 studs), wind pushes players
  sideways, and loot spawns faster during it. It's a risk window.
- **Guardians:** the **Ice Wraith** (floats, passes through ice walls, slows on hit) and
  the **Frost Wyrm** (a big serpent that surfaces from the ice and patrols a crevasse).
- **Treasures (6):** Glacier Pearl (Uncommon), Frozen Compass (Rare), Wyrm Fang (Rare),
  Aurora Harp (Epic), Crown of Winter (Legendary), Everfrost Core (Mythic).
  **Frostbane gets a home shrine here:** a pedestal in a sealed ice cave where it can spawn
  (it stays a Secret that can drop anywhere).
- **Secrets:** the **Frozen Ship** (inside the ice-locked wreck) and **Frostbane's Tomb** (an ice
  cave behind a frozen waterfall; the spot where Frostbane tends to appear).
- **Settlements:** a research station (the Dangerous exit, "Glacier Station") and an
  ice-fishing village of igloos.

### 3. STARFALL ISLES, floating islands over the sea (my pick, danger 7)
- **Why this one:** after red lava and white ice, the final zone needs a third, totally
  different feeling: magical, vertical and airy. It also makes the island's southern tip a
  climax you can see from far away (glowing islands in the sky at the end of the glacier).
- **Look:** 8-12 floating rock islands at different heights over the southern sea, with
  purple and gold crystals, starry particles, falling meteor streaks, a violet/indigo sky
  tint and waterfalls pouring off the island edges into the sea.
- **Traversal:** geysers (the system already exists), boost rings, low-gravity bridges of
  light and a few jump puzzles. It's the most skill-based zone.
- **Mechanic, low gravity:** on the isles your jumps are floaty (client-side
  VectorForce inside the zone), and falling off drops you into the sea. You lose the loot
  and wash up on the glacier shore.
- **Event, Meteor Shower:** meteors crash onto the isles. Each crater holds a treasure with
  boosted odds of Divine/Secret.
- **Guardians:** **Star Sentinels** (crystal constructs that fire slow homing orbs) and
  **Void Rays** (flying mantas that patrol between islands).
- **Treasures (6):** Stardust Vial (Rare), Comet Shard (Epic), Astrolabe of Ages (Epic),
  Nebula Orb (Legendary), Fallen Star (Mythic), plus one new **Divine**, the Celestial Crown.
- **Secrets:** the **Observatory** (the highest island, a ruined telescope) and **the Rift**
  (a hidden island only reachable during a meteor shower).
- **Exit:** the **Skyport**, a Secret exit on the lowest island that pays x2.25.

## 3. Progression and economy

- **Danger scale 1-7.** Add rows 5-7 to `GameConfig.Treasure.RarityByDanger`, each tilting
  further toward Epic and Legendary but never zero Uncommon (your rule: loot follows danger,
  while Mythic+ stays random everywhere and unchanged):
  - 5: Unc 8 / Rare 30 / Epic 42 / Legendary 20
  - 6: Unc 6 / Rare 24 / Epic 44 / Legendary 26
  - 7: Unc 4 / Rare 18 / Epic 45 / Legendary 33
- **Stars on the map, signs and HUD** go from 4 to 7 (`Regions.Stars`).
- **Recommended strength:** Emberfall 30K, Rimeheart 45K, Starfall 70K (today Falls is 20K).
  Discovery rewards: 200K / 400K / 800K.
- **Ascension gates (DECIDED 2026-09-25):** each new region needs an Ascension level to enter.
  This makes Ascension something you work toward to unlock new land:

  | Region | Needs | Strength (soft) |
  |---|---|---|
  | Ashen Pass + Emberfall | **Ascension 1** | 30K |
  | Steamfields + Rimeheart | **Ascension 3** | 45K |
  | Starfall Isles | **Ascension 5** | 70K |

  - **Permanent:** Ascension never goes down, so once a region is open it stays open (even
    though Ascending wipes cash and gadgets).
  - **How the gate works:**
    - A physical **Rune Gate** stands at each border (the Ashen Pass top, the Steamfields
      bridge, the Starfall launch geyser). It glows green for you when you qualify and red
      when you don't, and shows "ASCENSION 3 REQUIRED • you: 1".
    - The server enforces it with a zone check, like the District gate: if you're not
      allowed, you're pushed back to the gate, and the geyser won't launch you.
    - Signs, the map board ("🔒 ASC 3") and the HUD objective all show the requirement, and
      the Ascension menu previews "Unlocks: RIMEHEART" at the matching level.
  - **Carried loot:** someone who qualifies can carry loot out of a locked region, and anyone
    outside can bonk and steal it. Lower-level players get a taste of deep loot by
    ambushing the exits, which creates social tension and gives them a reason to ascend.
  - **The moment:** a first-time unlock gets a big banner ("RIMEHEART UNLOCKED"), a
    server-wide shout-out, and the gate opening with light and sound.
  - **Pacing to check with the simulation:**
    - Today Ascension 1 lands at about 80-95 min and Ascension 2 at 2.5-3 h, so Emberfall
      opens after roughly 1.5 h, which is right.
    - Ascension 3 (Rimeheart) and especially **Ascension 5 (Starfall)** cost 1B and 25B cash
      with the current table. Ascension 5 could take a very long time.
    - Before building Phase 3, simulate the time to Ascension 5 and tune
      `GameConfig.Ascension.CashCost` / `RequirementGrowth` so Starfall is a proud
      multi-session goal (aim: roughly 8-12 h of play), not a wall.
- **Collection sets:** three new sets (+10% income each), so there are more long-term goals.
- **Balance check:** re-run the pacing simulation (`tools/balance`) with the new tiers so the
  first Ascension still lands at 80-95 min. The new regions should speed up *later*
  ascensions, not the first one.

## 4. Travel and exits (what makes the length fun, not a chore)

- **Cliff Lift:** a wooden funicular up and down the Waterfall Mountain face, next to the
  existing Cliff Geyser, so you can come back DOWN while carrying.
- **Spine road:** one clear trail down the whole length with boost rings every ~120 studs
  on the spine (random rings elsewhere stay as they are).
- **Deep exits:**
  - Ashen Pass Camp: Safe, no bonus. You can bank without walking home.
  - Lava Outpost: Dangerous, +50% cash, 15% mutation.
  - Glacier Station: Dangerous+, +75% cash, 20% mutation.
  - Skyport: Secret, +125% cash, 40% mutation.
- **Night:** the whole south closes at night like the Wilds, and the fog gate moves to the
  Ashen Pass. Carried loot is still lost at nightfall, so the deep exits matter.
- **The map board** gets a tall layout (portrait or scrollable) because the island is now long.

## 5. Tech plan (how it's built)

- **Phase 0 (prep, needed first):**
  - **Streaming:** turn on `StreamingEnabled` with the gameplay-critical models kept loaded
    (treasures, extraction zones, map board, spawn areas). This needs an audit of every
    client `WaitForChild` and CollectionService assumption (listed in `docs/DEV_STATUS.md`
    as "needs a code review first"). A 75% larger world is exactly when phones start to
    struggle without it.
  - **Terrain generation:** make the generated area asymmetric (x ±608, z -1250..+608, only
    the south strip is new). The coastline becomes the union of today's circle and a long
    noisy peninsula (a capsule from z -400 to -1000, radius about 260). The sea around the
    isles stays open water.
  - **Zones and regions:**
    - `Zones.AreaName` gets new z-bands for the south.
    - `Regions`/`GameConfig.Regions` get the 3 new regions.
    - The danger scale goes to 7.
    - `MapView` gets the tall layout.
  - **Region gates:** a shared `RegionGates` check (server) plus Rune Gate visuals, driven
    by `GameConfig.Regions[area].RequiredAscension`.
  - **Hazard framework:** one server `HazardService` for lava (drop and knockback), crevasse
    and sea falls (drop and respawn at the edge), and zone forces (blizzard wind, low gravity
    on the client).
- **Phase 1, Ashen Pass + Emberfall:** terrain, lava channels, Mount Cinder, 6 treasures, 2
  secrets, 2 guardians, Eruption event, Lava Outpost exit, Cliff Lift.
- **Phase 2, Steamfields + Rimeheart:** glacier terrain, crevasses, ice physics, frozen ship,
  Frostbane's Tomb, Blizzard event, Glacier Station exit.
- **Phase 3, Starfall Isles:** floating islands (terrain balls plus rock parts), low gravity,
  light bridges, Meteor Shower event, Skyport exit.
- **Phase 4, balance and polish:** pacing simulation, music per biome (a lava drum track, an
  icy choir, an ethereal synth), announcements, analytics funnels for "first time in
  Emberfall", and the like.

Each phase ships on its own and is playable. I'd do them one at a time with a playtest after
each.

**Performance budget per new biome:** about 1,500 parts, about 25 lights, particle rates
capped, and client-side critters and animation distance-culled (the same patterns as today).
All models are procedural like the rest of the game, so there are no external assets or
moderation waits.

## 6. Open questions for you

1. ~~Ascension requirement~~ DECIDED: Emberfall Ascension 1, Rimeheart Ascension 3,
   Starfall Ascension 5.
2. Should the south have its own night rules (e.g. Rimeheart stays open at night during an
   aurora, with doubled Mythic+ odds)? It's fun, but riskier for balance.
3. Names: Emberfall / Rimeheart / Starfall Isles are placeholders. Swap any you like.
4. Should Frostbane move to the Rimeheart collection set when it exists? It's in Frostpeak now.
