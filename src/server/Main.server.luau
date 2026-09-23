-- Server bootstrap. Order matters: world first, then data, then gameplay services.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local Services = script.Parent.Services
local WorldBuilder = require(script.Parent.WorldBuilder)
local PlayerData = require(Services.PlayerData)
local Movement = require(Services.Movement)
local TreasureService = require(Services.TreasureService)
local Combat = require(Services.Combat)
local Extraction = require(Services.Extraction)
local Training = require(Services.Training)
local GadgetService = require(Services.GadgetService)
local GuardianService = require(Services.GuardianService)
local VaultService = require(Services.VaultService)
local Ascension = require(Services.Ascension)
local LeaderboardService = require(Services.LeaderboardService)
local EventService = require(Services.EventService)
local DayCycle = require(Services.DayCycle)
local Analytics = require(Services.Analytics)

Net.Init()
Players.RespawnTime = GameConfig.Player.RespawnTime

local world = WorldBuilder.Build()

PlayerData.Init()
Movement.Init()
TreasureService.Init(world.TreasureSpawns)
Combat.Init()
Extraction.Init()
Training.Init(world.Benches)
GadgetService.Init()
GuardianService.Init(world.GuardianSpawns)
VaultService.Init(world.VaultPlots)
Ascension.Init(world.AltarPrompt)
LeaderboardService.Init(world.Leaderboards)
EventService.Init()

-- Funnel step 1: every first-time player (lets the dashboard show where newcomers drop off).
PlayerData.Loaded:Connect(function(player)
	if PlayerData.Milestone(player, "Joined") then
		Analytics.Funnel(player, "Joined")
	end
end)

world.ShopPrompt.Triggered:Connect(function(player)
	Net.Fire("OpenMenu", player, { Menu = "Shop" })
end)

-- Player preferences. Only known boolean settings are accepted.
local BOOLEAN_SETTINGS = { Music = true }
Net.On("SetSetting", function(player, name, value)
	if type(name) ~= "string" or not BOOLEAN_SETTINGS[name] or type(value) ~= "boolean" then
		return
	end
	PlayerData.Update(player, function(d)
		d.Settings[name] = value
	end)
end, 4)

Net.On("TutorialProgress", function(player, step)
	if type(step) ~= "number" or step ~= math.floor(step) or step < 0 or step > 20 then
		return
	end
	local data = PlayerData.Get(player)
	if data and step > data.TutorialStep then
		PlayerData.Update(player, function(d)
			d.TutorialStep = step
		end)
	end
end, 2)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid") :: Humanoid
		humanoid.MaxHealth = GameConfig.Player.MaxHealth
		humanoid.Health = GameConfig.Player.MaxHealth
		humanoid.Died:Connect(function()
			PlayerData.Update(player, function(d)
				d.Stats.Deaths += 1
			end)
			if PlayerData.Milestone(player, "FirstDeath") then
				Analytics.Event(player, "FirstDeath")
			end
		end)
	end)
end)

-- Connected last so every other PlayerRemoving handler (drop treasure, cancel extraction)
-- has resolved state before the final save.
Players.PlayerRemoving:Connect(function(player)
	PlayerData.Release(player)
end)

PlayerData.Start()
TreasureService.Start()
Extraction.Start()
GuardianService.Start()
LeaderboardService.Start()
EventService.StartScheduler()
DayCycle.Start()

print("[StealTheTreasure] server ready")
