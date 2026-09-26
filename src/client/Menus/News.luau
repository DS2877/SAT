-- Info Board menu (opened at the board beside the spawn pavilion): NEWS (live announcement +
-- posts), ROADMAP (done / now / next / later), EVENTS (sign up; we ping you when it starts)
-- and CODES (type a code for a reward - Config/Codes, Services/CodeService).
-- Content: Config/News. Sign-ups + live announcements: Services/NewsService.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local News = require(Shared.Config.News)
local NewsBoard = require(Shared.Logic.NewsBoard)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local NewsMenu = {}

local TABS = { "NEWS", "ROADMAP", "EVENTS", "CODES" }
local STATUS_TITLES = { Done = "✅ DONE", Now = "🛠 WORKING ON IT", Next = "⏭ UP NEXT", Later = "🔮 LATER" }
local STATUS_ORDER = { "Now", "Next", "Later", "Done" }

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function now(): number
	return math.floor(workspace:GetServerTimeNow())
end

-- A wrapped text block that grows to fit.
local function block(parent: Instance, props: { [string]: any }): TextLabel
	local label = Kit.label({
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = parent,
	})
	for key, value in props do
		(label :: any)[key] = value
	end
	return label
end

local function card(parent: Instance, order: number, color: Color3, accent: Color3?): Frame
	local frame = Kit.panel({
		LayoutOrder = order,
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		Parent = parent,
	}, { Kit.padding(14), Kit.list(Enum.FillDirection.Vertical, 6) })
	local stroke = frame:FindFirstChildOfClass("UIStroke")
	if stroke and accent then
		stroke.Color = accent
		stroke.Transparency = 0.2
		stroke.Thickness = 2
	end
	return frame
end

local function page(root: Frame): ScrollingFrame
	return Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 56),
		Size = UDim2.new(1, 0, 1, -56),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Visible = false,
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 10), Kit.padding(4) })
end

function NewsMenu.Build(root: Frame)
	local pages: { [string]: ScrollingFrame } = {}
	local tabButtons: { [string]: TextButton } = {}
	local currentTab = "NEWS"

	local tabBar = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = root }, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	local function show(tab: string)
		currentTab = tab
		for name, frame in pages do
			frame.Visible = name == tab
			local button = tabButtons[name]
			button.BackgroundColor3 = if name == tab then Theme.Color.Button else Theme.Color.ButtonAlt
			button.TextColor3 = if name == tab then Theme.Color.ButtonText else Theme.Color.Text
		end
	end
	for i, tab in TABS do
		pages[tab] = page(root)
		tabButtons[tab] = Kit.button({ LayoutOrder = i, Size = UDim2.fromScale(0.23, 1), Text = tab, TextSize = 16, Parent = tabBar }, function()
			show(tab)
		end)
	end

	-- NEWS ----------------------------------------------------------------------------------
	local newsPage = pages.NEWS
	local liveCard = card(newsPage, 0, Color3.fromRGB(150, 30, 40), Theme.Color.Danger)
	block(liveCard, { Text = "📢 LIVE ANNOUNCEMENT", Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Gold })
	local liveText = block(liveCard, { Text = "", Font = Theme.Font.Display, TextSize = 22 })
	for i, post in News.Posts do
		local pinned = post.Kind == "Announcement"
		local c = card(newsPage, i, if pinned then Color3.fromRGB(70, 52, 20) else Theme.Color.PanelLight, if pinned then Theme.Color.Gold else nil)
		block(c, { Text = ("%s • %s"):format(if pinned then "📌 ANNOUNCEMENT" else "📰 NEWS", post.Date), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = if pinned then Theme.Color.Gold else Theme.Color.Info })
		block(c, { Text = ("%s %s"):format(post.Icon, post.Title), Font = Theme.Font.Display, TextSize = 24 })
		block(c, { Text = post.Body, Font = Theme.Font.Body, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.TextDim })
	end

	-- ROADMAP -------------------------------------------------------------------------------
	local roadmapPage = pages.ROADMAP
	for order, status in STATUS_ORDER do
		local items = {}
		for _, item in News.Roadmap do
			if item.Status == status then
				table.insert(items, item)
			end
		end
		if #items > 0 then
			local color = rgb(News.StatusColors[status])
			local c = card(roadmapPage, order, Theme.Color.PanelLight, color)
			block(c, { Text = STATUS_TITLES[status], Font = Theme.Font.Display, TextSize = 22, TextColor3 = color })
			for _, item in items do
				block(c, { Text = ("%s  <b>%s</b>  <font color=\"#B4BACD\">- %s</font>"):format(item.Icon, item.Title, item.Text), RichText = true, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body })
			end
		end
	end

	-- EVENTS --------------------------------------------------------------------------------
	local eventsPage = pages.EVENTS
	local eventRows = {}
	local latestData = nil
	for i, event in News.Events do
		local c = card(eventsPage, i, Color3.fromRGB(56, 28, 92), Theme.Color.Secret)
		block(c, { Text = ("%s %s"):format(event.Icon, event.Title), Font = Theme.Font.Display, TextSize = 26 })
		local when = block(c, { Text = "", Font = Theme.Font.Display, TextSize = 20, TextColor3 = Color3.fromRGB(120, 230, 255) })
		local date = block(c, { Text = "", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.Gold })
		block(c, { Text = event.Text, Font = Theme.Font.Body, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.TextDim })
		local foot = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 48), BackgroundTransparency = 1, Parent = c })
		local count = Kit.label({ Size = UDim2.fromScale(0.5, 1), Text = "", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body, TextXAlignment = Enum.TextXAlignment.Left, Parent = foot })
		local state = { SignedUp = false }
		local button = Kit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.48, 1), Text = "SIGN UP", TextSize = 18, Parent = foot }, function()
			if NewsBoard.Status(event, now()) ~= "Ended" then
				Net.Get("EventSignup"):FireServer(event.Id, not state.SignedUp)
			end
		end)
		if event.StartsAt then
			date.Text = "🗓 " .. DateTime.fromUnixTimestamp(event.StartsAt):FormatLocalTime("dddd, MMM D • h:mm A", "en-us") .. " (your time)"
		else
			date.Text = "🗓 Date announced soon - sign up to get pinged"
		end
		eventRows[event.Id] = { Event = event, When = when, Count = count, Button = button, State = state }
	end

	-- CODES ---------------------------------------------------------------------------------
	local codesPage = pages.CODES
	local codeCard = card(codesPage, 1, Theme.Color.PanelLight, Theme.Color.Gold)
	block(codeCard, { Text = "🎟 ENTER A CODE", Font = Theme.Font.Display, TextSize = 24, TextColor3 = Theme.Color.Gold })
	block(codeCard, { Text = "Codes drop in updates, events and on our socials.", Font = Theme.Font.Body, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.TextDim })
	local codeRow = Kit.new("Frame", { Size = UDim2.new(1, 0, 0, 52), BackgroundTransparency = 1, Parent = codeCard })
	local input = Kit.new("TextBox", {
		Size = UDim2.fromScale(0.62, 1),
		BackgroundColor3 = Color3.fromRGB(20, 24, 40),
		TextColor3 = Theme.Color.Text,
		PlaceholderText = "Type code here",
		PlaceholderColor3 = Theme.Color.TextDim,
		Text = "",
		Font = Theme.Font.Bold,
		TextSize = 20,
		ClearTextOnFocus = false,
		Parent = codeRow,
	}, { Kit.corner(Theme.Radius.Medium), Kit.padding(0, 12) })
	local function redeem()
		local text = input.Text
		if #text > 0 then
			Net.Get("RedeemCode"):FireServer(text)
			input.Text = ""
		end
	end
	input.FocusLost:Connect(function(enterPressed)
		if enterPressed then
			redeem()
		end
	end)
	Kit.button({ AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromScale(0.35, 1), Text = "REDEEM", TextSize = 18, BackgroundColor3 = Theme.Color.Safe, TextColor3 = Color3.fromRGB(10, 40, 16), Parent = codeRow }, redeem)

	local function tick()
		local t = now()
		local live = workspace:GetAttribute("NewsLiveText")
		liveCard.Visible = type(live) == "string" and live ~= ""
		liveText.Text = if type(live) == "string" then live else ""
		for _, row in eventRows do
			local event = row.Event
			row.When.Text = NewsBoard.When(event, t)
			local n = tonumber(workspace:GetAttribute("Signups_" .. event.Id)) or 0
			row.Count.Text = ("👥 %s signed up"):format(Kit.shortNumber(n))
			local status = NewsBoard.Status(event, t)
			local signedUp = latestData ~= nil and latestData.EventSignups ~= nil and latestData.EventSignups[event.Id] ~= nil
			row.State.SignedUp = signedUp
			local button = row.Button
			if status == "Ended" then
				button.Text = "ENDED"
				button.BackgroundColor3 = Theme.Color.Disabled
				button.TextColor3 = Theme.Color.TextDim
			elseif signedUp then
				button.Text = "✔ SIGNED UP"
				button.BackgroundColor3 = Theme.Color.Safe
				button.TextColor3 = Color3.fromRGB(10, 40, 16)
			else
				button.Text = "SIGN UP"
				button.BackgroundColor3 = Theme.Color.Button
				button.TextColor3 = Theme.Color.ButtonText
			end
		end
	end

	show(currentTab)
	task.spawn(function()
		while root.Parent do
			if root.Visible then
				tick()
			end
			task.wait(1)
		end
	end)

	local function refresh(data)
		latestData = data
		tick()
		-- Opening the board = the newest post is read.
		local newest = News.Posts[1]
		if root.Visible and newest and data.NewsSeen ~= newest.Id then
			Net.Get("NewsSeen"):FireServer(newest.Id)
		end
	end

	return { Refresh = refresh }
end

return NewsMenu
