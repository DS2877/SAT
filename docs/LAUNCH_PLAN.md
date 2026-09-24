# Launch plan: design review, economy, monetisation

Written as head of game design + monetisation, pre-launch. Everything below is implemented
unless it is listed under **"Your action before launch"**.

## 1. The loop (does everything connect?)

```
TRAIN (gym, waiting game) -> strength lets you carry heavier loot at full speed
  -> NIGHT wave spawns loot (harder regions = rarer loot, scarier guardians)
  -> FIND + CARRY it (PvP bonks, guardians, nightfall deadline)
  -> EXTRACT (safe / dangerous / secret: risk = bigger fee + mutation chance)
  -> VAULT earns $/s (x3 at night, collection sets, ascension, boosts)
  -> SPEND: vault floors, benches, gadgets
  -> ASCEND (rebirth): lose cash, gadgets and every treasure but your best -> permanent x income
```

Findings and fixes:

| # | Finding | Fix |
|---|---|---|
| 1 | Simulated player reached the **max Vault (60 slots) in ~77 min**, then had billions with nothing to buy. | Vault tiers 25K / 750K / 25M / 500M. Max vault now ~4-5 h. |
| 2 | Ascension kept every treasure, so the "fresh start" cost nothing (income came straight back). | Ascension now clears the Vault except the single best treasure (the **Heirloom**). Genre-standard rebirth. |
| 3 | Ascension cash requirement (150K) was irrelevant next to mid-game income. | 10M / 100M / 1B / 5B, then x5. Strength gates the first climbs (~80-95 min), cash matters from the 3rd. |
| 4 | Ascension income bonus (+25%/level) too weak for a real reset. | x1.5 / x2 / x2.5 / x3, then +0.5 per level. |
| 5 | Bench + gadget prices far below mid-game income. | Benches 15K / 1.5M / 30M / 600M; gadgets 500 ... 3M (they are lost on Ascension = recurring sink). |
| 6 | "RICHEST" leaderboard ranked current Cash, which Ascension wipes. | Now "TOP EARNERS" (lifetime). Boards reset for launch (store v2). |
| 7 | Discovery / secret rewards were pocket change after minute 5. | Coast 5K, Ruins 25K, Falls 100K; secrets 10K / 50K / 150K. |

Simulation (`python3 tools/balance/run.py`, 40 runs, active vs busy server): Vault 10 at ~6 min, Vault 20
~16-28 min, Vault 40 ~55-70 min, first Ascension ~80-95 min, second ~2.5-3 h, max Vault ~4-5 h.
Pacing is also locked in by unit tests (`tests/run.luau`).

## 2. Monetisation

Principle: **never sell PvP power.** Sell time on your own progress, convenience, and moments
that make the whole server's session better. Free players get generous free boosts too.

### Game passes (one-time)
| Pass | Price | Perk | Why it's fair |
|---|---|---|---|
| 💰 2x Cash | 499 R$ | Vault income x2 | Genre staple; own progress only |
| 👑 VIP | 299 R$ | +20% income, gold [VIP] chat tag, x2 daily reward | Status + mild boost |
| 💪 2x Strength | 349 R$ | Gym gains x2 | Carry speed is capped (x1.1), can't out-fight anyone |
| 🌙 Night Shift | 149 R$ | Offline 100% for 4 h (vs 50% / 30 min) | Pure convenience |
| 🧲 Auto Collect | 99 R$ | Cash lands in your wallet automatically | Pure convenience |

### Developer products (repeatable)
| Product | Price | Effect |
|---|---|---|
| 🌧 Treasure Rain | 149 R$ | Rains loot for the **whole server** (now, or at dawn). Buyer gets a server-wide shout-out. |
| ✨ Gold Rush | 99 R$ | Tonight's loot in one region x6 mutation chance **for everyone**. |
| ⚡ Strength Surge | 49 R$ | x3 gym gains for 15 min (stacks time). |
| 💵 Pocket Cash / 💰 Treasure Sack / 🏦 Dragon Hoard | 29 / 99 / 399 R$ | 10 / 45 / 240 minutes of **your** income (with floors), so a pack is never worthless at any stage. Bigger = better value. |

The two server events are the viral engine (the Steal a Brainrot / Grow a Garden "admin
event" effect): one purchase lights up a whole server, everyone benefits, the buyer is the hero.

### Free boosts (retention + virality)
- **Friends**: +10% Vault income per friend in the server, max +30% ("play with friends").
- **Premium**: +10% (also improves Premium Payouts).
- **Group**: +10% when `Free.GroupId` is set.
- **Daily streak**: 7 escalating days (day 7 jackpot), scaled to your income; VIP doubles it.
- **Offline**: 50% for 30 min (Night Shift pass: 100% for 4 h).

### Where the store shows up (soft, never pop-ups)
- 💎 STORE button in the left menu column (gold rim).
- "⚡ x3 SURGE" button on the gym panel (becomes a countdown while active).
- "💰 2x CASH" button in the Vault menu until owned.

### Tech
`Services/MonetizationService`: ownership on join + purchase, idempotent `ProcessReceipt`
(receipt log in player data, saved before `PurchaseGranted`), event queue for server gifts,
hooks into Vault (offline terms, auto collect), Training (multipliers) and the income boost
attribute. Items with `Id = 0` are hidden as "SOON" and grant nothing.

## 3. Your action before launch

1. ~~Create the passes + products~~ DONE 2026-09-24 (ids in Config/Monetization.luau).
   Still to do: add icons to each pass / product in the Creator Dashboard.
2. **Group**: create the community group and set `Monetization.Free.GroupId`.
3. **Private servers**: enable them (Creator Dashboard → Access) for ~100 R$.
4. **Experience questionnaire / maturity**: fill it in (mild cartoon violence: bonks).
5. **Thumbnails + icon + trailer**: the big day/night + Treasure Rain moments sell the game.
6. **Live place**: point the publish workflow at the live universe/place ids
   (`ROBLOX_TEST_UNIVERSE_ID` / `ROBLOX_TEST_PLACE_ID` variables) when you are ready.
7. **Playtest on a phone** once more (docs/PLAYTEST_CHECKLIST.md) - especially the store,
   Ascension (Heirloom) and the new prices.

## 4. Known limits / next ideas
- `StreamingEnabled` is off (the world is fully replicated). Fine for 10-player servers; if
  low-end phones struggle, streaming is the next performance step (needs a code review first).
- Music: licensed APM library tracks; the Mountain King + stings are our own approved uploads.
- Post-launch content cadence: a new region or event every 2 weeks keeps the treasure hunt fresh.
