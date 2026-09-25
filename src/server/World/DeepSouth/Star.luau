-- THE STARFALL ISLES (danger 7, Ascension 3): islands adrift in the sky past the glacier tip.
-- Reached by the Starfall Launch geyser; hop between them with updraft geysers and bridges
-- of light. Your jumps are floaty out here (Controllers/Pads), and falling off means a long
-- drop into the sea (HazardService: you wash up on the glacier tip and drop your loot).
--   Landing (I1) -> Crystal Garden (I2, light bridge) -> Starwell (I5, updraft)
--   Landing -> Moonstone (I3, updraft) -> Skyport (I4, light bridge: the Secret exit)
--   Starwell -> THE OBSERVATORY (I6, updraft; secret) -> light bridge back down to Moonstone
--   Starwell -> a hidden updraft behind the rocks -> THE RIFT (I7, secret) -> bridge back
--   Landing -> the Homeward Bridge down to the glacier tip.

local Common = require(script.Parent.Common)

local Star = {}

local part, cylinder = Common.part, Common.cylinder
local light, emitter = Common.light, Common.emitter

local ROCK = Color3.fromRGB(88, 78, 110)
local MOSS = Color3.fromRGB(150, 120, 210)
local GOLD = Color3.fromRGB(255, 210, 90)
local VIOLET = Color3.fromRGB(190, 120, 255)
local CYAN = Color3.fromRGB(120, 230, 255)
local CRYSTALS = { VIOLET, CYAN, GOLD, Color3.fromRGB(255, 150, 230) }

-- Islands: centre x/z, top height, radius.
Star.ISLES = {
	Landing = { X = 0, Z = -1085, Top = 60, R = 24 },
	Garden = { X = -72, Z = -1120, Top = 72, R = 17 },
	Moonstone = { X = 72, Z = -1122, Top = 80, R = 17 },
	Skyport = { X = 120, Z = -1190, Top = 55, R = 19 },
	Starwell = { X = -60, Z = -1180, Top = 95, R = 17 },
	Observatory = { X = 8, Z = -1218, Top = 120, R = 16 },
	Rift = { X = -122, Z = -1240, Top = 110, R = 10 },
}

local function isle(parent: Instance, info, rng: Random)
	local f = Common.folder("Isle", parent)
	local top = Vector3.new(info.X, info.Top, info.Z)
	cylinder(top - Vector3.new(0, 2, 0), 4, info.R * 2, { Name = "IsleTop", Color = MOSS, Material = Enum.Material.Grass, Parent = f })
	cylinder(top - Vector3.new(0, 4.5, 0), 2, info.R * 2 + 1, { Name = "IsleRim", Color = ROCK, Material = Enum.Material.Slate, Parent = f })
	-- The hanging rock root, narrowing into a point, crystals growing out of it.
	for i = 1, 5 do
		local size = info.R * 2 * (1 - i * 0.16)
		part({ Name = "IsleRoot", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.8, size), CFrame = CFrame.new(top - Vector3.new(rng:NextNumber(-1.5, 1.5), 3 + i * info.R * 0.28, rng:NextNumber(-1.5, 1.5))), Color = ROCK:Lerp(Color3.new(0, 0, 0), i * 0.06), Material = Enum.Material.Slate, Parent = f })
	end
	for _ = 1, 3 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local h = rng:NextNumber(4, 8)
		part({ Name = "HangingCrystal", Size = Vector3.new(h * 0.3, h, h * 0.3), CFrame = CFrame.new(top + Vector3.new(math.cos(a) * info.R * 0.5, -6 - h / 2 - info.R * 0.3, math.sin(a) * info.R * 0.5)) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), 0, math.rad(rng:NextNumber(-20, 20))), Color = CRYSTALS[rng:NextInteger(1, #CRYSTALS)], Material = Enum.Material.Neon, CanCollide = false, Parent = f })
	end
	-- A waterfall pouring off one edge into the sea far below.
	local a = rng:NextNumber(0, 2 * math.pi)
	local edge = top + Vector3.new(math.cos(a) * (info.R + 0.5), -1, math.sin(a) * (info.R + 0.5))
	local fallHeight = info.Top - 2
	local fall = part({ Name = "SkyFall", Size = Vector3.new(3, fallHeight, 1), CFrame = CFrame.lookAt(edge - Vector3.new(0, fallHeight / 2, 0), edge - Vector3.new(0, fallHeight / 2, 0) + Vector3.new(math.cos(a), 0, math.sin(a))), Color = Color3.fromRGB(170, 220, 255), Material = Enum.Material.Glass, Transparency = 0.45, CanCollide = false, CanQuery = false, CastShadow = false, Parent = f })
	emitter(fall, {
		Texture = Common.SMOKE,
		Color = ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new(2, 5),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 5,
		Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Front,
		LightInfluence = 1,
	})
	-- Crystal clusters and a couple of star lamps on top.
	for _ = 1, math.floor(info.R / 6) do
		local b = rng:NextNumber(0, 2 * math.pi)
		local r = rng:NextNumber(info.R * 0.4, info.R * 0.8)
		Common.crystals(f, top + Vector3.new(math.cos(b) * r, 0, math.sin(b) * r), rng, CRYSTALS, 0.9)
	end
	for i = 1, 2 do
		local b = i * math.pi + rng:NextNumber(-0.4, 0.4)
		local p = top + Vector3.new(math.cos(b) * info.R * 0.75, 0, math.sin(b) * info.R * 0.75)
		part({ Name = "LampPost", Size = Vector3.new(0.5, 5, 0.5), CFrame = CFrame.new(p + Vector3.new(0, 2.5, 0)), Color = GOLD, Material = Enum.Material.Metal, Parent = f })
		local orb = part({ Name = "StarLamp", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(p + Vector3.new(0, 5.6, 0)), Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		if i == 1 then
			light(orb, Color3.fromRGB(230, 210, 255), 22, 1.2)
		end
	end
	return f, top
end

local function edgePoint(info, towards: Vector3): Vector3
	local dir = Vector3.new(towards.X - info.X, 0, towards.Z - info.Z).Unit
	return Vector3.new(info.X, info.Top + 0.3, info.Z) + dir * (info.R - 2)
end

-- THE OBSERVATORY (secret): a ruined domed observatory with a giant telescope.
local function buildObservatory(parent: Instance)
	local o = Star.ISLES.Observatory
	local f = Common.folder("Observatory", parent)
	local c = Vector3.new(o.X, o.Top, o.Z)
	cylinder(c + Vector3.new(0, 0.1, 0), 0.2, 20, { Name = "StarMapFloor", Color = Color3.fromRGB(40, 30, 70), Material = Enum.Material.Slate, Parent = f })
	for i = 1, 14 do
		local a = i * 2.4
		local r = (i % 5 + 1) * 1.6
		part({ Name = "StarDot", Size = Vector3.new(0.4, 0.1, 0.4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * r, 0.25, math.sin(a) * r)), Color = GOLD, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	end
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		part({ Name = "Column", Size = Vector3.new(1.4, 12, 1.4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 11, 6, math.sin(a) * 11)), Color = Color3.fromRGB(220, 215, 235), Material = Enum.Material.Marble, Parent = f })
		if i % 2 == 0 then
			part({ Name = "DomeRib", Size = Vector3.new(1, 1, 16), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 6, 15, math.sin(a) * 6)) * CFrame.Angles(0, -a + math.pi / 2, 0) * CFrame.Angles(math.rad(35), 0, 0), Color = Color3.fromRGB(220, 215, 235), Material = Enum.Material.Marble, CanCollide = false, Parent = f })
		end
	end
	part({ Name = "DomeRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 24, 24), CFrame = CFrame.new(c + Vector3.new(0, 12.5, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 195, 220), Material = Enum.Material.Marble, Transparency = 0, CanCollide = false, Parent = f })
	-- The telescope: a brass tube on a mount, aimed at the sky.
	local mount = CFrame.new(c + Vector3.new(-3, 0, 3))
	part({ Name = "TelescopeMount", Size = Vector3.new(2.4, 5, 2.4), CFrame = mount * CFrame.new(0, 2.5, 0), Color = Color3.fromRGB(120, 90, 50), Material = Enum.Material.Metal, Parent = f })
	local aim = mount * CFrame.new(0, 5.5, 0) * CFrame.Angles(math.rad(-55), math.rad(30), 0)
	part({ Name = "TelescopeTube", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 2.6, 2.6), CFrame = aim * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.rad(90), 0), Color = Color3.fromRGB(200, 160, 80), Material = Enum.Material.Metal, Parent = f })
	local lens = part({ Name = "TelescopeLens", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 2.6, 2.6), CFrame = aim * CFrame.new(0, 0, -10) * CFrame.Angles(0, math.rad(90), 0), Color = CYAN, Material = Enum.Material.Neon, Parent = f })
	light(lens, CYAN, 20, 1.2)
	return {
		Spawn = { Area = "Star", Position = c + Vector3.new(3, 0.2, -3), MinRarity = "Epic", Secret = "observatory" },
	}
end

-- THE RIFT (secret): a tear in the sky on a lonely rock.
local function buildRift(parent: Instance)
	local r = Star.ISLES.Rift
	local f = Common.folder("Rift", parent)
	local c = Vector3.new(r.X, r.Top, r.Z)
	local tear = part({ Name = "RiftTear", Size = Vector3.new(0.4, 12, 5), CFrame = CFrame.new(c + Vector3.new(0, 7, 3)) * CFrame.Angles(0, math.rad(30), math.rad(8)), Color = Color3.fromRGB(170, 60, 255), Material = Enum.Material.Neon, Transparency = 0.1, CanCollide = false, Parent = f })
	part({ Name = "RiftCore", Size = Vector3.new(0.5, 10, 2), CFrame = tear.CFrame, Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
	light(tear, Color3.fromRGB(170, 80, 255), 30, 2.5)
	emitter(tear, {
		Texture = Common.SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(200, 120, 255), Color3.fromRGB(120, 230, 255)),
		LightEmission = 1,
		Size = NumberSequence.new(0.8, 0),
		Lifetime = NumberRange.new(1, 2),
		Rate = 30,
		Speed = NumberRange.new(2, 6),
		SpreadAngle = Vector2.new(180, 180),
	})
	return {
		Spawn = { Area = "Star", Position = c + Vector3.new(-2, 0.2, -2), MinRarity = "Legendary", Secret = "the_rift" },
	}
end

-- SKYPORT (Secret exit): a dock with a moored airship.
local function buildSkyport(parent: Instance)
	local s = Star.ISLES.Skyport
	local f = Common.folder("Skyport", parent)
	local c = Vector3.new(s.X, s.Top, s.Z)
	local toward = Vector3.new(s.X + 30, s.Top, s.Z - 10)
	local dock = CFrame.lookAt(c, toward) * CFrame.new(0, 0, -s.R)
	part({ Name = "Dock", Size = Vector3.new(8, 1, 16), CFrame = dock * CFrame.new(0, -0.5, -4), Color = Color3.fromRGB(120, 86, 56), Material = Enum.Material.WoodPlanks, Parent = f })
	local ship = dock * CFrame.new(10, 4, -8)
	part({ Name = "AirshipHull", Size = Vector3.new(6, 4, 16), CFrame = ship, Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "AirshipBalloon", Shape = Enum.PartType.Ball, Size = Vector3.new(14, 14, 14), CFrame = ship * CFrame.new(0, 12, 0), Color = Color3.fromRGB(200, 60, 60), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	for _, z in { -5, 5 } do
		part({ Name = "AirshipRope", Size = Vector3.new(0.2, 8, 0.2), CFrame = ship * CFrame.new(0, 5, z), Color = Color3.fromRGB(170, 140, 100), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	end
	part({ Name = "Propeller", Size = Vector3.new(6, 0.4, 0.8), CFrame = ship * CFrame.new(0, 0, 8.6), Color = GOLD, Material = Enum.Material.Metal, CanCollide = false, Parent = f })
	Common.sign(f, c + Vector3.new(0, 14, 0), "SKYPORT", "Secret exit • +100% cash", Color3.fromRGB(255, 215, 120))
end

local function buildMonolith(parent: Instance)
	local m = Star.ISLES.Moonstone
	local f = Common.folder("Moonstone", parent)
	local c = Vector3.new(m.X - 4, m.Top, m.Z + 4)
	local stone = part({ Name = "Moonstone", Size = Vector3.new(4, 14, 3), CFrame = CFrame.new(c + Vector3.new(0, 7, 0)) * CFrame.Angles(0, math.rad(20), math.rad(4)), Color = Color3.fromRGB(215, 225, 255), Material = Enum.Material.Marble, Parent = f })
	for i = 0, 3 do
		part({ Name = "MoonRune", Size = Vector3.new(1.2, 0.6, 0.2), CFrame = stone.CFrame * CFrame.new(0, 3 - i * 2, -1.55), Color = CYAN, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	end
	light(stone, Color3.fromRGB(200, 220, 255), 20, 1)
end

local function buildWell(parent: Instance)
	local w = Star.ISLES.Starwell
	local f = Common.folder("Starwell", parent)
	local c = Vector3.new(w.X, w.Top, w.Z)
	cylinder(c + Vector3.new(0, 1, 0), 2, 7, { Name = "WellRim", Color = Color3.fromRGB(200, 195, 220), Material = Enum.Material.Marble, Parent = f })
	local beam = cylinder(c + Vector3.new(0, 20, 0), 36, 4, { Name = "StarBeam", Color = Color3.fromRGB(255, 240, 200), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	beam.Transparency = 0.55
	beam.CastShadow = false
	light(beam, Color3.fromRGB(255, 235, 190), 30, 1.5)
	-- Rocks hiding the Rift updraft on the far side.
	for i = 1, 4 do
		local a = math.rad(215) + i * 0.18
		part({ Name = "HidingRock", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 4.5, 5), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 11, 1.5, math.sin(a) * 11)), Color = ROCK, Material = Enum.Material.Slate, Parent = f })
	end
end

-- Returns { Spawns, Avoid } - exact secret spawns.
function Star.Build(parent: Instance, rng: Random)
	local root = Common.folder("StarfallIsles", parent)
	for _, info in Star.ISLES do
		isle(root, info, rng)
	end
	local I = Star.ISLES
	local function link(a, b)
		Common.bridge(root, edgePoint(a, Vector3.new(b.X, 0, b.Z)), edgePoint(b, Vector3.new(a.X, 0, a.Z)), 5, "Light")
	end
	link(I.Landing, I.Garden)
	link(I.Moonstone, I.Skyport)
	link(I.Observatory, I.Moonstone)
	link(I.Rift, I.Starwell)
	-- The Homeward Bridge down to the glacier tip.
	Common.bridge(root, edgePoint(I.Landing, Vector3.new(14, 0, -1020)), Vector3.new(14, 41, -1022), 6, "Light")
	buildMonolith(root)
	buildWell(root)
	buildSkyport(root)
	local spawns = {}
	for _, built in { buildObservatory(root), buildRift(root) } do
		table.insert(spawns, built.Spawn)
	end
	-- Stardust drifting through the sky, and a few meteor streaks frozen in the distance.
	Common.weather(root, Vector3.new(0, 170, -1150), Vector2.new(320, 240), {
		Texture = Common.SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 240, 200), Color3.fromRGB(200, 170, 255)),
		LightEmission = 1,
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(8, 12),
		Rate = 40,
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(40, 40),
	})
	for _ = 1, 3 do
		local p = Vector3.new(rng:NextNumber(-150, 150), rng:NextNumber(170, 230), rng:NextNumber(-1300, -1180))
		part({ Name = "MeteorTrail", Size = Vector3.new(0.6, 0.6, 40), CFrame = CFrame.new(p) * CFrame.Angles(math.rad(-35), rng:NextNumber(0, 6.28), 0), Color = Color3.fromRGB(255, 220, 160), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false, CastShadow = false, Parent = root })
	end
	return { Spawns = spawns, Avoid = {} }
end

return Star
