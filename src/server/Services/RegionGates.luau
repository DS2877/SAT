-- The Deep South is unlocked by Ascension (GameConfig.Regions[area].RequiredAscension):
-- Emberfall at 1, Rimeheart at 2, the Starfall Isles at 3. Ascension never goes down, so
-- a region stays open once unlocked.
--   * Authority: 5x a second, anyone in a region they haven't unlocked - however they got
--     there (the path, swimming round the coast, climbing) - is sent to the start of the way
--     in (WorldLayout.DeepSouth.Returns). A treasure they carry drops where they crossed, on
--     the side they're allowed on (the last solid ground they stood on there).
--   * The Rune Gates (World/DeepSouth, tag "RuneGate") glow green/red per player on the client.
--   * Unlocking one (by Ascending) is a big moment: banner for you, shout-out for the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Config.WorldLayout)
local Regions = require(Shared.Config.Regions)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local VaultService = require(script.Parent.VaultService)
local Combat = require(script.Parent.Combat)
local TreasureService = require(script.Parent.TreasureService)

local RegionGates = {}

local lastAllowed: { [Player]: Vector3 } = {}
local lastGround: { [Player]: Vector3 } = {} -- last solid (not water) ground in an allowed region
local lastWarned: { [Player]: number } = {}
local knownLevel: { [Player]: number } = {}

-- Ascension a region needs (0 = open to everyone).
function RegionGates.Required(area: string): number
	local balance = GameConfig.Regions[area]
	return if balance then balance.RequiredAscension or 0 else 0
end

function RegionGates.Allowed(player: Player, area: string): boolean
	local data = PlayerData.Get(player)
	return data ~= nil and (data.Ascension or 0) >= RegionGates.Required(area)
end

-- The way in to the first region this player hasn't unlocked (Asc 0 anywhere in the south:
-- the Ashen Pass; Asc 1 on the glacier: the foot of the climb; ...).
local function returnPoint(level: number): Vector3?
	local best, bestNeed = nil, math.huge
	for area, point in WorldLayout.DeepSouth.Returns do
		local need = RegionGates.Required(area)
		if need > level and need < bestNeed then
			best, bestNeed = point, need
		end
	end
	return best
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.IgnoreWater = true

local function turnBack(player: Player, root: BasePart, area: string)
	local data = PlayerData.Get(player)
	local level = data and data.Ascension or 0
	-- Treasure drops where they crossed, on their side: the last solid ground they stood on
	-- there, if it's close by; otherwise the last allowed spot (even in the water).
	local back = lastAllowed[player]
	local ground = lastGround[player]
	local dropped = TreasureService.GetCarrying(player) ~= nil
	if dropped then
		local at = if ground and back and (ground - back).Magnitude < 60 then ground else back
		TreasureService.Drop(player, "Sealed", nil, at)
	end
	local point = returnPoint(level)
	local character = player.Character
	if point and character then
		groundParams.FilterDescendantsInstances = { character }
		local hit = workspace:Raycast(point + Vector3.new(0, 40, 0), Vector3.new(0, -80, 0), groundParams)
		local target = (if hit then hit.Position else point) + Vector3.new(0, 4, 0)
		character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
		root.AssemblyLinearVelocity = Vector3.zero
		lastAllowed[player] = target
		lastGround[player] = target
	else
		VaultService.SendHome(player)
	end
	local now = os.clock()
	if dropped or now - (lastWarned[player] or 0) > 2.5 then
		lastWarned[player] = now
		Net.Fire("Notify", player, {
			Kind = "Banner",
			Title = ("🔒 %s IS SEALED"):format(Regions.Info[area].Title),
			Text = ("Unlocks at ASCENSION %d • you are Ascension %d"):format(RegionGates.Required(area), level)
				.. (if dropped then " • your treasure dropped at the border" else ""),
			Tone = "Warn",
			Duration = 3,
		})
		Net.Fire("Feedback", player, { Type = "RegionLocked", Area = area })
	end
end

local function celebrate(player: Player, oldLevel: number, newLevel: number)
	for _, area in Regions.Order do
		local need = RegionGates.Required(area)
		if need > oldLevel and need <= newLevel then
			local title = Regions.Info[area].Title
			Net.Fire("Notify", player, { Kind = "Banner", Title = ("🔓 %s UNLOCKED!"):format(title), Text = Regions.Info[area].Tagline, Tone = "Reward", Duration = 6 })
			Net.Fire("Feedback", player, { Type = "RegionUnlocked", Area = area })
			Net.FireAll("Notify", { Kind = "Social", Text = ("%s UNLOCKED %s"):format(player.DisplayName:upper(), title), Rarity = "Legendary" })
		end
	end
end

local function tick()
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		local root = Combat.RootOf(player)
		if data and root then
			local level = data.Ascension or 0
			local previous = knownLevel[player]
			if previous and level > previous then
				celebrate(player, previous, level)
			end
			knownLevel[player] = level
			player:SetAttribute("Ascension", level) -- read by the Rune Gates and geysers
			local area = Zones.AreaId(root.Position)
			if level >= RegionGates.Required(area) then
				lastAllowed[player] = root.Position
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				local floor = humanoid and humanoid.FloorMaterial
				if floor and floor ~= Enum.Material.Air and floor ~= Enum.Material.Water then
					lastGround[player] = root.Position
				end
			else
				turnBack(player, root, area)
			end
		end
	end
end

function RegionGates.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastAllowed[player] = nil
		lastGround[player] = nil
		lastWarned[player] = nil
		knownLevel[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(tick)
			if not ok then
				warn("[RegionGates] tick error:", err)
			end
		end
	end)
end

return RegionGates
