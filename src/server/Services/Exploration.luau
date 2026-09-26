-- Exploration rewards: the first time a player enters a harder region, or finds one of the
-- island's secrets, they get a one-time cash bonus and the server hears about it. Milestones
-- ("Region_<Area>", "Secret_<id>") make each reward once-per-account.
-- The cinematic title card itself is client-side (Controllers/Biomes).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Regions = require(Shared.Config.Regions)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

local Exploration = {}

local function reward(player: Player, amount: number)
	if amount > 0 then
		PlayerData.AddCash(player, amount)
		local data = PlayerData.Get(player)
		if data then
			Analytics.Economy(player, "Source", amount, data.Cash, "Gameplay", "discovery")
		end
	end
end

local function checkRegion(player: Player, position: Vector3)
	local area = Zones.AreaId(position)
	local balance = GameConfig.Regions[area]
	if not balance or not PlayerData.Milestone(player, "Region_" .. area) then
		return
	end
	reward(player, balance.DiscoveryReward)
	Analytics.Event(player, "RegionDiscovered", { Area = area })
	Net.Fire("Feedback", player, { Type = "RegionDiscovered", Area = area, Reward = balance.DiscoveryReward })
	if balance.DiscoveryReward > 0 then
		Net.FireAll("Notify", {
			Kind = "Social",
			Text = ("%s REACHED %s"):format(player.DisplayName:upper(), Regions.Info[area].Title),
		})
	end
end

local function checkSecrets(player: Player, position: Vector3)
	for _, secret in Regions.Secrets do
		local offset = position - secret.Position
		if
			Vector2.new(offset.X, offset.Z).Magnitude <= secret.Radius
			and math.abs(offset.Y) <= 10
			and PlayerData.Milestone(player, "Secret_" .. secret.Id)
		then
			local amount = (GameConfig.Secrets[secret.Id] or {}).Reward or 0
			reward(player, amount)
			Analytics.Event(player, "SecretFound", { Id = secret.Id })
			Net.Fire("Feedback", player, { Type = "SecretFound", Id = secret.Id, Reward = amount })
			Net.FireAll("Notify", {
				Kind = "Social",
				Text = ("%s FOUND %s"):format(player.DisplayName:upper(), secret.Title),
			})
		end
	end
end

function Exploration.Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Exploration.CheckInterval)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root and PlayerData.IsLoaded(player) then
					local ok, err = pcall(function()
						checkRegion(player, root.Position)
						checkSecrets(player, root.Position)
					end)
					if not ok then
						warn("[Exploration]", err)
					end
				end
			end
		end
	end)
end

return Exploration
