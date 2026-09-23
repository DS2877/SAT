-- Timing-bar training at physical stations. A ProximityPrompt starts a set; the client shows a
-- marker sweeping a bar (synchronised by server time) and sends taps. The server grades taps
-- against its own clock (client timestamp only accepted within a small tolerance).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local TrainingTiming = require(Shared.Logic.TrainingTiming)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)

local Training = {}

local cfg = GameConfig.Training

type Session = {
	StationId: string,
	Position: Vector3,
	StartedAt: number, -- server time (workspace:GetServerTimeNow)
	Reps: number,
	LastTap: number,
}
local sessions: { [Player]: Session } = {}
local lastSetEnded: { [Player]: number } = {}

local function stop(player: Player, reason: string)
	if sessions[player] then
		sessions[player] = nil
		lastSetEnded[player] = os.clock()
		Net.Fire("TrainingState", player, { Active = false, Reason = reason })
	end
end

local function start(player: Player, stationId: string, position: Vector3)
	local station = cfg.Stations[stationId]
	local data = PlayerData.Get(player)
	local root = Combat.RootOf(player)
	if not station or not data or not root then
		return
	end
	if sessions[player] then
		return
	end
	if TreasureService.GetCarrying(player) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Extract your treasure before training", Tone = "Warn" })
		return
	end
	if data.Strength < station.RequiredStrength then
		Net.Fire("Notify", player, {
			Kind = "Toast",
			Text = ("%s needs %d STRENGTH"):format(station.Name:upper(), station.RequiredStrength),
			Tone = "Warn",
		})
		return
	end
	if os.clock() - (lastSetEnded[player] or 0) < cfg.RestBetweenSets then
		return
	end
	if (root.Position - position).Magnitude > cfg.MaxStationDistance then
		return
	end
	local session = {
		StationId = stationId,
		Position = position,
		StartedAt = workspace:GetServerTimeNow(),
		Reps = 0,
		LastTap = 0,
	}
	sessions[player] = session
	Net.Fire("TrainingState", player, {
		Active = true,
		StationId = stationId,
		StartedAt = session.StartedAt,
		Period = cfg.Period,
		Reps = cfg.RepsPerSet,
		PerfectWindow = station.PerfectWindow,
		GoodWindow = station.GoodWindow,
	})
	if PlayerData.Milestone(player, "FirstTraining") then
		Analytics.Funnel(player, "FirstTraining")
	end
end

local function onTap(player: Player, clientTime: any)
	local session = sessions[player]
	if not session then
		return
	end
	local serverNow = workspace:GetServerTimeNow()
	if serverNow - session.LastTap < cfg.MinTapInterval then
		return
	end
	local root = Combat.RootOf(player)
	if not root or (root.Position - session.Position).Magnitude > cfg.MaxStationDistance then
		stop(player, "Left")
		return
	end
	-- Accept the client's timestamp only if it's plausible (compensates for latency).
	local tapTime = serverNow
	if type(clientTime) == "number" and clientTime == clientTime then
		tapTime = math.clamp(clientTime, serverNow - cfg.ClientTimestampTolerance, serverNow)
	end
	session.LastTap = serverNow
	session.Reps += 1

	local station = cfg.Stations[session.StationId]
	local position = TrainingTiming.MarkerPosition(tapTime - session.StartedAt, cfg.Period)
	local grade = TrainingTiming.Grade(position, station)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local gain = TrainingTiming.Gain(grade, data.Strength, station, cfg.OverCapGain)
	if gain > 0 then
		PlayerData.Update(player, function(d)
			d.Strength = math.min(GameConfig.Strength.Max, d.Strength + gain)
		end)
	end
	Net.Fire("Feedback", player, {
		Type = "TrainingRep",
		Grade = grade,
		Gain = gain,
		Rep = session.Reps,
		StationId = session.StationId,
	})
	if session.Reps >= cfg.RepsPerSet then
		stop(player, "SetComplete")
	end
end

function Training.Init(stations)
	-- stations: { { Id, Position, Prompt } } built by WorldBuilder
	for _, station in stations do
		station.Prompt.Triggered:Connect(function(player)
			start(player, station.Id, station.Position)
		end)
	end
	Net.On("TrainingTap", onTap, 6)
	Net.On("StopTraining", function(player)
		stop(player, "Stopped")
	end, 4)
	TreasureService.PickedUp:Connect(function(player)
		stop(player, "Carrying")
	end)
	Players.PlayerRemoving:Connect(function(player)
		sessions[player] = nil
		lastSetEnded[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			stop(player, "Respawned")
		end)
	end)
end

return Training
