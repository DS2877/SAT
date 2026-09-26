-- Bats on the client (Config/Bats, Services/BatService): the swing trail on everyone's bat and
-- the slap impact burst. The bat itself is a real Roblox Tool (BatService), so Roblox does the
-- hand grip, the arm-out hold and the "Slash" swing animation - the standard look of every
-- Roblox melee game. There's no hotbar (the Backpack UI is off): the SLAP button swings, and
-- the server tucks the bat away while you carry treasure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Bats = require(Shared.Config.Bats)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Sounds = require(UI.Sounds)

local BatFx = {}

local localPlayer = Players.LocalPlayer
local swinging: { [Model]: boolean } = {}

local function trailOf(character: Model): Trail?
	local tool = character:FindFirstChild("Bat")
	local handle = tool and tool:IsA("Tool") and tool:FindFirstChild("Handle")
	local trail = handle and handle:FindFirstChild("SwingTrail")
	return if trail and trail:IsA("Trail") then trail else nil
end

-- Right shoulder + waist joints (R15), or the right shoulder alone (R6).
local function jointsOf(character: Model): (Motor6D?, Motor6D?)
	local arm = character:FindFirstChild("RightUpperArm")
	local shoulder = (arm and arm:FindFirstChild("RightShoulder")) or (character:FindFirstChild("Torso") and (character :: any).Torso:FindFirstChild("Right Shoulder"))
	local upper = character:FindFirstChild("UpperTorso")
	local waist = upper and upper:FindFirstChild("Waist")
	return (if shoulder and shoulder:IsA("Motor6D") then shoulder else nil), (if waist and waist:IsA("Motor6D") then waist else nil)
end

-- `base` turned `degrees` around the parent part's vertical axis, through the joint.
local function turned(base: CFrame, degrees: number): CFrame
	return CFrame.new(base.Position) * CFrame.Angles(0, math.rad(degrees), 0) * base.Rotation
end

-- The SWAT (Config/Bats.Swing): wind up right, whip across left, recover. Animated on every
-- client for every player (joint offsets on top of the held-tool pose), so it shows at once.
local function swing(player: Player)
	local character = player.Character
	if not character or swinging[character] or not character:FindFirstChild("Bat") then
		return
	end
	local shoulder, waist = jointsOf(character)
	if not shoulder then
		return
	end
	swinging[character] = true
	local cfg = Bats.Swing
	local baseArm = shoulder.C0
	local baseWaist = waist and waist.C0
	local function pose(step, time: number, style: Enum.EasingStyle, direction: Enum.EasingDirection?)
		local info = TweenInfo.new(time, style, direction or Enum.EasingDirection.Out)
		TweenService:Create(shoulder, info, { C0 = if step then turned(baseArm, step.Arm) else baseArm }):Play()
		if waist and baseWaist then
			TweenService:Create(waist, info, { C0 = if step then turned(baseWaist, step.Waist) else baseWaist }):Play()
		end
	end
	local trail = trailOf(character)
	-- Smooth: ease out of the ready pose into the wind-up, then one continuous sweep that
	-- accelerates through the middle and eases into the follow-through (Sine InOut).
	pose(cfg.WindUp, cfg.WindUp.Time, Enum.EasingStyle.Sine)
	task.delay(cfg.WindUp.Time, function()
		if trail then
			trail.Enabled = true
		end
		pose(cfg.Strike, cfg.Strike.Time, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		task.delay(cfg.Strike.Time + cfg.Hold, function()
			if trail then
				trail.Enabled = false
			end
			pose(nil, cfg.Recover, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
			task.delay(cfg.Recover, function()
				-- Snap exactly home (a respawn or a new bat mid-swing can't leave it twisted).
				if shoulder.Parent then
					shoulder.C0 = baseArm
				end
				if waist and baseWaist and waist.Parent then
					waist.C0 = baseWaist
				end
				swinging[character] = nil
			end)
		end)
	end)
end

-- Your own swing starts the moment you press SLAP (HUD), not after the server round trip.
function BatFx.SwingLocal()
	if localPlayer.Character and not swinging[localPlayer.Character] and localPlayer.Character:FindFirstChild("Bat") then
		Sounds.Play("Swing")
		swing(localPlayer)
	end
end

-- A burst where a slap lands: bigger and brighter the better the bat.
local function impact(position: Vector3, batId: string?, result: string?)
	local bat = Bats.Get(batId) or Bats.List[1]
	local color = Bats.TrailColor(bat)
	local size = 3 + bat.Tier * 0.5
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.new(1, 1, 1)
	ring.CFrame = CFrame.new(position)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	if bat.Tier >= 5 then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(color, Bats.Color(bat))
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Size = NumberSequence.new(0.6, 0)
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Speed = NumberRange.new(10, 20 + bat.Tier * 2)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Rate = 0
		sparks.Parent = ring
		sparks:Emit(8 + bat.Tier * 3)
	end
	-- "SLAP!" pops out of the hit.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = if result == "Knocked" then "WHAM!" elseif result == "Shaken" then "SLAP!" else "SLAP!"
	label.Rotation = math.random(-12, 12)
	label.Parent = gui
	gui.Parent = ring
	TweenService:Create(gui, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Sounds.PlayAt("BatHit", position)
	Sounds.PlayAt("Slap", position)
	task.delay(0.7, function()
		ring:Destroy()
	end)
end

function BatFx.Init()
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "Swing" then
			local other = Players:GetPlayerByUserId(payload.UserId)
			if other and other ~= localPlayer then
				swing(other)
			end
		elseif payload.Type == "SlapImpact" and typeof(payload.Position) == "Vector3" then
			impact(payload.Position, payload.BatId, payload.Result)
		elseif payload.Type == "BatBought" then
			Sounds.Play("BigReward")
		end
	end)
	-- No hotbar: the bat is always in hand (or tucked away while carrying).
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				return
			end
			task.wait(1)
		end
	end)
end

return BatFx
