-- Server events: rare, announced moments that pull players to ONE REGION of the island
-- (Wilds / Ruins / Coast / Falls) - never the whole map, so the rest stays calm and players
-- choose whether to rush over. Treasure Rain and the Deep South storms (RegionStorms) are
-- DAYTIME events;
-- Cursed Hour and Gold Rush are NIGHT modifiers that shape tonight's loot wave in one region
-- (rolled at nightfall by DayCycle, or forced by admins). One event at a time. State is published as workspace attributes
-- so every client (and late joiners) can show it without extra remotes:
--   EventId, EventName, EventSite, EventArea, EventPosition (Vector3), EventEndsAt (server time)
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
local DayNight = require(Shared.Logic.DayNight)
local Net = require(Shared.Net)

local TreasureService = require(script.Parent.TreasureService)
local Analytics = require(script.Parent.Analytics)
local RegionStorms = require(script.Parent.RegionStorms)

local EventService = {}

local cfg = GameConfig.Events
local rng = Random.new()
local active: string? = nil

type Site = { Area: string, Name: string, Icon: string?, Position: Vector3 }

-- "⚓ SHIPWRECK COAST EVENT!" - where it's happening, as the banner's headline.
local function headline(site: Site): string
	return ("%s %s EVENT!"):format(site.Icon or "✨", site.Name)
end

local function pickSite(): Site
	return WorldLayout.EventSites[rng:NextInteger(1, #WorldLayout.EventSites)]
end

local function publish(id: string?, name: string?, site: Site?, endsAt: number?)
	local position = site and site.Position
	workspace:SetAttribute("EventId", id or "")
	workspace:SetAttribute("EventName", name or "")
	workspace:SetAttribute("EventSite", if site then site.Name else "")
	workspace:SetAttribute("EventArea", if site then site.Area else "")
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

-- Rarity-weighted pick. Rare and above are the region's own treasures (a Coast rain drops
-- Coast treasure); Common/Uncommon filler can come from anywhere, because some regions (the
-- Falls) have no low-rarity natives and would otherwise rain only Epics.
local function rollRain(weights, area: string)
	local perRarity = {}
	local function eligible(def): boolean
		return weights[def.Rarity] ~= nil and (def.SpawnArea == area or Rarities.Rank(def.Rarity) <= 2)
	end
	for _, def in Treasures.List do
		if eligible(def) then
			perRarity[def.Rarity] = (perRarity[def.Rarity] or 0) + 1
		end
	end
	local candidates = {}
	for _, def in Treasures.List do
		local w = weights[def.Rarity]
		if w and eligible(def) then
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
	local site = pickSite()
	local endsAt = workspace:GetServerTimeNow() + rain.Duration
	publish("TreasureRain", rain.Name, site, endsAt)
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = headline(site),
		Text = ("%s %s - treasure is falling from the sky!"):format(rain.Icon, rain.Name),
		Tone = "Reward",
	})
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = "TreasureRain" })

	local interval = rain.Duration / rain.Waves
	for _ = 1, rain.Waves do
		for _ = 1, rain.PerWave do
			local angle = rng:NextNumber(0, math.pi * 2)
			local distance = math.sqrt(rng:NextNumber()) * rain.Radius
			local ground = groundAt(site.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance))
			local def = rollRain(rain.RarityWeights, site.Area)
			if ground and def then
				TreasureService.SpawnFalling(def, ground, rain.DropHeight, rain.FallTime, rain.Lifetime, site.Area)
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

-- Deep South storms (RegionStorms): Eruption, Blizzard, Meteor Shower.
for stormId in cfg.Storms do
	Runners[stormId] = function()
		RegionStorms.Run(stormId, publish, groundAt)
	end
end

-- Seconds until the end of the NEXT night (the loot wave a night modifier applies to).
local function untilNightEnds(): number
	local state = DayNight.State(workspace:GetServerTimeNow())
	if state.IsNight then
		return state.SecondsLeft
	end
	return state.SecondsLeft + GameConfig.DayNight.NightSeconds
end

local function tonight(): string
	return if DayNight.IsNight(workspace:GetServerTimeNow()) then "TONIGHT" else "NEXT NIGHT"
end

-- Cursed Hour: tonight's loot in the region is much rarer, and its guardians are furious
-- through the night and into the morning.
function Runners.CursedHour()
	local curse = cfg.CursedHour
	local site = pickSite()
	local waveEnds = untilNightEnds()
	local endsAt = workspace:GetServerTimeNow() + waveEnds + cfg.CurseLingerSeconds
	publish("CursedHour", curse.Name, site, endsAt)
	workspace:SetAttribute("GuardianRage", curse.GuardianRage)
	TreasureService.SetRegionBoost({ Area = site.Area, Rarity = curse.RarityBoost })
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = headline(site),
		Text = ("%s %s - %s: rare loot, furious guardians."):format(curse.Icon, curse.Name, tonight()),
		Tone = "Danger",
	})
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = "CursedHour" })
	local ok, err = pcall(task.wait, waveEnds)
	TreasureService.SetRegionBoost(nil)
	if ok then
		ok, err = pcall(task.wait, cfg.CurseLingerSeconds)
	end
	workspace:SetAttribute("GuardianRage", 1)
	Net.FireAll("Notify", { Kind = "Toast", Text = ("The curse on %s has lifted."):format(site.Name), Tone = "Info" })
	if not ok then
		error(err)
	end
end

-- Gold Rush: mutations (Silver / Gold / Diamond / Rainbow) far more likely in tonight's wave.
function Runners.GoldRush()
	local rush = cfg.GoldRush
	local site = pickSite()
	local waveEnds = untilNightEnds()
	publish("GoldRush", rush.Name, site, workspace:GetServerTimeNow() + waveEnds)
	TreasureService.SetRegionBoost({ Area = site.Area, Mutation = rush.MutationBoost })
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = headline(site),
		Text = ("%s %s - %s: mutated treasure x%d!"):format(rush.Icon, rush.Name, tonight(), rush.MutationBoost),
		Tone = "Reward",
	})
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = "GoldRush" })
	local ok, err = pcall(task.wait, waveEnds)
	TreasureService.SetRegionBoost(nil)
	if not ok then
		error(err)
	end
end

local function pickNightEvent(): string
	local total = 0
	for _, weight in cfg.NightWeights do
		total += weight
	end
	local roll = rng:NextNumber() * total
	for id, weight in cfg.NightWeights do
		roll -= weight
		if roll <= 0 then
			return id
		end
	end
	return "GoldRush"
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

local ALIASES = {
	rain = "TreasureRain",
	treasurerain = "TreasureRain",
	cursed = "CursedHour",
	curse = "CursedHour",
	gold = "GoldRush",
	goldrush = "GoldRush",
	eruption = "Eruption",
	volcano = "Eruption",
	blizzard = "Blizzard",
	meteor = "MeteorShower",
	meteors = "MeteorShower",
}

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
		Text = if started then "Event started: " .. eventId elseif active then "An event is already running" else "Unknown event (try /event rain, cursed, gold, eruption, blizzard or meteor)",
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

-- Called by DayCycle when night falls: maybe roll a night modifier for tonight's wave.
function EventService.OnNightfall()
	if not active and #Players:GetPlayers() > 0 and rng:NextNumber() < cfg.NightEventChance then
		EventService.Start(pickNightEvent())
	end
end

local function durationOf(eventId: string): number
	return if cfg.Storms[eventId] then cfg.Storms[eventId].Duration else cfg[eventId].Duration
end

-- A daytime event that fits before nightfall: Treasure Rain, or a Deep South storm if
-- someone on the server can reach that region.
local function pickDayEvent(secondsLeft: number): string?
	local options, total = {}, 0
	for id, weight in cfg.DaytimeWeights do
		if secondsLeft > durationOf(id) + 15 and (not cfg.Storms[id] or RegionStorms.Eligible(id)) then
			table.insert(options, { Id = id, Weight = weight })
			total += weight
		end
	end
	table.sort(options, function(a, b)
		return a.Id < b.Id
	end)
	local roll = rng:NextNumber() * total
	for _, option in options do
		roll -= option.Weight
		if roll <= 0 then
			return option.Id
		end
	end
	return nil
end

-- Daytime: an event now and then, only when the whole event fits before nightfall.
function EventService.StartScheduler()
	task.spawn(function()
		local nextEventAt = os.clock() + cfg.FirstDelay
		while true do
			task.wait(5)
			local state = DayNight.State(workspace:GetServerTimeNow())
			if os.clock() >= nextEventAt and not state.IsNight and not active and #Players:GetPlayers() > 0 then
				local eventId = pickDayEvent(state.SecondsLeft)
				if eventId then
					EventService.Start(eventId)
					nextEventAt = os.clock() + rng:NextNumber(cfg.IntervalMin, cfg.IntervalMax)
				end
			end
		end
	end)
end

return EventService
