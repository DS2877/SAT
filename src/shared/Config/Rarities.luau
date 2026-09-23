-- Rarity presentation + ordering. Rarity is never communicated by color alone:
-- every rarity also has a label, a pip count and a glyph.
-- Colours follow the Roblox "steal" genre standard (Steal a Brainrot / Steal an Egg):
-- Common grey, Uncommon green, Rare blue, Epic purple, Legendary gold, Mythic red and
-- Secret as black text with a white outline on name tags (LabelColor / LabelStroke).

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

Rarities.Info = {
	Common = {
		Rank = 1,
		Color = Color3.fromRGB(200, 200, 200),
		Glyph = "●",
		Pips = 1,
		Glow = false,
	},
	Uncommon = {
		Rank = 2,
		Color = Color3.fromRGB(85, 230, 85),
		Glyph = "◆",
		Pips = 2,
		Glow = false,
	},
	Rare = {
		Rank = 3,
		Color = Color3.fromRGB(40, 150, 255),
		Glyph = "★",
		Pips = 3,
		Glow = true,
	},
	Epic = {
		Rank = 4,
		Color = Color3.fromRGB(175, 60, 255),
		Glyph = "✦",
		Pips = 4,
		Glow = true,
	},
	Legendary = {
		Rank = 5,
		Color = Color3.fromRGB(255, 200, 0),
		Glyph = "♛",
		Pips = 5,
		Glow = true,
	},
	Mythic = {
		Rank = 6,
		Color = Color3.fromRGB(255, 45, 45),
		Glyph = "☠",
		Pips = 6,
		Glow = true,
	},
	Secret = {
		Rank = 7,
		Color = Color3.fromRGB(255, 255, 255),
		Glyph = "✺",
		Pips = 7,
		Glow = true,
		Rainbow = true,
		LabelColor = Color3.fromRGB(0, 0, 0),
		LabelStroke = Color3.fromRGB(255, 255, 255),
	},
}

-- Name-tag text colour + outline (Secret inverts: black text, white outline).
function Rarities.LabelColors(rarity: string): (Color3, Color3)
	local info = Rarities.Info[rarity]
	if not info then
		return Color3.new(1, 1, 1), Color3.new(0, 0, 0)
	end
	return info.LabelColor or info.Color, info.LabelStroke or Color3.new(0, 0, 0)
end

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
