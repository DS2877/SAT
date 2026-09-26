-- Deep South hazards (server-authoritative, 10x a second):
--   * LAVA (parts tagged "Lava", World/DeepSouth): touch it and you're flung out and DROP
--     what you carry, right there, on the lava - someone brave can still grab it.
--   * FALLS (invisible parts tagged "FallZone" with a Respawn attribute): Rimeheart's
--     crevasses. Fall in and you're pulled back out at the edge; your loot drops there.
--   * THE SEA under the Starfall Isles: fall off an island and you wash up on the glacier tip,
--     dropping your loot on the shore.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Config.WorldLayout)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)

local HazardService = {}

local cfg = GameConfig.Hazards
local cooldown: { [Player]: number } = {}

local function inside(part: BasePart, position: Vector3, margin: number): boolean
	local rel = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X + margin and math.abs(rel.Z) <= half.Z + margin and rel.Y <= half.Y + cfg.LavaReach and rel.Y >= -half.Y - 2
end

local function relocate(player: Player, to: Vector3)
	local character = player.Character
	local root = Combat.RootOf(player)
	if character and root then
		character:PivotTo(CFrame.new(to + Vector3.new(0, 3, 0)) * root.CFrame.Rotation)
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

local function burn(player: Player, lava: BasePart, root: BasePart)
	local away = root.Position - lava.Position
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.1 then away.Unit else Vector3.new(0, 0, 1)
	local carried = TreasureService.GetCarrying(player)
	TreasureService.Drop(player, "Lava")
	Net.Fire("Feedback", player, { Type = "Knockback", Direction = away, Power = cfg.LavaKnockback })
	Net.Fire("Feedback", player, { Type = "Hazard", Kind = "Lava" })
	Net.Fire("Notify", player, {
		Kind = "Toast",
		Text = if carried then "🔥 THE FLOOR IS LAVA! You dropped your treasure" else "🔥 THE FLOOR IS LAVA!",
		Tone = "Danger",
	})
end

local function fall(player: Player, to: Vector3, message: string)
	relocate(player, to)
	local carried = TreasureService.GetCarrying(player)
	TreasureService.Drop(player, "Fall")
	Net.Fire("Feedback", player, { Type = "Hazard", Kind = "Fall" })
	Net.Fire("Notify", player, { Kind = "Toast", Text = if carried then message .. " • your treasure dropped" else message, Tone = "Warn" })
end

local function tick()
	local now = os.clock()
	local lava = CollectionService:GetTagged("Lava")
	local falls = CollectionService:GetTagged("FallZone")
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and now >= (cooldown[player] or 0) then
			local position = root.Position
			if position.Z < WorldLayout.DeepSouth.EmberStart + 20 then
				local hit = false
				for _, part in lava do
					if part:IsA("BasePart") and inside(part, position, 0.5) then
						burn(player, part, root)
						cooldown[player] = now + cfg.Cooldown
						hit = true
						break
					end
				end
				if not hit then
					for _, part in falls do
						local respawn = part:GetAttribute("Respawn")
						if part:IsA("BasePart") and typeof(respawn) == "Vector3" and inside(part, position, 0) then
							fall(player, respawn, "❄ You fell into a crevasse!")
							cooldown[player] = now + cfg.Cooldown
							hit = true
							break
						end
					end
				end
				if not hit and Zones.AreaId(position) == "Star" and position.Y < cfg.SeaFallHeight then
					fall(player, WorldLayout.DeepSouth.StarShore, "🌊 You fell from the isles!")
					cooldown[player] = now + cfg.Cooldown
				end
			end
		end
	end
end

function HazardService.Init()
	Players.PlayerRemoving:Connect(function(player)
		cooldown[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(tick)
			if not ok then
				warn("[Hazards] tick error:", err)
			end
		end
	end)
end

return HazardService
