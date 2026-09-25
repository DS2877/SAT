-- The island map, drawn from config so it never goes stale: regions, danger, what loot each
-- danger level drops, exits and their payouts, secrets YOU have found, and whether YOUR
-- strength is enough for each region. Used on the board by the gate (SurfaceGui) and full
-- screen (Menus/Map). Laid out on a fixed 900 x 405 canvas; callers scale it (UIScale):
-- the island on the left, the Deep South strip (beyond the Falls) in the middle, the legend
-- on the right.
--
-- Orientation: "up" is INTO the Wilds (-Z), the way you face when you read the board at the
-- gate, so left/right on the map match left/right in front of you.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Config.WorldLayout)
local Regions = require(Shared.Config.Regions)
local Rarities = require(Shared.Config.Rarities)

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local MapView = {}

MapView.WIDTH, MapView.HEIGHT = 900, 405

local MAP = 405 -- the square map on the left, in px
local WORLD_R = 480 -- world half-span shown (studs)
local K = MAP / (WORLD_R * 2)
local LOOT_TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local INK = Color3.fromRGB(20, 22, 34)

-- Region shapes (centre x, z, radius), mirroring Zones / TerrainGen.BIOME_CENTERS.
local SHAPES = {
	{ Area = "Coast", X = -345, Z = -10, R = 160 },
	{ Area = "Ruins", X = 230, Z = -140, R = 150 },
	{ Area = "Frost", X = -290, Z = 250, R = 130 },
	{ Area = "Marsh", X = 270, Z = 180, R = 125 },
}
-- Where each region's label card sits (world x, z).
local LABELS = {
	Wilds = { 60, -20 },
	Coast = { -330, -40 },
	Ruins = { 250, -200 },
	Frost = { -290, 240 },
	Marsh = { 230, 240 },
	Falls = { 150, -325 },
}
-- The Deep South strip: world z from Top (far end) down to Bottom (the channel), x +-HalfX.
local SOUTH = { Top = -1275, Bottom = -435, HalfX = 200, Width = 170 }
local KS = SOUTH.Width / (SOUTH.HalfX * 2)
local ON_ISLAND_Z = -470 -- anything further south is drawn on the strip, not the island
local SOUTH_BANDS = {
	{ Area = "Ember", From = -505, To = -790 },
	{ Area = "Rime", From = -790, To = -1045 },
	{ Area = "Star", From = -1045, To = SOUTH.Top },
}
-- Starfall's isles (mirrors World/DeepSouth/Star): x, z, radius, and the light bridges.
local ISLES = {
	Landing = { 0, -1085, 24 },
	Garden = { -72, -1120, 17 },
	Moonstone = { 72, -1122, 17 },
	Skyport = { 120, -1190, 19 },
	Starwell = { -60, -1180, 17 },
	Observatory = { 8, -1218, 16 },
}
local LIGHT_BRIDGES = { { "Landing", "Garden" }, { "Moonstone", "Skyport" }, { "Observatory", "Moonstone" } }
local EXIT_COLORS = { Safe = Color3.fromRGB(80, 230, 110), Dangerous = Color3.fromRGB(255, 150, 40), Secret = Color3.fromRGB(190, 110, 255) }

local function px(x: number, z: number): UDim2
	return UDim2.fromOffset((WORLD_R - x) * K, (z + WORLD_R) * K)
end

local function spx(x: number, z: number): UDim2
	return UDim2.fromOffset((SOUTH.HalfX - x) * KS, (z - SOUTH.Top) * KS)
end

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function stars(danger: number): string
	return Regions.Stars(danger)
end

local function dangerColor(danger: number): Color3
	return ({
		Color3.fromRGB(120, 230, 90),
		Color3.fromRGB(255, 220, 70),
		Color3.fromRGB(255, 140, 50),
		Color3.fromRGB(255, 70, 70),
		Color3.fromRGB(255, 50, 120),
		Color3.fromRGB(230, 80, 220),
		Color3.fromRGB(180, 110, 255),
	})[danger] or Color3.new(1, 1, 1)
end

local function text(parent: Instance, props): TextLabel
	local label = Kit.label({
		Font = props.Font or Theme.Font.Black,
		TextSize = props.TextSize or 12,
		TextColor3 = props.Color or Color3.new(1, 1, 1),
		Text = props.Text,
		RichText = true,
		TextWrapped = false,
		Size = props.Size or UDim2.fromOffset(200, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.new(),
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
		ZIndex = props.ZIndex or 5,
		Parent = parent,
	})
	if props.Outline ~= false then
		Kit.textStroke(INK, props.Outline or 1.4).Parent = label
	end
	return label
end

-- Stacked bar of what one danger level drops (share of Common..Legendary).
local function lootBar(parent: Instance, danger: number, position: UDim2, width: number)
	local row = GameConfig.Treasure.RarityByDanger[danger]
	local total = 0
	for _, rarity in LOOT_TIERS do
		total += row[rarity] or 0
	end
	local bar = Kit.new("Frame", {
		Position = position,
		Size = UDim2.fromOffset(width, 9),
		BackgroundColor3 = INK,
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = parent,
	}, { Kit.corner(UDim.new(0, 4)) })
	local x = 0
	for _, rarity in LOOT_TIERS do
		local share = (row[rarity] or 0) / total
		if share > 0 then
			-- Tiny shares still get a visible sliver: a rare Epic in the Wilds should show.
			local w = math.max(2, share * width)
			Kit.new("Frame", {
				Position = UDim2.fromOffset(x, 0),
				Size = UDim2.fromOffset(w, 9),
				BackgroundColor3 = Rarities.Info[rarity].Color,
				BorderSizePixel = 0,
				ZIndex = 6,
				Parent = bar,
			})
			x += w
		end
	end
	return bar
end

-- The two most likely rarities, e.g. "COMMON-UNCOMMON".
local function typicalLoot(danger: number): string
	local row = GameConfig.Treasure.RarityByDanger[danger]
	local sorted = table.clone(LOOT_TIERS)
	table.sort(sorted, function(a, b)
		return (row[a] or 0) > (row[b] or 0)
	end)
	local first, second = sorted[1], sorted[2]
	if Rarities.Rank(first) > Rarities.Rank(second) then
		first, second = second, first
	end
	local function colored(rarity: string): string
		return ('<font color="#%s">%s</font>'):format(Rarities.Info[rarity].Color:ToHex(), rarity:upper())
	end
	return colored(first) .. "-" .. colored(second)
end

-- A line between two canvas points (UDim2 offsets).
local function line(parent: Instance, a: UDim2, b: UDim2, thickness: number, color: Color3, transparency: number, z: number)
	local ax, ay, bx, by = a.X.Offset, a.Y.Offset, b.X.Offset, b.Y.Offset
	return Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
		Size = UDim2.fromOffset(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2), thickness),
		Rotation = math.deg(math.atan2(by - ay, bx - ax)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
end

-- A small round map marker with a glyph.
local function marker(parent: Instance, position: UDim2, color: Color3, glyph: string, size: number)
	local dot = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 8,
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.stroke(Color3.new(1, 1, 1), 2, 0).Parent = dot
	text(dot, { Text = glyph, TextSize = size * 0.66, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), XAlign = Enum.TextXAlignment.Center, ZIndex = 9, Outline = 1 })
	return dot
end

-- Builds the map into `parent` (a 900 x 405 frame). Returns { Refresh(data) }.
function MapView.Build(parent: Frame)
	local canvas = Kit.new("Frame", {
		Name = "MapCanvas",
		Size = UDim2.fromOffset(MapView.WIDTH, MapView.HEIGHT),
		BackgroundColor3 = Color3.fromRGB(22, 30, 50),
		BorderSizePixel = 0,
		Parent = parent,
	}, { Kit.corner(UDim.new(0, 14)) })

	-- LEFT: THE MAP --------------------------------------------------------------------
	local sea = Kit.new("Frame", {
		Name = "Sea",
		Size = UDim2.fromOffset(MAP, MAP),
		BackgroundColor3 = Color3.fromRGB(40, 110, 170),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = canvas,
	}, {
		Kit.corner(UDim.new(0, 14)),
		Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.fromRGB(70, 150, 210), Color3.fromRGB(30, 80, 140)) }),
	})
	-- The island clips every region shape to its coastline.
	local island = Kit.new("CanvasGroup", {
		Name = "Island",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(0, 0),
		Size = UDim2.fromOffset(455 * 2 * K, 455 * 2 * K),
		BackgroundColor3 = rgb(Regions.Info.Wilds.Color):Lerp(Color3.fromRGB(40, 90, 40), 0.35),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = sea,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	local function inIsland(x: number, z: number): UDim2
		local offset = 455 * K
		return UDim2.fromOffset((0 - x) * K + offset, z * K + offset)
	end
	-- Falls: everything beyond z = -240 (a band across the top).
	Kit.new("Frame", {
		Size = UDim2.new(1, 0, 0, (-240 + 455) * K),
		BackgroundColor3 = rgb(Regions.Info.Falls.Color):Lerp(Color3.fromRGB(10, 50, 30), 0.55),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = island,
	})
	-- Volcano (no loot): a grey blob in the south-west of the band.
	local volcano = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = inIsland(-280, -360),
		Size = UDim2.fromOffset(300 * K, 300 * K),
		BackgroundColor3 = Color3.fromRGB(70, 66, 66),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = island,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	text(volcano, { Text = "🌋", TextSize = 18, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62, 0.62), Size = UDim2.fromOffset(24, 24), XAlign = Enum.TextXAlignment.Center, Outline = false })
	for _, shape in SHAPES do
		local blob = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = inIsland(shape.X, shape.Z),
			Size = UDim2.fromOffset(shape.R * 2 * K, shape.R * 2 * K),
			BackgroundColor3 = rgb(Regions.Info[shape.Area].Color):Lerp(Color3.fromRGB(30, 30, 40), 0.25),
			BackgroundTransparency = 0.15,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = island,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.55).Parent = blob
	end
	-- District (safe) at the bottom.
	local district = WorldLayout.District.Center
	local safe = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = inIsland(district.X, district.Z),
		Size = UDim2.fromOffset(150 * 2 * K, 150 * 2 * K),
		BackgroundColor3 = Color3.fromRGB(235, 225, 200),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = island,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.stroke(Color3.fromRGB(120, 220, 255), 2, 0).Parent = safe
	text(safe, { Text = "🛡 SAFE", TextSize = 11, Color = Color3.fromRGB(40, 90, 130), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(60, 14), XAlign = Enum.TextXAlignment.Center, Outline = false })

	-- Overlay layer (not clipped): trails, markers, labels.
	local overlay = Kit.new("Frame", { Name = "Overlay", Size = UDim2.fromOffset(MAP, MAP), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas })
	-- Trails from the gate camp to each region.
	local gate = Vector3.new(0, 0, 55)
	local trailEnds = {
		Vector3.new(0, 0, -270),
		WorldLayout.Temple.Courtyard + Vector3.new(0, 0, 15),
		WorldLayout.Shipwreck.Center + Vector3.new(60, 0, 0),
		WorldLayout.Frostpeak.Center + Vector3.new(50, 0, -40),
		WorldLayout.Marsh.Center + Vector3.new(-60, 0, -40),
	}
	for _, finish in trailEnds do
		line(overlay, px(gate.X, gate.Z), px(finish.X, finish.Z), 3, Color3.fromRGB(240, 220, 170), 0.25, 5)
	end

	-- MIDDLE: THE DEEP SOUTH, beyond the Falls, each region behind an Ascension gate --------
	local southPanel = Kit.new("Frame", { Name = "DeepSouth", Position = UDim2.fromOffset(MAP + 8, 0), Size = UDim2.fromOffset(SOUTH.Width, MapView.HEIGHT), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas })
	text(southPanel, { Text = "▲ THE DEEP SOUTH", TextSize = 12, Color = Color3.fromRGB(255, 190, 150), Position = UDim2.fromOffset(2, 4), Size = UDim2.fromOffset(SOUTH.Width, 14), ZIndex = 10 })
	local strip = Kit.new("Frame", {
		Name = "Strip",
		Position = UDim2.fromOffset(0, 22),
		Size = UDim2.fromOffset(SOUTH.Width, (SOUTH.Bottom - SOUTH.Top) * KS),
		BackgroundColor3 = Color3.fromRGB(14, 12, 34),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = southPanel,
	}, { Kit.corner(UDim.new(0, 12)) })
	-- Night sky behind the isles.
	local rng = Random.new(7)
	for _ = 1, 26 do
		Kit.new("Frame", { Position = UDim2.fromOffset(rng:NextNumber(4, SOUTH.Width - 4), rng:NextNumber(2, 96)), Size = UDim2.fromOffset(2, 2), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = rng:NextNumber(0, 0.6), BorderSizePixel = 0, ZIndex = 4, Parent = strip })
	end
	-- The neck of the Ashen Pass up from the Falls.
	local neckTop, neckBottom = spx(40, -505), spx(-40, SOUTH.Bottom)
	Kit.new("Frame", {
		Position = neckTop,
		Size = UDim2.fromOffset(neckBottom.X.Offset - neckTop.X.Offset, neckBottom.Y.Offset - neckTop.Y.Offset),
		BackgroundColor3 = rgb(Regions.Info.Falls.Color):Lerp(Color3.fromRGB(60, 40, 40), 0.6),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = strip,
	})
	local southCards = {}
	-- Veils sit on their own top layer so they cover every marker in a locked band too.
	local veils = Kit.new("Frame", { Name = "Veils", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = strip })
	for _, band in SOUTH_BANDS do
		local info = Regions.Info[band.Area]
		local balance = GameConfig.Regions[band.Area]
		local top, bottom = spx(SOUTH.HalfX, band.To), spx(-SOUTH.HalfX, band.From)
		local area = Kit.new("Frame", {
			Name = band.Area,
			Position = top,
			Size = UDim2.fromOffset(SOUTH.Width, bottom.Y.Offset - top.Y.Offset),
			BackgroundColor3 = rgb(info.Color):Lerp(Color3.fromRGB(30, 26, 40), if band.Area == "Star" then 0.85 else 0.35),
			BackgroundTransparency = if band.Area == "Star" then 0.3 else 0,
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = strip,
		})
		-- Region pill in the band's corner: name, danger, your strength.
		local pill = Kit.new("Frame", { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(92, 26), BackgroundColor3 = INK, BackgroundTransparency = 0.2, BorderSizePixel = 0, ZIndex = 11, Parent = area }, { Kit.corner(UDim.new(0, 5)) })
		Kit.stroke(rgb(info.Color), 1.2, 0.1).Parent = pill
		text(pill, { Text = (info.Title:gsub(" ISLES", "")), TextSize = 9, Color = rgb(info.Color), Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(60, 10), ZIndex = 12, Outline = false })
		local strength = text(pill, { Text = "", TextSize = 8, Position = UDim2.fromOffset(48, 2), Size = UDim2.fromOffset(40, 10), XAlign = Enum.TextXAlignment.Right, ZIndex = 12, Outline = false })
		text(pill, { Text = stars(balance.Danger), TextSize = 8, Color = dangerColor(balance.Danger), Position = UDim2.fromOffset(4, 14), Size = UDim2.fromOffset(84, 9), ZIndex = 12, Outline = false })
		-- The lock: a dark veil over the whole band until YOUR Ascension is high enough.
		local veil = Kit.new("Frame", { Position = area.Position, Size = area.Size, BackgroundColor3 = Color3.fromRGB(8, 8, 16), BackgroundTransparency = 0.3, BorderSizePixel = 0, ZIndex = 21, Parent = veils })
		text(veil, { Text = ("🔒 ASCENSION %d"):format(balance.RequiredAscension), TextSize = 12, Color = Color3.fromRGB(255, 215, 90), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 4), Size = UDim2.fromOffset(SOUTH.Width, 14), XAlign = Enum.TextXAlignment.Center, ZIndex = 22 })
		text(veil, { Text = (info.Title:gsub(" ISLES", "")), TextSize = 10, Color = rgb(info.Color), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, -11), Size = UDim2.fromOffset(SOUTH.Width, 12), XAlign = Enum.TextXAlignment.Center, ZIndex = 22 })
		southCards[band.Area] = { Strength = strength, Recommended = balance.RecommendedStrength, Veil = veil, Required = balance.RequiredAscension }
	end
	-- Mount Cinder, the crevasses, the isles and their light bridges.
	local cinder = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = spx(-100, -650), Size = UDim2.fromOffset(150 * KS, 150 * KS), BackgroundColor3 = Color3.fromRGB(70, 50, 48), BorderSizePixel = 0, ZIndex = 4, Parent = strip }, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.4, 0.4), BackgroundColor3 = Color3.fromRGB(255, 110, 30), BorderSizePixel = 0, ZIndex = 5, Parent = cinder }, { Kit.corner(UDim.new(0.5, 0)) })
	line(strip, spx(120, -700), spx(-20, -600), 3, Color3.fromRGB(255, 110, 30), 0.1, 4)
	for _, z in { -880, -950 } do
		line(strip, spx(SOUTH.HalfX, z), spx(-SOUTH.HalfX, z + 12), 3, Color3.fromRGB(20, 40, 70), 0, 4)
	end
	for _, pair in LIGHT_BRIDGES do
		local a, b = ISLES[pair[1]], ISLES[pair[2]]
		line(strip, spx(a[1], a[2]), spx(b[1], b[2]), 2, Color3.fromRGB(160, 220, 255), 0.2, 4)
	end
	for _, isle in ISLES do
		Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = spx(isle[1], isle[2]), Size = UDim2.fromOffset(isle[3] * 2 * KS, isle[3] * 2 * KS), BackgroundColor3 = Color3.fromRGB(120, 170, 110), BorderSizePixel = 0, ZIndex = 5, Parent = strip }, { Kit.corner(UDim.new(0.5, 0)) })
	end
	text(southPanel, { Text = "✨ Ascend to break each seal", TextSize = 9, Color = Color3.fromRGB(220, 200, 255), Position = UDim2.fromOffset(2, 22 + (SOUTH.Bottom - SOUTH.Top) * KS + 3), Size = UDim2.fromOffset(SOUTH.Width, 11), ZIndex = 10, Outline = false })
	-- The layer each world position is drawn on: the island, or the Deep South strip.
	local function placeOf(position: Vector3): (Instance, UDim2)
		if position.Z >= ON_ISLAND_Z then
			return overlay, px(position.X, position.Z)
		end
		return strip, spx(position.X, position.Z)
	end

	-- Geysers (the hidden one stays hidden).
	for _, geyser in WorldLayout.LaunchPads do
		if geyser.Name ~= "???" then
			local layer, at = placeOf(geyser.Position)
			text(layer, { Text = "⬆", TextSize = 13, Color = rgb(geyser.Color), AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(16, 16), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
		end
	end
	-- Exits: safe + dangerous shown, the secret ones only as a "?".
	for _, zone in WorldLayout.ExtractionZones do
		local layer, at = placeOf(zone.Position)
		local size = if layer == strip then 13 else 18
		marker(layer, at, EXIT_COLORS[zone.Category] or Color3.new(1, 1, 1), if zone.Category == "Secret" then "?" else "⌂", size)
	end
	-- Waystones: the dais in the District and each region's return stone.
	local waystoneSpots = { WorldLayout.Waystones.Circle }
	for _, region in WorldLayout.Waystones.Regions do
		table.insert(waystoneSpots, region.Stone)
	end
	for _, at in waystoneSpots do
		local layer, position = placeOf(at)
		text(layer, { Text = "◆", TextSize = 11, Color = Color3.fromRGB(220, 190, 255), AnchorPoint = Vector2.new(0.5, 0.5), Position = position, Size = UDim2.fromOffset(14, 14), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
	end
	-- Secrets you've found (filled in by Refresh).
	local secretMarks = {}
	for _, secret in Regions.Secrets do
		local layer, at = placeOf(secret.Position)
		secretMarks[secret.Id] = text(layer, { Text = "✦", TextSize = 13, Color = Color3.fromRGB(255, 225, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = at, Size = UDim2.fromOffset(16, 16), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
	end
	-- YOU ARE HERE at the gate (pulsing ring).
	local here = WorldLayout.District.Gate + Vector3.new(0, 0, 12)
	local ring = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = px(here.X, here.Z),
		Size = UDim2.fromOffset(16, 16),
		BackgroundColor3 = Color3.fromRGB(255, 70, 90),
		BorderSizePixel = 0,
		ZIndex = 10,
		Parent = overlay,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	Kit.stroke(Color3.new(1, 1, 1), 2.5, 0).Parent = ring
	local pulse = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 10,
		Parent = ring,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	local pulseStroke = Kit.stroke(Color3.fromRGB(255, 70, 90), 2, 0)
	pulseStroke.Parent = pulse
	Kit.tween(pulse, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Size = UDim2.fromScale(3, 3) })
	Kit.tween(pulseStroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 })
	text(overlay, { Text = "YOU ARE HERE", TextSize = 11, Color = Color3.fromRGB(255, 120, 130), AnchorPoint = Vector2.new(0.5, 0), Position = px(here.X, here.Z - 34), Size = UDim2.fromOffset(100, 12), XAlign = Enum.TextXAlignment.Center, ZIndex = 10 })
	text(overlay, { Text = "▲ INTO THE WILDS", TextSize = 11, Color = Color3.fromRGB(230, 240, 255), Position = UDim2.fromOffset(8, 6), Size = UDim2.fromOffset(140, 12), ZIndex = 10 })

	-- Region label cards.
	local cards = {}
	for area, at in LABELS do
		local balance = GameConfig.Regions[area]
		local info = Regions.Info[area]
		local card = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(at[1], at[2]),
			Size = UDim2.fromOffset(98, 44),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.18,
			BorderSizePixel = 0,
			ZIndex = 11,
			Parent = overlay,
		}, { Kit.corner(UDim.new(0, 6)) })
		Kit.stroke(rgb(info.Color), 1.5, 0.1).Parent = card
		text(card, { Text = info.Title, TextSize = 10, Color = rgb(info.Color), Position = UDim2.fromOffset(5, 3), Size = UDim2.fromOffset(90, 11), ZIndex = 12, Outline = false })
		text(card, { Text = stars(balance.Danger), TextSize = 8, Color = dangerColor(balance.Danger), Position = UDim2.fromOffset(5, 16), Size = UDim2.fromOffset(50, 10), ZIndex = 12, Outline = false })
		local strength = text(card, { Text = "", TextSize = 10, Position = UDim2.fromOffset(52, 15), Size = UDim2.fromOffset(42, 11), XAlign = Enum.TextXAlignment.Right, ZIndex = 12, Outline = false })
		text(card, { Text = typicalLoot(balance.Danger), TextSize = 9, Position = UDim2.fromOffset(5, 28), Size = UDim2.fromOffset(90, 11), ZIndex = 12, Outline = false })
		cards[area] = { Strength = strength, Recommended = balance.RecommendedStrength }
	end

	-- RIGHT: HOW TO READ IT ------------------------------------------------------------------
	local sideX = MAP + 8 + SOUTH.Width + 12
	local side = Kit.new("Frame", { Position = UDim2.fromOffset(sideX, 10), Size = UDim2.fromOffset(MapView.WIDTH - sideX - 10, MapView.HEIGHT - 20), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas })
	text(side, { Text = "🗺 PLAN YOUR RUN", Font = Theme.Font.Display, TextSize = 20, Color = Color3.fromRGB(255, 215, 90), Size = UDim2.fromOffset(290, 22), Outline = 1.8 })
	text(side, { Text = "MORE DANGER = RARER LOOT", TextSize = 11, Color = Color3.fromRGB(200, 210, 230), Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(290, 12), Outline = false })
	-- One row per danger level: stars, where, what drops.
	local ROW = 25
	local byDanger: { [number]: { string } } = {}
	for _, area in Regions.Order do
		local danger = GameConfig.Regions[area].Danger
		byDanger[danger] = byDanger[danger] or {}
		local short = Regions.Info[area].Title:gsub("^THE ", ""):gsub("SHIPWRECK ", ""):gsub("GLOWSHROOM ", ""):gsub("ANCIENT ", ""):gsub(" ISLES", "")
		table.insert(byDanger[danger], short)
	end
	for danger = 1, #GameConfig.Treasure.RarityByDanger do
		local y = 44 + (danger - 1) * ROW
		text(side, { Text = stars(danger), TextSize = 10, Color = dangerColor(danger), Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(74, 13) })
		text(side, { Text = table.concat(byDanger[danger] or {}, " • "), TextSize = 10, Color = Color3.fromRGB(235, 240, 250), Position = UDim2.fromOffset(78, y + 1), Size = UDim2.fromOffset(208, 12), Outline = false })
		lootBar(side, danger, UDim2.fromOffset(0, y + 14), 286)
	end
	-- Rarity key under the bars.
	local keyY = 44 + #GameConfig.Treasure.RarityByDanger * ROW + 2
	for i, rarity in LOOT_TIERS do
		local x = (i - 1) * 58
		Kit.new("Frame", { Position = UDim2.fromOffset(x, keyY + 2), Size = UDim2.fromOffset(9, 9), BackgroundColor3 = Rarities.Info[rarity].Color, BorderSizePixel = 0, ZIndex = 6, Parent = side }, { Kit.corner(UDim.new(0, 2)) })
		text(side, { Text = rarity:upper(), TextSize = 8, Color = Color3.fromRGB(210, 215, 230), Position = UDim2.fromOffset(x + 12, keyY + 1), Size = UDim2.fromOffset(46, 11), Outline = false })
	end
	text(side, { Text = '✨ <font color="#F44336">MYTHIC</font>+ CAN DROP <b>ANYWHERE</b>', TextSize = 11, Color = Color3.fromRGB(255, 240, 200), Position = UDim2.fromOffset(0, keyY + 16), Size = UDim2.fromOffset(290, 13), Outline = false })

	-- Exits and what they pay.
	local exitsY = keyY + 38
	text(side, { Text = "EXITS - RISKIER PAYS MORE", TextSize = 11, Color = Color3.fromRGB(200, 210, 230), Position = UDim2.fromOffset(0, exitsY), Size = UDim2.fromOffset(290, 12), Outline = false })
	local categories = GameConfig.Extraction.Categories
	local exitRows = {
		{ "Safe", "⌂", "Expedition Camp", "no bonus" },
		{ "Dangerous", "⌂", "Temple Courtyard", nil },
		{ "Secret", "?", "Somewhere hidden...", nil },
	}
	for i, row in exitRows do
		local category = categories[row[1]]
		local y = exitsY + 16 + (i - 1) * 17
		local dot = Kit.new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(13, 13), BackgroundColor3 = EXIT_COLORS[row[1]], BorderSizePixel = 0, ZIndex = 6, Parent = side }, { Kit.corner(UDim.new(0.5, 0)) })
		text(dot, { Text = row[2], TextSize = 9, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(13, 13), XAlign = Enum.TextXAlignment.Center, ZIndex = 7, Outline = 1 })
		local reward = row[4]
			or ('<font color="#78eb78">+%d%% cash</font> • %d%% mutation'):format(math.floor((category.Bonus - 1) * 100 + 0.5), math.floor(category.MutationChance * 100 + 0.5))
		text(side, { Text = ("<b>%s</b>  %s"):format(row[3], reward), TextSize = 10, Color = Color3.fromRGB(235, 240, 250), Position = UDim2.fromOffset(18, y), Size = UDim2.fromOffset(272, 13), Outline = false })
	end
	local footerY = exitsY + 16 + 3 * 17 + 6
	text(side, { Text = "🌙 New loot every NIGHT • ☀ bank it before dark", TextSize = 10, Color = Color3.fromRGB(190, 205, 255), Position = UDim2.fromOffset(0, footerY), Size = UDim2.fromOffset(290, 12), Outline = false })
	text(side, { Text = "⚡ Boost rings • ⬆ geysers • ◆ waystones • ✦ secrets", TextSize = 10, Color = Color3.fromRGB(190, 205, 255), Position = UDim2.fromOffset(0, footerY + 14), Size = UDim2.fromOffset(290, 12), Outline = false })
	local you = text(side, { Text = "", TextSize = 11, Color = Color3.fromRGB(255, 255, 255), Position = UDim2.fromOffset(0, footerY + 30), Size = UDim2.fromOffset(290, 13), Outline = false })

	local function refresh(data)
		local strength = if data then data.Strength or 0 else 0
		you.Text = ('💪 YOUR STRENGTH <font color="#FFD76A"><b>%s</b></font> • ✔ = you can carry it'):format(Kit.shortNumber(strength))
		for _, card in cards do
			local ready = strength >= card.Recommended
			card.Strength.Text = ('<font color="#%s">%s💪%s</font>'):format(if ready then "78eb78" else "ff9a50", if ready then "✔" else "", Kit.shortNumber(card.Recommended))
		end
		local ascension = if data then data.Ascension or 0 else 0
		for _, card in southCards do
			local ready = strength >= card.Recommended
			card.Strength.Text = ('<font color="#%s">%s💪%s</font>'):format(if ready then "78eb78" else "ff9a50", if ready then "✔" else "", Kit.shortNumber(card.Recommended))
			card.Veil.Visible = ascension < card.Required
		end
		local milestones = data and data.Milestones or {}
		for id, mark in secretMarks do
			mark.Visible = milestones["Secret_" .. id] ~= nil
		end
	end
	refresh(nil)
	return { Canvas = canvas, Refresh = refresh }
end

return MapView
