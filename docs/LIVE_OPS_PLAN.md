# STEAL THE TREASURE — Live Ops & Events Plan

The goal of events is simple. A player should feel the island is **alive this week** and that
something is happening **right now** that's worth telling a friend about. They should get that
without timers stuck to the HUD, streak guilt or pop-ups.

Everything here builds on systems that already ship:
- EventService, with its region events, night modifiers and Deep South storms
- Waystones
- Trophy pedestals
- Bats and slap combat
- Music layers
- Invites

It makes no monetization changes.

---

## 1. Research summary (what works and what we take from it)

Sources are linked at the site level; the figures are as reported by those outlets.

| Finding | What it means for STT |
|---|---|
| Steal a Brainrot runs developer-hosted **"Admin Abuse"** twice a week. One is Saturday around 3 PM ET, right after the weekly update. The other is "Taco Tuesday" around 6 PM ET. Each lasts roughly 30–45 minutes, runs across every server, and brings exclusive spawns and traits. ([eldorado.gg](https://www.eldorado.gg/), [SAB Events wiki](https://stealabrainrot.fandom.com/wiki/Events)) | A **fixed, predictable time** is the "log in now" hook. It isn't FOMO pressure; people plan around it the way they plan around a TV show. Pair it with the weekly update. |
| On 23 Aug 2025 the Grow a Garden × Steal a Brainrot **"Admin Abuse War"** ran for 90 minutes. GAG peaked around 22M concurrent players and SAB at 15M+, which pushed Roblox to a platform record of about 47M. ([Tribune](https://tribune.com.pk/), [designbeep](https://designbeep.com/)) | Hosted events are **the** growth format on Roblox right now: the rivalry and the spectacle get clipped and shared. It only works once there's a live audience, so this is a scaling tool, not a launch tool. |
| SAB's items tied to hosted events ("OG") **never return**. Event items may come back as variations. | Scarcity has to be **cosmetic and honest**. In a stealing game, power that only event attendees can get feels unfair and it breaks balance. |
| Roblox **Experience Events** have to be submitted at least 7 days ahead. Players can press **"Notify Me"** and get inbox and push notifications. Roblox's own docs say the best events run for 7–30 days and that a well-marketed event can multiply concurrent players 3–5× for 48–72 hours. ([Creator Hub: Experience events](https://create.roblox.com/docs/production/promotion/experience-events), [LiveOps planning](https://create.roblox.com/docs/production/game-design/liveops-planning)) | Every hosted event gets an Experience Event listing. That listing is **the** anticipation channel, and it's native and not spammy. |
| On Roblox, creators and TikTok/Shorts move discovery. The clips that spread are 5–15 seconds long, with one readable moment in each: a steal, a near-miss, a reveal, a dev appearing. ([bloxg event marketing](https://bloxg.com/)) | We design **clip moments** on purpose (section 11). |
| Licensed Roblox music (APM or DistroKid, from the Creator Store) is cleared **inside Roblox only**. ([Roblox Help: "Using Licensed Music on Roblox"](https://en.help.roblox.com/), [distrokid.com/roblox](https://distrokid.com/roblox)) | Clips uploaded to YouTube/TikTok with our in-game music **can get Content ID claims**. We need a way to mute the music during capture. |

**What we don't copy:** we don't copy their names, formats, items, "OG" branding or the brainrot theme.
Their structural lessons are fair game: a fixed schedule, attaching the event to the update, spectacle,
and honest scarcity. Our twist comes from our own loop: **heists, carrying, slapping and vaults**.

---

## 2. Our unique Admin Abuse: **HEIST HOUR**

In other games the admin is a generous god who showers everyone with loot. In STEAL THE TREASURE
the devs are **the biggest thieves on the island**, and the players are trying to rob *them*.

> *"The Crew is in town."* — For 45 minutes the devs open the island's hidden vaults on every server,
> then personally hunt anyone carrying their loot.

### The three acts (45 min, every server at once)

| Time | Act | What happens | Built on |
|---|---|---|---|
| 0–15 min | **1 · THE VAULTS OPEN** | Treasure falls across all four regions in rotation. Gold-tinted drops carry a heist-only mutation, **"Heisted"**: the treasure's model gets a gold-foil sheen and a coin-trail effect. | `TreasureRain` and `GoldRush` runners, a new mutation entry |
| 15–30 min | **2 · THE CREW HUNTS** | The hosting dev appears as a **Keeper**: a big guardian silhouette with a **Big Bang** bat. The dev slaps carriers, while slap-drops make extra loot for everyone nearby. Extracting while a dev is in the same region gives the line *"YOU ROBBED THE DEVS"* in the extraction reveal and a badge. | The Combat slap rules as they stand (1st slap slows, 2nd throws and drops); the Extraction reveal |
| 30–45 min | **3 · THE CROWN JOB** | Each server gets one **Dev Crown**, a huge, heavy Secret treasure that only a strong player can lift. It spawns at a random event site. Whoever banks it puts it on their vault's **trophy pedestal** for all to see. | `TreasureService` spawning, the trophy pedestal as it stands |

**Why this is ours:**
- The admin is a threat, not a vending machine.
- The best moments (a dev slapping a carrier off a cliff, a player escaping a dev with the Crown) are
  the kind of clips that get shared.
- It reuses almost everything we already have.

### What ships now (this build)

- `/event all <name>` (or `/event global <name>`) starts any existing event on **every live
  server** through MessagingService.
  - Each server shows a **"🎙 HEIST HOUR IS LIVE!"** banner and starts the event 4 seconds later.
  - A server with an event already running waits up to 45s for it to finish.
  - Broadcasts older than 60s are ignored.
- The config lives in `GameConfig.Events.Hosted`. The parser is `Shared/Logic/AdminCommand` and is unit-tested.
- In Studio, `/event all rain` runs on the local server only.
- Who can host: Studio, and the owner of a user-owned place. For a group-owned place, add host
  UserIds to `GameConfig.Events.AdminUserIds`.
  - Consider keeping that list out of this public repo, e.g. by reading it from a private config.

**Host runbook (today):** join a public server as the owner → `/event all rain` → wait for it to
end (60 s) → `/event all meteor` → … Space the events 2–3 minutes apart, so each one lands as its own moment.

---

## 3. Answers to the 12 questions

### 1. What should our first event be?
**HEIST HOUR #1: "The Opening Job"**, hosted on the Saturday of our first big content update.

Start with a **reduced version** that uses today's tooling: a dev on live servers chaining
`/event all rain`, `gold`, `eruption` and `meteor` over 30 minutes.

Ship the full three acts once the pieces in section 4 are built.

### 2. What should happen during it?
The three acts in section 2: **open vaults → the crew hunts → the Crown job.**

Each act changes what the smartest play is: grab fast, then carry carefully, then work together
to lift the Crown. That keeps the 45 minutes from feeling like one long loot pinata.

### 3. How long should it last?
- **Heist Hour:** 45 minutes (30 for the first, reduced one).
  - That's long enough for a friend who gets a notification to join in time.
  - It's short enough that attendance stays high.
- **Seasonal event** (Experience Event listing): 7 days, e.g. "Storm Week", when Deep South storms
  roll 3× as often and a themed mutation is in the pool.

### 4. How should players discover it?
All of these are native and non-intrusive:
1. **A Roblox Experience Event** listing, submitted at least 7 days ahead, with its **Notify Me** button. This is the main channel.
2. **The game icon and thumbnail** switch to the Heist Hour art 48 hours before.
3. **In the world**, not the HUD:
   - A **Heist Clock** board in the District shows the next Heist Hour time in the player's local time zone.
   - 10 minutes before it starts, a golden beam of light rises over the District vaults and every server's sky tints gold.
   - Players *see* it without a pop-up.
4. **The update log** board in the District.
5. **Community:** a Discord or group shout, and the creators in section 11.

### 5. What makes it visually and socially interesting?
- **Visual:**
  - The whole island reacts: a gold sky and rain in every region.
  - The dev appears as a giant Keeper.
  - The Crown is huge, and it's the only one on the server.
- **Social:**
  - There's a shared enemy (the dev) and a shared goal (the Crown needs a strong carrier plus escorts who slap off chasers).
  - A **public result:** the Crown sits on the winner's trophy pedestal for everyone passing the vault district to see.

### 6. How can players tell their friends about it?
- The Invites card already fires on `EventStarted`, and hosted events trigger it on every server.
  Next step: for hosted events, change its headline to *"🎙 HEIST HOUR — BRING YOUR CREW!"*. The throttling stays as it is.
- Banking the Crown or robbing a dev triggers a share moment, through the existing Invites reasons.
- The Experience Event **Notify Me** is also a share link players can send.
- Coming later: a Roblox **badge** for "Robbed the Devs". Badges show on profiles and bring people back.

### 7. What should be permanent vs temporary?

| Permanent (earned once, kept forever) | Temporary (only during the event) |
|---|---|
| Heisted-mutation treasures you banked (they keep earning income) | The Heisted mutation *dropping* |
| The Dev Crown on your pedestal | The Dev Crown *spawning* |
| Badges ("Robbed the Devs", "Crown Job") | The Crew Hunt act |
| Cosmetic bat trail for Crown bankers | Gold sky, beam, event music cue |

Rules:
- **No stat power is event-only.** Strength, bats, gadgets and income tiers stay reachable by everyone.
- A cosmetic may come back as a **variation** (a new colour or name), never as the identical item. That keeps the originals honest.

### 8. How often should events happen?

| Layer | Cadence | Status |
|---|---|---|
| Micro events (Rain, storms, night modifiers) | Every 5–10 min of daytime and at nightfall | ✅ live |
| **Heist Hour** (hosted) | **Weekly, same slot**: Saturday, 1 hour after the update | 🔨 tooling ✅, acts in progress |
| Second weekly slot | Only once the community asks for it (it's a CCU sign), e.g. a Wednesday evening | later |
| Weekly update | Every Friday/Saturday: 1 new treasure line, bat, area, or system | ongoing |
| Seasonal week | Every ~6 weeks, as a 7-day Experience Event | later |

Don't go faster than we can host. A hosted slot that gets skipped hurts more than never promising it.

### 9. How should we build anticipation?
- **T-7 days:** submit the Experience Event, and post a **silhouette teaser** of the new treasure or Crown.
- **T-48 hours:** switch the icon and thumbnail; the Heist Clock board shows the time.
- **T-24 hours:** creators get early access in a private server (section 11).
- **T-10 minutes:** the gold beam and gold sky go up on all servers. (A small `/event tease` broadcast is next on the list.)
- **T-0:** the hosted banner. A dev joins a busy server; players can see the dev's name in the player list.

### 10. What should happen after the event?
- **A lasting mark on the world:**
  - Crowns sit on pedestals.
  - The event site keeps a visual scar for a week (scorched ground, scattered gold coins).
- **A recap** on the update log board: how many Crowns were banked across all servers, and how many devs got robbed. Aggregate numbers only, no player names in the repo or in public posts without consent.
- **A bridge:** the Heist Clock immediately shows the next date, and the next update is teased.
- **Tuning:** check `Analytics` for EventStarted, extraction and drop counts during the hour, so the next one can be adjusted.

### 11. How can events generate short-form content?
Design the moments that make good clips:
- **The steal:** grabbing the Crown while three players slap at you.
- **The near miss:** "SO CLOSE! 4 STUDS FROM THE EXIT" is already a readable caption on screen.
- **The dev slap:** a Big Bang bat throw off the waterfall mountain.
- **The reveal:** the extraction reveal plus the Crown landing on the pedestal.

Creator program (lightweight):
- Before each Heist Hour, invite 3–10 small Roblox creators (5k–100k followers) to a private
  server, and give them the time and the "Robbed the Devs" challenge.

**Music caveat:** our licensed tracks are cleared for Roblox only. Add a **"Music: Off"** toggle
in settings, next on the list, and tell creators to use it while recording. The alternative is
risking Content ID claims on their clips.

### 12. How can events create "I need to log in now" moments without manipulative UI?
- **Real, scheduled, social moments.** "The devs are live right now and my friends are there" is a
  real reason, not a fake timer.
- **Notifications only through Roblox's Notify Me**, which players opt into.
- **No HUD countdowns, no "you'll lose X" warnings, no login streaks** that punish a missed day.
- Missing an event costs a cosmetic, never progress. The next Heist Hour is always a week away.
- Inside the game, the world itself is the alert: the gold sky and the beam.

---

## 4. Implementation backlog (in order, each one small and shippable)

| # | Task | Files | Size |
|---|---|---|---|
| 1 | ✅ `/event all <name>` cross-server hosting with a banner | `EventService`, `AdminCommand`, `GameConfig.Events.Hosted` | done |
| 2 | "Music: Off" setting (for creators recording clips) | `MusicController`, Settings menu, `DataSchema.Settings` | S |
| 3 | `HeistHour` runner: chains the 3 acts on a timer; `/event all heist` | `EventService` (a new runner that calls the existing runners in sequence) | M |
| 4 | "Heisted" mutation, spawned only while `workspace.EventId == "HeistHour"` | `Config/Mutations`, `TreasureService.SetRegionBoost` | S |
| 5 | Dev Keeper mode: an admin-only `/keeper` sets the Big Bang bat, a scaled character and a nametag | `BatService`, `EventService` | M |
| 6 | "YOU ROBBED THE DEVS" reveal line plus a badge, awarded when banking while an admin is in the same Area | `Extraction`, `Notifications`, BadgeService | S |
| 7 | Dev Crown: a Secret treasure that only spawns in Act 3 (one per server) | `Treasures`, `TreasureModels`, `TreasureService` | M |
| 8 | A Heist Clock board in the District, reading `GameConfig.Events.NextHeistUTC` and shown in local time | `WorldBuilder`, a client label | S |
| 9 | `/event tease`: a gold sky and beam on all servers | `EventService`, `Lighting` | S |

Every item needs:
- a unit test where it's pure logic
- a Studio smoke test with two clients
- a check against `docs/PLAYTEST_CHECKLIST.md`

## 5. First Heist Hour — checklist

- [ ] The weekly update is live and CI + Publish is green.
- [ ] The Experience Event was submitted at least 7 days before, with the art uploaded.
- [ ] The icon and thumbnail were swapped 48 hours before.
- [ ] The host account can run `/event rain` on a live server (a dry run the day before, in a private server).
- [ ] The host has the run sheet: `rain → (2 min) → gold → (2 min) → eruption → (2 min) → meteor`, repeated across 30 min.
- [ ] Someone watches the Developer Console for `[Events] global broadcast failed`.
- [ ] Afterwards, record the concurrent-player peak, session length and new favourites in `docs/DEV_STATUS.md`.

## Built: the 🛡 Admin panel and the Like Goal

- **Admin panel** (🛡 button next to 💬, only for the owner / `GameConfig.Events.AdminUserIds`):
  pick THIS SERVER or ALL SERVERS, then send a message (banner on every screen, optional pin on
  the Info Board), run a boost (LUCK x3, CASH x2, MUTATIONS x5, STRENGTH x2 for 5-60 min), end
  boosts, or start any event. Server side: `Services/AdminService` (MessagingService topic
  `SATAdmin`, boosts saved in DataStore `SATAdmin` so new servers join a running boost).
- **Like Goal** (floating over the Info Board): at each goal in `GameConfig.LikeGoal.Goals`
  every server gets the reward boost once. Community-wide, never a personal reward for liking.
  Needs "Allow HTTP Requests" (reads likes through a public proxy of the games API).
