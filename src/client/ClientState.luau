-- Client-side mirror of authoritative state. UI reads from here; it never invents state.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Treasures = require(Shared.Config.Treasures)
local Signal = require(Shared.Util.Signal)
local Net = require(Shared.Net)

local ClientState = {}

ClientState.Data = nil :: any
ClientState.DataChanged = Signal.new() -- (data, previous)
ClientState.AttributeChanged = Signal.new() -- (name, value)
ClientState.Cooldowns = {} :: { [string]: number } -- gadgetId -> server time ready

local player = Players.LocalPlayer

local WATCHED = { "CarryingId", "CarryingUid", "CarrySpeed", "Stability", "Extracting", "MoveLocked", "Strength" }

function ClientState.Carrying()
	local id = player:GetAttribute("CarryingId")
	if type(id) == "string" and id ~= "" then
		return Treasures.Get(id)
	end
	return nil
end

function ClientState.Stability(): string
	return player:GetAttribute("Stability") or "Stable"
end

function ClientState.Milestone(name: string): boolean
	local data = ClientState.Data
	return data ~= nil and data.Milestones[name] ~= nil
end

function ClientState.Init()
	Net.Get("DataSync").OnClientEvent:Connect(function(data)
		local previous = ClientState.Data
		ClientState.Data = data
		ClientState.DataChanged:Fire(data, previous)
	end)
	Net.Get("GadgetState").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Cooldowns) == "table" then
			ClientState.Cooldowns = payload.Cooldowns
			ClientState.AttributeChanged:Fire("Cooldowns", payload.Cooldowns)
		end
	end)
	for _, name in WATCHED do
		player:GetAttributeChangedSignal(name):Connect(function()
			ClientState.AttributeChanged:Fire(name, player:GetAttribute(name))
		end)
	end
end

return ClientState
