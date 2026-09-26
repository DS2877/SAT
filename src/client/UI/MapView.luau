-- The world map, drawn from config so it never goes stale. Used on the board by the gate
-- (SurfaceGui) and full screen (Menus/Map). Fixed 960 x 540 canvas; callers scale it.
--
-- DESIGN: one continuous map read as a JOURNEY, left to right: the safe District on the left,
-- every step right is more dangerous and pays rarer loot, ending in the Starfall Isles.
-- Everything a player needs to plan a run sits ON the region it's about:
--   * a card per region: name, danger, what it drops (loot bar + the two likeliest rarities)
--     and ONE personal status chip: ✔ ready / 💪 strength needed / 🔒 Ascension needed
--   * "★ BEST FOR YOU" on the most dangerous region you can handle right now (or "START
--     HERE" for a brand-new player), so the map answers "where should I go?"
--   * sealed regions are veiled; secrets appear once you've found them
-- A slim key lives in the empty sea corners (top right: danger + rarities, bottom right:
-- exits, symbols, night rule, you).
--
-- Orientation: right = south, INTO the Wilds (-Z). Facing that way, +X is on your right, which
-- is DOWN on this map (the map is the world turned a quarter clockwise).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Config.WorldLayout)
local Regions = require(Shared.Config.Regions)
local Rarities = require(Shared.Config.Rarities)

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local MapView = {}

MapView.WIDTH, MapView.HEIGHT = 960, 540

local K = 0.5625 -- px per stud
local Z0 = 420 -- world z at the left edge
local X0 = -480 -- world x at the top edge
local ISLAND_R = 455
local LOOT_TIERS = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
local INK = Color3.fromRGB(20, 22, 34)
local GOLD = Color3.fromRGB(255, 205, 70)

-- Where each region's card sits (world x, z) - placed clear of landmarks.
local CARDS = {
	Wilds = { 60, -60 },
	Coast = { -330, -40 },
	Frost = { -290, 250 },
	Marsh = { 270, 200 },
	Ruins = { 250, -170 },
	Falls = { 110, -320 },
	Ember = { 175, -600 },
	Rime = { 0, -915 },
	Star = { 200, -1160 },
}
-- The Deep South bands (world z) and the isles (mirrors World/DeepSouth).
local SOUTH = { Ember = { -505, -790 }, Rime = { -790, -1045 }, HalfX = 215 }
local ISLES = {
	Landing = { 0, -1085, 24 },
	Garden = { -72, -1120, 17 },
	Moonstone = { 72, -1122, 17 },
	Skyport = { 120, -1190, 19 },
	Starwell = { -60, -1180, 17 },
	Observatory = { 8, -1218, 16 },
}
local LIGHT_BRIDGES = { { "Landing", "Garden" }, { "Moonstone", "Skyport" }, { "Observatory", "Moonstone" } }
-- The main road south, from the Falls up the cliff, over the ridge and down the spine.
local SPINE = {
	{ 0, -270 },
	{ 40, -296 },
	{ 50, -380 },
	{ 28, -548 },
	{ 45, -600 },
	{ 55, -660 },
	{ 40, -720 },
	{ 12, -786 },
	{ 0, -852 },
	{ -5, -915 },
	{ 0, -1030 },
	{ 0, -1085 },
}
local EXIT_COLORS = { Safe = Color3.fromRGB(80, 230, 110), Dangerous = Color3.fromRGB(255, 150, 40), Secret = Color3.fromRGB(190, 110, 255) }

-- World (x, z) -> canvas pixels.
local function sx(z: number): number
	return (Z0 - z) * K
end
local function sy(x: number): number
	return (x - X0) * K
end
local function at(x: number, z: number): UDim2
	return UDim2.fromOffset(sx(z), sy(x))
end

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
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

local function blob(parent: Instance, position: UDim2, diameter: number, color: Color3, z: number, transparency: number?): Frame
	return Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(diameter, diameter),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency or 0,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	}, { Kit.corner(UDim.new(0.5, 0)) })
end

-- A line between two canvas points (offsets).
local function line(parent: Instance, a: UDim2, b: UDim2, thickness: number, color: Color3, transparency: number, z: number)
	local ax, ay, bx, by = a.X.Offset, a.Y.Offset, b.X.Offset, b.Y.Offset
	return Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
		Size = UDim2.fromOffset(math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2) + thickness * 0.5, thickness),
		Rotation = math.deg(math.atan2(by - ay, bx - ax)),
		BackgroundColor3 = color,
		BackgroundTransparency = transparency,
		BorderSizePixel = 0,
		ZIndex = z,
		Parent = parent,
	})
end

local function marker(parent: Instance, position: UDim2, color: Color3, glyph: string, size: number)
	local dot = blob(parent, position, size, color, 8)
	Kit.stroke(Color3.new(1, 1, 1), 1.5, 0).Parent = dot
	text(dot, { Text = glyph, TextSize = size * 0.66, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size, size), XAlign = Enum.TextXAlignment.Center, ZIndex = 9, Outline = 1 })
	return dot
end

-- Stacked bar of what one danger level drops (share of Common..Legendary).
local function lootBar(parent: Instance, danger: number, position: UDim2, width: number, height: number, z: number)
	local row = GameConfig.Treasure.RarityByDanger[danger]
	local total = 0
	for _, rarity in LOOT_TIERS do
		total += row[rarity] or 0
	end
	local bar = Kit.new("Frame", { Position = position, Size = UDim2.fromOffset(width, height), BackgroundColor3 = INK, BorderSizePixel = 0, ClipsDescendants = true, ZIndex = z, Parent = parent }, { Kit.corner(UDim.new(0, 3)) })
	local x = 0
	for _, rarity in LOOT_TIERS do
		local share = (row[rarity] or 0) / total
		if share > 0 then
			-- Tiny shares still get a visible sliver: a rare Epic in the Wilds should show.
			local w = math.max(2, share * width)
			Kit.new("Frame", { Position = UDim2.fromOffset(x, 0), Size = UDim2.fromOffset(w, height), BackgroundColor3 = Rarities.Info[rarity].Color, BorderSizePixel = 0, ZIndex = z + 1, Parent = bar })
			x += w
		end
	end
	return bar
end

-- The two most likely rarities, e.g. "COMMON-UNCOMMON", in their colours.
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

-- Builds the map into `parent`. Returns { Canvas, Refresh(data) }.
function MapView.Build(parent: Frame)
	local canvas = Kit.new("Frame", {
		Name = "MapCanvas",
		Size = UDim2.fromOffset(MapView.WIDTH, MapView.HEIGHT),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Parent = parent,
	}, {
		Kit.corner(UDim.new(0, 16)),
		-- The sea darkens into night sky toward the end of the world.
		Kit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(70, 150, 210)),
				ColorSequenceKeypoint.new(0.55, Color3.fromRGB(35, 85, 150)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(22, 18, 50)),
			}),
		}),
	})
	-- A few stars over the far end.
	local rng = Random.new(7)
	for _ = 1, 40 do
		local size = if rng:NextNumber() < 0.2 then 3 else 2
		Kit.new("Frame", { Position = UDim2.fromOffset(rng:NextNumber(800, 955), rng:NextNumber(130, 420)), Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = rng:NextNumber(0.1, 0.6), BorderSizePixel = 0, ZIndex = 1, Parent = canvas })
	end

	-- THE ISLAND (clipped to its round coastline) ------------------------------------------
	local island = Kit.new("CanvasGroup", {
		Name = "Island",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = at(0, 0),
		Size = UDim2.fromOffset(ISLAND_R * 2 * K, ISLAND_R * 2 * K),
		BackgroundColor3 = rgb(Regions.Info.Wilds.Color):Lerp(Color3.fromRGB(40, 90, 40), 0.35),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = canvas,
	}, { Kit.corner(UDim.new(0.5, 0)) })
	local function inIsland(x: number, z: number): UDim2
		return UDim2.fromOffset((ISLAND_R - z) * K, (x + ISLAND_R) * K)
	end
	-- The Falls: everything south of z = -240, a band down the island's right side.
	local fallsLeft = (ISLAND_R + 240) * K
	Kit.new("Frame", {
		Position = UDim2.fromOffset(fallsLeft, 0),
		Size = UDim2.new(1, -fallsLeft, 1, 0),
		BackgroundColor3 = rgb(Regions.Info.Falls.Color):Lerp(Color3.fromRGB(10, 50, 30), 0.55),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = island,
	})
	local volcano = blob(island, inIsland(-280, -360), 300 * K, Color3.fromRGB(70, 66, 66), 4)
	text(volcano, { Text = "🌋", TextSize = 16, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.45, 0.62), Size = UDim2.fromOffset(20, 20), XAlign = Enum.TextXAlignment.Center, Outline = false })
	local shapes = {
		{ "Coast", WorldLayout.Shipwreck.Center, 160 },
		{ "Ruins", WorldLayout.Temple.Center, 150 },
		{ "Frost", WorldLayout.Frostpeak.Center, WorldLayout.Frostpeak.Radius },
		{ "Marsh", WorldLayout.Marsh.Center, WorldLayout.Marsh.Radius },
	}
	for _, shape in shapes do
		local b = blob(island, inIsland(shape[2].X, shape[2].Z), shape[3] * 2 * K, rgb(Regions.Info[shape[1]].Color):Lerp(Color3.fromRGB(30, 30, 40), 0.25), 4, 0.15)
		Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.55).Parent = b
	end
	local district = WorldLayout.District.Center
	local safe = blob(island, inIsland(district.X, district.Z), GameConfig.SafeZone.Radius * 2 * K, Color3.fromRGB(235, 225, 200), 4)
	Kit.stroke(Color3.fromRGB(120, 220, 255), 2, 0).Parent = safe
	text(safe, { Text = "🛡 DISTRICT", TextSize = 11, Color = Color3.fromRGB(40, 90, 130), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.42, 0.5), Size = UDim2.fromOffset(90, 13), XAlign = Enum.TextXAlignment.Center, Outline = false })
	text(safe, { Text = "SAFE", TextSize = 9, Color = Color3.fromRGB(70, 130, 170), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.42, 0, 0.5, 13), Size = UDim2.fromOffset(90, 11), XAlign = Enum.TextXAlignment.Center, Outline = false })

	-- THE DEEP SOUTH ---------------------------------------------------------------------------
	local bands = {}
	for _, area in { "Ember", "Rime" } do
		local z1, z2 = SOUTH[area][1], SOUTH[area][2]
		bands[area] = Kit.new("Frame", {
			Name = area,
			Position = at(-SOUTH.HalfX, z1),
			Size = UDim2.fromOffset((z1 - z2) * K, SOUTH.HalfX * 2 * K),
			BackgroundColor3 = rgb(Regions.Info[area].Color):Lerp(Color3.fromRGB(30, 26, 40), 0.4),
			BorderSizePixel = 0,
			ZIndex = 2,
			Parent = canvas,
		}, { Kit.corner(UDim.new(0, 18)) })
	end
	-- Mount Cinder and a lava river; the crevasses across the glacier.
	local cinder = blob(canvas, at(-100, -650), 150 * K, Color3.fromRGB(70, 50, 48), 3)
	blob(cinder, UDim2.fromScale(0.5, 0.5), 60 * K, Color3.fromRGB(255, 110, 30), 4)
	line(canvas, at(120, -700), at(-20, -600), 3, Color3.fromRGB(255, 110, 30), 0.1, 3)
	for _, z in { -880, -950 } do
		line(canvas, at(-SOUTH.HalfX + 10, z), at(SOUTH.HalfX - 10, z - 12), 3, Color3.fromRGB(20, 40, 70), 0, 3)
	end
	-- The Starfall Isles over the night sea.
	for _, pair in LIGHT_BRIDGES do
		local a, b = ISLES[pair[1]], ISLES[pair[2]]
		line(canvas, at(a[1], a[2]), at(b[1], b[2]), 2, Color3.fromRGB(160, 220, 255), 0.2, 3)
	end
	line(canvas, at(14, -1022), at(0, -1085), 2, Color3.fromRGB(160, 220, 255), 0.2, 3)
	for _, isle in ISLES do
		local b = blob(canvas, at(isle[1], isle[2]), isle[3] * 2 * K, Color3.fromRGB(120, 170, 110), 4)
		Kit.stroke(Color3.fromRGB(200, 170, 255), 1.5, 0.3).Parent = b
	end

	-- ROUTES AND PLACES --------------------------------------------------------------------------
	local routes = Kit.new("Frame", { Name = "Routes", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas })
	local gate = Vector3.new(0, 0, 55)
	for _, finish in {
		WorldLayout.Temple.Courtyard + Vector3.new(0, 0, 15),
		WorldLayout.Shipwreck.Center + Vector3.new(60, 0, 0),
		WorldLayout.Frostpeak.Center + Vector3.new(50, 0, -40),
		WorldLayout.Marsh.Center + Vector3.new(-60, 0, -40),
	} do
		line(routes, at(gate.X, gate.Z), at(finish.X, finish.Z), 3, Color3.fromRGB(240, 220, 170), 0.3, 5)
	end
	-- The main road south, drawn bolder: this is the journey.
	line(routes, at(gate.X, gate.Z), at(SPINE[1][1], SPINE[1][2]), 3, Color3.fromRGB(255, 235, 180), 0.1, 5)
	for i = 1, #SPINE - 1 do
		line(routes, at(SPINE[i][1], SPINE[i][2]), at(SPINE[i + 1][1], SPINE[i + 1][2]), 3, Color3.fromRGB(255, 235, 180), 0.1, 5)
	end

	-- The layer each marker is drawn on (above routes, below the region veils and cards).
	local marks = Kit.new("Frame", { Name = "Marks", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6, Parent = canvas })
	for _, geyser in WorldLayout.LaunchPads do
		if geyser.Name ~= "???" then
			text(marks, { Text = "⬆", TextSize = 12, Color = rgb(geyser.Color), AnchorPoint = Vector2.new(0.5, 0.5), Position = at(geyser.Position.X, geyser.Position.Z), Size = UDim2.fromOffset(14, 14), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
		end
	end
	local waystones = { WorldLayout.Waystones.Circle }
	for _, region in WorldLayout.Waystones.Regions do
		table.insert(waystones, region.Stone)
	end
	for _, spot in waystones do
		text(marks, { Text = "◆", TextSize = 11, Color = Color3.fromRGB(225, 195, 255), AnchorPoint = Vector2.new(0.5, 0.5), Position = at(spot.X, spot.Z), Size = UDim2.fromOffset(14, 14), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
	end
	for _, zone in WorldLayout.ExtractionZones do
		marker(marks, at(zone.Position.X, zone.Position.Z), EXIT_COLORS[zone.Category] or Color3.new(1, 1, 1), if zone.Category == "Secret" then "?" else "⌂", 15)
	end
	local secretMarks = {}
	for _, secret in Regions.Secrets do
		secretMarks[secret.Id] = text(marks, { Text = "✦", TextSize = 13, Color = Color3.fromRGB(255, 225, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = at(secret.Position.X, secret.Position.Z), Size = UDim2.fromOffset(16, 16), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
	end
	-- YOU ARE HERE at the gate (pulsing).
	local here = WorldLayout.District.Gate + Vector3.new(0, 0, 12)
	local ring = blob(marks, at(here.X, here.Z), 14, Color3.fromRGB(255, 70, 90), 10)
	Kit.stroke(Color3.new(1, 1, 1), 2.5, 0).Parent = ring
	local pulse = blob(ring, UDim2.fromScale(0.5, 0.5), 14, Color3.new(), 10, 1)
	pulse.Size = UDim2.fromScale(1, 1)
	local pulseStroke = Kit.stroke(Color3.fromRGB(255, 70, 90), 2, 0)
	pulseStroke.Parent = pulse
	Kit.tween(pulse, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Size = UDim2.fromScale(3, 3) })
	Kit.tween(pulseStroke, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, -1), { Transparency = 1 })
	text(marks, { Text = "YOU ARE HERE", TextSize = 10, Color = Color3.fromRGB(255, 130, 140), AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.fromOffset(sx(here.Z), sy(here.X) - 10), Size = UDim2.fromOffset(90, 12), XAlign = Enum.TextXAlignment.Center, ZIndex = 10 })

	-- Veils over sealed regions (per player, in Refresh).
	local veilLayer = Kit.new("Frame", { Name = "Veils", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 11, Parent = canvas })
	local veils = {}
	local function veil(area: string, position: UDim2, size: UDim2)
		local v = Kit.new("Frame", { Position = position, Size = size, BackgroundColor3 = Color3.fromRGB(8, 8, 18), BackgroundTransparency = 0.35, BorderSizePixel = 0, ZIndex = 12, Parent = veilLayer }, { Kit.corner(UDim.new(0, 18)) })
		text(v, { Text = "🔒", TextSize = 22, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.3), Size = UDim2.fromOffset(30, 26), XAlign = Enum.TextXAlignment.Center, ZIndex = 13, Outline = false })
		veils[area] = v
	end
	for _, area in { "Ember", "Rime" } do
		veil(area, bands[area].Position, bands[area].Size)
	end
	veil("Star", at(-160, -1050), UDim2.fromOffset((1286 - 1050) * K, 320 * K))

	-- REGION CARDS ---------------------------------------------------------------------------------
	local cardLayer = Kit.new("Frame", { Name = "Cards", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 20, Parent = canvas })
	local cards = {}
	for area, spot in CARDS do
		local balance = GameConfig.Regions[area]
		local info = Regions.Info[area]
		local color = rgb(info.Color)
		local card = Kit.new("Frame", {
			Name = area,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = at(spot[1], spot[2]),
			Size = UDim2.fromOffset(118, 52),
			BackgroundColor3 = INK,
			BackgroundTransparency = 0.12,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = cardLayer,
		}, { Kit.corner(UDim.new(0, 7)) })
		local stroke = Kit.stroke(color, 1.5, 0.1)
		stroke.Parent = card
		local title = info.Title:gsub("^THE ", ""):gsub("SHIPWRECK ", ""):gsub("GLOWSHROOM ", ""):gsub("ANCIENT ", "")
		text(card, { Text = title, TextSize = 10, Color = color, Position = UDim2.fromOffset(6, 3), Size = UDim2.fromOffset(106, 12), ZIndex = 22, Outline = false })
		text(card, { Text = Regions.Stars(balance.Danger), TextSize = 8, Color = dangerColor(balance.Danger), Position = UDim2.fromOffset(6, 17), Size = UDim2.fromOffset(54, 10), ZIndex = 22, Outline = false })
		local status = text(card, { Text = "", TextSize = 9, Position = UDim2.fromOffset(56, 16), Size = UDim2.fromOffset(56, 11), XAlign = Enum.TextXAlignment.Right, ZIndex = 22, Outline = false })
		lootBar(card, balance.Danger, UDim2.fromOffset(6, 30), 106, 5, 22)
		text(card, { Text = typicalLoot(balance.Danger), TextSize = 8, Position = UDim2.fromOffset(6, 38), Size = UDim2.fromOffset(106, 10), ZIndex = 22, Outline = false })
		-- "★ BEST FOR YOU" tab, shown on one card at a time.
		local tab = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0, 1), Size = UDim2.fromOffset(92, 14), BackgroundColor3 = GOLD, BorderSizePixel = 0, Visible = false, ZIndex = 23, Parent = card }, { Kit.corner(UDim.new(0, 5)) })
		local tabText = text(tab, { Text = "★ BEST FOR YOU", TextSize = 9, Color = INK, Size = UDim2.fromScale(1, 1), XAlign = Enum.TextXAlignment.Center, ZIndex = 24, Outline = false })
		cards[area] = { Card = card, Stroke = stroke, Color = color, Status = status, Tab = tab, TabText = tabText, Danger = balance.Danger, Recommended = balance.RecommendedStrength, Required = balance.RequiredAscension or 0 }
	end
	-- The best card's tab pulses.
	for _, card in cards do
		Kit.tween(card.Tab, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { BackgroundTransparency = 0.35 })
	end

	-- KEY (in the empty sea corners) -------------------------------------------------------------
	local top = Kit.new("Frame", { Name = "KeyTop", Position = UDim2.fromOffset(508, 10), Size = UDim2.fromOffset(440, 110), BackgroundTransparency = 1, ZIndex = 30, Parent = canvas })
	text(top, { Text = "🗺 PLAN YOUR RUN", Font = Theme.Font.Display, TextSize = 22, Color = GOLD, Size = UDim2.fromOffset(300, 24), ZIndex = 31, Outline = 2 })
	-- Danger runs with the map: safe on the left, deadly on the right.
	text(top, { Text = "SAFE", TextSize = 10, Color = dangerColor(1), Position = UDim2.fromOffset(0, 32), Size = UDim2.fromOffset(40, 12), ZIndex = 31 })
	local scale = Kit.new("Frame", { Position = UDim2.fromOffset(42, 35), Size = UDim2.fromOffset(300, 7), BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 31, Parent = top }, {
		Kit.corner(UDim.new(0.5, 0)),
		Kit.new("UIGradient", { Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, dangerColor(1)), ColorSequenceKeypoint.new(0.5, dangerColor(4)), ColorSequenceKeypoint.new(1, dangerColor(7)) }) }),
	})
	text(scale, { Text = "▶", TextSize = 12, Color = dangerColor(7), AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, 1, 0.5, 0), Size = UDim2.fromOffset(12, 12), ZIndex = 31 })
	text(top, { Text = "DEADLY", TextSize = 10, Color = dangerColor(7), Position = UDim2.fromOffset(360, 32), Size = UDim2.fromOffset(60, 12), ZIndex = 31 })
	text(top, { Text = "The further you go, the rarer the loot", TextSize = 10, Color = Color3.fromRGB(215, 225, 245), Position = UDim2.fromOffset(0, 48), Size = UDim2.fromOffset(420, 12), ZIndex = 31, Outline = 1.2 })
	for i, rarity in LOOT_TIERS do
		local x = (i - 1) * 76
		Kit.new("Frame", { Position = UDim2.fromOffset(x, 68), Size = UDim2.fromOffset(10, 10), BackgroundColor3 = Rarities.Info[rarity].Color, BorderSizePixel = 0, ZIndex = 31, Parent = top }, { Kit.corner(UDim.new(0, 2)) })
		text(top, { Text = rarity:upper(), TextSize = 9, Color = Color3.fromRGB(225, 230, 245), Position = UDim2.fromOffset(x + 13, 67), Size = UDim2.fromOffset(62, 12), ZIndex = 31, Outline = 1.2 })
	end
	text(top, { Text = '✨ <font color="#F44336">MYTHIC</font>+ CAN DROP <b>ANYWHERE</b>', TextSize = 10, Color = Color3.fromRGB(255, 240, 200), Position = UDim2.fromOffset(0, 86), Size = UDim2.fromOffset(420, 12), ZIndex = 31, Outline = 1.2 })

	local bottom = Kit.new("Frame", { Name = "KeyBottom", Position = UDim2.fromOffset(508, 424), Size = UDim2.fromOffset(440, 108), BackgroundTransparency = 1, ZIndex = 30, Parent = canvas })
	local categories = GameConfig.Extraction.Categories
	local function bonus(category: string): string
		local c = categories[category]
		return ('<font color="#78eb78">+%d%%</font>'):format(math.floor((c.Bonus - 1) * 100 + 0.5))
	end
	text(bottom, { Text = "BANK IT AT AN EXIT - RISKIER EXITS PAY MORE", TextSize = 10, Color = Color3.fromRGB(215, 225, 245), Size = UDim2.fromOffset(440, 12), ZIndex = 31, Outline = 1.2 })
	for i, row in { { "Safe", "⌂", "Safe exit" }, { "Dangerous", "⌂", "Danger " .. bonus("Dangerous") }, { "Secret", "?", "Secret " .. bonus("Secret") } } do
		local x = (i - 1) * 138
		marker(bottom, UDim2.fromOffset(x + 7, 24), EXIT_COLORS[row[1]], row[2], 14).ZIndex = 31
		text(bottom, { Text = row[3], TextSize = 10, Position = UDim2.fromOffset(x + 18, 18), Size = UDim2.fromOffset(118, 12), ZIndex = 31, Outline = 1.2 })
	end
	text(bottom, { Text = "⬆ geyser   ◆ waystone   ✦ secret you found   ━ main road", TextSize = 10, Color = Color3.fromRGB(215, 225, 245), Position = UDim2.fromOffset(0, 40), Size = UDim2.fromOffset(440, 12), ZIndex = 31, Outline = 1.2 })
	text(bottom, { Text = "🌙 Night wipes every unbanked treasure - bank it before dark", TextSize = 10, Color = Color3.fromRGB(190, 205, 255), Position = UDim2.fromOffset(0, 58), Size = UDim2.fromOffset(440, 12), ZIndex = 31, Outline = 1.2 })
	local you = text(bottom, { Text = "", TextSize = 12, Position = UDim2.fromOffset(0, 80), Size = UDim2.fromOffset(440, 15), ZIndex = 31, Outline = 1.4 })

	local function refresh(data)
		local strength = if data then data.Strength or 0 else 0
		local ascension = if data then data.Ascension or 0 else 0
		you.Text = ('💪 YOU <font color="#FFD76A">%s</font>   ✨ ASCENSION <font color="#D7B4FF">%d</font>   ✔ = you can carry its loot'):format(Kit.shortNumber(strength), ascension)
		-- Best for you: the most dangerous region you're strong enough for and allowed into.
		local best, bestDanger = nil, -1
		for area, card in cards do
			local open = ascension >= card.Required
			local ready = open and strength >= card.Recommended
			if not open then
				card.Status.Text = ('<font color="#FFD76A">🔒 ASC %d</font>'):format(card.Required)
			elseif ready then
				card.Status.Text = ('<font color="#78eb78">✔ 💪%s</font>'):format(Kit.shortNumber(card.Recommended))
			else
				card.Status.Text = ('<font color="#ff9a50">💪%s</font>'):format(Kit.shortNumber(card.Recommended))
			end
			card.Card.BackgroundTransparency = if open then 0.12 else 0.3
			if ready and card.Danger > bestDanger then
				best, bestDanger = area, card.Danger
			end
			if veils[area] then
				veils[area].Visible = not open
			end
		end
		local brandNew = best == nil
		if brandNew then
			best = "Wilds"
		end
		for area, card in cards do
			local isBest = area == best
			card.Tab.Visible = isBest
			card.TabText.Text = if brandNew then "★ START HERE" else "★ BEST FOR YOU"
			card.Stroke.Color = if isBest then GOLD else card.Color
			card.Stroke.Thickness = if isBest then 2.5 else 1.5
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
