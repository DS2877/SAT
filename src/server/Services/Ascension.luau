-- Ascension: at the required Strength and Cash, start over (Strength, ALL Cash and every gadget
-- are wiped - Logic/AscensionReset) for a permanent income + training multiplier and a title.
-- Keeps Collection, Vault + treasures, benches, cosmetics and stats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local AscensionReset = require(Shared.Logic.AscensionReset)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Analytics = require(script.Parent.Analytics)

local Ascension = {}

local cfg = GameConfig.Ascension

local function onAscend(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.Strength < GameConfig.GetAscensionRequirement(data.Ascension) then
		return
	end
	if TreasureService.GetCarrying(player) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Extract your treasure first", Tone = "Warn" })
		return
	end
	local newLevel = data.Ascension + 1
	local cost = GameConfig.GetAscensionCost(newLevel)
	if data.Cash < cost then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Not enough Cash to Ascend", Tone = "Warn" })
		return
	end
	local cashLost = data.Cash
	local title = cfg.Titles[math.min(newLevel, #cfg.Titles)]
	if newLevel > #cfg.Titles then
		title = ("%s %d"):format(cfg.Titles[#cfg.Titles], newLevel)
	end
	PlayerData.Update(player, function(d)
		AscensionReset.Apply(d, newLevel, title, GameConfig)
	end)
	if cfg.ResetsCash and cashLost > 0 then
		Analytics.Economy(player, "Sink", cashLost, 0, "Gameplay", "ascension_" .. newLevel)
	end
	local multiplier = GameConfig.GetAscensionMultiplier(newLevel)
	Net.Fire("Feedback", player, { Type = "Ascended", Level = newLevel, Multiplier = multiplier, Title = title })
	Net.FireAll("Notify", {
		Kind = "Social",
		Text = ("%s ASCENDED • %s"):format(player.DisplayName:upper(), title:upper()),
		Rarity = "Legendary",
	})
	if PlayerData.Milestone(player, "FirstAscension") then
		Analytics.Funnel(player, "FirstAscension")
	end
	Analytics.Event(player, "Ascended", { Level = newLevel })
end

function Ascension.Init(altarPrompt: ProximityPrompt)
	altarPrompt.Triggered:Connect(function(player)
		Net.Fire("OpenMenu", player, { Menu = "Ascension" })
	end)
	Net.On("Ascend", onAscend, 1)
end

return Ascension
