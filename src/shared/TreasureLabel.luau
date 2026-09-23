-- Overhead name tag in the Roblox "steal" genre layout (Steal a Brainrot / Steal an Egg):
--
--     Gold            <- mutation (only when mutated), in the mutation colour / rainbow
--   Golden Crown      <- name, white
--    Legendary        <- rarity, in the rarity colour (Secret: black text, white outline)
--     $1,500/s        <- income, green
--
-- Chunky cartoon font with thick black outlines, fixed pixel size, and it only appears when
-- you are close (MaxDistance): the treasure's look is the first read, the tag confirms it.

local Rarities = require(script.Parent.Config.Rarities)
local Mutations = require(script.Parent.Config.Mutations)
local Economy = require(script.Parent.Logic.Economy)

local TreasureLabel = {}

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
	local rarityColor, rarityStroke = Rarities.LabelColors(def.Rarity)
	local rarityLabel = line(frame, 3, def.Rarity, rarityColor, rarityStroke, LINE - 2)
	if Rarities.Info[def.Rarity] and Rarities.Info[def.Rarity].Rainbow and not Rarities.Info[def.Rarity].LabelColor then
		rainbow(rarityLabel)
	end
	local income = opts.Income or Economy.Income(def, mutation)
	line(frame, 4, formatCash(income) .. "/s", CASH, BLACK, LINE - 2)

	gui.Size = UDim2.fromOffset(240, lines * LINE)
	return gui
end

return TreasureLabel
