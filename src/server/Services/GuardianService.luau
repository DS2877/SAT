-- Simple, reliable Guardian AI using server-owned Humanoid NPCs (smooth replication).
-- PATROL -> DETECT -> CHASE -> ATTACK -> (KNOCK) -> RETURN. Carriers are preferred targets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Guardians = require(Shared.Config.Guardians)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local Combat = require(script.Parent.Combat)
local TreasureService = require(script.Parent.TreasureService)
local Decoys = require(script.Parent.Decoys)
local Gadgets = require(Shared.Config.Gadgets)

local GuardianService = {}

type Guardian = {
	Type: string,
	Def: any,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Home: Vector3,
	PatrolRadius: number,
	Range: number?, -- hard limit from Home it never walks past (islands, between crevasses)
	Spawn: any, -- the spawn info, to rebuild it if it's ever lost
	LastPos: Vector3,
	StuckSince: number?,
	State: string, -- "Patrol" | "Chase" | "Return" | "Stunned"
	SlowUntil: number?, -- os.clock(): slowed by a bat hit until then
	Target: Player?,
	NextPatrolAt: number,
	LastAttack: number,
	StateUntil: number,
}

local guardians: { Guardian } = {}
local rng = Random.new()
local TICK = 0.2

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local WOOD = Color3.fromRGB(92, 62, 36)
local BONE = Color3.fromRGB(236, 228, 206)
local IRON = Color3.fromRGB(88, 84, 80)
local BLACK = Color3.fromRGB(18, 16, 20)

-- Builds a guardian body. All sizes/offsets below are design units (the old, small models);
-- `S` (def.Scale) blows them up so every guardian towers over a player.
local function build(typeName: string, def, position: Vector3): (Model, BasePart, Humanoid)
	local model = Instance.new("Model")
	model.Name = def.Name
	local S = def.Scale or 1
	local size = Vector3.new(def.Size[1], def.Size[2], def.Size[3]) * S
	local hip = def.HipHeight * S

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = size
	root.Transparency = 1
	root.CFrame = CFrame.new(position + Vector3.new(0, hip + size.Y / 2 + 0.5, 0))
	root.Parent = model
	model.PrimaryPart = root

	local body, accent, eye = rgb(def.BodyColor), rgb(def.AccentColor), rgb(def.EyeColor)
	-- Region variants reuse a body design (def.Model) with their own colours.
	local design = def.Model or typeName
	local ground = -(def.Size[2] / 2 + def.HipHeight) -- design-unit y of the feet

	local function add(name: string?, shape, sz: Vector3, color: Color3, material, offset: CFrame): BasePart
		local p = Instance.new("Part")
		p.Name = name or "Part"
		p.Shape = shape or Enum.PartType.Block
		p.Size = sz * S
		p.Color = color
		p.Material = material or Enum.Material.SmoothPlastic
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CFrame = root.CFrame * (CFrame.new(offset.Position * S) * offset.Rotation)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = p
		weld.Parent = p
		p.Parent = model
		return p
	end
	local function box(sz: Vector3, color: Color3, offset: CFrame, material: Enum.Material?): BasePart
		return add(nil, Enum.PartType.Block, sz, color, material, offset)
	end
	local function ball(sz: Vector3, color: Color3, offset: CFrame, material: Enum.Material?): BasePart
		return add(nil, Enum.PartType.Ball, sz, color, material, offset)
	end
	local function spike(sz: Vector3, color: Color3, offset: CFrame, material: Enum.Material?): BasePart
		return add(nil, Enum.PartType.Wedge, sz, color, material, offset)
	end
	-- A limb segment between two design-unit points.
	local function segment(a: Vector3, b: Vector3, thickness: number, color: Color3, material: Enum.Material?): BasePart
		local length = (b - a).Magnitude
		return box(Vector3.new(thickness, thickness, length), color, CFrame.lookAt((a + b) / 2, b), material)
	end
	local eyes = {}
	local function glowEye(sz: Vector3, offset: CFrame, shape: Enum.PartType?)
		local p = add("Eye", shape or Enum.PartType.Ball, sz, eye, Enum.Material.Neon, offset)
		table.insert(eyes, p)
		return p
	end
	local function brow(x: number, y: number, z: number, width: number)
		-- Slanted brow ridge: makes any face look angry.
		box(Vector3.new(width, 0.16, 0.3), BLACK, CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(if x > 0 then 22 else -22)))
	end

	if design == "Wolf" then
		-- DIRE WOLF: hunched shoulders, bristling spine, open fanged jaw.
		box(Vector3.new(2.7, 2.7, 2.5), body, CFrame.new(0, 0.3, -0.9) * CFrame.Angles(math.rad(-8), 0, 0), Enum.Material.Fabric)
		box(Vector3.new(2.2, 2.1, 2.5), body, CFrame.new(0, -0.1, 1.2), Enum.Material.Fabric)
		box(Vector3.new(2.9, 1.4, 1.6), accent, CFrame.new(0, 0.9, -1.7) * CFrame.Angles(math.rad(-15), 0, 0), Enum.Material.Fabric) -- ruff
		for i, z in { -1.9, -1.1, -0.3, 0.5, 1.3, 2.0 } do
			local h = 1.1 - math.abs(i - 2.5) * 0.12
			spike(Vector3.new(0.35, h, 0.7), BLACK, CFrame.new(0, 1.35 + h / 2, z) * CFrame.Angles(0, math.rad(180), 0))
		end
		local head = box(Vector3.new(1.9, 1.7, 1.9), body, CFrame.new(0, 0.8, -2.9), Enum.Material.Fabric)
		head.Name = "Head"
		box(Vector3.new(1.15, 0.75, 1.5), body, CFrame.new(0, 0.55, -4.3), Enum.Material.Fabric) -- snout
		ball(Vector3.new(0.45, 0.35, 0.35), BLACK, CFrame.new(0, 0.9, -5.05)) -- nose
		box(Vector3.new(1.05, 0.28, 1.3), body, CFrame.new(0, -0.05, -4.1) * CFrame.Angles(math.rad(22), 0, 0), Enum.Material.Fabric) -- open jaw
		box(Vector3.new(0.9, 0.1, 1.2), Color3.fromRGB(150, 30, 40), CFrame.new(0, 0.12, -4.1) * CFrame.Angles(math.rad(12), 0, 0)) -- maw
		for _, x in { -0.42, 0.42 } do
			spike(Vector3.new(0.16, 0.55, 0.2), BONE, CFrame.new(x, -0.05, -4.85) * CFrame.Angles(math.rad(180), 0, 0)) -- upper fangs
			spike(Vector3.new(0.14, 0.4, 0.18), BONE, CFrame.new(x * 0.8, 0.2, -4.6)) -- lower fangs
			spike(Vector3.new(0.3, 1.1, 0.6), body, CFrame.new(x * 1.4, 2.1, -2.6), Enum.Material.Fabric) -- ears
			glowEye(Vector3.new(0.42, 0.3, 0.3), CFrame.new(x * 1.15, 1.15, -3.82))
			brow(x * 1.15, 1.42, -3.86, 0.6)
		end
		box(Vector3.new(0.7, 0.7, 2.4), body, CFrame.new(0, 0.9, 3.1) * CFrame.Angles(math.rad(28), 0, 0), Enum.Material.Fabric) -- tail
		spike(Vector3.new(0.5, 0.5, 1), accent, CFrame.new(0, 1.55, 4.3) * CFrame.Angles(math.rad(28), 0, 0), Enum.Material.Fabric)
		for _, x in { -0.9, 0.9 } do
			for _, z in { -1.6, 1.7 } do
				local thick = if z < 0 then 0.85 else 0.75
				segment(Vector3.new(x, -0.3, z), Vector3.new(x * 1.05, ground + 0.35, z - 0.2), thick, body, Enum.Material.Fabric)
				box(Vector3.new(1, 0.4, 1.2), body, CFrame.new(x * 1.05, ground + 0.2, z - 0.4), Enum.Material.Fabric)
				for c = -1, 1 do
					spike(Vector3.new(0.14, 0.2, 0.4), BONE, CFrame.new(x * 1.05 + c * 0.3, ground + 0.1, z - 1.1))
				end
			end
		end
	elseif design == "Goblin" then
		-- GOBLIN BRUTE: huge hunched ogre-goblin with tusks, spiked pauldrons and a nail club.
		ball(Vector3.new(3.2, 3.2, 2.8), body, CFrame.new(0, 0, 0))
		box(Vector3.new(2.8, 0.9, 2.4), accent, CFrame.new(0, -1.3, 0), Enum.Material.Fabric) -- loincloth
		box(Vector3.new(3.1, 0.35, 2.6), WOOD, CFrame.new(0, -0.8, 0), Enum.Material.Wood) -- belt
		box(Vector3.new(0.6, 0.5, 0.2), Color3.fromRGB(190, 160, 70), CFrame.new(0, -0.8, -1.32), Enum.Material.Metal) -- buckle
		for _, x in { -1, 1 } do
			box(Vector3.new(1.5, 0.7, 1.5), IRON, CFrame.new(x * 1.6, 1.3, 0) * CFrame.Angles(0, 0, math.rad(x * -18)), Enum.Material.CorrodedMetal)
			for _, z in { -0.4, 0.4 } do
				spike(Vector3.new(0.3, 0.8, 0.3), BONE, CFrame.new(x * 1.9, 1.95, z))
			end
			-- Long arms: knuckles almost on the ground.
			segment(Vector3.new(x * 1.8, 1.0, 0), Vector3.new(x * 2.1, -0.9, -0.5), 0.9, body)
			ball(Vector3.new(1.3, 1.2, 1.3), body, CFrame.new(x * 2.15, -1.3, -0.6))
			-- Stubby, thick legs.
			segment(Vector3.new(x * 0.8, -1.2, 0), Vector3.new(x * 0.85, ground + 0.4, 0), 1.1, body)
			box(Vector3.new(1.3, 0.45, 1.7), accent, CFrame.new(x * 0.85, ground + 0.22, -0.25), Enum.Material.Fabric)
		end
		local head = ball(Vector3.new(2.3, 2.1, 2.2), body, CFrame.new(0, 1.9, -0.7))
		head.Name = "Head"
		box(Vector3.new(1.6, 0.6, 1), body, CFrame.new(0, 1.2, -1.45)) -- underbite jaw
		for _, x in { -0.5, 0.5 } do
			spike(Vector3.new(0.3, 0.9, 0.3), BONE, CFrame.new(x, 1.8, -1.85)) -- tusks
			glowEye(Vector3.new(0.45, 0.4, 0.4), CFrame.new(x * 0.9, 2.2, -1.72))
			brow(x * 0.9, 2.5, -1.78, 0.7)
			-- Long pointed ears.
			spike(Vector3.new(0.3, 0.6, 1.7), body, CFrame.new(x * 3.1, 2.3, -0.5) * CFrame.Angles(0, math.rad(x > 0 and 90 or -90), math.rad(x > 0 and -15 or 15)))
		end
		ball(Vector3.new(0.6, 0.5, 0.6), Color3.fromRGB(70, 110, 40), CFrame.new(0, 1.9, -1.85)) -- nose
		-- Nail club in the right hand.
		local club = CFrame.new(2.4, -1.0, -1.2) * CFrame.Angles(math.rad(-60), 0, 0)
		box(Vector3.new(0.4, 0.4, 3.2), WOOD, club * CFrame.new(0, 0, -1.2), Enum.Material.Wood)
		ball(Vector3.new(1.5, 1.5, 1.5), WOOD, club * CFrame.new(0, 0, -3), Enum.Material.Wood)
		for i = 0, 5 do
			local a = i * math.pi / 3
			spike(Vector3.new(0.18, 0.5, 0.18), IRON, club * CFrame.new(0, 0, -3) * CFrame.Angles(a, 0, 0) * CFrame.new(0, 0.85, 0), Enum.Material.Metal)
		end
	elseif design == "Golem" then
		-- STONE GOLEM: moss-covered boulder titan with a molten core.
		local core = eye -- molten orange on the Stone Golem, frost blue on the Ice Golem
		box(Vector3.new(3.8, 3.4, 2.8), body, CFrame.new(0, 0.3, 0) * CFrame.Angles(math.rad(-6), 0, 0), Enum.Material.Slate)
		box(Vector3.new(3.2, 1.4, 2.4), body, CFrame.new(0, -1.5, 0.1), Enum.Material.Slate)
		box(Vector3.new(0.35, 1.9, 0.12), core, CFrame.new(0.1, 0.5, -1.45) * CFrame.Angles(0, 0, math.rad(14)), Enum.Material.Neon)
		box(Vector3.new(0.9, 0.25, 0.12), core, CFrame.new(-0.5, -0.2, -1.43) * CFrame.Angles(0, 0, math.rad(-20)), Enum.Material.Neon)
		local heart = ball(Vector3.new(0.9, 0.9, 0.9), core, CFrame.new(0, 0.7, -1.3), Enum.Material.Neon)
		heart.Name = "Core"
		local head = box(Vector3.new(1.5, 1.2, 1.4), body, CFrame.new(0, 2.25, -0.7), Enum.Material.Slate)
		head.Name = "Head"
		box(Vector3.new(1.7, 0.35, 1.5), accent, CFrame.new(0, 2.95, -0.6), Enum.Material.Grass) -- mossy crown
		for _, x in { -1, 1 } do
			glowEye(Vector3.new(0.45, 0.16, 0.1), CFrame.new(x * 0.38, 2.35, -1.42), Enum.PartType.Block)
			-- Boulder shoulders with moss caps.
			ball(Vector3.new(2.2, 2.1, 2.2), body, CFrame.new(x * 2.3, 1.5, 0), Enum.Material.Slate)
			box(Vector3.new(1.7, 0.4, 1.7), accent, CFrame.new(x * 2.3, 2.5, 0), Enum.Material.Grass)
			-- Massive arms hanging to the ground, fists like boulders.
			segment(Vector3.new(x * 2.5, 0.8, 0), Vector3.new(x * 2.8, -1.3, -0.3), 1.4, body, Enum.Material.Slate)
			box(Vector3.new(2, 1.8, 2), body, CFrame.new(x * 2.85, -2.1, -0.45) * CFrame.Angles(math.rad(10), math.rad(x * 12), 0), Enum.Material.Slate)
			box(Vector3.new(0.12, 0.8, 0.12), core, CFrame.new(x * 2.85, -2.1, -1.47), Enum.Material.Neon)
			-- Pillar legs.
			segment(Vector3.new(x * 0.95, -1.8, 0), Vector3.new(x * 1, ground + 0.5, 0), 1.5, body, Enum.Material.Slate)
			box(Vector3.new(1.8, 0.6, 2.1), body, CFrame.new(x * 1, ground + 0.3, -0.2), Enum.Material.Slate)
		end
		-- Crystals growing out of its back.
		for _, c in { { -0.8, 2.2, 1.2, -18 }, { 0, 2.6, 1.3, 0 }, { 0.8, 2.1, 1.2, 18 }, { 0.4, 1.4, 1.5, 30 } } do
			spike(Vector3.new(0.5, 1.5, 0.5), eye:Lerp(Color3.new(1, 1, 1), 0.2), CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(math.rad(-25), 0, math.rad(c[4])), Enum.Material.Neon)
		end
		for _, m in { { -1.2, 0.9, -1.35 }, { 1.3, -0.6, -1.35 }, { -0.4, -1.4, -1.25 } } do
			box(Vector3.new(0.9, 0.5, 0.2), accent, CFrame.new(m[1], m[2], m[3]), Enum.Material.Grass)
		end
	elseif design == "Wraith" then
		-- WRAITH: a hooded spectre floating off the ground, tattered robe, clawed arms, a void
		-- where its face should be and two burning eyes.
		box(Vector3.new(2.4, 2.2, 1.6), body, CFrame.new(0, 0.8, 0), Enum.Material.Fabric)
		box(Vector3.new(2.9, 1.8, 2.1), body, CFrame.new(0, -1, 0.1), Enum.Material.Fabric)
		for i = 0, 5 do
			local a = i / 6 * 2 * math.pi
			spike(Vector3.new(0.7, 1.4, 0.4), body, CFrame.new(math.cos(a) * 1.1, -2.4, math.sin(a) * 0.8 + 0.1) * CFrame.Angles(math.pi, a, 0), Enum.Material.Fabric)
		end
		local hood = ball(Vector3.new(2, 2, 2), body, CFrame.new(0, 2.4, 0.15), Enum.Material.Fabric)
		hood.Name = "Head"
		spike(Vector3.new(1, 1, 1.2), body, CFrame.new(0, 3.5, 0.5) * CFrame.Angles(math.rad(-25), 0, 0), Enum.Material.Fabric)
		box(Vector3.new(1.2, 1.1, 0.25), BLACK, CFrame.new(0, 2.3, -0.8))
		for _, x in { -1, 1 } do
			glowEye(Vector3.new(0.34, 0.14, 0.1), CFrame.new(x * 0.25, 2.4, -0.95) * CFrame.Angles(0, 0, math.rad(x * -15)), Enum.PartType.Block)
			ball(Vector3.new(0.9, 0.8, 0.9), accent, CFrame.new(x * 1.3, 1.7, 0), Enum.Material.Metal)
			segment(Vector3.new(x * 1.35, 1.4, 0), Vector3.new(x * 1.9, -0.2, -0.9), 0.5, body, Enum.Material.Fabric)
			for c = -1, 1 do
				spike(Vector3.new(0.14, 0.7, 0.14), accent, CFrame.new(x * 2 + c * 0.14, -0.7, -1.2) * CFrame.Angles(math.rad(160), 0, math.rad(c * 12)), Enum.Material.Metal)
			end
			spike(Vector3.new(0.35, 1, 0.35), eye, CFrame.new(x * 1.7, 2.7, 0.7) * CFrame.Angles(0, 0, math.rad(x * -20)), Enum.Material.Neon)
		end
		local mist = Instance.new("ParticleEmitter")
		mist.Name = "WraithMist"
		mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
		mist.Color = ColorSequence.new(eye:Lerp(Color3.new(1, 1, 1), 0.4))
		mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
		mist.Size = NumberSequence.new(1.5 * S, 4 * S)
		mist.Lifetime = NumberRange.new(1.2, 2)
		mist.Rate = 10
		mist.Speed = NumberRange.new(0.5, 1.5)
		mist.EmissionDirection = Enum.NormalId.Bottom
		mist.LightInfluence = 0
		mist.Parent = root
	else -- Spider
		-- GIANT CAVE SPIDER: eight jointed legs, glowing eye cluster, venom-marked abdomen.
		local cephalo = ball(Vector3.new(2.6, 1.8, 2.8), body, CFrame.new(0, 0.2, -1.3))
		cephalo.Name = "Head"
		ball(Vector3.new(4.6, 3.4, 5.2), accent, CFrame.new(0, 1.1, 2.2) * CFrame.Angles(math.rad(-12), 0, 0), Enum.Material.Fabric)
		-- Venom hourglass on the back.
		local venom = Color3.fromRGB(230, 30, 60)
		spike(Vector3.new(1, 0.25, 1.1), venom, CFrame.new(0, 2.78, 1.4) * CFrame.Angles(0, 0, 0), Enum.Material.Neon)
		spike(Vector3.new(1, 0.25, 1.1), venom, CFrame.new(0, 2.7, 2.5) * CFrame.Angles(0, math.rad(180), 0), Enum.Material.Neon)
		for i = 1, 7 do
			local a = i * 0.8
			spike(Vector3.new(0.12, 0.6, 0.12), BLACK, CFrame.new(math.cos(a) * 1.6, 2.2 + math.sin(a) * 0.3, 2.2 + math.sin(a) * 1.6) * CFrame.Angles(math.rad(-20), a, 0))
		end
		-- Eyes: two big, four small, two on the sides.
		for _, x in { -0.38, 0.38 } do
			glowEye(Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, 0.7, -2.6))
			glowEye(Vector3.new(0.26, 0.26, 0.26), CFrame.new(x * 1.9, 0.85, -2.4))
			glowEye(Vector3.new(0.22, 0.22, 0.22), CFrame.new(x * 1.2, 1.05, -2.35))
			glowEye(Vector3.new(0.22, 0.22, 0.22), CFrame.new(x * 3.2, 0.55, -2.0))
			-- Fangs (chelicerae) curling inward.
			segment(Vector3.new(x, -0.1, -2.5), Vector3.new(x * 0.6, -0.9, -2.9), 0.35, BLACK, Enum.Material.Glass)
			spike(Vector3.new(0.2, 0.45, 0.2), BONE, CFrame.new(x * 0.5, -1.2, -2.95) * CFrame.Angles(math.rad(180), 0, 0))
		end
		-- Legs: body -> high knee -> foot on the ground, splayed wide.
		for _, side in { -1, 1 } do
			for i, z in { -2.2, -1.3, -0.4, 0.5 } do
				local spread = ({ 1.5, 0.7, 0.1, -0.6 })[i]
				local hipPoint = Vector3.new(side * 1.1, 0.2, z * 0.6 - 0.9)
				local knee = Vector3.new(side * 3.2, 2.2, z * 0.6 - 0.9 - spread * 0.8)
				local foot = Vector3.new(side * 4.8, ground + 0.1, z * 0.6 - 0.9 - spread * 2)
				segment(hipPoint, knee, 0.42, body, Enum.Material.Fabric)
				segment(knee, foot, 0.32, body, Enum.Material.Fabric)
				ball(Vector3.new(0.5, 0.5, 0.5), BLACK, CFrame.new(knee))
			end
		end
	end

	-- Eye glow that flares when the guardian starts hunting (see setState).
	local light = Instance.new("PointLight")
	light.Name = "EyeLight"
	light.Color = eye
	light.Range = 10 * S
	light.Brightness = 0.6
	light.Shadows = false
	light.Parent = eyes[1] or root

	-- Rage aura: dark smoke around the body while chasing.
	local aura = Instance.new("ParticleEmitter")
	aura.Name = "RageAura"
	aura.Enabled = false
	aura.Rate = 14
	aura.Lifetime = NumberRange.new(0.8, 1.4)
	aura.Speed = NumberRange.new(1, 3)
	aura.SpreadAngle = Vector2.new(180, 180)
	aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2 * S), NumberSequenceKeypoint.new(1, 2.6 * S) })
	aura.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	aura.Color = ColorSequence.new(Color3.fromRGB(40, 10, 20), eye)
	aura.LightEmission = 0.2
	aura.Parent = root

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HipHeight = hip
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = def.PatrolSpeed
	humanoid.AutoRotate = true
	for _, state in {
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Dead,
	} do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	-- Name tag just above the tallest part.
	local top = size.Y / 2
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			top = math.max(top, child.Position.Y + child.Size.Y / 2 - root.Position.Y)
		end
	end
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(150, 24)
	tag.StudsOffset = Vector3.new(0, top + 1.5, 0)
	tag.MaxDistance = 80
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 80, 70)
	label.TextStrokeTransparency = 0
	label.Text = "☠ " .. def.Name:upper()
	label.Name = "Label"
	label.Parent = tag
	tag.Name = "GuardianTag"
	tag.Parent = root

	model:SetAttribute("GuardianType", typeName)
	return model, root, humanoid
end

local function attractsGuardians(player: Player): boolean
	local record = TreasureService.GetCarrying(player)
	return record ~= nil and record.Def.SpecialEffect == "AttractsGuardians"
end

-- Regional events (Cursed Hour) enrage the guardians of ONE region via workspace attributes
-- GuardianRage (multiplier) + EventArea (region id).
local function rage(g: Guardian): number
	local value = workspace:GetAttribute("GuardianRage")
	if type(value) ~= "number" or value <= 0 then
		return 1
	end
	if Zones.AreaId(g.Home) ~= workspace:GetAttribute("EventArea") then
		return 1
	end
	return value
end

local function findTarget(g: Guardian): (Player?, BasePart?)
	local best, bestRoot, bestScore = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and not player.Character:FindFirstChildOfClass("ForceField") and not Zones.InSafeZone(root.Position) then
			local detect = g.Def.DetectRange * rage(g) * (if attractsGuardians(player) then 2.5 else 1)
			if player:GetAttribute("Disguised") then
				detect *= Gadgets.Get("disguise").GuardianDetectMultiplier
			end
			local distance = (root.Position - g.Root.Position).Magnitude
			local fromHome = (root.Position - g.Home).Magnitude
			if distance <= detect and fromHome <= g.Def.LeashRange and not Combat.IsKnocked(player) then
				local score = distance - (if TreasureService.GetCarrying(player) then 30 else 0)
				if score < bestScore then
					best, bestRoot, bestScore = player, root, score
				end
			end
		end
	end
	return best, bestRoot
end

-- A bat hit SLOWS a guardian for a moment (it never stops it cold): every walk speed goes
-- through here.
local function setSpeed(g: Guardian, speed: number)
	local slowed = os.clock() < (g.SlowUntil or 0)
	g.Humanoid.WalkSpeed = speed * (if slowed then GameConfig.Combat.GuardianSlow else 1)
end

local function setState(g: Guardian, state: string, target: Player?)
	if g.State ~= state or g.Target ~= target then
		if state == "Chase" and target and g.Target ~= target then
			Net.Fire("Feedback", target, { Type = "GuardianAlert", Name = g.Def.Name })
		end
		if g.State ~= state then
			local hunting = state == "Chase"
			local light = g.Model:FindFirstChild("EyeLight", true) :: PointLight?
			if light then
				light.Brightness = if hunting then 5 else 0.6
			end
			local aura = g.Root:FindFirstChild("RageAura") :: ParticleEmitter?
			if aura then
				aura.Enabled = hunting
			end
		end
		g.State = state
		g.Target = target
		g.Model:SetAttribute("State", state)
	end
end

-- Every walk goes through here: the goal is clamped to the guardian's Range, so it chases
-- you to the edge of its island (or its strip of glacier) and no further.
local function moveTo(g: Guardian, goal: Vector3)
	if g.Range then
		local offset = Vector3.new(goal.X - g.Home.X, 0, goal.Z - g.Home.Z)
		if offset.Magnitude > g.Range then
			goal = g.Home + offset.Unit * g.Range
		end
	end
	g.Humanoid:MoveTo(goal)
end

local function teleportHome(g: Guardian)
	local lift = g.Root.Size.Y / 2 + g.Humanoid.HipHeight + 0.5
	g.Model:PivotTo(CFrame.new(g.Home + Vector3.new(0, lift, 0)))
	g.Root.AssemblyLinearVelocity = Vector3.zero
	g.StuckSince = nil
	g.LastPos = g.Root.Position
	setState(g, "Patrol", nil)
	g.NextPatrolAt = 0
end

-- Keeps every guardian working: one that fell (a crevasse, off an island, through the map)
-- is put back home, and one stuck on a rock for a while hops, then is put back home.
local function recover(g: Guardian, now: number): boolean
	local position = g.Root.Position
	-- (30: well below any slope a patrol walks down; a crevasse floor or the sea is further.)
	if position.Y < g.Home.Y - 30 then
		teleportHome(g)
		return true
	end
	local moved = (position - g.LastPos).Magnitude
	g.LastPos = position
	local goal = g.Humanoid.WalkToPoint
	local wants = Vector3.new(goal.X - position.X, 0, goal.Z - position.Z).Magnitude > 5 and g.State ~= "Stunned"
	if not wants or moved > 0.3 then
		g.StuckSince = nil
		return false
	end
	g.StuckSince = g.StuckSince or now
	local stuck = now - (g.StuckSince :: number)
	if stuck > 1.5 then
		g.Humanoid.Jump = true
	end
	if stuck > 8 and g.State ~= "Chase" then
		teleportHome(g)
		return true
	end
	return false
end

local respawn

local function step(g: Guardian, now: number)
	if not g.Model.Parent or not g.Root.Parent then
		respawn(g)
		return
	end
	if recover(g, now) then
		return
	end
	if g.State == "Stunned" then
		if now < g.StateUntil then
			moveTo(g, g.Root.Position)
			return
		end
		setState(g, "Return", nil)
	end
	if g.State == "Return" and now < g.StateUntil then
		setSpeed(g, g.Def.PatrolSpeed * 1.4)
		moveTo(g, g.Home)
		return
	end

	-- A decoy duck in range is irresistible.
	local decoy = Decoys.Nearest(g.Root.Position, Gadgets.Get("decoy_duck").GuardianLureRange)
	if decoy and (decoy.Root.Position - g.Home).Magnitude <= g.Def.LeashRange then
		setState(g, "Chase", nil)
		setSpeed(g, g.Def.ChaseSpeed)
		moveTo(g, decoy.Root.Position)
		if (decoy.Root.Position - g.Root.Position).Magnitude <= g.Def.AttackRange + g.Root.Size.Z / 2 then
			decoy:Pop(nil)
			setState(g, "Return", nil)
			g.StateUntil = now + 2
		end
		return
	end

	local target, targetRoot = findTarget(g)
	if target and targetRoot then
		setState(g, "Chase", target)
		setSpeed(g, g.Def.ChaseSpeed * rage(g))
		moveTo(g, targetRoot.Position)
		local reach = g.Def.AttackRange + g.Root.Size.Z / 2
		if (targetRoot.Position - g.Root.Position).Magnitude <= reach and now - g.LastAttack >= g.Def.AttackCooldown then
			g.LastAttack = now
			-- Guardians throw, they don't hurt (Combat.ApplyHit); rage makes them throw harder.
			local result = Combat.ApplyHit(target, { Guardian = g.Type, Area = Zones.AreaId(g.Home), From = g.Root.Position, Knockback = (g.Def.Knockback or 1) * rage(g) })
			Net.FireAll("Feedback", { Type = "GuardianAttack", Position = g.Root.Position })
			if result ~= "Ignored" then
				-- Back off after a throw: the victim gets a fair chance to get up / reclaim.
				setState(g, "Return", nil)
				g.StateUntil = now + g.Def.RetreatAfterKnock
			end
		end
		return
	end

	local fromHome = (g.Root.Position - g.Home).Magnitude
	if fromHome > g.PatrolRadius + 10 then
		setState(g, "Return", nil)
		g.StateUntil = now + 1
		setSpeed(g, g.Def.PatrolSpeed * 1.4)
		moveTo(g, g.Home)
		return
	end
	setState(g, "Patrol", nil)
	setSpeed(g, g.Def.PatrolSpeed)
	if now >= g.NextPatrolAt then
		g.NextPatrolAt = now + rng:NextNumber(3, 7)
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, g.PatrolRadius)
		moveTo(g, g.Home + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
	end
end

local function tryHitGuardian(attacker: Player, attackerRoot: BasePart): boolean
	local look = attackerRoot.CFrame.LookVector
	for _, g in guardians do
		local offset = g.Root.Position - attackerRoot.Position
		local reach = GameConfig.Combat.AttackRange + g.Root.Size.Z / 2
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if offset.Magnitude <= reach and (flat.Magnitude < 0.1 or look:Dot(flat.Unit) >= GameConfig.Combat.AttackArcDot) then
			-- Slowed, not stunned: it keeps coming, just at a crawl for a moment.
			g.SlowUntil = os.clock() + GameConfig.Combat.GuardianSlowDuration
			g.Model:SetAttribute("SlowedUntil", workspace:GetServerTimeNow() + GameConfig.Combat.GuardianSlowDuration)
			setSpeed(g, g.Humanoid.WalkSpeed)
			Net.Fire("Feedback", attacker, { Type = "HitConfirm", Result = "Guardian" })
			return true
		end
	end
	return false
end

local folder: Folder

local function spawnBody(g: Guardian)
	local model, root, humanoid = build(g.Type, g.Def, g.Home)
	model.Parent = folder
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	g.Model, g.Root, g.Humanoid = model, root, humanoid
	g.LastPos = root.Position
	g.StuckSince = nil
	g.State = "Patrol"
	g.Target = nil
	g.NextPatrolAt = 0
end

-- Lost entirely (fell below the world and was destroyed): build it again at home.
function respawn(g: Guardian)
	if g.Model then
		g.Model:Destroy()
	end
	spawnBody(g)
end

function GuardianService.Init(spawns)
	folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace
	for _, spawnInfo in spawns do
		local def = Guardians[spawnInfo.Type]
		if def then
			local g = {
				Type = spawnInfo.Type,
				Def = def,
				Home = spawnInfo.Position,
				PatrolRadius = spawnInfo.PatrolRadius or 30,
				Range = spawnInfo.Range,
				Spawn = spawnInfo,
				State = "Patrol",
				Target = nil,
				NextPatrolAt = 0,
				LastAttack = 0,
				StateUntil = 0,
			} :: any
			spawnBody(g)
			table.insert(guardians, g)
		end
	end
	Combat.TryHitGuardian = tryHitGuardian
end

function GuardianService.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, g in guardians do
				local ok, err = pcall(step, g, now)
				if not ok then
					warn("[Guardian] step error:", err)
				end
			end
		end
	end)
end

return GuardianService
