-- Overhead name tag in the Roblox "steal" genre layout (Steal a Brainrot / Steal an Egg):
--
--     Gold            <- mutation (only when mutated), in the mutation colour / rainbow
--   Golden Crown      <- name, white
--    Legendary        <- rarity, in the rarity colour (Secret / OG: animated gradient)
--     $1,500/s        <- income, green
--
-- Chunky cartoon font with thick black outlines, fixed pixel size, and it only appears when
-- you are close (MaxDistance): the treasure's look is the first read, the tag confirms it.

local Rarities = require(script.Parent.Config.Rarities)
local Treasures = require(script.Parent.Config.Treasures)
local Mutations = require(script.Parent.Config.Mutations)
local Economy = require(script.Parent.Logic.Economy)

local CollectionService = game:GetService("CollectionService")

local TreasureLabel = {}

-- UIGradients with this tag slide across their text on every client (Controllers/Ambience).
TreasureLabel.SHIMMER_TAG = "RarityShimmer"

local FONT = Enum.Font.FredokaOne
local BLACK = Color3.new(0, 0, 0)
local CASH = Color3.fromRGB(80, 255, 90)
local LINE = 24

local function formatCash(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (s:gsub("^,", ""))
end

local function rainbow(label: TextLabel)
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 40)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(90, 255, 90)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(60, 200, 255)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(160, 90, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 80, 200)),
	})
	gradient.Parent = label
end

local function sequence(colors: { Color3 }): ColorSequence
	local points = {}
	for i, c in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

local function shimmer(parent: Instance, colors: { Color3 })
	local gradient = Instance.new("UIGradient")
	gradient.Name = "RarityGradient"
	gradient.Color = sequence(colors)
	gradient.Parent = parent
	CollectionService:AddTag(gradient, TreasureLabel.SHIMMER_TAG)
end

-- Colours a rarity text label (name tags, menus): rarity colour + outline, and the animated
-- gradient for Secret (black/white) and OG (gold shimmer).
function TreasureLabel.StyleRarity(label: TextLabel, rarity: string)
	local color, stroke = Rarities.LabelColors(rarity)
	label.TextColor3 = color
	local info = Rarities.Info[rarity]
	local outline = label:FindFirstChildOfClass("UIStroke")
	if not outline and info and info.Gradient then
		-- A black/white name needs its (inverse) outline to read on any background.
		outline = Instance.new("UIStroke")
		outline.Thickness = 1.5
		outline.Parent = label
	end
	if outline then
		outline.Color = stroke
	end
	if info and info.Gradient then
		shimmer(label, info.Gradient)
		if outline and info.StrokeGradient then
			shimmer(outline, info.StrokeGradient)
		end
	end
end

local function line(parent: Instance, order: number, text: string, color: Color3, stroke: Color3, size: number)
	local label = Instance.new("TextLabel")
	label.Name = "Line" .. order
	label.LayoutOrder = order
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1, 0, 0, size)
	label.Font = FONT
	label.TextSize = size
	label.TextColor3 = color
	label.Text = text
	label.TextWrapped = false
	local outline = Instance.new("UIStroke")
	outline.Color = stroke
	outline.Thickness = 2
	outline.Parent = label
	label.Parent = parent
	return label
end

-- opts: { MaxDistance, Height (studs above the handle), AlwaysOnTop, Income (override $/s) }
function TreasureLabel.Build(def, mutation: string?, opts): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "TreasureTag"
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.MaxDistance = opts.MaxDistance or 40
	gui.AlwaysOnTop = opts.AlwaysOnTop == true
	gui.StudsOffsetWorldSpace = Vector3.new(0, opts.Height or 4, 0)

	local frame = Instance.new("Frame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.Parent = frame

	local lines = 3
	local mutationInfo = Mutations.Get(mutation)
	if mutationInfo then
		lines += 1
		local label = line(frame, 1, mutation :: string, Mutations.Color(mutationInfo.Color), BLACK, LINE - 2)
		if mutationInfo.Rainbow then
			label.TextColor3 = Color3.new(1, 1, 1)
			rainbow(label)
		end
	end
	line(frame, 2, def.Name, Color3.new(1, 1, 1), BLACK, LINE)
	local rarityLabel = line(frame, 3, def.Rarity, Color3.new(1, 1, 1), BLACK, LINE - 2)
	TreasureLabel.StyleRarity(rarityLabel, def.Rarity)
	local income = opts.Income or Economy.Income(def, mutation)
	line(frame, 4, formatCash(income) .. "/s", CASH, BLACK, LINE - 2)
	local effect = def.SpecialEffect and Treasures.EffectLabels[def.SpecialEffect]
	if effect then
		lines += 1
		line(frame, 5, effect, Color3.fromRGB(255, 230, 150), BLACK, LINE - 6)
	end

	gui.Size = UDim2.fromOffset(240, lines * LINE)
	return gui
end

return TreasureLabel
