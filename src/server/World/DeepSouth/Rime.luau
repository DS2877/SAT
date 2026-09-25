-- RIMEHEART (danger 6, Ascension 2): a dead white glacier plateau.
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

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Util.Zones)
local WorldLayout = require(Shared.Config.WorldLayout)

local Props = require(script.Parent.Parent.Props)
local Common = require(script.Parent.Common)

local Rime = {}

local part = Common.part
local light, emitter = Common.light, Common.emitter

local ICE = Color3.fromRGB(170, 220, 245)
local DEEP_ICE = Color3.fromRGB(90, 160, 220)
local SNOW = Color3.fromRGB(245, 250, 255)
local FROST_WOOD = Color3.fromRGB(150, 160, 170)
local METAL = Color3.fromRGB(120, 125, 135)

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
	for i, off in { Vector3.new(-9, 0, 4), Vector3.new(8, 0, -6) } do
		local p = c + off
		part({ Name = "Hut", Size = Vector3.new(10, 6, 7), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, i * 0.3, 0), Color = Color3.fromRGB(200, 70, 50), Material = Enum.Material.Metal, Parent = f })
		part({ Name = "HutRoof", Shape = Enum.PartType.Cylinder, Size = Vector3.new(10.4, 7.4, 7.4), CFrame = CFrame.new(p + Vector3.new(0, 6, 0)) * CFrame.Angles(0, i * 0.3, 0), Color = SNOW, Material = Enum.Material.Snow, Parent = f })
		local window = part({ Name = "HutWindow", Size = Vector3.new(2.4, 1.6, 0.2), CFrame = CFrame.new(p + Vector3.new(0, 3.5, -3.6)) * CFrame.Angles(0, i * 0.3, 0), Color = Color3.fromRGB(255, 220, 150), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		light(window, Color3.fromRGB(255, 210, 150), 16, 1, true)
	end
	part({ Name = "RadioMast", Size = Vector3.new(0.6, 22, 0.6), CFrame = CFrame.new(c + Vector3.new(0, 11, 10)), Color = METAL, Material = Enum.Material.Metal, Parent = f })
	local beacon = part({ Name = "MastBeacon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.2, 1.2), CFrame = CFrame.new(c + Vector3.new(0, 22.5, 10)), Color = Color3.fromRGB(255, 50, 50), Material = Enum.Material.Neon, Parent = f })
	light(beacon, Color3.fromRGB(255, 60, 60), 24, 1.2)
	for _, off in { Vector3.new(14, 0, 4), Vector3.new(-14, 0, -8) } do
		part({ Name = "FlagPole", Size = Vector3.new(0.3, 8, 0.3), CFrame = CFrame.new(c + off + Vector3.new(0, 4, 0)), Color = METAL, Material = Enum.Material.Metal, Parent = f })
		part({ Name = "Flag", Size = Vector3.new(0.1, 1.6, 2.6), CFrame = CFrame.new(c + off + Vector3.new(0, 7.2, 1.3)), Color = Color3.fromRGB(230, 120, 30), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	end
	part({ Name = "Sled", Size = Vector3.new(2.4, 0.6, 6), CFrame = CFrame.new(c + Vector3.new(4, 0.5, 12)) * CFrame.Angles(0, 0.4, 0), Color = Color3.fromRGB(170, 60, 40), Material = Enum.Material.WoodPlanks, Parent = f })
	Common.sign(f, c + Vector3.new(0, 16, -14), "GLACIER STATION", "Dangerous exit • +50% cash", Color3.fromRGB(255, 190, 150))
	return { Vector2.new(c.X, c.Z), 24 }
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
	Common.scatter(rng, 30, 400, bounds, ok, function(x, z)
		Props.IceCrystals(f, groundAt(x, z, 120), rng)
		table.insert(avoid, { Vector2.new(x, z), 5 })
	end)
	Common.scatter(rng, 18, 300, bounds, ok, function(x, z)
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
	buildClimb(terrain, root)
	buildCrevasses(terrain, root, avoid)
	for _, built in { buildTomb(terrain, root), buildShip(terrain, root, rng) } do
		table.insert(spawns, built.Spawn)
		table.insert(avoid, built.Avoid)
	end
	table.insert(avoid, buildStation(root))
	table.insert(avoid, buildIgloos(root, rng))
	table.insert(avoid, buildMammoth(root))
	buildTip(root, groundAt)
	table.insert(avoid, { Vector2.new(0, -1030), 18 })
	scatter(root, groundAt, rng, avoid, spine)
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
