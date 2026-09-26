-- RIMEHEART (danger 6, Ascension 2): a glacier under the aurora.
--   * The plateau rolls: wind-blown dunes and pressure ridges of blue ice (TerrainGen.RimeRelief)
--     either side of a trodden trail marked with glowing ice posts.
--   * SERAC FIELDS: towers of blue ice leaning over the glacier's edges.
--   * THE HEART OF THE RIME: a colossal frozen crystal at the middle of the glacier.
--   * Two natural ICE ARCHES over the trail, and a FROZEN LAKE with fish locked in the ice.
--   * The AURORA: curtains of green and violet light across the sky (brighter at night).
--   * The Rime Gate and an ice gorge climbing the glacier face.
--   * Two CREVASSES cut the plateau (fall in = pulled out at the edge, loot dropped:
--     HazardService, tag "FallZone"). Cross on the ice bridge, a rope bridge, or jump the
--     narrow ledges.
--   * FROSTBANE'S TOMB (secret): behind a frozen waterfall in the glacier face, an ice tunnel
--     to a crypt of frozen knights around an empty sword altar.
--   * THE FROZEN SHIP (secret): a galleon locked in the ice on the west shore; climb in through
--     the hole in its hull.
--   * Glacier Station (Dangerous exit), an igloo village, a mammoth frozen in a block of ice.
--   * The Starfall launch at the glacier tip (Rune Gate, Ascension 3).

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Util.Zones)
local WorldLayout = require(Shared.Config.WorldLayout)

local Props = require(script.Parent.Parent.Props)
local Common = require(script.Parent.Common)

local Rime = {}

local part = Common.part

local function cylinderPart(parent: Instance, position: Vector3, height: number, diameter: number, color: Color3, material: Enum.Material, transparency: number): BasePart
	return Common.cylinder(position, height, diameter, { Name = "Disc", Color = color, Material = material, Transparency = transparency, CanCollide = false, Parent = parent })
end
local light, emitter = Common.light, Common.emitter

local ICE = Color3.fromRGB(170, 220, 245)
local DEEP_ICE = Color3.fromRGB(90, 160, 220)
local SNOW = Color3.fromRGB(245, 250, 255)
local FROST_WOOD = Color3.fromRGB(150, 160, 170)
local METAL = Color3.fromRGB(120, 125, 135)
local GLOW = Color3.fromRGB(120, 225, 255)

local TOP = WorldLayout.DeepSouth.PlateauHeight
Rime.TOMB = Vector3.new(-170, 12, -852) -- crypt floor
Rime.SHIP = Vector3.new(-160, TOP, -915)
Rime.CREVASSES = {
	{ Z = -880, MinX = -200, MaxX = 145, Bridges = { { X = 0, Style = "Ice" }, { X = -130, Style = "Planks" } }, Ledges = 100 },
	{ Z = -950, MinX = -150, MaxX = 205, Bridges = { { X = 0, Style = "Ice" }, { X = 150, Style = "Planks" } }, Ledges = -100 },
}
local CREVASSE_WIDTH = 12

-- THE CLIMB -------------------------------------------------------------------------------

local function buildClimb(terrain: Terrain, parent: Instance)
	local f = Common.folder("GlacierClimb", parent)
	local a, b = Vector3.new(12, 12, -786), Vector3.new(0, TOP, -852)
	local steps = 22
	for i = 0, steps do
		local t = i / steps
		local p = a:Lerp(b, t)
		terrain:FillBlock(CFrame.new(p.X, p.Y - 6, p.Z), Vector3.new(16, 12, 4), Enum.Material.Glacier)
		terrain:FillBlock(CFrame.new(p.X, p.Y + 8, p.Z), Vector3.new(14, 16, 4), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(p.X, p.Y - 0.5, p.Z), Vector3.new(10, 1, 4), Enum.Material.Snow)
		if i % 5 == 2 then
			for _, side in { -1, 1 } do
				local lamp = part({ Name = "IceLamp", Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(p + Vector3.new(side * 6.5, 3, 0)), Color = Color3.fromRGB(150, 230, 255), Material = Enum.Material.Neon, Parent = f })
				part({ Name = "IceLampPost", Size = Vector3.new(0.6, 2.5, 0.6), CFrame = CFrame.new(p + Vector3.new(side * 6.5, 1.3, 0)), Color = DEEP_ICE, Material = Enum.Material.Glass, Parent = f })
				if side > 0 then
					light(lamp, Color3.fromRGB(150, 220, 255), 18, 1)
				end
			end
		end
	end
	local gateAt = a:Lerp(b, 8 / 66)
	Common.runeGate(f, gateAt, Vector3.new(-0.18, 0, -1), 2, "RIMEHEART", Color3.fromRGB(150, 175, 195))
	Common.sign(f, gateAt + Vector3.new(0, 30, 0), "RIMEHEART", "★★★★★★☆ • ASCENSION 2", Color3.fromRGB(160, 225, 255), 20)
end

-- CREVASSES -------------------------------------------------------------------------------

local function buildCrevasses(terrain: Terrain, parent: Instance, avoid)
	local f = Common.folder("Crevasses", parent)
	for _, cv in Rime.CREVASSES do
		local length = cv.MaxX - cv.MinX
		local mid = (cv.MinX + cv.MaxX) / 2
		terrain:FillBlock(CFrame.new(mid, 26, cv.Z), Vector3.new(length, 44, CREVASSE_WIDTH), Enum.Material.Air)
		terrain:FillBlock(CFrame.new(mid, 3.5, cv.Z), Vector3.new(length, 3, CREVASSE_WIDTH + 2), Enum.Material.Ice)
		-- The pull-out zones: segments, each returning you to the near (north) edge.
		for x = cv.MinX, cv.MaxX - 1, 50 do
			local w = math.min(50, cv.MaxX - x)
			local zone = part({ Name = "CrevasseFall", Size = Vector3.new(w, 22, CREVASSE_WIDTH), CFrame = CFrame.new(x + w / 2, 15, cv.Z), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = f })
			zone:SetAttribute("Respawn", Vector3.new(x + w / 2, TOP + 1, cv.Z + CREVASSE_WIDTH / 2 + 4))
			game:GetService("CollectionService"):AddTag(zone, "FallZone")
		end
		-- Deep blue glow at the bottom so you feel the drop.
		for x = cv.MinX + 20, cv.MaxX - 20, 60 do
			local glow = part({ Name = "CrevasseGlow", Size = Vector3.new(6, 0.5, 4), CFrame = CFrame.new(x, 5.3, cv.Z), Color = Color3.fromRGB(80, 170, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
			light(glow, Color3.fromRGB(80, 170, 255), 22, 1.2)
		end
		for _, bridge in cv.Bridges do
			local north = Vector3.new(bridge.X, TOP, cv.Z + CREVASSE_WIDTH / 2 + 3)
			local south = Vector3.new(bridge.X, TOP, cv.Z - CREVASSE_WIDTH / 2 - 3)
			if bridge.Style == "Ice" then
				local deck = part({ Name = "IceBridge", Size = Vector3.new(8, 1.4, CREVASSE_WIDTH + 8), CFrame = CFrame.new(bridge.X, TOP - 0.5, cv.Z), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.2, Parent = f })
				part({ Name = "IceArch", Shape = Enum.PartType.Ball, Size = Vector3.new(8, 8, 8), CFrame = CFrame.new(bridge.X, TOP - 5, cv.Z), Color = DEEP_ICE, Material = Enum.Material.Glass, Transparency = 0.3, CanCollide = false, Parent = f })
				light(deck, Color3.fromRGB(150, 220, 255), 14, 0.8)
			else
				Common.bridge(f, north, south, 6, "Planks")
			end
			table.insert(avoid, { Vector2.new(bridge.X, cv.Z), 10 })
		end
		-- Two ice shelves reaching over the gap: a 5-stud jump.
		for _, side in { -1, 1 } do
			part({ Name = "IceShelf", Size = Vector3.new(8, 1.6, 3.5), CFrame = CFrame.new(cv.Ledges, TOP - 0.6, cv.Z + side * (CREVASSE_WIDTH / 2 - 1.75)), Color = ICE, Material = Enum.Material.Glacier, Parent = f })
		end
		table.insert(avoid, { Vector2.new(mid, cv.Z), 0 }) -- (lines are checked separately)
	end
end

local function nearCrevasse(x: number, z: number, margin: number): boolean
	for _, cv in Rime.CREVASSES do
		if x > cv.MinX - margin and x < cv.MaxX + margin and math.abs(z - cv.Z) < CREVASSE_WIDTH / 2 + margin then
			return true
		end
	end
	return false
end
Rime.NearCrevasse = nearCrevasse

-- FROSTBANE'S TOMB (secret) ---------------------------------------------------------------

local function buildTomb(terrain: Terrain, parent: Instance)
	local f = Common.folder("FrostbanesTomb", parent)
	local c = Rime.TOMB
	-- An ice tunnel from the glacier face (north) to the crypt.
	terrain:FillBlock(CFrame.new(c.X, c.Y + 5, -826), Vector3.new(9, 10, 44), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, c.Y - 1, -826), Vector3.new(9, 2, 44), Enum.Material.Ice)
	terrain:FillBall(Vector3.new(c.X, c.Y + 10, c.Z), 14, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, c.Y - 2, c.Z), Vector3.new(28, 4, 28), Enum.Material.Glacier)
	-- The frozen waterfall hiding the entrance: icicle curtains with a gap you can slip through.
	for i = -5, 5 do
		if math.abs(i) > 1 then
			local h = 12 + (i % 3) * 3
			part({ Name = "FrozenFall", Size = Vector3.new(1.4, h, 1.2), CFrame = CFrame.new(c.X + i * 1.5, c.Y + h / 2 + 2, -806), Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.25, Parent = f })
		end
	end
	part({ Name = "FrozenFallTop", Size = Vector3.new(18, 4, 3), CFrame = CFrame.new(c.X, c.Y + 18, -806), Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.2, Parent = f })
	-- Crypt: ice pillars, frozen knights kneeling toward the altar, an empty sword slot.
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		part({ Name = "IcePillar", Size = Vector3.new(2, 16, 2), CFrame = CFrame.new(c.X + math.cos(a) * 10, c.Y + 8, c.Z + math.sin(a) * 10), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.15, Parent = f })
		if i % 2 == 0 then
			local knight = CFrame.lookAt(Vector3.new(c.X + math.cos(a) * 6.5, c.Y, c.Z + math.sin(a) * 6.5), Vector3.new(c.X, c.Y, c.Z))
			part({ Name = "KnightBody", Size = Vector3.new(2.2, 2.6, 1.6), CFrame = knight * CFrame.new(0, 2.2, 0) * CFrame.Angles(math.rad(-15), 0, 0), Color = Color3.fromRGB(190, 220, 240), Material = Enum.Material.Ice, Parent = f })
			part({ Name = "KnightHelm", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = knight * CFrame.new(0, 4, -0.4), Color = Color3.fromRGB(170, 200, 225), Material = Enum.Material.Ice, Parent = f })
			part({ Name = "KnightLegs", Size = Vector3.new(2, 1, 2.4), CFrame = knight * CFrame.new(0, 0.5, 0.3), Color = Color3.fromRGB(190, 220, 240), Material = Enum.Material.Ice, Parent = f })
		end
	end
	local altar = part({ Name = "SwordAltar", Size = Vector3.new(4, 3, 7), CFrame = CFrame.new(c.X, c.Y + 1.5, c.Z - 6), Color = Color3.fromRGB(120, 150, 180), Material = Enum.Material.Slate, Parent = f })
	part({ Name = "SwordSlot", Size = Vector3.new(0.8, 0.1, 5.5), CFrame = CFrame.new(c.X, c.Y + 3.05, c.Z - 6), Color = Color3.fromRGB(90, 220, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	light(altar, Color3.fromRGB(90, 210, 255), 28, 2)
	emitter(altar, { Texture = Common.SPARKLE, Color = ColorSequence.new(Color3.fromRGB(150, 230, 255)), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(1, 2), Rate = 12, Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180) })
	Common.sign(f, Vector3.new(c.X, c.Y + 12, c.Z - 6), "IT WILL RETURN", nil, Color3.fromRGB(140, 220, 255), 12)
	return {
		Spawn = { Area = "Rime", Position = Vector3.new(c.X + 2, c.Y, c.Z + 2), MinRarity = "Legendary", Secret = "frostbane_tomb" },
		Avoid = { Vector2.new(c.X, c.Z), 18 },
	}
end

-- THE FROZEN SHIP (secret) ----------------------------------------------------------------

local function buildShip(terrain: Terrain, parent: Instance, rng: Random)
	local f = Common.folder("FrozenShip", parent)
	local c = Rime.SHIP
	local hull = CFrame.new(c) * CFrame.Angles(0, math.rad(20), math.rad(-6))
	terrain:FillBlock(hull * CFrame.new(0, 4.5, 0), Vector3.new(9, 8, 28), Enum.Material.Air)
	local plank = FROST_WOOD
	part({ Name = "HullFloor", Size = Vector3.new(10, 1, 30), CFrame = hull * CFrame.new(0, 0.5, 0), Color = plank, Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "HullWall", Size = Vector3.new(1, 8, 30), CFrame = hull * CFrame.new(-5, 4.5, 0), Color = plank, Material = Enum.Material.WoodPlanks, Parent = f })
	-- The east wall is broken open: two pieces with a gap in the middle.
	for _, z in { -9.5, 9.5 } do
		part({ Name = "HullWall", Size = Vector3.new(1, 8, 11), CFrame = hull * CFrame.new(5, 4.5, z), Color = plank, Material = Enum.Material.WoodPlanks, Parent = f })
	end
	part({ Name = "HullDeck", Size = Vector3.new(11, 1, 30), CFrame = hull * CFrame.new(0, 9, 0), Color = plank, Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "Bow", Class = "WedgePart", Size = Vector3.new(11, 9, 8), CFrame = hull * CFrame.new(0, 4.5, -19) * CFrame.Angles(0, math.pi, 0), Color = plank, Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "Stern", Size = Vector3.new(11, 12, 3), CFrame = hull * CFrame.new(0, 6, 16.5), Color = plank, Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "Mast", Size = Vector3.new(1.2, 14, 1.2), CFrame = hull * CFrame.new(0, 15, -3) * CFrame.Angles(math.rad(12), 0, math.rad(8)), Color = plank, Material = Enum.Material.Wood, Parent = f })
	part({ Name = "Sail", Size = Vector3.new(9, 6, 0.2), CFrame = hull * CFrame.new(0.8, 18, -2) * CFrame.Angles(math.rad(12), 0, math.rad(20)), Color = Color3.fromRGB(210, 220, 225), Material = Enum.Material.Fabric, Transparency = 0.15, CanCollide = false, Parent = f })
	-- Ice encasing the bow and stern, icicles hanging off the deck.
	part({ Name = "IceBlock", Size = Vector3.new(16, 13, 12), CFrame = hull * CFrame.new(0, 5, -18), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.45, Parent = f })
	part({ Name = "IceBlock", Size = Vector3.new(16, 14, 8), CFrame = hull * CFrame.new(0, 6, 17), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.45, Parent = f })
	for i = -3, 3 do
		local h = rng:NextNumber(1.5, 3.5)
		part({ Name = "Icicle", Class = "WedgePart", Size = Vector3.new(0.6, h, 0.6), CFrame = hull * CFrame.new(5.6, 8.5 - h / 2, i * 3.5) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(220, 245, 255), Material = Enum.Material.Glass, CanCollide = false, Parent = f })
	end
	-- Inside: the captain's lantern and his chest.
	local lantern = part({ Name = "HoldLantern", Size = Vector3.new(0.8, 1.1, 0.8), CFrame = hull * CFrame.new(0, 7.8, 0), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
	light(lantern, Color3.fromRGB(255, 190, 120), 16, 1.2)
	Props.Crate(f, hull * CFrame.new(-3, 2, 8), 2.2)
	Props.Barrel(f, hull * CFrame.new(-3, 1, -8))
	return {
		Spawn = { Area = "Rime", Position = (hull * CFrame.new(1, 1, 1)).Position, MinRarity = "Epic", Secret = "frozen_ship" },
		Avoid = { Vector2.new(c.X, c.Z), 26 },
	}
end

-- SETTLEMENTS -----------------------------------------------------------------------------

local function buildStation(parent: Instance)
	local f = Common.folder("GlacierStation", parent)
	local c = Vector3.new(120, TOP, -915)
	for i, off in { Vector3.new(-18, 0, 7), Vector3.new(17, 0, -10) } do
		local p = c + off
		part({ Name = "Hut", Size = Vector3.new(10, 6, 7), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, i * 0.3, 0), Color = Color3.fromRGB(200, 70, 50), Material = Enum.Material.Metal, Parent = f })
		part({ Name = "HutRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10.4, 7.4, 7.4), CFrame = CFrame.new(p + Vector3.new(0, 6, 0)) * CFrame.Angles(0, i * 0.3, 0), Color = SNOW, Material = Enum.Material.Snow, Parent = f })
		local window = part({ Name = "HutWindow", Size = Vector3.new(2.4, 1.6, 0.2), CFrame = CFrame.new(p + Vector3.new(0, 3.5, -3.6)) * CFrame.Angles(0, i * 0.3, 0), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		light(window, Color3.fromRGB(255, 210, 150), 16, 1, true)
	end
	part({ Name = "RadioMast", Size = Vector3.new(0.6, 22, 0.6), CFrame = CFrame.new(c + Vector3.new(0, 11, 19)), Color = METAL, Material = Enum.Material.Metal, Parent = f })
	local beacon = part({ Name = "MastBeacon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(c + Vector3.new(0, 22.5, 19)), Color = Color3.fromRGB(255, 50, 50), Material = Enum.Material.Neon, Parent = f })
	light(beacon, Color3.fromRGB(255, 60, 60), 24, 1.2)
	for _, off in { Vector3.new(20, 0, 4), Vector3.new(-19, 0, -9) } do
		part({ Name = "FlagPole", Size = Vector3.new(0.3, 8, 0.3), CFrame = CFrame.new(c + off + Vector3.new(0, 4, 0)), Color = METAL, Material = Enum.Material.Metal, Parent = f })
		part({ Name = "Flag", Size = Vector3.new(0.1, 1.6, 2.6), CFrame = CFrame.new(c + off + Vector3.new(0, 7.2, 1.3)), Color = Color3.fromRGB(230, 120, 30), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	end
	part({ Name = "Sled", Size = Vector3.new(2.4, 0.6, 6), CFrame = CFrame.new(c + Vector3.new(7, 0.5, 19)) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(170, 60, 40), Material = Enum.Material.WoodPlanks, Parent = f })
	Common.sign(f, c + Vector3.new(0, 16, -14), "GLACIER STATION", "Dangerous exit • +50% cash", Color3.fromRGB(255, 190, 150))
	return { Vector2.new(c.X, c.Z), 28 }
end

local function buildIgloos(parent: Instance, rng: Random)
	local f = Common.folder("IglooVillage", parent)
	local c = Vector3.new(-60, TOP, -990)
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi + 0.3
		local p = c + Vector3.new(math.cos(a) * 14, 0, math.sin(a) * 14)
		local size = rng:NextNumber(9, 12)
		part({ Name = "Igloo", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(p), Color = SNOW, Material = Enum.Material.Snow, Parent = f })
		local door = CFrame.lookAt(p, Vector3.new(c.X, p.Y, c.Z)) * CFrame.new(0, 1.2, -size / 2)
		part({ Name = "IglooDoor", Size = Vector3.new(3, 3.2, 3), CFrame = door, Color = SNOW, Material = Enum.Material.Snow, Parent = f })
		part({ Name = "IglooDark", Size = Vector3.new(2, 2.4, 0.2), CFrame = door * CFrame.new(0, -0.2, -1.55), Color = Color3.fromRGB(30, 40, 55), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = f })
	end
	local pit = part({ Name = "FirePit", Size = Vector3.new(3, 0.6, 3), CFrame = CFrame.new(c + Vector3.new(0, 0.3, 0)), Color = Color3.fromRGB(60, 50, 50), Material = Enum.Material.Slate, Parent = f })
	local fire = Instance.new("Fire")
	fire.Size = 4
	fire.Heat = 7
	fire.Parent = pit
	light(pit, Color3.fromRGB(255, 160, 80), 22, 1.4)
	for _, x in { -2, 2 } do
		part({ Name = "RackPost", Size = Vector3.new(0.4, 4, 0.4), CFrame = CFrame.new(c + Vector3.new(x, 2, 6)), Color = FROST_WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	for i = -1, 1 do
		part({ Name = "DriedFish", Size = Vector3.new(0.3, 1.4, 0.6), CFrame = CFrame.new(c + Vector3.new(i * 1.2, 2.8, 6)), Color = Color3.fromRGB(200, 170, 120), Material = Enum.Material.SmoothPlastic, CanCollide = false, Parent = f })
	end
	return { Vector2.new(c.X, c.Z), 24 }
end

local function buildMammoth(parent: Instance)
	local f = Common.folder("FrozenMammoth", parent)
	local c = Vector3.new(80, TOP, -985)
	local fur = Color3.fromRGB(110, 80, 60)
	local cf = CFrame.new(c) * CFrame.Angles(0, math.rad(30), 0)
	part({ Name = "MammothBody", Shape = Enum.PartType.Ball, Size = Vector3.new(10, 10, 10), CFrame = cf * CFrame.new(0, 7, 0), Color = fur, Material = Enum.Material.Fabric, Parent = f })
	part({ Name = "MammothHead", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = cf * CFrame.new(0, 9, -6), Color = fur, Material = Enum.Material.Fabric, Parent = f })
	for _, x in { -1, 1 } do
		part({ Name = "Tusk", Size = Vector3.new(0.8, 0.8, 7), CFrame = cf * CFrame.new(x * 1.6, 6.5, -9) * CFrame.Angles(math.rad(25), math.rad(x * 10), 0), Color = Color3.fromRGB(240, 230, 210), Material = Enum.Material.Marble, Parent = f })
		for _, z in { -2.5, 2.5 } do
			part({ Name = "MammothLeg", Size = Vector3.new(2.4, 5, 2.4), CFrame = cf * CFrame.new(x * 2.6, 2.5, z), Color = fur, Material = Enum.Material.Fabric, Parent = f })
		end
	end
	part({ Name = "MammothTrunk", Size = Vector3.new(1.4, 6, 1.4), CFrame = cf * CFrame.new(0, 6, -8.5) * CFrame.Angles(math.rad(15), 0, 0), Color = fur, Material = Enum.Material.Fabric, Parent = f })
	part({ Name = "IceCoffin", Size = Vector3.new(16, 16, 22), CFrame = cf * CFrame.new(0, 7.5, -1), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.5, Parent = f })
	return { Vector2.new(c.X, c.Z), 16 }
end

-- LANDMARKS -------------------------------------------------------------------------------

Rime.HEART = Vector3.new(-88, TOP, -915)
Rime.LAKE = { X = -145, Z = -985, R = 22 }
Rime.ARCHES = { { Z = -900, X = -3 }, { Z = -1003, X = 0 } }

-- A serac: a leaning tower of blue ice, stacked from two or three blocks.
local function serac(parent: Instance, ground: Vector3, rng: Random, scale: number)
	local tilt = CFrame.new(ground) * CFrame.Angles(math.rad(rng:NextNumber(-10, 10)), rng:NextNumber(0, 2 * math.pi), math.rad(rng:NextNumber(-10, 10)))
	local h = rng:NextNumber(10, 18) * scale
	local w = rng:NextNumber(4, 7) * scale
	part({ Name = "Serac", Size = Vector3.new(w, h, w * 0.8), CFrame = tilt * CFrame.new(0, h / 2 - 2, 0), Color = DEEP_ICE:Lerp(ICE, rng:NextNumber(0, 0.5)), Material = Enum.Material.Glacier, Parent = parent })
	local h2 = h * rng:NextNumber(0.4, 0.7)
	part({ Name = "SeracTop", Class = "WedgePart", Size = Vector3.new(w * 0.8, h2, w * 0.7), CFrame = tilt * CFrame.new(0, h - 2 + h2 / 2, 0) * CFrame.Angles(0, if rng:NextNumber() > 0.5 then 0 else math.pi, 0), Color = ICE, Material = Enum.Material.Glacier, Parent = parent })
	part({ Name = "SeracSnow", Size = Vector3.new(w + 0.6, 1, w * 0.8 + 0.6), CFrame = tilt * CFrame.new(0, h - 2, 0), Color = SNOW, Material = Enum.Material.Snow, CanCollide = false, Parent = parent })
	if rng:NextNumber() < 0.6 then
		local side = rng:NextNumber(3, 6) * scale
		part({ Name = "SeracShard", Size = Vector3.new(side * 0.6, side * 1.6, side * 0.6), CFrame = tilt * CFrame.new(w * 0.7, side * 0.6 - 1.5, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color = Color3.fromRGB(150, 210, 245), Material = Enum.Material.Glass, Transparency = 0.25, Parent = parent })
	end
end

local function buildSeracFields(parent: Instance, groundAt, rng: Random, avoid)
	local f = Common.folder("SeracFields", parent)
	-- The fields hug the glacier's sides, leaving the middle open to run through.
	local bounds = { MinX = -205, MaxX = 205, MinZ = -1000, MaxZ = -838 }
	Common.scatter(rng, 26, 500, bounds, function(x, z)
		if math.abs(x) < 70 or Zones.AreaId(Vector3.new(x, TOP, z)) ~= "Rime" or Common.tooClose(avoid, x, z, 4) or nearCrevasse(x, z, 8) then
			return false
		end
		return groundAt(x, z, 120).Y > TOP - 6
	end, function(x, z)
		local g = groundAt(x, z, 120)
		for i = 1, rng:NextInteger(2, 4) do
			local at = if i == 1 then g else groundAt(x + rng:NextNumber(-7, 7), z + rng:NextNumber(-7, 7), 120)
			serac(f, at, rng, if i == 1 then rng:NextNumber(1.1, 1.6) else rng:NextNumber(0.6, 1))
		end
		table.insert(avoid, { Vector2.new(x, z), 12 })
	end)
end

-- THE HEART OF THE RIME: a colossal crystal frozen mid-rise, broken ice pillars around it.
local function buildHeart(parent: Instance, rng: Random)
	local f = Common.folder("HeartOfTheRime", parent)
	local c = Rime.HEART
	part({ Name = "HeartBase", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2, 22, 22), CFrame = CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = DEEP_ICE, Material = Enum.Material.Glacier, Parent = f })
	local core = part({ Name = "HeartCrystal", Size = Vector3.new(6, 26, 6), CFrame = CFrame.new(c + Vector3.new(0, 16, 0)) * CFrame.Angles(math.rad(6), math.rad(30), math.rad(-5)), Color = GLOW, Material = Enum.Material.Glass, Transparency = 0.15, Parent = f })
	part({ Name = "HeartGlow", Size = Vector3.new(2.4, 20, 2.4), CFrame = core.CFrame, Color = Color3.fromRGB(170, 240, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		local h = rng:NextNumber(8, 14)
		part({ Name = "HeartShard", Size = Vector3.new(2.6, h, 2.6), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 4.5, h / 2 + 1, math.sin(a) * 4.5)) * CFrame.Angles(math.cos(a) * 0.35, a, math.sin(a) * 0.35), Color = ICE, Material = Enum.Material.Glass, Transparency = 0.2, Parent = f })
	end
	-- Broken pillars in a ring: whoever built this, it wasn't built to hold it.
	for i = 1, 7 do
		local a = i / 7 * 2 * math.pi + 0.2
		local h = if i % 3 == 0 then 3 else rng:NextNumber(6, 11)
		part({ Name = "RingPillar", Size = Vector3.new(2.2, h, 2.2), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 16, h / 2, math.sin(a) * 16)) * CFrame.Angles(0, a, math.rad(rng:NextNumber(-6, 6))), Color = Color3.fromRGB(190, 215, 235), Material = Enum.Material.Slate, Parent = f })
	end
	light(core, Color3.fromRGB(120, 220, 255), 40, 1.6)
	emitter(core, { Texture = Common.SPARKLE, Color = ColorSequence.new(Color3.fromRGB(190, 245, 255)), LightEmission = 1, Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(2, 3.5), Rate = 10, Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180), Acceleration = Vector3.new(0, 1.5, 0) })
	return { Vector2.new(c.X, c.Z), 19 }
end

-- A natural arch of ice over the trail.
local function buildArch(parent: Instance, groundAt, info)
	local f = Common.folder("IceArch", parent)
	local span, rise, segments = 26, 22, 9
	local base = Vector3.new(info.X, TOP, info.Z)
	local points = {}
	for i = 0, segments do
		local t = i / segments
		local a = math.pi * t
		local x = info.X - math.cos(a) * span / 2
		local y = groundAt(x, info.Z, 120).Y * (1 - math.sin(a)) + (TOP + rise) * math.sin(a)
		table.insert(points, Vector3.new(x, y, info.Z))
	end
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local thick = 5 - math.sin(math.pi * (i - 0.5) / segments) * 1.8
		part({ Name = "ArchIce", Size = Vector3.new(thick, thick * 0.9, (b - a).Magnitude + 2), CFrame = CFrame.lookAt((a + b) / 2, b), Color = DEEP_ICE:Lerp(ICE, i / #points), Material = Enum.Material.Glacier, Parent = f })
	end
	for _, side in { -1, 1 } do
		part({ Name = "ArchFoot", Size = Vector3.new(7, 6, 7), CFrame = CFrame.new(base + Vector3.new(side * span / 2, 1, 0)) * CFrame.Angles(0, math.rad(20), 0), Color = DEEP_ICE, Material = Enum.Material.Glacier, Parent = f })
	end
	-- Icicles hanging off the crown.
	for i = -2, 2 do
		local len = 4 - math.abs(i) * 0.6
		part({ Name = "Icicle", Class = "WedgePart", Size = Vector3.new(0.7, len, 0.7), CFrame = CFrame.new(info.X + i * 2.2, TOP + rise - 2.6 - len / 2, info.Z) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(220, 245, 255), Material = Enum.Material.Glass, Transparency = 0.2, CanCollide = false, Parent = f })
	end
	return { Vector2.new(info.X, info.Z), 16 }
end

-- THE FROZEN LAKE: a sheet of clear ice over dark water, fish locked mid-swim below it.
local function buildLake(terrain: Terrain, parent: Instance, rng: Random)
	local f = Common.folder("FrozenLake", parent)
	local l = Rime.LAKE
	local c = Vector3.new(l.X, TOP, l.Z)
	terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -4, 0)), 8, l.R, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(c + Vector3.new(0, -9, 0)), 2, l.R + 1, Enum.Material.Glacier)
	cylinderPart(f, c + Vector3.new(0, -7.6, 0), 0.6, l.R * 2, Color3.fromRGB(20, 50, 90), Enum.Material.SmoothPlastic, 0)
	local sheet = cylinderPart(f, c + Vector3.new(0, -0.6, 0), 1.2, l.R * 2 + 1, Color3.fromRGB(170, 225, 250), Enum.Material.Glass, 0.45)
	sheet.CanCollide = true
	for _ = 1, 9 do
		local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(3, l.R - 4)
		local fish = CFrame.new(c + Vector3.new(math.cos(a) * r, rng:NextNumber(-6, -3), math.sin(a) * r)) * CFrame.Angles(0, rng:NextNumber(0, 2 * math.pi), 0)
		local color = if rng:NextNumber() < 0.3 then Color3.fromRGB(255, 170, 80) else Color3.fromRGB(150, 200, 230)
		part({ Name = "FrozenFish", Shape = Enum.PartType.Ball, Size = Vector3.new(0.9, 1, 2.4), CFrame = fish, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = f })
		part({ Name = "FishTail", Class = "WedgePart", Size = Vector3.new(0.2, 1, 1), CFrame = fish * CFrame.new(0, 0, 1.5), Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false, CanQuery = false, Parent = f })
	end
	-- White cracks across the surface.
	for _ = 1, 6 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local len = rng:NextNumber(8, 16)
		local from = c + Vector3.new(math.cos(a) * rng:NextNumber(0, 8), 0.02, math.sin(a) * rng:NextNumber(0, 8))
		part({ Name = "IceCrack", Size = Vector3.new(0.15, 0.05, len), CFrame = CFrame.new(from) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -len / 2), Color = Color3.new(1, 1, 1), Material = Enum.Material.SmoothPlastic, Transparency = 0.3, CanCollide = false, CanQuery = false, Parent = f })
	end
	-- Snowbanks around the shore.
	for i = 1, 10 do
		local a = i / 10 * 2 * math.pi + rng:NextNumber(-0.2, 0.2)
		local w = rng:NextNumber(5, 8)
		part({ Name = "Snowbank", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w * 0.6, w), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * (l.R + 3), -w * 0.1, math.sin(a) * (l.R + 3))), Color = SNOW, Material = Enum.Material.Snow, Parent = f })
	end
	return { Vector2.new(l.X, l.Z), l.R + 6 }
end

-- Glowing ice posts either side of the trail, so it reads from far away (and at night).
local function buildTrailPosts(parent: Instance, groundAt, spine: { Vector2 })
	local f = Common.folder("TrailPosts", parent)
	local count = 0
	for i = 1, #spine - 1 do
		local a, b = spine[i], spine[i + 1]
		if a.Y > -845 then
			continue
		end
		local delta = b - a
		local across = Vector2.new(-delta.Y, delta.X).Unit
		for t = 0, delta.Magnitude - 1, 24 do
			local p = a + delta.Unit * t
			if nearCrevasse(p.X, p.Y, 6) then
				continue
			end
			count += 1
			local side = if count % 2 == 0 then 1 else -1
			local q = p + across * side * 8
			local g = groundAt(q.X, q.Y, 120)
			part({ Name = "TrailPost", Size = Vector3.new(0.8, 4, 0.8), CFrame = CFrame.new(g + Vector3.new(0, 2, 0)) * CFrame.Angles(0, t, math.rad(4)), Color = DEEP_ICE, Material = Enum.Material.Glacier, Parent = f })
			local tip = part({ Name = "TrailGlow", Class = "WedgePart", Size = Vector3.new(0.8, 1.2, 0.8), CFrame = CFrame.new(g + Vector3.new(0, 4.6, 0)), Color = GLOW, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
			if count % 3 == 0 then
				light(tip, GLOW, 14, 1, true)
			end
		end
	end
end

-- THE AURORA: slow curtains of light high over the glacier (Controllers/WorldLife brightens
-- them at night: tag "Aurora").
local function buildAurora(parent: Instance)
	local f = Common.folder("Aurora", parent)
	local curtains = {
		{ Z = -860, Y = 170, Colors = { Color3.fromRGB(80, 255, 170), Color3.fromRGB(90, 220, 255) } },
		{ Z = -925, Y = 185, Colors = { Color3.fromRGB(120, 255, 190), Color3.fromRGB(170, 120, 255) } },
		{ Z = -995, Y = 175, Colors = { Color3.fromRGB(90, 230, 255), Color3.fromRGB(80, 255, 160) } },
	}
	for i, curtain in curtains do
		local anchor = part({ Name = "AuroraAnchor", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(0, curtain.Y, curtain.Z), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = f })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(-240, 0, (i - 2) * 10)
		a0.Parent = anchor
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(240, 0, -(i - 2) * 10)
		a1.Parent = anchor
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Color = ColorSequence.new(curtain.Colors[1], curtain.Colors[2])
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.2, 0.55),
			NumberSequenceKeypoint.new(0.5, 0.4),
			NumberSequenceKeypoint.new(0.8, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		})
		beam.Texture = Common.SMOKE
		beam.TextureMode = Enum.TextureMode.Wrap
		beam.TextureLength = 90
		beam.TextureSpeed = 0.04 * (if i % 2 == 0 then -1 else 1)
		beam.LightEmission = 1
		beam.LightInfluence = 0
		beam.Brightness = 1
		beam.Width0, beam.Width1 = 45, 60
		beam.CurveSize0, beam.CurveSize1 = 90 * (if i % 2 == 0 then 1 else -1), -70 * (if i % 2 == 0 then 1 else -1)
		beam.Segments = 24
		beam.FaceCamera = true
		beam.Parent = anchor
		CollectionService:AddTag(beam, "Aurora")
	end
end

-- THE STARFALL LAUNCH at the glacier tip: Rune Gate (Ascension 3) and the geyser beyond it
-- (the geyser itself is WorldLayout.LaunchPads "Starfall Launch", built by World/Adventure).
local function buildTip(parent: Instance, groundAt)
	local f = Common.folder("GlacierTip", parent)
	local g = groundAt(0, -1028, 120)
	Common.runeGate(f, g, Vector3.new(0, 0, -1), 3, "STARFALL ISLES", Color3.fromRGB(140, 130, 170))
	Common.sign(f, g + Vector3.new(0, 30, 0), "STARFALL ISLES", "★★★★★★★ • ASCENSION 3", Color3.fromRGB(200, 160, 255), 20)
end

-- SCATTER ---------------------------------------------------------------------------------

local function scatter(parent: Instance, groundAt, rng: Random, avoid, spine: { Vector2 })
	local f = Common.folder("RimeScatter", parent)
	local bounds = { MinX = -205, MaxX = 205, MinZ = -1005, MaxZ = -845 }
	local function ok(x: number, z: number): boolean
		if Zones.AreaId(Vector3.new(x, TOP, z)) ~= "Rime" or Common.tooClose(avoid, x, z) or nearCrevasse(x, z, 5) then
			return false
		end
		if Common.distanceToPath(spine, x, z) < 9 then
			return false
		end
		return groundAt(x, z, 120).Y > TOP - 6
	end
	Common.scatter(rng, 22, 400, bounds, ok, function(x, z)
		Props.IceCrystals(f, groundAt(x, z, 120), rng)
		table.insert(avoid, { Vector2.new(x, z), 5 })
	end)
	Common.scatter(rng, 10, 300, bounds, ok, function(x, z)
		Props.DeadTree(f, groundAt(x, z, 120), rng, Color3.fromRGB(200, 215, 230))
		table.insert(avoid, { Vector2.new(x, z), 5 })
	end)
	Common.scatter(rng, 26, 300, bounds, ok, function(x, z)
		local g = groundAt(x, z, 120)
		local w = rng:NextNumber(5, 10)
		part({ Name = "SnowDrift", Shape = Enum.PartType.Ball, Size = Vector3.new(w, w, w), CFrame = CFrame.new(g - Vector3.new(0, w * 0.3, 0)), Color = SNOW, Material = Enum.Material.Snow, Parent = f })
	end)
	Common.scatter(rng, 14, 300, bounds, ok, function(x, z)
		Common.crystals(f, groundAt(x, z, 120), rng, { Color3.fromRGB(120, 210, 255), Color3.fromRGB(180, 240, 255), Color3.fromRGB(90, 160, 255) }, 1.3)
		table.insert(avoid, { Vector2.new(x, z), 5 })
	end)
end

-- Returns { Avoid, Spawns }.
function Rime.Build(terrain: Terrain, parent: Instance, rng: Random, groundAt, spine: { Vector2 })
	local root = Common.folder("Rimeheart", parent)
	local avoid = {}
	local spawns = {}
	-- Keep props off the loot spots and the guardians' homes.
	for _, info in WorldLayout.TreasureSpawns do
		if info.Area == "Rime" then
			table.insert(avoid, { Vector2.new(info.Position.X, info.Position.Z), 6 })
		end
	end
	for _, info in WorldLayout.GuardianSpawns do
		if info.Position.Z < WorldLayout.DeepSouth.RimeStart then
			table.insert(avoid, { Vector2.new(info.Position.X, info.Position.Z), 8 })
		end
	end
	buildClimb(terrain, root)
	buildCrevasses(terrain, root, avoid)
	table.insert(avoid, buildLake(terrain, root, rng))
	table.insert(avoid, buildHeart(root, rng))
	for _, info in Rime.ARCHES do
		table.insert(avoid, buildArch(root, groundAt, info))
	end
	for _, built in { buildTomb(terrain, root), buildShip(terrain, root, rng) } do
		table.insert(spawns, built.Spawn)
		table.insert(avoid, built.Avoid)
	end
	table.insert(avoid, buildStation(root))
	table.insert(avoid, buildIgloos(root, rng))
	table.insert(avoid, buildMammoth(root))
	buildTip(root, groundAt)
	table.insert(avoid, { Vector2.new(0, -1030), 18 })
	buildTrailPosts(root, groundAt, spine)
	buildSeracFields(root, groundAt, rng, avoid)
	scatter(root, groundAt, rng, avoid, spine)
	buildAurora(root)
	-- A steady fall of snow over the whole glacier.
	Common.weather(root, Vector3.new(0, 95, -910), Vector2.new(420, 240), {
		Texture = Common.SPARKLE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		LightEmission = 0.3,
		Size = NumberSequence.new(0.45, 0.3),
		Lifetime = NumberRange.new(8, 11),
		Rate = 90,
		Speed = NumberRange.new(5, 8),
		SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(3, 0, 0),
	})
	return { Avoid = avoid, Spawns = spawns }
end

return Rime
