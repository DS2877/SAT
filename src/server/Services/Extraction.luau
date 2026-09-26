-- Banking. The everyday way: carry it home - the moment a carrier is inside the Treasure
-- District (through the gate) it's banked, at the HOME finder's fee. The bonus way: stand in an
-- extraction zone out in the world for Duration seconds (starts automatically, mobile friendly;
-- hits interrupt, knocks drop) for a bigger fee and a chance of a mutation.
-- Success: treasure -> EXTRACTED -> finder's fee -> Collection -> a free Vault pedestal, where
-- it earns $/s. With a full Vault the treasure is sold on the spot (Economy.SellPrice).
-- Risky zones can bless an unmutated treasure with a mutation; every extraction in the same
-- day grows a run STREAK (finder's fee multiplier, reset at nightfall via ResetStreaks).
-- Epic+ extractions are announced server-wide and the extractor gets an "ExtractingRarity"
-- attribute so every client can mark them: a chase moment.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Economy = require(Shared.Logic.Economy)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)

local Extraction = {}

Extraction.Completed = Signal.new() -- (player, def, mutation, placedSlot: number?, soldFor: number)

local cfg = GameConfig.Extraction
-- Banking at home is a "zone" too, so both ways share one reward path.
local HOME = { Id = "home", Name = "Treasure District", Category = "Home" }

type Session = { Zone: any, Uid: number, StartedAt: number, ServerStartedAt: number }
local sessions: { [Player]: Session } = {}
-- After an interruption the player must step out (or wait) before auto-restart, so a hit
-- in the zone doesn't instantly restart progress under the attacker's nose.
local restartBlockedUntil: { [Player]: number } = {}
local streaks: { [Player]: number } = {}
local rng = Random.new()

local function setStreak(player: Player, value: number)
	streaks[player] = value
	player:SetAttribute("Streak", value)
end

-- Nightfall: everyone's run streak starts over.
function Extraction.ResetStreaks()
	for player in streaks do
		setStreak(player, 0)
	end
end

local function send(player: Player, payload)
	Net.Fire("ExtractionState", player, payload)
end

local function cancel(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	player:SetAttribute("Extracting", false)
	player:SetAttribute("ExtractingRarity", "")
	restartBlockedUntil[player] = os.clock() + (if reason == "Left" then 0 else 1.0)
	send(player, { Active = false, Reason = reason })
	if reason ~= "Left" then
		Analytics.Event(player, "ExtractionInterrupted", { Reason = reason, Zone = session.Zone.Id })
	end
end

local function complete(player: Player, session: Session)
	sessions[player] = nil
	player:SetAttribute("Extracting", false)
	player:SetAttribute("ExtractingRarity", "")
	local def, foundMutation = TreasureService.Consume(player, session.Uid)
	if not def then
		send(player, { Active = false, Reason = "Invalid" })
		return
	end

	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local category = cfg.Categories[session.Zone.Category] or cfg.Categories.Safe
	local multiplier = GameConfig.GetAscensionMultiplier(data.Ascension)
	local blessed = Economy.RollExtractionMutation(session.Zone.Category, foundMutation, function()
		return rng:NextNumber()
	end)
	local mutation = foundMutation or blessed
	local streak = (streaks[player] or 0) + 1
	setStreak(player, streak)
	local streakMultiplier = Economy.StreakMultiplier(streak)
	local reward = math.floor(Economy.FindersFee(def, mutation, category.Bonus, multiplier) * streakMultiplier + 0.5)
	local strengthGain = GameConfig.ExtractionStrength(def.Weight, data.Ascension or 0)
	local entry = data.Collection[def.Id]
	local isNew = entry == nil or not entry.Discovered
	local rank = Rarities.Rank(def.Rarity)
	local tier = GameConfig.Vault.Tiers[data.Vault.Tier] or GameConfig.Vault.Tiers[1]
	local setsBefore = Economy.CompletedSets(data.Collection, Treasures.List)
	local placedSlot: number? = nil
	local soldFor = 0

	-- Single synchronous mutation: no yields between consume and reward, so no duplicates.
	PlayerData.Update(player, function(d)
		for index = 1, tier.Slots do
			if d.Vault.Displays[tostring(index)] == nil then
				placedSlot = index
				d.Vault.Displays[tostring(index)] = Economy.EncodeSlot(def.Id, mutation)
				break
			end
		end
		if not placedSlot then
			soldFor = Economy.SellPrice(def, mutation)
		end
		local cash = reward + soldFor
		d.Cash += cash
		d.Stats.TotalEarned += cash
		d.Stats.Extractions += 1
		d.Strength = math.min(GameConfig.Strength.Max, d.Strength + strengthGain)
		local e = d.Collection[def.Id]
		if not e then
			e = { Discovered = true, Count = 0 }
			d.Collection[def.Id] = e
		end
		e.Discovered = true
		e.Count += 1
		if mutation then
			e.Mutations = e.Mutations or {}
			e.Mutations[mutation] = true
		end
		if rank > d.Stats.BestRarityRank then
			d.Stats.BestRarityRank = rank
			d.Stats.BestTreasureId = def.Id
		end
	end)

	send(player, { Active = false, Reason = "Complete" })
	if Economy.CompletedSets(data.Collection, Treasures.List) > setsBefore then
		task.delay(3, function()
			Net.Fire("Notify", player, {
				Kind = "Banner",
				Title = ("🏆 %s SET COMPLETE!"):format(def.SpawnArea:upper()),
				Text = ("+%d%% Vault income forever"):format(math.floor(GameConfig.Collection.SetBonusPerSet * 100 + 0.5)),
				Tone = "Reward",
			})
		end)
		Analytics.Event(player, "CollectionSetComplete", { Area = def.SpawnArea })
	end
	local first = PlayerData.Milestone(player, "FirstExtraction")
	Net.Fire("Feedback", player, {
		Type = "Extracted",
		First = first, -- the very first bank: the client makes a big moment of it
		TreasureId = def.Id,
		Mutation = mutation,
		Reward = reward,
		Income = Economy.Income(def, mutation),
		BlessedMutation = blessed,
		Streak = streak,
		StreakMultiplier = streakMultiplier,
		PlacedSlot = placedSlot,
		SoldFor = soldFor,
		Bonus = category.Bonus,
		Multiplier = multiplier,
		ZoneName = session.Zone.Name,
		Category = session.Zone.Category,
		NewDiscovery = isNew,
		StrengthGain = strengthGain,
	})
	if Rarities.AtLeast(def.Rarity, GameConfig.Treasure.BroadcastMinRarity) then
		Net.FireAll("Notify", {
			Kind = "Social",
			Text = ("%s EXTRACTED THE %s%s"):format(
				player.DisplayName:upper(),
				if mutation then mutation:upper() .. " " else "",
				def.Name:upper()
			),
			Rarity = def.Rarity,
		})
	end
	if first then
		Analytics.Funnel(player, "FirstExtraction")
	end
	Analytics.Event(player, "Extracted", { Treasure = def.Id, Zone = session.Zone.Id, Reward = reward })
	Analytics.Economy(player, "Source", reward + soldFor, data.Cash, "Gameplay", def.Id)
	TreasureService.RefreshCarrier(player)
	Extraction.Completed:Fire(player, def, mutation, placedSlot, soldFor)
end

local function tick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local session = sessions[player]
		local record = TreasureService.GetCarrying(player)
		local root = Combat.RootOf(player)
		if session then
			if not record or record.Uid ~= session.Uid or not root then
				cancel(player, "Dropped")
			elseif Combat.IsKnocked(player) then
				cancel(player, "Knocked")
			elseif Zones.ExtractionZoneAt(root.Position) ~= session.Zone then
				cancel(player, "Left")
			elseif now - session.StartedAt >= cfg.Duration then
				complete(player, session)
			end
		elseif record and root and Zones.InSafeZone(root.Position) and not Combat.IsKnocked(player) then
			-- Made it home: banked on the spot.
			complete(player, { Zone = HOME, Uid = record.Uid, StartedAt = now, ServerStartedAt = workspace:GetServerTimeNow() })
		elseif record and root and now >= (restartBlockedUntil[player] or 0) and not Combat.IsKnocked(player) then
			local zone = Zones.ExtractionZoneAt(root.Position)
			if zone then
				local serverNow = workspace:GetServerTimeNow()
				sessions[player] = { Zone = zone, Uid = record.Uid, StartedAt = now, ServerStartedAt = serverNow }
				player:SetAttribute("Extracting", true)
				if Rarities.AtLeast(record.Def.Rarity, cfg.AnnounceMinRarity) then
					-- Chase moment: everyone learns where a big prize is being banked.
					player:SetAttribute("ExtractingRarity", record.Def.Rarity)
					Net.FireAll("Notify", {
						Kind = "Social",
						Text = ("⚠ %s IS EXTRACTING A %s AT %s!"):format(
							player.DisplayName:upper(),
							record.Def.Rarity:upper(),
							zone.Name:upper()
						),
						Rarity = record.Def.Rarity,
					})
				end
				send(player, {
					Active = true,
					ZoneName = zone.Name,
					Category = zone.Category,
					StartedAt = serverNow,
					Duration = cfg.Duration,
				})
			end
		end
	end
end

function Extraction.IsExtracting(player: Player): boolean
	return sessions[player] ~= nil
end

function Extraction.Init()
	Combat.PlayerHit:Connect(function(victim, result)
		if sessions[victim] and (cfg.HitInterrupts or result == "Knocked") then
			cancel(victim, if result == "Knocked" then "Knocked" else "Hit")
		end
	end)
	TreasureService.Dropped:Connect(function(player)
		if sessions[player] then
			cancel(player, "Dropped")
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		restartBlockedUntil[player] = nil
		streaks[player] = nil
	end)
end

function Extraction.Start()
	task.spawn(function()
		while true do
			task.wait(cfg.TickRate)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Extraction] tick error:", err)
			end
		end
	end)
end

return Extraction
