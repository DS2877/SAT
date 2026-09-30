-- 🛡 ADMIN PANEL (owners / admins only; the server checks every action: Services/AdminService).
-- Pick THIS SERVER or ALL SERVERS at the top, then:
--   📢 send a message as a banner on every screen (optionally pinned on the Info Board)
--   ⚡ run a global boost (luck / cash / mutations / strength) for N minutes, or end them
--   🎉 start an event (Treasure Rain, Cursed Hour, Gold Rush, the Deep South storms)
--   🎁 gift a vault skin to anyone by name (online anywhere now, or waiting for their next join)
--   ✨ drop any treasure (the EVENT ones too) with any mutation - at your feet or by everyone
--   💬 read player feedback (the last week, newest first; no names are ever stored)
-- Built for a phone first: big buttons, one scrolling column.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Mutations = require(Shared.Config.Mutations)
local VaultSkins = require(Shared.Config.VaultSkins)
local Players = game:GetService("Players")
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

	-- A horizontally scrolling row of chips; returns (frame, add(text, color, onClick) -> button).
	local function chipRow(height: number)
		local frame = Kit.new("ScrollingFrame", {
			LayoutOrder = nextOrder(),
			Size = UDim2.new(1, 0, 0, height),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 4,
			ScrollingDirection = Enum.ScrollingDirection.X,
			AutomaticCanvasSize = Enum.AutomaticSize.X,
			CanvasSize = UDim2.new(),
			Parent = scroll,
		}, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
		local function add(text: string, color: Color3, onClick: () -> ()): TextButton
			local b = Kit.button({ Size = UDim2.new(0, 0, 1, -6), AutomaticSize = Enum.AutomaticSize.X, Text = "  " .. text .. "  ", TextSize = Theme.TextSize.Small, Font = Theme.Font.Display, BackgroundColor3 = color, TextColor3 = Color3.new(1, 1, 1), Parent = frame }, onClick)
			return b
		end
		return frame, add
	end
	local function paint(buttons: { [any]: TextButton }, selected: any, on: Color3?)
		for key, b in buttons do
			b.BackgroundColor3 = if key == selected then (on or ON) else OFF
		end
	end

	-- GIFT A VAULT SKIN
	heading("🎁 GIFT A VAULT SKIN")
	local giftBox = Kit.new("TextBox", {
		LayoutOrder = nextOrder(),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		Font = Theme.Font.Bold,
		TextSize = 18,
		TextColor3 = Theme.Color.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		PlaceholderText = "Username (any player - or tap someone in this server below)",
		PlaceholderColor3 = Theme.Color.TextDim,
		Text = "",
		Parent = scroll,
	}, { Kit.corner(Theme.Radius.Medium), Kit.padding(0, 10) })
	local playerRowFrame, addPlayer = chipRow(40)
	local function refreshPlayers()
		for _, child in playerRowFrame:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for _, p in Players:GetPlayers() do
			addPlayer("👤 " .. p.DisplayName, OFF, function()
				giftBox.Text = p.Name
			end)
		end
	end
	refreshPlayers()
	Players.PlayerAdded:Connect(refreshPlayers)
	Players.PlayerRemoving:Connect(function()
		task.defer(refreshPlayers)
	end)
	local giftSkin: string? = nil
	local skinButtons: { [string]: TextButton } = {}
	local _, addSkin = chipRow(44)
	for _, skin in VaultSkins.List do
		if skin.Id ~= VaultSkins.Default then
			skinButtons[skin.Id] = addSkin(("%s %s"):format(skin.Icon, skin.Name), OFF, function()
				giftSkin = skin.Id
				paint(skinButtons, giftSkin, Color3.fromRGB(120, 200, 255))
			end)
		end
	end
	local giftRow = row(46)
	button(giftRow, "🎁 GIVE SKIN", 200, Color3.fromRGB(60, 160, 110), function()
		if not giftSkin or giftBox.Text:match("^%s*$") then
			Sounds.Play("Error")
			return
		end
		send({ Kind = "GiftSkin", Target = giftBox.Text, Skin = giftSkin })
	end)
	Kit.label({ Text = "Theirs for good - it goes straight on their vault. Offline? They get it on their next join.", Size = UDim2.new(1, -210, 1, 0), LayoutOrder = 2, TextWrapped = true, Font = Theme.Font.Bold, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = giftRow })

	-- DROP A TREASURE
	heading("✨ DROP A TREASURE")
	local dropRarity = "Event"
	local dropTreasure: string? = nil
	local dropMutation = ""
	local dropCount = GameConfig.Admin.DropCounts[1]
	local rarityButtons: { [string]: TextButton } = {}
	local treasureRowFrame, addTreasure = nil, nil
	local selectedLabel
	local function listTreasures()
		for _, child in treasureRowFrame:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local buttons: { [string]: TextButton } = {}
		for _, def in Treasures.List do
			local fits = if dropRarity == "Event" then def.AdminOnly == true else (def.Rarity == dropRarity and not def.AdminOnly)
			if fits then
				local info = Rarities.Info[def.Rarity]
				buttons[def.Id] = addTreasure(def.Name, OFF, function()
					dropTreasure = def.Id
					selectedLabel.Text = ("Selected: %s %s (%s)"):format(info and info.Glyph or "", def.Name, def.Rarity)
					selectedLabel.TextColor3 = info and info.Color or Theme.Color.Text
					for id, b in buttons do
						b.BackgroundColor3 = if id == dropTreasure then (info and info.Color or ON) else OFF
					end
				end)
			end
		end
	end
	local _, addRarity = chipRow(40)
	local rarityOrder = { "Event" }
	for _, name in Rarities.Order do
		table.insert(rarityOrder, name)
	end
	for _, name in rarityOrder do
		local info = Rarities.Info[name]
		rarityButtons[name] = addRarity(if name == "Event" then "⭐ EVENT ONLY" else name:upper(), OFF, function()
			dropRarity = name
			paint(rarityButtons, dropRarity, if info then info.Color else Color3.fromRGB(230, 120, 40))
			listTreasures()
		end)
	end
	treasureRowFrame, addTreasure = chipRow(44)
	selectedLabel = Kit.label({ LayoutOrder = nextOrder(), Text = "Pick a treasure above", Size = UDim2.new(1, 0, 0, 20), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = scroll })
	local mutationButtons: { [string]: TextButton } = {}
	local _, addMutation = chipRow(40)
	mutationButtons[""] = addMutation("NO MUTATION", ON, function()
		dropMutation = ""
		paint(mutationButtons, dropMutation)
	end)
	for _, name in Mutations.Order do
		local info = Mutations.Info[name]
		mutationButtons[name] = addMutation(name:upper(), OFF, function()
			dropMutation = name
			paint(mutationButtons, dropMutation, Mutations.Color(info.Sparkle):Lerp(Color3.new(0, 0, 0), 0.35))
		end)
	end
	local countButtons: { [number]: TextButton } = {}
	local countRow = row(40)
	for _, n in GameConfig.Admin.DropCounts do
		countButtons[n] = button(countRow, ("x%d"):format(n), 70, if n == dropCount then ON else OFF, function()
			dropCount = n
			paint(countButtons, dropCount)
		end)
	end
	local dropRow = row(50)
	local function drop(where: string)
		if not dropTreasure then
			Sounds.Play("Error")
			return
		end
		send({ Kind = "Drop", Treasure = dropTreasure, Mutation = dropMutation, Count = dropCount, Where = where, Global = global })
	end
	button(dropRow, "✨ AT MY FEET", 180, Color3.fromRGB(230, 150, 40), function()
		drop("Me")
	end)
	button(dropRow, "🌧 NEXT TO EVERYONE", 230, Color3.fromRGB(200, 80, 200), function()
		drop("Everyone")
	end)
	paint(rarityButtons, dropRarity, Color3.fromRGB(230, 120, 40))
	listTreasures()

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
