-- Makes the island feel alive. Everything here is local, decorative and cheap:
--   * birds: flocks wheel over the island by day (seagulls over the coast), gone at night
--   * fireflies drift around the District gardens, groves and the waterfall at night
--   * butterflies / pollen flutter around flower beds by day (tag "Flowerbed")
--   * leaves drift down in the Wilds groves
--   * street lamps (tag "NightLamp") glow and cast light only after dusk
--   * now and then a fish jumps out of the sea near you
--   * Rimeheart's aurora (tag "Aurora") brightens at night
-- Day/night comes from the shared DayNight clock (server time).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local WorldLayout = require(Shared.Config.WorldLayout)
local DayNight = require(Shared.Logic.DayNight)

local Sounds = require(script.Parent.Parent.UI.Sounds)

local WorldLife = {}

local player = Players.LocalPlayer
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local folder: Folder

-- 0 = full day, 1 = full night (smooth around dusk/dawn), same curve as Ambience.
local function nightFactor(): number
	local clock = DayNight.State(workspace:GetServerTimeNow()).ClockTime
	local t = math.clamp((math.abs(clock - 12.5) - 5) / 1.5, 0, 1)
	return t * t * (3 - 2 * t)
end

local function decoPart(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = props.Parent or folder
	return p
end

-- BIRDS ---------------------------------------------------------------------------------------

type Bird = { Body: Part, WingL: Part, WingR: Part, Phase: number, Offset: Vector3 }
type Flock = { Center: Vector3, Radius: number, Speed: number, Angle: number, Birds: { Bird } }

local flocks: { Flock } = {}

local function makeBird(color: Color3, scale: number): Bird
	local body = decoPart({ Name = "Bird", Size = Vector3.new(0.5, 0.45, 1.3) * scale, Color = color, Material = Enum.Material.SmoothPlastic })
	local wingL = decoPart({ Name = "Wing", Size = Vector3.new(1.4, 0.08, 0.7) * scale, Color = color, Material = Enum.Material.SmoothPlastic })
	local wingR = decoPart({ Name = "Wing", Size = Vector3.new(1.4, 0.08, 0.7) * scale, Color = color, Material = Enum.Material.SmoothPlastic })
	return { Body = body, WingL = wingL, WingR = wingR, Phase = math.random() * 6, Offset = Vector3.zero }
end

local function addFlock(center: Vector3, radius: number, count: number, color: Color3, scale: number)
	local flock: Flock = { Center = center, Radius = radius, Speed = 0.12 + math.random() * 0.08, Angle = math.random() * 6.28, Birds = {} }
	for i = 1, count do
		local bird = makeBird(color, scale)
		bird.Offset = Vector3.new((math.random() - 0.5) * 8, (math.random() - 0.5) * 4, -i * 2.5)
		table.insert(flock.Birds, bird)
	end
	table.insert(flocks, flock)
end

local function updateBirds(dt: number, visible: boolean)
	for _, flock in flocks do
		flock.Angle += dt * flock.Speed
		local a = flock.Angle
		local pos = flock.Center + Vector3.new(math.cos(a) * flock.Radius, math.sin(a * 2.3) * 4, math.sin(a) * flock.Radius)
		-- Tangent of the circle = flight direction.
		local ahead = flock.Center + Vector3.new(math.cos(a + 0.05) * flock.Radius, math.sin((a + 0.05) * 2.3) * 4, math.sin(a + 0.05) * flock.Radius)
		local heading = CFrame.lookAt(pos, ahead)
		for _, bird in flock.Birds do
			local transparency = if visible then 0 else 1
			bird.Body.Transparency = transparency
			bird.WingL.Transparency = transparency
			bird.WingR.Transparency = transparency
			if visible then
				bird.Phase += dt * 9
				local flap = math.sin(bird.Phase) * 0.7
				local cf = heading * CFrame.new(bird.Offset)
				local half = bird.WingL.Size.X / 2
				bird.Body.CFrame = cf
				bird.WingL.CFrame = cf * CFrame.Angles(0, 0, flap) * CFrame.new(-half, 0, 0)
				bird.WingR.CFrame = cf * CFrame.Angles(0, 0, -flap) * CFrame.new(half, 0, 0)
			end
		end
	end
end

-- PARTICLE AMBIENCE -----------------------------------------------------------------------------

local fireflies: { ParticleEmitter } = {}
local butterflies: { ParticleEmitter } = {}

local function emitterAt(position: Vector3, size: Vector3, props): ParticleEmitter
	local anchor = decoPart({ Name = "AmbienceArea", Size = size, CFrame = CFrame.new(position), Transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = SPARKLE
	emitter.LightInfluence = 0
	emitter.Shape = Enum.ParticleEmitterShape.Box
	emitter.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	for key, value in props do
		(emitter :: any)[key] = value
	end
	emitter.Parent = anchor
	return emitter
end

local function addFireflies(position: Vector3, spread: number)
	table.insert(
		fireflies,
		emitterAt(position, Vector3.new(spread, 6, spread), {
			Color = ColorSequence.new(Color3.fromRGB(210, 255, 120)),
			LightEmission = 1,
			Size = NumberSequence.new(0.35),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.3, 0.1),
				NumberSequenceKeypoint.new(0.6, 0.7),
				NumberSequenceKeypoint.new(0.8, 0.1),
				NumberSequenceKeypoint.new(1, 1),
			}),
			Lifetime = NumberRange.new(4, 7),
			Rate = 0,
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Acceleration = Vector3.new(0, 0.15, 0),
		})
	)
end

local function addButterflies(position: Vector3)
	local colors = { Color3.fromRGB(255, 190, 90), Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 200, 255), Color3.fromRGB(255, 150, 200) }
	table.insert(
		butterflies,
		emitterAt(position, Vector3.new(6, 2, 6), {
			Color = ColorSequence.new(colors[math.random(1, #colors)]),
			LightEmission = 0.3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(0.5, 0.45), NumberSequenceKeypoint.new(1, 0.25) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0), NumberSequenceKeypoint.new(0.8, 0), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(3, 5),
			Rate = 0,
			Speed = NumberRange.new(0.8, 1.6),
			SpreadAngle = Vector2.new(180, 60),
			RotSpeed = NumberRange.new(-200, 200),
			Acceleration = Vector3.new(0, 0.2, 0),
		})
	)
end

local function addLeaves(position: Vector3)
	emitterAt(position, Vector3.new(60, 2, 60), {
		Color = ColorSequence.new(Color3.fromRGB(150, 170, 70), Color3.fromRGB(190, 140, 60)),
		LightEmission = 0,
		LightInfluence = 1,
		Size = NumberSequence.new(0.35),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.1), NumberSequenceKeypoint.new(0.85, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Lifetime = NumberRange.new(6, 9),
		Rate = 3,
		Speed = NumberRange.new(0.5, 1.5),
		SpreadAngle = Vector2.new(60, 60),
		Rotation = NumberRange.new(0, 360),
		RotSpeed = NumberRange.new(-90, 90),
		Acceleration = Vector3.new(0.6, -1.4, 0.3),
		Drag = 0.8,
	})
end

-- LAMPS --------------------------------------------------------------------------------------------

local function applyLamp(bulb: Instance, lit: boolean)
	if not bulb:IsA("BasePart") then
		return
	end
	bulb.Material = if lit then Enum.Material.Neon else Enum.Material.Glass
	bulb.Transparency = if lit then 0 else 0.3
	local light = bulb:FindFirstChildOfClass("PointLight")
	if light then
		light.Enabled = lit
	end
end

-- FISH -------------------------------------------------------------------------------------------

local function jumpFish()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	-- Look for open water a little way out from the player.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { workspace.Terrain }
	for _ = 1, 4 do
		local angle = math.random() * math.pi * 2
		local distance = 25 + math.random() * 45
		local spot = root.Position + Vector3.new(math.cos(angle) * distance, 0, math.sin(angle) * distance)
		local hit = workspace:Raycast(Vector3.new(spot.X, 60, spot.Z), Vector3.new(0, -120, 0), params)
		if hit and hit.Material == Enum.Material.Water then
			local start = hit.Position
			local fish = decoPart({ Name = "Fish", Size = Vector3.new(0.5, 0.7, 1.6), Color = Color3.fromRGB(150, 190, 210), Material = Enum.Material.SmoothPlastic, Reflectance = 0.3, CFrame = CFrame.new(start) })
			local direction = Vector3.new(math.cos(angle + 1.6), 0, math.sin(angle + 1.6))
			local t0 = os.clock()
			local conn
			conn = RunService.Heartbeat:Connect(function()
				local t = (os.clock() - t0) / 0.9
				if t >= 1 then
					conn:Disconnect()
					fish:Destroy()
					Sounds.PlayAt("Splash", start + direction * 5)
					return
				end
				local pos = start + direction * (5 * t) + Vector3.new(0, 4 * math.sin(t * math.pi), 0)
				fish.CFrame = CFrame.lookAt(pos, pos + direction + Vector3.new(0, math.cos(t * math.pi) * 1.5, 0))
			end)
			Sounds.PlayAt("Splash", start)
			return
		end
	end
end

function WorldLife.Init()
	folder = Instance.new("Folder")
	folder.Name = "WorldLife"
	folder.Parent = workspace

	-- Flocks: songbirds over the Wilds and District, gulls over the coast.
	local district = WorldLayout.District.Center
	addFlock(district + Vector3.new(0, 55, 0), 70, 5, Color3.fromRGB(70, 60, 55), 1)
	addFlock(Vector3.new(0, 70, -80), 90, 4, Color3.fromRGB(60, 55, 50), 1)
	addFlock(WorldLayout.Temple.Center + Vector3.new(0, 80, 0), 60, 3, Color3.fromRGB(50, 45, 45), 1.2)
	addFlock(WorldLayout.Shipwreck.Center + Vector3.new(-40, 35, 0), 55, 5, Color3.fromRGB(245, 245, 245), 1.3)
	addFlock(WorldLayout.Waterfall.CliffCenter + Vector3.new(0, 70, 60), 50, 3, Color3.fromRGB(80, 70, 60), 1)

	-- Fireflies: District gardens, the Wilds groves, the waterfall pool.
	addFireflies(district + Vector3.new(0, 3, 0), 120)
	addFireflies(Vector3.new(-60, 14, -40), 90)
	addFireflies(Vector3.new(80, 14, -110), 90)
	addFireflies(Vector3.new(0, 14, -270), 70)

	-- Falling leaves over the groves.
	addLeaves(Vector3.new(-80, 40, -30))
	addLeaves(Vector3.new(90, 40, -120))
	addLeaves(Vector3.new(-40, 40, -170))

	-- Butterflies at flower beds (they stream in with the world).
	local function track(anchor: Instance)
		if anchor:IsA("BasePart") then
			addButterflies(anchor.Position)
		end
	end
	for _, anchor in CollectionService:GetTagged("Flowerbed") do
		track(anchor)
	end
	CollectionService:GetInstanceAddedSignal("Flowerbed"):Connect(track)

	local lampsLit: boolean? = nil
	CollectionService:GetInstanceAddedSignal("NightLamp"):Connect(function(bulb)
		if lampsLit ~= nil then
			applyLamp(bulb, lampsLit)
		end
	end)

	local accumulator = 0
	local nextFish = os.clock() + 8
	RunService.RenderStepped:Connect(function(dt)
		local night = nightFactor()
		updateBirds(dt, night < 0.5)
		accumulator += dt
		if accumulator < 0.5 then
			return
		end
		accumulator = 0
		for _, emitter in fireflies do
			emitter.Rate = 14 * night
		end
		for _, emitter in butterflies do
			emitter.Rate = 0.6 * (1 - night)
		end
		-- Rimeheart's aurora: a faint shimmer by day, bright curtains at night.
		for _, beam in CollectionService:GetTagged("Aurora") do
			if beam:IsA("Beam") then
				beam.Brightness = 0.5 + night * 2.5
			end
		end
		local lit = night > 0.35
		if lit ~= lampsLit then
			lampsLit = lit
			for _, bulb in CollectionService:GetTagged("NightLamp") do
				applyLamp(bulb, lit)
			end
		end
		if os.clock() >= nextFish then
			nextFish = os.clock() + 6 + math.random() * 8
			task.spawn(jumpFish)
		end
	end)
end

return WorldLife
