-- 🛡 ADMIN PANEL (Steal-a-Brainrot style "admin abuse"), for the owner / admins only
-- (EventService.IsAdmin). From the panel an admin can, on THIS server or on EVERY server:
--   * BROADCAST a message: a big banner on every screen (text-filtered, like everything
--     players see); optionally also pinned on the Info Board (NewsService).
--   * START an event: Treasure Rain, Cursed Hour, Gold Rush, the Deep South storms.
--   * RUN a global boost (GameConfig.GlobalBoosts): LUCK, CASH, MUTATIONS, STRENGTH for N minutes.
--     Boosts are saved (DataStore "SATAdmin") so a server that starts mid-boost joins in.
-- Every server hears about global actions through MessagingService topic "SATAdmin".
-- The Like Goal (Services/LikeGoal) starts its reward boost through AdminService.StartBoost.

local DataStoreService = game:GetService("DataStoreService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local EventService = require(script.Parent.EventService)
local NewsService = require(script.Parent.NewsService)
local Analytics = require(script.Parent.Analytics)

local AdminService = {}

local cfg = GameConfig.Admin
local TOPIC = "SATAdmin"
local STORE, KEY = "SATAdmin", "Boosts"
local MAX_AGE = 60 -- ignore stale broadcasts (seconds)

local function store(): DataStore?
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE)
	return if ok then result else nil
end

local function toast(player: Player, text: string, ok: boolean)
	Net.Fire("Notify", player, { Kind = "Toast", Text = text, Tone = if ok then "Info" else "Warn" })
end

-- APPLY (runs on every server that hears about it) -------------------------------------

-- Shown as the speaker talking: their head + a big speech bubble (Notifications.Announce).
local function applyBroadcast(text: string, name: string, userId: number)
	Net.FireAll("Notify", { Kind = "Announcement", Text = text, Name = name, UserId = userId })
	Net.FireAll("Feedback", { Type = "AdminBroadcast" })
end

-- A boost ending at `endsAt` (unix time). Only ever extends: an older, shorter message can't
-- cut a running boost short (use EndBoosts for that).
local function applyBoost(kind: string, endsAt: number, reason: string?)
	local info = GameConfig.GlobalBoosts[kind]
	if not info then
		return
	end
	local current = workspace:GetAttribute("Boost_" .. kind)
	if type(current) == "number" and current >= endsAt then
		return
	end
	workspace:SetAttribute("Boost_" .. kind, endsAt)
	local minutes = math.max(1, math.floor((endsAt - os.time()) / 60 + 0.5))
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = ("%s %s x%d FOR %d MIN!"):format(info.Icon, info.Name, info.Multiplier, minutes),
		Text = reason or info.Text,
		Tone = "Reward",
		Duration = 6,
	})
	Net.FireAll("Feedback", { Type = "GlobalBoost", Kind = kind })
end

local function applyEnd()
	for _, kind in GameConfig.GlobalBoosts.Order do
		workspace:SetAttribute("Boost_" .. kind, 0)
	end
	Net.FireAll("Notify", { Kind = "Toast", Text = "The boosts have ended", Tone = "Info" })
end

local function apply(data)
	if data.Kind == "Broadcast" and type(data.Text) == "string" then
		applyBroadcast(data.Text, tostring(data.From or "ANNOUNCEMENT"), tonumber(data.UserId) or 0)
	elseif data.Kind == "Boost" and type(data.Boost) == "string" and type(data.EndsAt) == "number" then
		applyBoost(data.Boost, data.EndsAt, if type(data.Reason) == "string" then data.Reason else nil)
	elseif data.Kind == "EndBoosts" then
		applyEnd()
	end
end

-- Here only, or on every server (this one included: we hear our own message).
local function send(data, global: boolean): boolean
	if not global or RunService:IsStudio() then
		apply(data)
		return true
	end
	data.Sent = os.time()
	local ok, err = pcall(MessagingService.PublishAsync, MessagingService, TOPIC, data)
	if not ok then
		warn("[Admin] broadcast failed:", err)
		apply(data)
	end
	return ok
end

-- Saved boosts, so a server that starts later joins a running boost.
local function saveBoost(kind: string, endsAt: number?)
	task.spawn(function()
		local s = store()
		if not s then
			return
		end
		pcall(s.UpdateAsync, s, KEY, function(old)
			local boosts = if type(old) == "table" then old else {}
			if endsAt then
				boosts[kind] = math.max(tonumber(boosts[kind]) or 0, endsAt)
			else
				boosts = {}
			end
			return boosts
		end)
	end)
end

-- Starts a boost for `minutes` (Like Goal and admins). Returns whether it went out everywhere.
function AdminService.StartBoost(kind: string, minutes: number, global: boolean, reason: string?): boolean
	if not GameConfig.GlobalBoosts[kind] then
		return false
	end
	local endsAt = os.time() + math.floor(math.clamp(minutes, 1, cfg.MaxBoostMinutes) * 60)
	if global then
		saveBoost(kind, endsAt)
	end
	return send({ Kind = "Boost", Boost = kind, EndsAt = endsAt, Reason = reason }, global)
end

-- ACTIONS FROM THE PANEL ---------------------------------------------------------------

local function filtered(player: Player, raw: any): string?
	if type(raw) ~= "string" then
		return nil
	end
	local text = string.sub(raw:gsub("^%s+", ""):gsub("%s+$", ""), 1, cfg.MaxBroadcast)
	if text == "" then
		return nil
	end
	local ok, result = pcall(function()
		return TextService:FilterStringAsync(text, player.UserId):GetNonChatStringForBroadcastAsync()
	end)
	return if ok then result else nil
end

local function onAction(player: Player, action: any)
	if not EventService.IsAdmin(player) or type(action) ~= "table" then
		return
	end
	local global = action.Global == true
	local kind = action.Kind
	if kind == "Broadcast" then
		local text = filtered(player, action.Text)
		if not text then
			toast(player, "Type a message first (or the text filter is busy - try again)", false)
			return
		end
		local ok = send({ Kind = "Broadcast", Text = text, From = player.DisplayName, UserId = player.UserId }, global)
		if action.Pin == true then
			NewsService.Announce(player, text)
		end
		toast(player, if ok then (if global then "Sent to every server" else "Sent to this server") else "Broadcast failed - shown here only", ok)
	elseif kind == "Event" and type(action.EventId) == "string" then
		local ok, message = EventService.Host(action.EventId, global)
		toast(player, message, ok)
	elseif kind == "Boost" and type(action.Boost) == "string" and type(action.Minutes) == "number" then
		local ok = AdminService.StartBoost(action.Boost, action.Minutes, global)
		toast(player, if ok then "Boost started" .. (if global then " on every server" else " here") else "Boost failed", ok)
	elseif kind == "EndBoosts" then
		if global then
			task.spawn(function()
				local s = store()
				if s then
					pcall(s.SetAsync, s, KEY, {})
				end
			end)
		end
		send({ Kind = "EndBoosts" }, global)
		toast(player, "Boosts ended" .. (if global then " everywhere" else " here"), true)
	else
		return
	end
	Analytics.Event(player, "AdminAction", { Kind = tostring(kind), Global = global })
end

function AdminService.Init()
	for _, kind in GameConfig.GlobalBoosts.Order do
		workspace:SetAttribute("Boost_" .. kind, 0)
	end
	-- The panel only shows for admins (the server still checks every action).
	local function mark(player: Player)
		player:SetAttribute("IsAdmin", EventService.IsAdmin(player))
	end
	Players.PlayerAdded:Connect(mark)
	for _, player in Players:GetPlayers() do
		mark(player)
	end
	Net.On("AdminAction", onAction, 2)
	if RunService:IsStudio() then
		return
	end
	task.spawn(function()
		local ok, err = pcall(MessagingService.SubscribeAsync, MessagingService, TOPIC, function(message)
			local data = message.Data
			if type(data) == "table" and math.abs(os.time() - (tonumber(data.Sent) or 0)) <= MAX_AGE then
				apply(data)
			end
		end)
		if not ok then
			warn("[Admin] subscribe failed:", err)
		end
	end)
	-- Join any boost that's still running on the other servers.
	task.spawn(function()
		local s = store()
		if not s then
			return
		end
		local ok, boosts = pcall(s.GetAsync, s, KEY)
		if ok and type(boosts) == "table" then
			for kind, endsAt in boosts do
				if type(kind) == "string" and type(endsAt) == "number" and endsAt > os.time() + 5 then
					workspace:SetAttribute("Boost_" .. kind, endsAt)
				end
			end
		end
	end)
end

return AdminService
