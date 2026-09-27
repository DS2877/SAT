-- VAULT SKINS: how your vault looks (Services/VaultService paints it, World/VaultSkinDecor adds
-- each skin's showpieces, Menus/VaultSkins sells and equips them). Cosmetic ONLY: a skin never
-- changes what the vault earns (Config/Monetization: we never sell power).
--
-- Three ways to get one, so everybody always has the next one to chase:
--   * NET WORTH - your best-ever net worth (cash + uncollected + what your vault would sell
--     for; Stats.PeakNetWorth, never goes down - spending or Ascending never takes one away)
--   * ASCENSION - one per Deep South region you've opened up
--   * ROBUX     - a game pass each (Monetization.SkinPasses). DIAMOND ROYALE is the flex:
--     buy-only, pricey, and it tells the whole server.
--
-- Palette roles (every skin sets all of them; tests check):
--   Floor / Wall / Trim / Glow / Carpet / Plaque / SignText / Pillar / Plinth / Stair / StairAlt
--   / Glass / Screen  -> { r, g, b }
--   FloorMat / WallMat / TrimMat / CarpetMat / PillarMat / StairMat -> Enum.Material name
--   Reflect (optional) -> trim reflectance, CarpetNeon (optional) -> the carpet glows
-- Decor = the showpiece builder in World/VaultSkinDecor (one per skin).

local VaultSkins = {}

export type Unlock = { Kind: string, Value: number?, Pass: string? }

VaultSkins.Default = "classic"

VaultSkins.List = {
	-- FREE -----------------------------------------------------------------------------------
	{
		Id = "classic",
		Name = "Classic Marble",
		Icon = "🏛",
		Tagline = "Cream marble and gold. Where every heist begins.",
		Unlock = { Kind = "Free" },
		Decor = "classic",
		Palette = {
			Floor = { 62, 52, 88 }, FloorMat = "Marble",
			Wall = { 245, 235, 210 }, WallMat = "Marble",
			Trim = { 255, 196, 50 }, TrimMat = "Metal",
			Glow = { 255, 196, 50 },
			Carpet = { 180, 30, 50 }, CarpetMat = "Fabric",
			Plaque = { 45, 36, 80 }, SignText = { 255, 196, 50 },
			Pillar = { 235, 228, 210 }, PillarMat = "Marble",
			Plinth = { 70, 60, 95 },
			Stair = { 235, 228, 210 }, StairAlt = { 222, 214, 196 }, StairMat = "Marble",
			Glass = { 200, 235, 255 },
			Screen = { 120, 220, 255 },
		},
	},

	-- EARNED BY NET WORTH ----------------------------------------------------------------------
	{
		Id = "pharaoh",
		Name = "Pharaoh's Tomb",
		Icon = "🏺",
		Tagline = "Sandstone, lapis and gold. Obelisks, torches and the winged sun.",
		Unlock = { Kind = "NetWorth", Value = 250000 },
		Decor = "pharaoh",
		Palette = {
			Floor = { 196, 160, 104 }, FloorMat = "Sandstone",
			Wall = { 226, 196, 140 }, WallMat = "Sandstone",
			Trim = { 232, 180, 60 }, TrimMat = "Metal",
			Glow = { 60, 220, 210 },
			Carpet = { 30, 60, 150 }, CarpetMat = "Fabric",
			Plaque = { 30, 50, 110 }, SignText = { 255, 214, 110 },
			Pillar = { 222, 190, 132 }, PillarMat = "Sandstone",
			Plinth = { 40, 70, 150 },
			Stair = { 214, 180, 124 }, StairAlt = { 200, 166, 110 }, StairMat = "Sandstone",
			Glass = { 120, 230, 220 },
			Screen = { 60, 220, 210 },
		},
	},
	{
		Id = "jungle",
		Name = "Lost Temple",
		Icon = "🌿",
		Tagline = "Mossy stone swallowed by the jungle. Stone idols with glowing eyes.",
		Unlock = { Kind = "NetWorth", Value = 5000000 },
		Decor = "jungle",
		Palette = {
			Floor = { 88, 98, 78 }, FloorMat = "Cobblestone",
			Wall = { 118, 128, 100 }, WallMat = "Slate",
			Trim = { 96, 150, 70 }, TrimMat = "Grass",
			Glow = { 150, 255, 90 },
			Carpet = { 70, 110, 50 }, CarpetMat = "LeafyGrass",
			Plaque = { 50, 62, 40 }, SignText = { 190, 255, 140 },
			Pillar = { 130, 138, 110 }, PillarMat = "Slate",
			Plinth = { 76, 86, 64 },
			Stair = { 124, 132, 106 }, StairAlt = { 110, 118, 94 }, StairMat = "Slate",
			Glass = { 170, 230, 150 },
			Screen = { 150, 255, 90 },
		},
	},
	{
		Id = "frost",
		Name = "Frost Palace",
		Icon = "❄",
		Tagline = "A palace carved from ice. Spires, icicles and its own snowfall.",
		Unlock = { Kind = "NetWorth", Value = 100000000 },
		Decor = "frost",
		Palette = {
			Floor = { 200, 228, 245 }, FloorMat = "Glacier",
			Wall = { 170, 215, 245 }, WallMat = "Ice",
			Trim = { 225, 240, 255 }, TrimMat = "Foil", Reflect = 0.25,
			Glow = { 120, 230, 255 },
			Carpet = { 245, 250, 255 }, CarpetMat = "Snow",
			Plaque = { 40, 80, 130 }, SignText = { 210, 245, 255 },
			Pillar = { 190, 225, 250 }, PillarMat = "Ice",
			Plinth = { 90, 150, 210 },
			Stair = { 215, 235, 250 }, StairAlt = { 195, 222, 245 }, StairMat = "Glacier",
			Glass = { 190, 240, 255 },
			Screen = { 120, 230, 255 },
		},
	},
	{
		Id = "royal",
		Name = "Golden Palace",
		Icon = "👑",
		Tagline = "Solid gold walls, black marble, a crown over the gate. For billionaires.",
		Unlock = { Kind = "NetWorth", Value = 2000000000 },
		Decor = "royal",
		Palette = {
			Floor = { 24, 20, 26 }, FloorMat = "Marble",
			Wall = { 250, 205, 90 }, WallMat = "Foil",
			Trim = { 255, 235, 160 }, TrimMat = "Foil", Reflect = 0.3,
			Glow = { 255, 240, 190 },
			Carpet = { 110, 30, 140 }, CarpetMat = "Fabric",
			Plaque = { 70, 20, 90 }, SignText = { 255, 225, 120 },
			Pillar = { 245, 200, 80 }, PillarMat = "Foil",
			Plinth = { 30, 24, 30 },
			Stair = { 36, 30, 36 }, StairAlt = { 28, 24, 30 }, StairMat = "Marble",
			Glass = { 255, 230, 150 },
			Screen = { 255, 220, 120 },
		},
	},

	-- EARNED BY ASCENSION ----------------------------------------------------------------------
	{
		Id = "ember",
		Name = "Emberfall Forge",
		Icon = "🌋",
		Tagline = "Basalt and copper, a river of lava down the aisle, embers in the air.",
		Unlock = { Kind = "Ascension", Value = 1 },
		Decor = "ember",
		Palette = {
			Floor = { 40, 34, 34 }, FloorMat = "Basalt",
			Wall = { 58, 50, 50 }, WallMat = "Basalt",
			Trim = { 190, 100, 50 }, TrimMat = "CorrodedMetal",
			Glow = { 255, 110, 30 },
			Carpet = { 255, 110, 25 }, CarpetMat = "Neon", CarpetNeon = true,
			Plaque = { 30, 22, 22 }, SignText = { 255, 150, 60 },
			Pillar = { 70, 60, 58 }, PillarMat = "Basalt",
			Plinth = { 50, 40, 38 },
			Stair = { 62, 54, 52 }, StairAlt = { 52, 46, 44 }, StairMat = "Basalt",
			Glass = { 255, 150, 90 },
			Screen = { 255, 120, 40 },
		},
	},
	{
		Id = "rime",
		Name = "Rimeheart Citadel",
		Icon = "🧊",
		Tagline = "Deep glacier blue, a frozen heart over the gate and the aurora above.",
		Unlock = { Kind = "Ascension", Value = 2 },
		Decor = "rime",
		Palette = {
			Floor = { 120, 170, 210 }, FloorMat = "Glacier",
			Wall = { 80, 140, 200 }, WallMat = "Glacier",
			Trim = { 235, 248, 255 }, TrimMat = "Snow",
			Glow = { 110, 255, 200 },
			Carpet = { 40, 70, 120 }, CarpetMat = "Fabric",
			Plaque = { 20, 45, 80 }, SignText = { 160, 255, 220 },
			Pillar = { 150, 200, 235 }, PillarMat = "Ice",
			Plinth = { 40, 80, 130 },
			Stair = { 130, 180, 220 }, StairAlt = { 115, 165, 208 }, StairMat = "Glacier",
			Glass = { 160, 255, 230 },
			Screen = { 110, 255, 200 },
		},
	},
	{
		Id = "starfall",
		Name = "Starfall Sanctum",
		Icon = "🌌",
		Tagline = "Violet stone under a sky of its own. Crystals orbit, a planet floats.",
		Unlock = { Kind = "Ascension", Value = 3 },
		Decor = "starfall",
		Palette = {
			Floor = { 24, 20, 48 }, FloorMat = "Slate",
			Wall = { 84, 64, 130 }, WallMat = "Slate",
			Trim = { 255, 210, 110 }, TrimMat = "Metal",
			Glow = { 190, 130, 255 },
			Carpet = { 40, 30, 90 }, CarpetMat = "Fabric",
			Plaque = { 30, 20, 60 }, SignText = { 220, 180, 255 },
			Pillar = { 100, 80, 150 }, PillarMat = "Slate",
			Plinth = { 40, 30, 80 },
			Stair = { 90, 72, 140 }, StairAlt = { 76, 60, 124 }, StairMat = "Slate",
			Glass = { 200, 170, 255 },
			Screen = { 130, 220, 255 },
		},
	},

	-- ROBUX ------------------------------------------------------------------------------------
	{
		Id = "candy",
		Name = "Candy Kingdom",
		Icon = "🍭",
		Tagline = "Pastel walls, giant lollipops, candy-cane gates and a sprinkle storm.",
		Unlock = { Kind = "Pass", Pass = "SkinCandy" },
		Decor = "candy",
		Palette = {
			Floor = { 170, 240, 215 }, FloorMat = "SmoothPlastic",
			Wall = { 255, 180, 215 }, WallMat = "SmoothPlastic",
			Trim = { 255, 255, 255 }, TrimMat = "SmoothPlastic",
			Glow = { 255, 90, 180 },
			Carpet = { 110, 60, 40 }, CarpetMat = "SmoothPlastic",
			Plaque = { 255, 120, 190 }, SignText = { 255, 255, 255 },
			Pillar = { 255, 230, 240 }, PillarMat = "SmoothPlastic",
			Plinth = { 150, 220, 255 },
			Stair = { 255, 200, 225 }, StairAlt = { 200, 245, 225 }, StairMat = "SmoothPlastic",
			Glass = { 255, 200, 235 },
			Screen = { 255, 90, 180 },
		},
	},
	{
		Id = "neon",
		Name = "Neon Cyber",
		Icon = "⚡",
		Tagline = "Black glass and diamond plate, laser gates, a holo ring over the door.",
		Unlock = { Kind = "Pass", Pass = "SkinNeon" },
		Decor = "neon",
		Palette = {
			Floor = { 14, 14, 22 }, FloorMat = "Glass",
			Wall = { 30, 32, 44 }, WallMat = "DiamondPlate",
			Trim = { 0, 240, 255 }, TrimMat = "Neon",
			Glow = { 255, 40, 200 },
			Carpet = { 255, 40, 200 }, CarpetMat = "Neon", CarpetNeon = true,
			Plaque = { 10, 10, 18 }, SignText = { 0, 240, 255 },
			Pillar = { 36, 38, 52 }, PillarMat = "DiamondPlate",
			Plinth = { 18, 18, 28 },
			Stair = { 34, 36, 48 }, StairAlt = { 26, 28, 40 }, StairMat = "DiamondPlate",
			Glass = { 0, 240, 255 },
			Screen = { 255, 40, 200 },
		},
	},
	{
		Id = "crypt",
		Name = "Haunted Crypt",
		Icon = "👻",
		Tagline = "Tombstones, iron spikes, ghost lights and a fog that never lifts.",
		Unlock = { Kind = "Pass", Pass = "SkinCrypt" },
		Decor = "crypt",
		Palette = {
			Floor = { 50, 52, 50 }, FloorMat = "Slate",
			Wall = { 96, 100, 94 }, WallMat = "Cobblestone",
			Trim = { 70, 62, 58 }, TrimMat = "CorrodedMetal",
			Glow = { 120, 255, 150 },
			Carpet = { 60, 30, 70 }, CarpetMat = "Fabric",
			Plaque = { 30, 30, 30 }, SignText = { 150, 255, 170 },
			Pillar = { 110, 112, 104 }, PillarMat = "Cobblestone",
			Plinth = { 40, 40, 44 },
			Stair = { 88, 90, 86 }, StairAlt = { 76, 78, 74 }, StairMat = "Slate",
			Glass = { 150, 255, 170 },
			Screen = { 120, 255, 150 },
		},
	},
	{
		Id = "pirate",
		Name = "Pirate's Cove",
		Icon = "🏴‍☠️",
		Tagline = "Ship's timbers and brass, cannons at the gate, a chest spilling gold.",
		Unlock = { Kind = "Pass", Pass = "SkinPirate" },
		Decor = "pirate",
		Palette = {
			Floor = { 120, 82, 50 }, FloorMat = "WoodPlanks",
			Wall = { 104, 70, 44 }, WallMat = "WoodPlanks",
			Trim = { 210, 165, 70 }, TrimMat = "Metal",
			Glow = { 255, 170, 70 },
			Carpet = { 160, 30, 30 }, CarpetMat = "Fabric",
			Plaque = { 30, 22, 16 }, SignText = { 255, 215, 120 },
			Pillar = { 96, 64, 40 }, PillarMat = "Wood",
			Plinth = { 70, 46, 30 },
			Stair = { 128, 88, 54 }, StairAlt = { 112, 76, 46 }, StairMat = "WoodPlanks",
			Glass = { 255, 210, 140 },
			Screen = { 255, 170, 70 },
		},
	},
	{
		Id = "dragon",
		Name = "Dragon's Hoard",
		Icon = "🐉",
		Tagline = "Obsidian and gold. A dragon's head over the gate, breathing fire.",
		Unlock = { Kind = "Pass", Pass = "SkinDragon" },
		Decor = "dragon",
		Palette = {
			Floor = { 70, 20, 24 }, FloorMat = "Marble",
			Wall = { 26, 18, 22 }, WallMat = "Glass",
			Trim = { 255, 190, 60 }, TrimMat = "Foil", Reflect = 0.2,
			Glow = { 255, 70, 30 },
			Carpet = { 150, 16, 24 }, CarpetMat = "Fabric",
			Plaque = { 20, 12, 14 }, SignText = { 255, 170, 60 },
			Pillar = { 34, 24, 28 }, PillarMat = "Glass",
			Plinth = { 90, 24, 30 },
			Stair = { 80, 24, 28 }, StairAlt = { 64, 18, 22 }, StairMat = "Marble",
			Glass = { 255, 140, 80 },
			Screen = { 255, 70, 30 },
		},
	},
	{
		-- THE FLEX. Buy-only, expensive, unmistakable from across the District.
		Id = "diamond",
		Name = "Diamond Royale",
		Icon = "💎",
		Tagline = "Walls of diamond, a giant floating gem, sky beams - and the whole server hears about it.",
		Unlock = { Kind = "Pass", Pass = "SkinDiamond" },
		Decor = "diamond",
		Flex = true,
		Palette = {
			Floor = { 235, 242, 250 }, FloorMat = "Marble",
			Wall = { 200, 240, 255 }, WallMat = "Glass",
			Trim = { 255, 255, 255 }, TrimMat = "Neon",
			Glow = { 170, 235, 255 },
			Carpet = { 30, 50, 150 }, CarpetMat = "Fabric",
			Plaque = { 20, 30, 70 }, SignText = { 200, 245, 255 },
			Pillar = { 215, 245, 255 }, PillarMat = "Glass",
			Plinth = { 225, 235, 250 },
			Stair = { 240, 246, 252 }, StairAlt = { 225, 234, 245 }, StairMat = "Marble",
			Glass = { 210, 245, 255 },
			Screen = { 170, 235, 255 },
		},
	},
}

VaultSkins.ById = {}
for order, skin in VaultSkins.List do
	skin.Order = order
	VaultSkins.ById[skin.Id] = skin
end

function VaultSkins.Get(id: string?)
	return VaultSkins.ById[id or ""] or VaultSkins.ById[VaultSkins.Default]
end

return VaultSkins
