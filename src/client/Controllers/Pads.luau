-- Boost pads + launch geysers (built by World/Adventure).
--   BOOST: the server grants the speed (Services/BoostService); here the chevrons pulse
--   forward, and when YOU are boosted: whoosh, FOV kick, a cyan speed trail, status line.
--   GEYSERS (tag "LaunchPad", attribute Target): client-side because your character's physics
--   is yours. Scripted flight: straight up past the cliff edge, then a guided glide that lands
--   exactly on the target (heavy loot included - the geyser doesn't care).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local HUD = require(script.Parent.HUD)

local Pads = {}

local player = Players.LocalPlayer
local BOOST_COLOR = Color3.fromRGB(60, 230, 255)
local BASE_FOV = 70
local boostToken = 0
local launching = false
local lastLaunch = 0

local function character(): (BasePart?, Humanoid?)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	return root, humanoid
end

-- BOOST ---------------------------------------------------------------------------------

local function speedTrail(root: BasePart, duration: number)
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0, 1.2, 0)
	a0.Parent = root
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(0, -1.4, 0)
	a1.Parent = root
	local trail = Instance.new("Trail")
	trail.Attachment0 = a0
	trail.Attachment1 = a1
	trail.Color = ColorSequence.new(BOOST_COLOR, Color3.new(1, 1, 1))
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.Lifetime = 0.35
	trail.LightEmission = 1
	trail.FaceCamera = true
	trail.Parent = root
	task.delay(duration, function()
		trail.Enabled = false
		task.delay(0.5, function()
			trail:Destroy()
			a0:Destroy()
			a1:Destroy()
		end)
	end)
end

local function onBoosted(payload)
	local duration = tonumber(payload.Duration) or GameConfig.Boost.Duration
	local root = character()
	boostToken += 1
	local token = boostToken
	Sounds.Play("Boost")
	HUD.ShowStatus("⚡ SPEED BOOST!", nil, BOOST_COLOR, 1.2)
	local camera = workspace.CurrentCamera
	Kit.tween(camera, TweenInfo.new(0.18, Enum.EasingStyle.Quad), { FieldOfView = BASE_FOV + 14 })
	task.delay(duration - 0.6, function()
		if boostToken == token then
			Kit.tween(camera, TweenInfo.new(0.6, Enum.EasingStyle.Quad), { FieldOfView = BASE_FOV })
		end
	end)
	if root then
		speedTrail(root, duration)
	end
end

-- Chevrons light up one after another, pointing the way.
local function animateChevrons()
	local chevrons: { BasePart } = {}
	local function add(inst: Instance)
		if inst:IsA("BasePart") then
			table.insert(chevrons, inst)
		end
	end
	for _, inst in CollectionService:GetTagged("BoostChevron") do
		add(inst)
	end
	CollectionService:GetInstanceAddedSignal("BoostChevron"):Connect(add)
	RunService.Heartbeat:Connect(function()
		local phase = (os.clock() * 3) % 3
		for _, chevron in chevrons do
			local index = (chevron:GetAttribute("Index") or 1) - 1
			local lit = math.clamp(1 - math.abs(((phase - index + 1.5) % 3) - 1.5), 0, 1)
			chevron.Transparency = 0.75 - 0.7 * lit
		end
	end)
end

-- LAUNCH GEYSERS -----------------------------------------------------------------------

-- Scripted flight: every frame the velocity is set from the planned arc, so nothing (input,
-- air friction) can pull the player off course.
local function launch(target: Vector3)
	local root, humanoid = character()
	if not root or not humanoid then
		return
	end
	launching = true
	lastLaunch = os.clock()
	local cfg = GameConfig.Launch
	local g = workspace.Gravity
	local start = root.Position
	local apex = math.max(start.Y, target.Y) + cfg.ApexExtra
	local vy = math.sqrt(2 * g * (apex - start.Y))
	local upTime = vy / g
	Sounds.Play("Launch")
	HUD.ShowStatus("🌋 WHOOSH!", nil, Color3.fromRGB(255, 220, 120), 1)
	Kit.tween(workspace.CurrentCamera, TweenInfo.new(0.25), { FieldOfView = BASE_FOV + 12 })
	humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	local began = os.clock()
	local glideStart: Vector3? = nil
	local glideVelocity = Vector3.zero
	local connection
	connection = RunService.Heartbeat:Connect(function()
		local t = os.clock() - began
		if not root.Parent then
			connection:Disconnect()
			launching = false
			return
		end
		if t < upTime then
			root.AssemblyLinearVelocity = Vector3.new(0, vy - g * t, 0)
			return
		end
		if not glideStart then
			glideStart = root.Position
			local d = target - root.Position
			local T = cfg.GlideSeconds
			glideVelocity = Vector3.new(d.X / T, (d.Y + 0.5 * g * T * T) / T, d.Z / T)
		end
		local glideT = t - upTime
		if glideT >= cfg.GlideSeconds then
			root.AssemblyLinearVelocity = Vector3.new(0, -10, 0)
			connection:Disconnect()
			launching = false
			Kit.tween(workspace.CurrentCamera, TweenInfo.new(0.5), { FieldOfView = BASE_FOV })
			return
		end
		root.AssemblyLinearVelocity = Vector3.new(glideVelocity.X, glideVelocity.Y - g * glideT, glideVelocity.Z)
	end)
end

local function watchGeysers()
	local cfg = GameConfig.Launch
	RunService.Heartbeat:Connect(function()
		if launching or os.clock() - lastLaunch < cfg.Cooldown then
			return
		end
		local root = character()
		if not root or player:GetAttribute("MoveLocked") then
			return
		end
		for _, core in CollectionService:GetTagged("LaunchPad") do
			if core:IsA("BasePart") then
				local offset = root.Position - core.Position
				if math.abs(offset.Y) < 6 and Vector2.new(offset.X, offset.Z).Magnitude <= cfg.Radius then
					local target = core:GetAttribute("Target")
					if typeof(target) == "Vector3" then
						launch(target)
					end
					return
				end
			end
		end
	end)
end

function Pads.Init()
	BASE_FOV = workspace.CurrentCamera.FieldOfView
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.Type == "Boosted" then
			onBoosted(payload)
		end
	end)
	animateChevrons()
	watchGeysers()
end

return Pads
