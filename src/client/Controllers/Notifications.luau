-- Rare, meaningful notifications. Three channels:
--   Toast  – short hint in the top stack under the objective (max 3 visible)
--   Banner – headline in the top stack (danger/reward), priority-aware
--   Social – small server feed on the left ("X STOLE THE GOLDEN CROWN")
-- Plus the extraction reward popup, scaled by how big the reward is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)

local Notifications = {}

local gui: ScreenGui
local toastStack: Frame
local feed: Frame
local banner: Frame
local bannerTitle: TextLabel
local bannerText: TextLabel
local bannerPriority = 0
local bannerToken = nil
local toastOrder = 0
local feedOrder = 0

local TONE_PRIORITY = { Danger = 3, Reward = 2, Warn = 1, Info = 1 }

function Notifications.Toast(text: string, tone: string?)
	local color = Theme.ToneColor[tone or "Info"] or Theme.Color.Info
	toastOrder += 1
	local toast = Kit.panel({
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		Radius = Theme.Radius.Round,
		LayoutOrder = toastOrder,
		Parent = toastStack,
	}, { Kit.padding(0, 16) })
	Kit.label({
		Text = text,
		Size = UDim2.fromOffset(0, 28),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Tiny,
		TextColor3 = color,
		Parent = toast,
	})
	local children = {}
	for _, child in toastStack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 3 then
		table.sort(children, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		children[1]:Destroy()
	end
	if tone == "Warn" or tone == "Danger" then
		Sounds.Play("Error")
	end
	task.delay(2.6, function()
		if toast.Parent then
			Kit.tween(toast, Theme.Motion.Normal, { BackgroundTransparency = 1 })
			task.wait(0.22)
			toast:Destroy()
		end
	end)
end

function Notifications.Banner(title: string, text: string?, tone: string?, duration: number?)
	local priority = TONE_PRIORITY[tone or "Info"] or 1
	if banner.Visible and priority < bannerPriority then
		return -- never bury danger under a lower-priority message
	end
	bannerPriority = priority
	local color = Theme.ToneColor[tone or "Info"] or Theme.Color.Info
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerText.Text = text or ""
	banner.Visible = true
	Kit.pulse(banner)
	local token = {}
	bannerToken = token
	task.delay(duration or 3, function()
		if bannerToken == token then
			banner.Visible = false
			bannerPriority = 0
		end
	end)
end

function Notifications.Social(text: string, rarity: string?)
	local info = rarity and Rarities.Info[rarity]
	feedOrder += 1
	local line = Kit.panel({
		LayoutOrder = feedOrder,
		Size = UDim2.new(1, 0, 0, 26),
		BackgroundTransparency = Theme.Transparency.PanelSoft,
		Radius = Theme.Radius.Small,
		Parent = feed,
	}, { Kit.padding(0, 8) })
	Kit.label({
		Text = (if info then info.Glyph .. " " else "") .. text,
		Size = UDim2.fromScale(1, 1),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Tiny,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextColor3 = if info then info.Color else Theme.Color.Text,
		Parent = line,
	})
	local lines = {}
	for _, child in feed:GetChildren() do
		if child:IsA("Frame") then
			table.insert(lines, child)
		end
	end
	if #lines > 4 then
		table.sort(lines, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		lines[1]:Destroy()
	end
	task.delay(7, function()
		if line.Parent then
			line:Destroy()
		end
	end)
end

-- Big reward moment. Scales intensity with value so small wins stay small.
function Notifications.Reward(payload)
	local def = Treasures.Get(payload.TreasureId)
	if not def then
		return
	end
	local info = Rarities.Info[def.Rarity]
	local big = info.Rank >= 4
	local frame = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(if big then 360 else 300, if big then 150 else 124),
		AutomaticSize = Enum.AutomaticSize.Y, -- grows for the mutation / streak lines
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center), Kit.padding(10) })
	Kit.stroke(info.Color, 3, 0.1).Parent = frame
	Kit.label({ Text = "EXTRACTED • FINDER'S FEE", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, Parent = frame })
	local amount = Kit.label({ Text = "+$0", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, if big then 46 else 38), Font = Theme.Font.Display, TextSize = if big then 42 else 34, TextColor3 = Theme.Color.Cash, TextStrokeTransparency = 0.4, Parent = frame })
	local title = if payload.Mutation then ("%s %s"):format(tostring(payload.Mutation):upper(), def.Name:upper()) else def.Name:upper()
	Kit.label({ Text = ("%s %s"):format(info.Glyph, title), LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), Font = Theme.Font.Display, TextSize = 18, TextColor3 = info.Color, Parent = frame })
	local detail = if payload.PlacedSlot
		then ("NOW EARNING %s/s IN YOUR VAULT"):format(Kit.shortCash(payload.Income or 0))
		else ("VAULT FULL • SOLD FOR %s"):format(Kit.shortCash(payload.SoldFor or 0))
	if payload.NewDiscovery then
		detail = "NEW! " .. detail
	end
	if payload.Bonus and payload.Bonus > 1 then
		detail ..= (" • x%.1f %s BONUS"):format(payload.Bonus, (payload.Category or ""):upper())
	end
	Kit.label({ Text = detail, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = if payload.NewDiscovery then Theme.Color.Gold else Theme.Color.TextDim, Parent = frame })
	if payload.BlessedMutation then
		Kit.label({ Text = ("✨ %s MUTATION FROM THE RISKY ESCAPE!"):format(tostring(payload.BlessedMutation):upper()), LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Gold, Parent = frame })
		big = true
	end
	if payload.Streak and payload.Streak > 1 then
		Kit.label({ Text = ("🔥 RUN STREAK %d • FEE x%.2f"):format(payload.Streak, payload.StreakMultiplier or 1), LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Strength, Parent = frame })
	end
	if payload.StrengthGain and payload.StrengthGain > 0 then
		Kit.label({ Text = ("+%d STRENGTH"):format(payload.StrengthGain), LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Strength, Parent = frame })
	end
	Kit.pulse(frame)
	Sounds.Play(if big then "BigReward" else "ExtractSuccess")

	-- Count-up
	task.spawn(function()
		local steps = if big then 30 else 16
		for i = 1, steps do
			amount.Text = "+" .. Kit.formatCash(payload.Reward * (i / steps))
			task.wait(0.03)
		end
		amount.Text = "+" .. Kit.formatCash(payload.Reward)
	end)
	task.delay(if big then 4 else 3, function()
		Kit.tween(frame, Theme.Motion.Normal, { BackgroundTransparency = 1 })
		for _, d in frame:GetDescendants() do
			if d:IsA("TextLabel") then
				Kit.tween(d, Theme.Motion.Normal, { TextTransparency = 1, TextStrokeTransparency = 1 })
			elseif d:IsA("UIStroke") then
				Kit.tween(d, Theme.Motion.Normal, { Transparency = 1 })
			end
		end
		task.wait(0.25)
		frame:Destroy()
	end)
end

-- topStack: the HUD's top-centre layout (objective card, nav hint). Banner and toasts are
-- appended beneath it so nothing can ever overlap the objective.
function Notifications.Init(screenGui: ScreenGui, topStack: Frame)
	gui = screenGui
	toastStack = Kit.new("Frame", {
		Name = "Toasts",
		LayoutOrder = 5,
		Size = UDim2.fromOffset(330, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Parent = topStack,
	}, { Kit.list(Enum.FillDirection.Vertical, 4) })
	feed = Kit.new("Frame", {
		Name = "SocialFeed",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 12, 1, -20),
		Size = UDim2.fromOffset(330, 140),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 4, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Bottom) })
	banner = Kit.panel({
		Name = "Banner",
		LayoutOrder = 4,
		Size = UDim2.fromOffset(330, 54),
		Visible = false,
		Parent = topStack,
	})
	bannerTitle = Kit.label({
		Size = UDim2.new(1, -16, 0, 26),
		Position = UDim2.fromOffset(8, 5),
		Font = Theme.Font.Display,
		TextScaled = true,
		Parent = banner,
	})
	Kit.new("UITextSizeConstraint", { MaxTextSize = 22, Parent = bannerTitle })
	bannerText = Kit.label({
		Size = UDim2.new(1, -16, 0, 16),
		Position = UDim2.fromOffset(8, 32),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
		Parent = banner,
	})

	Net.Get("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Kind == "Toast" then
			Notifications.Toast(payload.Text, payload.Tone)
		elseif payload.Kind == "Banner" then
			Notifications.Banner(payload.Title, payload.Text, payload.Tone, tonumber(payload.Duration))
			if payload.Tone == "Reward" then
				Sounds.Play("ExtractSuccess")
			end
		elseif payload.Kind == "Social" then
			Notifications.Social(payload.Text, payload.Rarity)
		end
	end)
end

return Notifications
