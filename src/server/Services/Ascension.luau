-- Ascension: at the required Strength, reset Strength for a permanent Cash multiplier + title.
-- Keeps Collection, Vault, Cash, cosmetics and stats.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Analytics = require(script.Parent.Analytics)

local Ascension = {}

local cfg = GameConfig.Ascension

local function onAscend(player: Player)
	local data = PlayerData.Get(player)
	if not data or data.Strength < cfg.RequiredStrength then
		return
	end
	if TreasureService.GetCarrying(player) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Extract your treasure first", Tone = "Warn" })
		return
	end
	local newLevel = data.Ascension + 1
	local title = cfg.Titles[math.min(newLevel, #cfg.Titles)]
	if newLevel > #cfg.Titles then
		title = ("%s %d"):format(cfg.Titles[#cfg.Titles], newLevel)
	end
	PlayerData.Update(player, function(d)
		d.Strength = GameConfig.Strength.Start
		d.Ascension = newLevel
		if not table.find(d.Titles, title) then
			table.insert(d.Titles, title)
		end
		d.SelectedTitle = title
	end)
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
