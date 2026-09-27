-- 🛡 ADMIN PANEL (owners / admins only; the server checks every action: Services/AdminService).
-- Pick THIS SERVER or ALL SERVERS at the top, then:
--   📢 send a message as a banner on every screen (optionally pinned on the Info Board)
--   ⚡ run a global boost (luck / cash / mutations / strength) for N minutes, or end them
--   🎉 start an event (Treasure Rain, Cursed Hour, Gold Rush, the Deep South storms)
--   💬 read player feedback (the last week, newest first; no names are ever stored)
-- Built for a phone first: big buttons, one scrolling column.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)

local Admin = {}

local ON = Color3.fromRGB(80, 200, 120)
local OFF = Color3.fromRGB(70, 74, 104)

local function send(action)
	Net.Get("AdminAction"):FireServer(action)
	Sounds.Play("Click")
end

function Admin.Build(root: Frame, _menus)
	local global = true
	local minutes = GameConfig.Admin.BoostMinutes[2] or 15
	local pin = false

	local scroll = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 10), Kit.padding(4, 6) })

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end
	local function heading(text: string)
		Kit.label({ Text = text, LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, 26), Font = Theme.Font.Display, TextSize = 22, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll })
	end
	local function row(height: number): Frame
		return Kit.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.new(1, 0, 0, height), BackgroundTransparency = 1, Parent = scroll }, {
			Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
		})
	end
	local function button(parent: Instance, text: string, width: number, color: Color3, onClick: () -> ()): TextButton
		return Kit.button({ Size = UDim2.new(0, width, 1, 0), Text = text, TextSize = Theme.TextSize.Small, Font = Theme.Font.Display, BackgroundColor3 = color, TextColor3 = Color3.new(1, 1, 1), Parent = parent }, onClick)
	end

	-- WHERE: this server or every server.
	heading("🌍 WHERE")
	local scopeRow = row(46)
	local here, everywhere
	local function paintScope()
		here.BackgroundColor3 = if global then OFF else ON
		everywhere.BackgroundColor3 = if global then ON else OFF
	end
	here = button(scopeRow, "THIS SERVER", 170, OFF, function()
		global = false
		paintScope()
	end)
	everywhere = button(scopeRow, "ALL SERVERS", 170, ON, function()
		global = true
		paintScope()
	end)
	paintScope()

	-- MESSAGE
	heading("📢 MESSAGE TO EVERYONE")
	local box = Kit.new("TextBox", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 70),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Font.Body,
		TextSize = 18,
		TextColor3 = Theme.Color.Text,
		PlaceholderText = "e.g. HEIST HOUR in 5 minutes - everybody to the Ruins!",
		PlaceholderColor3 = Theme.Color.TextDim,
		Text = "",
		Parent = scroll,
	}, { Kit.corner(Theme.Radius.Medium), Kit.padding(8) })
	box:GetPropertyChangedSignal("Text"):Connect(function()
		if #box.Text > GameConfig.Admin.MaxBroadcast then
			box.Text = box.Text:sub(1, GameConfig.Admin.MaxBroadcast)
		end
	end)
	local messageRow = row(46)
	local pinButton
	pinButton = button(messageRow, "📌 PIN ON BOARD: OFF", 210, OFF, function()
		pin = not pin
		pinButton.Text = if pin then "📌 PIN ON BOARD: ON" else "📌 PIN ON BOARD: OFF"
		pinButton.BackgroundColor3 = if pin then ON else OFF
	end)
	button(messageRow, "SEND 📢", 150, Theme.Color.Info, function()
		if box.Text:match("^%s*$") then
			Sounds.Play("Error")
			return
		end
		send({ Kind = "Broadcast", Text = box.Text, Global = global, Pin = pin })
		box.Text = ""
	end)

	-- BOOSTS
	heading("⚡ BOOSTS (ADMIN ABUSE)")
	local minuteRow = row(40)
	local minuteButtons = {}
	local function paintMinutes()
		for value, b in minuteButtons do
			b.BackgroundColor3 = if value == minutes then ON else OFF
		end
	end
	for _, value in GameConfig.Admin.BoostMinutes do
		minuteButtons[value] = button(minuteRow, ("%d MIN"):format(value), 80, OFF, function()
			minutes = value
			paintMinutes()
		end)
	end
	paintMinutes()
	local boostRow1, boostRow2 = row(54), row(54)
	for i, kind in GameConfig.GlobalBoosts.Order do
		local info = GameConfig.GlobalBoosts[kind]
		button(if i <= 2 then boostRow1 else boostRow2, ("%s %s x%d"):format(info.Icon, info.Name, info.Multiplier), 190, Color3.fromRGB(170, 90, 255), function()
			send({ Kind = "Boost", Boost = kind, Minutes = minutes, Global = global })
		end)
	end
	local endRow = row(40)
	button(endRow, "✖ END ALL BOOSTS", 200, Theme.Color.Danger, function()
		send({ Kind = "EndBoosts", Global = global })
	end)

	-- EVENTS
	heading("🎉 START AN EVENT")
	local events = {}
	for _, id in { "TreasureRain", "CursedHour", "GoldRush" } do
		local info = GameConfig.Events[id]
		table.insert(events, { Id = id, Name = info.Name, Icon = info.Icon })
	end
	for _, id in { "Eruption", "Blizzard", "MeteorShower" } do
		local info = GameConfig.Events.Storms[id]
		if info then
			table.insert(events, { Id = id, Name = info.Name, Icon = info.Icon })
		end
	end
	local eventRow = nil
	for i, event in events do
		if (i - 1) % 2 == 0 then
			eventRow = row(50)
		end
		button(eventRow :: Frame, ("%s %s"):format(event.Icon, event.Name), 190, Color3.fromRGB(230, 120, 40), function()
			send({ Kind = "Event", EventId = event.Id, Global = global })
		end)
	end
	Kit.label({
		Text = "ALL SERVERS events wait for any event already running there. Storms only hit players who can reach that region.",
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 36),
		TextWrapped = true,
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Tiny,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = scroll,
	})

	-- PLAYER FEEDBACK
	heading("💬 PLAYER FEEDBACK")
	local kindLabels = {}
	for _, kind in GameConfig.Feedback.Kinds do
		kindLabels[kind.Id] = kind.Label
	end
	local feedbackRow = row(46)
	local summary = Kit.label({ Size = UDim2.new(1, -170, 1, 0), Text = "Tap LOAD to read what players sent", Font = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, LayoutOrder = 2, Parent = feedbackRow })
	local loadButton = button(feedbackRow, "📥 LOAD", 150, Theme.Color.Info, function()
		summary.Text = "Loading..."
		send({ Kind = "ReadFeedback" })
	end)
	loadButton.LayoutOrder = 1
	local list = Kit.new("Frame", { LayoutOrder = nextOrder(), Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = scroll }, { Kit.list(Enum.FillDirection.Vertical, 6) })
	Net.Get("AdminFeedback").OnClientEvent:Connect(function(payload)
		for _, child in list:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		local entries = if type(payload) == "table" and type(payload.Entries) == "table" then payload.Entries else {}
		local up, down = 0, 0
		for i, entry in entries do
			up += if entry.v == 1 then 1 else 0
			down += if entry.v == -1 then 1 else 0
			local tag = kindLabels[entry.k] or (if entry.v == 1 then "👍" elseif entry.v == -1 then "👎" else "💬")
			local when = os.date("!%b %d %H:%M", tonumber(entry.t) or 0)
			local message = if type(entry.m) == "string" and entry.m ~= "" then entry.m else "(no message)"
			local rowFrame = Kit.new("Frame", { LayoutOrder = i, Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0, Parent = list }, { Kit.corner(Theme.Radius.Medium), Kit.padding(8), Kit.list(Enum.FillDirection.Vertical, 2) })
			Kit.label({ Size = UDim2.new(1, 0, 0, 18), Text = ("%s  •  %s UTC  •  %d banked  •  Ascension %d"):format(tag, when, tonumber(entry.x) or 0, tonumber(entry.a) or 0), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Gold, TextXAlignment = Enum.TextXAlignment.Left, Parent = rowFrame })
			Kit.label({ Size = UDim2.fromScale(1, 0), AutomaticSize = Enum.AutomaticSize.Y, Text = message, TextWrapped = true, Font = Theme.Font.Body, TextSize = 17, TextColor3 = Theme.Color.Text, TextXAlignment = Enum.TextXAlignment.Left, Parent = rowFrame })
		end
		local days = if type(payload) == "table" then tonumber(payload.Days) or 7 else 7
		if type(payload) == "table" and type(payload.Error) == "string" then
			summary.Text = "⚠ " .. payload.Error
		elseif #entries == 0 then
			summary.Text = ("Nothing in the last %d days yet"):format(days)
		else
			summary.Text = ("%d messages in %d days  •  👍 %d  👎 %d"):format(#entries, days, up, down)
		end
	end)

	return {
		Refresh = function() end,
	}
end

return Admin
