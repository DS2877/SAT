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
-- Island map just inside the gate, beside the avenue, facing players on their way out.
WorldLayout.MapBoard = {
	Position = Vector3.new(-25, 11, 121), -- ground (plaza top) under the board
	Facing = Vector3.new(-6, 11, 150),
	Width = 16, -- studs (16:9 like the map canvas)
	Height = 9,
	Lift = 2.2, -- board bottom above the ground
}
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

-- FROSTPEAK (north-west of the District): snowy peaks around a frozen lake.
WorldLayout.Frostpeak = {
	Center = Vector3.new(-290, 10, 250),
	Radius = 130, -- region size (Zones)
	LakeRadius = 42, -- flat frozen lake (terrain Ice) in the middle
}

-- GLOWSHROOM MARSH (north-east of the District): a glowing bog of pools and boardwalks.
WorldLayout.Marsh = {
	Center = Vector3.new(270, 10, 180),
	Radius = 125,
}

-- LAUNCH GEYSERS: step in and get flung onto a high place (client: Controllers/Pads).
-- Target = where you land. Colour = steam / glow.
WorldLayout.LaunchPads = {
	{ Name = "Cliff Geyser", Position = Vector3.new(-40, 10, -292), Target = Vector3.new(-40, 92, -332), Color = { 90, 230, 255 } },
	{ Name = "Temple Geyser", Position = Vector3.new(182, 10, -140), Target = Vector3.new(229, 51, -143), Color = { 255, 200, 80 } },
	{ Name = "Witch Geyser", Position = Vector3.new(308, 10, 165), Target = Vector3.new(330, 39.5, 144), Color = { 200, 120, 255 } },
}

WorldLayout.Volcano = {
	Center = Vector3.new(-280, 0, -360),
	BaseRadius = 150,
	Height = 190,
}

-- SETTLEMENTS (World/Settlements): lived-in places in every region, most with loot inside.
WorldLayout.Settlements = {
	Farm = Vector3.new(-100, 10, 75), -- Wilds: farmhouse, barn, windmill, field
	Watchtower = Vector3.new(60, 10, -110), -- Wilds: ranger tower (loot on top)
	Camp = Vector3.new(-60, 10, -200), -- Wilds: explorers' campsite
	Village = Vector3.new(-385, 10, 90), -- Coast: fishing village + pier
	StiltVillage = Vector3.new(318, 18, 236), -- Marsh: huts on stilts (floor height 18)
	Chapel = Vector3.new(240, 10, 95), -- Marsh: drowned chapel ruin
	Aqueduct = Vector3.new(318, 10, -75), -- Ruins: broken aqueduct (walkable deck on top)
	Obelisks = Vector3.new(165, 10, -90), -- Ruins: obelisk circle
	Trapper = Vector3.new(-240, 10, 280), -- Frost: trapper's cabin
	Outpost = Vector3.new(-320, 10, 185), -- Frost: mining outpost
	Hermit = Vector3.new(-70, 90, -350), -- Falls: hermit's hut on the cliff top
}
WorldLayout.AqueductDeck = 16 -- deck height above the ground
WorldLayout.WatchtowerDeck = 22

-- Treasure spawn points. WHAT spawns follows the region's danger (GameConfig.Treasure
-- RarityByDanger; Mythic+ can appear anywhere). Optional MinRarity/MaxRarity clamp a point:
-- the starter spots by the gate only ever hold easy loot. RayFrom: raycast start height, for
-- loot inside a building (from under its roof) or on top of something.
local S = WorldLayout.Settlements
WorldLayout.TreasureSpawns = {
	-- THE WILDS: starter loot by the District gate first (refills during the day too)
	{ Area = "Wilds", Position = Vector3.new(38, 10, 88), MaxRarity = "Common" },
	{ Area = "Wilds", Position = Vector3.new(-45, 10, 70), MaxRarity = "Common" },
	{ Area = "Wilds", Position = Vector3.new(70, 10, 20), MaxRarity = "Uncommon" },
	{ Area = "Wilds", Position = Vector3.new(-90, 10, 10), MaxRarity = "Uncommon" },
	{ Area = "Wilds", Position = Vector3.new(-150, 10, -40) },
	{ Area = "Wilds", Position = Vector3.new(130, 10, -60) },
	{ Area = "Wilds", Position = Vector3.new(-40, 10, -110) },
	{ Area = "Wilds", Position = Vector3.new(60, 10, -170) },
	{ Area = "Wilds", Position = Vector3.new(-170, 10, -190) },
	{ Area = "Wilds", Position = Vector3.new(150, 10, -250) },
	{ Area = "Wilds", Position = Vector3.new(-20, 10, -40) },
	{ Area = "Wilds", Position = Vector3.new(100, 10, 60) },
	{ Area = "Wilds", Position = Vector3.new(-60, 10, 20) },
	{ Area = "Wilds", Position = Vector3.new(-130, 10, -20) },
	{ Area = "Wilds", Position = S.Farm + Vector3.new(16, 0, -10), RayFrom = 20 }, -- in the barn
	{ Area = "Wilds", Position = S.Farm + Vector3.new(8, 0, 22) }, -- by the crop field
	{ Area = "Wilds", Position = S.Watchtower + Vector3.new(0, 22, 0), RayFrom = 36 }, -- on top
	{ Area = "Wilds", Position = S.Camp + Vector3.new(5, 0, 5) },
	-- SHIPWRECK COAST
	{ Area = "Coast", Position = Vector3.new(-270, 10, 50) },
	{ Area = "Coast", Position = Vector3.new(-280, 10, -80) },
	{ Area = "Coast", Position = Vector3.new(-310, 10, 30) },
	{ Area = "Coast", Position = Vector3.new(-330, 30, -10) },
	{ Area = "Coast", Position = Vector3.new(-350, 10, -70) },
	{ Area = "Coast", Position = Vector3.new(-215, 10, 30) },
	{ Area = "Coast", Position = Vector3.new(-240, 10, -120) },
	{ Area = "Coast", Position = S.Village + Vector3.new(-11, 0, -16), RayFrom = 16 }, -- in a hut
	{ Area = "Coast", Position = Vector3.new(S.Village.X - 90, 11, S.Village.Z - 2), RayFrom = 15 }, -- pier end
	-- GLOWSHROOM MARSH
	{ Area = "Marsh", Position = Vector3.new(220, 10, 130) },
	{ Area = "Marsh", Position = Vector3.new(300, 10, 120) },
	{ Area = "Marsh", Position = Vector3.new(250, 10, 215) },
	{ Area = "Marsh", Position = Vector3.new(320, 10, 200) },
	{ Area = "Marsh", Position = Vector3.new(290, 10, 250) },
	{ Area = "Marsh", Position = Vector3.new(195, 10, 170) },
	{ Area = "Marsh", Position = S.StiltVillage + Vector3.new(-9, 0, -8), RayFrom = S.StiltVillage.Y + 6 }, -- stilt hut
	{ Area = "Marsh", Position = Vector3.new(241.5, 10, 101) }, -- drowned chapel nave
	-- ANCIENT RUINS
	{ Area = "Ruins", Position = Vector3.new(200, 10, -30) },
	{ Area = "Ruins", Position = Vector3.new(262, 10, -30) },
	{ Area = "Ruins", Position = Vector3.new(170, 10, -150) },
	{ Area = "Ruins", Position = Vector3.new(292, 10, -150) },
	{ Area = "Ruins", Position = Vector3.new(230, 10, -205) },
	{ Area = "Ruins", Position = Vector3.new(230, 60, -140) }, -- temple top
	{ Area = "Ruins", Position = Vector3.new(300, 10, -230) },
	{ Area = "Ruins", Position = S.Aqueduct + Vector3.new(0, 16, 0), RayFrom = 32 }, -- aqueduct deck
	{ Area = "Ruins", Position = S.Obelisks }, -- rune altar
	-- FROSTPEAK
	{ Area = "Frost", Position = Vector3.new(-250, 10, 190) },
	{ Area = "Frost", Position = Vector3.new(-300, 10, 205) },
	{ Area = "Frost", Position = Vector3.new(-290, 10, 250) }, -- frozen lake
	{ Area = "Frost", Position = Vector3.new(-240, 10, 305) },
	{ Area = "Frost", Position = Vector3.new(-345, 10, 300) },
	{ Area = "Frost", Position = S.Trapper, RayFrom = 16 }, -- inside the cabin
	{ Area = "Frost", Position = S.Outpost + Vector3.new(10, 0, 4) }, -- by the ore carts
	-- THE FALLS (waterfall, cliff top, hidden cave)
	{ Area = "Falls", Position = Vector3.new(-58, 10, -282) },
	{ Area = "Falls", Position = Vector3.new(-12, 10, -340), RayFrom = 26 }, -- behind the falls
	{ Area = "Falls", Position = Vector3.new(-40, 91, -345) }, -- cliff top
	{ Area = "Falls", Position = Vector3.new(60, 10, -270) },
	{ Area = "Falls", Position = Vector3.new(-120, 10, -270) },
	{ Area = "Falls", Position = Vector3.new(150, 10, -290) },
	{ Area = "Falls", Position = S.Hermit, RayFrom = 96 }, -- inside the hermit's hut
}

-- Open areas where events (Treasure Rain, ...) take place.
-- One site per region: events always hit ONE region (Area matches treasure SpawnArea).
WorldLayout.EventSites = {
	{ Area = "Wilds", Name = "THE WILDS", Position = Vector3.new(0, 10, -60) },
	{ Area = "Ruins", Name = "THE ANCIENT RUINS", Position = Vector3.new(160, 10, -30) },
	{ Area = "Coast", Name = "SHIPWRECK COAST", Position = Vector3.new(-250, 10, 10) },
	{ Area = "Falls", Name = "THE FALLS", Position = Vector3.new(20, 10, -240) },
	{ Area = "Frost", Name = "FROSTPEAK", Position = Vector3.new(-280, 10, 215) },
	{ Area = "Marsh", Name = "GLOWSHROOM MARSH", Position = Vector3.new(265, 10, 160) },
}

WorldLayout.GuardianSpawns = {
	{ Type = "Wolf", Position = Vector3.new(-110, 10, -60), PatrolRadius = 45 },
	{ Type = "Wolf", Position = Vector3.new(60, 10, -150), PatrolRadius = 45 },
	-- Shipwreck Coast: a goblin raiding party
	{ Type = "Goblin", Position = Vector3.new(-300, 10, -20), PatrolRadius = 40 },
	{ Type = "Goblin", Position = Vector3.new(-290, 10, 50), PatrolRadius = 30 },
	-- Ancient Ruins: a goblin at the courtyard, the Stone Golem guarding the temple's back
	{ Type = "Goblin", Position = Vector3.new(230, 10, -60), PatrolRadius = 35 },
	{ Type = "Golem", Position = Vector3.new(230, 10, -200), PatrolRadius = 28 },
	-- Frostpeak: ice golems guard the lake
	{ Type = "IceGolem", Position = Vector3.new(-290, 10, 285), PatrolRadius = 30 },
	{ Type = "IceGolem", Position = Vector3.new(-250, 10, 215), PatrolRadius = 26 },
	-- Glowshroom Marsh: bog spiders lurk between the pools
	{ Type = "BogSpider", Position = Vector3.new(275, 10, 200), PatrolRadius = 28 },
	{ Type = "BogSpider", Position = Vector3.new(235, 10, 150), PatrolRadius = 24 },
	-- The Falls: the spiders' nest
	{ Type = "Spider", Position = Vector3.new(30, 10, -290), PatrolRadius = 25 },
	{ Type = "Spider", Position = Vector3.new(-60, 10, -275), PatrolRadius = 22 },
}

return WorldLayout
