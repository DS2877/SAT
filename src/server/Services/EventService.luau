-- Server events: rare, announced moments that pull players to one place.
-- One event at a time. State is published as workspace attributes so every client
-- (and late joiners) can show it without extra remotes:
--   EventId, EventName, EventSite, EventPosition (Vector3), EventEndsAt (server time)
--
-- Adding an event = add a runner to Runners + config in GameConfig.Events.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextChatService = game:GetService("TextChatService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local WorldLayout = require(Shared.Config.WorldLayout)
local TreasureRoll = require(Shared.Logic.TreasureRoll)
local Net = require(Shared.Net)

local TreasureService = require(script.Parent.TreasureService)
local Analytics = require(script.Parent.Analytics)

local EventService = {}

local cfg = GameConfig.Events
local rng = Random.new()
local active: string? = nil

local function publish(id: string?, name: string?, site: string?, position: Vector3?, endsAt: number?)
	workspace:SetAttribute("EventId", id or "")
	workspace:SetAttribute("EventName", name or "")
	workspace:SetAttribute("EventSite", site or "")
	workspace:SetAttribute("EventPosition", position or Vector3.zero)
	workspace:SetAttribute("EventEndsAt", endsAt or 0)
end

local function groundAt(position: Vector3): Vector3?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, name in { "Treasures", "Guardians" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local result = workspace:Raycast(position + Vector3.new(0, 250, 0), Vector3.new(0, -400, 0), params)
	if result and result.Material ~= Enum.Material.Water then
		return result.Position
	end
	return nil
end

-- Rarity-weighted pick across all treasures (events ignore spawn areas).
local function rollRain(weights)
	local perRarity = {}
	for _, def in Treasures.List do
		if weights[def.Rarity] then
			perRarity[def.Rarity] = (perRarity[def.Rarity] or 0) + 1
		end
	end
	local candidates = {}
	for _, def in Treasures.List do
		local w = weights[def.Rarity]
		if w then
			table.insert(candidates, { Def = def, Weight = w / perRarity[def.Rarity] })
		end
	end
	return TreasureRoll.Pick(candidates, function()
		return rng:NextNumber()
	end)
end

local Runners = {}

function Runners.TreasureRain()
	local rain = cfg.TreasureRain
	local site = WorldLayout.EventSites[rng:NextInteger(1, #WorldLayout.EventSites)]
	local endsAt = workspace:GetServerTimeNow() + rain.Duration
	publish("TreasureRain", rain.Name, site.Name, site.Position, endsAt)
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = ("%s %s!"):format(rain.Icon, rain.Name),
		Text = ("Treasure is falling at %s!"):format(site.Name),
		Tone = "Reward",
	})
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = "TreasureRain" })

	local interval = rain.Duration / rain.Waves
	for _ = 1, rain.Waves do
		for _ = 1, rain.PerWave do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = math.sqrt(rng:NextNumber()) * rain.Radius
			local ground = groundAt(site.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
			local def = rollRain(rain.RarityWeights)
			if ground and def then
				TreasureService.SpawnFalling(def, ground, rain.DropHeight, rain.FallTime, rain.Lifetime)
				if Rarities.AtLeast(def.Rarity, "Epic") then
					Net.FireAll("Notify", {
						Kind = "Social",
						Text = ("%s %s IS FALLING AT %s"):format(Rarities.Info[def.Rarity].Glyph, def.Name:upper(), site.Name),
						Rarity = def.Rarity,
					})
				end
			end
		end
		task.wait(interval)
	end
end

function Runners.CursedHour()
	local curse = cfg.CursedHour
	local endsAt = workspace:GetServerTimeNow() + curse.Duration
	publish("CursedHour", curse.Name, "THE WHOLE ISLAND", nil, endsAt)
	workspace:SetAttribute("GuardianRage", curse.GuardianRage)
	TreasureService.SetRarityBoost(curse.RarityBoost)
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = ("%s %s!"):format(curse.Icon, curse.Name),
		Text = "Rare treasure everywhere. Guardians are furious.",
		Tone = "Danger",
	})
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = "CursedHour" })
	local ok, err = pcall(task.wait, curse.Duration)
	workspace:SetAttribute("GuardianRage", 1)
	TreasureService.SetRarityBoost(nil)
	Net.FireAll("Notify", { Kind = "Toast", Text = "The curse has lifted.", Tone = "Info" })
	if not ok then
		error(err)
	end
end

local function pickEvent(): string
	local total = 0
	for id, weight in cfg.Weights do
		if Runners[id] then
			total += weight
		end
	end
	local roll = rng:NextNumber() * total
	for id, weight in cfg.Weights do
		if Runners[id] then
			roll -= weight
			if roll <= 0 then
				return id
			end
		end
	end
	return "TreasureRain"
end

function EventService.IsActive(): boolean
	return active ~= nil
end

function EventService.Start(eventId: string): boolean
	local runner = Runners[eventId]
	if not runner or active then
		return false
	end
	active = eventId
	for _, player in Players:GetPlayers() do
		Analytics.Event(player, "EventStarted", { Event = eventId })
	end
	task.spawn(function()
		local ok, err = pcall(runner)
		if not ok then
			warn("[Events] " .. eventId .. " failed:", err)
		end
		active = nil
		publish(nil)
	end)
	return true
end

-- ADMIN COMMANDS --------------------------------------------------------------------

local ALIASES = { rain = "TreasureRain", treasurerain = "TreasureRain", cursed = "CursedHour", curse = "CursedHour" }

local function isAdmin(player: Player): boolean
	if RunService:IsStudio() or table.find(cfg.AdminUserIds, player.UserId) then
		return true
	end
	-- Group-owned games: list admins in GameConfig.Events.AdminUserIds.
	return game.CreatorType == Enum.CreatorType.User and player.UserId == game.CreatorId
end

local lastCommand: { [Player]: number } = {}
local function handleCommand(player: Player, message: string)
	local name = string.match(string.lower(message), "^/event%s+(%w+)")
	if not name or not isAdmin(player) then
		return
	end
	-- Legacy Chatted and TextChatCommand can both fire for one message.
	if os.clock() - (lastCommand[player] or 0) < 1 then
		return
	end
	lastCommand[player] = os.clock()
	local eventId = ALIASES[name]
	local started = eventId ~= nil and EventService.Start(eventId)
	Net.Fire("Notify", player, {
		Kind = "Toast",
		Text = if started then "Event started: " .. eventId elseif active then "An event is already running" else "Unknown event (try /event rain or /event cursed)",
		Tone = if started then "Info" else "Warn",
	})
end

function EventService.Init()
	publish(nil)
	workspace:SetAttribute("GuardianRage", 1)
	Players.PlayerAdded:Connect(function(player)
		player.Chatted:Connect(function(message)
			handleCommand(player, message)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastCommand[player] = nil
	end)
	task.spawn(function()
		local commands = TextChatService:WaitForChild("TextChatCommands", 15)
		if commands then
			local command = Instance.new("TextChatCommand")
			command.Name = "SATEventCommand"
			command.PrimaryAlias = "/event"
			command.Parent = commands
			command.Triggered:Connect(function(source: TextSource, message: string)
				local player = Players:GetPlayerByUserId(source.UserId)
				if player then
					handleCommand(player, message)
				end
			end)
		end
	end)
end

function EventService.StartScheduler()
	task.spawn(function()
		task.wait(cfg.FirstDelay)
		while true do
			if #Players:GetPlayers() > 0 then
				EventService.Start(pickEvent())
			end
			task.wait(rng:NextNumber(cfg.IntervalMin, cfg.IntervalMax))
		end
	end)
end

return EventService
