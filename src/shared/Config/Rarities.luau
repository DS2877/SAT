-- Rarity presentation + ordering. Rarity is never communicated by color alone:
-- every rarity also has a label, a pip count and a glyph.

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common = {
		Rank = 1,
		Color = Color3.fromRGB(196, 202, 210),
		Glyph = "●",
		Pips = 1,
		BillboardDistance = 70,
		Glow = false,
	},
	Uncommon = {
		Rank = 2,
		Color = Color3.fromRGB(96, 214, 120),
		Glyph = "◆",
		Pips = 2,
		BillboardDistance = 90,
		Glow = false,
	},
	Rare = {
		Rank = 3,
		Color = Color3.fromRGB(70, 160, 255),
		Glyph = "★",
		Pips = 3,
		BillboardDistance = 130,
		Glow = true,
	},
	Epic = {
		Rank = 4,
		Color = Color3.fromRGB(180, 96, 255),
		Glyph = "✦",
		Pips = 4,
		BillboardDistance = 180,
		Glow = true,
	},
	Legendary = {
		Rank = 5,
		Color = Color3.fromRGB(255, 184, 40),
		Glyph = "♛",
		Pips = 5,
		BillboardDistance = 260,
		Glow = true,
	},
	Mythic = {
		Rank = 6,
		Color = Color3.fromRGB(255, 70, 110),
		Glyph = "☠",
		Pips = 6,
		BillboardDistance = 320,
		Glow = true,
	},
	Secret = {
		Rank = 7,
		Color = Color3.fromRGB(255, 255, 255),
		Glyph = "✺",
		Pips = 7,
		BillboardDistance = 400,
		Glow = true,
		Rainbow = true,
	},
}

function Rarities.Rank(rarity: string): number
	local info = Rarities.Info[rarity]
	return info and info.Rank or 0
end

function Rarities.AtLeast(rarity: string, minimum: string): boolean
	return Rarities.Rank(rarity) >= Rarities.Rank(minimum)
end

function Rarities.PipString(rarity: string): string
	local info = Rarities.Info[rarity]
	if not info then
		return ""
	end
	return string.rep(info.Glyph, math.min(info.Pips, 3))
end

return Rarities
