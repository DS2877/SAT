-- Single owner of Humanoid.WalkSpeed / JumpPower. Services contribute named
-- multipliers ("Carry", "SpeedSoda") and locks ("Knocked", "Bubble"); this module
-- combines them. Nothing else should write WalkSpeed directly.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Movement = {}

type Entry = { Speed: { [string]: number? }, Jump: { [string]: number? }, Locks: { [string]: boolean? } }
local entries: { [Player]: Entry } = {}

local function entryFor(player: Player): Entry
	local entry = entries[player]
	if not entry then
		entry = { Speed = {}, Jump = {}, Locks = {} }
		entries[player] = entry
	end
	return entry
end

function Movement.Refresh(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local entry = entryFor(player)
	local speed = GameConfig.Player.BaseWalkSpeed
	local jump = GameConfig.Player.BaseJumpPower
	for _, mult in entry.Speed do
		speed *= mult :: number
	end
	for _, mult in entry.Jump do
		jump *= mult :: number
	end
	if next(entry.Locks) ~= nil then
		speed = 0
		jump = 0
	end
	humanoid.UseJumpPower = true
	humanoid.WalkSpeed = speed
	humanoid.JumpPower = jump
	player:SetAttribute("MoveLocked", next(entry.Locks) ~= nil)
end

function Movement.SetSpeed(player: Player, key: string, multiplier: number?)
	entryFor(player).Speed[key] = multiplier
	Movement.Refresh(player)
end

function Movement.SetJump(player: Player, key: string, multiplier: number?)
	entryFor(player).Jump[key] = multiplier
	Movement.Refresh(player)
end

function Movement.SetLock(player: Player, key: string, locked: boolean)
	entryFor(player).Locks[key] = if locked then true else nil
	Movement.Refresh(player)
end

function Movement.IsLocked(player: Player, key: string?): boolean
	local entry = entries[player]
	if not entry then
		return false
	end
	if key then
		return entry.Locks[key] == true
	end
	return next(entry.Locks) ~= nil
end

-- Clears temporary effects on respawn (carry state is re-applied by its owner if relevant).
function Movement.ResetTemporary(player: Player)
	local entry = entryFor(player)
	entry.Locks = {}
	entry.Speed.SpeedSoda = nil
	entry.Speed.Bees = nil
	Movement.Refresh(player)
end

function Movement.Init()
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			task.defer(Movement.ResetTemporary, player)
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		entries[player] = nil
	end)
end

return Movement
