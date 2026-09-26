-- Default HUD: stats (top-left), objective / carried treasure (top-centre), navigation hint,
-- extraction bar, danger status, action cluster (attack + 3 gadget slots, bottom-right).
-- Event-driven: rebuilds only on state changes; a light 10 Hz loop handles nav + cooldowns.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gadgets = require(Shared.Config.Gadgets)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local WorldLayout = require(Shared.Config.WorldLayout)
local Carry = require(Shared.Logic.Carry)
local Economy = require(Shared.Logic.Economy)
local DayNight = require(Shared.Logic.DayNight)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local MusicController = require(script.Parent.MusicController)
local ClientState = require(script.Parent.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)
local BatFx = require(script.Parent.BatFx)

local HUD = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local refs: { [string]: any } = {}
local navTarget: { Name: string, Position: Vector3 }? = nil
local extraction: { StartedAt: number, Duration: number, ZoneName: string, Category: string }? = nil
local secretKnown = false
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

HUD.OpenMenu = nil :: ((string) -> ())? -- injected by Main

local AREA_COLORS = {
	["TREASURE DISTRICT"] = Theme.Color.Safe,
	["THE WILDS"] = Color3.fromRGB(150, 220, 120),
	["ANCIENT RUINS"] = Theme.Color.Gold,
	["SHIPWRECK COAST"] = Theme.Color.Info,
	["THE FALLS"] = Color3.fromRGB(140, 230, 255),
	["FROSTPEAK"] = Color3.fromRGB(190, 235, 255),
	["GLOWSHROOM MARSH"] = Color3.fromRGB(200, 130, 255),
	["EMBERFALL"] = Color3.fromRGB(255, 120, 60),
	["RIMEHEART"] = Color3.fromRGB(160, 225, 255),
	["STARFALL ISLES"] = Color3.fromRGB(200, 150, 255),
}

local function rarityColor(rarity: string): Color3
	return Rarities.Info[rarity] and Rarities.Info[rarity].Color or Theme.Color.Text
end

-- LAYOUT ----------------------------------------------------------------------

local function buildStats()
	local stack = Kit.new("Frame", {
		Name = "Stats",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(12, 10),
		Size = UDim2.fromOffset(230, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 6, Enum.HorizontalAlignment.Left) })
	refs.StatsStack = stack

	local function pill(name: string, icon: string, color: Color3, order: number)
		local frame = Kit.panel({
			Name = name,
			Size = UDim2.fromOffset(160, 34),
			LayoutOrder = order,
			Radius = Theme.Radius.Round,
			Parent = stack,
		})
		Kit.label({
			Text = icon,
			Size = UDim2.fromOffset(34, 34),
			TextSize = 18,
			Parent = frame,
		})
		local value = Kit.label({
			Name = "Value",
			Text = "0",
			Position = UDim2.fromOffset(34, 0),
			Size = UDim2.new(1, -42, 1, 0),
			Font = Theme.Font.Display,
			TextSize = 20,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		return value
	end
	refs.Strength = pill("Strength", "💪", Theme.Color.Strength, 1)
	-- Music mute toggle, tucked next to the Strength pill (outside the list layout's flow).
	local musicButton = Kit.button({
		Name = "MusicToggle",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 8, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		Text = "🔊",
		TextSize = 18,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = Theme.Transparency.Panel,
		Radius = Theme.Radius.Round,
		Parent = refs.Strength.Parent,
	}, function()
		MusicController.ToggleMute()
	end)
	local function syncMusicIcon()
		musicButton.Text = if player:GetAttribute("MusicMuted") == true then "🔇" else "🔊"
	end
	player:GetAttributeChangedSignal("MusicMuted"):Connect(syncMusicIcon)
	syncMusicIcon()
	-- Feedback (💬) sits right beside it: small, always reachable, never in the way.
	Kit.button({
		Name = "FeedbackButton",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(1, 50, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		Text = "💬",
		TextSize = 18,
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = Theme.Transparency.Panel,
		Radius = Theme.Radius.Round,
		Parent = refs.Strength.Parent,
	}, function()
		if HUD.OpenMenu then
			HUD.OpenMenu("Feedback")
		end
	end)
	refs.Cash = pill("Cash", "💰", Theme.Color.Cash, 2)
	-- Vault income + day/night clock: "your money machine" is always in view.
	refs.Income = Kit.label({
		Name = "Income",
		Text = "",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(260, 18),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Cash,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		RichText = true,
		Parent = stack,
	})
	refs.Clock = Kit.label({
		Name = "Clock",
		Text = "",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(260, 18),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		Parent = stack,
	})
	refs.Area = Kit.label({
		Name = "Area",
		Text = "TREASURE DISTRICT • SAFE",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(260, 20),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.75,
		Parent = stack,
	})
	refs.Ascension = Kit.label({
		Name = "Ascension",
		Text = "",
		LayoutOrder = 6,
		Size = UDim2.fromOffset(260, 18),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Secret,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextStrokeTransparency = 0.5,
		Visible = false,
		Parent = stack,
	})
end

local function buildMenuButtons()
	local column = Kit.new("Frame", {
		Name = "MenuButtons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.62, 0),
		Size = UDim2.fromOffset(64, 160),
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 10, Enum.HorizontalAlignment.Left) })
	-- Vault and Gadget Shop are NOT here on purpose: you manage them at your Vault terminal and
	-- the shop counter in the District.
	for i, entry in { { "Collection", "📖" }, { "Store", "💎" } } do
		local button = Kit.button({
			Name = entry[1],
			Text = "",
			Size = UDim2.fromOffset(60, 60),
			BackgroundColor3 = Theme.Color.Panel,
			BackgroundTransparency = Theme.Transparency.Panel,
			Radius = Theme.Radius.Large,
			LayoutOrder = i,
			Parent = column,
		}, function()
			if HUD.OpenMenu then
				HUD.OpenMenu(entry[1])
			end
		end)
		Kit.stroke().Parent = button
		Kit.label({ Text = entry[2], Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 4), TextSize = 26, Parent = button })
		local caption = Kit.label({
			Text = entry[1]:upper(),
			Size = UDim2.new(1, -6, 0, 12),
			Position = UDim2.new(0, 3, 1, -16),
			TextScaled = true,
			Font = Theme.Font.Black,
			TextColor3 = Theme.Color.TextDim,
			Parent = button,
		})
		Kit.new("UITextSizeConstraint", { MaxTextSize = 10, Parent = caption })
		refs["Menu" .. entry[1]] = button
	end
	-- The store stands out (gold rim) without shouting.
	local storeStroke = refs.MenuStore:FindFirstChildOfClass("UIStroke")
	if storeStroke then
		storeStroke.Color = Theme.Color.Gold
		storeStroke.Transparency = 0.1
		storeStroke.Thickness = 2
	end
end

local function buildObjective()
	-- Objective card + nav hint stack vertically so the hint always sits under the card.
	local topStack = Kit.new("Frame", {
		Name = "TopCenter",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 8),
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })
	HUD.TopStack = topStack
	-- Objective tracker: slim card under the stats (left), out of the player's line of sight.
	-- Expands for a few seconds when the goal changes, then collapses to one line; tap to toggle.
	local card = Kit.panel({
		Name = "Objective",
		LayoutOrder = 7,
		Size = UDim2.fromOffset(220, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.4,
		Parent = refs.StatsStack,
	}, { Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left), Kit.padding(5, 10) })
	card.Active = true
	card.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			HUD.SetObjectiveExpanded(not refs.ObjExpanded)
		end
	end)
	refs.ObjectiveCard = card
	refs.ObjHeader = Kit.label({ Name = "Header", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 13), Font = Theme.Font.Black, TextSize = 10, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = card })
	refs.ObjTitle = Kit.label({ Name = "Title", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Display, TextSize = 16, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = card })
	refs.ObjLine1 = Kit.label({ Name = "Line1", LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 15), Font = Theme.Font.Bold, TextSize = 12, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = card })
	local barBack = Kit.new("Frame", {
		Name = "Bar",
		LayoutOrder = 4,
		Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Parent = card,
	}, { Kit.corner(Theme.Radius.Round) })
	refs.ObjBar = barBack
	refs.ObjBarFill = Kit.new("Frame", {
		Name = "Fill",
		Size = UDim2.fromScale(0.5, 1),
		BackgroundColor3 = Theme.Color.Strength,
		BorderSizePixel = 0,
		Parent = barBack,
	}, { Kit.corner(Theme.Radius.Round) })
	refs.ObjLine2 = Kit.label({ Name = "Line2", LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 15), Font = Theme.Font.Black, TextSize = 12, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = card })

	refs.Nav = Kit.panel({
		Name = "Nav",
		LayoutOrder = 3,
		Size = UDim2.fromOffset(260, 34),
		Radius = Theme.Radius.Round,
		BackgroundTransparency = Theme.Transparency.PanelSoft,
		Visible = false,
		Parent = topStack,
	})
	refs.NavArrow = Kit.label({ Name = "Arrow", Text = "▲", Size = UDim2.fromOffset(34, 34), TextSize = 22, TextColor3 = Theme.Color.Gold, Parent = refs.Nav })
	refs.NavText = Kit.label({ Name = "Text", Text = "", Position = UDim2.fromOffset(34, 0), Size = UDim2.new(1, -44, 1, 0), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextXAlignment = Enum.TextXAlignment.Left, Parent = refs.Nav })
end

local function buildStatus()
	refs.Status = Kit.label({
		Name = "Status",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.44),
		Size = UDim2.fromOffset(560, 44),
		Font = Theme.Font.Display,
		TextSize = Theme.TextSize.Hero,
		TextColor3 = Theme.Color.Danger,
		TextStrokeTransparency = 0.2,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	refs.StatusSub = Kit.label({
		Name = "StatusSub",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 0, 0.44, 32),
		Size = UDim2.fromOffset(560, 22),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Body,
		TextStrokeTransparency = 0.3,
		Text = "",
		Visible = false,
		Parent = gui,
	})
	-- Danger vignette (edge glow) for Shaken / Knocked
	refs.Vignette = Kit.new("Frame", {
		Name = "Vignette",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 0,
		Parent = gui,
	})
	refs.VignetteStroke = Kit.new("UIStroke", {
		Color = Theme.Color.Danger,
		Thickness = 22,
		Transparency = 1,
		Parent = refs.Vignette,
	})
end

-- Small centre reticle, only while an aimed gadget (Grapple Hook) is equipped.
local function buildReticle()
	refs.Reticle = Kit.label({
		Name = "Reticle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(24, 24),
		Text = "◎",
		TextSize = 22,
		TextColor3 = Color3.new(1, 1, 1),
		TextTransparency = 0.25,
		TextStrokeTransparency = 0.5,
		Visible = false,
		Parent = gui,
	})
end

local function buildExtractionBar()
	local frame = Kit.panel({
		Name = "Extraction",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -150),
		Size = UDim2.fromOffset(420, 86),
		Visible = false,
		Parent = gui,
	}, { Kit.padding(10, 16) })
	refs.Extraction = frame
	refs.ExtTitle = Kit.label({ Text = "EXTRACTING...", Size = UDim2.new(1, -70, 0, 26), Font = Theme.Font.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
	refs.ExtTime = Kit.label({ Text = "10.0", Position = UDim2.new(1, -70, 0, 0), Size = UDim2.fromOffset(70, 26), Font = Theme.Font.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Right, TextColor3 = Theme.Color.Gold, Parent = frame })
	local back = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 32),
		Size = UDim2.new(1, 0, 0, 14),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Parent = frame,
	}, { Kit.corner(Theme.Radius.Round) })
	refs.ExtFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.Safe, BorderSizePixel = 0, Parent = back }, { Kit.corner(Theme.Radius.Round) })
	refs.ExtZone = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, Parent = frame })
end

-- Action cluster: attack + 3 gadget slots, clear of the mobile jump button.
local function buildActions()
	local right = if isTouch then 175 else 24
	local cluster = Kit.new("Frame", {
		Name = "Actions",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -right, 1, -18),
		Size = UDim2.fromOffset(250, 210),
		Parent = gui,
	})
	local attack = Kit.button({
		Name = "Attack",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(96, 96),
		BackgroundColor3 = Theme.Color.Danger,
		TextColor3 = Theme.Color.Text,
		Radius = Theme.Radius.Round,
		Parent = cluster,
	}, function()
		HUD.Attack()
	end)
	Kit.stroke(Color3.new(1, 1, 1), 3, 0.3).Parent = attack
	Kit.label({ Text = "🏏", Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 12), TextSize = 38, Parent = attack })
	refs.AttackLabel = Kit.label({ Text = "SLAP", Size = UDim2.new(1, 0, 0, 20), Position = UDim2.new(0, 0, 1, -32), TextSize = 16, Font = Theme.Font.Black, Parent = attack })
	refs.Attack = attack
	-- Put the bat on your back (SLAP draws it again). Sits on SLAP's rim; H on keyboard.
	local sheathe = Kit.button({
		Name = "Sheathe",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.86, 0.1),
		Size = UDim2.fromOffset(46, 26),
		Text = "HIDE",
		TextSize = 12,
		Font = Theme.Font.Black,
		BackgroundColor3 = Theme.Color.ButtonAlt,
		TextColor3 = Theme.Color.Text,
		Radius = Theme.Radius.Round,
		ZIndex = 5,
		Parent = attack,
	}, function()
		HUD.SheatheBat()
	end)
	Kit.stroke(Color3.new(1, 1, 1), 1.5, 0.4).Parent = sheathe
	refs.Sheathe = sheathe

	-- DROP: only while carrying. Separate from SLAP so mashing attack never drops your loot.
	local drop = Kit.button({
		Name = "Drop",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -196, 1, -6),
		Size = UDim2.fromOffset(72, 72),
		BackgroundColor3 = Theme.Color.ButtonAlt,
		TextColor3 = Theme.Color.Text,
		Radius = Theme.Radius.Round,
		Visible = false,
		Parent = cluster,
	}, function()
		HUD.DropTreasure()
	end)
	Kit.stroke(Theme.Color.Warn, 2, 0.2).Parent = drop
	Kit.label({ Text = "📦", Size = UDim2.new(1, 0, 0, 34), Position = UDim2.fromOffset(0, 8), TextSize = 28, Parent = drop })
	Kit.label({ Text = if isTouch then "DROP" else "DROP [G]", Size = UDim2.new(1, 0, 0, 16), Position = UDim2.new(0, 0, 1, -24), TextSize = 12, Font = Theme.Font.Black, Parent = drop })
	refs.Drop = drop

	refs.Slots = {}
	local positions = {
		UDim2.new(1, -118, 1, -2),
		UDim2.new(1, -108, 1, -84),
		UDim2.new(1, -32, 1, -112),
	}
	for slot = 1, GameConfig.Gadgets.Slots do
		local button = Kit.button({
			Name = "Gadget" .. slot,
			AnchorPoint = Vector2.new(1, 1),
			Position = positions[slot],
			Size = UDim2.fromOffset(68, 68),
			BackgroundColor3 = Theme.Color.Panel,
			BackgroundTransparency = Theme.Transparency.Panel,
			Radius = Theme.Radius.Round,
			ClipsDescendants = true,
			Parent = cluster,
		}, function()
			HUD.UseGadget(slot)
		end)
		Kit.stroke(Theme.Color.Gold, 2, 0.4).Parent = button
		local icon = Kit.label({ Name = "Icon", Text = "+", Size = UDim2.fromScale(1, 1), TextSize = 32, Parent = button })
		local cooldown = Kit.new("Frame", {
			Name = "Cooldown",
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BackgroundTransparency = 0.35,
			BorderSizePixel = 0,
			Visible = false,
			ZIndex = 2,
			Parent = button,
		}, { Kit.corner(Theme.Radius.Round) })
		local cooldownGradient = Kit.new("UIGradient", { Rotation = 90, Parent = cooldown })
		local timer = Kit.label({ Name = "Timer", Text = "", Size = UDim2.fromScale(1, 1), Font = Theme.Font.Display, TextSize = 24, ZIndex = 3, Parent = button })
		local key = Kit.label({
			Name = "Key",
			Text = if isTouch then "" else tostring(slot),
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, 0, 0, 2),
			Size = UDim2.fromOffset(20, 14),
			TextSize = 11,
			Font = Theme.Font.Black,
			TextColor3 = Theme.Color.TextDim,
			ZIndex = 3,
			Parent = button,
		})
		refs.Slots[slot] =
			{ Button = button, Icon = icon, Cooldown = cooldown, Gradient = cooldownGradient, Timer = timer, Key = key }
	end
end

-- STATE -> UI --------------------------------------------------------------------

local function nearestExtraction(position: Vector3)
	local best, bestDistance = nil, math.huge
	for _, zone in WorldLayout.ExtractionZones do
		if zone.Category ~= "Secret" or secretKnown then
			local d = (zone.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = zone, d
			end
		end
	end
	return best
end

local function nearestTreasure(position: Vector3, maxRank: number?)
	local folder = workspace:FindFirstChild("Treasures")
	if not folder then
		return nil
	end
	local best, bestDistance = nil, math.huge
	for _, model in folder:GetChildren() do
		local state = model:GetAttribute("State")
		local primary = (model :: Model).PrimaryPart
		if primary and (state == "World" or state == "Dropped") then
			local rank = Rarities.Rank(model:GetAttribute("Rarity") or "Common")
			if not maxRank or rank <= maxRank then
				local d = (primary.Position - position).Magnitude
				if d < bestDistance then
					best, bestDistance = primary, d
				end
			end
		end
	end
	return best
end

local function vaultNav()
	local plotIndex = player:GetAttribute("VaultPlot")
	local plotFolder = workspace:FindFirstChild("Vaults", true)
	local plot = plotFolder and plotIndex and plotFolder:FindFirstChild("Vault" .. tostring(plotIndex))
	local center = plot and plot:GetAttribute("VaultCenter")
	return if typeof(center) == "Vector3" then { Name = "YOUR VAULT", Position = center } else nil
end

local function updateClock(serverNow: number)
	local state = DayNight.State(serverNow)
	local left = math.ceil(state.SecondsLeft)
	local clock = ("%d:%02d"):format(left // 60, left % 60)
	if state.IsNight then
		refs.Clock.Text = ("🌙 NIGHT • NEW LOOT • %s"):format(clock)
		refs.Clock.TextColor3 = Color3.fromRGB(170, 185, 255)
	else
		refs.Clock.Text = ("☀ DAY • NIGHT IN %s"):format(clock)
		-- Last minute of the day: turn red, carried loot is about to be lost.
		refs.Clock.TextColor3 = if left <= 60 then Theme.Color.Danger else Theme.Color.Gold
	end
	local income = player:GetAttribute("VaultIncome")
	local streak = tonumber(player:GetAttribute("Streak")) or 0
	local hasIncome = type(income) == "number" and income > 0
	refs.Income.Visible = hasIncome or streak >= 2
	local parts = {}
	if hasIncome then
		table.insert(parts, ("📈 VAULT +%s/s"):format(Kit.shortCash(income :: number)))
	end
	if streak >= 2 then
		table.insert(parts, ('<font color="#ff9646">🔥 STREAK %d</font>'):format(streak))
	end
	refs.Income.Text = table.concat(parts, "  •  ")
end

local function nextTreasureGoal(data)
	local best = nil
	for _, def in Treasures.List do
		local entry = data.Collection[def.Id]
		if (not entry or not entry.Discovered) and def.Rarity ~= "Secret" then
			if not best or def.Value < best.Value then
				best = def
			end
		end
	end
	return best
end

local AREA_NAMES = { Wilds = "THE WILDS", Ruins = "THE ANCIENT RUINS", Coast = "SHIPWRECK COAST", Falls = "THE FALLS" }

-- Loot mostly spawns on the night wave: say whether the goal treasure is out there right now.
local function goalWhere(goal): string
	local area = AREA_NAMES[goal.SpawnArea] or goal.SpawnArea:upper()
	if DayNight.IsNight(workspace:GetServerTimeNow()) then
		return ("▶ THE WILDS OPEN AT DAWN • SEARCH %s"):format(area)
	end
	local folder = workspace:FindFirstChild("Treasures")
	if folder then
		for _, model in folder:GetChildren() do
			if model:GetAttribute("TreasureId") == goal.Id and model:GetAttribute("State") ~= "Carried" then
				return ("▶ ONE IS OUT NOW IN %s!"):format(area)
			end
		end
	end
	return ("▶ SPAWNS AT NIGHT IN %s"):format(area)
end

local objectiveDetails = { Line1 = false, Line2 = false, Bar = false }
local objectiveKey = ""
local pinnedExpanded = false -- carrying: always show details

function HUD.SetObjectiveExpanded(expanded: boolean)
	refs.ObjExpanded = expanded
	local show = expanded or pinnedExpanded
	refs.ObjLine1.Visible = show and objectiveDetails.Line1
	refs.ObjLine2.Visible = show and objectiveDetails.Line2
	refs.ObjBar.Visible = show and objectiveDetails.Bar
end

local function setObjective(header: string, title: string, titleColor: Color3?, line1: string?, line2: string?, bar: number?, barColor: Color3?)
	refs.ObjHeader.Text = header
	refs.ObjTitle.Text = title
	refs.ObjTitle.TextColor3 = titleColor or Theme.Color.Text
	refs.ObjLine1.Text = line1 or ""
	refs.ObjLine2.Text = line2 or ""
	objectiveDetails.Line1 = line1 ~= nil
	objectiveDetails.Line2 = line2 ~= nil
	objectiveDetails.Bar = bar ~= nil
	if bar then
		refs.ObjBarFill.Size = UDim2.fromScale(math.clamp(bar, 0.02, 1), 1)
		refs.ObjBarFill.BackgroundColor3 = barColor or Theme.Color.Strength
	end
	-- A new goal pops open briefly, then tucks away.
	local key = header .. "|" .. title
	if key ~= objectiveKey then
		objectiveKey = key
		HUD.SetObjectiveExpanded(true)
		Kit.pulse(refs.ObjectiveCard)
		local token = {}
		refs.ObjCollapseToken = token
		task.delay(6, function()
			if refs.ObjCollapseToken == token then
				HUD.SetObjectiveExpanded(false)
			end
		end)
	else
		HUD.SetObjectiveExpanded(refs.ObjExpanded == true)
	end
end

local warnedEventEnd = 0 -- EventEndsAt we already gave the 10-second heads-up for

local function refreshObjective()
	local data = ClientState.Data
	if not data then
		return
	end
	local carrying = ClientState.Carrying()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local position = if root then root.Position else WorldLayout.Spawn

	pinnedExpanded = carrying ~= nil
	if carrying then
		local info = Rarities.Info[carrying.Rarity]
		local speed = player:GetAttribute("CarrySpeed") or 1
		local stability = ClientState.Stability()
		local burden = Carry.BurdenLabel(speed)
		local line2 = ("SPEED %d%% • %s"):format(math.floor(speed * 100 + 0.5), burden)
		if stability == "Shaken" then
			line2 = "<font color=\"#ff4650\">⚠ SHAKEN — ONE MORE HIT AND YOU DROP IT</font>"
		end
		-- No name / rarity / income for the carrier (others see the tag over your head): the
		-- panel is about getting it home.
		setObjective(
			"🎒 CARRYING TREASURE",
			"GET IT HOME!",
			info.Color,
			("WEIGHT %s"):format(Kit.bigNumber(carrying.Weight)),
			line2,
			speed,
			if speed >= 0.75 then Theme.Color.Safe elseif speed >= 0.45 then Theme.Color.Warn else Theme.Color.Danger
		)
		local zone = nearestExtraction(position)
		navTarget = zone and { Name = zone.Name:upper(), Position = zone.Position }
		return
	end

	if not ClientState.Milestone("FirstTraining") then
		setObjective("STEP 1 • GET STRONGER", "LIFT AT THE BENCH PRESS", Theme.Color.Strength, "Stronger = carry heavy treasure faster", nil)
		navTarget = { Name = "STRENGTH GYM", Position = WorldLayout.Gym.Origin }
		return
	end
	if not ClientState.Milestone("FirstExtraction") then
		local target = nearestTreasure(position, 2)
		local night = DayNight.State(workspace:GetServerTimeNow())
		if night.IsNight then
			local left = math.ceil(night.SecondsLeft)
			setObjective("STEP 2 • WAIT FOR DAWN", "THE WILDS ARE CLOSED", Theme.Color.Info, ("New treasure is spawning • Gate opens in %d:%02d"):format(left // 60, left % 60), nil)
		elseif ClientState.Milestone("FirstTreasure") then
			setObjective("STEP 3 • PICK IT UP", "GRAB A TREASURE", Theme.Color.Gold, "Carry it to an EXTRACTION beam to bank it", nil)
		else
			setObjective("STEP 2 • EXPLORE", "FIND A TREASURE", Theme.Color.Gold, "Head through the gate into THE WILDS", nil)
		end
		navTarget = if target then { Name = "TREASURE", Position = target.Position } else { Name = "THE WILDS", Position = WorldLayout.District.Gate }
		return
	end

	-- Step 4: the new economy's key idea - your Vault pays you, walk over and collect it.
	if not ClientState.Milestone("FirstCollect") then
		setObjective("STEP 4 • GET PAID", "COLLECT YOUR CASH", Theme.Color.Cash, "Your treasure earns $ every second", "▶ STEP ON THE GREEN PAD AT YOUR VAULT", nil)
		navTarget = vaultNav()
		return
	end

	local owned = 0
	for _ in data.OwnedGadgets do
		owned += 1
	end
	local cheapest = Gadgets.Get("speed_soda")
	-- Only ever for someone who has never had a gadget: Ascension wipes gadgets, but it must not
	-- replay the tutorial (milestones persist; older saves without one are covered by Ascension).
	local neverHadGadget = not ClientState.Milestone("FirstGadgetBought") and not ClientState.Milestone("FirstGadgetUse") and (data.Ascension or 0) == 0
	if owned == 0 and neverHadGadget and cheapest and data.Cash >= cheapest.Price then
		setObjective("NEW • GADGETS", "BUY YOUR FIRST GADGET", Theme.Color.Info, ("You can afford the %s!"):format(cheapest.Name:upper()), nil)
		navTarget = { Name = "GADGET SHOP", Position = WorldLayout.Shop }
		return
	end

	if
		data.Strength >= GameConfig.GetAscensionRequirement(data.Ascension)
		and data.Cash >= GameConfig.GetAscensionCost(data.Ascension + 1)
	then
		setObjective("✨ READY", "ASCENSION AVAILABLE", Theme.Color.Secret, ("Permanent x%.2f Cash multiplier"):format(GameConfig.GetAscensionMultiplier(data.Ascension + 1)), nil)
		navTarget = { Name = "ASCENSION ALTAR", Position = WorldLayout.AscensionAltar }
		return
	end

	-- Full Vault and the next tier is affordable: growing it is the best move right now.
	local tier = GameConfig.Vault.Tiers[data.Vault.Tier] or GameConfig.Vault.Tiers[1]
	local nextTier = GameConfig.Vault.Tiers[data.Vault.Tier + 1]
	local used = 0
	for _ in data.Vault.Displays do
		used += 1
	end
	if used >= tier.Slots and nextTier and nextTier.Enabled and data.Cash >= nextTier.Price then
		setObjective("VAULT FULL", "UPGRADE YOUR VAULT", Theme.Color.Gold, ("%d → %d pedestals • %s"):format(tier.Slots, nextTier.Slots, Kit.shortCash(nextTier.Price)), "▶ OPEN THE VAULT MENU", nil)
		navTarget = vaultNav()
		return
	end

	-- A better bench you can afford (and have the Ascension for): faster training.
	for _, bench in GameConfig.Training.Benches do
		if bench.Price > 0 and not data.OwnedBenches[bench.Id] and data.Ascension >= bench.RequiredAscension and data.Cash >= bench.Price then
			setObjective("UPGRADE", ("UNLOCK THE %s"):format(bench.Name:upper()), Theme.Color.Strength, ("+%d 💪 per rep • %s"):format(bench.RepGain, Kit.shortCash(bench.Price)), "▶ LIE DOWN ON IT AT THE GYM", nil)
			navTarget = { Name = "STRENGTH GYM", Position = WorldLayout.Gym.Origin }
			return
		end
	end

	local goal = nextTreasureGoal(data)
	if not goal then
		setObjective("COLLECTION COMPLETE", "HUNT THE SECRET", Theme.Color.Secret, "Legends speak of the Heart of the Island...", nil)
		navTarget = nil
		return
	end
	local recommended = Carry.RecommendedStrength(goal.Weight, GameConfig.Carry)
	local strength = math.floor(data.Strength)
	local needsTraining = strength < recommended
	setObjective(
		"NEXT TREASURE",
		goal.Name:upper(),
		rarityColor(goal.Rarity),
		if needsTraining
			then ("<font color=\"#78eb78\">%s/s</font>  •  STRENGTH %s / %s"):format(Kit.shortCash(Economy.Income(goal)), Kit.bigNumber(strength), Kit.bigNumber(recommended))
			else ("<font color=\"#78eb78\">%s/s</font>  •  WEIGHT %s"):format(Kit.shortCash(Economy.Income(goal)), Kit.bigNumber(goal.Weight)),
		if needsTraining then "▶ TRAIN" else goalWhere(goal),
		if needsTraining then strength / recommended else nil,
		if needsTraining then Theme.Color.Strength else Theme.Color.Safe
	)
	-- Past the tutorial there is no GPS target: events are announced (a banner at the start, one
	-- alert near the end) and players discover the world instead of following a marker.
	navTarget = nil
end
HUD.RefreshObjective = refreshObjective

-- Where the objective is pointing right now ({ Name, Position } or nil), for Controllers/Guide.
function HUD.NavTarget()
	return navTarget
end

local function refreshStats(data, previous)
	refs.Strength.Text = Kit.bigNumber(data.Strength)
	refs.Cash.Text = Kit.formatCash(data.Cash)
	if previous then
		if data.Cash ~= previous.Cash then
			Kit.pulse(refs.Cash.Parent)
		end
		if math.floor(data.Strength) ~= math.floor(previous.Strength) then
			Kit.pulse(refs.Strength.Parent)
		end
		local gained = math.floor(data.Strength) - math.floor(previous.Strength)
		if gained > 0 then
			-- "+N" flies out of the Strength pill so every gain is felt, whatever its source.
			local pill = refs.Strength.Parent :: GuiObject
			local fly = Kit.label({
				Text = "+" .. Kit.bigNumber(gained),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(1, 8, 0.5, 0),
				Size = UDim2.fromOffset(120, 26),
				Font = Theme.Font.Display,
				TextSize = 22,
				TextColor3 = Theme.Color.Strength,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextWrapped = false,
				Parent = pill,
			})
			Kit.textStroke(Color3.fromRGB(40, 22, 8), 2).Parent = fly
			local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			Kit.tween(fly, info, { Position = UDim2.new(1, 30, 0.5, 0), TextTransparency = 1 })
			Kit.tween(fly:FindFirstChildOfClass("UIStroke") :: UIStroke, info, { Transparency = 1 })
			task.delay(0.95, function()
				fly:Destroy()
			end)
		end
	end
	refs.Ascension.Visible = data.Ascension > 0
	refs.Ascension.Text = ("✨ %s • x%.2f CASH"):format((data.SelectedTitle or ""):upper(), GameConfig.GetAscensionMultiplier(data.Ascension))
end

local function refreshSlots()
	local data = ClientState.Data
	if not data then
		return
	end
	local carrying = ClientState.Carrying() ~= nil
	for slot, ui in refs.Slots do
		local id = data.EquippedGadgets[slot]
		local def = id and id ~= "" and Gadgets.Get(id)
		if def then
			ui.Icon.Text = def.Icon
			local blocked = carrying and not def.CanUseWhileCarrying
			ui.Icon.TextTransparency = if blocked then 0.6 else 0
			ui.Button.BackgroundColor3 = if blocked then Theme.Color.Disabled else Theme.Color.Panel
		else
			ui.Icon.Text = "+"
			ui.Icon.TextTransparency = 0.4
			ui.Button.BackgroundColor3 = Theme.Color.Panel
		end
	end
	local aimed = false
	for slot = 1, GameConfig.Gadgets.Slots do
		local def = Gadgets.Get(data.EquippedGadgets[slot] or "")
		if def and def.NeedsAim then
			aimed = true
		end
	end
	refs.Reticle.Visible = aimed
	refs.Drop.Visible = carrying ~= nil
	-- HIDE only while the bat is in your hand (sheathed: SLAP is how you draw it).
	refs.Sheathe.Visible = not carrying and not (data.Settings and data.Settings.SheatheBat)
	refs.AttackLabel.Text = if carrying and not GameConfig.Combat.CarrierCanAttack then "RUN!" else "SLAP"
	refs.Attack.BackgroundColor3 = if carrying and not GameConfig.Combat.CarrierCanAttack then Theme.Color.Disabled else Theme.Color.Danger
end

local function updateCooldowns(serverNow: number)
	local data = ClientState.Data
	if not data then
		return
	end
	for slot, ui in refs.Slots do
		local id = data.EquippedGadgets[slot]
		local def = id and id ~= "" and Gadgets.Get(id)
		local ready = def and ClientState.Cooldowns[id] or 0
		local remaining = if def then ready - serverNow else 0
		if remaining > 0 then
			-- Dark fill drains from the top as the cooldown runs out (hard edge at `cut`).
			local cut = math.clamp(1 - remaining / def.Cooldown, 0.001, 0.998)
			ui.Gradient.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(cut, 1),
				NumberSequenceKeypoint.new(cut + 0.001, 0),
				NumberSequenceKeypoint.new(1, 0),
			})
			ui.Cooldown.Visible = true
			ui.Timer.Text = tostring(math.ceil(remaining))
		else
			ui.Cooldown.Visible = false
			ui.Timer.Text = ""
		end
	end
end

local lastArea = ""
local function updateNav()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		refs.Nav.Visible = false
		return
	end
	local position = root.Position

	local area = Zones.AreaName(position)
	if area ~= lastArea then
		lastArea = area
		local safe = area == "TREASURE DISTRICT"
		refs.Area.Text = if safe then "🛡 TREASURE DISTRICT • SAFE" else "⚔ " .. area
		refs.Area.TextColor3 = AREA_COLORS[area] or Theme.Color.Text
	end
	if not secretKnown then
		for _, zone in WorldLayout.ExtractionZones do
			if zone.Category == "Secret" and (zone.Position - position).Magnitude < 45 then
				secretKnown = true
			end
		end
	end

	if not navTarget then
		refs.Nav.Visible = false
		return
	end
	local target = (navTarget :: any).Position :: Vector3
	local offset = target - position
	local distance = Vector3.new(offset.X, 0, offset.Z).Magnitude
	if distance < 14 then
		refs.Nav.Visible = false
		return
	end
	local camera = workspace.CurrentCamera
	local look = camera.CFrame.LookVector
	local camAngle = math.atan2(look.X, -look.Z)
	local targetAngle = math.atan2(offset.X, -offset.Z)
	refs.NavArrow.Rotation = math.deg(targetAngle - camAngle)
	refs.NavText.Text = ("%s • %dm"):format((navTarget :: any).Name, math.floor(distance / 3.5 + 0.5))
	refs.Nav.Visible = true
end

local function updateExtraction(serverNow: number)
	if not extraction then
		return
	end
	local e = extraction :: any
	local elapsed = serverNow - e.StartedAt
	local remaining = math.max(0, e.Duration - elapsed)
	local progress = math.clamp(elapsed / e.Duration, 0, 1)
	refs.ExtFill.Size = UDim2.fromScale(progress, 1)
	refs.ExtTime.Text = ("%.1f"):format(remaining)
	-- Heartbeat that speeds up as the bar fills: the last seconds should feel tense.
	local now = os.clock()
	if now >= (e.NextBeat or 0) then
		Sounds.Play("Heartbeat", 0.6 + 0.4 * progress)
		e.NextBeat = now + (0.9 - 0.55 * progress)
	end
end

function HUD.ShowStatus(title: string, subtitle: string?, color: Color3, duration: number)
	refs.Status.Text = title
	refs.Status.TextColor3 = color
	refs.Status.Visible = true
	refs.StatusSub.Text = subtitle or ""
	refs.StatusSub.Visible = subtitle ~= nil
	Kit.pulse(refs.Status)
	local token = {}
	refs.StatusToken = token
	task.delay(duration, function()
		if refs.StatusToken == token then
			refs.Status.Visible = false
			refs.StatusSub.Visible = false
		end
	end)
end

function HUD.FlashDanger(strength: number, duration: number)
	refs.VignetteStroke.Transparency = 1 - strength
	Kit.tween(refs.VignetteStroke, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Transparency = 1 })
end

local lastSwing = 0
function HUD.DropTreasure()
	if ClientState.Carrying() then
		Net.Get("DropTreasure"):FireServer()
	end
end

function HUD.Attack()
	if os.clock() - lastSwing < GameConfig.Combat.AttackCooldown then
		return
	end
	if ClientState.Carrying() and not GameConfig.Combat.CarrierCanAttack then
		return
	end
	lastSwing = os.clock()
	-- The slap itself goes first: a visual hiccup must never cost you the hit.
	Net.Get("Attack"):FireServer()
	local ok, err = pcall(BatFx.SwingLocal)
	if not ok then
		warn("[BatFx] swing:", err)
	end
end

-- Bat on your back / back in hand (the server moves it; SLAP also draws it).
function HUD.SheatheBat()
	local data = ClientState.Data
	if data and data.Settings and not data.Settings.SheatheBat then
		Net.Get("SetSetting"):FireServer("SheatheBat", true)
	end
end

function HUD.UseGadget(slot: number)
	local data = ClientState.Data
	if not data then
		return
	end
	local id = data.EquippedGadgets[slot]
	if not id or id == "" then
		-- Empty slot: gadgets are bought and equipped at the shop counter, not from anywhere.
		HUD.ShowStatus("GET GADGETS AT THE 🛒 GADGET SHOP", nil, Theme.Color.Info, 2)
		return
	end
	local def = Gadgets.Get(id)
	if not def then
		return
	end
	if (ClientState.Cooldowns[id] or 0) > workspace:GetServerTimeNow() then
		Sounds.Play("Error")
		return
	end
	if ClientState.Carrying() and not def.CanUseWhileCarrying then
		Sounds.Play("Error")
		return
	end
	-- Aim = camera centre (works the same on touch, mouse and gamepad).
	Net.Get("UseGadget"):FireServer(slot, workspace.CurrentCamera.CFrame.LookVector)
end

local function onExtractionState(payload)
	if payload.Active then
		extraction = { StartedAt = payload.StartedAt, Duration = payload.Duration, ZoneName = payload.ZoneName, Category = payload.Category }
		local cat = GameConfig.Extraction.Categories[payload.Category]
		refs.ExtTitle.Text = "EXTRACTING..."
		refs.ExtTitle.TextColor3 = Theme.Color.Text
		local blessing = if cat and (cat.MutationChance or 0) > 0 then (" • %d%% MUTATION"):format(math.floor(cat.MutationChance * 100 + 0.5)) else ""
		refs.ExtZone.Text = ("%s • x%.1f FEE%s"):format(if cat then cat.Label else "", if cat then cat.Bonus else 1, blessing)
		refs.ExtFill.BackgroundColor3 = if payload.Category == "Secret" then Theme.Color.Secret elseif payload.Category == "Dangerous" then Theme.Color.Warn else Theme.Color.Safe
		refs.Extraction.Visible = true
		Sounds.Play("ExtractStart")
	else
		extraction = nil
		refs.Extraction.Visible = false
		local reason = payload.Reason
		if reason == "Hit" then
			HUD.ShowStatus("EXTRACTION INTERRUPTED", "Hold the zone to try again", Theme.Color.Danger, 2)
			Sounds.Play("ExtractInterrupted")
		elseif reason == "Knocked" or reason == "Dropped" then
			HUD.ShowStatus("EXTRACTION INTERRUPTED", "TREASURE DROPPED", Theme.Color.Danger, 2.5)
			Sounds.Play("ExtractInterrupted")
		end
	end
end

function HUD.Init(screenGui: ScreenGui)
	gui = screenGui
	buildStats()
	buildMenuButtons()
	buildObjective()
	buildStatus()
	buildExtractionBar()
	buildReticle()
	buildActions()

	ClientState.DataChanged:Connect(function(data, previous)
		refreshStats(data, previous)
		refreshSlots()
		refreshObjective()
	end)
	ClientState.AttributeChanged:Connect(function(name)
		if name == "CarryingId" or name == "Stability" or name == "CarrySpeed" then
			refreshObjective()
			refreshSlots()
		end
	end)
	Net.Get("ExtractionState").OnClientEvent:Connect(onExtractionState)

	-- Keyboard / gamepad bindings (touch uses the on-screen buttons).
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonR2 or input.UserInputType == Enum.UserInputType.MouseButton1 then
			HUD.Attack()
		elseif key == Enum.KeyCode.One or key == Enum.KeyCode.ButtonL1 then
			HUD.UseGadget(1)
		elseif key == Enum.KeyCode.Two or key == Enum.KeyCode.ButtonR1 then
			HUD.UseGadget(2)
		elseif key == Enum.KeyCode.Three or key == Enum.KeyCode.ButtonY then
			HUD.UseGadget(3)
		elseif key == Enum.KeyCode.G or key == Enum.KeyCode.DPadDown then
			HUD.DropTreasure()
		elseif key == Enum.KeyCode.H then
			HUD.SheatheBat()
		end
	end)

	-- Light polling loop: navigation arrow, cooldown overlays, extraction countdown,
	-- and objective refresh (nearest treasure moves as treasures spawn/despawn).
	task.spawn(function()
		local elapsed = 0
		while true do
			local dt = task.wait(0.1)
			elapsed += dt
			local serverNow = workspace:GetServerTimeNow()
			updateNav()
			updateCooldowns(serverNow)
			updateExtraction(serverNow)
			updateClock(serverNow)
			-- No persistent event countdown: one short heads-up ~10 s before the end, then nothing.
			local eventEnds = workspace:GetAttribute("EventEndsAt") or 0
			local remaining = eventEnds - serverNow
			if remaining > 0 and remaining <= 10 and warnedEventEnd ~= eventEnds then
				warnedEventEnd = eventEnds
				Notifications.Banner(("⏳ %s ENDS IN 10s"):format(tostring(workspace:GetAttribute("EventName"))), "Last chance!", "Warn", 3)
			end
			if elapsed >= 1.5 then
				elapsed = 0
				refreshObjective()
			end
		end
	end)
end

return HUD
