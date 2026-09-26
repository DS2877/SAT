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

-- A joint we can bend: a Motor6D (classic rigs: offset C0) or an AnimationConstraint (the
-- upgraded avatar joints: offset its parent-side attachment). Both rotate the same way.
type Joint = { Get: () -> CFrame, Target: Instance, Property: string }

local function jointNamed(part: Instance?, name: string): Joint?
	local joint = part and part:FindFirstChild(name)
	if joint and joint:IsA("Motor6D") then
		local motor = joint
		return { Get = function()
			return motor.C0
		end, Target = motor, Property = "C0" }
	elseif joint and joint:IsA("AnimationConstraint") and joint.Attachment0 then
		local attachment = joint.Attachment0 :: Attachment
		return { Get = function()
			return attachment.CFrame
		end, Target = attachment, Property = "CFrame" }
	end
	return nil
end

-- Right shoulder + waist (R15), or the right shoulder alone (R6).
local function jointsOf(character: Model): (Joint?, Joint?)
	local shoulder = jointNamed(character:FindFirstChild("RightUpperArm"), "RightShoulder") or jointNamed(character:FindFirstChild("Torso"), "Right Shoulder")
	return shoulder, jointNamed(character:FindFirstChild("UpperTorso"), "Waist")
end

-- `base` turned `degrees` around the parent part's vertical axis, through the joint.
local function turned(base: CFrame, degrees: number): CFrame
	return CFrame.new(base.Position) * CFrame.Angles(0, math.rad(degrees), 0) * base.Rotation
end

-- The SWAT (Config/Bats.Swing): wind up right, whip across left, recover. Animated on every
-- client for every player, so it shows at once: the arm and waist turn, and the bat itself
-- tips back and chops through level in the hand (that part works on every avatar).
local function swing(player: Player)
	local character = player.Character
	local tool = character and character:FindFirstChild("Bat")
	if not character or swinging[character] or not tool or not tool:IsA("Tool") then
		return
	end
	swinging[character] = true
	local cfg = Bats.Swing
	local shoulder, waist = jointsOf(character)
	local baseArm = shoulder and shoulder.Get()
	local baseWaist = waist and waist.Get()
	local lean = Instance.new("NumberValue")
	lean.Value = Bats.GripElevation
	lean.Changed:Connect(function(value)
		if tool.Parent == character then
			tool.Grip = Bats.GripAt(value)
		end
	end)
	local function pose(step, time: number, style: Enum.EasingStyle, direction: Enum.EasingDirection?)
		local info = TweenInfo.new(time, style, direction or Enum.EasingDirection.Out)
		if shoulder and baseArm then
			TweenService:Create(shoulder.Target, info, { [shoulder.Property] = if step then turned(baseArm, step.Arm) else baseArm }):Play()
		end
		if waist and baseWaist then
			TweenService:Create(waist.Target, info, { [waist.Property] = if step then turned(baseWaist, step.Waist) else baseWaist }):Play()
		end
		TweenService:Create(lean, info, { Value = if step then step.Bat else Bats.GripElevation }):Play()
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
			task.delay(cfg.Recover + 0.02, function()
				-- Snap exactly home (a respawn or a new bat mid-swing can't leave it twisted).
				if shoulder and baseArm and shoulder.Target.Parent then
					(shoulder.Target :: any)[shoulder.Property] = baseArm
				end
				if waist and baseWaist and waist.Target.Parent then
					(waist.Target :: any)[waist.Property] = baseWaist
				end
				if tool.Parent == character then
					tool.Grip = Bats.Grip
				end
				lean:Destroy()
				swinging[character] = nil
			end)
		end)
	end)
end

-- Your own swing starts the moment you press SLAP (HUD), not after the server round trip.
local lastLocalSwing = 0
function BatFx.SwingLocal()
	local character = localPlayer.Character
	Sounds.Play("Swing")
	if character and not swinging[character] and character:FindFirstChild("Bat") then
		lastLocalSwing = os.clock()
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
			-- Your own swing already played on the press - unless the bat was on your back
			-- (the server just drew it), then it plays now.
			if other and (other ~= localPlayer or os.clock() - lastLocalSwing > 0.6) then
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
