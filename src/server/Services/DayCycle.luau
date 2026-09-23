-- Nightfall rules (the clock itself is Logic/DayNight, derived from server time):
--   * every treasure still out in the world is lost - including anything being carried;
--     only extracted loot is safe
--   * everyone outside the Treasure District is sent home to their Vault (players already in
--     the District - lifting, shopping, at their Vault - are left alone)
--   * everyone's extraction run streak resets
--   * the night's loot wave starts (TreasureService spawns only at night) and a night event
--     may be rolled for one region (EventService.OnNightfall)
--   * the gate into the Wilds is sealed by night fog until dawn; anyone still outside the
--     District (grapple tricks, late respawns) is sent home
-- At DAWN: "A NEW DAY BEGINS" for everyone, the gate opens, and every super-rare treasure the
-- night wave dropped is announced with its region (a race to it).
-- The countdown warnings, fog visuals and lighting are client-side from the same clock.

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

local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)

local DayCycle = {}

local nightGate: BasePart? = nil

local AREA_NAMES = { Wilds = "THE WILDS", Ruins = "THE ANCIENT RUINS", Coast = "SHIPWRECK COAST", Falls = "THE FALLS" }

local function setGateSealed(sealed: boolean)
	if nightGate then
		nightGate.CanCollide = sealed
	end
	workspace:SetAttribute("WildsClosed", sealed)
end

local function sendOutsidersHome(explain: boolean)
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and not Zones.InSafeZone(root.Position) then
			VaultService.SendHome(player)
			if explain then
				Net.Fire("Notify", player, { Kind = "Toast", Text = "🌙 The Wilds are closed until dawn", Tone = "Info" })
			end
		end
	end
end

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
	sendOutsidersHome(false)
	setGateSealed(true)
	Extraction.ResetStreaks()
	EventService.OnNightfall()
end

-- Dawn: the island reopens with a fresh wave. Super-rare spawns are announced one by one.
local function dawn()
	setGateSealed(false)
	Net.FireAll("Notify", {
		Kind = "Banner",
		Title = "☀ A NEW DAY BEGINS",
		Text = "All treasures reset • The Wilds are open!",
		Tone = "Reward",
	})
	local cfg = GameConfig.DayNight
	local announced = 0
	for _, record in TreasureService.All() do
		local special = record.Mutation == "Rainbow" or record.Mutation == "Diamond"
		if record.State == "World" and (Rarities.AtLeast(record.Def.Rarity, cfg.AnnounceMinRarity) or special) then
			announced += 1
			if announced > cfg.AnnounceMax then
				break
			end
			local area = record.SpawnPoint and AREA_NAMES[record.SpawnPoint.Area] or "THE ISLAND"
			local what = if record.Mutation then record.Mutation:upper() .. " " .. record.Def.Rarity:upper() else record.Def.Rarity:upper()
			task.delay(announced * 3.2, function()
				Net.FireAll("Notify", {
					Kind = "Banner",
					Title = ("%s %s TREASURE SPAWNED"):format(Rarities.Info[record.Def.Rarity].Glyph, what),
					Text = ("%s • %s"):format(record.Def.Name:upper(), area),
					Tone = "Reward",
				})
			end)
		end
	end
end

function DayCycle.Init(gate: BasePart?)
	nightGate = gate
end

function DayCycle.Start()
	task.spawn(function()
		local wasNight = DayNight.IsNight(workspace:GetServerTimeNow())
		setGateSealed(wasNight) -- a server can start in the middle of the night
		while true do
			task.wait(0.25)
			local isNight = DayNight.IsNight(workspace:GetServerTimeNow())
			if isNight ~= wasNight then
				local ok, err = pcall(if isNight then nightfall else dawn)
				if not ok then
					warn("[DayCycle] transition error:", err)
				end
			elseif isNight then
				-- Nobody stays out at night (the gate is sealed; this catches edge cases).
				sendOutsidersHome(true)
			end
			wasNight = isNight
		end
	end)
end

return DayCycle
