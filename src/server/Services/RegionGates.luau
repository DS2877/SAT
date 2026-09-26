-- The Deep South is unlocked by Ascension (GameConfig.Regions[area].RequiredAscension):
-- Emberfall at 1, Rimeheart at 2, the Starfall Isles at 3. Ascension never goes down, so
-- a region stays open once unlocked.
--   * Authority: 5x a second, anyone standing in a region they haven't unlocked is put back
--     where they last were allowed (a little further back, so they don't bounce on the line).
--   * The Rune Gates (World/DeepSouth, tag "RuneGate") glow green/red per player on the client.
--   * Unlocking one (by Ascending) is a big moment: banner for you, shout-out for the server.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Regions = require(Shared.Config.Regions)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local VaultService = require(script.Parent.VaultService)
local Combat = require(script.Parent.Combat)

local RegionGates = {}

local lastAllowed: { [Player]: Vector3 } = {}
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

local function turnBack(player: Player, root: BasePart, area: string)
	local back = lastAllowed[player]
	if back then
		local away = back - root.Position
		away = Vector3.new(away.X, 0, away.Z)
		local target = back + (if away.Magnitude > 0.1 then away.Unit * 6 else Vector3.zero) + Vector3.new(0, 2, 0)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(target) * root.CFrame.Rotation)
		end
		root.AssemblyLinearVelocity = Vector3.zero
	else
		VaultService.SendHome(player)
	end
	local now = os.clock()
	if now - (lastWarned[player] or 0) > 2.5 then
		lastWarned[player] = now
		local data = PlayerData.Get(player)
		Net.Fire("Notify", player, {
			Kind = "Banner",
			Title = ("🔒 %s IS SEALED"):format(Regions.Info[area].Title),
			Text = ("Unlocks at ASCENSION %d • you are Ascension %d"):format(RegionGates.Required(area), data and data.Ascension or 0),
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
			else
				turnBack(player, root, area)
			end
		end
	end
end

function RegionGates.Init()
	Players.PlayerRemoving:Connect(function(player)
		lastAllowed[player] = nil
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
