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

GameConfig.Strength = {
	Start = 10, -- enough to carry a Common comfortably on the very first run
	Max = math.huge, -- uncapped: Ascension requirements keep growing instead
	-- Strength earned when extracting: ceil(weight * factor)
	ExtractionGainPerWeight = 0.1,
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
	PickupRange = 12,
	PickupHoldBase = 0.25,
	PickupHoldPerWeight = 0.01,
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
	MaxActive = 16, -- world + carried + dropped
	SpawnTick = 2,
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
}

GameConfig.Extraction = {
	Duration = 10,
	TickRate = 0.1,
	HitInterrupts = true, -- any qualifying hit cancels progress; a Knock also drops the treasure
	Categories = {
		Safe = { Bonus = 1.0, Label = "SAFE" },
		Dangerous = { Bonus = 1.5, Label = "DANGEROUS" },
		Secret = { Bonus = 2.0, Label = "SECRET" },
	},
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

-- Bench-press training (AFK-friendly). Lie on a bench to gain Strength over time; tap PUSH
-- for a short boost. Higher tiers are unlocked with Cash + a Strength requirement.
GameConfig.Training = {
	TickRate = 1, -- seconds between server strength ticks
	SprintMultiplier = 2,
	SprintDuration = 1.5, -- seconds of boost per tap
	MaxTapsPerSecond = 4,
	LeaveDistance = 6, -- studs from the belt centre before the session ends
	PressPeriod = 1.6, -- seconds per rep (visual), halved while boosting
	-- Placeholder for a "2x Strength" game pass (0 = disabled). Multiplies all bench gains.
	StrengthPassId = 0,
	StrengthPassMultiplier = 2,
	-- Benches are gated by ASCENSION (permanent), not Strength (which resets on every Ascension).
	-- Actual gain = Rate x TrainingMultiplier(ascension) x boosts.
	Benches = {
		{ Id = "wooden", Name = "Wooden Bench", Price = 0, RequiredAscension = 0, Rate = 0.02, Color = { 170, 120, 70 }, Count = 4 },
		{ Id = "iron", Name = "Iron Bench", Price = 5000, RequiredAscension = 0, Rate = 0.05, Color = { 150, 155, 170 }, Count = 4 },
		{ Id = "golden", Name = "Golden Bench", Price = 75000, RequiredAscension = 1, Rate = 0.12, Color = { 255, 196, 50 }, Count = 4 },
		{ Id = "diamond", Name = "Diamond Bench", Price = 500000, RequiredAscension = 2, Rate = 0.3, Color = { 120, 220, 255 }, Count = 4 },
		{ Id = "mythic", Name = "Mythic Bench", Price = 5000000, RequiredAscension = 4, Rate = 0.8, Color = { 255, 70, 110 }, Count = 3 },
	},
}

GameConfig.Vault = {
	-- Progression tiers. Vaults grow UP: every PerFloor slots add a new floor to the gallery.
	Tiers = {
		{ Slots = 5, Price = 0, Enabled = true },
		{ Slots = 10, Price = 25000, Enabled = true },
		{ Slots = 20, Price = 250000, Enabled = true },
		{ Slots = 40, Price = 2500000, Enabled = true },
		{ Slots = 60, Price = 10000000, Enabled = true },
	},
	PlotSize = 30,
	PerFloor = 20,
	FloorHeight = 12,
	Columns = 5,
	ColumnSpacing = 5,
	RowSpacing = 5.5,
	DisplayMaxScale = 2.4, -- treasure size cap on pedestals
	AutoPlaceNewTreasures = true,
	TeleportHomeOnExtract = true, -- carrier is brought to their Vault after extracting
	HomeStandDistance = 19, -- studs in front of the plot centre
	HomeTrophySeconds = 3, -- how long the banked treasure is held overhead (cosmetic)
}

GameConfig.Ascension = {
	-- Strength needed to Ascend grows every time: Base x Growth^ascension (100, 250, 625, 1.6K...)
	BaseRequirement = 100,
	RequirementGrowth = 2.5,
	-- ...but training speeds up every time too (compounding), so each climb stays reachable.
	TrainingMultiplierPerLevel = 1.6,
	-- Cash price per ascension (index = new level). Ties Ascension to the treasure loop, not just training.
	CashCost = { 50000, 250000, 1000000, 3000000 },
	CashCostGrowthAfterTable = 2,
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
	FirstDelay = 240, -- seconds after server start before the first event
	IntervalMin = 480,
	IntervalMax = 720,
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
	CursedHour = {
		Name = "CURSED HOUR",
		Icon = "☠",
		Duration = 120,
		-- Multiplies spawn weights of these rarities while the curse lasts.
		RarityBoost = { Rare = 2, Epic = 3, Legendary = 3, Mythic = 3 },
		GuardianRage = 1.3, -- guardian detect range, chase speed and damage multiplier
	},
	-- Relative chance the scheduler picks each event.
	Weights = { TreasureRain = 2, CursedHour = 1 },
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
