-- Day/night clock shared by server (gameplay) and client (lighting + HUD). Pure: pass the
-- server time (workspace:GetServerTimeNow()), so every server and client agree on the phase
-- without any replication. Inspired by Steal an Egg: long days, short nights that pay out.

local DayNight = {}

-- Roblox requires the config via `script`; the Lune test runner injects it with DayNight.Use.
local GameConfig
if script then
	GameConfig = require(script.Parent.Parent.Config.GameConfig)
end

function DayNight.Use(gameConfig)
	GameConfig = gameConfig
end

export type State = {
	IsNight: boolean,
	SecondsLeft: number, -- until the phase changes
	Progress: number, -- 0..1 through the current phase
	ClockTime: number, -- Lighting.ClockTime to show
}

function DayNight.State(serverTime: number): State
	local cfg = GameConfig.DayNight
	local dayLength = cfg.CycleSeconds - cfg.NightSeconds
	local t = serverTime % cfg.CycleSeconds
	if t < dayLength then
		local progress = t / dayLength
		return {
			IsNight = false,
			SecondsLeft = dayLength - t,
			Progress = progress,
			ClockTime = cfg.DayStartClock + (cfg.DayEndClock - cfg.DayStartClock) * progress,
		}
	end
	local progress = (t - dayLength) / cfg.NightSeconds
	local nightHours = 24 - cfg.DayEndClock + cfg.DayStartClock
	return {
		IsNight = true,
		SecondsLeft = cfg.CycleSeconds - t,
		Progress = progress,
		ClockTime = (cfg.DayEndClock + nightHours * progress) % 24,
	}
end

function DayNight.IsNight(serverTime: number): boolean
	return DayNight.State(serverTime).IsNight
end

return DayNight
