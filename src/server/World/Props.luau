-- Procedural prop library: vegetation, rocks and settlement dressing built from primitives.
-- Everything is anchored; decorative leaves/flowers are non-colliding and non-queryable so they
-- never block raycasts (treasure spawns, grapple aim) or snag players.

local CollectionService = game:GetService("CollectionService")

local Props = {}

-- Tags read by the client WorldLife controller: "NightLamp" (lamp glass that lights up at
-- night) and "Flowerbed" (invisible anchor where butterflies flutter by day).

Props.DefaultParent = workspace :: Instance

function Props.part(props): BasePart
	local p: BasePart = if props.Class then Instance.new(props.Class) :: BasePart else Instance.new("Part")
	if props.Shape then
		(p :: Part).Shape = props.Shape
	end
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or Color3.fromRGB(200, 190, 170)
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.CanQuery = if props.CanQuery == nil then true else props.CanQuery
	p.CanTouch = false
	p.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Parent = props.Parent or Props.DefaultParent
	return p
end

-- Upright cylinder (Roblox cylinders run along X).
function Props.cylinder(position: Vector3, height: number, diameter: number, props): BasePart
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return Props.part(props)
end

local function decor(props)
	props.CanCollide = false
	props.CanQuery = false
	return Props.part(props)
end

local LEAF_GREENS = {
	Color3.fromRGB(76, 168, 72),
	Color3.fromRGB(58, 140, 64),
	Color3.fromRGB(98, 182, 70),
	Color3.fromRGB(46, 122, 70),
	Color3.fromRGB(120, 176, 60),
}

local function pick(rng: Random, list)
	return list[rng:NextInteger(1, #list)]
end

-- VEGETATION ------------------------------------------------------------------------

function Props.Broadleaf(parent: Instance, ground: Vector3, rng: Random)
	local height = rng:NextNumber(12, 20)
	local thickness = rng:NextNumber(2, 3)
	local trunkCf = CFrame.new(ground + Vector3.new(0, height / 2 - 0.5, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-4, 4)))
	Props.part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, thickness, thickness),
		CFrame = trunkCf * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(110, 76, 48),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	-- Root flare
	decor({
		Name = "Roots",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(thickness * 2, 1.4, thickness * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)),
		Color = Color3.fromRGB(100, 70, 45),
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local top = (trunkCf * CFrame.new(0, height / 2, 0)).Position
	local base = pick(rng, LEAF_GREENS)
	for i = 1, rng:NextInteger(4, 6) do
		local size = rng:NextNumber(8, 13)
		local offset = if i == 1
			then Vector3.new(0, 1.5, 0)
			else Vector3.new(rng:NextNumber(-5, 5), rng:NextNumber(-2.5, 2), rng:NextNumber(-5, 5))
		local shade = rng:NextNumber(-0.08, 0.08)
		decor({
			Name = "Canopy",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * rng:NextNumber(0.7, 0.9), size),
			CFrame = CFrame.new(top + offset),
			Color = Color3.new(
				math.clamp(base.R + shade, 0, 1),
				math.clamp(base.G + shade, 0, 1),
				math.clamp(base.B + shade * 0.5, 0, 1)
			),
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
end

function Props.Palm(parent: Instance, ground: Vector3, rng: Random)
	local segments = 6
	local segmentLength = rng:NextNumber(2.6, 3.4)
	local bend = math.rad(rng:NextNumber(4, 9))
	local cf = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	for i = 1, segments do
		cf = cf * CFrame.Angles(bend, 0, 0)
		local mid = cf * CFrame.new(0, segmentLength / 2, 0)
		Props.part({
			Name = "PalmTrunk",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(segmentLength + 0.3, 1.9 - i * 0.12, 1.9 - i * 0.12),
			CFrame = mid * CFrame.Angles(0, 0, math.rad(90)),
			Color = if i % 2 == 0 then Color3.fromRGB(170, 130, 85) else Color3.fromRGB(150, 112, 72),
			Material = Enum.Material.Wood,
			Parent = parent,
		})
		cf = cf * CFrame.new(0, segmentLength, 0)
	end
	local top = cf.Position
	for i = 0, 6 do
		local yaw = i / 7 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local frond = CFrame.new(top) * CFrame.Angles(0, yaw, 0)
		for k = 0, 1 do
			decor({
				Name = "Frond",
				Size = Vector3.new(2.4 - k * 0.7, 0.25, 4.6),
				CFrame = frond * CFrame.new(0, -k * 1.4, -2.2 - k * 4.2) * CFrame.Angles(math.rad(-10 - k * 26), 0, 0),
				Color = if k == 1 then Color3.fromRGB(90, 160, 60) else Color3.fromRGB(70, 150, 60),
				Material = Enum.Material.Grass,
				Parent = parent,
			})
		end
	end
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2
		decor({
			Name = "Coconut",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = CFrame.new(top + Vector3.new(math.cos(a) * 0.7, -0.8, math.sin(a) * 0.7)),
			Color = Color3.fromRGB(110, 80, 45),
			Parent = parent,
		})
	end
end

function Props.Bush(parent: Instance, ground: Vector3, rng: Random)
	local base = pick(rng, LEAF_GREENS)
	for _ = 1, rng:NextInteger(2, 4) do
		local size = rng:NextNumber(3, 5.5)
		decor({
			Name = "Bush",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.75, size),
			CFrame = CFrame.new(ground + Vector3.new(rng:NextNumber(-2, 2), size * 0.25, rng:NextNumber(-2, 2))),
			Color = base,
			Material = Enum.Material.Grass,
			Parent = parent,
		})
	end
	if rng:NextNumber() < 0.35 then
		local berry = if rng:NextNumber() < 0.5 then Color3.fromRGB(230, 60, 80) else Color3.fromRGB(255, 200, 60)
		for _ = 1, 4 do
			decor({
				Name = "Berry",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.5, 0.5, 0.5),
				CFrame = CFrame.new(ground + Vector3.new(rng:NextNumber(-2, 2), rng:NextNumber(1.5, 2.8), rng:NextNumber(-2, 2))),
				Color = berry,
				Parent = parent,
			})
		end
	end
end

local FLOWER_COLORS = {
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(255, 220, 80),
	Color3.fromRGB(170, 120, 255),
	Color3.fromRGB(255, 255, 255),
	Color3.fromRGB(255, 150, 70),
}

function Props.Flowers(parent: Instance, ground: Vector3, rng: Random, count: number?)
	local color = pick(rng, FLOWER_COLORS)
	local anchor = decor({
		Name = "FlowerbedAnchor",
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)),
		Transparency = 1,
		CastShadow = false,
		Parent = parent,
	})
	CollectionService:AddTag(anchor, "Flowerbed")
	for _ = 1, count or rng:NextInteger(5, 8) do
		-- Bloom only (terrain grass decoration provides the stems visually).
		local p = ground + Vector3.new(rng:NextNumber(-3, 3), 0, rng:NextNumber(-3, 3))
		decor({
			Name = "Bloom",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.7, 0.45, 0.7),
			CFrame = CFrame.new(p + Vector3.new(0, 0.7, 0)),
			Color = color,
			CastShadow = false,
			Parent = parent,
		})
	end
end

function Props.Rocks(parent: Instance, ground: Vector3, rng: Random)
	for i = 1, rng:NextInteger(2, 4) do
		local size = if i == 1 then rng:NextNumber(5, 10) else rng:NextNumber(2, 5)
		Props.part({
			Name = "Rock",
			Shape = if rng:NextNumber() < 0.6 then Enum.PartType.Ball else Enum.PartType.Block,
			Size = Vector3.new(size * 1.3, size * 0.8, size),
			CFrame = CFrame.new(ground + Vector3.new(rng:NextNumber(-4, 4), size * 0.2, rng:NextNumber(-4, 4)))
				* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6.28), rng:NextNumber(-0.3, 0.3)),
			Color = if rng:NextNumber() < 0.3 then Color3.fromRGB(110, 130, 95) else Color3.fromRGB(128, 122, 114),
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
end

-- BIOME VEGETATION --------------------------------------------------------------------
-- Each region has its own flora so the island reads as distinct places: Wilds = meadow
-- (Broadleaf, Bush, Flowers), Ruins = desert (Cactus, DeadTree, Bones), Coast = storm shore
-- (Palm, DuneGrass, Driftwood), Falls = jungle (JungleTree, Fern, GiantMushroom).

-- A block stretched between two points (branches, bones, roots).
local function beam(a: Vector3, b: Vector3, thickness: number, props)
	props.Size = Vector3.new(thickness, thickness, (b - a).Magnitude)
	props.CFrame = CFrame.lookAt((a + b) / 2, b)
	return Props.part(props)
end

function Props.Cactus(parent: Instance, ground: Vector3, rng: Random)
	local green = Color3.fromRGB(72, 140, 76):Lerp(Color3.fromRGB(110, 150, 70), rng:NextNumber())
	local height = rng:NextNumber(7, 13)
	Props.cylinder(ground + Vector3.new(0, height / 2, 0), height, 2.2, { Name = "Cactus", Color = green, Material = Enum.Material.Grass, Parent = parent })
	decor({ Name = "CactusTop", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), CFrame = CFrame.new(ground + Vector3.new(0, height, 0)), Color = green, Material = Enum.Material.Grass, Parent = parent })
	for i = 1, rng:NextInteger(1, 2) do
		local side = if i == 1 then 1 else -1
		local yaw = CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
		local armY = rng:NextNumber(height * 0.35, height * 0.6)
		local out = (yaw * CFrame.new(side * 2.2, 0, 0)).Position
		decor({ Name = "CactusArm", Size = Vector3.new(2.6, 1.5, 1.5), CFrame = CFrame.new(ground + Vector3.new(0, armY, 0) + out / 2) * yaw, Color = green, Material = Enum.Material.Grass, Parent = parent })
		local up = rng:NextNumber(2.5, 4)
		decor({ Name = "CactusArm", Shape = Enum.PartType.Cylinder, Size = Vector3.new(up, 1.5, 1.5), CFrame = CFrame.new(ground + Vector3.new(0, armY + up / 2, 0) + out) * CFrame.Angles(0, 0, math.rad(90)), Color = green, Material = Enum.Material.Grass, Parent = parent })
		if rng:NextNumber() < 0.5 then
			decor({ Name = "Blossom", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.6, 0.9), CFrame = CFrame.new(ground + Vector3.new(0, armY + up + 0.3, 0) + out), Color = Color3.fromRGB(255, 90, 150), Parent = parent })
		end
	end
end

function Props.DeadTree(parent: Instance, ground: Vector3, rng: Random, color: Color3?)
	local bark = color or Color3.fromRGB(120, 100, 84)
	local height = rng:NextNumber(9, 15)
	local lean = CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-8, 8)))
	local base = CFrame.new(ground) * lean
	local top = (base * CFrame.new(0, height, 0)).Position
	beam(ground - Vector3.new(0, 0.5, 0), top, 1.5, { Name = "DeadTrunk", Color = bark, Material = Enum.Material.Wood, Parent = parent })
	for _ = 1, rng:NextInteger(3, 5) do
		local from = ground:Lerp(top, rng:NextNumber(0.45, 0.95))
		local yaw = rng:NextNumber(0, 6.28)
		local length = rng:NextNumber(3, 6)
		local to = from + Vector3.new(math.cos(yaw) * length, rng:NextNumber(1.5, 4), math.sin(yaw) * length)
		beam(from, to, 0.6, { Name = "Branch", Color = bark, Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, Parent = parent })
		local twig = to + Vector3.new(math.cos(yaw + 0.8) * 1.8, 1.4, math.sin(yaw + 0.8) * 1.8)
		beam(to, twig, 0.35, { Name = "Twig", Color = bark, Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, Parent = parent })
	end
end

-- Bleached bones of something huge: a rib cage half-buried in the sand, and a skull.
function Props.Bones(parent: Instance, ground: Vector3, rng: Random)
	local bone = Color3.fromRGB(236, 226, 200)
	local yaw = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
	local ribs = rng:NextInteger(4, 6)
	beam((yaw * CFrame.new(0, 0.4, -ribs * 1.1)).Position, (yaw * CFrame.new(0, 0.6, ribs * 1.1)).Position, 0.8, { Name = "Spine", Color = bone, Parent = parent })
	for i = 1, ribs do
		local z = (i - ribs / 2 - 0.5) * 2.1
		local size = 4.5 - math.abs(i - ribs / 2 - 0.5) * 0.5
		for _, side in { -1, 1 } do
			local root = (yaw * CFrame.new(0, 0.6, z)).Position
			local mid = (yaw * CFrame.new(side * size * 0.7, size * 0.9, z)).Position
			local tip = (yaw * CFrame.new(side * size * 0.9, -0.2, z)).Position
			beam(root, mid, 0.45, { Name = "Rib", Color = bone, CanCollide = false, CanQuery = false, Parent = parent })
			beam(mid, tip, 0.4, { Name = "Rib", Color = bone, CanCollide = false, CanQuery = false, Parent = parent })
		end
	end
	local skull = yaw * CFrame.new(0, 1.1, -ribs * 1.1 - 2.4)
	Props.part({ Name = "Skull", Size = Vector3.new(2.6, 2, 3.4), CFrame = skull, Color = bone, Parent = parent })
	for _, x in { -0.6, 0.6 } do
		decor({ Name = "EyeSocket", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 0.8, 0.4), CFrame = skull * CFrame.new(x, 0.3, -1.6), Color = Color3.fromRGB(30, 26, 24), Parent = parent })
		beam((skull * CFrame.new(x * 1.6, 0.8, 0)).Position, (skull * CFrame.new(x * 3.2, 2.6, 1.2)).Position, 0.5, { Name = "Horn", Color = bone, CanCollide = false, CanQuery = false, Parent = parent })
	end
end

function Props.DuneGrass(parent: Instance, ground: Vector3, rng: Random)
	local color = Color3.fromRGB(190, 180, 110):Lerp(Color3.fromRGB(140, 150, 90), rng:NextNumber())
	for _ = 1, rng:NextInteger(5, 9) do
		local p = ground + Vector3.new(rng:NextNumber(-2.5, 2.5), 0, rng:NextNumber(-2.5, 2.5))
		local h = rng:NextNumber(1.5, 3)
		decor({ Name = "Blade", Size = Vector3.new(0.15, h, 0.4), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6.28), rng:NextNumber(-0.4, 0.4)), Color = color, Material = Enum.Material.Grass, CastShadow = false, Parent = parent })
	end
end

function Props.Driftwood(parent: Instance, ground: Vector3, rng: Random)
	local yaw = rng:NextNumber(0, 6.28)
	local length = rng:NextNumber(6, 11)
	local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw)) * length / 2
	beam(ground - dir + Vector3.new(0, 0.5, 0), ground + dir + Vector3.new(0, 0.9, 0), rng:NextNumber(1, 1.6), { Name = "Driftwood", Color = Color3.fromRGB(176, 160, 140), Material = Enum.Material.Wood, Parent = parent })
end

-- Towering jungle tree: buttress roots, a straight dark trunk, a flat high canopy and vines.
function Props.JungleTree(parent: Instance, ground: Vector3, rng: Random)
	local height = rng:NextNumber(24, 34)
	local bark = Color3.fromRGB(76, 60, 46)
	Props.cylinder(ground + Vector3.new(0, height / 2 - 1, 0), height, rng:NextNumber(2.6, 3.4), { Name = "JungleTrunk", Color = bark, Material = Enum.Material.Wood, Parent = parent })
	for i = 1, 4 do
		local a = i * math.pi / 2 + rng:NextNumber(-0.3, 0.3)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		beam(ground + Vector3.new(0, 4, 0) + out * 0.8, ground + out * 4.5 - Vector3.new(0, 0.3, 0), 0.9, { Name = "Buttress", Color = bark, Material = Enum.Material.Wood, CanCollide = false, CanQuery = false, Parent = parent })
	end
	local top = ground + Vector3.new(0, height, 0)
	local greens = { Color3.fromRGB(34, 96, 48), Color3.fromRGB(46, 112, 52), Color3.fromRGB(28, 84, 56) }
	for i = 1, rng:NextInteger(5, 7) do
		local size = rng:NextNumber(10, 15)
		local offset = if i == 1 then Vector3.new(0, 1, 0) else Vector3.new(rng:NextNumber(-7, 7), rng:NextNumber(-1.5, 1.5), rng:NextNumber(-7, 7))
		decor({ Name = "Canopy", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.45, size), CFrame = CFrame.new(top + offset), Color = pick(rng, greens), Material = Enum.Material.Grass, Parent = parent })
	end
	for _ = 1, rng:NextInteger(2, 4) do
		local a = rng:NextNumber(0, 6.28)
		Props.Vine(parent, top + Vector3.new(math.cos(a) * 5, -2, math.sin(a) * 5), rng:NextNumber(10, 18), rng)
	end
end

function Props.Fern(parent: Instance, ground: Vector3, rng: Random)
	local color = Color3.fromRGB(40, 120, 60):Lerp(Color3.fromRGB(70, 140, 50), rng:NextNumber())
	for i = 1, rng:NextInteger(6, 9) do
		local yaw = i / 8 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		decor({ Name = "Frond", Size = Vector3.new(1.1, 0.15, 4), CFrame = CFrame.new(ground + Vector3.new(0, 0.9, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(0, 0, -1.8) * CFrame.Angles(math.rad(30), 0, 0), Color = color, Material = Enum.Material.Grass, CastShadow = false, Parent = parent })
	end
end

-- Giant glowing mushroom: lights up the dark jungle floor.
local SHROOM_GLOW = { Color3.fromRGB(80, 220, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(120, 255, 170) }
function Props.GiantMushroom(parent: Instance, ground: Vector3, rng: Random)
	local glow = pick(rng, SHROOM_GLOW)
	for i = 1, rng:NextInteger(1, 3) do
		local scale = if i == 1 then rng:NextNumber(1, 1.6) else rng:NextNumber(0.4, 0.7)
		local p = ground + (if i == 1 then Vector3.zero else Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)))
		local stem = 6 * scale
		Props.cylinder(p + Vector3.new(0, stem / 2, 0), stem, 1.3 * scale, { Name = "MushroomStem", Color = Color3.fromRGB(226, 220, 200), Material = Enum.Material.SmoothPlastic, Parent = parent })
		local cap = Props.part({ Name = "MushroomCap", Shape = Enum.PartType.Ball, Size = Vector3.new(7, 3, 7) * scale, CFrame = CFrame.new(p + Vector3.new(0, stem + 0.4 * scale, 0)), Color = glow:Lerp(Color3.new(0, 0, 0), 0.35), Material = Enum.Material.SmoothPlastic, Parent = parent })
		for s = 1, 5 do
			local a = s / 5 * math.pi * 2
			decor({ Name = "Spot", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 0.5, 1) * scale, CFrame = CFrame.new(p + Vector3.new(math.cos(a) * 2 * scale, stem + 1.4 * scale, math.sin(a) * 2 * scale)), Color = glow, Material = Enum.Material.Neon, CastShadow = false, Parent = parent })
		end
		if i == 1 then
			local light = Instance.new("PointLight")
			light.Color = glow
			light.Range = 16
			light.Brightness = 0.8
			light.Shadows = false
			light.Parent = cap
		end
	end
end

-- SETTLEMENT --------------------------------------------------------------------------

local HOUSE_COLORS = {
	Color3.fromRGB(240, 196, 130),
	Color3.fromRGB(165, 212, 230),
	Color3.fromRGB(236, 160, 145),
	Color3.fromRGB(196, 224, 160),
	Color3.fromRGB(250, 232, 175),
}
local ROOF_COLORS = {
	Color3.fromRGB(190, 70, 60),
	Color3.fromRGB(60, 100, 170),
	Color3.fromRGB(80, 140, 90),
	Color3.fromRGB(150, 90, 60),
}

-- cf: ground centre of the house, -Z (LookVector) is the front door side.
function Props.House(parent: Instance, cf: CFrame, rng: Random)
	local w, d, h = rng:NextNumber(13, 17), rng:NextNumber(10, 13), rng:NextNumber(8, 10)
	local wall = pick(rng, HOUSE_COLORS)
	local roof = pick(rng, ROOF_COLORS)
	Props.part({ Name = "Foundation", Size = Vector3.new(w + 1, 1, d + 1), CFrame = cf * CFrame.new(0, 0.5, 0), Color = Color3.fromRGB(150, 140, 125), Material = Enum.Material.Cobblestone, Parent = parent })
	Props.part({ Name = "Walls", Size = Vector3.new(w, h, d), CFrame = cf * CFrame.new(0, 1 + h / 2, 0), Color = wall, Material = Enum.Material.Plaster, Parent = parent })
	-- Timber corners
	for _, x in { -w / 2, w / 2 } do
		for _, z in { -d / 2, d / 2 } do
			Props.part({ Name = "Beam", Size = Vector3.new(0.8, h, 0.8), CFrame = cf * CFrame.new(x, 1 + h / 2, z), Color = Color3.fromRGB(95, 62, 40), Material = Enum.Material.Wood, Parent = parent })
		end
	end
	-- Gable roof: two slabs + stepped attic filling the gable
	local pitch = math.rad(32)
	local halfSpan = w / 2 + 1.2
	local slabLength = halfSpan / math.cos(pitch)
	local rise = math.tan(pitch) * (w / 2)
	local eave = cf * CFrame.new(0, 1 + h, 0)
	for side = -1, 1, 2 do
		Props.part({
			Name = "Roof",
			Size = Vector3.new(slabLength, 0.9, d + 2),
			CFrame = eave * CFrame.new(side * halfSpan / 2, math.tan(pitch) * halfSpan / 2 - 0.3, 0) * CFrame.Angles(0, 0, -side * pitch),
			Color = roof,
			Material = Enum.Material.Slate,
			Parent = parent,
		})
	end
	for step = 1, 3 do
		local fraction = 1 - step / 3.5
		Props.part({
			Name = "Attic",
			Size = Vector3.new(w * fraction, rise / 3, d - 0.2),
			CFrame = eave * CFrame.new(0, (step - 0.5) * rise / 3, 0),
			Color = wall,
			Material = Enum.Material.Plaster,
			Parent = parent,
		})
	end
	Props.part({ Name = "Chimney", Size = Vector3.new(1.8, 5, 1.8), CFrame = eave * CFrame.new(w / 4, rise + 0.5, d / 4), Color = Color3.fromRGB(160, 90, 70), Material = Enum.Material.Brick, Parent = parent })
	-- Door + windows on the front
	local front = cf * CFrame.new(0, 0, -d / 2 - 0.15)
	Props.part({ Name = "Door", Size = Vector3.new(3, 5.5, 0.4), CFrame = front * CFrame.new(0, 3.75, 0), Color = Color3.fromRGB(110, 70, 45), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, x in { -w / 3.2, w / 3.2 } do
		decor({ Name = "Window", Size = Vector3.new(2.6, 2.6, 0.3), CFrame = front * CFrame.new(x, 1 + h * 0.6, 0), Color = Color3.fromRGB(255, 225, 150), Material = Enum.Material.Neon, Transparency = 0.25, Parent = parent })
		Props.part({ Name = "Sill", Size = Vector3.new(3.2, 0.3, 0.8), CFrame = front * CFrame.new(x, 1 + h * 0.6 - 1.45, -0.2), Color = Color3.fromRGB(95, 62, 40), Material = Enum.Material.Wood, Parent = parent })
		Props.Flowers(parent, (front * CFrame.new(x, 1 + h * 0.6 - 1.2, -0.3)).Position, rng, 2)
	end
	-- Awning over the door
	Props.part({ Name = "Awning", Size = Vector3.new(5, 0.3, 2.4), CFrame = front * CFrame.new(0, 7.2, -1) * CFrame.Angles(math.rad(-15), 0, 0), Color = roof, Material = Enum.Material.Fabric, Parent = parent })
end

function Props.Lamp(parent: Instance, ground: Vector3)
	Props.cylinder(ground + Vector3.new(0, 4, 0), 8, 0.6, { Name = "LampPost", Color = Color3.fromRGB(45, 45, 55), Material = Enum.Material.Metal, Parent = parent })
	Props.part({ Name = "LampCap", Size = Vector3.new(1.6, 0.4, 1.6), CFrame = CFrame.new(ground + Vector3.new(0, 9.6, 0)), Color = Color3.fromRGB(45, 45, 55), Material = Enum.Material.Metal, Parent = parent })
	local bulb = decor({ Name = "LampGlass", Size = Vector3.new(1.2, 1.4, 1.2), CFrame = CFrame.new(ground + Vector3.new(0, 8.7, 0)), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, Parent = parent })
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 210, 140)
	light.Range = 18
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = bulb
	CollectionService:AddTag(bulb, "NightLamp")
end

function Props.Bench(parent: Instance, cf: CFrame)
	Props.part({ Name = "Seat", Size = Vector3.new(6, 0.5, 2), CFrame = cf * CFrame.new(0, 1.8, 0), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.WoodPlanks, Parent = parent })
	Props.part({ Name = "Back", Size = Vector3.new(6, 1.6, 0.4), CFrame = cf * CFrame.new(0, 2.9, 0.9) * CFrame.Angles(math.rad(-10), 0, 0), Color = Color3.fromRGB(150, 100, 60), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, x in { -2.5, 2.5 } do
		Props.part({ Name = "Leg", Size = Vector3.new(0.4, 1.6, 1.8), CFrame = cf * CFrame.new(x, 0.8, 0), Color = Color3.fromRGB(45, 45, 55), Material = Enum.Material.Metal, Parent = parent })
	end
end

function Props.Barrel(parent: Instance, cf: CFrame)
	Props.part({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 2.4, 2.4), CFrame = cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(130, 85, 50), Material = Enum.Material.WoodPlanks, Parent = parent })
	for _, y in { 0.5, 2.5 } do
		decor({ Name = "Hoop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 2.5, 2.5), CFrame = cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Metal, Parent = parent })
	end
end

function Props.Crate(parent: Instance, cf: CFrame, size: number?)
	local s = size or 3
	Props.part({ Name = "Crate", Size = Vector3.new(s, s, s), CFrame = cf * CFrame.new(0, s / 2, 0), Color = Color3.fromRGB(165, 120, 70), Material = Enum.Material.WoodPlanks, Parent = parent })
	decor({ Name = "Band", Size = Vector3.new(s + 0.1, 0.35, s + 0.1), CFrame = cf * CFrame.new(0, s / 2, 0), Color = Color3.fromRGB(95, 62, 40), Material = Enum.Material.Wood, Parent = parent })
end

function Props.Brazier(parent: Instance, ground: Vector3)
	Props.cylinder(ground + Vector3.new(0, 1.5, 0), 3, 1, { Name = "BrazierStand", Color = Color3.fromRGB(60, 55, 50), Material = Enum.Material.Metal, Parent = parent })
	local bowl = Props.cylinder(ground + Vector3.new(0, 3.3, 0), 0.8, 3, { Name = "BrazierBowl", Color = Color3.fromRGB(190, 140, 60), Material = Enum.Material.Metal, Parent = parent })
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 9
	fire.Parent = bowl
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 70)
	light.Range = 20
	light.Brightness = 1.5
	light.Parent = bowl
end

-- Hanging vine: a chain of thin leafy segments from `top` downwards.
function Props.Vine(parent: Instance, top: Vector3, length: number, rng: Random)
	local segments = math.max(2, math.floor(length / 2))
	for i = 0, segments - 1 do
		decor({
			Name = "Vine",
			Size = Vector3.new(0.35, 2.1, 0.35),
			CFrame = CFrame.new(top - Vector3.new(0, i * 2 + 1, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-8, 8))),
			Color = Color3.fromRGB(60, 130, 55),
			Material = Enum.Material.Grass,
			CastShadow = false,
			Parent = parent,
		})
		if i % 2 == 0 then
			decor({
				Name = "Leaf",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.9, 0.5, 0.9),
				CFrame = CFrame.new(top - Vector3.new(0, i * 2 + 1, 0) + Vector3.new(0.3, 0, 0)),
				Color = Color3.fromRGB(80, 160, 70),
				CastShadow = false,
				Parent = parent,
			})
		end
	end
end

-- String of triangular flags between two points (festive District bunting).
function Props.Bunting(parent: Instance, from: Vector3, to: Vector3, rng: Random)
	local delta = to - from
	local flags = math.floor(delta.Magnitude / 3)
	local sag = 2.5
	for i = 0, flags do
		local t = i / flags
		local p = from + delta * t - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
		decor({
			Name = "Flag",
			Class = "WedgePart",
			Size = Vector3.new(0.1, 1.4, 1.2),
			CFrame = CFrame.lookAt(p, p + delta) * CFrame.Angles(math.rad(180), math.rad(90), 0) * CFrame.new(0, 0.7, 0),
			Color = pick(rng, FLOWER_COLORS),
			Material = Enum.Material.Fabric,
			CastShadow = false,
			Parent = parent,
		})
	end
end

return Props
