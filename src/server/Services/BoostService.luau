-- Speed BOOST RINGS (scattered at random by World/Adventure). Server-authoritative: the
-- server sees you on a pad and grants GameConfig.Boost.SpeedMultiplier for Duration seconds
-- through Movement (so it stacks correctly with carry weight, soda, bubbles...). Works for
-- carriers and chasers alike. Clients get a "Boosted" feedback for the whoosh / FOV / trail
-- and the "BoostUntil" attribute (server time) for the HUD.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local Movement = require(script.Parent.Movement)
local Combat = require(script.Parent.Combat)

local BoostService = {}

local cfg = GameConfig.Boost
local pads: { { Position: Vector3 } } = {}
local nextAllowed: { [Player]: number } = {}
local boostToken: { [Player]: number } = {}

local function boost(player: Player, pad)
	local now = os.clock()
	nextAllowed[player] = now + cfg.Cooldown
	local token = (boostToken[player] or 0) + 1
	boostToken[player] = token
	Movement.SetSpeed(player, "Boost", cfg.SpeedMultiplier)
	player:SetAttribute("BoostUntil", workspace:GetServerTimeNow() + cfg.Duration)
	Net.Fire("Feedback", player, { Type = "Boosted", Duration = cfg.Duration, Position = pad.Position })
	task.delay(cfg.Duration, function()
		if boostToken[player] == token then
			Movement.SetSpeed(player, "Boost", nil)
		end
	end)
end

local function tick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		if (nextAllowed[player] or 0) <= now then
			local root = Combat.RootOf(player)
			if root then
				local position = root.Position
				for _, pad in pads do
					local offset = position - pad.Position
					if offset.Y > -3 and offset.Y < 10 and Vector2.new(offset.X, offset.Z).Magnitude <= cfg.Radius then
						boost(player, pad)
						break
					end
				end
			end
		end
	end
end

function BoostService.Init(boostPads)
	pads = boostPads or {}
	Players.PlayerRemoving:Connect(function(player)
		nextAllowed[player] = nil
		boostToken[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Boost] tick error:", err)
			end
		end
	end)
end

return BoostService
