-- Procedural prop library: vegetation, rocks and settlement dressing built from primitives.
-- Everything is anchored; decorative leaves/flowers are non-colliding and non-queryable so they
-- never block raycasts (treasure spawns, grapple aim) or snag players.

local Props = {}

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
