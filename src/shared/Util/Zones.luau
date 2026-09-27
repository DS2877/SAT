-- Region queries shared by server (authority) and client (presentation only).

local Config = script.Parent.Parent.Config
local GameConfig = require(Config.GameConfig)
local WorldLayout = require(Config.WorldLayout)

local Zones = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude
end

function Zones.InSafeZone(position: Vector3): boolean
	return flatDistance(position, WorldLayout.District.Center) <= GameConfig.SafeZone.Radius
end

function Zones.FlatDistance(a: Vector3, b: Vector3): number
	return flatDistance(a, b)
end

-- Returns the extraction zone definition containing `position`, if any: a cylinder over the
-- shrine. Tall enough that standing on the dais, jumping on it or stepping on its obelisk
-- bases always counts, but not a floor above or a cave below it. (Measured against both the
-- ground the server found and the configured height, so a bad measurement can't disable it.)
function Zones.ExtractionZoneAt(position: Vector3)
	for _, zone in WorldLayout.ExtractionZones do
		local zonePos = zone.ResolvedPosition or zone.Position
		if flatDistance(position, zonePos) <= zone.Radius then
			for _, y in { zonePos.Y, zone.Position.Y } do
				local dy = position.Y - y
				if dy >= -8 and dy <= 18 then
					return zone
				end
			end
		end
	end
	return nil
end

-- Region id used by spawns and events:
-- "District" | "Ruins" | "Coast" | "Frost" | "Marsh" | "Falls" | "Wilds" | "Ember" | "Rime" | "Star".
local AREA_IDS = {
	["TREASURE DISTRICT"] = "District",
	["ANCIENT RUINS"] = "Ruins",
	["SHIPWRECK COAST"] = "Coast",
	["THE FALLS"] = "Falls",
	["FROSTPEAK"] = "Frost",
	["GLOWSHROOM MARSH"] = "Marsh",
	["THE WILDS"] = "Wilds",
	["EMBERFALL"] = "Ember",
	["RIMEHEART"] = "Rime",
	["STARFALL ISLES"] = "Star",
}

function Zones.AreaId(position: Vector3): string
	return AREA_IDS[Zones.AreaName(position)] or "Wilds"
end

function Zones.AreaName(position: Vector3): string
	if Zones.InSafeZone(position) then
		return "TREASURE DISTRICT"
	end
	local temple = WorldLayout.Temple.Center
	if flatDistance(position, temple) < 150 then
		return "ANCIENT RUINS"
	end
	if flatDistance(position, WorldLayout.Shipwreck.Center) < 160 then
		return "SHIPWRECK COAST"
	end
	if flatDistance(position, WorldLayout.Frostpeak.Center) < WorldLayout.Frostpeak.Radius then
		return "FROSTPEAK"
	end
	if flatDistance(position, WorldLayout.Marsh.Center) < WorldLayout.Marsh.Radius then
		return "GLOWSHROOM MARSH"
	end
	-- The Deep South runs in bands across the peninsula beyond the Sundering channel.
	local south = WorldLayout.DeepSouth
	if position.Z < south.StarStart then
		return "STARFALL ISLES"
	elseif position.Z < south.RimeStart then
		return "RIMEHEART"
	elseif position.Z < south.EmberStart then
		return "EMBERFALL"
	end
	if position.Z < -240 then
		return "THE FALLS"
	end
	return "THE WILDS"
end

return Zones
