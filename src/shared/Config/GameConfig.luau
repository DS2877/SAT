-- Central balance + tuning values. Gameplay scripts must read numbers from here,
-- never hard-code them. Pure data: no requires, no Roblox APIs (unit-testable).

local GameConfig = {}

GameConfig.MaxPlayers = 10

GameConfig.Player = {
	BaseWalkSpeed = 18,
	BaseJumpPower = 50,
	RespawnTime = 3,
	SpawnProtection = 2, -- seconds of ForceField after spawning
	MaxHealth = 100,
}

-- Strength and treasure Weight share one scale (x100 of the original design) so every rep and
-- extraction pays out numbers that feel big: a Common weighs 100-500, a new player has 1,000.
GameConfig.Strength = {
	Start = 1000, -- enough to carry a Common comfortably on the very first run
	Max = math.huge, -- uncapped: Ascension requirements keep growing instead
	-- Strength earned when extracting: ceil(weight * factor) (Pirate Chest 2,000 -> +200)
	ExtractionGainPerWeight = 0.1,
}

-- MONEY: treasures in your Vault earn $/s (Economy.Income = Value / IncomeDivisor x mutation),
-- so income depends on WHAT you own, not how often you run. Extraction only pays a finder's
-- fee; the real reward is a new earner. Prices below are tuned against these incomes
-- (see the pacing test in tests/run.luau).
GameConfig.Economy = {
	IncomeDivisor = 100, -- Common $1-5/s, Rare $30-95/s, Legendary $650-2.1K/s, Secret $25K/s
	SellIncomeSeconds = 60, -- sell price = one minute of that treasure's income
	FindersFeeSeconds = 20, -- extraction pays 20 s of income up front (x zone bonus)
	CollectRadius = 4, -- studs from the Vault's collect pad to cash out
	-- OFFLINE: while you're in a server the Vault always earns full rate (AFK and benching
	-- included - we want players to stay online). While you're OFFLINE it earns this fraction,
	-- for at most OfflineMaxHours, paid onto the collect pad when you come back.
	-- (A later monetisation lever: e.g. a pass that raises the rate or the cap.)
	OfflineIncomeRate = 0.5,
	OfflineMaxHours = 0.5, -- 30 minutes
	OfflineMinSeconds = 60, -- shorter gaps (a quick rejoin) pay nothing
}

-- The island's heartbeat (Steal-an-Egg style): a 5-minute DAY to hunt and extract, then a
-- 30-second NIGHT. At nightfall every treasure still out there - including anything being
-- carried - is lost, and everyone in the wilds is sent home to their Vault. During the night a
-- fresh wave of loot spawns: treasure ONLY spawns at night (Treasure Rain is the exception).
-- Clock is derived from server time (Logic/DayNight) so every server and client agree.
GameConfig.DayNight = {
	CycleSeconds = 330,
	NightSeconds = 30,
	DayStartClock = 6.5,
	DayEndClock = 18.5,
	NightIncomeMultiplier = 3, -- Vaults earn triple while it's dark
	WaveFillFraction = 0.6, -- the loot wave is fully spawned after 60% of the night
	WarnSecondsBeforeNight = { 60, 30, 10 },
	-- At dawn every spawned treasure of this rarity or better (plus Diamond/Rainbow mutations)
	-- is announced to the server with its region, at most AnnounceMax banners.
	AnnounceMinRarity = "Legendary",
	AnnounceMax = 3,
}

-- Collection sets: discover every treasure native to a region (Wilds, Ruins, Coast, Falls) to
-- complete its set; each completed set adds a permanent Vault income bonus.
GameConfig.Collection = {
	SetBonusPerSet = 0.10,
}

-- REGIONS: the island gets harder the further you go. Danger (1-4 stars) and the strength we
-- recommend are shown on the region gates and the title card when you cross in; the first
-- visit pays a one-time discovery bonus (Config/Regions has names, colours and moods).
GameConfig.Regions = {
	Wilds = { Danger = 1, RecommendedStrength = 1000, DiscoveryReward = 0 },
	Coast = { Danger = 2, RecommendedStrength = 3000, DiscoveryReward = 5000 },
	Marsh = { Danger = 2, RecommendedStrength = 5000, DiscoveryReward = 12000 },
	Ruins = { Danger = 3, RecommendedStrength = 8000, DiscoveryReward = 25000 },
	Frost = { Danger = 3, RecommendedStrength = 12000, DiscoveryReward = 50000 },
	Falls = { Danger = 4, RecommendedStrength = 20000, DiscoveryReward = 100000 },
}

-- Hidden places (Config/Regions.Secrets): one-time cash for finding each, plus a spawn point
-- inside that only the explorers know about.
GameConfig.Exploration = {
	CheckInterval = 1, -- seconds between the server's region / secret checks
}
GameConfig.Secrets = {
	old_mine = { Reward = 10000 },
	sky_ruins = { Reward = 50000 },
	catacombs = { Reward = 150000 },
	frozen_grotto = { Reward = 60000 },
	witch_hut = { Reward = 30000 },
	hollow_oak = { Reward = 8000 },
	smugglers_den = { Reward = 20000 },
	eagles_nest = { Reward = 120000 },
}

-- BOOST PADS along the trails: step on one for a burst of speed. Carriers AND chasers use them,
-- so they shape chases rather than decide them.
GameConfig.Boost = {
	SpeedMultiplier = 1.45,
	Duration = 4, -- seconds
	Radius = 5.5, -- studs from the ring's centre line (horizontal)
	Cooldown = 2, -- per player, before the same player can trigger another ring
	-- Rings are scattered at random every server (World/Adventure).
	Count = 24,
	MaxPerArea = 6, -- per region, so every region gets a share
	MinSpacing = 55, -- studs between rings
	MaxDistance = 400, -- from the island centre
}

-- LAUNCH GEYSERS (WorldLayout.LaunchPads): straight up, then a guided glide onto the target.
GameConfig.Launch = {
	Radius = 4.5,
	Cooldown = 1.5,
	ApexExtra = 14, -- studs above the higher of start / target
	GlideSeconds = 0.9, -- time from the apex to the landing
}

GameConfig.Carry = {
	-- Carry Ratio = Treasure Weight / Player Strength. First band whose MaxRatio >= ratio wins.
	Bands = {
		-- "Overpowered" carries: far stronger than the load = slightly faster than walking.
		-- Kept small on purpose so strong carriers can still be chased down.
		{ MaxRatio = 0.05, Speed = 1.1 },
		{ MaxRatio = 0.10, Speed = 1.05 },
		{ MaxRatio = 0.25, Speed = 1.0 },
		{ MaxRatio = 0.50, Speed = 0.9 },
		{ MaxRatio = 0.75, Speed = 0.75 },
		{ MaxRatio = 1.00, Speed = 0.6 },
		{ MaxRatio = 1.50, Speed = 0.45 },
		{ MaxRatio = math.huge, Speed = 0.3 },
	},
	JumpMultiplierFloor = 0.55, -- jump power scales with speed but never below this
	RecommendedStrengthFactor = 1.2, -- UI: recommended strength = ceil(weight * factor)
	-- Weight/Strength ratio that counts as "carries it easily" (full walk speed) for unlock toasts.
	EasyRatio = 0.25,
	PickupRange = 12,
	PickupHoldBase = 0.25,
	PickupHoldPerWeight = 0.0001,
	PickupHoldMax = 1.0,
}

GameConfig.Stability = {
	ShakenWindow = 3, -- seconds a carrier stays Shaken without another hit
	KnockedDuration = 1.5,
	KnockImmunity = 1.5, -- after recovering from Knocked
}

GameConfig.Treasure = {
	ReclaimProtection = 2,
	DroppedTimeout = 30,
	MaxActive = 30, -- loot per night wave (world + carried + dropped)
	SpawnTick = 1, -- seconds between spawn checks during the night wave
	RespawnDelayMin = 15,
	RespawnDelayMax = 40,
	InitialFillFraction = 0.75, -- fraction of MaxActive spawned immediately at server start
	-- WHAT SPAWNS WHERE. Common..Legendary follow the region's Danger (weights per ~100 rolls):
	-- easy regions are mostly Common/Uncommon with the odd Epic, hard regions are mostly
	-- Rare/Epic but still drop some Uncommons. Mythic and above ignore the region: they can
	-- turn up ANYWHERE on the island (AnywhereWeights, same odds everywhere).
	-- A spawn point's optional MinRarity/MaxRarity still clamps it (starter spots, secrets).
	RarityByDanger = {
		[1] = { Common = 58, Uncommon = 30, Rare = 10, Epic = 1.7, Legendary = 0.3 },
		[2] = { Common = 30, Uncommon = 36, Rare = 25, Epic = 7.5, Legendary = 1.5 },
		[3] = { Common = 8, Uncommon = 22, Rare = 38, Epic = 25, Legendary = 7 },
		[4] = { Common = 0, Uncommon = 12, Rare = 33, Epic = 40, Legendary = 15 },
	},
	AnywhereWeights = {
		Mythic = 0.2,
		Divine = 0.07,
		Secret = 0.03,
		OG = 0.007,
	},
	-- Max simultaneously active treasures of a rarity (server-wide). Keeps rare treasures rare.
	RarityCaps = {
		Epic = 3,
		Legendary = 2,
		Mythic = 1,
		Divine = 1,
		Secret = 1,
		OG = 1,
	},
	-- Rarities announced to the whole server when picked up/stolen/extracted.
	BroadcastMinRarity = "Epic",
	-- Overhead name tag (mutation / name / rarity / $ per s) only shows up close: you should
	-- read rarity and mutation from the treasure's LOOK first; the tag confirms it.
	LabelDistance = 40,
	-- Starter loot: spawn points near the gate whose MaxRarity is at most this keep refilling
	-- during the DAY too (Commons/Uncommons only), so a player who joins mid-day always finds a
	-- first treasure. Everything else only spawns on the night wave.
	StarterMaxRarity = "Uncommon",
	CarriedLabelDistance = 75, -- others see a carried treasure's tag (through walls) this close
	SwiftSpeedBonus = 1.15, -- SpecialEffect "Swift": carrier speed multiplier
	NocturnalMultiplier = 2, -- SpecialEffect "Nocturnal": Vault income multiplier at night
	VaultLabelDistance = 22,
}

-- In-game feedback (Services/FeedbackService, read with .github/workflows/feedback.yml).
GameConfig.Feedback = {
	StoreName = "PlayerFeedback",
	MaxLength = 280, -- characters per message
	MaxPerDay = 400, -- entries kept per UTC day (one DataStore key per day)
	Cooldown = 60, -- seconds between messages per player
}

GameConfig.Extraction = {
	Duration = 10,
	TickRate = 0.1,
	HitInterrupts = true, -- any qualifying hit cancels progress; a Knock also drops the treasure
	-- Riskier zones pay a bigger finder's fee AND can bless an unmutated treasure with a
	-- mutation on the spot (permanently more $/s) - the reason to take the dangerous route.
	Categories = {
		Safe = { Bonus = 1.0, Label = "SAFE", MutationChance = 0 },
		Dangerous = { Bonus = 1.5, Label = "DANGEROUS", MutationChance = 0.15 },
		Secret = { Bonus = 2.0, Label = "SECRET", MutationChance = 0.35 },
	},
	-- Which mutation a risky extraction grants (relative weights).
	MutationWeights = { Silver = 60, Gold = 30, Diamond = 10 },
	-- Epic+ extractions are announced to the whole server with a marker over the extractor.
	AnnounceMinRarity = "Epic",
	-- Run streak: every extraction in the same DAY raises the finder's fee; nightfall resets it.
	StreakBonusPerRun = 0.25,
	StreakMax = 8, -- fee x2.75 at the cap
}

GameConfig.Combat = {
	AttackRange = 9,
	AttackCooldown = 0.7,
	AttackArcDot = 0.25, -- target must be roughly in front (dot of look vector)
	PvPDamage = 8,
	KnockbackPower = 45,
	CarrierCanAttack = false, -- CARRIER = RUN, CHASER = STOP
	SafeZoneProtectsCarriers = false, -- carriers cannot hide in the District forever
	GuardianStunDuration = 2,
}

GameConfig.SafeZone = {
	-- Treasure District: circle on XZ plane. Keep in sync with WorldLayout.
	Radius = 150, -- matches the District wall
}

-- Bench-press training. Lie on a bench and every rep pays out Strength - no tapping; staying is
-- what pays (pump, set bonuses, MEGA / GOLDEN REP jackpots).
GameConfig.Training = {
	-- Training is a waiting game (Logic/Lifting): lie down and the reps come by themselves.
	RepPeriod = 1.6, -- seconds per rep
	LeaveDistance = 6, -- studs from the bench before the session ends
	-- PUMP: each rep in a row adds PumpPerRep to the multiplier, up to PumpMax (reached after
	-- ~40 s). Getting up resets it, so staying on the bench is what pays.
	PumpPerRep = 0.03,
	PumpMax = 1.75,
	-- SETS: every SetSize reps completes a set and pays SetBonus x what the set earned.
	SetSize = 10,
	SetBonus = 0.25,
	-- JACKPOTS: MEGA REP (x5) and the rare GOLDEN REP (x25).
	CritChance = 0.08,
	CritMultiplier = 5,
	GoldenChance = 0.005,
	GoldenMultiplier = 25,
	-- Paid training boosts (2x Strength pass, Strength Surge) live in Config/Monetization.
	-- Benches are gated by ASCENSION (permanent), not Strength (which resets on every Ascension).
	-- Strength per rep = RepGain x TrainingMultiplier(ascension) x pump x jackpot x pass.
	Benches = {
		{ Id = "wooden", Name = "Wooden Bench", Price = 0, RequiredAscension = 0, RepGain = 5, Color = { 170, 120, 70 }, Count = 4 },
		{ Id = "iron", Name = "Iron Bench", Price = 15000, RequiredAscension = 0, RepGain = 12, Color = { 150, 155, 170 }, Count = 4 },
		{ Id = "golden", Name = "Golden Bench", Price = 1500000, RequiredAscension = 1, RepGain = 30, Color = { 255, 196, 50 }, Count = 4 },
		{ Id = "diamond", Name = "Diamond Bench", Price = 30000000, RequiredAscension = 2, RepGain = 75, Color = { 120, 220, 255 }, Count = 4 },
		{ Id = "mythic", Name = "Mythic Bench", Price = 600000000, RequiredAscension = 4, RepGain = 180, Color = { 255, 70, 110 }, Count = 3 },
	},
}

GameConfig.Vault = {
	-- Progression tiers. Vaults grow UP: every PerFloor slots add a new floor to the gallery.
	Tiers = {
		{ Slots = 5, Price = 0, Enabled = true },
		{ Slots = 10, Price = 25000, Enabled = true },
		{ Slots = 20, Price = 750000, Enabled = true },
		{ Slots = 40, Price = 25000000, Enabled = true },
		{ Slots = 60, Price = 500000000, Enabled = true },
	},
	PlotSize = 30,
	-- Gallery layout: 4 columns split by a central aisle (walk in, lift at the far end),
	-- 4 rows, airy spacing and tall floors. 60 slots = 4 floors.
	PerFloor = 16,
	FloorHeight = 14,
	Columns = 4,
	ColumnSpacing = 5,
	AisleWidth = 4, -- extra gap between the left and right halves
	RowSpacing = 6.5,
	DisplayMaxScale = 2.4, -- treasure size cap on pedestals
	AutoPlaceNewTreasures = true,
	TeleportHomeOnExtract = true, -- carrier is brought to their Vault after extracting
	HomeStandDistance = 19, -- studs in front of the plot centre
	HomeTrophySeconds = 3, -- how long the banked treasure is held overhead (cosmetic)
}

GameConfig.Ascension = {
	-- Strength needed to Ascend grows every time: Base x Growth^ascension (30K, 75K, 188K, 469K...)
	BaseRequirement = 30000,
	RequirementGrowth = 2.5,
	-- ...but training speeds up every time too (compounding), so each climb stays reachable.
	TrainingMultiplierPerLevel = 1.6,
	-- Cash you must HAVE to ascend (index = new level). Ties Ascension to the treasure loop.
	-- Tuned with a progression simulation: Strength gates the first climbs (~80-95 min to the
	-- first Ascension), cash starts to matter from the third one.
	CashCost = { 10000000, 100000000, 1000000000, 5000000000 },
	-- A real restart (genre "rebirth"): ascending wipes ALL your Cash, every gadget and every
	-- Vault treasure except your single best one - the HEIRLOOM (Logic/AscensionReset).
	-- Vault size, benches, Collection (+ set bonuses) and titles are kept.
	ResetsCash = true,
	ResetsGadgets = true,
	ResetsVault = true,
	HeirloomsKept = 1,
	CashCostGrowthAfterTable = 5,
	-- Permanent Vault income multiplier: big enough that restarting feels worth it.
	Multipliers = { [0] = 1.0, [1] = 1.5, [2] = 2.0, [3] = 2.5, [4] = 3.0 },
	MultiplierPerLevelAfterTable = 0.5,
	Titles = { "Ascended", "Twice Ascended", "Treasure Titan", "Island Legend" },
}

GameConfig.Leaderboards = {
	StorePrefix = "SAT_LB_v2_", -- v2: fresh boards for launch (Richest = lifetime earnings)
	Rows = 10,
	RefreshInterval = 75, -- seconds between global fetches / board redraws
	WriteInterval = 120, -- seconds between a player's score uploads
	-- Id -> how the score is computed from player data (see LeaderboardService.Score)
	Boards = {
		{ Id = "Richest", Title = "TOP EARNERS", Icon = "💰", Format = "Cash" },
		{ Id = "Strongest", Title = "STRONGEST", Icon = "💪", Format = "Number" },
		{ Id = "Rarest", Title = "RAREST TREASURE", Icon = "♛", Format = "Treasure" },
		{ Id = "Extractions", Title = "MOST EXTRACTIONS", Icon = "📦", Format = "Number" },
		{ Id = "Ascended", Title = "MOST ASCENDED", Icon = "✨", Format = "Number" },
	},
}

GameConfig.Events = {
	FirstDelay = 90, -- seconds after server start before the first Treasure Rain can start
	IntervalMin = 300, -- between Treasure Rains (daytime only)
	IntervalMax = 600,
	-- Who can force events with chat commands ("/event rain"). Studio and the owner of a
	-- user-owned place are always allowed; add group admins here by UserId.
	AdminUserIds = {},
	TreasureRain = {
		Name = "TREASURE RAIN",
		Icon = "🌧",
		Duration = 60, -- treasure keeps falling for this long
		Waves = 5,
		PerWave = 3,
		Radius = 55,
		DropHeight = 140,
		FallTime = 2.5,
		Lifetime = 60, -- ungrabbed rain treasure disappears after landing + this
		RarityWeights = { Common = 55, Uncommon = 40, Rare = 22, Epic = 7, Legendary = 1 },
		-- Landing sites: WorldLayout.EventSites
	},
	-- Every event hits ONE region (Wilds / Ruins / Coast / Falls), never the whole island.
	CursedHour = {
		Name = "CURSED HOUR",
		Icon = "☠",
		Duration = 120,
		-- Multiplies spawn weights of these rarities in the cursed region.
		RarityBoost = { Rare = 2, Epic = 3, Legendary = 3, Mythic = 3 },
		GuardianRage = 1.3, -- guardian detect range, chase speed and damage multiplier (region only)
	},
	GoldRush = {
		Name = "GOLD RUSH",
		Icon = "✨",
		Duration = 90,
		MutationBoost = 6, -- every mutation chance x6 in the region
	},
	-- Treasure Rain happens during the DAY (the only daytime loot). Cursed Hour and Gold Rush
	-- are NIGHT modifiers: rolled at nightfall, they shape tonight's loot wave in one region.
	NightEventChance = 0.4,
	NightWeights = { CursedHour = 1, GoldRush = 1.5 },
	CurseLingerSeconds = 120, -- the cursed region's guardians stay furious into the morning
}

GameConfig.Gadgets = {
	Slots = 3,
}

GameConfig.Data = {
	StoreName = "SAT_PlayerData",
	Scope = "launch1", -- fresh saves for launch (all test progress stays in scope "v1")
	AutosaveInterval = 120,
	SessionLockTimeout = 300, -- seconds before another server's lock is considered stale
	LoadRetries = 4,
}

GameConfig.Remotes = {
	-- Max requests per second per player per remote (token bucket).
	DefaultRate = 10,
}

-- Strength required to go from `level` to `level + 1`.
function GameConfig.GetAscensionRequirement(level: number): number
	local a = GameConfig.Ascension
	return math.floor(a.BaseRequirement * a.RequirementGrowth ^ level)
end

-- Strength per rep for a bench at an ascension level (before pump / jackpots / pass).
function GameConfig.GetRepGain(tier, level: number): number
	return math.floor(tier.RepGain * GameConfig.GetTrainingMultiplier(level) + 0.5)
end

-- Training (bench) speed multiplier at a given ascension level.
function GameConfig.GetTrainingMultiplier(level: number): number
	return GameConfig.Ascension.TrainingMultiplierPerLevel ^ level
end

function GameConfig.GetAscensionCost(newLevel: number): number
	local costs = GameConfig.Ascension.CashCost
	if costs[newLevel] then
		return costs[newLevel]
	end
	return costs[#costs] * GameConfig.Ascension.CashCostGrowthAfterTable ^ (newLevel - #costs)
end

function GameConfig.GetAscensionMultiplier(level: number): number
	local mult = GameConfig.Ascension.Multipliers[level]
	if mult then
		return mult
	end
	local maxDefined = 0
	for lvl in GameConfig.Ascension.Multipliers do
		if lvl > maxDefined then
			maxDefined = lvl
		end
	end
	return GameConfig.Ascension.Multipliers[maxDefined]
		+ (level - maxDefined) * GameConfig.Ascension.MultiplierPerLevelAfterTable
end

return GameConfig
