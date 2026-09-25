-- Adventure layer on top of the island:
--   * GLOWSHROOM MARSH dressing: bog pools (swim-slow water), lily pads, boardwalks, glow lamps
--   * FROSTPEAK dressing: frozen-lake markers, snowmen, blue lanterns
--   * BOOST RINGS scattered at random: run through one for a burst of speed (BoostService)
--   * LAUNCH GEYSERS that fling you onto high places (client: Controllers/Pads)
-- Runs after the terrain; returns positions the vegetation must keep clear of.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Config.WorldLayout)
local Zones = require(Shared.Util.Zones)

local Props = require(script.Parent.Props)

local Adventure = {}

local part, cylinder = Props.part, Props.cylinder

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

-- MARSH -------------------------------------------------------------------------------

-- Pools relative to the marsh centre: { dx, dz, radius }.
local POOLS = {
	{ -35, -20, 13 },
	{ 20, -45, 10 },
	{ 45, 5, 14 },
	{ -10, 30, 11 },
	{ -55, 25, 9 },
	{ 15, 60, 10 },
	{ 70, -35, 9 },
}

local function buildMarsh(terrain: Terrain, parent: Instance, rng: Random, avoid)
	local marsh = folder("GlowshroomMarsh", parent)
	local c = WorldLayout.Marsh.Center
	local pools = {}
	for _, p in POOLS do
		local center = Vector3.new(c.X + p[1], 10, c.Z + p[2])
		-- Carve a shallow bowl, then fill it with water (you swim = you're slow = you're prey).
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, 2, 0)), 8, p[3], Enum.Material.Air)
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -4, 0)), 4, p[3], Enum.Material.Water) -- surface at y = 8
		terrain:FillCylinder(CFrame.new(center + Vector3.new(0, -8, 0)), 4, p[3] + 2, Enum.Material.Mud)
		table.insert(pools, { Center = center, Radius = p[3] })
		table.insert(avoid, { Vector2.new(center.X, center.Z), p[3] + 4 })
		for _ = 1, math.floor(p[3] / 2.5) do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = rng:NextNumber(0, p[3] - 2)
			Props.LilyPad(marsh, center + Vector3.new(math.cos(a) * r, -1.9, math.sin(a) * r), rng)
		end
		Props.Reeds(marsh, center + Vector3.new(p[3] * 0.8, 0, 0), rng)
		Props.Reeds(marsh, center + Vector3.new(-p[3] * 0.7, 0, p[3] * 0.3), rng)
	end
	-- Boardwalks across the bog (the fast way through - and a PvP chokepoint).
	local walks = {
		{ Vector3.new(c.X - 90, 10.3, c.Z - 60), Vector3.new(c.X - 5, 10.3, c.Z - 10) },
		{ Vector3.new(c.X - 5, 10.3, c.Z - 10), Vector3.new(c.X + 60, 10.3, c.Z + 20) },
		{ Vector3.new(c.X - 5, 10.3, c.Z - 10), Vector3.new(c.X - 20, 10.3, c.Z + 70) },
	}
	for _, w in walks do
		Props.Boardwalk(marsh, w[1], w[2], 5)
		local delta = w[2] - w[1]
		for d = 0, delta.Magnitude, 8 do
			local p = w[1] + delta.Unit * d
			table.insert(avoid, { Vector2.new(p.X, p.Z), 5 })
		end
	end
	-- Glowing lanterns on poles along the boardwalks.
	for _, w in walks do
		for t = 0.2, 0.8, 0.3 do
			local p = w[1]:Lerp(w[2], t) + Vector3.new(3.2, 0, 0)
			part({ Name = "LampPole", Size = Vector3.new(0.4, 7, 0.4), CFrame = CFrame.new(p + Vector3.new(0, 3.5, 0)), Color = Color3.fromRGB(70, 55, 40), Material = Enum.Material.Wood, Parent = marsh })
			local lamp = part({ Name = "GlowLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(p + Vector3.new(0, 7.2, 0)), Color = Color3.fromRGB(200, 120, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = marsh })
			light(lamp, Color3.fromRGB(200, 130, 255), 18, 1.2)
		end
	end
	-- Floating spores in the air.
	local sporeAnchor = part({ Name = "Spores", Size = Vector3.new(180, 1, 180), CFrame = CFrame.new(c + Vector3.new(0, 14, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = marsh })
	local spores = Instance.new("ParticleEmitter")
	spores.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	spores.Color = ColorSequence.new(Color3.fromRGB(210, 150, 255), Color3.fromRGB(140, 255, 200))
	spores.LightEmission = 1
	spores.Size = NumberSequence.new(0.35, 0)
	spores.Lifetime = NumberRange.new(4, 7)
	spores.Rate = 25
	spores.Speed = NumberRange.new(0.3, 1)
	spores.SpreadAngle = Vector2.new(180, 180)
	spores.Shape = Enum.ParticleEmitterShape.Box
	spores.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	spores.Parent = sporeAnchor
	return pools
end

-- FROSTPEAK ---------------------------------------------------------------------------

local function buildFrost(parent: Instance, rng: Random, avoid, groundAt)
	local frost = folder("Frostpeak", parent)
	local lake = WorldLayout.Frostpeak.Center
	table.insert(avoid, { Vector2.new(lake.X, lake.Z), WorldLayout.Frostpeak.LakeRadius + 6 })
	-- Blue lanterns around the frozen lake.
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local p = groundAt(lake.X + math.cos(a) * (WorldLayout.Frostpeak.LakeRadius + 4), lake.Z + math.sin(a) * (WorldLayout.Frostpeak.LakeRadius + 4))
		part({ Name = "LanternPost", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(60, 70, 90), Material = Enum.Material.Metal, Parent = frost })
		local lantern = part({ Name = "IceLantern", Size = Vector3.new(1.2, 1.5, 1.2), CFrame = CFrame.new(p + Vector3.new(0, 6.6, 0)), Color = Color3.fromRGB(120, 210, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = frost })
		light(lantern, Color3.fromRGB(140, 210, 255), 20, 1)
		table.insert(avoid, { Vector2.new(p.X, p.Z), 4 })
	end
	-- Snowmen (somebody got bored up here).
	for i = 1, 3 do
		local a = rng:NextNumber(0, math.pi * 2)
		local p = groundAt(lake.X + math.cos(a) * 60, lake.Z + math.sin(a) * 60)
		for k, size in { 4.2, 3.2, 2.3 } do
			part({ Name = "Snowman", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(p + Vector3.new(0, size / 2 + (k - 1) * 2.8, 0)), Color = Color3.fromRGB(245, 250, 255), Material = Enum.Material.Snow, Parent = frost })
		end
		part({ Name = "Nose", Class = "WedgePart", Size = Vector3.new(0.4, 0.4, 1.4), CFrame = CFrame.lookAt(p + Vector3.new(0, 7.6, 0), p + Vector3.new(0, 7.6, 0) + Vector3.new(math.cos(a + i), 0, math.sin(a + i))) * CFrame.new(0, 0, -1.4), Color = Color3.fromRGB(255, 140, 40), CanCollide = false, Parent = frost })
		table.insert(avoid, { Vector2.new(p.X, p.Z), 6 })
	end
	-- Snowfall over the region.
	local c = WorldLayout.Frostpeak.Center
	local snowAnchor = part({ Name = "Snowfall", Size = Vector3.new(240, 1, 240), CFrame = CFrame.new(c + Vector3.new(0, 70, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = frost })
	local snow = Instance.new("ParticleEmitter")
	snow.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	snow.Color = ColorSequence.new(Color3.new(1, 1, 1))
	snow.Size = NumberSequence.new(0.35)
	snow.Lifetime = NumberRange.new(8, 12)
	snow.Rate = 60
	snow.Speed = NumberRange.new(5, 8)
	snow.EmissionDirection = Enum.NormalId.Bottom
	snow.SpreadAngle = Vector2.new(15, 15)
	snow.Acceleration = Vector3.new(1.5, 0, 0.5)
	snow.Shape = Enum.ParticleEmitterShape.Box
	snow.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	snow.Parent = snowAnchor
end

-- BOOST PADS --------------------------------------------------------------------------

local BOOST = Color3.fromRGB(40, 170, 255) -- electric blue hoop
local BOOST_GOLD = Color3.fromRGB(255, 215, 60) -- golden inner ring
local RING_RADIUS = 4.6 -- hoop radius (studs); the trigger radius is GameConfig.Boost.Radius
local RING_HEIGHT = 5.4 -- hoop centre above the ground

-- A circle of `count` bricks in the hoop's local XY plane.
local function hoop(model: Model, centre: CFrame, radius: number, count: number, thickness: number, color: Color3, name: string)
	local segment = 2 * math.pi * radius / count * 1.08
	for i = 1, count do
		local angle = (i - 0.5) / count * 2 * math.pi
		part({
			Name = name,
			Size = Vector3.new(segment, thickness, thickness),
			CFrame = centre * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = model,
		})
	end
end

-- Sonic-style BOOST RING: a floating, spinning blue-and-gold hoop over a round glowing launch
-- plate. Run through it from any side. The client spins it (tag "BoostRing") and bursts it
-- when you take it.
local function buildBoostRing(parent: Instance, ground: Vector3, rng: Random)
	local model = Instance.new("Model")
	model.Name = "BoostRing"
	local centre = CFrame.new(ground + Vector3.new(0, RING_HEIGHT, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
	local core = part({
		Name = "Core",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = centre,
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = model,
	})
	model.PrimaryPart = core
	hoop(model, centre, RING_RADIUS, 16, 0.75, BOOST, "Hoop")
	hoop(model, centre, RING_RADIUS - 0.75, 12, 0.35, BOOST_GOLD, "Inner")
	-- Faint portal film inside the hoop.
	part({
		Name = "Film",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.1, (RING_RADIUS - 0.9) * 2, (RING_RADIUS - 0.9) * 2),
		CFrame = centre * CFrame.Angles(0, math.rad(90), 0),
		Color = BOOST,
		Material = Enum.Material.ForceField,
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = model,
	})
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Name = "Sparkle"
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(BOOST, BOOST_GOLD)
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Size = NumberSequence.new(0.5, 0)
	sparkle.Lifetime = NumberRange.new(0.5, 0.9)
	sparkle.Rate = 5
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = core
	local burst = sparkle:Clone()
	burst.Name = "Burst" -- emitted by the client when the ring is taken
	burst.Rate = 0
	burst.Size = NumberSequence.new(1.1, 0)
	burst.Speed = NumberRange.new(14, 26)
	burst.Lifetime = NumberRange.new(0.4, 0.7)
	burst.Parent = core
	-- No PointLight: two dozen of them cost phones a lot; the neon hoop glows on its own.

	-- Round launch plate on the ground.
	local plateCf = CFrame.new(ground) * CFrame.Angles(0, 0, math.rad(90))
	part({ Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 10, 10), CFrame = plateCf * CFrame.new(0.15, 0, 0), Color = Color3.fromRGB(22, 28, 46), Material = Enum.Material.Slate, Parent = model })
	part({ Name = "PlateRim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.42, 10.6, 10.6), CFrame = plateCf * CFrame.new(0.1, 0, 0), Color = BOOST, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = model })
	part({ Name = "PlateGlow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.45, 5, 5), CFrame = plateCf * CFrame.new(0.15, 0, 0), Color = BOOST_GOLD, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = model })

	model:SetAttribute("Home", centre)
	model.Parent = parent
	CollectionService:AddTag(model, "BoostRing")
	return { Position = ground }
end

local SURFACE_PARAMS = RaycastParams.new()
SURFACE_PARAMS.IgnoreWater = false

-- Open, flat, dry TERRAIN at (x, z) (not a roof, not water, not a cliff face), or nil.
local function openGround(x: number, z: number): Vector3?
	local centre = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -360, 0), SURFACE_PARAMS)
	if not centre or not centre.Instance:IsA("Terrain") or centre.Material == Enum.Material.Water or centre.Position.Y < 6 then
		return nil
	end
	for _, offset in { Vector2.new(6, 0), Vector2.new(-6, 0), Vector2.new(0, 6), Vector2.new(0, -6) } do
		local hit = workspace:Raycast(Vector3.new(x + offset.X, 300, z + offset.Y), Vector3.new(0, -360, 0), SURFACE_PARAMS)
		if not hit or not hit.Instance:IsA("Terrain") or math.abs(hit.Position.Y - centre.Position.Y) > 2.5 then
			return nil
		end
	end
	return centre.Position
end

-- One ring on the given ground spot (the Deep South places its own along the road).
function Adventure.BoostRingAt(parent: Instance, ground: Vector3, rng: Random)
	return buildBoostRing(parent, ground, rng)
end

-- Returns { { Position } } for BoostService.
-- Scatters boost rings at RANDOM spots over the Wilds - a new layout every server - spread
-- across every region and kept apart from each other and from landmarks.
function Adventure.BuildBoostRings(parent: Instance, avoid)
	local cfg = GameConfig.Boost
	local rng = Random.new()
	local folderRings = folder("BoostRings", parent)
	local rings = {}
	local perArea: { [string]: number } = {}
	local districtCentre = WorldLayout.District.Center
	for _ = 1, cfg.Count * 80 do
		if #rings >= cfg.Count then
			break
		end
		local angle = rng:NextNumber(0, 2 * math.pi)
		local distance = math.sqrt(rng:NextNumber()) * cfg.MaxDistance
		local x, z = math.cos(angle) * distance, math.sin(angle) * distance
		local flat = Vector2.new(x, z)
		local probe = Vector3.new(x, 10, z)
		local area = Zones.AreaId(probe)
		local ok = (flat - Vector2.new(districtCentre.X, districtCentre.Z)).Magnitude > GameConfig.SafeZone.Radius + 20
			and (perArea[area] or 0) < cfg.MaxPerArea
		if ok then
			for _, ring in rings do
				if (Vector2.new(ring.Position.X, ring.Position.Z) - flat).Magnitude < cfg.MinSpacing then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, entry in avoid do
				if (entry[1] - flat).Magnitude < entry[2] + 8 then
					ok = false
					break
				end
			end
		end
		local ground = if ok then openGround(x, z) else nil
		if ground then
			perArea[area] = (perArea[area] or 0) + 1
			table.insert(rings, buildBoostRing(folderRings, ground, rng))
			table.insert(avoid, { flat, 9 })
		end
	end
	if #rings < cfg.Count then
		warn(("[Adventure] placed %d of %d boost rings"):format(#rings, cfg.Count))
	end
	return rings
end

-- LAUNCH GEYSERS ----------------------------------------------------------------------

local function buildGeyser(parent: Instance, info, groundAt, avoid)
	local geyser = folder("Geyser_" .. info.Name, parent)
	local ground = groundAt(info.Position.X, info.Position.Z)
	local color = Color3.fromRGB(info.Color[1], info.Color[2], info.Color[3])
	cylinder(ground + Vector3.new(0, 0.5, 0), 1, 9, { Name = "GeyserRim", Color = Color3.fromRGB(90, 86, 96), Material = Enum.Material.Slate, Parent = geyser })
	local core = cylinder(ground + Vector3.new(0, 1.05, 0), 0.1, 6.5, { Name = "GeyserCore", Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = geyser })
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		part({ Name = "GeyserStone", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 1.6, 2.2), CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * 5, 0.6, math.sin(a) * 5)), Color = Color3.fromRGB(110, 104, 112), Material = Enum.Material.Slate, Parent = geyser })
	end
	local steam = Instance.new("ParticleEmitter")
	steam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	steam.Color = ColorSequence.new(Color3.new(1, 1, 1), color)
	steam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	steam.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.5), NumberSequenceKeypoint.new(1, 7) })
	steam.Lifetime = NumberRange.new(1.5, 2.5)
	steam.Rate = 14
	steam.Speed = NumberRange.new(10, 16)
	steam.SpreadAngle = Vector2.new(8, 8)
	steam.EmissionDirection = Enum.NormalId.Right -- the cylinder is rotated: +X is up
	steam.Parent = core
	light(core, color, 16, 1.4)
	core:SetAttribute("Target", info.Target)
	core:SetAttribute("RequiredAscension", info.RequiredAscension or 0) -- the Starfall launch
	CollectionService:AddTag(core, "LaunchPad")
	-- A little sign so players know it's a ride, not a hazard.
	local signPart = part({ Name = "GeyserSign", Size = Vector3.new(0.5, 0.5, 0.5), CFrame = CFrame.new(ground + Vector3.new(0, 5, 0)), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = geyser })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(10, 1.8)
	gui.MaxDistance = 70
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = "⬆ " .. info.Name:upper()
	label.Parent = gui
	gui.Parent = signPart
	table.insert(avoid, { Vector2.new(ground.X, ground.Z), 10 })
end

-- Returns { Avoid = {...} }. The boost rings are placed last (Adventure.BuildBoostRings), once
-- everything else stands, so they land in open clearings.
function Adventure.Build(terrain: Terrain, parent: Instance, rng: Random, groundAt)
	local root = folder("Adventure", parent)
	local avoid = {}
	buildMarsh(terrain, root, rng, avoid)
	buildFrost(root, rng, avoid, groundAt)
	for _, info in WorldLayout.LaunchPads do
		buildGeyser(root, info, groundAt, avoid)
	end
	return { Avoid = avoid }
end

return Adventure
