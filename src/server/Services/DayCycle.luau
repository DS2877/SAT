-- Nightfall rules (the clock itself is Logic/DayNight, derived from server time):
--   * every treasure still out in the world is lost - including anything being carried;
--     only extracted loot is safe
--   * everyone outside the Treasure District is sent home to their Vault (players already in
--     the District - lifting, shopping, at their Vault - are left alone)
--   * everyone's extraction run streak resets
--   * the night's loot wave starts (TreasureService spawns only at night) and a night event
--     may be rolled for one region (EventService.OnNightfall)
-- The countdown warnings and lighting are client-side (Ambience) from the same clock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local DayNight = require(Shared.Logic.DayNight)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local TreasureService = require(script.Parent.TreasureService)
local VaultService = require(script.Parent.VaultService)
local EventService = require(script.Parent.EventService)
local Extraction = require(script.Parent.Extraction)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)

local DayCycle = {}

local function nightfall()
	local losers = TreasureService.ClearAll("Nightfall")
	for _, player in losers do
		Net.Fire("Notify", player, {
			Kind = "Banner",
			Title = "🌙 LOOT LOST",
			Text = "Night fell before you extracted it",
			Tone = "Danger",
		})
		Analytics.Event(player, "LootLostAtNightfall", {})
	end
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and not Zones.InSafeZone(root.Position) then
			VaultService.SendHome(player)
		end
	end
	Extraction.ResetStreaks()
	EventService.OnNightfall()
end

function DayCycle.Start()
	task.spawn(function()
		local wasNight = DayNight.IsNight(workspace:GetServerTimeNow())
		while true do
			task.wait(0.25)
			local isNight = DayNight.IsNight(workspace:GetServerTimeNow())
			if isNight and not wasNight then
				local ok, err = pcall(nightfall)
				if not ok then
					warn("[DayCycle] nightfall error:", err)
				end
			end
			wasNight = isNight
		end
	end)
end

return DayCycle
