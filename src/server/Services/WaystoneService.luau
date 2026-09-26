-- Waystones (World/Waystones, tag "Waystone"): fast travel between the District and the Deep
-- South, so the long walk is a first-time adventure rather than a daily chore.
--   * District -> region: needs the region's Ascension AND to have reached it on foot once
--     (Exploration's "Region_<Area>" milestone attunes the stone).
--   * Region -> District: a free ride home.
--   * Never while carrying treasure (bank it at an exit - that's the game) and never at night
--     (the Wilds are sealed; DayCycle sends everyone home anyway).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Regions = require(Shared.Config.Regions)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local RegionGates = require(script.Parent.RegionGates)
local Combat = require(script.Parent.Combat)

local WaystoneService = {}

local COOLDOWN = 2
local lastTravel: { [Player]: number } = {}

local function deny(player: Player, title: string, text: string)
	Net.Fire("Notify", player, { Kind = "Banner", Title = title, Text = text, Tone = "Warn", Duration = 3 })
	Net.Fire("Feedback", player, { Type = "RegionLocked" })
end

-- Why `player` can't use a stone to `area` right now, or nil if they can.
function WaystoneService.Refusal(player: Player, area: string): (string?, string?)
	if TreasureService.GetCarrying(player) then
		return "✋ HANDS FULL", "Waystones won't carry treasure - bank it at an exit ⌂"
	end
	if workspace:GetAttribute("WildsClosed") then
		return "🌙 THE STONES SLEEP", "The waystones wake at dawn"
	end
	if area == "District" then
		return nil
	end
	local title = Regions.Info[area].Title
	if not RegionGates.Allowed(player, area) then
		return ("🔒 %s IS SEALED"):format(title), ("Unlocks at ASCENSION %d"):format(RegionGates.Required(area))
	end
	local data = PlayerData.Get(player)
	if not (data and data.Milestones["Region_" .. area]) then
		return "🪨 NOT ATTUNED YET", ("Reach %s on foot once to attune this stone"):format(title)
	end
	return nil
end

-- Where the root part goes so the feet land ON the ground at `destination` (re-measured
-- now, so terrain or props can never swallow you), whatever the avatar's size.
local function landingFor(destination: Vector3, character: Model, root: BasePart): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	-- From a little above (not 60 up: a sign or canopy overhead must not become the "ground").
	local hit = workspace:Raycast(destination + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), params)
	local ground = if hit then hit.Position else destination
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local hip = if humanoid then humanoid.HipHeight else 2
	return ground + Vector3.new(0, hip + root.Size.Y / 2 + 1, 0)
end

local function travel(player: Player, stone: BasePart)
	local now = os.clock()
	if now - (lastTravel[player] or 0) < COOLDOWN then
		return
	end
	local root = Combat.RootOf(player)
	local character = player.Character
	if not root or not character then
		return
	end
	-- Only from the stone you're actually standing at.
	if (root.Position - stone.Position).Magnitude > 16 then
		return
	end
	local area = stone:GetAttribute("Area")
	local destination = stone:GetAttribute("Destination")
	if type(area) ~= "string" or typeof(destination) ~= "Vector3" then
		return
	end
	local title, text = WaystoneService.Refusal(player, area)
	if title then
		deny(player, title, text or "")
		return
	end
	lastTravel[player] = now
	character:PivotTo(CFrame.new(landingFor(destination, character, root)) * root.CFrame.Rotation)
	root.AssemblyLinearVelocity = Vector3.zero
	Net.Fire("Feedback", player, { Type = "Warp", Area = area })
	local where = if area == "District" then "TREASURE DISTRICT" else Regions.Info[area].Title
	Net.Fire("Notify", player, { Kind = "Banner", Title = ("✨ %s"):format(where), Text = if area == "District" then "Home, safe and sound" else Regions.Info[area].Tagline, Tone = "Reward", Duration = 2.5 })
end

local function bind(stone: Instance)
	if not stone:IsA("BasePart") then
		return
	end
	local prompt = stone:WaitForChild("WaystonePrompt", 10)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			travel(player, stone)
		end)
	end
end

function WaystoneService.Init()
	for _, stone in CollectionService:GetTagged("Waystone") do
		task.spawn(bind, stone)
	end
	CollectionService:GetInstanceAddedSignal("Waystone"):Connect(bind)
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
end

return WaystoneService
