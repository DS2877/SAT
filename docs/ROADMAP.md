# Roadmap

Agreed plan (from the project owner). Work top to bottom; a later phase only starts when the
earlier one is solid. **Fun and stability beat feature count.**

## 1. Stabilise the current build  ← CURRENT
No big new features. Mobile-test the whole core loop (see `docs/PLAYTEST_CHECKLIST.md`):
Strength/training, treasure discovery, carry/weight, guardians, PvP/knock/drop, extraction,
cash, Vault, gadgets, Collection, Ascension, day/night, events, respawn/death, persistence, UI.
**Goal:** no major gameplay bugs and nothing that feels half-finished.

Done in code so far (static audit):
- Starter loot: the low-rarity spawn points near the gate refill during the day, so a player
  who joins mid-day always finds a first treasure (loot otherwise only spawns at night).
- Tutorial step 4 "COLLECT YOUR CASH" (the new economy was never taught).
- Vault sell prompt moved off F (F is BONK: holding attack in your Vault could sell).
- "Next treasure" goal says whether it is out right now or spawns tonight.
- Funnel + time-to-step analytics (see phase 3).

## 2. Make the core loop addictive
Train → Explore → Find → Carry → Escape → Extract → Earn → Upgrade → Repeat

Analysis of the current build (to validate in playtests before building):

| Question | Today | Gap / proposal |
|---|---|---|
| Why one more run? | Every night wave refreshes the island (a "slot pull" every 5.5 min), new treasures raise income, mutations are a lottery, Collection has gaps | No short-term streak/combo for chaining runs. Proposal: "run streak" bonus for extractions in the same day. |
| Is risk/reward clear? | Tags show $/s; guardians, PvP and nightfall are the risks | **Regression:** the Dangerous/Secret extraction bonus now only scales the small finder's fee, so the risky route barely matters. Proposal: risky extractions get a chance to ADD a mutation (e.g. 15% / 35%). |
| Are treasures exciting? | Size, aura, mutation skins, tags | Primitive shapes; no "reveal" moment. Proposal: short flash + sound when the night wave lands, jackpot sting on Epic+ pickup, real models later (phase 4). |
| Is carrying heavy fun? | Slower, lower jumps, visible to everyone, "OVERPOWERED" when strong | Little physical feedback. Proposal: strain animation/sway, heavy footsteps, camera bob scaled by burden. |
| Does extraction feel tense? | 10 s stand-still, hits interrupt | Nobody knows it's happening. Proposal: server-wide "X is extracting a LEGENDARY at the Dock!" for Epic+ with a 10 s marker → chase moments; heartbeat audio for the extractor. |
| Fast enough early? | First gadget ~2 min, first Vault upgrade ~15–20 min, Commons carried at full speed from the start | Needs real funnel data (phase 3). |
| Always a clear next goal? | Tutorial steps 1–4, gadget, Ascension, next undiscovered treasure | Missing: "UPGRADE VAULT" when full and affordable, "SELL your weakest" when full, mid-term goals (collection sets). |

## 3. First 10 minutes
A new player must quickly understand: *I train → find something valuable → have to get it
home → can be stopped → earn money → get stronger → want something even better.*

Measurement (live): Roblox onboarding funnel, in order: Joined → FirstTraining →
FirstTreasure → FirstExtraction → FirstCollect → FirstGadget → FirstVaultUpgrade →
FirstTheft → FirstAscension, plus a `FunnelTime_<step>` custom event whose value is the
seconds since joining. Creator Dashboard → Analytics → Funnels / Custom events.

## 4. Treasure / content expansion
More (and more visually extreme) treasures, more mutations, stronger rarity identity,
secrets, hidden locations, better discovery moments, environmental storytelling.
**Every new treasure needs a gameplay or economic purpose** (weight/value trade-off, special
effect, set bonus, region identity) - not just another object.

## 5. World expansion
Improve existing areas first: shortcuts, verticality, hidden areas, risk/reward zones, more
extraction choices, new landmarks, event locations. A big new region only after the current
map is fun. No huge map before that.

## 6. Social layer
Leaderboards (exist), rare treasure showcase, Vault presentation, emotes, social moments,
server events, global announcements, bragging/flex moments.
**Not planned:** trading, clans, MMO systems (unless decided later).

## Parked (decide later)
- Vault raiding + Lock button (genre core in Steal a Brainrot; revisit after phase 2).
- Monetisation pack (2x Strength pass is coded, needs a pass ID; 2x Cash, auto-collect,
  luck boost, extra pedestals), offline earnings, daily rewards.
