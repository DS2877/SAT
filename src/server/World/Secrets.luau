-- Hidden places for explorers (Config/Regions.Secrets). Each one hides a treasure spawn point
-- that only people who find it will ever loot:
--   OLD MINE    - a lantern-lit tunnel straight through a rocky hill in the Wilds (a shortcut
--                 toward the Coast), with a crystal cave in the middle.
--   SKY RUINS   - a spiral of broken pillars east of the temple, climbing to a floating island.
--   CATACOMBS   - stone stairs behind the temple down to a torch-lit burial hall. The Stone
--                 Golem patrols the entrance.
--   FROZEN GROTTO - an ice tunnel into a snowy hill in Frostpeak, glowing crystal chamber.
--   WITCH'S HUT - on stilts above the Glowshroom Marsh; the Witch Geyser flings you up.
-- Build() runs after the terrain and before vegetation (its Avoid list keeps trees out).

local Props = require(script.Parent.Props)

local Secrets = {}

local part, cylinder = Props.part, Props.cylinder

local WOOD = Color3.fromRGB(108, 76, 46)
local IRON = Color3.fromRGB(70, 68, 66)
local STONE = Color3.fromRGB(150, 138, 120)
local DARK_STONE = Color3.fromRGB(96, 88, 80)
local SANDSTONE = Color3.fromRGB(222, 184, 128)
local GOLD = Color3.fromRGB(255, 200, 60)

local function light(parent: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
end

local function torch(parent: Instance, position: Vector3)
	part({ Name = "TorchHandle", Size = Vector3.new(0.5, 2, 0.5), CFrame = CFrame.new(position), Color = WOOD, Material = Enum.Material.Wood, CanCollide = false, Parent = parent })
	local head = part({ Name = "TorchHead", Size = Vector3.new(0.8, 0.6, 0.8), CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0)), Color = IRON, Material = Enum.Material.Metal, CanCollide = false, Parent = parent })
	local fire = Instance.new("Fire")
	fire.Size = 2.5
	fire.Heat = 6
	fire.Parent = head
	light(head, Color3.fromRGB(255, 150, 70), 18, 1.4)
end

-- OLD MINE ------------------------------------------------------------------------------

local MINE = Vector3.new(-205, 12, -125) -- tunnel floor centre (flat zone at ground 10)

local function buildMine(terrain: Terrain, parent: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "OldMine"
	folder.Parent = parent
	local c = MINE
	-- The hill, then the tunnel (east-west, floor at y = 12) and the crystal cave.
	-- A grassy shell so it reads as a hill, rock inside.
	terrain:FillBall(Vector3.new(c.X, 2, c.Z), 32, Enum.Material.Grass)
	terrain:FillBall(Vector3.new(c.X, 2, c.Z), 28, Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(c.X, 17, c.Z), Vector3.new(76, 10, 10), Enum.Material.Air)
	terrain:FillBall(Vector3.new(c.X, 18, c.Z), 10, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, 10, c.Z), Vector3.new(24, 4, 24), Enum.Material.Rock)

	-- Plank walkway through the whole tunnel, ramps down to the ground at both mouths.
	part({ Name = "MineFloor", Size = Vector3.new(66, 1, 8), CFrame = CFrame.new(c.X, 11.6, c.Z), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	for _, side in { -1, 1 } do
		local x = c.X + side * 37
		part({ Name = "MineRamp", Class = "WedgePart", Size = Vector3.new(8, 2.2, 8), CFrame = CFrame.new(x, 11, c.Z) * CFrame.Angles(0, math.rad(side * -90), 0), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = folder })
	end
	-- Rails
	for _, z in { -1.6, 1.6 } do
		part({ Name = "Rail", Size = Vector3.new(66, 0.3, 0.3), CFrame = CFrame.new(c.X, 12.25, c.Z + z), Color = IRON, Material = Enum.Material.Metal, CanCollide = false, Parent = folder })
	end
	-- Timber supports + lanterns every 8 studs (skipping the open cave).
	for dx = -24, 24, 8 do
		if math.abs(dx) > 9 then
			local x = c.X + dx
			for _, z in { -4.3, 4.3 } do
				part({ Name = "Support", Size = Vector3.new(1, 10, 1), CFrame = CFrame.new(x, 17, c.Z + z), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
			end
			part({ Name = "Beam", Size = Vector3.new(1.2, 1.2, 9.6), CFrame = CFrame.new(x, 21.6, c.Z), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
			local lantern = part({ Name = "Lantern", Size = Vector3.new(0.8, 1.1, 0.8), CFrame = CFrame.new(x, 20.4, c.Z), Color = Color3.fromRGB(255, 190, 90), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
			light(lantern, Color3.fromRGB(255, 180, 90), 16, 1.2)
		end
	end
	-- Portal frames + signs at both mouths.
	for _, side in { -1, 1 } do
		local x = c.X + side * 30
		for _, z in { -5, 5 } do
			part({ Name = "Portal", Size = Vector3.new(1.6, 11, 1.6), CFrame = CFrame.new(x, 17.5, c.Z + z), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
		end
		part({ Name = "PortalBeam", Size = Vector3.new(1.8, 1.8, 12), CFrame = CFrame.new(x, 23, c.Z), Color = WOOD, Material = Enum.Material.Wood, Parent = folder })
		local sign = part({ Name = "MineSign", Size = Vector3.new(0.3, 1.8, 6), CFrame = CFrame.new(x + side * 1.1, 23, c.Z), Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Wood, CanCollide = false, Parent = folder })
		local gui = Instance.new("SurfaceGui")
		gui.Face = if side > 0 then Enum.NormalId.Right else Enum.NormalId.Left
		gui.PixelsPerStud = 40
		gui.LightInfluence = 0.3
		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = Color3.fromRGB(255, 230, 170)
		label.Text = "OLD MINE"
		label.Parent = gui
		gui.Parent = sign
	end
	-- Crystal cave: glowing clusters on the walls, a derailed minecart.
	local crystalColors = { Color3.fromRGB(90, 220, 255), Color3.fromRGB(190, 110, 255), Color3.fromRGB(120, 255, 200) }
	for i = 1, 9 do
		local a = i / 9 * math.pi * 2
		local base = Vector3.new(c.X + math.cos(a) * 8.5, 12.5 + (i % 3) * 3, c.Z + math.sin(a) * 8.5)
		local color = crystalColors[i % 3 + 1]
		for k = 1, 3 do
			local crystal = part({
				Name = "Crystal",
				Class = "WedgePart",
				Size = Vector3.new(0.9, 2.2 + k * 0.6, 0.9),
				CFrame = CFrame.new(base) * CFrame.Angles(0, -a, 0) * CFrame.Angles(math.rad(-25 + k * 12), 0, math.rad((k - 2) * 25)),
				Color = color,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			if k == 2 and i % 2 == 0 then
				light(crystal, color, 14, 1)
			end
		end
	end
	local cart = CFrame.new(c.X - 5, 13.4, c.Z + 5) * CFrame.Angles(0, math.rad(30), math.rad(12))
	part({ Name = "Minecart", Size = Vector3.new(4, 2.2, 2.6), CFrame = cart, Color = IRON, Material = Enum.Material.CorrodedMetal, Parent = folder })
	part({ Name = "Ore", Shape = Enum.PartType.Ball, Size = Vector3.new(3, 1.6, 2.2), CFrame = cart * CFrame.new(0, 1.2, 0), Color = GOLD, Material = Enum.Material.Foil, CanCollide = false, Parent = folder })

	return {
		Spawn = { Area = "Wilds", Position = Vector3.new(c.X + 3, 12, c.Z - 4), MinRarity = "Rare", MaxRarity = "Rare", Secret = "old_mine" },
		Avoid = { Vector2.new(c.X, c.Z), 46 },
	}
end

-- SKY RUINS -----------------------------------------------------------------------------

local SKY = Vector3.new(330, 10, -165) -- ground centre of the spiral
local SKY_TOP = 66 -- top of the floating island
local STEPS = 12

local function buildSkyRuins(parent: Folder, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "SkyRuins"
	folder.Parent = parent
	-- Broken pillars spiralling up: each one 4.5 studs higher, ~5 studs apart (one jump).
	for i = 1, STEPS do
		local a = math.pi + (i - 1) * math.rad(30)
		local top = SKY.Y + i * 4.5
		local p = Vector3.new(SKY.X + math.cos(a) * 24, 0, SKY.Z + math.sin(a) * 24)
		local height = top - SKY.Y + 2
		cylinder(Vector3.new(p.X, SKY.Y - 2 + height / 2, p.Z), height, 4.2, { Name = "Pillar", Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = folder })
		for r = 1, 3 do
			local y = SKY.Y + height * r / 4
			if y < top - 2 then
				cylinder(Vector3.new(p.X, y, p.Z), 0.6, 4.8, { Name = "Ring", Color = Color3.fromRGB(196, 158, 104), Material = Enum.Material.Sandstone, Parent = folder })
			end
		end
		part({
			Name = "Step",
			Size = Vector3.new(7, 1.4, 7),
			CFrame = CFrame.new(p.X, top - 0.7, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 1.5), math.rad(rng:NextNumber(-3, 3))),
			Color = STONE,
			Material = Enum.Material.Slate,
			Parent = folder,
		})
	end
	-- The floating island: a stone disc on a hanging rock root.
	local centre = Vector3.new(SKY.X, SKY_TOP, SKY.Z)
	cylinder(centre - Vector3.new(0, 1.5, 0), 3, 30, { Name = "SkyIsland", Color = STONE, Material = Enum.Material.Slate, Parent = folder })
	cylinder(centre + Vector3.new(0, 0.05, 0), 0.1, 26, { Name = "SkyGrass", Color = Color3.fromRGB(120, 180, 80), Material = Enum.Material.Grass, CanCollide = false, Parent = folder })
	for i = 1, 7 do
		local size = 22 - i * 2.6
		part({
			Name = "SkyRoot",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size * 0.8, size),
			CFrame = CFrame.new(centre - Vector3.new(rng:NextNumber(-1.5, 1.5), 2 + i * 2.6, rng:NextNumber(-1.5, 1.5))),
			Color = Color3.fromRGB(120, 108, 96),
			Material = Enum.Material.Rock,
			Parent = folder,
		})
	end
	-- Ruined arches around the edge.
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3 + 0.4
		local cf = CFrame.new(centre + Vector3.new(math.cos(a) * 10, 0, math.sin(a) * 10)) * CFrame.Angles(0, -a + math.pi / 2, 0)
		for _, x in { -3.5, 3.5 } do
			part({ Name = "ArchPillar", Size = Vector3.new(1.6, 9, 1.6), CFrame = cf * CFrame.new(x, 4.5, 0), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = folder })
		end
		if k ~= 1 then
			part({ Name = "ArchTop", Size = Vector3.new(9, 1.6, 2), CFrame = cf * CFrame.new(0, 9.5, 0), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = folder })
		end
	end
	-- Golden dais where the treasure rests, plus a beacon of sparkles to lure climbers.
	local dais = cylinder(centre + Vector3.new(0, 0.5, 0), 1, 8, { Name = "Dais", Color = GOLD, Material = Enum.Material.Foil, Parent = folder })
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Rate = 6
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(60, 60)
	sparkle.Size = NumberSequence.new(0.8, 0)
	sparkle.Color = ColorSequence.new(GOLD)
	sparkle.LightEmission = 1
	sparkle.Parent = dais
	for _ = 1, 6 do
		local a = rng:NextNumber(0, 6.28)
		Props.Vine(folder, centre + Vector3.new(math.cos(a) * 14, -2, math.sin(a) * 14), rng:NextNumber(6, 14), rng)
	end
	return {
		Spawn = { Area = "Ruins", Position = centre + Vector3.new(0, 1, 0), MinRarity = "Epic", MaxRarity = "Legendary", Secret = "sky_ruins" },
		Avoid = { Vector2.new(SKY.X, SKY.Z), 40 },
	}
end

-- CATACOMBS ----------------------------------------------------------------------------

local CRYPT = Vector3.new(190, 10, -190) -- top of the stairs (behind the temple, west side)
local STAIR_STEPS = 12
local STEP_DEPTH = 4
local STEP_DROP = 2
local ROOM_FLOOR = CRYPT.Y - STAIR_STEPS * STEP_DROP -- -14
local ROOM = Vector3.new(CRYPT.X, ROOM_FLOOR, CRYPT.Z - STAIR_STEPS * STEP_DEPTH - 16) -- centre of the hall floor

local function buildCatacombs(terrain: Terrain, parent: Folder, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Catacombs"
	folder.Parent = parent
	local brick = Enum.Material.Brick
	-- Stairwell: carve, then line every step with stone so the voxels never show.
	for i = 1, STAIR_STEPS do
		local floorY = CRYPT.Y - i * STEP_DROP
		local z = CRYPT.Z - (i - 0.5) * STEP_DEPTH
		terrain:FillBlock(CFrame.new(CRYPT.X, floorY + 6, z), Vector3.new(12, 12, STEP_DEPTH + 0.5), Enum.Material.Air)
		part({ Name = "Step", Size = Vector3.new(10, 4, STEP_DEPTH), CFrame = CFrame.new(CRYPT.X, floorY - 2, z), Color = DARK_STONE, Material = Enum.Material.Slate, Parent = folder })
		for _, x in { -5.5, 5.5 } do
			part({ Name = "StairWall", Size = Vector3.new(1, 12, STEP_DEPTH), CFrame = CFrame.new(CRYPT.X + x, floorY + 6, z), Color = STONE, Material = brick, Parent = folder })
		end
		if floorY + 12 < CRYPT.Y then
			part({ Name = "StairCeiling", Size = Vector3.new(12, 1, STEP_DEPTH), CFrame = CFrame.new(CRYPT.X, floorY + 12.5, z), Color = DARK_STONE, Material = brick, Parent = folder })
		end
		if i % 3 == 0 then
			torch(folder, Vector3.new(CRYPT.X + 4.6, floorY + 4.5, z))
		end
	end
	-- Crypt gateway at the top.
	for _, x in { -6.5, 6.5 } do
		part({ Name = "GatePillar", Size = Vector3.new(2.4, 14, 2.4), CFrame = CFrame.new(CRYPT.X + x, CRYPT.Y + 5, CRYPT.Z + 1), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = folder })
		part({ Name = "Skull", Shape = Enum.PartType.Ball, Size = Vector3.new(1.6, 1.6, 1.6), CFrame = CFrame.new(CRYPT.X + x, CRYPT.Y + 12.8, CRYPT.Z + 1), Color = Color3.fromRGB(236, 226, 200), Parent = folder })
	end
	part({ Name = "GateLintel", Size = Vector3.new(16, 2.4, 3), CFrame = CFrame.new(CRYPT.X, CRYPT.Y + 11, CRYPT.Z + 1), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = folder })

	-- The burial hall.
	local w, d, h = 32, 28, 13
	terrain:FillBlock(CFrame.new(ROOM.X, ROOM.Y + h / 2, ROOM.Z), Vector3.new(w + 2, h + 2, d + 2), Enum.Material.Air)
	part({ Name = "HallFloor", Size = Vector3.new(w, 2, d), CFrame = CFrame.new(ROOM.X, ROOM.Y - 1, ROOM.Z), Color = DARK_STONE, Material = Enum.Material.Slate, Parent = folder })
	part({ Name = "HallCeiling", Size = Vector3.new(w, 1.5, d), CFrame = CFrame.new(ROOM.X, ROOM.Y + h + 0.75, ROOM.Z), Color = DARK_STONE, Material = brick, Parent = folder })
	for _, x in { -1, 1 } do
		part({ Name = "HallWall", Size = Vector3.new(1.5, h, d), CFrame = CFrame.new(ROOM.X + x * (w / 2 + 0.75), ROOM.Y + h / 2, ROOM.Z), Color = STONE, Material = brick, Parent = folder })
	end
	part({ Name = "HallWall", Size = Vector3.new(w, h, 1.5), CFrame = CFrame.new(ROOM.X, ROOM.Y + h / 2, ROOM.Z - d / 2 - 0.75), Color = STONE, Material = brick, Parent = folder })
	-- North wall with the stair doorway (10 wide, 12 high).
	local north = ROOM.Z + d / 2 + 0.75
	for _, x in { -1, 1 } do
		part({ Name = "HallWall", Size = Vector3.new((w - 10) / 2, h, 1.5), CFrame = CFrame.new(ROOM.X + x * (5 + (w - 10) / 4), ROOM.Y + h / 2, north), Color = STONE, Material = brick, Parent = folder })
	end
	part({ Name = "HallWall", Size = Vector3.new(10, 1, 1.5), CFrame = CFrame.new(ROOM.X, ROOM.Y + h - 0.5, north), Color = STONE, Material = brick, Parent = folder })
	-- Doorway between the last step and the hall.
	terrain:FillBlock(CFrame.new(ROOM.X, ROOM.Y + 6, north + 0.5), Vector3.new(12, 12, 4), Enum.Material.Air)
	part({ Name = "Threshold", Size = Vector3.new(10, 2, 3), CFrame = CFrame.new(ROOM.X, ROOM.Y - 1, north + 0.5), Color = DARK_STONE, Material = Enum.Material.Slate, Parent = folder })
	-- Pillars, sarcophagi, torches, bones and cobwebs.
	for _, x in { -9, 9 } do
		for _, z in { -7, 5 } do
			part({ Name = "HallPillar", Size = Vector3.new(2.4, h, 2.4), CFrame = CFrame.new(ROOM.X + x, ROOM.Y + h / 2, ROOM.Z + z), Color = SANDSTONE, Material = Enum.Material.Sandstone, Parent = folder })
		end
		for k, z in { -9, -1, 7 } do
			local cf = CFrame.new(ROOM.X + x * 1.45, ROOM.Y + 1.2, ROOM.Z + z)
			part({ Name = "Sarcophagus", Size = Vector3.new(3.4, 2.4, 6.5), CFrame = cf, Color = Color3.fromRGB(120, 112, 100), Material = Enum.Material.Slate, Parent = folder })
			part({ Name = "Lid", Size = Vector3.new(3.8, 0.6, 7), CFrame = cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(0, if k == 2 then 0.35 else 0, 0), Color = Color3.fromRGB(140, 130, 112), Material = Enum.Material.Slate, Parent = folder })
		end
		torch(folder, Vector3.new(ROOM.X + x * 1.7, ROOM.Y + 7, ROOM.Z - 12))
		torch(folder, Vector3.new(ROOM.X + x * 1.7, ROOM.Y + 7, ROOM.Z + 11))
	end
	for _ = 1, 10 do
		part({
			Name = "Bone",
			Size = Vector3.new(0.35, 0.35, rng:NextNumber(1.2, 2.2)),
			CFrame = CFrame.new(ROOM.X + rng:NextNumber(-12, 12), ROOM.Y + 0.2, ROOM.Z + rng:NextNumber(-12, 12)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = Color3.fromRGB(230, 220, 196),
			CanCollide = false,
			Parent = folder,
		})
	end
	for _, corner in { Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) } do
		part({
			Name = "Cobweb",
			Size = Vector3.new(6, 0.05, 6),
			CFrame = CFrame.new(ROOM + Vector3.new(corner.X * (w / 2 - 2), h - 1.5, corner.Z * (d / 2 - 2))) * CFrame.Angles(math.rad(corner.Z * 35), math.rad(45), math.rad(corner.X * -35)),
			Color = Color3.fromRGB(235, 235, 240),
			Transparency = 0.55,
			Material = Enum.Material.Fabric,
			CanCollide = false,
			CanQuery = false,
			Parent = folder,
		})
	end
	-- The treasure altar at the far end.
	local altar = part({ Name = "Altar", Size = Vector3.new(8, 1.5, 5), CFrame = CFrame.new(ROOM.X, ROOM.Y + 0.75, ROOM.Z - 9), Color = GOLD, Material = Enum.Material.Foil, Parent = folder })
	light(altar, Color3.fromRGB(255, 200, 110), 22, 1.2)
	return {
		Spawn = { Area = "Ruins", Position = Vector3.new(ROOM.X, ROOM.Y + 1.5, ROOM.Z - 9), MinRarity = "Legendary", MaxRarity = "Mythic", Secret = "catacombs" },
		Avoid = { Vector2.new(CRYPT.X, CRYPT.Z - 30), 36 },
	}
end

-- FROZEN GROTTO (Frostpeak) ------------------------------------------------------------

local GROTTO = Vector3.new(-215, 12, 330) -- chamber floor centre

local function buildGrotto(terrain: Terrain, parent: Folder)
	local folder = Instance.new("Folder")
	folder.Name = "FrozenGrotto"
	folder.Parent = parent
	local c = GROTTO
	-- An ice hill (snow shell, glacier inside) with a tunnel from the east and a chamber.
	terrain:FillBall(Vector3.new(c.X, 2, c.Z), 28, Enum.Material.Snow)
	terrain:FillBall(Vector3.new(c.X, 2, c.Z), 24, Enum.Material.Glacier)
	terrain:FillBlock(CFrame.new(c.X + 18, 17, c.Z), Vector3.new(36, 10, 9), Enum.Material.Air)
	terrain:FillBall(Vector3.new(c.X, 18, c.Z), 9, Enum.Material.Air)
	terrain:FillBlock(CFrame.new(c.X, 10, c.Z), Vector3.new(20, 4, 20), Enum.Material.Glacier)
	part({ Name = "GrottoFloor", Size = Vector3.new(34, 1, 7), CFrame = CFrame.new(c.X + 17, 11.6, c.Z), Color = Color3.fromRGB(170, 220, 245), Material = Enum.Material.Ice, Parent = folder })
	part({ Name = "GrottoRamp", Class = "WedgePart", Size = Vector3.new(7, 2.2, 8), CFrame = CFrame.new(c.X + 38, 11, c.Z) * CFrame.Angles(0, math.rad(-90), 0), Color = Color3.fromRGB(170, 220, 245), Material = Enum.Material.Ice, Parent = folder })
	-- Icicles on the roof and glowing crystals in the chamber.
	for i = 1, 8 do
		local x = c.X + 4 + i * 3.5
		part({ Name = "Icicle", Class = "WedgePart", Size = Vector3.new(0.6, 2.4, 0.6), CFrame = CFrame.new(x, 20.6, c.Z + (i % 2 == 0 and 2 or -2)) * CFrame.Angles(math.rad(180), 0, 0), Color = Color3.fromRGB(200, 240, 255), Material = Enum.Material.Glass, Transparency = 0.25, CanCollide = false, Parent = folder })
	end
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2
		local crystal = part({
			Name = "Crystal",
			Class = "WedgePart",
			Size = Vector3.new(1, 3.4, 1),
			CFrame = CFrame.new(c.X + math.cos(a) * 7.5, 13.5, c.Z + math.sin(a) * 7.5) * CFrame.Angles(0, -a, math.rad(15)),
			Color = Color3.fromRGB(110, 210, 255),
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = folder,
		})
		if i % 2 == 0 then
			light(crystal, Color3.fromRGB(120, 210, 255), 16, 1.1)
		end
	end
	return {
		Spawn = { Area = "Frost", Position = Vector3.new(c.X - 2, 12, c.Z), MinRarity = "Epic", MaxRarity = "Divine", Secret = "frozen_grotto" },
		Avoid = { Vector2.new(c.X, c.Z), 34 },
	}
end

-- WITCH'S HUT (Glowshroom Marsh) --------------------------------------------------------

local HUT = Vector3.new(330, 38, 150) -- platform top centre

local function buildWitchHut(parent: Folder, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "WitchHut"
	folder.Parent = parent
	local c = HUT
	local wood = Color3.fromRGB(78, 58, 44)
	-- Crooked stilts and the platform.
	for _, x in { -8, 8 } do
		for _, z in { -8, 8 } do
			local foot = Vector3.new(c.X + x * 1.1, 10, c.Z + z * 1.1)
			local top = Vector3.new(c.X + x, c.Y - 1, c.Z + z)
			part({ Name = "Stilt", Size = Vector3.new(1.3, 1.3, (top - foot).Magnitude), CFrame = CFrame.lookAt((foot + top) / 2, top), Color = wood, Material = Enum.Material.Wood, Parent = folder })
		end
	end
	part({ Name = "Platform", Size = Vector3.new(20, 1, 20), CFrame = CFrame.new(c.X, c.Y - 0.5, c.Z), Color = Color3.fromRGB(110, 84, 60), Material = Enum.Material.WoodPlanks, Parent = folder })
	-- The hut on the back half (+Z), a porch in front.
	local hut = CFrame.new(c.X, c.Y, c.Z + 5)
	part({ Name = "HutBack", Size = Vector3.new(14, 9, 1), CFrame = hut * CFrame.new(0, 4.5, 4.5), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
	for _, x in { -1, 1 } do
		part({ Name = "HutSide", Size = Vector3.new(1, 9, 10), CFrame = hut * CFrame.new(x * 6.5, 4.5, 0), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
		part({ Name = "HutFront", Size = Vector3.new(4, 9, 1), CFrame = hut * CFrame.new(x * 5, 4.5, -4.5), Color = wood, Material = Enum.Material.WoodPlanks, Parent = folder })
		part({ Name = "Roof", Size = Vector3.new(9, 1, 13), CFrame = hut * CFrame.new(x * 3.6, 10.6, 0) * CFrame.Angles(0, 0, math.rad(x * -28)), Color = Color3.fromRGB(90, 60, 110), Material = Enum.Material.Fabric, Parent = folder })
	end
	-- Bubbling cauldron with green fire on the porch.
	local cauldron = part({ Name = "Cauldron", Shape = Enum.PartType.Ball, Size = Vector3.new(4, 3.4, 4), CFrame = CFrame.new(c.X + 5, c.Y + 1.6, c.Z - 5), Color = Color3.fromRGB(40, 40, 46), Material = Enum.Material.Metal, Parent = folder })
	local brew = part({ Name = "Brew", Size = Vector3.new(3, 0.2, 3), CFrame = CFrame.new(c.X + 5, c.Y + 3.2, c.Z - 5), Color = Color3.fromRGB(120, 255, 90), Material = Enum.Material.Neon, CanCollide = false, Parent = folder })
	local fire = Instance.new("Fire")
	fire.Color = Color3.fromRGB(120, 255, 90)
	fire.SecondaryColor = Color3.fromRGB(40, 140, 30)
	fire.Size = 3
	fire.Parent = cauldron
	light(brew, Color3.fromRGB(140, 255, 110), 20, 1.4)
	-- Hanging charms.
	for i = 1, 4 do
		Props.Vine(folder, Vector3.new(c.X - 8 + i * 3.2, c.Y - 1, c.Z - 10), rng:NextNumber(3, 6), rng)
	end
	return {
		Spawn = { Area = "Marsh", Position = Vector3.new(c.X - 3, c.Y, c.Z - 4), MinRarity = "Epic", MaxRarity = "Legendary", Secret = "witch_hut" },
		Avoid = { Vector2.new(c.X, c.Z), 16 },
	}
end

-- Returns { Spawns = { spawn point }, Avoid = { { Vector2, radius } } }. Spawn positions are
-- final (not ground-resolved: a raycast from the sky would land on the hill / island).
function Secrets.Build(terrain: Terrain, parent: Instance, rng: Random)
	local folder = Instance.new("Folder")
	folder.Name = "Secrets"
	folder.Parent = parent
	local result = { Spawns = {}, Avoid = {} }
	for _, built in {
		buildMine(terrain, folder),
		buildSkyRuins(folder, rng),
		buildCatacombs(terrain, folder, rng),
		buildGrotto(terrain, folder),
		buildWitchHut(folder, rng),
	} do
		table.insert(result.Spawns, built.Spawn)
		table.insert(result.Avoid, built.Avoid)
	end
	return result
end

Secrets.MINE = MINE
Secrets.SKY = SKY
Secrets.SKY_TOP = SKY_TOP
Secrets.ROOM = ROOM

return Secrets
