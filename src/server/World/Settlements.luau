-- Lived-in places across the Wilds (anchors in WorldLayout.Settlements). Each region gets
-- buildings you can walk into, climb or loot, so the island reads as a place people lived:
--   WILDS   farmstead (house, barn, turning windmill, crop field), ranger watchtower, campsite
--   COAST   fishing village: huts, a long pier, boats, drying nets (+ the Smugglers' Den shed)
--   MARSH   stilt village linked by a rope bridge, a drowned chapel
--   RUINS   a broken aqueduct you can walk along, an obelisk circle
--   FROST   trapper's cabin, mining outpost with a turning wheel, ice-fishing huts on the lake
--   FALLS   hermit's hut on the cliff top
-- Moving parts are tagged "Spinner" (client turns them); chimneys smoke. Loot spots inside
-- are WorldLayout.TreasureSpawns entries that raycast from under the roof (RayFrom).
-- Runs after the terrain and before vegetation; returns the Avoid list for the scatter.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)

local Props = require(script.Parent.Props)

local Settlements = {}

local part, cylinder = Props.part, Props.cylinder

local WOOD = Color3.fromRGB(112, 80, 52)
local DARK_WOOD = Color3.fromRGB(78, 56, 38)
local STONE = Color3.fromRGB(150, 142, 130)
local SANDSTONE = Color3.fromRGB(214, 176, 122)
local LAMP = Color3.fromRGB(255, 200, 120)

local function folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function lantern(parent: Instance, position: Vector3, color: Color3?)
	local glass = part({ Name = "Lantern", Size = Vector3.new(0.9, 1.2, 0.9), CFrame = CFrame.new(position), Color = color or LAMP, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = parent })
	light(glass, color or LAMP, 16, 1.1)
	CollectionService:AddTag(glass, "NightLamp")
	return glass
end

local function smoke(parent: BasePart)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "ChimneySmoke"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5) })
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Rate = 3
	emitter.Speed = NumberRange.new(2, 3)
	emitter.SpreadAngle = Vector2.new(10, 10)
	emitter.Acceleration = Vector3.new(1.5, 0.5, 0)
	emitter.LightInfluence = 1
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = parent
end

local function campfire(parent: Instance, ground: Vector3)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		part({ Name = "FireStone", Size = Vector3.new(1.2, 0.8, 1.2), CFrame = CFrame.new(ground + Vector3.new(math.cos(a) * 1.8, 0.4, math.sin(a) * 1.8)), Color = STONE, Material = Enum.Material.Slate, Parent = parent })
	end
	local logs = part({ Name = "FireLogs", Size = Vector3.new(2.4, 0.6, 0.6), CFrame = CFrame.new(ground + Vector3.new(0, 0.4, 0)), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	part({ Name = "FireLogs", Size = Vector3.new(0.6, 0.6, 2.4), CFrame = CFrame.new(ground + Vector3.new(0, 0.6, 0)), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Parent = logs
	light(logs, Color3.fromRGB(255, 150, 70), 20, 1.6)
end

-- Walls with a doorway on the front (-Z), a floor, and a gable roof along X.
-- Returns the floor top height. opts: Wall, Roof, Floor, Material, Chimney (bool), Door (width).
local function hut(parent: Instance, cf: CFrame, w: number, d: number, h: number, opts)
	local wall = opts.Wall or WOOD
	local material = opts.Material or Enum.Material.WoodPlanks
	local door = opts.Door or 4
	part({ Name = "Floor", Size = Vector3.new(w, 1, d), CFrame = cf * CFrame.new(0, 0.5, 0), Color = opts.Floor or DARK_WOOD, Material = Enum.Material.WoodPlanks, Parent = parent })
	local base = cf * CFrame.new(0, 1, 0)
	part({ Name = "WallBack", Size = Vector3.new(w, h, 1), CFrame = base * CFrame.new(0, h / 2, d / 2 - 0.5), Color = wall, Material = material, Parent = parent })
	for _, x in { -1, 1 } do
		part({ Name = "WallSide", Size = Vector3.new(1, h, d), CFrame = base * CFrame.new(x * (w / 2 - 0.5), h / 2, 0), Color = wall, Material = material, Parent = parent })
		local piece = (w - door) / 2
		part({ Name = "WallFront", Size = Vector3.new(piece, h, 1), CFrame = base * CFrame.new(x * (door / 2 + piece / 2), h / 2, -d / 2 + 0.5), Color = wall, Material = material, Parent = parent })
	end
	if h > 6.5 then
		part({ Name = "Lintel", Size = Vector3.new(door, h - 6.5, 1), CFrame = base * CFrame.new(0, 6.5 + (h - 6.5) / 2, -d / 2 + 0.5), Color = wall, Material = material, Parent = parent })
	end
	-- Gable roof: two slabs + stepped attic.
	local pitch = math.rad(30)
	local halfSpan = w / 2 + 1
	local rise = math.tan(pitch) * (w / 2)
	local eave = base * CFrame.new(0, h, 0)
	for side = -1, 1, 2 do
		part({
			Name = "Roof",
			Size = Vector3.new(halfSpan / math.cos(pitch), 0.8, d + 1.6),
			CFrame = eave * CFrame.new(side * halfSpan / 2, math.tan(pitch) * halfSpan / 2 - 0.3, 0) * CFrame.Angles(0, 0, -side * pitch),
			Color = opts.Roof or DARK_WOOD,
			Material = opts.RoofMaterial or Enum.Material.WoodPlanks,
			Parent = parent,
		})
	end
	for step = 1, 3 do
		part({ Name = "Attic", Size = Vector3.new(w * (1 - step / 3.5), rise / 3, d - 0.2), CFrame = eave * CFrame.new(0, (step - 0.5) * rise / 3, 0), Color = wall, Material = material, Parent = parent })
	end
	if opts.Snow then
		for side = -1, 1, 2 do
			part({
				Name = "RoofSnow",
				Size = Vector3.new(halfSpan / math.cos(pitch), 0.5, d + 1.8),
				CFrame = eave * CFrame.new(side * halfSpan / 2, math.tan(pitch) * halfSpan / 2 + 0.3, 0) * CFrame.Angles(0, 0, -side * pitch),
				Color = Color3.fromRGB(245, 250, 255),
				Material = Enum.Material.Snow,
				CanCollide = false,
				Parent = parent,
			})
		end
	end
	if opts.Chimney then
		local chimney = part({ Name = "Chimney", Size = Vector3.new(1.6, rise + 3, 1.6), CFrame = eave * CFrame.new(w / 4, (rise + 3) / 2, d / 4), Color = Color3.fromRGB(140, 90, 70), Material = Enum.Material.Brick, Parent = parent })
		smoke(chimney)
	end
	-- A warm window glow on each side.
	for _, x in { -1, 1 } do
		part({ Name = "Window", Size = Vector3.new(0.2, 2, 2.4), CFrame = base * CFrame.new(x * (w / 2 + 0.05), h * 0.6, 0), Color = LAMP, Material = Enum.Material.Neon, Transparency = 0.2, CanCollide = false, CanQuery = false, Parent = parent })
	end
	lantern(parent, (base * CFrame.new(0, h - 1.2, 0)).Position)
	return (cf * CFrame.new(0, 1, 0)).Position.Y
end

local function fence(parent: Instance, from: Vector3, to: Vector3)
	local delta = to - from
	local posts = math.max(1, math.floor(delta.Magnitude / 5))
	for i = 0, posts do
		local p = from + delta * (i / posts)
		part({ Name = "FencePost", Size = Vector3.new(0.6, 3.4, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 1.7, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = parent })
	end
	local mid = from + delta / 2
	for _, y in { 1.3, 2.6 } do
		part({ Name = "FenceRail", Size = Vector3.new(0.3, 0.4, delta.Magnitude), CFrame = CFrame.lookAt(mid + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0)), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	end
end

-- A model the client turns about its PrimaryPart's LookVector (tag "Spinner", attribute Speed).
local function spinner(parent: Instance, name: string, hubCf: CFrame, speed: number): Model
	local model = Instance.new("Model")
	model.Name = name
	local hub = part({ Name = "Hub", Size = Vector3.new(1.6, 1.6, 1.6), CFrame = hubCf, Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = model })
	model.PrimaryPart = hub
	model:SetAttribute("Speed", speed)
	model:SetAttribute("Home", hubCf)
	model.Parent = parent
	CollectionService:AddTag(model, "Spinner")
	return model
end

-- WILDS ---------------------------------------------------------------------------------

local function buildFarm(parent: Instance, rng: Random, groundAt)
	local f = folder("Farmstead", parent)
	local c = WorldLayout.Settlements.Farm
	local yard = Vector3.new(c.X, c.Y, c.Z)
	Props.House(f, CFrame.lookAt(Vector3.new(c.X - 16, c.Y, c.Z - 12), yard), rng)
	-- Red barn with a wide door facing the yard; loot inside.
	local barnPos = Vector3.new(c.X + 16, c.Y, c.Z - 10)
	hut(f, CFrame.lookAt(barnPos, Vector3.new(yard.X, barnPos.Y, yard.Z + 6)), 18, 14, 11, { Wall = Color3.fromRGB(170, 52, 44), Roof = Color3.fromRGB(70, 60, 58), RoofMaterial = Enum.Material.Slate, Door = 7 })
	for i = 1, 5 do
		cylinder(Vector3.new(barnPos.X - 12 + i * 1.8, c.Y + 1, barnPos.Z + 11 + (i % 2) * 2.2), 3, 2.2, { Name = "HayBale", Color = Color3.fromRGB(226, 196, 110), Material = Enum.Material.Grass, Parent = f })
	end
	-- Windmill: stone tower, turning sails.
	local mill = Vector3.new(c.X - 18, c.Y, c.Z + 17)
	for i, size in { 9, 7.6, 6.2 } do
		part({ Name = "MillTower", Size = Vector3.new(size, 7, size), CFrame = CFrame.new(mill + Vector3.new(0, 3.5 + (i - 1) * 7, 0)), Color = Color3.fromRGB(236, 230, 214), Material = Enum.Material.Plaster, Parent = f })
	end
	part({ Name = "MillCap", Class = "WedgePart", Size = Vector3.new(7, 4, 3.5), CFrame = CFrame.new(mill + Vector3.new(0, 23, 1.75)), Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "MillCap", Class = "WedgePart", Size = Vector3.new(7, 4, 3.5), CFrame = CFrame.new(mill + Vector3.new(0, 23, -1.75)) * CFrame.Angles(0, math.pi, 0), Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.WoodPlanks, Parent = f })
	local sails = spinner(f, "MillSails", CFrame.lookAt(mill + Vector3.new(0, 19, -3.8), mill + Vector3.new(0, 19, -10)), 0.8)
	for k = 0, 3 do
		local arm = CFrame.lookAt(mill + Vector3.new(0, 19, -4.2), mill + Vector3.new(0, 19, -10)) * CFrame.Angles(0, 0, k * math.pi / 2)
		part({ Name = "SailArm", Size = Vector3.new(0.5, 11, 0.4), CFrame = arm * CFrame.new(0, 5.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = sails })
		part({ Name = "Sail", Size = Vector3.new(2.6, 8, 0.15), CFrame = arm * CFrame.new(1.5, 6.5, 0), Color = Color3.fromRGB(240, 236, 220), Material = Enum.Material.Fabric, CanCollide = false, Parent = sails })
	end
	-- Crop field with a fence, a scarecrow and a well.
	local field = Vector3.new(c.X + 6, c.Y, c.Z + 16)
	for row = 0, 5 do
		for col = 0, 7 do
			local p = field + Vector3.new(-10 + col * 2.8, 0, -6 + row * 2.4)
			part({ Name = "Crop", Size = Vector3.new(1.4, rng:NextNumber(0.8, 1.6), 1.4), CFrame = CFrame.new(p + Vector3.new(0, 0.6, 0)), Color = if row % 2 == 0 then Color3.fromRGB(110, 170, 60) else Color3.fromRGB(220, 190, 70), Material = Enum.Material.Grass, CanCollide = false, Parent = f })
		end
	end
	local corners = { field + Vector3.new(-13, 0, -9), field + Vector3.new(13, 0, -9), field + Vector3.new(13, 0, 9), field + Vector3.new(-13, 0, 9) }
	for i = 1, 3 do
		fence(f, corners[i], corners[i + 1])
	end
	part({ Name = "ScarecrowPole", Size = Vector3.new(0.5, 6, 0.5), CFrame = CFrame.new(field + Vector3.new(2, 3, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	part({ Name = "ScarecrowArms", Size = Vector3.new(4.5, 0.4, 0.4), CFrame = CFrame.new(field + Vector3.new(2, 4.6, 0)), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = f })
	part({ Name = "ScarecrowHead", Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(field + Vector3.new(2, 6.3, 0)), Color = Color3.fromRGB(230, 170, 60), Material = Enum.Material.Fabric, Parent = f })
	local well = Vector3.new(c.X - 2, c.Y, c.Z - 2)
	cylinder(well + Vector3.new(0, 1.2, 0), 2.4, 4.4, { Name = "Well", Color = STONE, Material = Enum.Material.Cobblestone, Parent = f })
	cylinder(well + Vector3.new(0, 2.45, 0), 0.1, 3.4, { Name = "WellWater", Color = Color3.fromRGB(40, 80, 110), Material = Enum.Material.Glass, CanCollide = false, Parent = f })
	for _, x in { -2, 2 } do
		part({ Name = "WellPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(well + Vector3.new(x, 4, 0)), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	part({ Name = "WellRoof", Size = Vector3.new(5.4, 0.4, 3.4), CFrame = CFrame.new(well + Vector3.new(0, 6.2, 0)), Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.WoodPlanks, Parent = f })
	Props.Lamp(f, groundAt(c.X + 4, c.Z - 14))
	return { Vector2.new(c.X, c.Z), 38 }
end

local function buildWatchtower(parent: Instance)
	local f = folder("Watchtower", parent)
	local c = WorldLayout.Settlements.Watchtower
	local deck = WorldLayout.WatchtowerDeck
	for _, x in { -4, 4 } do
		for _, z in { -4, 4 } do
			part({ Name = "Leg", Size = Vector3.new(1.2, deck + 8, 1.2), CFrame = CFrame.new(c.X + x, c.Y + (deck + 8) / 2, c.Z + z), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
		end
	end
	for _, y in { 7, 15 } do
		for _, side in { -4, 4 } do
			part({ Name = "Brace", Size = Vector3.new(8, 0.5, 0.5), CFrame = CFrame.new(c.X, c.Y + y, c.Z + side), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = f })
			part({ Name = "Brace", Size = Vector3.new(0.5, 0.5, 8), CFrame = CFrame.new(c.X + side, c.Y + y, c.Z), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = f })
		end
	end
	part({ Name = "Deck", Size = Vector3.new(11, 1, 11), CFrame = CFrame.new(c.X, c.Y + deck - 0.5, c.Z), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	for _, side in { -1, 1 } do
		part({ Name = "Rail", Size = Vector3.new(11, 2.4, 0.4), CFrame = CFrame.new(c.X, c.Y + deck + 1.2, c.Z + side * 5.3), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	end
	part({ Name = "Rail", Size = Vector3.new(0.4, 2.4, 11), CFrame = CFrame.new(c.X + 5.3, c.Y + deck + 1.2, c.Z), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	-- Ladder on the open (-X) side.
	part({ Name = "TowerLadder", Class = "TrussPart", Size = Vector3.new(2, deck, 2), CFrame = CFrame.new(c.X - 6.4, c.Y + deck / 2, c.Z), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	part({ Name = "TowerRoof", Size = Vector3.new(12.5, 1, 12.5), CFrame = CFrame.new(c.X, c.Y + deck + 8, c.Z), Color = Color3.fromRGB(60, 90, 60), Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "TowerFlagPole", Size = Vector3.new(0.3, 6, 0.3), CFrame = CFrame.new(c.X, c.Y + deck + 11.5, c.Z), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = f })
	part({ Name = "TowerFlag", Size = Vector3.new(0.1, 1.8, 3), CFrame = CFrame.new(c.X, c.Y + deck + 13.5, c.Z + 1.5), Color = Color3.fromRGB(230, 70, 60), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	lantern(f, Vector3.new(c.X + 4.4, c.Y + deck + 6.6, c.Z + 4.4))
	return { Vector2.new(c.X, c.Z), 14 }
end

local function buildCamp(parent: Instance, rng: Random)
	local f = folder("Campsite", parent)
	local c = WorldLayout.Settlements.Camp
	campfire(f, c)
	local colors = { Color3.fromRGB(220, 110, 50), Color3.fromRGB(60, 130, 190), Color3.fromRGB(90, 160, 80) }
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi + 0.5
		local p = c + Vector3.new(math.cos(a) * 9, 0, math.sin(a) * 9)
		local cf = CFrame.lookAt(p, c)
		for side = -1, 1, 2 do
			part({ Name = "Tent", Size = Vector3.new(0.3, 5.6, 7), CFrame = cf * CFrame.new(side * 1.9, 2.4, 0) * CFrame.Angles(0, 0, side * math.rad(36)), Color = colors[i], Material = Enum.Material.Fabric, Parent = f })
		end
	end
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		part({ Name = "LogSeat", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 1.2, 1.2), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 4, 0.6, math.sin(a) * 4)) * CFrame.Angles(0, -a + math.pi / 2, 0), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	Props.Crate(f, CFrame.new(c + Vector3.new(5, 1, -6)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0))
	Props.Barrel(f, CFrame.new(c + Vector3.new(-6, 0, 5)))
	return { Vector2.new(c.X, c.Z), 16 }
end

-- COAST ---------------------------------------------------------------------------------

local function buildVillage(parent: Instance, rng: Random, groundAt)
	local f = folder("FishingVillage", parent)
	local c = WorldLayout.Settlements.Village
	local palette = { Color3.fromRGB(70, 130, 170), Color3.fromRGB(200, 90, 70), Color3.fromRGB(230, 200, 120) }
	for i, offset in { Vector3.new(-11, 0, -16), Vector3.new(-15, 0, 8), Vector3.new(6, 0, -24) } do
		local p = c + offset
		hut(f, CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)), 11, 10, 7, { Wall = palette[i], Roof = Color3.fromRGB(80, 70, 66), RoofMaterial = Enum.Material.Slate, Chimney = i ~= 2 })
	end
	-- The pier: a long plank walk out over the water on posts.
	local pierStart, pierEnd = c.X - 22, c.X - 86
	local pierZ = c.Z - 2
	part({ Name = "Pier", Size = Vector3.new(pierStart - pierEnd, 1, 6), CFrame = CFrame.new((pierStart + pierEnd) / 2, 11, pierZ), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	for x = pierEnd + 2, pierStart - 2, 8 do
		for _, dz in { -2.6, 2.6 } do
			cylinder(Vector3.new(x, -2, pierZ + dz), 26, 1, { Name = "PierPost", Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
		end
	end
	part({ Name = "PierEnd", Size = Vector3.new(10, 1, 12), CFrame = CFrame.new(pierEnd - 3, 11, pierZ), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	lantern(f, Vector3.new(pierEnd - 6, 14, pierZ + 5))
	part({ Name = "LanternPost", Size = Vector3.new(0.4, 3, 0.4), CFrame = CFrame.new(pierEnd - 6, 12.5, pierZ + 5), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = f })
	-- Rowboats pulled up on the sand.
	for _, spot in { Vector3.new(-18, 0, 22), Vector3.new(-24, 0, -30) } do
		local ground = groundAt(c.X + spot.X, c.Z + spot.Z)
		local cf = CFrame.new(ground + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), math.rad(8))
		part({ Name = "BoatHull", Size = Vector3.new(3.4, 1.2, 9), CFrame = cf, Color = palette[rng:NextInteger(1, 3)], Material = Enum.Material.WoodPlanks, Parent = f })
		part({ Name = "BoatSeat", Size = Vector3.new(3.4, 0.3, 1), CFrame = cf * CFrame.new(0, 0.5, 0), Color = DARK_WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = f })
	end
	-- Drying nets between posts, barrels and crates.
	for k = 0, 1 do
		local base = c + Vector3.new(-2, 0, 12 + k * 6)
		for _, dx in { -4, 4 } do
			part({ Name = "NetPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = CFrame.new(base + Vector3.new(dx, 2.5, 0)), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
		end
		part({ Name = "DryingNet", Size = Vector3.new(8, 3.6, 0.15), CFrame = CFrame.new(base + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(200, 186, 140), Material = Enum.Material.Fabric, Transparency = 0.45, CanCollide = false, Parent = f })
	end
	for i = 1, 4 do
		Props.Barrel(f, CFrame.new(c + Vector3.new(10 + (i % 2) * 2.2, 0, -8 + i * 2)))
	end
	Props.Crate(f, CFrame.new(c + Vector3.new(-2, 1.2, -6)), 2.4)
	Props.Lamp(f, groundAt(c.X + 2, c.Z - 12))
	Props.Lamp(f, groundAt(c.X - 18, c.Z + 2))
	return { Vector2.new(c.X, c.Z), 34 }
end

-- MARSH ---------------------------------------------------------------------------------

local function buildStiltVillage(parent: Instance, groundAt)
	local f = folder("StiltVillage", parent)
	local c = WorldLayout.Settlements.StiltVillage
	local floorY = c.Y
	local purple = Color3.fromRGB(200, 130, 255)
	local huts = { Vector3.new(c.X - 9, floorY, c.Z - 8), Vector3.new(c.X + 10, floorY, c.Z + 9) }
	for _, p in huts do
		-- Stilts down to whatever is below.
		for _, dx in { -5, 5 } do
			for _, dz in { -5, 5 } do
				local ground = groundAt(p.X + dx, p.Z + dz, floorY - 1)
				local height = floorY - ground.Y + 1
				cylinder(Vector3.new(p.X + dx, ground.Y + height / 2 - 1, p.Z + dz), height, 1, { Name = "Stilt", Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
			end
		end
		part({ Name = "Porch", Size = Vector3.new(12, 1, 4), CFrame = CFrame.new(p.X, floorY + 0.5, p.Z - 7), Color = Color3.fromRGB(96, 80, 64), Material = Enum.Material.WoodPlanks, Parent = f })
		hut(f, CFrame.new(p), 11, 10, 7, { Wall = Color3.fromRGB(90, 96, 70), Roof = Color3.fromRGB(70, 60, 90), RoofMaterial = Enum.Material.Fabric })
		lantern(f, p + Vector3.new(4.5, 5, -8.6), purple)
		local ladderGround = groundAt(p.X, p.Z - 9.5, floorY - 1)
		local ladderHeight = floorY + 1 - ladderGround.Y
		part({ Name = "HutLadder", Class = "TrussPart", Size = Vector3.new(2, ladderHeight, 2), CFrame = CFrame.new(p.X, ladderGround.Y + ladderHeight / 2, p.Z - 9.6), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	-- Rope bridge between the two porches (sagging planks).
	local a, b = huts[1] + Vector3.new(6, 0.6, -7), huts[2] + Vector3.new(-6, 0.6, -7)
	local delta = b - a
	local planks = math.floor(delta.Magnitude / 1.6)
	for i = 0, planks do
		local t = i / planks
		local p = a + delta * t - Vector3.new(0, math.sin(t * math.pi) * 1.4, 0)
		part({ Name = "BridgePlank", Size = Vector3.new(3.4, 0.35, 1.3), CFrame = CFrame.lookAt(p, p + Vector3.new(delta.X, 0, delta.Z)) * CFrame.Angles(0, math.pi / 2, 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	end
	return { Vector2.new(c.X, c.Z), 26 }
end

local function buildChapel(parent: Instance, rng: Random)
	local f = folder("DrownedChapel", parent)
	local c = WorldLayout.Settlements.Chapel
	local moss = Color3.fromRGB(96, 120, 90)
	local cf = CFrame.new(c) * CFrame.Angles(0, math.rad(15), 0)
	-- Broken walls: segments of random height, a gap for the door.
	for _, side in { -1, 1 } do
		for k = 0, 4 do
			local height = rng:NextNumber(3, 11)
			part({ Name = "ChapelWall", Size = Vector3.new(1.4, height, 5.4), CFrame = cf * CFrame.new(side * 7, height / 2, -11 + k * 5.5), Color = STONE:Lerp(moss, rng:NextNumber(0.1, 0.5)), Material = Enum.Material.Cobblestone, Parent = f })
		end
	end
	part({ Name = "ChapelApse", Size = Vector3.new(15.4, 13, 1.4), CFrame = cf * CFrame.new(0, 6.5, 13), Color = STONE:Lerp(moss, 0.3), Material = Enum.Material.Cobblestone, Parent = f })
	part({ Name = "RoseWindow", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 5, 5), CFrame = cf * CFrame.new(0, 9, 12.2) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(170, 120, 255), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, Parent = f })
	for _, x in { -5, 5 } do
		part({ Name = "FrontWall", Size = Vector3.new(4.4, rng:NextNumber(6, 12), 1.4), CFrame = cf * CFrame.new(x, 4, -13.5), Color = STONE:Lerp(moss, 0.25), Material = Enum.Material.Cobblestone, Parent = f })
	end
	-- Toppled column and an altar with candles.
	part({ Name = "FallenColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(12, 2.2, 2.2), CFrame = cf * CFrame.new(-2, 1.1, -3) * CFrame.Angles(0, math.rad(30), 0), Color = STONE, Material = Enum.Material.Marble, Parent = f })
	part({ Name = "Altar", Size = Vector3.new(5, 2.6, 2.4), CFrame = cf * CFrame.new(0, 1.3, 9.5), Color = STONE, Material = Enum.Material.Marble, Parent = f })
	for _, x in { -1.8, 1.8 } do
		lantern(f, (cf * CFrame.new(x, 3.2, 9.5)).Position, Color3.fromRGB(190, 150, 255))
	end
	for _ = 1, 5 do
		Props.Vine(f, (cf * CFrame.new(rng:NextNumber(-7, 7), rng:NextNumber(6, 10), rng:NextNumber(-10, 12))).Position, rng:NextNumber(2, 5), rng)
	end
	return { Vector2.new(c.X, c.Z), 20 }
end

-- RUINS ---------------------------------------------------------------------------------

local function buildAqueduct(parent: Instance, rng: Random)
	local f = folder("Aqueduct", parent)
	local c = WorldLayout.Settlements.Aqueduct
	local deck = WorldLayout.AqueductDeck
	local south, north = c.Z - 40, c.Z + 40
	-- Piers + arches.
	for z = south, north, 16 do
		part({ Name = "Pier", Size = Vector3.new(5, deck, 4), CFrame = CFrame.new(c.X, c.Y + deck / 2, z), Color = SANDSTONE:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.12)), Material = Enum.Material.Sandstone, Parent = f })
	end
	for z = south + 8, north - 8, 16 do
		part({ Name = "Arch", Size = Vector3.new(5, 3, 12), CFrame = CFrame.new(c.X, c.Y + deck - 2.5, z), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = f })
	end
	-- The channel on top: a walkable deck with low side walls.
	part({ Name = "Channel", Size = Vector3.new(6, 1, north - south + 4), CFrame = CFrame.new(c.X, c.Y + deck - 0.5, c.Z), Color = SANDSTONE:Lerp(Color3.new(1, 1, 1), 0.1), Material = Enum.Material.Sandstone, Parent = f })
	for _, side in { -1, 1 } do
		part({ Name = "ChannelWall", Size = Vector3.new(0.8, 1.6, north - south + 4), CFrame = CFrame.new(c.X + side * 2.6, c.Y + deck + 0.8, c.Z), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = f })
	end
	-- A rubble ramp at the north end is the way up.
	local rampLength = deck * 2.2
	part({
		Name = "RubbleRamp",
		Class = "WedgePart",
		Size = Vector3.new(6, deck, rampLength),
		CFrame = CFrame.new(c.X, c.Y + deck / 2, north + 2 + rampLength / 2) * CFrame.Angles(0, math.pi, 0),
		Color = SANDSTONE:Lerp(Color3.fromRGB(120, 100, 80), 0.3),
		Material = Enum.Material.Sandstone,
		Parent = f,
	})
	for _ = 1, 8 do
		local size = rng:NextNumber(1.5, 3.5)
		part({ Name = "Rubble", Size = Vector3.new(size, size * 0.7, size), CFrame = CFrame.new(c.X + rng:NextNumber(-7, 7), c.Y + size * 0.3, rng:NextNumber(south, north)) * CFrame.Angles(rng:NextNumber(0, 1), rng:NextNumber(0, 3), 0), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = f })
	end
	return { Vector2.new(c.X, c.Z), 12 }, { Vector2.new(c.X, north + 2 + rampLength / 2), 10 }, { Vector2.new(c.X, south), 8 }
end

local function buildObelisks(parent: Instance)
	local f = folder("ObeliskCircle", parent)
	local c = WorldLayout.Settlements.Obelisks
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		local p = c + Vector3.new(math.cos(a) * 12, 0, math.sin(a) * 12)
		local height = if i % 3 == 0 then 6 else 12
		part({ Name = "Obelisk", Size = Vector3.new(2.2, height, 2.2), CFrame = CFrame.new(p + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, a, 0), Color = Color3.fromRGB(70, 64, 60), Material = Enum.Material.Basalt, Parent = f })
		if height > 6 then
			part({ Name = "ObeliskGlyph", Size = Vector3.new(0.2, 3, 1), CFrame = CFrame.lookAt(p + Vector3.new(0, 7, 0), c + Vector3.new(0, 7, 0)) * CFrame.new(0, 0, -1.15) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(255, 190, 70), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
		end
	end
	local altar = part({ Name = "RuneAltar", Size = Vector3.new(5, 1.2, 5), CFrame = CFrame.new(c + Vector3.new(0, 0.6, 0)), Color = Color3.fromRGB(80, 74, 70), Material = Enum.Material.Basalt, Parent = f })
	part({ Name = "RuneRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.1, 4.2, 4.2), CFrame = CFrame.new(c + Vector3.new(0, 1.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 190, 70), Material = Enum.Material.Neon, Transparency = 0.35, CanCollide = false, CanQuery = false, Parent = f })
	light(altar, Color3.fromRGB(255, 180, 80), 18, 1)
	return { Vector2.new(c.X, c.Z), 18 }
end

-- FROST ---------------------------------------------------------------------------------

local function buildTrapper(parent: Instance, rng: Random)
	local f = folder("TrapperCabin", parent)
	local c = WorldLayout.Settlements.Trapper
	hut(f, CFrame.lookAt(c, c + Vector3.new(-1, 0, -1)), 12, 10, 7, { Wall = Color3.fromRGB(96, 66, 44), Material = Enum.Material.Wood, Roof = DARK_WOOD, Chimney = true, Snow = true })
	-- Firewood stack, pelts on a rack, a sled.
	for i = 0, 5 do
		part({ Name = "Firewood", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3, 0.9, 0.9), CFrame = CFrame.new(c + Vector3.new(8, 0.45 + (i // 3) * 0.85, -2 + (i % 3) * 0.95)) * CFrame.Angles(0, math.rad(90), 0), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	for _, dz in { -2, 2 } do
		part({ Name = "RackPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(c + Vector3.new(-9, 2, dz)), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	for k = 0, 1 do
		part({ Name = "Pelt", Size = Vector3.new(0.15, 2.4, 1.6), CFrame = CFrame.new(c + Vector3.new(-9, 2.6, -1 + k * 2)), Color = if k == 0 then Color3.fromRGB(150, 110, 70) else Color3.fromRGB(230, 230, 230), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	end
	part({ Name = "Sled", Size = Vector3.new(2.2, 0.5, 5), CFrame = CFrame.new(c + Vector3.new(4, 0.6, -10)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0), Color = Color3.fromRGB(170, 60, 50), Material = Enum.Material.WoodPlanks, Parent = f })
	return { Vector2.new(c.X, c.Z), 16 }
end

local function buildOutpost(parent: Instance, rng: Random)
	local f = folder("MiningOutpost", parent)
	local c = WorldLayout.Settlements.Outpost
	-- Headframe: an A-frame over the shaft with a turning winding wheel.
	for _, x in { -3.5, 3.5 } do
		part({ Name = "Headframe", Size = Vector3.new(1, 16, 1), CFrame = CFrame.new(c + Vector3.new(x, 8, 6)) * CFrame.Angles(0, 0, math.rad(x * 2.5)), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	part({ Name = "HeadframeBeam", Size = Vector3.new(8, 1, 1), CFrame = CFrame.new(c + Vector3.new(0, 15.5, 6)), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
	part({ Name = "ShaftCover", Size = Vector3.new(6, 0.6, 6), CFrame = CFrame.new(c + Vector3.new(0, 0.3, 6)), Color = Color3.fromRGB(40, 36, 34), Material = Enum.Material.WoodPlanks, Parent = f })
	local wheel = spinner(f, "WindingWheel", CFrame.lookAt(c + Vector3.new(0, 17, 6), c + Vector3.new(1, 17, 6)), 1.2)
	for k = 0, 5 do
		part({ Name = "Spoke", Size = Vector3.new(0.3, 5, 0.3), CFrame = wheel.PrimaryPart.CFrame * CFrame.Angles(0, 0, k * math.pi / 3) * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(70, 70, 76), Material = Enum.Material.Metal, CanCollide = false, Parent = wheel })
	end
	-- Shack, rails, ore carts, crates.
	hut(f, CFrame.lookAt(c + Vector3.new(-10, 0, -4), c + Vector3.new(0, 0, -4)), 10, 8, 7, { Wall = Color3.fromRGB(110, 100, 90), Roof = Color3.fromRGB(80, 80, 86), RoofMaterial = Enum.Material.CorrodedMetal, Chimney = true, Snow = true })
	for _, dx in { -0.9, 0.9 } do
		part({ Name = "Rail", Size = Vector3.new(0.3, 0.3, 18), CFrame = CFrame.new(c + Vector3.new(6 + dx, 0.2, -2)), Color = Color3.fromRGB(80, 78, 76), Material = Enum.Material.Metal, CanCollide = false, Parent = f })
	end
	for k = 0, 1 do
		local cart = CFrame.new(c + Vector3.new(6, 1.4, -8 + k * 7))
		part({ Name = "OreCart", Size = Vector3.new(2.8, 2, 3.6), CFrame = cart, Color = Color3.fromRGB(90, 70, 50), Material = Enum.Material.CorrodedMetal, Parent = f })
		part({ Name = "Ore", Size = Vector3.new(2.4, 0.8, 3.2), CFrame = cart * CFrame.new(0, 1, 0), Color = if k == 0 then Color3.fromRGB(120, 200, 255) else Color3.fromRGB(80, 80, 90), Material = if k == 0 then Enum.Material.Neon else Enum.Material.Slate, CanCollide = false, Parent = f })
	end
	for i = 1, 3 do
		Props.Crate(f, CFrame.new(c + Vector3.new(-4 + i * 1.5, 1, 12)) * CFrame.Angles(0, rng:NextNumber(0, 1), 0))
	end
	lantern(f, c + Vector3.new(0, 13, 6), Color3.fromRGB(150, 210, 255))
	return { Vector2.new(c.X, c.Z), 18 }
end

local function buildIceHuts(parent: Instance)
	local f = folder("IceFishing", parent)
	local lake = WorldLayout.Frostpeak.Center
	local colors = { Color3.fromRGB(200, 60, 50), Color3.fromRGB(60, 110, 200), Color3.fromRGB(230, 180, 50) }
	for i, offset in { Vector3.new(12, 0, 12), Vector3.new(-12, 0, -10), Vector3.new(-6, 0, 18) } do
		local p = Vector3.new(lake.X, 10, lake.Z) + offset
		hut(f, CFrame.lookAt(p, Vector3.new(lake.X, 10, lake.Z)), 6, 6, 6, { Wall = colors[i], Roof = Color3.fromRGB(245, 250, 255), Door = 3 })
		cylinder(p + Vector3.new(0, 0.05, -6), 0.1, 2.4, { Name = "FishingHole", Color = Color3.fromRGB(20, 50, 80), Material = Enum.Material.Glass, CanCollide = false, Parent = f })
		part({ Name = "Stool", Size = Vector3.new(1, 1.2, 1), CFrame = CFrame.new(p + Vector3.new(1.6, 0.6, -6)), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
end

-- FALLS ---------------------------------------------------------------------------------

local function buildHermit(parent: Instance, rng: Random, groundAt)
	local f = folder("HermitHut", parent)
	local c = WorldLayout.Settlements.Hermit
	local ground = groundAt(c.X, c.Z, 200)
	hut(f, CFrame.lookAt(ground, ground + Vector3.new(0, 0, 1)), 10, 9, 7, { Wall = Color3.fromRGB(120, 110, 90), Roof = Color3.fromRGB(70, 100, 60), RoofMaterial = Enum.Material.Grass, Chimney = true })
	-- Prayer flags down to a little herb garden.
	local pole = ground + Vector3.new(10, 0, 8)
	part({ Name = "FlagPole", Size = Vector3.new(0.4, 9, 0.4), CFrame = CFrame.new(pole + Vector3.new(0, 4.5, 0)), Color = DARK_WOOD, Material = Enum.Material.Wood, Parent = f })
	Props.Bunting(f, ground + Vector3.new(4, 8.5, 5), pole + Vector3.new(0, 8.8, 0), rng)
	for i = 0, 3 do
		part({ Name = "HerbBed", Size = Vector3.new(6, 0.8, 1.4), CFrame = CFrame.new(ground + Vector3.new(-10, 0.4, -3 + i * 2.2)), Color = Color3.fromRGB(90, 140, 70), Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = f })
	end
	return { Vector2.new(c.X, c.Z), 16 }
end

-- Returns { Avoid = { { Vector2, radius } } }.
function Settlements.Build(parent: Instance, rng: Random, groundAt)
	local root = folder("Settlements", parent)
	local avoid = {}
	local function add(...)
		for _, entry in { ... } do
			table.insert(avoid, entry)
		end
	end
	add(buildFarm(root, rng, groundAt))
	add(buildWatchtower(root))
	add(buildCamp(root, rng))
	add(buildVillage(root, rng, groundAt))
	add(buildStiltVillage(root, groundAt))
	add(buildChapel(root, rng))
	add(buildAqueduct(root, rng))
	add(buildObelisks(root))
	add(buildTrapper(root, rng))
	add(buildOutpost(root, rng))
	buildIceHuts(root)
	add(buildHermit(root, rng, groundAt))
	return { Avoid = avoid }
end

return Settlements
