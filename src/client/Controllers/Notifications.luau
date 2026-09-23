-- Rare, meaningful notifications. Three channels:
--   Toast  – short hint under the objective (queued, max 3 visible)
--   Banner – big centre-top message (danger/reward), priority-aware
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
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Radius = Theme.Radius.Round,
		LayoutOrder = toastOrder,
		Parent = toastStack,
	}, { Kit.padding(0, 16) })
	Kit.label({
		Text = text,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
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
		Position = UDim2.fromScale(0.5, 0.42),
		Size = UDim2.fromOffset(if big then 460 else 380, if big then 190 else 150),
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center), Kit.padding(10) })
	Kit.stroke(info.Color, 3, 0.1).Parent = frame
	Kit.label({ Text = "EXTRACTION COMPLETE", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 22), Font = Theme.Font.Black, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.TextDim, Parent = frame })
	local amount = Kit.label({ Text = "+$0", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, if big then 60 else 48), Font = Theme.Font.Display, TextSize = if big then 56 else 44, TextColor3 = Theme.Color.Cash, TextStrokeTransparency = 0.4, Parent = frame })
	Kit.label({ Text = ("%s %s"):format(info.Glyph, def.Name:upper()), LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), Font = Theme.Font.Display, TextSize = 24, TextColor3 = info.Color, Parent = frame })
	local detail = if payload.NewDiscovery then "NEW! ADDED TO COLLECTION" else "ADDED TO COLLECTION"
	if payload.Bonus and payload.Bonus > 1 then
		detail ..= (" • x%.1f %s BONUS"):format(payload.Bonus, (payload.Category or ""):upper())
	end
	Kit.label({ Text = detail, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = if payload.NewDiscovery then Theme.Color.Gold else Theme.Color.TextDim, Parent = frame })
	if payload.StrengthGain and payload.StrengthGain > 0 then
		Kit.label({ Text = ("+%d STRENGTH"):format(payload.StrengthGain), LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Strength, Parent = frame })
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

function Notifications.Init(screenGui: ScreenGui)
	gui = screenGui
	toastStack = Kit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 200),
		Size = UDim2.fromOffset(500, 130),
		BackgroundTransparency = 1,
		Parent = gui,
	}, { Kit.list(Enum.FillDirection.Vertical, 6) })
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
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.24),
		Size = UDim2.fromOffset(520, 92),
		Visible = false,
		Parent = gui,
	})
	bannerTitle = Kit.label({ Size = UDim2.new(1, 0, 0, 50), Position = UDim2.fromOffset(0, 8), Font = Theme.Font.Display, TextSize = 40, TextStrokeTransparency = 0.3, Parent = banner })
	bannerText = Kit.label({ Size = UDim2.new(1, -20, 0, 24), Position = UDim2.fromOffset(10, 58), Font = Theme.Font.Black, TextSize = Theme.TextSize.Body, Parent = banner })

	Net.Get("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Kind == "Toast" then
			Notifications.Toast(payload.Text, payload.Tone)
		elseif payload.Kind == "Banner" then
			Notifications.Banner(payload.Title, payload.Text, payload.Tone)
			if payload.Tone == "Reward" then
				Sounds.Play("ExtractSuccess")
			end
		elseif payload.Kind == "Social" then
			Notifications.Social(payload.Text, payload.Rarity)
		end
	end)
end

return Notifications
