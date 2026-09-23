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
	MaxActive = 20, -- loot per night wave (world + carried + dropped)
	SpawnTick = 1, -- seconds between spawn checks during the night wave
	RespawnDelayMin = 15,
	RespawnDelayMax = 40,
	InitialFillFraction = 0.75, -- fraction of MaxActive spawned immediately at server start
	-- Relative roll weights. A spawn point's MinRarity/MaxRarity clamps which are eligible.
	RarityWeights = {
		Common = 100,
		Uncommon = 45,
		Rare = 18,
		Epic = 6,
		Legendary = 1.6,
		Mythic = 0.35,
		Secret = 0.05,
	},
	-- Max simultaneously active treasures of a rarity (server-wide). Keeps rare treasures rare.
	RarityCaps = {
		Epic = 2,
		Legendary = 1,
		Mythic = 1,
		Secret = 1,
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
	CarriedLabelDistance = 60,
	SwiftSpeedBonus = 1.15, -- SpecialEffect "Swift": carrier speed multiplier
	NocturnalMultiplier = 2, -- SpecialEffect "Nocturnal": Vault income multiplier at night
	VaultLabelDistance = 22,
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

-- Bench-press training (AFK-friendly). Lie on a bench and every rep pays out Strength. Tapping
-- PUSH makes reps twice as fast and builds a combo; any rep can crit as a MEGA REP.
GameConfig.Training = {
	RepPeriod = 1.6, -- seconds per rep (halved while boosting)
	SprintDuration = 1.5, -- seconds of boost per tap
	MaxTapsPerSecond = 4,
	LeaveDistance = 6, -- studs from the bench before the session ends
	-- Combo: every boosted rep in a row adds a stack (+ComboBonusPerStack each); a slow rep resets it.
	ComboMax = 10,
	ComboBonusPerStack = 0.1,
	-- MEGA REP: random jackpot rep.
	CritChance = 0.08,
	CritMultiplier = 5,
	-- Placeholder for a "2x Strength" game pass (0 = disabled). Multiplies all bench gains.
	StrengthPassId = 0,
	StrengthPassMultiplier = 2,
	-- Benches are gated by ASCENSION (permanent), not Strength (which resets on every Ascension).
	-- Strength per rep = RepGain x TrainingMultiplier(ascension) x combo x crit x pass.
	Benches = {
		{ Id = "wooden", Name = "Wooden Bench", Price = 0, RequiredAscension = 0, RepGain = 5, Color = { 170, 120, 70 }, Count = 4 },
		{ Id = "iron", Name = "Iron Bench", Price = 12000, RequiredAscension = 0, RepGain = 12, Color = { 150, 155, 170 }, Count = 4 },
		{ Id = "golden", Name = "Golden Bench", Price = 200000, RequiredAscension = 1, RepGain = 30, Color = { 255, 196, 50 }, Count = 4 },
		{ Id = "diamond", Name = "Diamond Bench", Price = 2500000, RequiredAscension = 2, RepGain = 75, Color = { 120, 220, 255 }, Count = 4 },
		{ Id = "mythic", Name = "Mythic Bench", Price = 40000000, RequiredAscension = 4, RepGain = 180, Color = { 255, 70, 110 }, Count = 3 },
	},
}

GameConfig.Vault = {
	-- Progression tiers. Vaults grow UP: every PerFloor slots add a new floor to the gallery.
	Tiers = {
		{ Slots = 5, Price = 0, Enabled = true },
		{ Slots = 10, Price = 30000, Enabled = true },
		{ Slots = 20, Price = 400000, Enabled = true },
		{ Slots = 40, Price = 6000000, Enabled = true },
		{ Slots = 60, Price = 60000000, Enabled = true },
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
	-- Strength needed to Ascend grows every time: Base x Growth^ascension (10K, 25K, 62.5K, 156K...)
	BaseRequirement = 10000,
	RequirementGrowth = 2.5,
	-- ...but training speeds up every time too (compounding), so each climb stays reachable.
	TrainingMultiplierPerLevel = 1.6,
	-- Cash price per ascension (index = new level). Ties Ascension to the treasure loop, not just training.
	CashCost = { 150000, 1500000, 15000000, 100000000 },
	CashCostGrowthAfterTable = 3,
	Multipliers = { [0] = 1.0, [1] = 1.25, [2] = 1.5, [3] = 1.75, [4] = 2.0 },
	MultiplierPerLevelAfterTable = 0.25,
	Titles = { "Ascended", "Twice Ascended", "Treasure Titan", "Island Legend" },
}

GameConfig.Leaderboards = {
	StorePrefix = "SAT_LB_v1_",
	Rows = 10,
	RefreshInterval = 75, -- seconds between global fetches / board redraws
	WriteInterval = 120, -- seconds between a player's score uploads
	-- Id -> how the score is computed from player data (see LeaderboardService.Score)
	Boards = {
		{ Id = "Richest", Title = "RICHEST", Icon = "💰", Format = "Cash" },
		{ Id = "Strongest", Title = "STRONGEST", Icon = "💪", Format = "Number" },
		{ Id = "Rarest", Title = "RAREST TREASURE", Icon = "♛", Format = "Treasure" },
		{ Id = "Extractions", Title = "MOST EXTRACTIONS", Icon = "📦", Format = "Number" },
		{ Id = "Ascended", Title = "MOST ASCENDED", Icon = "✦", Format = "Number" },
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
	Scope = "v1",
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

-- Strength per rep for a bench at an ascension level (before combo / crit / pass).
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
