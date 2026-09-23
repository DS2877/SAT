-- Positions of everything gameplay-relevant on Treasure Island.
-- Shared so the client can point to extraction zones without searching Workspace.
-- Y values are hints: WorldBuilder raycasts down from RayFrom (default 300) to find the ground.

local WorldLayout = {}

WorldLayout.GroundY = 10
WorldLayout.SeaLevel = 0

WorldLayout.District = {
	Center = Vector3.new(0, 10, 250),
	FloorRadius = 150,
	Gate = Vector3.new(0, 10, 100), -- the ONLY way between the District and the Wilds
	WallRadius = 150,
	WallHeight = 16,
	GateHalfWidth = 14,
	VaultArcRadius = 112,
	VaultArcDegrees = 150, -- plots spread across the south side, facing the plaza
}

WorldLayout.Spawn = Vector3.new(0, 13.5, 290) -- on top of the spawn pavilion

-- Strength Gym: one row of bench presses per tier (GameConfig.Training.Benches).
WorldLayout.Gym = {
	Origin = Vector3.new(-62, 10, 196), -- first bench of the first (cheapest, plaza-side) row
	RowSpacing = -14, -- each higher tier sits one row further from the plaza (-X)
	LaneSpacing = 7, -- along +Z within a row
}

WorldLayout.Shop = Vector3.new(70, 10, 215)
-- Leaderboards: arc behind the fountain, facing the spawn
WorldLayout.Leaderboards = { Radius = 40, SpreadDegrees = 100 }
WorldLayout.AscensionAltar = Vector3.new(58, 10, 160)

WorldLayout.ExtractionZones = {
	{
		Id = "expedition_camp",
		Name = "Expedition Camp",
		Category = "Safe",
		Position = Vector3.new(0, 10, 55),
		Radius = 11,
	},
	{
		Id = "temple_courtyard",
		Name = "Temple Courtyard",
		Category = "Dangerous",
		Position = Vector3.new(230, 10, -45),
		Radius = 10,
	},
	{
		Id = "hidden_falls",
		Name = "Hidden Falls Cave",
		Category = "Secret",
		Position = Vector3.new(0, 10, -330),
		Radius = 9,
		RayFrom = 26,
	},
}

WorldLayout.Waterfall = {
	CliffCenter = Vector3.new(0, 45, -345),
	CliffSize = Vector3.new(360, 90, 80), -- front face at z = -305, top at y = 90
	FallWidth = 40,
	CaveCenter = Vector3.new(0, 20, -328),
	CaveSize = Vector3.new(40, 20, 50),
	PoolCenter = Vector3.new(0, 10, -285),
	PoolRadius = 26,
}

WorldLayout.Temple = {
	Center = Vector3.new(230, 10, -140),
	BaseSize = 72,
	Tiers = 5,
	TierHeight = 8,
	Courtyard = Vector3.new(230, 10, -45),
}

WorldLayout.Shipwreck = {
	Center = Vector3.new(-345, 4, -10),
	CoveCenter = Vector3.new(-432, 0, -10),
	CoveSize = Vector3.new(150, 20, 160),
}

WorldLayout.Volcano = {
	Center = Vector3.new(-280, 0, -360),
	BaseRadius = 150,
	Height = 190,
}

-- Treasure spawn points. MinRarity/MaxRarity clamp what a point may roll.
WorldLayout.TreasureSpawns = {
	-- Wilds: close to the District gate first (guaranteed easy first treasure)
	{ Area = "Wilds", Position = Vector3.new(38, 10, 88), MinRarity = "Common", MaxRarity = "Common" },
	{ Area = "Wilds", Position = Vector3.new(-45, 10, 70), MinRarity = "Common", MaxRarity = "Common" },
	{ Area = "Wilds", Position = Vector3.new(70, 10, 20), MinRarity = "Common", MaxRarity = "Uncommon" },
	{ Area = "Wilds", Position = Vector3.new(-90, 10, 10), MinRarity = "Common", MaxRarity = "Uncommon" },
	{ Area = "Wilds", Position = Vector3.new(-150, 10, -40), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Wilds", Position = Vector3.new(130, 10, -60), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Wilds", Position = Vector3.new(-40, 10, -110), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Wilds", Position = Vector3.new(60, 10, -170), MinRarity = "Uncommon", MaxRarity = "Rare" },
	{ Area = "Wilds", Position = Vector3.new(-170, 10, -190), MinRarity = "Uncommon", MaxRarity = "Rare" },
	{ Area = "Wilds", Position = Vector3.new(150, 10, -250), MinRarity = "Uncommon", MaxRarity = "Rare" },
	-- Ancient Ruins
	{ Area = "Ruins", Position = Vector3.new(200, 10, -30), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Ruins", Position = Vector3.new(262, 10, -30), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Ruins", Position = Vector3.new(170, 10, -150), MinRarity = "Uncommon", MaxRarity = "Epic" },
	{ Area = "Ruins", Position = Vector3.new(292, 10, -150), MinRarity = "Uncommon", MaxRarity = "Epic" },
	{ Area = "Ruins", Position = Vector3.new(230, 10, -205), MinRarity = "Rare", MaxRarity = "Legendary" },
	{ Area = "Ruins", Position = Vector3.new(230, 60, -140), MinRarity = "Epic", MaxRarity = "Mythic" },
	-- Shipwreck Coast
	{ Area = "Coast", Position = Vector3.new(-270, 10, 50), MinRarity = "Common", MaxRarity = "Uncommon" },
	{ Area = "Coast", Position = Vector3.new(-280, 10, -80), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Coast", Position = Vector3.new(-310, 10, 30), MinRarity = "Common", MaxRarity = "Rare" },
	{ Area = "Coast", Position = Vector3.new(-330, 30, -10), MinRarity = "Uncommon", MaxRarity = "Legendary" },
	{ Area = "Coast", Position = Vector3.new(-350, 10, -70), MinRarity = "Rare", MaxRarity = "Epic" },
	-- The Falls (waterfall, cliff top, hidden cave)
	{ Area = "Falls", Position = Vector3.new(-58, 10, -282), MinRarity = "Epic", MaxRarity = "Legendary" },
	{ Area = "Falls", Position = Vector3.new(-12, 10, -340), MinRarity = "Epic", MaxRarity = "Secret", RayFrom = 26 },
	{ Area = "Falls", Position = Vector3.new(-40, 91, -345), MinRarity = "Epic", MaxRarity = "Mythic" },
}

-- Open areas where events (Treasure Rain, ...) take place.
WorldLayout.EventSites = {
	{ Name = "THE WILDS", Position = Vector3.new(0, 10, -60) },
	{ Name = "THE TEMPLE ROAD", Position = Vector3.new(160, 10, -30) },
	{ Name = "SHIPWRECK COAST", Position = Vector3.new(-250, 10, 10) },
	{ Name = "THE WATERFALL", Position = Vector3.new(20, 10, -240) },
}

WorldLayout.GuardianSpawns = {
	{ Type = "Wolf", Position = Vector3.new(-110, 10, -60), PatrolRadius = 45 },
	{ Type = "Wolf", Position = Vector3.new(110, 10, -190), PatrolRadius = 45 },
	{ Type = "Goblin", Position = Vector3.new(230, 10, -60), PatrolRadius = 35 },
	{ Type = "Goblin", Position = Vector3.new(-300, 10, -20), PatrolRadius = 40 },
	{ Type = "Spider", Position = Vector3.new(30, 10, -290), PatrolRadius = 25 },
}

return WorldLayout
