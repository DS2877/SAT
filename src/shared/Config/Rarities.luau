-- Rarity presentation + ordering. Rarity is never communicated by color alone:
-- every rarity also has a label, a pip count and a glyph.
-- Official STEAL THE TREASURE palette (Roblox "steal" genre standard):
--   Common #9E9E9E grey, Uncommon #4CAF50 green, Rare #2196F3 blue, Epic #9C27B0 purple,
--   Legendary #FFC107 gold, Mythic #F44336 red, Divine #00E5FF cyan,
--   Secret #111111 black (black/white animated gradient), OG #FFD700 gold (premium shimmer).
-- `Color` is the colour used for glows, strokes and text on dark UI. Secret's swatch is black,
-- which would vanish there, so its `Color` is white and the black lives in `Swatch` + `Gradient`.
-- `Gradient` rarities get an animated gradient on their name (TreasureLabel.StyleRarity).

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Secret", "OG" }

local function hex(value: string): Color3
	return Color3.fromHex(value)
end

Rarities.Info = {
	Common = {
		Rank = 1,
		Color = hex("#9E9E9E"),
		Glyph = "●",
		Pips = 1,
		Glow = false,
	},
	Uncommon = {
		Rank = 2,
		Color = hex("#4CAF50"),
		Glyph = "◆",
		Pips = 2,
		Glow = false,
	},
	Rare = {
		Rank = 3,
		Color = hex("#2196F3"),
		Glyph = "★",
		Pips = 3,
		Glow = true,
	},
	Epic = {
		Rank = 4,
		Color = hex("#9C27B0"),
		Glyph = "✦",
		Pips = 4,
		Glow = true,
	},
	Legendary = {
		Rank = 5,
		Color = hex("#FFC107"),
		Glyph = "♛",
		Pips = 5,
		Glow = true,
	},
	Mythic = {
		Rank = 6,
		Color = hex("#F44336"),
		Glyph = "☠",
		Pips = 6,
		Glow = true,
	},
	Divine = {
		Rank = 7,
		Color = hex("#00E5FF"),
		Glyph = "✧",
		Pips = 7,
		Glow = true,
	},
	Secret = {
		Rank = 8,
		Color = Color3.fromRGB(255, 255, 255),
		Swatch = hex("#111111"),
		Glyph = "✺",
		Pips = 8,
		Glow = true,
		-- Black / white, sliding across the text (the outline runs the inverse so it always reads).
		Gradient = { hex("#111111"), Color3.fromRGB(255, 255, 255), hex("#111111") },
		StrokeGradient = { Color3.fromRGB(255, 255, 255), hex("#111111"), Color3.fromRGB(255, 255, 255) },
		LabelColor = Color3.fromRGB(255, 255, 255),
		LabelStroke = Color3.fromRGB(255, 255, 255),
		Aura = { hex("#111111"), Color3.fromRGB(255, 255, 255) },
	},
	OG = {
		Rank = 9,
		Color = hex("#FFD700"),
		Glyph = "♚",
		Pips = 9,
		Glow = true,
		-- Premium shimmer: a bright highlight sweeping over gold.
		Gradient = { hex("#FFD700"), Color3.fromRGB(255, 250, 215), hex("#FFD700") },
		LabelStroke = Color3.fromRGB(90, 55, 0),
		Aura = { hex("#FFD700"), Color3.fromRGB(255, 250, 215) },
	},
}

-- Name-tag text colour + outline.
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
