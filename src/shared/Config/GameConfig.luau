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
	Start = 1,
	Max = 150,
	-- Strength earned when extracting: ceil(weight * factor)
	ExtractionGainPerWeight = 0.2,
}

GameConfig.Carry = {
	-- Carry Ratio = Treasure Weight / Player Strength. First band whose MaxRatio >= ratio wins.
	Bands = {
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
	Radius = 145,
}

GameConfig.Training = {
	Period = 1.6, -- seconds for the marker to sweep 0 -> 1 -> 0
	RepsPerSet = 8,
	MinTapInterval = 0.3,
	ClientTimestampTolerance = 0.4,
	MaxStationDistance = 16,
	RestBetweenSets = 1.5,
	OverCapGain = 1, -- perfect reps above a station's cap still give this much
	Stations = {
		stone_lift = {
			Name = "Stone Lift",
			RequiredStrength = 1,
			Cap = 30,
			PerfectGain = 2,
			GoodGain = 1,
			PerfectWindow = 0.08,
			GoodWindow = 0.2,
		},
		chain_pull = {
			Name = "Chain Pull",
			RequiredStrength = 20,
			Cap = 70,
			PerfectGain = 4,
			GoodGain = 2,
			PerfectWindow = 0.07,
			GoodWindow = 0.17,
		},
		strength_challenge = {
			Name = "Strength Challenge",
			RequiredStrength = 50,
			Cap = 150,
			PerfectGain = 6,
			GoodGain = 3,
			PerfectWindow = 0.06,
			GoodWindow = 0.14,
		},
	},
}

GameConfig.Vault = {
	-- Progression tiers. Enabled=false tiers are designed but not yet physically supported.
	Tiers = {
		{ Slots = 5, Price = 0, Enabled = true },
		{ Slots = 10, Price = 25000, Enabled = true },
		{ Slots = 20, Price = 250000, Enabled = true },
		{ Slots = 40, Price = 2500000, Enabled = false },
		{ Slots = 60, Price = 10000000, Enabled = false },
	},
	Columns = 5,
	Spacing = 6,
	AutoPlaceNewTreasures = true,
}

GameConfig.Ascension = {
	RequiredStrength = 100,
	Multipliers = { [0] = 1.0, [1] = 1.25, [2] = 1.5, [3] = 1.75, [4] = 2.0 },
	MultiplierPerLevelAfterTable = 0.25,
	Titles = { "Ascended", "Twice Ascended", "Treasure Titan", "Island Legend" },
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
