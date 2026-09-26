-- The Info Board (Config/News, Logic/NewsBoard, Menus/News, Controllers/InfoBoard):
--   * Event sign-ups: players sign up at the board; a global count per event is kept in a
--     DataStore and shown to everyone (workspace attribute "Signups_<eventId>"). Signed-up
--     players who are online get a heads-up before the start and a banner when it goes live
--     (also on joining while it's on).
--   * "/announce <text>" (owners/admins, see EventService.IsAdmin): a live announcement on
--     every server's board and as a banner, filtered by Roblox's text filter, kept for
--     News.LiveAnnouncementHours. "/announce clear" takes it down.
--   * A one-time toast for returning players when there's a post they haven't read.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared
local News = require(Shared.Config.News)
local NewsBoard = require(Shared.Logic.NewsBoard)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local EventService = require(script.Parent.EventService)
local Analytics = require(script.Parent.Analytics)

local NewsService = {}

local SIGNUP_STORE = "SATEventSignups"
local NEWS_STORE = "SATNews"
local TOPIC = "SATNews"
local MAX_ANNOUNCEMENT = 200

local counts: { [string]: number } = {}
local reminded: { [Player]: { [string]: boolean } } = {}

local function store(name: string): DataStore?
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, name)
	return if ok then result else nil
end

local function publishCount(id: string)
	workspace:SetAttribute("Signups_" .. id, math.max(0, counts[id] or 0))
end

local function refreshCounts()
	local signups = store(SIGNUP_STORE)
	for _, event in News.Events do
		if signups then
			local ok, value = pcall(signups.GetAsync, signups, event.Id)
			if ok then
				counts[event.Id] = tonumber(value) or 0
			end
		end
		publishCount(event.Id)
	end
end

-- EVENT SIGN-UPS ------------------------------------------------------------------------

local function onSignup(player: Player, eventId: any, wantIn: any)
	if type(eventId) ~= "string" or type(wantIn) ~= "boolean" then
		return
	end
	local event = News.GetEvent(eventId)
	local data = PlayerData.Get(player)
	if not event or not data or NewsBoard.Status(event, os.time()) == "Ended" then
		return
	end
	local isIn = data.EventSignups[eventId] ~= nil
	if isIn == wantIn then
		return
	end
	PlayerData.Update(player, function(d)
		d.EventSignups[eventId] = if wantIn then os.time() else nil
	end)
	local delta = if wantIn then 1 else -1
	counts[eventId] = math.max(0, (counts[eventId] or 0) + delta)
	publishCount(eventId)
	task.spawn(function()
		local signups = store(SIGNUP_STORE)
		if signups then
			pcall(signups.IncrementAsync, signups, eventId, delta)
		end
	end)
	if wantIn then
		Net.Fire("Notify", player, { Kind = "Toast", Text = ("✅ SIGNED UP! We'll ping you when %s starts."):format(event.Title), Tone = "Reward" })
		Analytics.Event(player, "EventSignup", { Event = eventId })
	end
end

-- Heads-up / live banners for signed-up players (once per player, event and phase).
local function remind(player: Player, now: number)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local sent = reminded[player]
	if not sent then
		sent = {}
		reminded[player] = sent
	end
	for _, event in News.Events do
		if data.EventSignups[event.Id] and event.StartsAt then
			local status = NewsBoard.Status(event, now)
			if status == "Live" and not sent[event.Id .. "Live"] then
				sent[event.Id .. "Live"] = true
				sent[event.Id .. "Soon"] = true
				Net.Fire("Notify", player, { Kind = "Banner", Title = ("🔴 %s IS LIVE!"):format(event.Title), Text = "You signed up - it's happening NOW", Tone = "Reward" })
			elseif status == "Upcoming" and event.StartsAt - now <= News.RemindBefore and not sent[event.Id .. "Soon"] then
				sent[event.Id .. "Soon"] = true
				Net.Fire("Notify", player, { Kind = "Banner", Title = ("%s %s IN %s"):format(event.Icon, event.Title, NewsBoard.Countdown(event.StartsAt - now)), Text = "You signed up - get ready!", Tone = "Info" })
			end
		end
	end
end

-- LIVE ANNOUNCEMENTS --------------------------------------------------------------------

local function applyLive(text: string, at: number)
	local fresh = text ~= "" and os.time() - at < News.LiveAnnouncementHours * 3600
	workspace:SetAttribute("NewsLiveText", if fresh then text else "")
	workspace:SetAttribute("NewsLiveAt", if fresh then at else 0)
end

local function onLiveMessage(data: any)
	if type(data) ~= "table" or type(data.Text) ~= "string" or type(data.At) ~= "number" then
		return
	end
	applyLive(data.Text, data.At)
	if data.Text ~= "" then
		Net.FireAll("Notify", { Kind = "Banner", Title = "📢 ANNOUNCEMENT", Text = data.Text, Tone = "Info", Duration = 6 })
	end
end

local function announce(player: Player, raw: string)
	local text = raw:gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Usage: /announce <text>  (or /announce clear)", Tone = "Warn" })
		return
	end
	if string.lower(text) == "clear" then
		text = ""
	else
		text = string.sub(text, 1, MAX_ANNOUNCEMENT)
		-- Everything shown to other players goes through Roblox's text filter.
		local ok, filtered = pcall(function()
			return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			Net.Fire("Notify", player, { Kind = "Toast", Text = "Couldn't post that (text filter unavailable) - try again", Tone = "Warn" })
			return
		end
		text = filtered
	end
	local payload = { Text = text, At = os.time() }
	task.spawn(function()
		local newsStore = store(NEWS_STORE)
		if newsStore then
			pcall(newsStore.SetAsync, newsStore, "Live", payload)
		end
	end)
	if RunService:IsStudio() then
		onLiveMessage(payload)
	else
		local ok = pcall(MessagingService.PublishAsync, MessagingService, TOPIC, payload)
		if not ok then
			onLiveMessage(payload) -- at least this server
		end
	end
	Net.Fire("Notify", player, { Kind = "Toast", Text = if text == "" then "Announcement cleared" else "Announcement posted on every server", Tone = "Info" })
end

local lastCommand: { [Player]: number } = {}
local function handleCommand(player: Player, message: string)
	local rest = string.match(message, "^/[Aa][Nn][Nn][Oo][Uu][Nn][Cc][Ee]%s*(.*)$")
	if not rest or not EventService.IsAdmin(player) then
		return
	end
	-- Legacy Chatted and TextChatCommand can both fire for one message.
	if os.clock() - (lastCommand[player] or 0) < 1 then
		return
	end
	lastCommand[player] = os.clock()
	announce(player, rest)
end

-- PLAYERS ---------------------------------------------------------------------------------

local function onLoaded(player: Player, data)
	remind(player, os.time())
	local unread = NewsBoard.UnreadCount(News.Posts, data.NewsSeen)
	local newest = News.Posts[1]
	if unread > 0 and newest and (data.Stats.Extractions or 0) > 0 then
		task.delay(25, function()
			if player.Parent then
				Net.Fire("Notify", player, { Kind = "Toast", Text = ("📰 NEW ON THE INFO BOARD: %s"):format(newest.Title), Tone = "Info" })
			end
		end)
	end
end

local function onSeen(player: Player, postId: any)
	if type(postId) ~= "string" or #postId > 64 then
		return
	end
	local data = PlayerData.Get(player)
	if data and data.NewsSeen ~= postId then
		PlayerData.Update(player, function(d)
			d.NewsSeen = postId
		end)
	end
end

function NewsService.Init()
	applyLive("", 0)
	Net.On("EventSignup", onSignup, 4)
	Net.On("NewsSeen", onSeen, 2)
	PlayerData.Loaded:Connect(onLoaded)
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			handleCommand(player, message)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		reminded[player] = nil
		lastCommand[player] = nil
	end)
	task.spawn(function()
		local commands = TextChatService:WaitForChild("TextChatCommands", 15)
		if commands then
			local command = Instance.new("TextChatCommand")
			command.Name = "SATAnnounceCommand"
			command.PrimaryAlias = "/announce"
			command.Parent = commands
			command.Triggered:Connect(function(source: TextSource, message: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					handleCommand(player, message)
				end
			end)
		end
	end)
	task.spawn(function()
		-- The current live announcement (if any), then keep in sync with the other servers.
		local newsStore = store(NEWS_STORE)
		if newsStore then
			local ok, live = pcall(newsStore.GetAsync, newsStore, "Live")
			if ok and type(live) == "table" and type(live.Text) == "string" and type(live.At) == "number" then
				applyLive(live.Text, live.At)
			end
		end
		if not RunService:IsStudio() then
			pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(message)
				onLiveMessage(message.Data)
			end)
		end
	end)
	task.spawn(function()
		while true do
			refreshCounts()
			for _ = 1, 8 do -- counts every 2 minutes, reminders every 15 s
				local now = os.time()
				for _, player in Players:GetPlayers() do
					remind(player, now)
				end
				-- An announcement past its time comes down by itself.
				local at = workspace:GetAttribute("NewsLiveAt")
				if type(at) == "number" and at > 0 and now - at >= News.LiveAnnouncementHours * 3600 then
					applyLive("", 0)
				end
				task.wait(15)
			end
		end
	end)
end

return NewsService
