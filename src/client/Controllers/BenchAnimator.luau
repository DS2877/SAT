-- Animates EVERY player who is on a bench press (player attribute "Bench" ~= ""), locally on
-- each client. The barbell is driven from the lying root part (works for any rig: R6, R15 and
-- avatars whose joints are AnimationConstraints instead of Motor6Ds), and IKControls pull the
-- hands onto the bar so the arms follow. Every server rep ("BenchRep" attribute) snaps the
-- press to lockout, so the bar hits the top exactly when the Strength pops; other lifters get a
-- floating "+N 💪" over their head ("BenchGain") so the whole gym sees the gains, and a heat
-- aura that grows with their PUMP ("BenchPump"): the longest lifter in the gym visibly glows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local BenchAnimator = {}

type Lifter = {
	Character: Model,
	Bar: Model,
	Iks: { IKControl },
	HiddenRack: BasePart?,
	Phase: number,
	Kick: number,
	Aura: ParticleEmitter?,
	Glow: PointLight?,
}

local localPlayer = Players.LocalPlayer
local lifters: { [Player]: Lifter } = {}
local TIER_COLOR = {}
for _, tier in GameConfig.Training.Benches do
	TIER_COLOR[tier.Id] = Color3.fromRGB(tier.Color[1], tier.Color[2], tier.Color[3])
end

-- Bar height above the chest (studs along the lying root's look vector).
local BAR_LOW = 1.1
local BAR_HIGH = 3.0
local BAR_TOWARD_HEAD = 0.9
local GRIP = 1.45

local function makeBar(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "LocalBarbell"
	local function piece(name: string, size: Vector3, partColor: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = partColor
		p.Material = material
		p.Parent = model
		return p
	end
	local bar = piece("Bar", Vector3.new(7.4, 0.35, 0.35), Color3.fromRGB(205, 205, 215), Enum.Material.Metal)
	model.PrimaryPart = bar
	piece("PlateA", Vector3.new(0.5, 2.2, 2.2), color, Enum.Material.Metal)
	piece("PlateB", Vector3.new(0.5, 2.2, 2.2), color, Enum.Material.Metal)
	for _, side in { { "GripR", GRIP }, { "GripL", -GRIP } } do
		local attachment = Instance.new("Attachment")
		attachment.Name = side[1]
		attachment.Position = Vector3.new(side[2], 0, 0)
		attachment.Parent = bar
	end
	model.Parent = workspace
	return model
end

local function makeIk(character: Model, upper: string, hand: string, target: Attachment): IKControl?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local chainRoot = character:FindFirstChild(upper)
	local effector = character:FindFirstChild(hand)
	if not humanoid or not chainRoot or not effector then
		return nil -- R6: no arm chain, the bar still presses on its own
	end
	local ik = Instance.new("IKControl")
	ik.Name = "BenchIK"
	ik.Type = Enum.IKControlType.Position
	ik.ChainRoot = chainRoot
	ik.EndEffector = effector
	ik.Target = target
	ik.Weight = 1
	ik.Priority = 10
	ik.Parent = humanoid
	return ik
end

-- The bench's own resting barbell would double up with the one being lifted.
local function nearestRackBar(position: Vector3): BasePart?
	local gym = workspace:FindFirstChild("StrengthGym", true)
	if not gym then
		return nil
	end
	local best, bestDistance = nil, 6
	for _, child in gym:GetChildren() do
		if child.Name == "RackBar" and child:IsA("BasePart") then
			local d = (child.Position - position).Magnitude
			if d < bestDistance then
				best, bestDistance = child, d
			end
		end
	end
	return best
end

local function start(player: Player)
	local character = player.Character
	if not character or lifters[player] then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tierId = player:GetAttribute("Bench")
	local bar = makeBar(TIER_COLOR[tierId] or Color3.fromRGB(170, 120, 70))
	local primary = bar.PrimaryPart :: BasePart
	local iks = {}
	for _, spec in { { "RightUpperArm", "RightHand", "GripR" }, { "LeftUpperArm", "LeftHand", "GripL" } } do
		local ik = makeIk(character, spec[1], spec[2], primary:FindFirstChild(spec[3]) :: Attachment)
		if ik then
			table.insert(iks, ik)
		end
	end
	local rack = if root then nearestRackBar(root.Position) else nil
	if rack then
		rack.Transparency = 1 -- local only
	end
	-- Heat aura: embers rising off the lifter, stronger as the pump builds.
	local aura, glow = nil, nil
	if root then
		aura = Instance.new("ParticleEmitter")
		aura.Name = "PumpAura"
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Rate = 0
		aura.Lifetime = NumberRange.new(0.8, 1.4)
		aura.Speed = NumberRange.new(2, 4)
		aura.SpreadAngle = Vector2.new(40, 40)
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
		aura.LightEmission = 1
		aura.Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 40))
		aura.Parent = root
		glow = Instance.new("PointLight")
		glow.Name = "PumpGlow"
		glow.Color = Color3.fromRGB(255, 140, 60)
		glow.Range = 10
		glow.Brightness = 0
		glow.Parent = root
	end
	lifters[player] = { Character = character, Bar = bar, Iks = iks, HiddenRack = rack, Phase = 0.5, Kick = 0, Aura = aura, Glow = glow }
end

local function stop(player: Player)
	local lifter = lifters[player]
	if not lifter then
		return
	end
	lifters[player] = nil
	for _, ik in lifter.Iks do
		ik:Destroy()
	end
	if lifter.HiddenRack then
		lifter.HiddenRack.Transparency = 0
	end
	if lifter.Aura then
		lifter.Aura:Destroy()
	end
	if lifter.Glow then
		lifter.Glow:Destroy()
	end
	lifter.Bar:Destroy()
end

local function refresh(player: Player)
	local bench = player:GetAttribute("Bench")
	if type(bench) == "string" and bench ~= "" then
		start(player)
	else
		stop(player)
	end
end

-- "+N 💪" rising over another lifter's head.
local function worldPop(lifter: Lifter, amount: number, kind: string?)
	local head = lifter.Character:FindFirstChild("Head") or lifter.Character:FindFirstChild("HumanoidRootPart")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(math.random(-10, 10) / 10, 3, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = if kind == "Golden" or kind == "Mega" then Color3.fromRGB(255, 215, 60) else Color3.fromRGB(255, 170, 70)
	label.TextStrokeTransparency = 0.2
	label.Text = if kind == "Golden" then ("✨ +%d 💪"):format(amount) else ("+%d 💪"):format(amount)
	if kind == "Golden" then
		gui.Size = UDim2.fromOffset(240, 60)
	end
	label.Parent = gui
	gui.Adornee = head
	gui.Parent = head
	local info = TweenInfo.new(1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(gui, info, { StudsOffsetWorldSpace = gui.StudsOffsetWorldSpace + Vector3.new(0, 2.5, 0) }):Play()
	TweenService:Create(label, info, { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(1.05, function()
		gui:Destroy()
	end)
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Bench"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("BenchRep"):Connect(function()
		local lifter = lifters[player]
		if not lifter then
			return
		end
		-- Lockout is phase 0.5: jump there and add a little overshoot "kick".
		lifter.Phase = 0.5
		lifter.Kick = 1
		local gain = player:GetAttribute("BenchGain")
		if player ~= localPlayer and type(gain) == "number" then
			local kind = player:GetAttribute("BenchKind")
			worldPop(lifter, gain, if type(kind) == "string" then kind else nil)
		end
	end)
	player.CharacterRemoving:Connect(function()
		stop(player)
	end)
	refresh(player)
end

function BenchAnimator.Init()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(stop)

	local period = GameConfig.Training.RepPeriod
	local pumpMax = GameConfig.Training.PumpMax
	RunService.RenderStepped:Connect(function(dt)
		for player, lifter in lifters do
			local root = lifter.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not lifter.Character.Parent or not root then
				stop(player)
				continue
			end
			lifter.Phase = (lifter.Phase + dt / period) % 1
			local pump = tonumber(player:GetAttribute("BenchPump")) or 1
			local heat = math.clamp((pump - 1) / (pumpMax - 1), 0, 1)
			if lifter.Aura then
				lifter.Aura.Rate = heat * 18
			end
			if lifter.Glow then
				lifter.Glow.Brightness = heat * 1.6
			end
			lifter.Kick = math.max(0, lifter.Kick - dt * 5)
			-- 0 = bar at the chest, 1 = arms locked out
			local extend = 0.5 - 0.5 * math.cos(lifter.Phase * math.pi * 2)
			local height = BAR_LOW + (BAR_HIGH - BAR_LOW) * extend + 0.25 * lifter.Kick
			-- Lying root: LookVector points at the sky, UpVector toward the head. Bar axis = RightVector.
			local barCf = root.CFrame * CFrame.new(0, BAR_TOWARD_HEAD, -height)
			local primary = lifter.Bar.PrimaryPart :: BasePart
			primary.CFrame = barCf
			local plateA = lifter.Bar:FindFirstChild("PlateA") :: BasePart
			local plateB = lifter.Bar:FindFirstChild("PlateB") :: BasePart
			plateA.CFrame = barCf * CFrame.new(3.1, 0, 0)
			plateB.CFrame = barCf * CFrame.new(-3.1, 0, 0)
		end
	end)
end

return BenchAnimator
