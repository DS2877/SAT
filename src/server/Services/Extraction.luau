-- Extraction: a carrier standing in an extraction zone for Duration seconds banks the treasure.
-- Starts automatically on entering the zone (mobile friendly). Hits interrupt, knocks drop.
-- Success: treasure -> EXTRACTED -> Cash -> Collection -> Vault.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)

local Extraction = {}

Extraction.Completed = Signal.new() -- (player, def, reward)

local cfg = GameConfig.Extraction

type Session = { Zone: any, Uid: number, StartedAt: number, ServerStartedAt: number }
local sessions: { [Player]: Session } = {}
-- After an interruption the player must step out (or wait) before auto-restart, so a hit
-- in the zone doesn't instantly restart progress under the attacker's nose.
local restartBlockedUntil: { [Player]: number } = {}

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
	restartBlockedUntil[player] = os.clock() + (if reason == "Left" then 0 else 1.0)
	send(player, { Active = false, Reason = reason })
	if reason ~= "Left" then
		Analytics.Event(player, "ExtractionInterrupted", { Reason = reason, Zone = session.Zone.Id })
	end
end

local function complete(player: Player, session: Session)
	sessions[player] = nil
	player:SetAttribute("Extracting", false)
	local def = TreasureService.Consume(player, session.Uid)
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
	local reward = math.floor(def.Value * category.Bonus * multiplier)
	local strengthGain = math.ceil(def.Weight * GameConfig.Strength.ExtractionGainPerWeight)
	local entry = data.Collection[def.Id]
	local isNew = entry == nil or not entry.Discovered
	local rank = Rarities.Rank(def.Rarity)

	-- Single synchronous mutation: no yields between consume and reward, so no duplicates.
	PlayerData.Update(player, function(d)
		d.Cash += reward
		d.Stats.TotalEarned += reward
		d.Stats.Extractions += 1
		d.Strength = math.min(GameConfig.Strength.Max, d.Strength + strengthGain)
		local e = d.Collection[def.Id]
		if not e then
			e = { Discovered = true, Count = 0 }
			d.Collection[def.Id] = e
		end
		e.Discovered = true
		e.Count += 1
		if rank > d.Stats.BestRarityRank then
			d.Stats.BestRarityRank = rank
			d.Stats.BestTreasureId = def.Id
		end
	end)

	send(player, { Active = false, Reason = "Complete" })
	Net.Fire("Feedback", player, {
		Type = "Extracted",
		TreasureId = def.Id,
		Reward = reward,
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
			Text = ("%s EXTRACTED THE %s"):format(player.DisplayName:upper(), def.Name:upper()),
			Rarity = def.Rarity,
		})
	end
	if PlayerData.Milestone(player, "FirstExtraction") then
		Analytics.Funnel(player, "FirstExtraction")
	end
	Analytics.Event(player, "Extracted", { Treasure = def.Id, Zone = session.Zone.Id, Reward = reward })
	Analytics.Economy(player, "Source", reward, data.Cash, "Gameplay", def.Id)
	TreasureService.RefreshCarrier(player)
	Extraction.Completed:Fire(player, def, reward)
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
		elseif record and root and now >= (restartBlockedUntil[player] or 0) and not Combat.IsKnocked(player) then
			local zone = Zones.ExtractionZoneAt(root.Position)
			if zone then
				local serverNow = workspace:GetServerTimeNow()
				sessions[player] = { Zone = zone, Uid = record.Uid, StartedAt = now, ServerStartedAt = serverNow }
				player:SetAttribute("Extracting", true)
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
