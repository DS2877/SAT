-- Deep South presentation on YOUR client:
--   * Rune Gates glow green when you've unlocked the region beyond (Ascension), red if not.
--   * LOW GRAVITY on the Starfall Isles: a gentle upward force makes jumps floaty.
--   * BLIZZARD (event): in Rimeheart, driving snow around you and wind pushing you sideways.
--   * Hazard / gate feedback: sounds and a camera jolt for lava, falls, sealed and unlocked
--     regions.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Sounds = require(UI.Sounds)

local DeepSouth = {}

local player = Players.LocalPlayer
local OPEN = Color3.fromRGB(90, 255, 150)
local SEALED = Color3.fromRGB(255, 80, 70)
local LOW_GRAVITY = 0.45 -- share of gravity cancelled on the isles
local WIND = 16 -- blizzard push: sideways acceleration in studs/s^2 at full gust

local function paintGates()
	local level = tonumber(player:GetAttribute("Ascension")) or 0
	for _, glow in CollectionService:GetTagged("RuneGateGlow") do
		if glow:IsA("BasePart") then
			local need = tonumber(glow:GetAttribute("RequiredAscension")) or 0
			glow.Color = if level >= need then OPEN else SEALED
			local lamp = glow:FindFirstChildOfClass("PointLight")
			if lamp then
				lamp.Color = glow.Color
			end
		end
	end
end

local lift: VectorForce? = nil
local wind: VectorForce? = nil
local snowAnchor: Part? = nil

local function forceOn(root: BasePart, name: string): VectorForce
	local attachment = root:FindFirstChild("SouthAttachment") :: Attachment?
	if not attachment then
		attachment = Instance.new("Attachment")
		attachment.Name = "SouthAttachment"
		attachment.Parent = root
	end
	local force = Instance.new("VectorForce")
	force.Name = name
	force.Attachment0 = attachment
	force.RelativeTo = Enum.ActuatorRelativeTo.World
	force.ApplyAtCenterOfMass = true
	force.Force = Vector3.zero
	force.Parent = root
	return force
end

local function update()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local area = Zones.AreaId(root.Position)
	-- Low gravity on the isles.
	if area == "Star" then
		if not lift or lift.Parent ~= root then
			lift = forceOn(root, "LowGravity")
		end
		(lift :: VectorForce).Force = Vector3.new(0, root.AssemblyMass * workspace.Gravity * LOW_GRAVITY, 0)
	elseif lift then
		lift:Destroy()
		lift = nil
	end
	-- Blizzard in Rimeheart.
	local blizzard = area == "Rime" and workspace:GetAttribute("EventId") == "Blizzard"
	if blizzard then
		if not wind or wind.Parent ~= root then
			wind = forceOn(root, "BlizzardWind")
		end
		local gust = 0.6 + 0.4 * math.sin(os.clock() * 0.8)
		local force = wind :: VectorForce
		force.Force = Vector3.new(WIND * gust, 0, WIND * 0.3 * gust) * root.AssemblyMass
		if not snowAnchor then
			local a = Instance.new("Part")
			snowAnchor = a
			a.Name = "BlizzardSnow"
			a.Anchored = true
			a.CanCollide = false
			a.CanQuery = false
			a.CanTouch = false
			a.Transparency = 1
			a.Size = Vector3.new(80, 1, 80)
			a.Parent = workspace
			local e = Instance.new("ParticleEmitter")
			e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			e.Color = ColorSequence.new(Color3.new(1, 1, 1))
			e.LightInfluence = 0
			e.Size = NumberSequence.new(0.6, 0.4)
			e.Lifetime = NumberRange.new(2, 3)
			e.Rate = 400
			e.Speed = NumberRange.new(20, 30)
			e.Acceleration = Vector3.new(40, 0, 10)
			e.Shape = Enum.ParticleEmitterShape.Box
			e.EmissionDirection = Enum.NormalId.Bottom
			e.Parent = a
		end
		(snowAnchor :: Part).CFrame = CFrame.new(root.Position + Vector3.new(-20, 25, 0))
	else
		if wind then
			wind:Destroy()
			wind = nil
		end
		if snowAnchor then
			snowAnchor:Destroy()
			snowAnchor = nil
		end
	end
end

function DeepSouth.Init()
	paintGates()
	player:GetAttributeChangedSignal("Ascension"):Connect(paintGates)
	CollectionService:GetInstanceAddedSignal("RuneGateGlow"):Connect(function()
		task.defer(paintGates)
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			update()
		end
	end)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "Hazard" then
			Sounds.Play(if payload.Kind == "Lava" or payload.Kind == "Storm" then "Hit" else "Splash")
		elseif payload.Type == "RegionLocked" then
			Sounds.Play("Error")
		elseif payload.Type == "RegionUnlocked" then
			Sounds.Play("Ascend")
		elseif payload.Type == "Warp" then
			Sounds.Play("RareDiscovery")
		end
	end)
end

return DeepSouth
