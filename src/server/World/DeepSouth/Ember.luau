-- THE ASHEN PASS + EMBERFALL (danger 5, Ascension 1).
--   * The Ashen Pass: a basalt ridge from the back of the Waterfall Mountain, down across the
--     Sundering channel, braziers burning along it. The Ember Gate (Rune Gate) at its foot.
--   * Mount Cinder: an active volcano. The Cinder Vent geyser flings you onto its rim; inside
--     the crater an obsidian island in a lava lake holds the CALDERA VAULT (secret). Ledges
--     spiral back up the crater wall.
--   * Lava rivers pour off the volcano to the sea (the floor IS lava: HazardService). The road
--     crosses on the Obsidian Bridge; elsewhere, stepping stones.
--   * Ashen Camp (Safe exit), the Obsidian Temple, the Lava Outpost (Dangerous exit), the old
--     mining camp whose tunnel leads under the volcano to the OLD KING'S FORGE (secret), and
--     the Steamfields: hot springs where the lava meets the ice.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Zones = require(Shared.Util.Zones)

local Props = require(script.Parent.Parent.Props)
local Common = require(script.Parent.Common)

local Ember = {}

local part, cylinder = Common.part, Common.cylinder
local light, emitter = Common.light, Common.emitter

local BASALT = Color3.fromRGB(46, 40, 42)
local ASH = Color3.fromRGB(88, 80, 78)
local OBSIDIAN = Color3.fromRGB(24, 18, 30)
local EMBER = Color3.fromRGB(255, 110, 30)
local RUST = Color3.fromRGB(110, 60, 40)
local WOOD = Color3.fromRGB(96, 66, 42)

Ember.CINDER = Vector3.new(-100, 0, -650) -- Mount Cinder's centre (ground level)
Ember.CINDER_TOP = 110 -- rim height
Ember.CRATER_FLOOR = 96
Ember.FORGE = Vector3.new(-100, 10, -700) -- the Old King's Forge (floor)
Ember.PASS_TOP = Vector3.new(50, 90, -380)
Ember.PASS_FOOT = Vector3.new(28, 11, -548)

-- Lava rivers (world x, z), from the volcano to the sea.
Ember.RIVERS = {
	{ Vector2.new(-15, -625), Vector2.new(25, -605), Vector2.new(75, -640), Vector2.new(125, -690), Vector2.new(185, -705), Vector2.new(235, -705) },
	{ Vector2.new(-150, -598), Vector2.new(-180, -566), Vector2.new(-222, -540) },
}

-- THE ASHEN PASS --------------------------------------------------------------------------

function Ember.BuildPass(terrain: Terrain, parent: Instance, rng: Random)
	local f = Common.folder("AshenPass", parent)
	local a, b = Ember.PASS_TOP, Ember.PASS_FOOT
	local steps = 44
	local gatePoint, gateDir
	for i = 0, steps do
		local t = i / steps
		local x = a.X + (b.X - a.X) * t + math.sin(t * math.pi) * 14
		local z = a.Z + (b.Z - a.Z) * t
		local y = a.Y + (b.Y - a.Y) * t
		-- A basalt column from the sea floor up to the path, then an ash-grey road on top.
		terrain:FillBlock(CFrame.new(x, (y - 18) / 2, z), Vector3.new(30, y + 18, 6), Enum.Material.Basalt)
		terrain:FillBlock(CFrame.new(x, y - 1, z), Vector3.new(12, 2, 6), Enum.Material.Ground)
		local nextT = math.min(1, t + 1 / steps)
		local dir = Vector3.new(a.X + (b.X - a.X) * nextT + math.sin(nextT * math.pi) * 14 - x, 0, (b.Z - a.Z) / steps)
		if not gatePoint and z <= -496 then
			gatePoint, gateDir = Vector3.new(x, y, z), dir
		end
		-- Braziers and basalt spires alternate along the edges.
		if i % 6 == 3 then
			for _, side in { -1, 1 } do
				local right = dir.Unit:Cross(Vector3.yAxis)
				local p = Vector3.new(x, y, z) + right * side * 9
				part({ Name = "Brazier", Size = Vector3.new(1.4, 4, 1.4), CFrame = CFrame.new(p + Vector3.new(0, 2, 0)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
				local bowl = part({ Name = "BrazierBowl", Size = Vector3.new(2.6, 0.8, 2.6), CFrame = CFrame.new(p + Vector3.new(0, 4.3, 0)), Color = Color3.fromRGB(70, 60, 56), Material = Enum.Material.Metal, Parent = f })
				local fire = Instance.new("Fire")
				fire.Size = 4
				fire.Heat = 8
				fire.Parent = bowl
				if i % 12 == 3 then
					light(bowl, Color3.fromRGB(255, 140, 60), 22, 1.4)
				end
			end
		elseif i % 6 == 0 and i > 0 and i < steps then
			local right = dir.Unit:Cross(Vector3.yAxis)
			local side = if i % 12 == 0 then 1 else -1
			local p = Vector3.new(x, y - 1, z) + right * side * 12
			local h = rng:NextNumber(8, 16)
			part({ Name = "BasaltSpire", Class = "WedgePart", Size = Vector3.new(3, h, 4), CFrame = CFrame.new(p + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), Color = BASALT, Material = Enum.Material.Basalt, Parent = f })
		end
	end
	Common.sign(f, a + Vector3.new(0, 9, -6), "THE ASHEN PASS", "Emberfall below • Ascension 1", Color3.fromRGB(255, 140, 70))
	if gatePoint then
		Common.runeGate(f, gatePoint, gateDir, 1, "EMBERFALL", BASALT)
		Common.sign(f, gatePoint + Vector3.new(0, 30, 0), "EMBERFALL", "★★★★★☆☆ • ASCENSION 1", EMBER, 20)
	end
end

-- MOUNT CINDER ----------------------------------------------------------------------------

local function buildCinder(terrain: Terrain, parent: Instance, rng: Random)
	local f = Common.folder("MountCinder", parent)
	local c = Ember.CINDER
	local layers = 10
	local h = Ember.CINDER_TOP / layers
	for i = 0, layers - 1 do
		local r = 14 + 80 * (1 - i / layers)
		terrain:FillCylinder(CFrame.new(c.X, i * h + h / 2, c.Z), h, r, if i < 2 then Enum.Material.Rock else Enum.Material.Basalt)
	end
	-- A wide rim, then the crater: a lava lake around an obsidian island.
	terrain:FillCylinder(CFrame.new(c.X, Ember.CINDER_TOP - 2, c.Z), 4, 28, Enum.Material.Basalt)
	local floor = Ember.CRATER_FLOOR
	terrain:FillCylinder(CFrame.new(c.X, floor + 10, c.Z), 20, 19, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(c.X, floor - 1, c.Z), 2, 19, Enum.Material.CrackedLava)
	Common.lava(f, CFrame.new(c.X, floor + 0.5, c.Z), Vector3.new(34, 1, 34), true)
	cylinder(Vector3.new(c.X, floor + 1.5, c.Z), 4, 12, { Name = "ObsidianIsland", Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
	-- Stepping stones from the island to the wall, then ledges spiralling up to the rim.
	for i = 1, 2 do
		cylinder(Vector3.new(c.X + 6 + i * 3.2, floor + 1.2 + i * 0.6, c.Z), 3 + i * 1.2, 3, { Name = "SteppingStone", Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
	end
	for i = 0, 4 do
		local a = math.rad(i * 42)
		local y = floor + 3.6 + i * 3.4
		part({ Name = "CraterLedge", Size = Vector3.new(5, 1.2, 5), CFrame = CFrame.new(c.X + math.cos(a) * 16.5, y, c.Z + math.sin(a) * 16.5) * CFrame.Angles(0, -a, 0), Color = BASALT, Material = Enum.Material.Basalt, Parent = f })
	end
	-- The vault itself: a ring of black pillars and a glowing sigil.
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		part({ Name = "VaultPillar", Size = Vector3.new(0.9, rng:NextNumber(2.5, 4), 0.9), CFrame = CFrame.new(c.X + math.cos(a) * 4.8, floor + 5, c.Z + math.sin(a) * 4.8), Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
	end
	local sigil = cylinder(Vector3.new(c.X, floor + 3.55, c.Z), 0.1, 7, { Name = "Sigil", Color = Color3.fromRGB(255, 70, 40), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	light(sigil, Color3.fromRGB(255, 90, 40), 20, 1.5)
	-- A smoke column you can see from the whole south, and lava tumbling down one flank.
	local vent = part({ Name = "SmokeVent", Size = Vector3.new(20, 1, 20), CFrame = CFrame.new(c.X, Ember.CINDER_TOP + 6, c.Z), Transparency = 1, CanCollide = false, CanQuery = false, Parent = f })
	emitter(vent, {
		Texture = Common.SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(70, 60, 60), Color3.fromRGB(40, 36, 36)),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 10), NumberSequenceKeypoint.new(1, 40) }),
		Lifetime = NumberRange.new(6, 9),
		Rate = 6,
		Speed = NumberRange.new(10, 16),
		SpreadAngle = Vector2.new(12, 12),
		EmissionDirection = Enum.NormalId.Top,
		Acceleration = Vector3.new(3, 1, 0),
		LightInfluence = 1,
	})
	for i = 0, 7 do
		local t = i / 7
		local r = 22 + t * 60
		local y = Ember.CINDER_TOP - t * 88
		part({ Name = "Lavafall", Size = Vector3.new(4 - t, 1, 14), CFrame = CFrame.new(c.X + r * 0.97, y, c.Z + r * 0.24) * CFrame.Angles(0, math.rad(-76), math.rad(52)), Color = EMBER, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	end
end

-- LAVA RIVERS -----------------------------------------------------------------------------

local function carveRiver(terrain: Terrain, parent: Instance, path: { Vector2 }, groundAt, lit: { number })
	local f = Common.folder("LavaRiver", parent)
	local tile = 0
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local delta = b - a
		local steps = math.ceil(delta.Magnitude / 6)
		for s = 0, steps - 1 do
			local p = a + delta * ((s + 0.5) / steps)
			local g = groundAt(p.X, p.Y).Y
			local dir = Vector3.new(delta.X, 0, delta.Y).Unit
			local cf = CFrame.lookAt(Vector3.new(p.X, g, p.Y), Vector3.new(p.X, g, p.Y) + dir)
			terrain:FillBlock(cf * CFrame.new(0, 3, 0), Vector3.new(14, 14, 6.8), Enum.Material.Air)
			terrain:FillBlock(cf * CFrame.new(0, -5, 0), Vector3.new(16, 2, 6.8), Enum.Material.CrackedLava)
			tile += 1
			lit[1] += 1
			Common.lava(f, cf * CFrame.new(0, -3.6, 0), Vector3.new(12, 1, 6.9), tile % 5 == 1)
		end
	end
end

-- SETTLEMENTS -----------------------------------------------------------------------------

local function tent(parent: Instance, cf: CFrame, color: Color3)
	for _, side in { -1, 1 } do
		part({ Name = "Tent", Size = Vector3.new(0.3, 6, 8), CFrame = cf * CFrame.new(side * 2.1, 2.5, 0) * CFrame.Angles(0, 0, math.rad(side * 36)), Color = color, Material = Enum.Material.Fabric, Parent = parent })
	end
end

local function buildAshenCamp(parent: Instance, groundAt)
	local f = Common.folder("AshenCamp", parent)
	local c = groundAt(22, -565)
	for i, off in { Vector3.new(-14, 0, -6), Vector3.new(-12, 0, 10), Vector3.new(14, 0, 12) } do
		local p = c + off
		tent(f, CFrame.lookAt(p, c), if i == 2 then Color3.fromRGB(150, 40, 30) else Color3.fromRGB(60, 50, 50))
	end
	for _, off in { Vector3.new(-18, 0, 0), Vector3.new(18, 0, -4) } do
		local p = c + off
		part({ Name = "BannerPole", Size = Vector3.new(0.5, 12, 0.5), CFrame = CFrame.new(p + Vector3.new(0, 6, 0)), Color = BASALT, Material = Enum.Material.Metal, Parent = f })
		part({ Name = "Banner", Size = Vector3.new(0.15, 5, 3), CFrame = CFrame.new(p + Vector3.new(0, 9, 1.6)), Color = Color3.fromRGB(170, 40, 30), Material = Enum.Material.Fabric, CanCollide = false, Parent = f })
	end
	for i = 1, 4 do
		Props.Crate(f, CFrame.new(c + Vector3.new(8 + (i % 2) * 2.4, 1, -12 + i * 1.3)))
	end
	Common.sign(f, c + Vector3.new(0, 11, -18), "ASHEN CAMP", "Safe exit • rest before the fire", Color3.fromRGB(255, 190, 110))
	return { Vector2.new(c.X, c.Z), 26 }
end

local function buildTemple(parent: Instance, groundAt, rng: Random)
	local f = Common.folder("ObsidianTemple", parent)
	local c = groundAt(115, -560)
	part({ Name = "TempleFloor", Size = Vector3.new(30, 2, 30), CFrame = CFrame.new(c + Vector3.new(0, 1, 0)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
	for _, side in { -1, 1 } do
		part({ Name = "TempleStep", Size = Vector3.new(10, 1, 3), CFrame = CFrame.new(c + Vector3.new(0, 0.5, side * 16.5)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
	end
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		local h = if i % 3 == 0 then rng:NextNumber(4, 7) else rng:NextNumber(12, 16)
		part({ Name = "ObsidianPillar", Size = Vector3.new(2.4, h, 2.4), CFrame = CFrame.new(c + Vector3.new(math.cos(a) * 11, 2 + h / 2, math.sin(a) * 11)) * CFrame.Angles(0, a, math.rad(rng:NextNumber(-4, 4))), Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
	end
	part({ Name = "FallenPillar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(14, 2.4, 2.4), CFrame = CFrame.new(c + Vector3.new(-6, 3.2, 8)) * CFrame.Angles(0, math.rad(35), 0), Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
	local altar = part({ Name = "Altar", Size = Vector3.new(6, 2, 6), CFrame = CFrame.new(c + Vector3.new(0, 3, 0)), Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
	local rune = cylinder(c + Vector3.new(0, 2.06, 0), 0.1, 18, { Name = "RuneCircle", Color = Color3.fromRGB(255, 60, 40), Material = Enum.Material.Neon, Transparency = 0.3, CanCollide = false, CanQuery = false, Parent = f })
	light(altar, Color3.fromRGB(255, 70, 40), 26, 1.6)
	emitter(rune, { Texture = Common.SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 120, 60)), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(1, 2), Rate = 10, Speed = NumberRange.new(2, 4), EmissionDirection = Enum.NormalId.Right })
	return { Vector2.new(c.X, c.Z), 24 }
end

local function buildOutpost(parent: Instance, groundAt)
	local f = Common.folder("LavaOutpost", parent)
	local c = groundAt(140, -740)
	local size = 36
	-- Basalt walls with a gate to the north (the road), towers on the corners.
	for _, side in { -1, 1 } do
		part({ Name = "Wall", Size = Vector3.new(2, 8, size), CFrame = CFrame.new(c + Vector3.new(side * size / 2, 4, 0)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
		part({ Name = "Wall", Size = Vector3.new(size, 8, 2), CFrame = CFrame.new(c + Vector3.new(0, 4, size / 2)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
		part({ Name = "Wall", Size = Vector3.new(size / 2 - 5, 8, 2), CFrame = CFrame.new(c + Vector3.new(side * (size / 4 + 2.5), 4, -size / 2)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
	end
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			local p = c + Vector3.new(x * size / 2, 0, z * size / 2)
			part({ Name = "Tower", Size = Vector3.new(6, 14, 6), CFrame = CFrame.new(p + Vector3.new(0, 7, 0)), Color = BASALT:Lerp(ASH, 0.3), Material = Enum.Material.Slate, Parent = f })
			local bowl = part({ Name = "TowerFire", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(p + Vector3.new(0, 14.5, 0)), Color = RUST, Material = Enum.Material.Metal, Parent = f })
			local fire = Instance.new("Fire")
			fire.Size = 5
			fire.Heat = 10
			fire.Parent = bowl
		end
	end
	-- The forge trough and hanging cages in the courtyard.
	local trough = part({ Name = "ForgeTrough", Size = Vector3.new(10, 1, 3), CFrame = CFrame.new(c + Vector3.new(-8, 1.2, 10)), Color = EMBER, Material = Enum.Material.Neon, CanCollide = false, Parent = f })
	part({ Name = "TroughStone", Size = Vector3.new(11, 1.5, 4), CFrame = CFrame.new(c + Vector3.new(-8, 0.4, 10)), Color = BASALT, Material = Enum.Material.Slate, Parent = f })
	light(trough, EMBER, 22, 1.5)
	for i = 0, 1 do
		local p = c + Vector3.new(10 + i * 5, 0, 8)
		part({ Name = "GibbetPost", Size = Vector3.new(0.6, 10, 0.6), CFrame = CFrame.new(p + Vector3.new(0, 5, 0)), Color = RUST, Material = Enum.Material.Metal, Parent = f })
		part({ Name = "Cage", Size = Vector3.new(2.4, 3.4, 2.4), CFrame = CFrame.new(p + Vector3.new(1.6, 7, 0)), Color = RUST, Material = Enum.Material.CorrodedMetal, Transparency = 0.5, Parent = f })
	end
	Common.sign(f, c + Vector3.new(0, 18, -size / 2), "LAVA OUTPOST", "Dangerous exit • +50% cash", Color3.fromRGB(255, 160, 80))
	return { Vector2.new(c.X, c.Z), size * 0.75 }
end

local function buildMiningCamp(parent: Instance, groundAt, rng: Random)
	local f = Common.folder("MiningCamp", parent)
	local c = groundAt(-150, -735)
	for i, off in { Vector3.new(-6, 0, -6), Vector3.new(8, 0, 6) } do
		local p = c + off
		part({ Name = "Shack", Size = Vector3.new(8, 6, 7), CFrame = CFrame.new(p + Vector3.new(0, 3, 0)) * CFrame.Angles(0, i * 0.5, 0), Color = WOOD:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.WoodPlanks, Parent = f })
		part({ Name = "ShackRoof", Size = Vector3.new(9, 0.6, 8), CFrame = CFrame.new(p + Vector3.new(0, 6.4, 0)) * CFrame.Angles(0, i * 0.5, math.rad(12)), Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = f })
	end
	-- Rails from the camp east to the old tunnel mouth under the volcano.
	local mouth = Vector3.new(Ember.FORGE.X, c.Y, -744)
	local delta = Vector3.new(mouth.X - c.X, 0, mouth.Z - c.Z)
	for _, dx in { -0.9, 0.9 } do
		local offset = delta.Unit:Cross(Vector3.yAxis) * dx
		part({ Name = "Rail", Size = Vector3.new(0.3, 0.3, delta.Magnitude), CFrame = CFrame.lookAt(c + delta / 2 + offset + Vector3.new(0, 0.3, 0), mouth + offset + Vector3.new(0, 0.3, 0)), Color = RUST, Material = Enum.Material.Metal, CanCollide = false, Parent = f })
	end
	for i = 0, 1 do
		local p = c + delta * (0.35 + i * 0.3)
		part({ Name = "OreCart", Size = Vector3.new(2.8, 2, 3.6), CFrame = CFrame.lookAt(p + Vector3.new(0, 1.4, 0), p + delta + Vector3.new(0, 1.4, 0)), Color = RUST, Material = Enum.Material.CorrodedMetal, Parent = f })
		part({ Name = "Ore", Size = Vector3.new(2.4, 0.8, 3.2), CFrame = CFrame.new(p + Vector3.new(0, 2.6, 0)), Color = if i == 0 then EMBER else ASH, Material = if i == 0 then Enum.Material.Neon else Enum.Material.Slate, CanCollide = false, Parent = f })
	end
	for _ = 1, 4 do
		Props.Crate(f, CFrame.new(c + Vector3.new(rng:NextNumber(-10, 10), 1, rng:NextNumber(4, 12))) * CFrame.Angles(0, rng:NextNumber(0, 3), 0))
	end
	return { Vector2.new(c.X, c.Z), 20 }
end

-- THE OLD KING'S FORGE (secret): an old mine tunnel under Mount Cinder to a lava-lit forge.
local function buildForge(terrain: Terrain, parent: Instance)
	local f = Common.folder("OldKingsForge", parent)
	local c = Ember.FORGE
	-- Tunnel (north from the mouth) and the domed forge hall.
	terrain:FillBlock(CFrame.new(c.X, c.Y + 5, -727), Vector3.new(10, 10, 30), Enum.Material.Air)
	terrain:FillBall(Vector3.new(c.X, c.Y + 9, c.Z), 16, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, c.Y - 2, c.Z), Vector3.new(34, 4, 34), Enum.Material.Slate)
	terrain:FillBlock(CFrame.new(c.X, c.Y - 1, -727), Vector3.new(10, 2, 30), Enum.Material.Slate)
	-- Timber supports and lanterns down the tunnel, a portal at the mouth.
	for z = -740, -716, 8 do
		for _, x in { -4.4, 4.4 } do
			part({ Name = "Support", Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(c.X + x, c.Y + 4.5, z), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
		end
		part({ Name = "Beam", Size = Vector3.new(9.8, 1, 1), CFrame = CFrame.new(c.X, c.Y + 9.2, z), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
		local lantern = part({ Name = "Lantern", Size = Vector3.new(0.8, 1.1, 0.8), CFrame = CFrame.new(c.X, c.Y + 8, z), Color = Color3.fromRGB(255, 170, 80), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		if z % 16 == 12 then
			light(lantern, Color3.fromRGB(255, 160, 80), 16, 1.1)
		end
	end
	Common.sign(f, Vector3.new(c.X, c.Y + 14, -746), "OLD KING'S MINE", "Closed after the collapse", Color3.fromRGB(230, 190, 140))
	-- The forge: anvil, hearth with a lava trough, the Old King's statue with his hammer.
	part({ Name = "Anvil", Size = Vector3.new(3, 2, 1.6), CFrame = CFrame.new(c + Vector3.new(4, 1, 4)), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal, Parent = f })
	part({ Name = "AnvilHorn", Class = "WedgePart", Size = Vector3.new(1.4, 1, 1.6), CFrame = CFrame.new(c + Vector3.new(6, 1.5, 4)) * CFrame.Angles(0, math.rad(-90), 0), Color = Color3.fromRGB(60, 60, 66), Material = Enum.Material.Metal, Parent = f })
	part({ Name = "Hearth", Size = Vector3.new(10, 5, 4), CFrame = CFrame.new(c + Vector3.new(0, 2.5, 12)), Color = Color3.fromRGB(120, 60, 50), Material = Enum.Material.Brick, Parent = f })
	local coals = part({ Name = "Coals", Size = Vector3.new(8, 0.6, 3), CFrame = CFrame.new(c + Vector3.new(0, 5.2, 12)), Color = EMBER, Material = Enum.Material.Neon, Parent = f })
	local fire = Instance.new("Fire")
	fire.Size = 6
	fire.Heat = 12
	fire.Parent = coals
	light(coals, EMBER, 30, 2)
	local king = CFrame.new(c + Vector3.new(-8, 0, 8)) * CFrame.Angles(0, math.rad(30), 0)
	part({ Name = "KingBody", Size = Vector3.new(4, 5, 3), CFrame = king * CFrame.new(0, 4.5, 0), Color = Color3.fromRGB(120, 110, 100), Material = Enum.Material.Slate, Parent = f })
	part({ Name = "KingHead", Size = Vector3.new(2.6, 2.4, 2.4), CFrame = king * CFrame.new(0, 8.2, 0), Color = Color3.fromRGB(120, 110, 100), Material = Enum.Material.Slate, Parent = f })
	part({ Name = "KingBeard", Class = "WedgePart", Size = Vector3.new(2.6, 3, 1), CFrame = king * CFrame.new(0, 6.3, -1.4) * CFrame.Angles(0, 0, math.rad(180)), Color = Color3.fromRGB(150, 140, 130), Material = Enum.Material.Slate, Parent = f })
	part({ Name = "KingCrown", Size = Vector3.new(2.8, 0.8, 2.6), CFrame = king * CFrame.new(0, 9.8, 0), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal, Parent = f })
	part({ Name = "KingLegs", Size = Vector3.new(3.6, 2, 2.6), CFrame = king * CFrame.new(0, 1, 0), Color = Color3.fromRGB(110, 100, 92), Material = Enum.Material.Slate, Parent = f })
	part({ Name = "HammerHaft", Size = Vector3.new(0.5, 6, 0.5), CFrame = king * CFrame.new(2.6, 4, -1) * CFrame.Angles(0, 0, math.rad(-15)), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	part({ Name = "HammerHead", Size = Vector3.new(2.6, 1.6, 1.6), CFrame = king * CFrame.new(3.4, 7, -1), Color = Color3.fromRGB(80, 80, 90), Material = Enum.Material.Metal, Parent = f })
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		part({ Name = "WallRune", Size = Vector3.new(0.3, 2, 1.2), CFrame = CFrame.lookAt(c + Vector3.new(math.cos(a) * 14.5, 7, math.sin(a) * 14.5), c + Vector3.new(0, 7, 0)), Color = Color3.fromRGB(255, 150, 60), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	end
	return {
		Spawn = { Area = "Ember", Position = c + Vector3.new(2, 0, -2), MinRarity = "Epic", Secret = "old_kings_forge" },
		Avoid = { Vector2.new(c.X, -744), 14 },
	}
end

-- THE STEAMFIELDS: hot springs, mineral terraces, a ruined bathhouse, steam everywhere.
local function buildSteamfields(terrain: Terrain, parent: Instance, groundAt, rng: Random, avoid)
	local f = Common.folder("Steamfields", parent)
	local pools = { { -120, -768, 9 }, { -60, -772, 11 }, { 70, -765, 8 }, { 120, -778, 10 }, { 175, -762, 7 }, { -165, -775, 7 } }
	for _, p in pools do
		local g = groundAt(p[1], p[2])
		terrain:FillCylinder(CFrame.new(p[1], g.Y - 1.5, p[2]), 5, p[3], Enum.Material.Air)
		terrain:FillCylinder(CFrame.new(p[1], g.Y - 4, p[2]), 2, p[3] + 3, Enum.Material.Limestone)
		terrain:FillCylinder(CFrame.new(p[1], g.Y - 2.5, p[2]), 3, p[3], Enum.Material.Water)
		local steam = part({ Name = "Steam", Size = Vector3.new(p[3] * 1.6, 1, p[3] * 1.6), CFrame = CFrame.new(p[1], g.Y - 1, p[2]), Transparency = 1, CanCollide = false, CanQuery = false, Parent = f })
		emitter(steam, {
			Texture = Common.SMOKE,
			Color = ColorSequence.new(Color3.fromRGB(240, 240, 245)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 9) }),
			Lifetime = NumberRange.new(3, 5),
			Rate = 5,
			Speed = NumberRange.new(2, 4),
			Shape = Enum.ParticleEmitterShape.Box,
			EmissionDirection = Enum.NormalId.Top,
			LightInfluence = 1,
		})
		table.insert(avoid, { Vector2.new(p[1], p[2]), p[3] + 5 })
	end
	-- The bathhouse over the big pool.
	local b = groundAt(-60, -772)
	for _, x in { -1, 1 } do
		for _, z in { -1, 1 } do
			part({ Name = "BathPost", Size = Vector3.new(1, 9, 1), CFrame = CFrame.new(b + Vector3.new(x * 12, 4.5, z * 12)), Color = Color3.fromRGB(150, 60, 40), Material = Enum.Material.Wood, Parent = f })
		end
	end
	for _, side in { -1, 1 } do
		part({ Name = "BathRoof", Size = Vector3.new(15, 0.8, 28), CFrame = CFrame.new(b + Vector3.new(side * 6.5, 10.6, 0)) * CFrame.Angles(0, 0, math.rad(-side * 18)), Color = Color3.fromRGB(60, 50, 50), Material = Enum.Material.Slate, Parent = f })
	end
	for _, x in { -14, 14 } do
		local lantern = part({ Name = "StoneLantern", Size = Vector3.new(1.4, 1.4, 1.4), CFrame = CFrame.new(b + Vector3.new(x, 3, -14)), Color = Color3.fromRGB(255, 200, 120), Material = Enum.Material.Neon, Parent = f })
		part({ Name = "LanternBase", Size = Vector3.new(1, 2.4, 1), CFrame = CFrame.new(b + Vector3.new(x, 1.2, -14)), Color = Color3.fromRGB(150, 145, 140), Material = Enum.Material.Slate, Parent = f })
		light(lantern, Color3.fromRGB(255, 190, 120), 16, 1, true)
	end
	-- Geothermal vents: jets of steam.
	for _ = 1, 5 do
		local x, z = rng:NextNumber(-170, 170), rng:NextNumber(-785, -750)
		if not Common.tooClose(avoid, x, z, 6) then
			local g = groundAt(x, z)
			local vent = part({ Name = "SteamVent", Size = Vector3.new(2.4, 0.4, 2.4), CFrame = CFrame.new(g + Vector3.new(0, 0.2, 0)), Color = Color3.fromRGB(200, 190, 150), Material = Enum.Material.Limestone, Parent = f })
			emitter(vent, {
				Texture = Common.SMOKE,
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) }),
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 6) }),
				Lifetime = NumberRange.new(1.5, 2.5),
				Rate = 10,
				Speed = NumberRange.new(14, 20),
				SpreadAngle = Vector2.new(6, 6),
				EmissionDirection = Enum.NormalId.Top,
				LightInfluence = 1,
			})
			table.insert(avoid, { Vector2.new(x, z), 5 })
		end
	end
end

-- THE CALDERA VAULT (secret): inside Mount Cinder's crater.
local function calderaSpawn()
	local c = Ember.CINDER
	return {
		Spawn = { Area = "Ember", Position = Vector3.new(c.X + 1.5, Ember.CRATER_FLOOR + 3.5, c.Z - 1.5), MinRarity = "Epic", Secret = "caldera_vault" },
		Avoid = { Vector2.new(c.X, c.Z), 100 },
	}
end

-- SCATTER ---------------------------------------------------------------------------------

local function scatter(parent: Instance, groundAt, rng: Random, avoid, spine: { Vector2 })
	local f = Common.folder("EmberScatter", parent)
	local bounds = { MinX = -210, MaxX = 210, MinZ = -780, MaxZ = -520 }
	local cinder = Vector2.new(Ember.CINDER.X, Ember.CINDER.Z)
	local function ok(x: number, z: number): boolean
		if Zones.AreaId(Vector3.new(x, 10, z)) ~= "Ember" or Common.tooClose(avoid, x, z) then
			return false
		end
		if (Vector2.new(x, z) - cinder).Magnitude < 100 or Common.distanceToPath(spine, x, z) < 10 then
			return false
		end
		for _, river in Ember.RIVERS do
			if Common.distanceToPath(river, x, z) < 13 then
				return false
			end
		end
		return groundAt(x, z).Y > 6
	end
	-- Obsidian spires: glassy black shards bursting from the ground.
	Common.scatter(rng, 28, 400, bounds, ok, function(x, z)
		local g = groundAt(x, z)
		for i = 1, rng:NextInteger(2, 4) do
			local h = if i == 1 then rng:NextNumber(8, 16) else rng:NextNumber(3, 8)
			local w = h * 0.3
			local cf = CFrame.new(g + Vector3.new(rng:NextNumber(-2, 2), 0, rng:NextNumber(-2, 2))) * CFrame.Angles(math.rad(rng:NextNumber(-18, 18)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-18, 18)))
			part({ Name = "ObsidianSpire", Size = Vector3.new(w, h, w), CFrame = cf * CFrame.new(0, h / 2 - 0.5, 0), Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = f })
		end
		table.insert(avoid, { Vector2.new(x, z), 6 })
	end)
	-- Charred trees.
	Common.scatter(rng, 34, 500, bounds, ok, function(x, z)
		Props.DeadTree(f, groundAt(x, z), rng, Color3.fromRGB(36, 30, 30))
		table.insert(avoid, { Vector2.new(x, z), 5 })
	end)
	-- Lava vents: glowing cracks with a lick of fire (decoration, not a hazard).
	Common.scatter(rng, 12, 300, bounds, ok, function(x, z)
		local g = groundAt(x, z)
		local crack = part({ Name = "LavaVent", Size = Vector3.new(rng:NextNumber(3, 5), 0.3, rng:NextNumber(0.8, 1.4)), CFrame = CFrame.new(g + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0), Color = EMBER, Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		local fire = Instance.new("Fire")
		fire.Size = 2.5
		fire.Heat = 5
		fire.Parent = crack
		table.insert(avoid, { Vector2.new(x, z), 4 })
	end)
	Common.scatter(rng, 8, 200, bounds, ok, function(x, z)
		Props.Bones(f, groundAt(x, z), rng)
	end)
	Common.scatter(rng, 16, 300, bounds, ok, function(x, z)
		local g = groundAt(x, z)
		local size = rng:NextNumber(3, 7)
		part({ Name = "Boulder", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size, size), CFrame = CFrame.new(g + Vector3.new(0, size * 0.25, 0)), Color = BASALT:Lerp(ASH, rng:NextNumber()), Material = Enum.Material.Basalt, Parent = f })
	end)
end

-- Returns { Avoid, Spawns } (secret spawns are exact positions).
function Ember.Build(terrain: Terrain, parent: Instance, rng: Random, groundAt, spine: { Vector2 })
	local root = Common.folder("Emberfall", parent)
	local avoid = {}
	local spawns = {}
	buildCinder(terrain, root, rng)
	local lit = { 0 }
	for _, river in Ember.RIVERS do
		carveRiver(terrain, root, river, groundAt, lit)
	end
	-- The Obsidian Bridge where the road crosses the great lava river.
	local cross = Vector2.new(48, -621)
	local bridgeGround = groundAt(cross.X, cross.Y - 12)
	local bridgeCf = CFrame.lookAt(Vector3.new(cross.X, bridgeGround.Y + 0.6, cross.Y), Vector3.new(cross.X + 6, bridgeGround.Y + 0.6, cross.Y - 60))
	part({ Name = "ObsidianBridge", Size = Vector3.new(9, 1.2, 28), CFrame = bridgeCf, Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = root })
	for _, side in { -1, 1 } do
		part({ Name = "BridgeRail", Size = Vector3.new(0.6, 1.4, 28), CFrame = bridgeCf * CFrame.new(side * 4.4, 1.2, 0), Color = BASALT, Material = Enum.Material.Slate, Parent = root })
		for _, z in { -13, 13 } do
			local post = part({ Name = "BridgeLamp", Size = Vector3.new(1, 1, 1), CFrame = bridgeCf * CFrame.new(side * 4.4, 3, z), Color = Color3.fromRGB(255, 170, 80), Material = Enum.Material.Neon, Parent = root })
			if z > 0 then
				light(post, Color3.fromRGB(255, 160, 80), 16, 1, true)
			end
		end
	end
	-- Stepping stones across the western river.
	for i = 0, 3 do
		local p = Vector2.new(-170 + i * 1.5, -575 - i * 4)
		cylinder(groundAt(p.X, p.Y) + Vector3.new(0, 0.2, 0), 2.4, 3.6, { Name = "SteppingStone", Color = OBSIDIAN, Material = Enum.Material.Glass, Parent = root })
	end
	table.insert(avoid, buildAshenCamp(root, groundAt))
	table.insert(avoid, buildTemple(root, groundAt, rng))
	table.insert(avoid, buildOutpost(root, groundAt))
	table.insert(avoid, buildMiningCamp(root, groundAt, rng))
	for _, built in { buildForge(terrain, root), calderaSpawn() } do
		table.insert(spawns, built.Spawn)
		table.insert(avoid, built.Avoid)
	end
	buildSteamfields(terrain, root, groundAt, rng, avoid)
	scatter(root, groundAt, rng, avoid, spine)
	-- Ash drifting down over everything, with the odd ember.
	Common.weather(root, Vector3.new(0, 85, -645), Vector2.new(420, 270), {
		Texture = Common.SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(150, 140, 135), Color3.fromRGB(255, 120, 50)),
		LightEmission = 0.4,
		Size = NumberSequence.new(0.5, 0.2),
		Lifetime = NumberRange.new(8, 12),
		Rate = 60,
		Speed = NumberRange.new(4, 7),
		SpreadAngle = Vector2.new(20, 20),
		Acceleration = Vector3.new(1.5, 0, 0),
	})
	return { Avoid = avoid, Spawns = spawns }
end

return Ember
