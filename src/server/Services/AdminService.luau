-- 🛡 ADMIN PANEL (Steal-a-Brainrot style "admin abuse"), for the owner / admins only
-- (EventService.IsAdmin). From the panel an admin can, on THIS server or on EVERY server:
--   * BROADCAST a message: a big banner on every screen (text-filtered, like everything
--     players see); optionally also pinned on the Info Board (NewsService).
--   * START an event: Treasure Rain, Cursed Hour, Gold Rush, the Deep South storms.
--   * GIFT A VAULT SKIN to anyone by name - online on any server now, or on their next join
--     (pending gifts wait in the DataStore "SATGifts").
--   * DROP A TREASURE - any treasure (the admin-only EVENT treasures too), any mutation - at your
--     feet or next to every player, here or on every server.
--   * READ PLAYER FEEDBACK: the last week of messages from the 💬 button and the Info Board.
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
local FeedbackService = require(script.Parent.FeedbackService)
local VaultService = require(script.Parent.VaultService)
local TreasureService = require(script.Parent.TreasureService)
local PlayerData = require(script.Parent.PlayerData)
local Treasures = require(Shared.Config.Treasures)
local Mutations = require(Shared.Config.Mutations)
local Rarities = require(Shared.Config.Rarities)
local VaultSkins = require(Shared.Config.VaultSkins)
local Zones = require(Shared.Util.Zones)

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

-- GIFTS -------------------------------------------------------------------------------------

local GIFTS = "SATGifts" -- key = user id, value = { [skinId] = gifter's name }
local function giftStore(): DataStore?
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, GIFTS)
	return if ok then result else nil
end

local function forgetGift(userId: number, skinId: string)
	local s = giftStore()
	if s then
		pcall(s.UpdateAsync, s, tostring(userId), function(old)
			if type(old) ~= "table" then
				return nil
			end
			old[skinId] = nil
			return old
		end)
	end
end

-- On whichever server the player is: put it on their vault.
local function applyGift(userId: number, skinId: string, from: string)
	local player = Players:GetPlayerByUserId(userId)
	if player and VaultService.GrantSkin(player, skinId, from) then
		task.spawn(forgetGift, userId, skinId)
	end
end

-- Gifts that waited for the player to come online.
local function deliverPending(player: Player)
	local s = giftStore()
	if not s then
		return
	end
	local ok, pending = pcall(s.GetAsync, s, tostring(player.UserId))
	if not ok or type(pending) ~= "table" then
		return
	end
	for skinId, from in pending do
		if type(skinId) == "string" and player.Parent then
			VaultService.GrantSkin(player, skinId, if type(from) == "string" then from else nil)
		end
	end
	pcall(s.RemoveAsync, s, tostring(player.UserId))
end

-- A name typed in the panel -> a user id: someone in this server (name or display name), a
-- raw user id, or any Roblox username.
local function resolveUserId(text: string): number?
	text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("^@", "")
	if text == "" then
		return nil
	end
	local lower = text:lower()
	for _, p in Players:GetPlayers() do
		if p.Name:lower() == lower or p.DisplayName:lower() == lower then
			return p.UserId
		end
	end
	local asNumber = tonumber(text)
	if asNumber and asNumber > 0 then
		return math.floor(asNumber)
	end
	local ok, id = pcall(Players.GetUserIdFromNameAsync, Players, text)
	return if ok and type(id) == "number" then id else nil
end

-- DROPS -------------------------------------------------------------------------------------

local dropParams = RaycastParams.new()
dropParams.FilterType = Enum.RaycastFilterType.Exclude
dropParams.IgnoreWater = true

local function groundNear(position: Vector3): Vector3?
	local exclude: { Instance } = {}
	for _, name in { "Treasures", "TreasureMarkers", "Guardians" } do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(exclude, f)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	dropParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(position + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), dropParams)
	return if hit then hit.Position else nil
end

-- `count` of treasure `def` falling from the sky around each position.
local function dropAround(positions: { Vector3 }, def, mutation: string, count: number)
	local rng = Random.new()
	for _, centre in positions do
		for i = 1, count do
			local a = (i / count) * 2 * math.pi + rng:NextNumber(0, 1)
			local r = rng:NextNumber(6, 11)
			local ground = groundNear(centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r))
			if ground then
				TreasureService.SpawnFalling(def, ground, 45, 1.3, cfg.DropLifetime, Zones.AreaId(ground), mutation)
			end
		end
	end
end

local function announceDrop(def, mutation: string, count: number, from: string, everyone: boolean)
	local info = Rarities.Info[def.Rarity]
	local name = (if mutation ~= "" then mutation:upper() .. " " else "") .. def.Name:upper()
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = ("✨ ADMIN DROP: %s%s"):format(name, if count > 1 then (" x%d"):format(count) else ""),
		Text = if everyone then ("From %s - one is falling right next to YOU. Grab it!"):format(from) else ("%s is dropping it - race to it!"):format(from),
		Tone = "Reward",
		Duration = 6,
	})
	Net.FireAll("Notify", { Kind = "Social", Text = ("%s %s DROPPED %s"):format(info and info.Glyph or "✨", from:upper(), name), Rarity = def.Rarity })
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = "TreasureRain" })
end

local function applyDropEveryone(treasureId: string, mutation: string, count: number, from: string)
	local def = Treasures.Get(treasureId)
	if not def then
		return
	end
	local positions = {}
	for _, p in Players:GetPlayers() do
		local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root then
			table.insert(positions, root.Position)
		end
	end
	announceDrop(def, mutation, count, from, true)
	dropAround(positions, def, mutation, count)
end

local function apply(data)
	if data.Kind == "GiftSkin" and type(data.UserId) == "number" and type(data.Skin) == "string" then
		applyGift(data.UserId, data.Skin, tostring(data.From or "An admin"))
		return
	elseif data.Kind == "Drop" and type(data.Treasure) == "string" then
		applyDropEveryone(data.Treasure, if type(data.Mutation) == "string" then data.Mutation else "", math.clamp(tonumber(data.Count) or 1, 1, 10), tostring(data.From or "An admin"))
		return
	end
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
	elseif kind == "GiftSkin" and type(action.Skin) == "string" and type(action.Target) == "string" then
		local skin = VaultSkins.ById[action.Skin]
		if not skin then
			toast(player, "Pick a skin first", false)
			return
		end
		local target = string.sub(action.Target, 1, 40)
		task.spawn(function()
			local userId = resolveUserId(target)
			if not userId then
				toast(player, ("No player called \"%s\""):format(target), false)
				return
			end
			-- Remembered first: if they aren't online anywhere, it's waiting for their next join.
			local s = giftStore()
			if s then
				pcall(s.UpdateAsync, s, tostring(userId), function(old)
					local gifts = if type(old) == "table" then old else {}
					gifts[skin.Id] = player.DisplayName
					return gifts
				end)
			end
			send({ Kind = "GiftSkin", UserId = userId, Skin = skin.Id, From = player.DisplayName }, true)
			toast(player, ("🎁 %s %s sent to %s"):format(skin.Icon, skin.Name, target), true)
			Analytics.Event(player, "AdminAction", { Kind = "GiftSkin", Skin = skin.Id, Global = true })
		end)
		return
	elseif kind == "Drop" and type(action.Treasure) == "string" then
		local def = Treasures.Get(action.Treasure)
		if not def then
			toast(player, "Pick a treasure first", false)
			return
		end
		local mutation = if type(action.Mutation) == "string" and Mutations.Info[action.Mutation] then action.Mutation else ""
		local count = math.clamp(math.floor(tonumber(action.Count) or 1), 1, 10)
		if action.Where == "Everyone" then
			send({ Kind = "Drop", Treasure = def.Id, Mutation = mutation, Count = count, From = player.DisplayName }, global)
			toast(player, ("✨ Dropped next to every player%s"):format(if global then " on every server" else ""), true)
		else
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root then
				return
			end
			announceDrop(def, mutation, count, player.DisplayName, false)
			dropAround({ root.Position }, def, mutation, count)
			toast(player, "✨ Dropped at your feet", true)
		end
	elseif kind == "ReadFeedback" then
		task.spawn(FeedbackService.SendToAdmin, player)
		return
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
	PlayerData.Loaded:Connect(function(player)
		task.delay(6, deliverPending, player) -- after the vault is set up
	end)
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
