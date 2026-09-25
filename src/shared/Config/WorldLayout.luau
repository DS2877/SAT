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
	Width = 16, -- studs (16:9 like the 960 x 540 map canvas)
	Height = 9,
	Lift = 2.2, -- board bottom above the ground
}
-- Waystones: fast travel between the District and the Deep South. A circle of stones across
-- the avenue from the map board, and one return stone at each region's arrival point.
WorldLayout.Waystones = {
	Circle = Vector3.new(42, 11, 126), -- dais centre (plaza top); stones face the avenue (-X)
	Radius = 10,
	Regions = {
		{ Area = "Ember", Name = "ASHEN CAMP", Stone = Vector3.new(10, 10, -540) },
		{ Area = "Rime", Name = "GLACIER GORGE", Stone = Vector3.new(14, 40, -862) },
		{ Area = "Star", Name = "LANDING ISLE", Stone = Vector3.new(-12, 60, -1076) },
	},
}
-- Leaderboards: arc behind the fountain, facing the spawn
WorldLayout.Leaderboards = { Radius = 40, SpreadDegrees = 100 }
WorldLayout.AscensionAltar = Vector3.new(58, 10, 160)

-- Exits are big, easy-to-hit circles (radius 17 safe / 14-15 dangerous / 13 secret).
WorldLayout.ExtractionZones = {
	{
		Id = "expedition_camp",
		Name = "Expedition Camp",
		Category = "Safe",
		Position = Vector3.new(0, 10, 55),
		Radius = 17,
	},
	{
		Id = "temple_courtyard",
		Name = "Temple Courtyard",
		Category = "Dangerous",
		Position = Vector3.new(230, 10, -45),
		Radius = 15,
	},
	{
		Id = "hidden_falls",
		Name = "Hidden Falls Cave",
		Category = "Secret",
		Position = Vector3.new(0, 10, -330),
		Radius = 13,
		RayFrom = 26,
	},
	-- The Deep South: bank your loot without the long walk home.
	{
		Id = "ashen_camp",
		Name = "Ashen Camp",
		Category = "Safe",
		Position = Vector3.new(22, 10, -565),
		Radius = 17,
	},
	{
		Id = "lava_outpost",
		Name = "Lava Outpost",
		Category = "Dangerous",
		Position = Vector3.new(140, 12, -740),
		Radius = 14, -- fits inside the outpost walls
	},
	{
		Id = "glacier_station",
		Name = "Glacier Station",
		Category = "Dangerous",
		Position = Vector3.new(120, 40, -915),
		Radius = 15,
	},
	{
		Id = "skyport",
		Name = "Skyport",
		Category = "Secret",
		Position = Vector3.new(120, 55, -1190),
		Radius = 13,
		RayFrom = 80,
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
	{ Name = "Cliff Geyser", Position = Vector3.new(-45, 10, -266), Target = Vector3.new(-42, 92, -334), Color = { 90, 230, 255 } },
	{ Name = "Temple Geyser", Position = Vector3.new(182, 10, -140), Target = Vector3.new(229, 51, -143), Color = { 255, 200, 80 } },
	{ Name = "Witch Geyser", Position = Vector3.new(308, 10, 165), Target = Vector3.new(330, 39.5, 144), Color = { 200, 120, 255 } },
	-- The Deep South (World/DeepSouth).
	{ Name = "Cinder Vent", Position = Vector3.new(-15, 22, -665), Target = Vector3.new(-76, 111, -650), Color = { 255, 120, 40 } },
	{ Name = "Starfall Launch", Position = Vector3.new(0, 40, -1036), Target = Vector3.new(0, 61, -1085), Color = { 190, 140, 255 }, RequiredAscension = 3 },
	{ Name = "Moonstone Updraft", Position = Vector3.new(16, 60, -1098), Target = Vector3.new(66, 81, -1118), Color = { 150, 220, 255 } },
	{ Name = "Starwell Updraft", Position = Vector3.new(-74, 72, -1132), Target = Vector3.new(-62, 96, -1172), Color = { 255, 230, 160 } },
	{ Name = "Observatory Updraft", Position = Vector3.new(-48, 95, -1190), Target = Vector3.new(2, 121, -1212), Color = { 150, 220, 255 } },
	{ Name = "???", Position = Vector3.new(-71, 95, -1191), Target = Vector3.new(-120, 111, -1238), Color = { 190, 90, 255 } },
}

WorldLayout.Volcano = {
	Center = Vector3.new(-280, 0, -360),
	BaseRadius = 150,
	Height = 190,
}

-- THE DEEP SOUTH (World/DeepSouth, docs/EXPANSION_PLAN.md): a long peninsula beyond the
-- Waterfall Mountain, reached over the Ashen Pass. Region borders run across it (z).
WorldLayout.DeepSouth = {
	EmberStart = -505, -- Emberfall: lava lowlands (Ascension 1)
	RimeStart = -790, -- Rimeheart: the glacier (Ascension 2)
	StarStart = -1045, -- Starfall Isles: floating islands beyond the glacier tip (Ascension 3)
	PlateauHeight = 40, -- Rimeheart's ice plateau
	StarShore = Vector3.new(0, 42, -1012), -- where you wash up after falling from the isles
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
	{ Area = "Falls", Position = Vector3.new(-72, 10, -262) },
	{ Area = "Falls", Position = Vector3.new(-12, 10, -340), RayFrom = 26 }, -- behind the falls
	{ Area = "Falls", Position = Vector3.new(-40, 91, -345) }, -- cliff top
	{ Area = "Falls", Position = Vector3.new(60, 10, -270) },
	{ Area = "Falls", Position = Vector3.new(-120, 10, -270) },
	{ Area = "Falls", Position = Vector3.new(170, 10, -266) },
	{ Area = "Falls", Position = S.Hermit, RayFrom = 96 }, -- inside the hermit's hut
	-- EMBERFALL
	{ Area = "Ember", Position = Vector3.new(70, 12, -555) },
	{ Area = "Ember", Position = Vector3.new(115, 12, -560) }, -- the obsidian temple's altar
	{ Area = "Ember", Position = Vector3.new(-40, 12, -545) },
	{ Area = "Ember", Position = Vector3.new(160, 12, -600) },
	{ Area = "Ember", Position = Vector3.new(95, 12, -655) },
	{ Area = "Ember", Position = Vector3.new(20, 12, -700) },
	{ Area = "Ember", Position = Vector3.new(128, 12, -752) }, -- inside the Lava Outpost
	{ Area = "Ember", Position = Vector3.new(-150, 12, -730) }, -- the mining camp
	{ Area = "Ember", Position = Vector3.new(-195, 12, -625) },
	{ Area = "Ember", Position = Vector3.new(60, 12, -735) },
	{ Area = "Ember", Position = Vector3.new(-40, 12, -778) }, -- the bathhouse
	{ Area = "Ember", Position = Vector3.new(160, 12, -780) }, -- the Steamfields
	-- RIMEHEART
	{ Area = "Rime", Position = Vector3.new(-100, 40, -832) },
	{ Area = "Rime", Position = Vector3.new(60, 40, -830) },
	{ Area = "Rime", Position = Vector3.new(160, 40, -860) },
	{ Area = "Rime", Position = Vector3.new(-150, 40, -900) },
	{ Area = "Rime", Position = Vector3.new(-40, 40, -905) },
	{ Area = "Rime", Position = Vector3.new(70, 40, -905) },
	{ Area = "Rime", Position = Vector3.new(138, 40, -900) }, -- Glacier Station
	{ Area = "Rime", Position = Vector3.new(-120, 40, -975) },
	{ Area = "Rime", Position = Vector3.new(40, 40, -975) },
	{ Area = "Rime", Position = Vector3.new(-60, 40, -990) }, -- the igloo village
	{ Area = "Rime", Position = Vector3.new(150, 40, -985) },
	{ Area = "Rime", Position = Vector3.new(-25, 40, -1015) }, -- the glacier tip
	-- THE STARFALL ISLES
	{ Area = "Star", Position = Vector3.new(8, 60, -1078) },
	{ Area = "Star", Position = Vector3.new(-10, 60, -1094) },
	{ Area = "Star", Position = Vector3.new(-78, 72, -1114) }, -- the Crystal Garden
	{ Area = "Star", Position = Vector3.new(78, 80, -1126) }, -- Moonstone
	{ Area = "Star", Position = Vector3.new(109, 55, -1179) }, -- the Skyport
	{ Area = "Star", Position = Vector3.new(-52, 95, -1176) }, -- the Starwell
	{ Area = "Star", Position = Vector3.new(-66, 95, -1172) },
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
	-- EMBERFALL
	{ Type = "MagmaGolem", Position = Vector3.new(100, 12, -615), PatrolRadius = 26 },
	{ Type = "MagmaGolem", Position = Vector3.new(-40, 12, -760), PatrolRadius = 26 },
	{ Type = "Salamander", Position = Vector3.new(125, 12, -710), PatrolRadius = 30 },
	{ Type = "Salamander", Position = Vector3.new(-170, 12, -700), PatrolRadius = 30 },
	{ Type = "Salamander", Position = Vector3.new(80, 12, -560), PatrolRadius = 28 },
	-- RIMEHEART
	{ Type = "IceWraith", Position = Vector3.new(-80, 40, -860), PatrolRadius = 26, RayFrom = 80 },
	{ Type = "IceWraith", Position = Vector3.new(70, 40, -915), PatrolRadius = 26, RayFrom = 80 },
	{ Type = "IceWraith", Position = Vector3.new(-90, 40, -935), PatrolRadius = 24, RayFrom = 80 },
	{ Type = "GlacialTitan", Position = Vector3.new(40, 40, -980), PatrolRadius = 24, RayFrom = 80 },
	-- THE STARFALL ISLES (short patrols: they stay on their island)
	{ Type = "StarSentinel", Position = Vector3.new(-70, 72, -1122), PatrolRadius = 7, RayFrom = 100 },
	{ Type = "VoidWraith", Position = Vector3.new(70, 80, -1120), PatrolRadius = 7, RayFrom = 110 },
	{ Type = "VoidWraith", Position = Vector3.new(-58, 95, -1184), PatrolRadius = 7, RayFrom = 130 },
}

return WorldLayout
