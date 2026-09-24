-- The island map, drawn from config so it never goes stale: regions, danger, what loot each
-- danger level drops, exits and their payouts, secrets YOU have found, and whether YOUR
-- strength is enough for each region. Used on the board by the gate (SurfaceGui) and full
-- screen (Menus/Map). Laid out on a fixed 720 x 405 canvas; callers scale it (UIScale).
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

MapView.WIDTH, MapView.HEIGHT = 720, 405

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
local EXIT_COLORS = { Safe = Color3.fromRGB(80, 230, 110), Dangerous = Color3.fromRGB(255, 150, 40), Secret = Color3.fromRGB(190, 110, 255) }

local function px(x: number, z: number): UDim2
	return UDim2.fromOffset((WORLD_R - x) * K, (z + WORLD_R) * K)
end

local function rgb(t): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function stars(danger: number): string
	return Regions.Stars(danger)
end

local function dangerColor(danger: number): Color3
	return ({ Color3.fromRGB(120, 230, 90), Color3.fromRGB(255, 220, 70), Color3.fromRGB(255, 140, 50), Color3.fromRGB(255, 70, 70) })[danger]
		or Color3.new(1, 1, 1)
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
		Size = UDim2.fromOffset(width, 12),
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
				Size = UDim2.fromOffset(w, 12),
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

-- Builds the map into `parent` (a 720 x 405 frame). Returns { Refresh(data) }.
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
		local a, b = px(gate.X, gate.Z), px(finish.X, finish.Z)
		local ax, ay, bx, by = a.X.Offset, a.Y.Offset, b.X.Offset, b.Y.Offset
		local length = math.sqrt((bx - ax) ^ 2 + (by - ay) ^ 2)
		Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset((ax + bx) / 2, (ay + by) / 2),
			Size = UDim2.fromOffset(length, 3),
			Rotation = math.deg(math.atan2(by - ay, bx - ax)),
			BackgroundColor3 = Color3.fromRGB(240, 220, 170),
			BackgroundTransparency = 0.25,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = overlay,
		})
	end
	-- Geysers.
	for _, geyser in WorldLayout.LaunchPads do
		text(overlay, { Text = "⬆", TextSize = 13, Color = rgb(geyser.Color), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(geyser.Position.X, geyser.Position.Z), Size = UDim2.fromOffset(16, 16), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
	end
	-- Exits: safe + dangerous shown, the secret one only as a "?".
	for _, zone in WorldLayout.ExtractionZones do
		local color = EXIT_COLORS[zone.Category] or Color3.new(1, 1, 1)
		local dot = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = px(zone.Position.X, zone.Position.Z),
			Size = UDim2.fromOffset(18, 18),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 8,
			Parent = overlay,
		}, { Kit.corner(UDim.new(0.5, 0)) })
		Kit.stroke(Color3.new(1, 1, 1), 2, 0).Parent = dot
		text(dot, { Text = if zone.Category == "Secret" then "?" else "⌂", TextSize = 12, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(18, 18), XAlign = Enum.TextXAlignment.Center, ZIndex = 9, Outline = 1 })
	end
	-- Secrets you've found (filled in by Refresh).
	local secretMarks = {}
	for _, secret in Regions.Secrets do
		secretMarks[secret.Id] = text(overlay, { Text = "✦", TextSize = 13, Color = Color3.fromRGB(255, 225, 120), AnchorPoint = Vector2.new(0.5, 0.5), Position = px(secret.Position.X, secret.Position.Z), Size = UDim2.fromOffset(16, 16), XAlign = Enum.TextXAlignment.Center, ZIndex = 7 })
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
		text(card, { Text = stars(balance.Danger), TextSize = 10, Color = dangerColor(balance.Danger), Position = UDim2.fromOffset(5, 15), Size = UDim2.fromOffset(44, 11), ZIndex = 12, Outline = false })
		local strength = text(card, { Text = "", TextSize = 10, Position = UDim2.fromOffset(46, 15), Size = UDim2.fromOffset(48, 11), XAlign = Enum.TextXAlignment.Right, ZIndex = 12, Outline = false })
		text(card, { Text = typicalLoot(balance.Danger), TextSize = 9, Position = UDim2.fromOffset(5, 28), Size = UDim2.fromOffset(90, 11), ZIndex = 12, Outline = false })
		cards[area] = { Strength = strength, Recommended = balance.RecommendedStrength }
	end

	-- RIGHT: HOW TO READ IT ------------------------------------------------------------------
	local side = Kit.new("Frame", { Position = UDim2.fromOffset(MAP + 12, 10), Size = UDim2.fromOffset(MapView.WIDTH - MAP - 22, MapView.HEIGHT - 20), BackgroundTransparency = 1, ZIndex = 5, Parent = canvas })
	text(side, { Text = "🗺 PLAN YOUR RUN", Font = Theme.Font.Display, TextSize = 20, Color = Color3.fromRGB(255, 215, 90), Size = UDim2.fromOffset(290, 22), Outline = 1.8 })
	text(side, { Text = "MORE DANGER = RARER LOOT", TextSize = 11, Color = Color3.fromRGB(200, 210, 230), Position = UDim2.fromOffset(0, 26), Size = UDim2.fromOffset(290, 12), Outline = false })
	-- One row per danger level: stars, where, what drops.
	local byDanger: { [number]: { string } } = {}
	for _, area in Regions.Order do
		local danger = GameConfig.Regions[area].Danger
		byDanger[danger] = byDanger[danger] or {}
		local short = Regions.Info[area].Title:gsub("^THE ", ""):gsub("SHIPWRECK ", ""):gsub("GLOWSHROOM ", ""):gsub("ANCIENT ", "")
		table.insert(byDanger[danger], short)
	end
	for danger = 1, #GameConfig.Treasure.RarityByDanger do
		local y = 44 + (danger - 1) * 30
		text(side, { Text = stars(danger), TextSize = 12, Color = dangerColor(danger), Position = UDim2.fromOffset(0, y), Size = UDim2.fromOffset(52, 13) })
		text(side, { Text = table.concat(byDanger[danger] or {}, " • "), TextSize = 10, Color = Color3.fromRGB(235, 240, 250), Position = UDim2.fromOffset(56, y + 1), Size = UDim2.fromOffset(230, 12), Outline = false })
		lootBar(side, danger, UDim2.fromOffset(0, y + 15), 286)
	end
	-- Rarity key under the bars.
	local keyY = 44 + #GameConfig.Treasure.RarityByDanger * 30 + 2
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
	text(side, { Text = "⚡ Boost rings • ⬆ geysers • ✦ secrets you found", TextSize = 10, Color = Color3.fromRGB(190, 205, 255), Position = UDim2.fromOffset(0, footerY + 14), Size = UDim2.fromOffset(290, 12), Outline = false })
	local you = text(side, { Text = "", TextSize = 11, Color = Color3.fromRGB(255, 255, 255), Position = UDim2.fromOffset(0, footerY + 30), Size = UDim2.fromOffset(290, 13), Outline = false })

	local function refresh(data)
		local strength = if data then data.Strength or 0 else 0
		you.Text = ('💪 YOUR STRENGTH <font color="#FFD76A"><b>%s</b></font> • ✔ = you can carry it'):format(Kit.shortNumber(strength))
		for _, card in cards do
			local ready = strength >= card.Recommended
			card.Strength.Text = ('<font color="#%s">%s💪%s</font>'):format(if ready then "78eb78" else "ff9a50", if ready then "✔" else "", Kit.shortNumber(card.Recommended))
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
