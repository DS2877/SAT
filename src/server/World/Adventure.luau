-- Adventure layer on top of the island:
--   * GLOWSHROOM MARSH dressing: bog pools (swim-slow water), lily pads, boardwalks, glow lamps
--   * FROSTPEAK dressing: frozen-lake markers, snowmen, blue lanterns
--   * BOOST PADS along every trail: step on one for a burst of speed (server: BoostService)
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

local BOOST = Color3.fromRGB(60, 230, 255)

local function buildBoostPad(parent: Instance, ground: Vector3, forward: Vector3)
	local pad = folder("BoostPad", parent)
	local cf = CFrame.lookAt(ground, ground + Vector3.new(forward.X, 0, forward.Z))
	local base = part({ Name = "BoostBase", Size = Vector3.new(8, 0.5, 10), CFrame = cf * CFrame.new(0, 0.15, 0), Color = Color3.fromRGB(26, 32, 48), Material = Enum.Material.Slate, Parent = pad })
	for _, x in { -3.85, 3.85 } do
		part({ Name = "BoostRail", Size = Vector3.new(0.3, 0.15, 10), CFrame = cf * CFrame.new(x, 0.45, 0), Color = BOOST, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = pad })
	end
	-- Three chevrons ( > ) pointing along the trail; the client lights them in sequence.
	for i = 1, 3 do
		local z = 3 - (i - 1) * 3
		for _, side in { -1, 1 } do
			local chevron = part({
				Name = "BoostChevron",
				Size = Vector3.new(0.6, 0.12, 3.2),
				CFrame = cf * CFrame.new(side * 1.05, 0.45, z) * CFrame.Angles(0, math.rad(side * 38), 0),
				Color = BOOST,
				Material = Enum.Material.Neon,
				Transparency = 0.35,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = pad,
			})
			chevron:SetAttribute("Index", i)
			CollectionService:AddTag(chevron, "BoostChevron")
		end
	end
	-- Arch over the pad.
	for _, x in { -4.4, 4.4 } do
		part({ Name = "ArchPost", Size = Vector3.new(0.6, 6, 0.6), CFrame = cf * CFrame.new(x, 3, 3.5), Color = Color3.fromRGB(40, 46, 70), Material = Enum.Material.Metal, CanCollide = false, Parent = pad })
	end
	part({ Name = "ArchTop", Size = Vector3.new(9.4, 0.5, 0.6), CFrame = cf * CFrame.new(0, 6, 3.5), Color = BOOST, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = pad })
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(BOOST)
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.4, 0)
	sparks.Lifetime = NumberRange.new(0.6, 1)
	sparks.Rate = 10
	sparks.Speed = NumberRange.new(3, 6)
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.SpreadAngle = Vector2.new(20, 20)
	sparks.Parent = base
	light(base, BOOST, 14, 1.2)
	CollectionService:AddTag(base, "BoostPad")
	return { Position = ground, Forward = Vector3.new(forward.X, 0, forward.Z).Unit }
end

-- Drops boost pads every PadSpacing studs along each trail (outside the District and away
-- from water / bridges), plus a few hand-placed ones.
local function buildBoostPads(parent: Instance, trails, groundAt, avoid)
	local cfg = GameConfig.Boost
	local folderPads = folder("BoostPads", parent)
	local pads = {}
	for _, trail in trails do
		local delta = Vector3.new(trail[2].X - trail[1].X, 0, trail[2].Z - trail[1].Z)
		local unit = delta.Unit
		for d = cfg.FirstPadDistance, delta.Magnitude - 25, cfg.PadSpacing do
			local p = trail[1] + unit * d
			local nearBridge = (Vector2.new(p.X, p.Z) - Vector2.new(120, 10)).Magnitude < 22
			if not Zones.InSafeZone(p) and not nearBridge then
				local ground = groundAt(p.X, p.Z)
				if ground.Y > 5 then
					table.insert(pads, buildBoostPad(folderPads, ground, unit))
					table.insert(avoid, { Vector2.new(p.X, p.Z), 9 })
				end
			end
		end
	end
	return pads
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

-- Returns { Avoid = {...}, BoostPads = { { Position, Forward } } }.
function Adventure.Build(terrain: Terrain, parent: Instance, rng: Random, groundAt, trails)
	local root = folder("Adventure", parent)
	local avoid = {}
	buildMarsh(terrain, root, rng, avoid)
	buildFrost(root, rng, avoid, groundAt)
	local pads = buildBoostPads(root, trails, groundAt, avoid)
	for _, info in WorldLayout.LaunchPads do
		buildGeyser(root, info, groundAt, avoid)
	end
	return { Avoid = avoid, BoostPads = pads }
end

return Adventure
