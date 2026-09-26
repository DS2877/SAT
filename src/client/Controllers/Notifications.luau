-- Rare, meaningful notifications. Channels, top to bottom of the top-centre stack:
--   Announcement – an admin speaking (🛡 panel): their head + big speech bubble, always on top
--   Banner – headline card: small coloured title, BIG message; priority-aware
--   Toast  – short line with a coloured dot (max 3 visible)
--   Social – small server feed on the left ("X STOLE THE GOLDEN CROWN")
-- Plus the extraction reward popup, scaled by how big the reward is.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Net = require(Shared.Net)
local DayNight = require(Shared.Logic.DayNight)

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
local bannerStroke: UIStroke
local bannerScale: UIScale
local announcement: Frame
local announceScale: UIScale
local speakerHead: ImageLabel
local speakerName: TextLabel
local speech: TextLabel
local bannerPriority = 0
local bannerToken = nil
local toastOrder = 0
local feedOrder = 0

local TONE_PRIORITY = { Danger = 3, Reward = 2, Warn = 1, Info = 1 }

-- TOASTS: a short line with a coloured dot, readable on a phone (max 3, newest last).
function Notifications.Toast(text: string, tone: string?)
	local color = Theme.ToneColor[tone or "Info"] or Theme.Color.Info
	toastOrder += 1
	local toast = Kit.panel({
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Radius = Theme.Radius.Round,
		LayoutOrder = toastOrder,
		BackgroundTransparency = 0.15,
		Parent = toastStack,
	}, { Kit.padding(0, 14), Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
	local toastStroke = toast:FindFirstChildOfClass("UIStroke")
	if toastStroke then
		toastStroke.Color = color
		toastStroke.Transparency = 0.35
	end
	local dot = Kit.new("Frame", { LayoutOrder = 1, Size = UDim2.fromOffset(10, 10), BackgroundColor3 = color, BorderSizePixel = 0, Parent = toast })
	Kit.corner(UDim.new(1, 0)).Parent = dot
	Kit.label({
		Text = text,
		LayoutOrder = 2,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Font = Theme.Font.Bold,
		TextSize = 17,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = toast,
	})
	local children = {}
	for _, child in toastStack:GetChildren() do
		if child:IsA("Frame") then
			table.insert(children, child)
		end
	end
	if #children > 3 then
		table.sort(children, function(x, y)
			return x.LayoutOrder < y.LayoutOrder
		end)
		children[1]:Destroy()
	end
	if tone == "Danger" then
		Sounds.Play("Error")
	end
	task.delay(3, function()
		if toast.Parent then
			Kit.tween(toast, Theme.Motion.Normal, { BackgroundTransparency = 1 })
			task.wait(0.22)
			toast:Destroy()
		end
	end)
end

-- BANNERS: a headline card. A small coloured title (what kind of news) over the MESSAGE in
-- big type - the message is what you read. Priority-aware: danger is never buried.
local function showBanner(title: string, text: string?, tone: string?, duration: number?)
	local priority = TONE_PRIORITY[tone or "Info"] or 1
	if banner.Visible and priority < bannerPriority then
		return
	end
	bannerPriority = priority
	local color = Theme.ToneColor[tone or "Info"] or Theme.Color.Info
	bannerStroke.Color = color
	bannerTitle.Text = title
	bannerTitle.TextColor3 = color
	bannerText.Text = text or ""
	bannerText.Visible = text ~= nil and text ~= ""
	banner.Visible = true
	bannerScale.Scale = 0.85
	Kit.tween(bannerScale, Theme.Motion.Pop, { Scale = 1 })
	local token = {}
	bannerToken = token
	task.delay(duration or 3.5, function()
		if bannerToken == token then
			banner.Visible = false
			bannerPriority = 0
		end
	end)
end

function Notifications.Banner(title: string, text: string?, tone: string?, duration: number?)
	showBanner(title, text, tone, duration)
end

-- ANNOUNCEMENTS (the 🛡 Admin panel): the speaker's head on the left and what they say in big
-- type on the right, like a speech bubble. Always on top of every other notification (they
-- sit below it), and a new announcement replaces the old one.
local announceToken = nil
function Notifications.Announce(payload)
	local text = tostring(payload.Text or "")
	if text == "" then
		return
	end
	announcement.Visible = true
	speakerHead.Image = if tonumber(payload.UserId) and tonumber(payload.UserId) > 0
		then ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(tonumber(payload.UserId) :: number)
		else ""
	speakerName.Text = ("📢 %s"):format(tostring(payload.Name or "ANNOUNCEMENT"):upper())
	speech.Text = text
	announceScale.Scale = 0.7
	Kit.tween(announceScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	Sounds.Play("Notify")
	local token = {}
	announceToken = token
	local duration = math.clamp(6 + #text / 14, 7, 16)
	task.delay(duration, function()
		if announceToken == token then
			announcement.Visible = false
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
	local home = payload.Category == "Home"
	Kit.label({ Text = if home then "BANKED AT HOME • FINDER'S FEE" else "EXTRACTED • FINDER'S FEE", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, Parent = frame })
	local amount = Kit.label({ Text = "+$0", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, if big then 46 else 38), Font = Theme.Font.Display, TextSize = if big then 42 else 34, TextColor3 = Theme.Color.Cash, TextStrokeTransparency = 0.4, Parent = frame })
	local title = if payload.Mutation then ("%s %s"):format(tostring(payload.Mutation):upper(), def.Name:upper()) else def.Name:upper()
	Kit.label({ Text = ("%s %s"):format(info.Glyph, title), LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 20), Font = Theme.Font.Display, TextSize = 18, TextColor3 = info.Color, Parent = frame })
	local detail = if payload.PlacedSlot
		then ("NOW EARNING %s/s IN YOUR VAULT"):format(Kit.shortCash(payload.Income or 0))
		else ("VAULT FULL • SOLD FOR %s"):format(Kit.shortCash(payload.SoldFor or 0))
	if payload.PlacedSlot and payload.Replaced then
		detail ..= (" • OLD ONE SOLD FOR %s"):format(Kit.shortCash(payload.SoldFor or 0))
	end
	if payload.NewDiscovery then
		detail = "NEW! " .. detail
	end
	if payload.Bonus and payload.Bonus > 1 then
		detail ..= (" • x%.1f %s BONUS"):format(payload.Bonus, (payload.Category or ""):upper())
	end
	Kit.label({ Text = detail, LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = if payload.NewDiscovery then Theme.Color.Gold else Theme.Color.TextDim, Parent = frame })
	if home then
		Kit.label({ Text = "Exit beams in the wilds pay 2x+ and can add a mutation", LayoutOrder = 9, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, Parent = frame })
	end
	if payload.BlessedMutation then
		Kit.label({ Text = ("✨ %s MUTATION FROM THE RISKY ESCAPE!"):format(tostring(payload.BlessedMutation):upper()), LayoutOrder = 6, Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Gold, Parent = frame })
		big = true
	end
	if payload.Streak and payload.Streak > 1 then
		Kit.label({ Text = ("🔥 RUN STREAK %d • FEE x%.2f"):format(payload.Streak, payload.StreakMultiplier or 1), LayoutOrder = 7, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Strength, Parent = frame })
	end
	if payload.StrengthGain and payload.StrengthGain > 0 then
		Kit.label({ Text = ("💪 +%s STRENGTH"):format(Kit.bigNumber(payload.StrengthGain)), LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Strength, Parent = frame })
	end
	-- "One more run": how much daylight is left to go again.
	local day = DayNight.State(workspace:GetServerTimeNow())
	if not day.IsNight and day.SecondsLeft > 45 then
		local left = math.floor(day.SecondsLeft)
		Kit.label({ Text = ("⏱ %d:%02d of daylight left • one more run?"):format(left // 60, left % 60), LayoutOrder = 8, Size = UDim2.new(1, 0, 0, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Color3.fromRGB(190, 210, 255), Parent = frame })
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
	-- The announcement card: head left, speech right. Top of the stack, above everything.
	announcement = Kit.new("Frame", {
		Name = "Announcement",
		LayoutOrder = -2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Visible = false,
		Parent = topStack,
	})
	announceScale = Kit.new("UIScale", { Parent = announcement })
	local headRing = Kit.new("Frame", {
		Name = "Head",
		Size = UDim2.fromOffset(84, 84),
		BackgroundColor3 = Color3.fromRGB(255, 205, 80),
		BorderSizePixel = 0,
		Parent = announcement,
	})
	Kit.corner(UDim.new(1, 0)).Parent = headRing
	speakerHead = Kit.new("ImageLabel", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -8, 1, -8),
		BackgroundColor3 = Color3.fromRGB(40, 46, 80),
		BorderSizePixel = 0,
		Image = "",
		Parent = headRing,
	})
	Kit.corner(UDim.new(1, 0)).Parent = speakerHead
	-- The speech bubble, with a little tail pointing at the head.
	local bubble = Kit.new("Frame", {
		Name = "Bubble",
		Position = UDim2.fromOffset(100, 0),
		Size = UDim2.new(1, -100, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(255, 252, 240),
		BorderSizePixel = 0,
		ZIndex = 2,
		Parent = announcement,
	}, { Kit.padding(10, 14), Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left) })
	Kit.corner(Theme.Radius.Medium).Parent = bubble
	Kit.stroke(Color3.fromRGB(255, 205, 80), 3, 0).Parent = bubble
	local tail = Kit.new("Frame", {
		Name = "Tail",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(100, 42),
		Size = UDim2.fromOffset(18, 18),
		Rotation = 45,
		BackgroundColor3 = Color3.fromRGB(255, 252, 240),
		BorderSizePixel = 0,
		ZIndex = 1,
		Parent = announcement,
	})
	Kit.stroke(Color3.fromRGB(255, 205, 80), 3, 0).Parent = tail
	speakerName = Kit.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Font.Black,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(200, 120, 20),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bubble,
	})
	speech = Kit.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Display,
		TextSize = 26,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(30, 30, 50),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = bubble,
	})

	-- The banner card: tone-coloured frame and title, big message.
	banner = Kit.panel({
		Name = "Banner",
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = topStack,
	}, { Kit.padding(8, 16), Kit.list(Enum.FillDirection.Vertical, 2, Enum.HorizontalAlignment.Left) })
	bannerScale = Kit.new("UIScale", { Parent = banner })
	bannerStroke = banner:FindFirstChildOfClass("UIStroke") :: UIStroke
	bannerStroke.Thickness = 2
	bannerStroke.Transparency = 0.2
	bannerTitle = Kit.label({
		LayoutOrder = 1,
		Size = UDim2.new(1, 0, 0, 20),
		Font = Theme.Font.Black,
		TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})
	bannerText = Kit.label({
		LayoutOrder = 2,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Display,
		TextSize = 22,
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = banner,
	})

	Net.Get("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Kind == "Announcement" then
			Notifications.Announce(payload)
		elseif payload.Kind == "Toast" then
			Notifications.Toast(payload.Text, payload.Tone)
		elseif payload.Kind == "Banner" then
			Notifications.Banner(payload.Title, payload.Text, payload.Tone, tonumber(payload.Duration))
			-- One gentle chime per banner: rewards ding, everything else a soft notify.
			Sounds.Play(if payload.Tone == "Reward" then "ExtractSuccess" else "Notify")
		elseif payload.Kind == "Social" then
			Notifications.Social(payload.Text, payload.Rarity)
		end
	end)
end

return Notifications
