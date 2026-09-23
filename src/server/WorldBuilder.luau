-- Builds Treasure Island at server start from WorldLayout (placeholder art: terrain + parts).
-- Everything is deterministic so every server looks identical. Returns the gameplay anchors
-- (spawn points, stations, vault plots, prompts) other services hook into.
--
-- Swap-in path for real art: replace individual build* functions with cloned prefabs that
-- keep the same returned anchors.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local WorldLayout = require(Shared.Config.WorldLayout)
local Treasures = require(Shared.Config.Treasures)
local TreasureVisual = require(Shared.TreasureVisual)

local TerrainGen = require(script.Parent.World.TerrainGen)
local Props = require(script.Parent.World.Props)

local WorldBuilder = {}

local terrain = workspace.Terrain
local world: Folder
local rng = Random.new(20260923)

local C = {
	Cream = Color3.fromRGB(245, 235, 210),
	Stone = Color3.fromRGB(200, 190, 170),
	Sandstone = Color3.fromRGB(222, 190, 130),
	DarkStone = Color3.fromRGB(120, 115, 105),
	Wood = Color3.fromRGB(125, 85, 50),
	DarkWood = Color3.fromRGB(80, 52, 32),
	Gold = Color3.fromRGB(255, 196, 50),
	Teal = Color3.fromRGB(40, 190, 190),
	Red = Color3.fromRGB(220, 60, 60),
	Leaf = Color3.fromRGB(70, 160, 70),
	LeafDark = Color3.fromRGB(45, 120, 60),
	Safe = Color3.fromRGB(90, 230, 120),
	Danger = Color3.fromRGB(255, 140, 40),
	Secret = Color3.fromRGB(190, 110, 255),
}

local function part(props): BasePart
	local p: BasePart
	if props.Class then
		p = Instance.new(props.Class) :: BasePart
	else
		p = Instance.new("Part")
	end
	if props.Shape then
		(p :: Part).Shape = props.Shape
	end
	p.Anchored = true
	p.Size = props.Size
	p.CFrame = props.CFrame
	p.Color = props.Color or C.Stone
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Transparency = props.Transparency or 0
	p.CanCollide = if props.CanCollide == nil then true else props.CanCollide
	p.CanQuery = if props.CanQuery == nil then true else props.CanQuery
	p.CastShadow = if props.CastShadow == nil then true else props.CastShadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Parent = props.Parent or world
	return p
end

-- Upright cylinder (Roblox cylinders run along X, so rotate onto Y).
local function cylinder(position: Vector3, height: number, diameter: number, props)
	props.Shape = Enum.PartType.Cylinder
	props.Size = Vector3.new(height, diameter, diameter)
	props.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	return part(props)
end

local function folder(name: string, parent: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or world
	return f
end

-- studWidth given: the sign is sized in world studs and shrinks with distance (local signs).
-- Otherwise it is a compact fixed-pixel label readable from far away (landmarks, beacons).
local function billboardSign(
	parent: BasePart,
	title: string,
	subtitle: string?,
	color: Color3,
	maxDistance: number,
	offset: number,
	studWidth: number?
)
	local gui = Instance.new("BillboardGui")
	if studWidth then
		gui.Size = UDim2.fromScale(studWidth, studWidth * (if subtitle then 0.26 else 0.16))
	else
		gui.Size = UDim2.fromOffset(190, if subtitle then 46 else 30)
	end
	gui.StudsOffset = Vector3.new(0, offset, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	gui.Name = "Sign"
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, if subtitle then 0.6 else 1)
	t.Font = Enum.Font.GothamBlack
	t.TextScaled = true
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Text = title
	t.Name = "Title"
	t.Parent = gui
	if subtitle then
		local s = Instance.new("TextLabel")
		s.BackgroundTransparency = 1
		s.Position = UDim2.fromScale(0, 0.6)
		s.Size = UDim2.fromScale(1, 0.4)
		s.Font = Enum.Font.GothamBold
		s.TextScaled = true
		s.TextColor3 = Color3.new(1, 1, 1)
		s.TextStrokeTransparency = 0.3
		s.Text = subtitle
		s.Name = "Subtitle"
		s.Parent = gui
	end
	gui.Parent = parent
	return gui
end

local function prompt(parent: BasePart, action: string, object: string, hold: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.HoldDuration = hold or 0
	p.MaxActivationDistance = 12
	p.RequiresLineOfSight = false
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.GamepadKeyCode = Enum.KeyCode.ButtonX
	p.Parent = parent
	return p
end

local function groundAt(x: number, z: number, from: number?): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = {}
	params.IgnoreWater = true
	local origin = Vector3.new(x, from or 300, z)
	local result = workspace:Raycast(origin, Vector3.new(0, -((from or 300) + 60), 0), params)
	return if result then result.Position else Vector3.new(x, WorldLayout.GroundY, z)
end

-- ENVIRONMENT -----------------------------------------------------------------

local function buildLighting()
	Lighting.ClockTime = 15.3
	Lighting.Brightness = 3
	Lighting.GlobalShadows = true
	Lighting.ShadowSoftness = 0.25
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 145, 160)
	Lighting.Ambient = Color3.fromRGB(80, 75, 90)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 236, 200)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GeographicLatitude = 20

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.32
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(205, 225, 240)
	atmosphere.Decay = Color3.fromRGB(120, 160, 200)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.6
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.6
	bloom.Size = 28
	bloom.Threshold = 1.4
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.22
	color.Contrast = 0.08
	color.Brightness = 0.02
	color.TintColor = Color3.fromRGB(255, 250, 240)
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.08
	rays.Spread = 0.6
	rays.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 16
	sky.Parent = Lighting

	local clouds = Instance.new("Clouds")
	clouds.Cover = 0.55
	clouds.Density = 0.55
	clouds.Color = Color3.fromRGB(255, 252, 245)
	clouds.Parent = terrain
end

local function buildTerrain()
	terrain.WaterColor = Color3.fromRGB(20, 170, 190)
	terrain.WaterTransparency = 0.75
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 9
	terrain.WaterReflectance = 0.5
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(104, 178, 72))
	terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(86, 160, 66))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(244, 224, 168))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(128, 120, 112))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(150, 116, 80))
	terrain:SetMaterialColor(Enum.Material.Basalt, Color3.fromRGB(70, 62, 60))

	-- Ocean (sea floor + water, top at y = 0)
	terrain:FillBlock(CFrame.new(0, -32, 0), Vector3.new(1800, 16, 1800), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(1800, 24, 1800), Enum.Material.Water)

	-- Island: noise heightmap (hills, coastline, beaches); gameplay areas stay flat at y = 10.
	TerrainGen.Generate(terrain)

	-- Shipwreck cove (open to the ocean on the west)
	local cove = WorldLayout.Shipwreck
	terrain:FillBlock(CFrame.new(cove.CoveCenter + Vector3.new(0, 6, 0)), cove.CoveSize, Enum.Material.Air)
	terrain:FillBlock(
		CFrame.new(cove.CoveCenter + Vector3.new(0, -10, 0)),
		Vector3.new(cove.CoveSize.X, 20, cove.CoveSize.Z),
		Enum.Material.Water
	)
	terrain:FillBlock(CFrame.new(cove.Center + Vector3.new(30, 0, 0)), Vector3.new(40, 12, 190), Enum.Material.Sand)

	-- Volcano landmark (future late-game zone): stacked basalt cylinders + lava crater
	local v = WorldLayout.Volcano
	local layers = 10
	for i = 0, layers - 1 do
		local h = v.Height / layers
		terrain:FillCylinder(
			CFrame.new(v.Center + Vector3.new(0, i * h + h / 2 - 10, 0)),
			h,
			v.BaseRadius * (1 - i / layers) + 12,
			if i < 3 then Enum.Material.Rock else Enum.Material.Basalt
		)
	end
	local top = v.Center + Vector3.new(0, v.Height - 10, 0)
	terrain:FillCylinder(CFrame.new(top + Vector3.new(0, 4, 0)), 14, 22, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(top + Vector3.new(0, -4, 0)), 4, 22, Enum.Material.CrackedLava)
end

local function paintPath(from: Vector3, to: Vector3, width: number)
	local delta = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local steps = math.ceil(delta.Magnitude / 8)
	for i = 0, steps do
		local p = from + delta * (i / steps)
		local region = Region3.new(
			Vector3.new(p.X - width / 2, 0, p.Z - width / 2),
			Vector3.new(p.X + width / 2, 72, p.Z + width / 2)
		):ExpandToGrid(4)
		terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Ground)
		terrain:ReplaceMaterial(region, 4, Enum.Material.LeafyGrass, Enum.Material.Ground)
	end
end

-- TREASURE DISTRICT -------------------------------------------------------------

-- Welcoming spawn pavilion: stepped marble dais, ring of pillars, dome with a spinning golden
-- crown, sparkles, and a welcome arch that doubles as the how-to-play sign.
local function buildSpawnPavilion(district: Folder)
	local pav = folder("SpawnPavilion", district)
	local spawnPos = WorldLayout.Spawn
	local base = Vector3.new(spawnPos.X, WorldLayout.District.Center.Y + 1, spawnPos.Z)
	cylinder(base + Vector3.new(0, 0.5, 0), 1, 34, { Name = "Step1", Color = Color3.fromRGB(225, 218, 200), Material = Enum.Material.Marble, Parent = pav })
	cylinder(base + Vector3.new(0, 1.5, 0), 1, 28, { Name = "Step2", Color = Color3.fromRGB(240, 234, 220), Material = Enum.Material.Marble, Parent = pav })
	cylinder(base + Vector3.new(0, 2.05, 0), 0.12, 24, { Name = "GoldInlay", Color = C.Gold, Material = Enum.Material.Metal, CanCollide = false, Parent = pav })
	cylinder(base + Vector3.new(0, 2.08, 0), 0.12, 21, { Name = "InnerFloor", Color = Color3.fromRGB(70, 60, 110), Material = Enum.Material.Marble, CanCollide = false, Parent = pav })

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DistrictSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(12, 0.2, 12)
	spawn.CFrame = CFrame.lookAt(spawnPos - Vector3.new(0, 0.4, 0), Vector3.new(0, spawnPos.Y - 0.4, WorldLayout.District.Gate.Z))
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.Duration = GameConfig.Player.SpawnProtection
	spawn.Neutral = true
	spawn.Parent = pav
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Pillars (gap facing north so the view opens onto the plaza)
	for i = 0, 7 do
		local a = math.rad(22.5 + i * 45)
		local p = base + Vector3.new(math.sin(a) * 12, 0, math.cos(a) * 12)
		cylinder(p + Vector3.new(0, 8, 0), 12, 1.6, { Name = "Pillar", Color = Color3.fromRGB(250, 246, 236), Material = Enum.Material.Marble, Parent = pav })
		cylinder(p + Vector3.new(0, 14.3, 0), 0.6, 2.2, { Name = "PillarCap", Color = C.Gold, Material = Enum.Material.Metal, Parent = pav })
	end
	cylinder(base + Vector3.new(0, 15, 0), 1.2, 27, { Name = "RoofRing", Color = C.Gold, Material = Enum.Material.Metal, Parent = pav })
	part({ Name = "Dome", Shape = Enum.PartType.Ball, Size = Vector3.new(26, 11, 26), CFrame = CFrame.new(base + Vector3.new(0, 16.5, 0)), Color = Color3.fromRGB(60, 170, 190), Material = Enum.Material.SmoothPlastic, Parent = pav })
	local crownDef = Treasures.Get("golden_crown")
	if crownDef then
		local crown = TreasureVisual.Build(crownDef, CFrame.new(base + Vector3.new(0, 25.5, 0)), 3)
		crown.Name = "SpawnCrown"
		crown.Parent = pav
		local crownHandle = crown.PrimaryPart :: BasePart
		crownHandle:SetAttribute("Spin", 0.5)
	end
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Color = ColorSequence.new(C.Gold)
	sparkle.LightEmission = 1
	sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0) })
	sparkle.Lifetime = NumberRange.new(1.5, 2.5)
	sparkle.Rate = 12
	sparkle.Speed = NumberRange.new(1, 3)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	local emitterPart = part({ Name = "Sparkles", Size = Vector3.new(20, 1, 20), CFrame = CFrame.new(base + Vector3.new(0, 4, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = pav })
	sparkle.Parent = emitterPart

	-- Welcome arch between the pavilion and the fountain; its panel teaches the loop.
	local archZ = base.Z - 22
	for _, x in { -12, 12 } do
		part({ Name = "ArchPost", Size = Vector3.new(2.4, 15, 2.4), CFrame = CFrame.new(base.X + x, base.Y + 7.5, archZ), Color = C.Sandstone, Material = Enum.Material.Sandstone, Parent = pav })
		part({ Name = "ArchPostCap", Size = Vector3.new(3.2, 1, 3.2), CFrame = CFrame.new(base.X + x, base.Y + 15.5, archZ), Color = C.Gold, Material = Enum.Material.Metal, Parent = pav })
	end
	local panel = part({
		Name = "WelcomePanel",
		Size = Vector3.new(26, 5, 1),
		CFrame = CFrame.lookAt(Vector3.new(base.X, base.Y + 13, archZ), Vector3.new(base.X, base.Y + 13, archZ + 1)),
		Color = Color3.fromRGB(40, 32, 70),
		Material = Enum.Material.SmoothPlastic,
		Parent = pav,
	})
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		local surface = Instance.new("SurfaceGui")
		surface.Face = face
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 24
		surface.LightInfluence = 0
		surface.Parent = panel
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.FredokaOne
		text.TextScaled = true
		text.RichText = true
		text.TextColor3 = C.Gold
		text.Text = if face == Enum.NormalId.Front
			then "STEAL THE TREASURE\n<font color=\"#ffffff\" size=\"60\">TRAIN • FIND • CARRY • EXTRACT</font>"
			else "WELCOME HOME, TREASURE HUNTER"
		text.Parent = surface
	end
	for _, x in { -18, 18 } do
		part({ Name = "Planter", Size = Vector3.new(6, 1.2, 6), CFrame = CFrame.new(base.X + x, base.Y + 0.6, base.Z + 16), Color = Color3.fromRGB(160, 90, 70), Material = Enum.Material.Brick, Parent = pav })
		Props.Flowers(pav, Vector3.new(base.X + x, base.Y + 1.2, base.Z + 16), rng, 9)
	end
end

-- Stone wall around the District: the north gatehouse is the ONLY way to the Wilds.
-- An invisible barrier above the wall stops Balloons/Grapples from skipping the gate.
local function buildWall(district: Folder)
	local walls = folder("DistrictWall", district)
	local d = WorldLayout.District
	local center = Vector3.new(d.Center.X, d.Center.Y, d.Center.Z)
	local radius, height = d.WallRadius, d.WallHeight
	local stone = Color3.fromRGB(196, 186, 168)
	local gateGap = math.deg(d.GateHalfWidth / radius) + 1.5
	local span = 360 - gateGap * 2
	local segments = math.ceil(span / 6)
	local step = span / segments
	local function onCircle(degreesFromGate: number, y: number): (Vector3, CFrame)
		local a = math.rad(180 + degreesFromGate)
		local pos = center + Vector3.new(math.sin(a) * radius, y, math.cos(a) * radius)
		return pos, CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z))
	end
	local length = 2 * radius * math.sin(math.rad(step / 2)) + 1
	for k = 0, segments - 1 do
		local b = gateGap + (k + 0.5) * step
		local _, cf = onCircle(b, height / 2)
		part({ Name = "Wall", Size = Vector3.new(length, height, 3), CFrame = cf, Color = stone, Material = Enum.Material.Cobblestone, Parent = walls })
		part({ Name = "WallCap", Size = Vector3.new(length, 1, 3.8), CFrame = cf * CFrame.new(0, height / 2 + 0.5, 0), Color = Color3.fromRGB(170, 160, 145), Material = Enum.Material.Slate, Parent = walls })
		for m = -1, 1 do
			part({ Name = "Merlon", Size = Vector3.new(2.2, 2, 1.6), CFrame = cf * CFrame.new(m * length / 3, height / 2 + 2, 1), Color = stone, Material = Enum.Material.Cobblestone, Parent = walls })
		end
		part({
			Name = "Barrier",
			Size = Vector3.new(length, 110, 3),
			CFrame = cf * CFrame.new(0, height / 2 + 1 + 55, 0),
			Transparency = 1,
			CanQuery = false,
			CastShadow = false,
			Parent = walls,
		})
		if k % 5 == 2 then
			local towerPos = onCircle(b, 0)
			cylinder(towerPos + Vector3.new(0, (height + 6) / 2, 0), height + 6, 9, { Name = "Tower", Color = stone, Material = Enum.Material.Cobblestone, Parent = walls })
			cylinder(towerPos + Vector3.new(0, height + 6.8, 0), 1.6, 10.5, { Name = "TowerRim", Color = Color3.fromRGB(170, 160, 145), Material = Enum.Material.Slate, Parent = walls })
			cylinder(towerPos + Vector3.new(0, height + 9, 0), 3, 8, { Name = "Roof1", Color = C.Red, Material = Enum.Material.Slate, Parent = walls })
			cylinder(towerPos + Vector3.new(0, height + 11.5, 0), 2, 5, { Name = "Roof2", Color = C.Red, Material = Enum.Material.Slate, Parent = walls })
			cylinder(towerPos + Vector3.new(0, height + 13.3, 0), 1.6, 2, { Name = "Roof3", Color = C.Red, Material = Enum.Material.Slate, Parent = walls })
		end
	end

	-- Gatehouse
	local gate = d.Gate
	for _, x in { -1, 1 } do
		local towerPos = Vector3.new(gate.X + x * (d.GateHalfWidth + 5), gate.Y, gate.Z)
		part({ Name = "GateTower", Size = Vector3.new(10, height + 12, 10), CFrame = CFrame.new(towerPos + Vector3.new(0, (height + 12) / 2, 0)), Color = stone, Material = Enum.Material.Cobblestone, Parent = walls })
		for mx = -1, 1, 2 do
			for mz = -1, 1, 2 do
				part({ Name = "GateMerlon", Size = Vector3.new(2.4, 2.4, 2.4), CFrame = CFrame.new(towerPos + Vector3.new(mx * 3.8, height + 13.2, mz * 3.8)), Color = stone, Material = Enum.Material.Cobblestone, Parent = walls })
			end
		end
		Props.Brazier(walls, towerPos + Vector3.new(0, 0, 7))
		part({ Name = "Banner", Size = Vector3.new(4, 9, 0.3), CFrame = CFrame.new(towerPos + Vector3.new(0, height + 4, -5.2)), Color = C.Red, Material = Enum.Material.Fabric, CanCollide = false, Parent = walls })
		part({ Name = "BannerEmblem", Size = Vector3.new(2, 2, 0.35), CFrame = CFrame.new(towerPos + Vector3.new(0, height + 5, -5.25)) * CFrame.Angles(0, 0, math.rad(45)), Color = C.Gold, Material = Enum.Material.Metal, CanCollide = false, Parent = walls })
	end
	local arch = part({ Name = "GateArch", Size = Vector3.new(d.GateHalfWidth * 2 + 2, 5, 8), CFrame = CFrame.new(gate + Vector3.new(0, height + 6.5, 0)), Color = stone, Material = Enum.Material.Cobblestone, Parent = walls })
	part({ Name = "GateBarrier", Size = Vector3.new(d.GateHalfWidth * 2, 100, 3), CFrame = CFrame.new(gate + Vector3.new(0, height + 9 + 50, 0)), Transparency = 1, CanQuery = false, CastShadow = false, Parent = walls })
	for _, x in { -1, 1 } do
		part({ Name = "GateDoor", Size = Vector3.new(d.GateHalfWidth - 1, height + 2, 1), CFrame = CFrame.new(gate + Vector3.new(x * (d.GateHalfWidth + 1), (height + 2) / 2, 5)) * CFrame.Angles(0, math.rad(x * 80), 0) * CFrame.new(x * (d.GateHalfWidth - 1) / 2, 0, 0), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = walls })
	end
	billboardSign(arch, "THE WILDS", "Treasure awaits. Danger too.", C.Gold, 300, 5, 24)
end

local function buildDistrict()
	local d = WorldLayout.District
	local district = folder("TreasureDistrict")
	local center = d.Center

	cylinder(center + Vector3.new(0, 0.5, 0), 1, d.FloorRadius * 2, {
		Name = "Plaza",
		Color = Color3.fromRGB(232, 222, 196),
		Material = Enum.Material.Pavement,
		Parent = district,
	})
	cylinder(center + Vector3.new(0, 0.55, 0), 1.02, 70, {
		Name = "InnerPlaza",
		Color = Color3.fromRGB(210, 175, 120),
		Material = Enum.Material.Pavement,
		Parent = district,
	})

	-- Fountain with a giant golden coin: the District's own landmark
	cylinder(center + Vector3.new(0, 2, 0), 3, 26, { Name = "FountainRim", Color = C.Stone, Material = Enum.Material.Marble, Parent = district })
	cylinder(center + Vector3.new(0, 2.6, 0), 2, 22, { Name = "FountainWater", Color = Color3.fromRGB(60, 180, 220), Material = Enum.Material.Glass, Transparency = 0.3, Parent = district })
	cylinder(center + Vector3.new(0, 6, 0), 8, 4, { Name = "FountainPillar", Color = C.Stone, Material = Enum.Material.Marble, Parent = district })
	local coin = part({
		Name = "GoldenCoin",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.6, 14, 14),
		CFrame = CFrame.new(center + Vector3.new(0, 17, 0)) * CFrame.Angles(0, math.rad(90), 0),
		Color = C.Gold,
		Material = Enum.Material.Metal,
		Parent = district,
	})
	coin:SetAttribute("Spin", 0.6)
	local coinLight = Instance.new("PointLight")
	coinLight.Color = C.Gold
	coinLight.Range = 30
	coinLight.Brightness = 1.5
	coinLight.Parent = coin

	buildSpawnPavilion(district)
	buildWall(district)

	return district
end

-- Strength Gym: rows of treadmills, one row per tier. Belts run toward +X (the plaza).
local function buildGym(district: Folder)
	local gym = folder("StrengthGym", district)
	local layout = WorldLayout.Gym
	local machines = {}
	local floorY = WorldLayout.District.Center.Y + 1
	local tiers = GameConfig.Training.Treadmills
	local firstX = layout.Origin.X
	local lastX = layout.Origin.X + (#tiers - 1) * layout.RowSpacing
	local lanes = 0
	for _, tier in tiers do
		lanes = math.max(lanes, tier.Count)
	end
	local zMin = layout.Origin.Z - 5
	local zMax = layout.Origin.Z + (lanes - 1) * layout.LaneSpacing + 5
	-- Rubber gym floor under all rows
	part({
		Name = "GymFloor",
		Size = Vector3.new(math.abs(lastX - firstX) + 16, 0.3, zMax - zMin),
		CFrame = CFrame.new((firstX + lastX) / 2, floorY + 0.15, (zMin + zMax) / 2),
		Color = Color3.fromRGB(55, 60, 75),
		Material = Enum.Material.Rubber,
		Parent = gym,
	})
	for row, tier in tiers do
		local color = Color3.fromRGB(tier.Color[1], tier.Color[2], tier.Color[3])
		local x = layout.Origin.X + (row - 1) * layout.RowSpacing
		for lane = 1, tier.Count do
			local z = layout.Origin.Z + (lane - 1) * layout.LaneSpacing
			local beltCf = CFrame.lookAt(Vector3.new(x, floorY + 0.9, z), Vector3.new(x + 1, floorY + 0.9, z))
			-- Frame + belt
			part({ Name = "Frame", Size = Vector3.new(4.6, 1, 8.6), CFrame = beltCf * CFrame.new(0, -0.3, 0), Color = Color3.fromRGB(40, 42, 50), Material = Enum.Material.Metal, Parent = gym })
			local belt = part({ Name = "Belt", Size = Vector3.new(3.6, 0.3, 8), CFrame = beltCf * CFrame.new(0, 0.35, 0), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Rubber, Parent = gym })
			for _, side in { -2.2, 2.2 } do
				part({ Name = "Trim", Size = Vector3.new(0.3, 0.4, 8.4), CFrame = beltCf * CFrame.new(side, 0.35, 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, Parent = gym })
				part({ Name = "Upright", Size = Vector3.new(0.35, 4, 0.35), CFrame = beltCf * CFrame.new(side, 2.3, -3.6) * CFrame.Angles(math.rad(-12), 0, 0), Color = Color3.fromRGB(70, 72, 80), Material = Enum.Material.Metal, Parent = gym })
			end
			part({ Name = "Handlebar", Size = Vector3.new(4.8, 0.35, 0.35), CFrame = beltCf * CFrame.new(0, 4.1, -4), Color = Color3.fromRGB(70, 72, 80), Material = Enum.Material.Metal, Parent = gym })
			local console = part({ Name = "Console", Size = Vector3.new(2.6, 1.6, 0.4), CFrame = beltCf * CFrame.new(0, 4.6, -4.2) * CFrame.Angles(math.rad(-20), 0, 0), Color = color, Material = Enum.Material.Neon, Parent = gym })
			local runPrompt = prompt(belt, if tier.Price > 0 then "Run / Unlock" else "Run", tier.Name, if tier.Price > 0 then 0.8 else 0)
			runPrompt.MaxActivationDistance = 9
			table.insert(machines, { Tier = tier, BeltCFrame = beltCf * CFrame.new(0, 0.5, 0), Prompt = runPrompt, Occupant = nil, Console = console })
		end
		-- Row sign: tier name, rate and unlock requirement
		local signPost = part({
			Name = "RowSign",
			Size = Vector3.new(0.6, 5, 0.6),
			CFrame = CFrame.new(x, floorY + 2.5, zMin - 1),
			Color = Color3.fromRGB(70, 72, 80),
			Material = Enum.Material.Metal,
			Parent = gym,
		})
		local priceText = tostring(tier.Price):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		local unlock = if tier.Price > 0 then ("$%s • %d STR"):format(priceText, tier.RequiredStrength) else "FREE"
		billboardSign(signPost, tier.Name:upper(), ("+%.2f 💪/s  •  %s"):format(tier.Rate, unlock), color, 90, 4, 10)
	end
	local header = part({
		Name = "GymHeader",
		Size = Vector3.new(1, 1, 1),
		CFrame = CFrame.new((firstX + lastX) / 2, floorY + 14, (zMin + zMax) / 2),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
		Parent = gym,
	})
	billboardSign(header, "💪 STRENGTH GYM", "Stand on a treadmill • Tap SPRINT to boost", C.Gold, 200, 0, 26)
	return machines
end

local function buildShop(district: Folder)
	local pos = WorldLayout.Shop
	local shop = folder("GadgetShop", district)
	local facing = CFrame.lookAt(pos, Vector3.new(WorldLayout.District.Center.X, pos.Y, WorldLayout.District.Center.Z))
	local counter = part({ Name = "Counter", Size = Vector3.new(16, 4, 4), CFrame = facing * CFrame.new(0, 3, 0), Color = C.Wood, Material = Enum.Material.Wood, Parent = shop })
	for _, x in { -7.5, 7.5 } do
		part({ Name = "Post", Size = Vector3.new(1, 12, 1), CFrame = facing * CFrame.new(x, 7, 2), Color = C.DarkWood, Parent = shop })
	end
	for i = 0, 7 do
		part({ Name = "Awning", Size = Vector3.new(2, 0.4, 7), CFrame = facing * CFrame.new(-7 + i * 2, 13.2, 0) * CFrame.Angles(math.rad(-12), 0, 0), Color = if i % 2 == 0 then C.Red else C.Cream, Parent = shop })
	end
	for i, colorValue in { Color3.fromRGB(255, 120, 60), Color3.fromRGB(255, 70, 90), Color3.fromRGB(150, 220, 255) } do
		part({ Name = "Display", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = facing * CFrame.new(-5 + (i - 1) * 5, 6, 0), Color = colorValue, Material = Enum.Material.Neon, Parent = shop })
	end
	billboardSign(counter, "GADGET SHOP", "Toys for escapes & chaos", C.Teal, 160, 12, 14)
	return prompt(counter, "Browse", "Gadget Shop", 0)
end

local function buildAscensionAltar(district: Folder)
	local pos = WorldLayout.AscensionAltar
	local altar = folder("AscensionAltar", district)
	cylinder(pos + Vector3.new(0, 1.5, 0), 2, 18, { Name = "Base", Color = C.Cream, Material = Enum.Material.Marble, Parent = altar })
	cylinder(pos + Vector3.new(0, 2.55, 0), 0.2, 14, { Name = "Ring", Color = C.Secret, Material = Enum.Material.Neon, CanCollide = false, Parent = altar })
	local obelisk = part({ Name = "Obelisk", Size = Vector3.new(3, 16, 3), CFrame = CFrame.new(pos + Vector3.new(0, 10.5, 0)) * CFrame.Angles(0, math.rad(45), 0), Color = Color3.fromRGB(60, 40, 90), Material = Enum.Material.Slate, Parent = altar })
	local gem = part({ Name = "Gem", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(pos + Vector3.new(0, 21, 0)) * CFrame.Angles(math.rad(45), 0, math.rad(45)), Color = C.Secret, Material = Enum.Material.Neon, Parent = altar })
	gem:SetAttribute("Spin", 1.2)
	billboardSign(gem, "ASCENSION", ("Reach %d Strength"):format(GameConfig.Ascension.RequiredStrength), C.Secret, 160, 4, 12)
	return prompt(obelisk, "Ascend", "Ascension Altar", 0.5)
end

-- Vault plots: an open marble gallery with an arched entrance, red carpet and tall corner
-- towers that frame the upper floors a vault grows into (floors themselves are built by
-- VaultService as the owner upgrades).
local function buildVaultPlots(district: Folder)
	local d = WorldLayout.District
	local vcfg = GameConfig.Vault
	local plots = {}
	local vaults = folder("Vaults", district)
	local maxSlots = 0
	for _, tier in vcfg.Tiers do
		if tier.Enabled then
			maxSlots = math.max(maxSlots, tier.Slots)
		end
	end
	local floors = math.ceil(maxSlots / vcfg.PerFloor)
	local towerHeight = (floors - 1) * vcfg.FloorHeight + 12
	local half = vcfg.PlotSize / 2
	local count = GameConfig.MaxPlayers
	for i = 1, count do
		local t = if count == 1 then 0.5 else (i - 1) / (count - 1)
		local angle = math.rad(-d.VaultArcDegrees / 2 + t * d.VaultArcDegrees)
		local pos = d.Center + Vector3.new(math.sin(angle) * d.VaultArcRadius, 1, math.cos(angle) * d.VaultArcRadius)
		local cf = CFrame.lookAt(pos, Vector3.new(d.Center.X, pos.Y, d.Center.Z))
		local plotFolder = folder("Vault" .. i, vaults)
		-- Floor with a gold border
		part({ Name = "Border", Size = Vector3.new(vcfg.PlotSize + 1, 0.5, vcfg.PlotSize + 1), CFrame = cf * CFrame.new(0, 0.25, 0), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		part({ Name = "Floor", Size = Vector3.new(vcfg.PlotSize - 1, 0.6, vcfg.PlotSize - 1), CFrame = cf * CFrame.new(0, 0.3, 0), Color = Color3.fromRGB(62, 52, 88), Material = Enum.Material.Marble, Parent = plotFolder })
		part({ Name = "Carpet", Size = Vector3.new(5, 0.08, half + 2), CFrame = cf * CFrame.new(0, 0.64, -half / 2 - 1), Color = Color3.fromRGB(180, 30, 50), Material = Enum.Material.Fabric, CanCollide = false, Parent = plotFolder })
		-- Back wall with emblem
		part({ Name = "BackWall", Size = Vector3.new(vcfg.PlotSize, 10, 1), CFrame = cf * CFrame.new(0, 5, half), Color = C.Cream, Material = Enum.Material.Marble, Parent = plotFolder })
		part({ Name = "WallTrim", Size = Vector3.new(vcfg.PlotSize + 0.4, 0.6, 1.4), CFrame = cf * CFrame.new(0, 10.2, half), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		part({ Name = "Emblem", Size = Vector3.new(3.2, 3.2, 0.4), CFrame = cf * CFrame.new(0, 6.5, half - 0.6) * CFrame.Angles(0, 0, math.rad(45)), Color = C.Gold, Material = Enum.Material.Neon, CanCollide = false, Parent = plotFolder })
		-- Low balustrades on the sides keep the gallery visible from the plaza
		for _, x in { -half, half } do
			part({ Name = "Balustrade", Size = Vector3.new(1, 2.4, vcfg.PlotSize), CFrame = cf * CFrame.new(x, 1.8, 0), Color = C.Cream, Material = Enum.Material.Marble, Parent = plotFolder })
			part({ Name = "Rail", Size = Vector3.new(1.4, 0.4, vcfg.PlotSize), CFrame = cf * CFrame.new(x, 3.2, 0), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		end
		-- Corner towers: the frame the vault grows into
		for _, x in { -half, half } do
			for _, z in { -half, half } do
				part({ Name = "CornerTower", Size = Vector3.new(2, towerHeight, 2), CFrame = cf * CFrame.new(x, towerHeight / 2 + 0.5, z), Color = Color3.fromRGB(235, 228, 210), Material = Enum.Material.Marble, Parent = plotFolder })
				part({ Name = "TowerCap", Size = Vector3.new(2.8, 1, 2.8), CFrame = cf * CFrame.new(x, towerHeight + 1, z), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
			end
		end
		-- Entrance arch with the owner's name plaque
		for _, x in { -5, 5 } do
			part({ Name = "ArchPost", Size = Vector3.new(1.6, 9, 1.6), CFrame = cf * CFrame.new(x, 5, -half), Color = C.Cream, Material = Enum.Material.Marble, Parent = plotFolder })
		end
		local plaque = part({ Name = "ArchTop", Size = Vector3.new(12, 2.2, 1.8), CFrame = cf * CFrame.new(0, 10.4, -half), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		local sign = billboardSign(plaque, "EMPTY VAULT", nil, C.Gold, 140, 2.2, 16)
		local terminal = part({ Name = "Terminal", Size = Vector3.new(2.2, 3.4, 2.2), CFrame = cf * CFrame.new(-8.5, 2.3, -half + 1.5), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		part({ Name = "TerminalScreen", Size = Vector3.new(1.8, 1.2, 0.2), CFrame = cf * CFrame.new(-8.5, 3.6, -half + 0.35) * CFrame.Angles(math.rad(-20), 0, 0), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, CanCollide = false, Parent = plotFolder })
		local displays = folder("Displays", plotFolder)
		table.insert(plots, {
			Index = i,
			CFrame = cf * CFrame.new(0, 0.6, 0), -- floor surface
			Sign = sign:FindFirstChild("Title") :: TextLabel,
			Prompt = prompt(terminal, "Edit Vault", "Vault", 0),
			Displays = displays,
			Owner = nil,
		})
	end
	return plots
end

local function buildLeaderboards(district: Folder)
	local boardsFolder = folder("Leaderboards", district)
	local d = WorldLayout.District
	local layout = WorldLayout.Leaderboards
	local defs = GameConfig.Leaderboards.Boards
	local boards = {}
	for i, def in defs do
		local t = if #defs == 1 then 0.5 else (i - 1) / (#defs - 1)
		local angle = math.rad(-layout.SpreadDegrees / 2 + t * layout.SpreadDegrees)
		local pos = d.Center + Vector3.new(math.sin(angle) * layout.Radius, 10.5, -math.cos(angle) * layout.Radius)
		local facing = CFrame.lookAt(pos, Vector3.new(WorldLayout.Spawn.X, pos.Y, WorldLayout.Spawn.Z))
		local board = part({
			Name = def.Id,
			Size = Vector3.new(12, 15, 0.8),
			CFrame = facing,
			Color = Color3.fromRGB(28, 32, 52),
			Material = Enum.Material.SmoothPlastic,
			Parent = boardsFolder,
		})
		part({ Name = "Frame", Size = Vector3.new(12.8, 15.8, 0.6), CFrame = facing * CFrame.new(0, 0, 0.3), Color = C.Gold, Material = Enum.Material.Metal, Parent = boardsFolder })
		for _, x in { -5, 5 } do
			part({ Name = "Leg", Size = Vector3.new(0.8, 4, 0.8), CFrame = facing * CFrame.new(x, -9, 0), Color = C.DarkWood, Parent = boardsFolder })
		end
		local surface = Instance.new("SurfaceGui")
		surface.Name = "Board"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 30
		surface.LightInfluence = 0
		surface.MaxDistance = 140
		surface.Parent = board
		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, 0, 0, 56)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = C.Gold
		title.Text = def.Icon .. " " .. def.Title
		title.Parent = surface
		local rows = Instance.new("Frame")
		rows.Name = "Rows"
		rows.BackgroundTransparency = 1
		rows.Position = UDim2.fromOffset(14, 64)
		rows.Size = UDim2.new(1, -28, 1, -74)
		rows.Parent = surface
		local list = Instance.new("UIListLayout")
		list.SortOrder = Enum.SortOrder.LayoutOrder
		list.Padding = UDim.new(0, 4)
		list.Parent = rows
		boards[def.Id] = rows
	end
	return boards
end

-- WILDS -------------------------------------------------------------------------

local function tooClose(x: number, z: number, avoid): boolean
	for _, a in avoid do
		if (Vector2.new(x, z) - a[1]).Magnitude < a[2] then
			return true
		end
	end
	return false
end

local function buildWilds()
	local wilds = folder("Wilds")
	local avoid = {
		{ Vector2.new(WorldLayout.District.Center.X, WorldLayout.District.Center.Z), WorldLayout.District.FloorRadius + 8 },
		{ Vector2.new(WorldLayout.Temple.Center.X, WorldLayout.Temple.Center.Z - 20), 110 },
		{ Vector2.new(0, -330), 70 },
		{ Vector2.new(WorldLayout.Shipwreck.CoveCenter.X, WorldLayout.Shipwreck.CoveCenter.Z), 120 },
		{ Vector2.new(0, 70), 25 }, -- camp
		{ Vector2.new(WorldLayout.Volcano.Center.X, WorldLayout.Volcano.Center.Z), WorldLayout.Volcano.BaseRadius + 20 },
	}
	for _, spawnInfo in WorldLayout.TreasureSpawns do
		table.insert(avoid, { Vector2.new(spawnInfo.Position.X, spawnInfo.Position.Z), 8 })
	end
	for _, zone in WorldLayout.ExtractionZones do
		table.insert(avoid, { Vector2.new(zone.Position.X, zone.Position.Z), zone.Radius + 8 })
	end

	-- Keep the trails clear of vegetation.
	local gate = WorldLayout.District.Gate
	local trails = {
		{ gate, Vector3.new(0, 10, -270) },
		{ gate + Vector3.new(0, 0, -45), WorldLayout.Temple.Courtyard + Vector3.new(0, 0, 15) },
		{ gate + Vector3.new(0, 0, -45), WorldLayout.Shipwreck.Center + Vector3.new(60, 0, 0) },
	}
	for _, trail in trails do
		local delta = trail[2] - trail[1]
		for d = 0, delta.Magnitude, 10 do
			local p = trail[1] + delta.Unit * d
			table.insert(avoid, { Vector2.new(p.X, p.Z), 8 })
		end
	end

	-- Scatter helper: tries random points on the island, calls place(ground, x, z, coast) when the
	-- spot is clear. Spacing keeps props from overlapping each other.
	local function scatter(count: number, spacing: number, accept: (Vector3, number) -> boolean, place)
		local placed, attempts = 0, 0
		while placed < count and attempts < count * 12 do
			attempts += 1
			local r = math.sqrt(rng:NextNumber()) * 540
			local a = rng:NextNumber(0, math.pi * 2)
			local x, z = math.cos(a) * r, math.sin(a) * r
			if not tooClose(x, z, avoid) then
				local ground = groundAt(x, z)
				local _, coast = TerrainGen.Height(x, z)
				if accept(ground, coast) then
					place(ground, coast)
					placed += 1
					table.insert(avoid, { Vector2.new(x, z), spacing })
				end
			end
		end
	end

	local trees = folder("Trees", wilds)
	-- Palms line the beaches, broadleaf trees fill the interior (clustered by noise into groves).
	scatter(55, 9, function(ground, coast)
		return ground.Y > 2.5 and ground.Y < 12 and coast > 0.08
	end, function(ground)
		Props.Palm(trees, ground, rng)
	end)
	scatter(190, 9, function(ground, coast)
		local grove = math.noise(ground.X / 90, ground.Z / 90, 3.7)
		return ground.Y > 8 and coast < 0.15 and grove > -0.15
	end, function(ground)
		Props.Broadleaf(trees, ground, rng)
	end)
	local undergrowth = folder("Undergrowth", wilds)
	scatter(150, 5, function(ground, coast)
		return ground.Y > 8 and coast < 0.2
	end, function(ground)
		Props.Bush(undergrowth, ground, rng)
	end)
	scatter(90, 6, function(ground, coast)
		return ground.Y > 8.5 and coast < 0.1
	end, function(ground)
		Props.Flowers(undergrowth, ground, rng)
	end)
	scatter(45, 12, function(ground)
		return ground.Y > 4
	end, function(ground)
		Props.Rocks(undergrowth, ground, rng)
	end)

	-- Dirt trails from the gate toward each landmark
	for _, trail in trails do
		paintPath(trail[1], trail[2], 9)
	end
	-- Bridge rails
	local railCf = CFrame.new(Vector3.new(120, 10, 10) + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(20), 0)
	for _, side in { -4.2, 4.2 } do
		part({ Name = "Rope", Size = Vector3.new(26, 0.3, 0.3), CFrame = railCf * CFrame.new(0, 3, side), Color = Color3.fromRGB(190, 160, 110), Material = Enum.Material.Fabric, CanCollide = false, Parent = wilds })
		for i = -2, 2 do
			part({ Name = "Post", Size = Vector3.new(0.5, 3.5, 0.5), CFrame = railCf * CFrame.new(i * 6, 1.6, side), Color = C.DarkWood, Material = Enum.Material.Wood, Parent = wilds })
		end
	end

	-- A rope bridge over a small ravine on the ruins trail
	local ravine = Vector3.new(120, 10, 10)
	-- Shallow water at the bottom lets anyone who falls in swim back out.
	terrain:FillBlock(CFrame.new(ravine + Vector3.new(0, -2, 0)) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(14, 8, 60), Enum.Material.Air)
	terrain:FillBlock(CFrame.new(ravine + Vector3.new(0, -4, 0)) * CFrame.Angles(0, math.rad(20), 0), Vector3.new(14, 4, 60), Enum.Material.Water)
	local bridgeCf = CFrame.new(ravine + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, math.rad(20), 0)
	for i = -4, 4 do
		part({ Name = "Plank", Size = Vector3.new(2.6, 0.5, 8), CFrame = bridgeCf * CFrame.new(i * 2.8, 0, 0), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = wilds })
	end
end

-- LANDMARKS ---------------------------------------------------------------------

local function buildWaterfall()
	local w = WorldLayout.Waterfall
	local falls = folder("GiantWaterfall")
	terrain:FillBlock(CFrame.new(w.CliffCenter), w.CliffSize, Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(-150, 65, -385), Vector3.new(170, 130, 60), Enum.Material.Rock)
	terrain:FillBlock(CFrame.new(150, 55, -380), Vector3.new(120, 110, 60), Enum.Material.Rock)
	local topY = w.CliffCenter.Y + w.CliffSize.Y / 2
	terrain:FillBlock(CFrame.new(0, topY - 1, w.CliffCenter.Z), Vector3.new(w.CliffSize.X, 2, w.CliffSize.Z), Enum.Material.Grass)
	-- River on the cliff top feeding the falls
	terrain:FillBlock(CFrame.new(0, topY - 2, w.CliffCenter.Z - 10), Vector3.new(w.FallWidth, 4, 60), Enum.Material.Water)
	-- Hidden cave behind the falls (secret extraction)
	terrain:FillBlock(CFrame.new(w.CaveCenter), w.CaveSize, Enum.Material.Air)
	-- Plunge pool
	terrain:FillCylinder(CFrame.new(w.PoolCenter + Vector3.new(0, -3, 0)), 8, w.PoolRadius, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(w.PoolCenter + Vector3.new(0, -5.5, 0)), 3, w.PoolRadius, Enum.Material.Water)

	local faceZ = w.CliffCenter.Z + w.CliffSize.Z / 2
	local sheet = part({
		Name = "FallingWater",
		Size = Vector3.new(w.FallWidth, topY - 6, 1.5),
		CFrame = CFrame.new(0, (topY + 6) / 2, faceZ + 1.5),
		Color = Color3.fromRGB(150, 220, 245),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = falls,
	})
	local mistAttachment = Instance.new("Attachment")
	mistAttachment.Position = Vector3.new(0, -sheet.Size.Y / 2 + 2, 2)
	mistAttachment.Parent = sheet
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.new(1, 1, 1))
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	mist.Size = NumberSequence.new(8, 18)
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Rate = 14
	mist.Speed = NumberRange.new(4, 8)
	mist.SpreadAngle = Vector2.new(60, 20)
	mist.Parent = mistAttachment

	-- Ramp up to the cliff top lookout
	local bottom = Vector3.new(40, 10, faceZ + 9)
	local topPos = Vector3.new(170, topY, faceZ + 9)
	local delta = topPos - bottom
	local angle = math.atan2(delta.Y, delta.X)
	part({
		Name = "CliffRamp",
		Size = Vector3.new(delta.Magnitude, 3, 22),
		CFrame = CFrame.new((bottom + topPos) / 2 + Vector3.new(0, -1.4, 0)) * CFrame.Angles(0, 0, angle),
		Color = Color3.fromRGB(150, 130, 110),
		Material = Enum.Material.Slate,
		Parent = falls,
	})
	local lookout = part({ Name = "Lookout", Size = Vector3.new(16, 1, 16), CFrame = CFrame.new(-40, topY + 0.5, w.CliffCenter.Z), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = falls })
	billboardSign(sheet, "GIANT WATERFALL", nil, Color3.fromRGB(170, 235, 255), 900, sheet.Size.Y / 2 + 6)
	return lookout
end

local function buildTemple()
	local t = WorldLayout.Temple
	local temple = folder("AncientRuins")
	local center = t.Center
	for i = 0, t.Tiers - 1 do
		local size = t.BaseSize - i * 14
		part({
			Name = "Tier" .. i,
			Size = Vector3.new(size, t.TierHeight, size),
			CFrame = CFrame.new(center + Vector3.new(0, t.TierHeight / 2 + i * t.TierHeight, 0)),
			Color = if i % 2 == 0 then C.Sandstone else Color3.fromRGB(205, 170, 110),
			Material = Enum.Material.Sandstone,
			Parent = temple,
		})
	end
	local topY = center.Y + t.Tiers * t.TierHeight
	-- Front stairs (ramp) facing the courtyard (+Z)
	local topEdge = center + Vector3.new(0, t.Tiers * t.TierHeight, (t.BaseSize - (t.Tiers - 1) * 14) / 2)
	local foot = center + Vector3.new(0, 0, t.BaseSize / 2 + 34)
	local delta = topEdge - foot
	local length = delta.Magnitude
	local pitch = math.atan2(delta.Y, -delta.Z)
	part({
		Name = "GrandStairs",
		Size = Vector3.new(12, 2, length),
		CFrame = CFrame.new((topEdge + foot) / 2) * CFrame.Angles(pitch, 0, 0),
		Color = Color3.fromRGB(235, 205, 150),
		Material = Enum.Material.Sandstone,
		Parent = temple,
	})
	-- Roofless shrine pillars on top
	for _, off in { { -6, -6 }, { 6, -6 }, { -6, 6 }, { 6, 6 } } do
		cylinder(Vector3.new(center.X + off[1], topY + 5, center.Z + off[2]), 10, 1.6, { Name = "ShrinePillar", Color = C.Cream, Material = Enum.Material.Marble, Parent = temple })
	end
	local beacon = part({
		Name = "TempleGlow",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(3, 3, 3),
		CFrame = CFrame.new(center.X, topY + 14, center.Z),
		Color = C.Gold,
		Material = Enum.Material.Neon,
		CanCollide = false,
		CanQuery = false,
		Parent = temple,
	})
	billboardSign(beacon, "ANCIENT TEMPLE", nil, C.Gold, 900, 4)

	-- Giant statues guarding the courtyard
	for _, x in { -35, 35 } do
		local base = Vector3.new(center.X + x, 10, t.Courtyard.Z - 20)
		part({ Name = "StatueBase", Size = Vector3.new(10, 4, 10), CFrame = CFrame.new(base + Vector3.new(0, 2, 0)), Color = C.DarkStone, Material = Enum.Material.Slate, Parent = temple })
		part({ Name = "StatueBody", Size = Vector3.new(8, 16, 6), CFrame = CFrame.new(base + Vector3.new(0, 12, 0)), Color = Color3.fromRGB(150, 160, 130), Material = Enum.Material.Slate, Parent = temple })
		part({ Name = "StatueHead", Size = Vector3.new(7, 7, 7), CFrame = CFrame.new(base + Vector3.new(0, 23.5, 0)), Color = Color3.fromRGB(150, 160, 130), Material = Enum.Material.Slate, Parent = temple })
		for _, ex in { -1.5, 1.5 } do
			part({ Name = "StatueEye", Size = Vector3.new(1.2, 0.8, 0.4), CFrame = CFrame.new(base + Vector3.new(ex, 24.5, 3.6)), Color = Color3.fromRGB(90, 255, 200), Material = Enum.Material.Neon, CanCollide = false, Parent = temple })
		end
	end

	-- Courtyard floor + pillars (cover around the Dangerous extraction)
	part({ Name = "Courtyard", Size = Vector3.new(76, 1, 56), CFrame = CFrame.new(t.Courtyard + Vector3.new(0, 0.3, 0)), Color = Color3.fromRGB(215, 190, 140), Material = Enum.Material.Sandstone, Parent = temple })
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local pos = t.Courtyard + Vector3.new(math.cos(a) * 24, 0, math.sin(a) * 19)
		local h = if i % 3 == 0 then 5 else 14
		cylinder(pos + Vector3.new(0, h / 2, 0), h, 3, { Name = "Pillar", Color = C.Cream, Material = Enum.Material.Marble, Parent = temple })
	end
end

local function buildShipwreck()
	local s = WorldLayout.Shipwreck
	local ship = folder("Shipwreck")
	local cf = CFrame.new(s.Center) * CFrame.Angles(0, math.rad(20), math.rad(6))
	part({ Name = "Hull", Size = Vector3.new(64, 13, 18), CFrame = cf * CFrame.new(0, 0, 0), Color = C.DarkWood, Material = Enum.Material.WoodPlanks, Parent = ship })
	part({ Name = "Keel", Size = Vector3.new(58, 4, 10), CFrame = cf * CFrame.new(0, -8, 0), Color = C.DarkWood, Material = Enum.Material.Wood, Parent = ship })
	part({ Name = "Deck", Size = Vector3.new(60, 1, 16), CFrame = cf * CFrame.new(0, 7, 0), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = ship })
	part({ Name = "Bow", Class = "WedgePart", Size = Vector3.new(18, 13, 14), CFrame = cf * CFrame.new(-39, 0, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = C.DarkWood, Material = Enum.Material.WoodPlanks, Parent = ship })
	part({ Name = "Cabin", Size = Vector3.new(14, 8, 16), CFrame = cf * CFrame.new(24, 11.5, 0), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.WoodPlanks, Parent = ship })
	local mastCf = cf * CFrame.new(-6, 26, 0) * CFrame.Angles(math.rad(14), 0, math.rad(-8))
	part({ Name = "Mast", Shape = Enum.PartType.Cylinder, Size = Vector3.new(38, 2, 2), CFrame = mastCf * CFrame.Angles(0, 0, math.rad(90)), Color = C.Wood, Material = Enum.Material.Wood, Parent = ship })
	part({ Name = "Sail", Size = Vector3.new(0.4, 14, 20), CFrame = mastCf * CFrame.new(0, 6, 0) * CFrame.Angles(0, math.rad(90), math.rad(8)), Color = Color3.fromRGB(235, 225, 200), Material = Enum.Material.Fabric, Parent = ship })
	local flag = part({ Name = "Flag", Size = Vector3.new(0.2, 4, 6), CFrame = mastCf * CFrame.new(0, 20, 3), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Fabric, CanCollide = false, Parent = ship })
	billboardSign(flag, "SHIPWRECK COAST", nil, Color3.fromRGB(255, 240, 200), 900, 4)
	-- Crates as steps onto the deck
	for i, off in { Vector3.new(22, -3, 12), Vector3.new(16, -1, 14), Vector3.new(10, 1, 13) } do
		local size = 6 - i
		part({ Name = "Crate", Size = Vector3.new(size + 2, size + 2, size + 2), CFrame = cf * CFrame.new(off), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = ship })
	end
end

local function buildLighthouse()
	local pos = Vector3.new(360, 8, 300)
	local ground = groundAt(pos.X, pos.Z)
	local lh = folder("Lighthouse")
	for i = 0, 5 do
		cylinder(ground + Vector3.new(0, 4 + i * 8, 0), 8, 12 - i, {
			Name = "Tower",
			Color = if i % 2 == 0 then Color3.new(1, 1, 1) else C.Red,
			Material = Enum.Material.SmoothPlastic,
			Parent = lh,
		})
	end
	local lamp = part({ Name = "Lamp", Shape = Enum.PartType.Ball, Size = Vector3.new(6, 6, 6), CFrame = CFrame.new(ground + Vector3.new(0, 52, 0)), Color = Color3.fromRGB(255, 240, 180), Material = Enum.Material.Neon, Parent = lh })
	local light = Instance.new("PointLight")
	light.Range = 60
	light.Brightness = 3
	light.Color = Color3.fromRGB(255, 240, 180)
	light.Parent = lamp
end

-- EXTRACTION ZONES --------------------------------------------------------------

local function buildExtractionZones()
	local zonesFolder = folder("ExtractionZones")
	local colors = { Safe = C.Safe, Dangerous = C.Danger, Secret = C.Secret }
	for _, zone in WorldLayout.ExtractionZones do
		local ground = groundAt(zone.Position.X, zone.Position.Z, zone.RayFrom)
		zone.ResolvedPosition = ground
		local color = colors[zone.Category]
		local zf = folder(zone.Id, zonesFolder)
		cylinder(ground + Vector3.new(0, 0.15, 0), 0.3, zone.Radius * 2, { Name = "Pad", Color = color, Material = Enum.Material.Neon, Transparency = 0.55, CanCollide = false, CanQuery = false, Parent = zf })
		cylinder(ground + Vector3.new(0, 0.2, 0), 0.3, zone.Radius * 2 - 3, { Name = "Inner", Color = Color3.fromRGB(30, 30, 40), Material = Enum.Material.SmoothPlastic, Transparency = 0.5, CanCollide = false, CanQuery = false, Parent = zf })
		local beamHeight = if zone.Category == "Secret" then 16 else 140
		local beam = cylinder(ground + Vector3.new(0, beamHeight / 2, 0), beamHeight, if zone.Category == "Secret" then 1 else 3, {
			Name = "Beacon",
			Color = color,
			Material = Enum.Material.Neon,
			Transparency = 0.55,
			CanCollide = false,
			CanQuery = false,
			CastShadow = false,
			Parent = zf,
		})
		local label = ("%s EXTRACTION"):format(GameConfig.Extraction.Categories[zone.Category].Label)
		local bonus = GameConfig.Extraction.Categories[zone.Category].Bonus
		billboardSign(beam, zone.Name:upper(), ("%s • x%.1f CASH"):format(label, bonus), color, if zone.Category == "Secret" then 60 else 600, beamHeight / 2 - 4)

		if zone.Id == "expedition_camp" then
			for i, off in { Vector3.new(-16, 0, -6), Vector3.new(16, 0, -4), Vector3.new(-12, 0, 14) } do
				local tentCf = CFrame.new(ground + off + Vector3.new(0, 3, 0)) * CFrame.Angles(0, math.rad(i * 70), 0)
				part({ Name = "TentL", Class = "WedgePart", Size = Vector3.new(8, 6, 4), CFrame = tentCf * CFrame.new(0, 0, -2), Color = Color3.fromRGB(230, 200, 140), Material = Enum.Material.Fabric, Parent = zf })
				part({ Name = "TentR", Class = "WedgePart", Size = Vector3.new(8, 6, 4), CFrame = tentCf * CFrame.new(0, 0, 2) * CFrame.Angles(0, math.rad(180), 0), Color = Color3.fromRGB(210, 180, 120), Material = Enum.Material.Fabric, Parent = zf })
			end
			local fire = part({ Name = "Campfire", Size = Vector3.new(3, 1, 3), CFrame = CFrame.new(ground + Vector3.new(14, 0.5, 12)), Color = C.DarkWood, Material = Enum.Material.Wood, Parent = zf })
			Instance.new("Fire").Parent = fire
			for _, off in { Vector3.new(10, 1.5, -14), Vector3.new(12, 1.5, -11), Vector3.new(-18, 1.5, 6) } do
				part({ Name = "Crate", Size = Vector3.new(3, 3, 3), CFrame = CFrame.new(ground + off), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = zf })
			end
		elseif zone.Id == "temple_courtyard" then
			part({ Name = "Altar", Size = Vector3.new(4, 3, 2), CFrame = CFrame.new(ground + Vector3.new(0, 1.5, -zone.Radius - 3)), Color = C.Cream, Material = Enum.Material.Marble, Parent = zf })
		end
	end
end

-- DRESSING ----------------------------------------------------------------------
-- Pure decoration layered on top of the gameplay layout. Nothing here affects anchors.

local function dressDistrict()
	local d = WorldLayout.District
	local center = d.Center
	local dressing = folder("DistrictDressing")
	local plazaY = center.Y + 1

	-- Paving rings (stacked discs read as inlaid stone circles)
	for i, ring in { { 104, Color3.fromRGB(205, 170, 120) }, { 100, Color3.fromRGB(232, 222, 196) }, { 64, Color3.fromRGB(190, 150, 105) }, { 60, Color3.fromRGB(232, 222, 196) } } do
		cylinder(Vector3.new(center.X, plazaY + 0.01 * i, center.Z), 0.1, ring[1] * 2, {
			Name = "PavingRing",
			Color = ring[2],
			Material = Enum.Material.Pavement,
			CanCollide = false,
			CanQuery = false,
			Parent = dressing,
		})
	end
	-- Cobbled avenue from the fountain to the north gate
	local avenueStart, avenueEnd = center.Z - 36, d.Gate.Z
	part({
		Name = "Avenue",
		Size = Vector3.new(12, 0.2, avenueStart - avenueEnd),
		CFrame = CFrame.new(center.X, plazaY + 0.06, (avenueStart + avenueEnd) / 2),
		Color = Color3.fromRGB(170, 160, 150),
		Material = Enum.Material.Cobblestone,
		CanCollide = false,
		CanQuery = false,
		Parent = dressing,
	})
	-- Bunting over the avenue
	for _, z in { 125, 160, 195 } do
		for _, x in { -9, 9 } do
			cylinder(Vector3.new(x, plazaY + 6, z), 12, 0.5, { Name = "BuntingPole", Color = C.DarkWood, Material = Enum.Material.Wood, Parent = dressing })
		end
		Props.Bunting(dressing, Vector3.new(-9, plazaY + 11.5, z), Vector3.new(9, plazaY + 11.5, z), rng)
	end

	-- Houses around the edge, facing the plaza
	for _, degrees in { 100, 125, 150, 210, 235, 260 } do
		local a = math.rad(degrees)
		local pos = Vector3.new(center.X + math.sin(a) * 135, plazaY - 1, center.Z + math.cos(a) * 135)
		Props.House(dressing, CFrame.lookAt(pos, Vector3.new(center.X, pos.Y, center.Z)), rng)
	end

	-- Benches + flower beds around the fountain
	for i = 0, 5 do
		local a = math.rad(30 + i * 60)
		local pos = Vector3.new(center.X + math.sin(a) * 22, plazaY, center.Z + math.cos(a) * 22)
		local facing = CFrame.lookAt(pos, Vector3.new(center.X, plazaY, center.Z)) * CFrame.Angles(0, math.rad(180), 0)
		if i % 2 == 0 then
			Props.Bench(dressing, facing)
		else
			part({ Name = "Planter", Size = Vector3.new(7, 1.2, 3), CFrame = facing * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(160, 90, 70), Material = Enum.Material.Brick, Parent = dressing })
			Props.Flowers(dressing, (facing * CFrame.new(0, 1.2, 0)).Position, rng, 8)
		end
	end
	-- Palms for a holiday-town feel
	for _, pos in { Vector3.new(-48, 0, 300), Vector3.new(48, 0, 300), Vector3.new(-96, 0, 250), Vector3.new(96, 0, 250), Vector3.new(-30, 0, 140), Vector3.new(30, 0, 140) } do
		local ground = Vector3.new(pos.X, plazaY, pos.Z)
		cylinder(ground + Vector3.new(0, 0.4, 0), 0.8, 6, { Name = "PalmBed", Color = Color3.fromRGB(150, 110, 70), Material = Enum.Material.Ground, Parent = dressing })
		Props.Palm(dressing, ground + Vector3.new(0, 0.8, 0), rng)
	end
	-- Street lamps along the avenue
	for _, z in { 110, 142, 178, 212 } do
		Props.Lamp(dressing, Vector3.new(-12, plazaY, z))
		Props.Lamp(dressing, Vector3.new(12, plazaY, z))
	end

	-- Fountain jets
	local pillar = dressing.Parent and dressing.Parent:FindFirstChild("TreasureDistrict")
	local jetBase = Instance.new("Part")
	jetBase.Name = "FountainJets"
	jetBase.Anchored = true
	jetBase.CanCollide = false
	jetBase.CanQuery = false
	jetBase.Transparency = 1
	jetBase.Size = Vector3.new(1, 1, 1)
	jetBase.CFrame = CFrame.new(center + Vector3.new(0, 10.5, 0))
	jetBase.Parent = pillar or dressing
	local jets = Instance.new("ParticleEmitter")
	jets.Color = ColorSequence.new(Color3.fromRGB(190, 235, 255))
	jets.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	jets.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.4) })
	jets.Lifetime = NumberRange.new(1.2, 1.6)
	jets.Rate = 45
	jets.Speed = NumberRange.new(14, 18)
	jets.SpreadAngle = Vector2.new(22, 22)
	jets.Acceleration = Vector3.new(0, -30, 0)
	jets.EmissionDirection = Enum.NormalId.Top
	jets.Parent = jetBase
end

local function dressLandmarks()
	local dressing = folder("LandmarkDressing")

	-- Temple: vines down each tier, braziers at the stairs, broken pillar pieces
	local t = WorldLayout.Temple
	for tier = 0, t.Tiers - 2 do
		local size = t.BaseSize - tier * 14
		local topY = t.Center.Y + (tier + 1) * t.TierHeight
		for _ = 1, 3 do
			local x = t.Center.X + rng:NextNumber(-size / 2 + 2, size / 2 - 2)
			if math.abs(x - t.Center.X) > 8 then -- keep the stairs clear
				Props.Vine(dressing, Vector3.new(x, topY, t.Center.Z + size / 2 + 0.4), rng:NextNumber(4, 7), rng)
			end
			local side = if rng:NextNumber() < 0.5 then -1 else 1
			Props.Vine(dressing, Vector3.new(t.Center.X + side * (size / 2 + 0.4), topY, t.Center.Z + rng:NextNumber(-size / 2, size / 2)), rng:NextNumber(4, 7), rng)
		end
	end
	local stairFoot = t.Center + Vector3.new(0, 0, t.BaseSize / 2 + 34)
	for _, x in { -9, 9 } do
		Props.Brazier(dressing, stairFoot + Vector3.new(x, 1, 4))
		-- Between the shrine pillars (at +-6, +-6) and clear of the stair landing.
		Props.Brazier(dressing, Vector3.new(t.Center.X + x * 0.72, t.Center.Y + t.Tiers * t.TierHeight, t.Center.Z))
	end
	for _ = 1, 8 do
		local a = rng:NextNumber(0, math.pi * 2)
		local ground = groundAt(t.Center.X + math.cos(a) * rng:NextNumber(50, 75), t.Center.Z + math.sin(a) * rng:NextNumber(50, 75))
		part({
			Name = "FallenPillar",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(rng:NextNumber(4, 9), 3, 3),
			CFrame = CFrame.new(ground + Vector3.new(0, 1.3, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-10, 10))),
			Color = Color3.fromRGB(225, 215, 190),
			Material = Enum.Material.Marble,
			Parent = dressing,
		})
	end

	-- Waterfall: second translucent layer, foam, rocks around the pool
	local w = WorldLayout.Waterfall
	local topY = w.CliffCenter.Y + w.CliffSize.Y / 2
	local faceZ = w.CliffCenter.Z + w.CliffSize.Z / 2
	local veil = part({
		Name = "FallingWaterVeil",
		Size = Vector3.new(w.FallWidth + 6, topY - 6, 1),
		CFrame = CFrame.new(0, (topY + 6) / 2, faceZ + 3.2),
		Color = Color3.fromRGB(215, 245, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.7,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
		Parent = dressing,
	})
	local streaks = Instance.new("ParticleEmitter")
	streaks.Color = ColorSequence.new(Color3.new(1, 1, 1))
	streaks.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.9) })
	streaks.Size = NumberSequence.new(2.5)
	streaks.Lifetime = NumberRange.new(1.5, 2)
	streaks.Rate = 40
	streaks.Speed = NumberRange.new(40, 50)
	streaks.EmissionDirection = Enum.NormalId.Bottom
	streaks.SpreadAngle = Vector2.new(4, 4)
	local streakAttachment = Instance.new("Attachment")
	streakAttachment.Position = Vector3.new(0, veil.Size.Y / 2 - 2, 0)
	streakAttachment.Parent = veil
	streaks.Parent = streakAttachment
	local foam = Instance.new("ParticleEmitter")
	foam.Texture = "rbxasset://textures/particles/smoke_main.dds"
	foam.Color = ColorSequence.new(Color3.new(1, 1, 1))
	foam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	foam.Size = NumberSequence.new(5, 12)
	foam.Lifetime = NumberRange.new(1.2, 2)
	foam.Rate = 30
	foam.Speed = NumberRange.new(3, 7)
	foam.SpreadAngle = Vector2.new(80, 80)
	foam.EmissionDirection = Enum.NormalId.Top
	local foamAttachment = Instance.new("Attachment")
	foamAttachment.Position = Vector3.new(0, -veil.Size.Y / 2 + 1, 2)
	foamAttachment.Parent = veil
	foam.Parent = foamAttachment
	for i = 0, 9 do
		local a = math.rad(i * 36 + rng:NextNumber(-8, 8))
		local ground = groundAt(w.PoolCenter.X + math.cos(a) * (w.PoolRadius + 3), w.PoolCenter.Z + math.sin(a) * (w.PoolRadius + 3))
		if ground.Z > faceZ + 8 and not (math.abs(ground.X) < 14 and ground.Z < faceZ + 30) then
			Props.Rocks(dressing, ground, rng)
		end
	end

	-- Shipwreck beach: cargo spilled from the wreck
	local ship = WorldLayout.Shipwreck.Center
	for _ = 1, 10 do
		local ground = groundAt(ship.X + rng:NextNumber(18, 48), ship.Z + rng:NextNumber(-45, 45))
		if ground.Y > 1 then
			local cf = CFrame.new(ground) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			if rng:NextNumber() < 0.5 then
				Props.Barrel(dressing, cf)
			else
				Props.Crate(dressing, cf, rng:NextNumber(2.5, 3.5))
			end
		end
	end
	for _ = 1, 6 do
		local ground = groundAt(ship.X + rng:NextNumber(15, 50), ship.Z + rng:NextNumber(-50, 50))
		part({
			Name = "Driftwood",
			Size = Vector3.new(rng:NextNumber(4, 8), 0.5, 1.2),
			CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-8, 8))),
			Color = Color3.fromRGB(150, 120, 90),
			Material = Enum.Material.WoodPlanks,
			CanCollide = false,
			Parent = dressing,
		})
	end

	-- Expedition camp: logs around the fire, lanterns, a map table
	local camp = WorldLayout.ExtractionZones[1]
	local campGround = camp.ResolvedPosition or camp.Position
	local fire = campGround + Vector3.new(14, 0, 12)
	for i = 0, 2 do
		local a = math.rad(i * 120 + 30)
		part({
			Name = "LogSeat",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 1.4, 1.4),
			CFrame = CFrame.new(fire + Vector3.new(math.cos(a) * 4, 0.7, math.sin(a) * 4)) * CFrame.Angles(0, -a + math.rad(90), 0),
			Color = Color3.fromRGB(110, 75, 45),
			Material = Enum.Material.Wood,
			Parent = dressing,
		})
	end
	for _, offset in { Vector3.new(-20, 0, -16), Vector3.new(20, 0, -16), Vector3.new(-22, 0, 18) } do
		Props.Lamp(dressing, campGround + offset)
	end
	part({ Name = "MapTable", Size = Vector3.new(5, 0.4, 3), CFrame = CFrame.new(campGround + Vector3.new(-6, 3, -16)), Color = C.Wood, Material = Enum.Material.WoodPlanks, Parent = dressing })
	part({ Name = "Map", Size = Vector3.new(3.6, 0.05, 2.2), CFrame = CFrame.new(campGround + Vector3.new(-6, 3.23, -16)) * CFrame.Angles(0, 0.2, 0), Color = Color3.fromRGB(230, 205, 150), Material = Enum.Material.Fabric, CanCollide = false, Parent = dressing })
	for _, x in { -8, -4 } do
		part({ Name = "TableLeg", Size = Vector3.new(0.4, 2.8, 2.6), CFrame = CFrame.new(campGround + Vector3.new(x, 1.4, -16)), Color = C.DarkWood, Material = Enum.Material.Wood, Parent = dressing })
	end
end

-- PUBLIC ------------------------------------------------------------------------

function WorldBuilder.Build()
	world = folder("World", workspace)
	Props.DefaultParent = world
	buildLighting()
	buildTerrain()
	local district = buildDistrict()
	local machines = buildGym(district)
	local shopPrompt = buildShop(district)
	local altarPrompt = buildAscensionAltar(district)
	local plots = buildVaultPlots(district)
	local leaderboards = buildLeaderboards(district)
	buildWaterfall()
	buildTemple()
	buildShipwreck()
	buildLighthouse()
	buildWilds()
	buildExtractionZones()
	dressDistrict()
	dressLandmarks()

	-- Resolve treasure spawn heights against the finished world
	local spawns = {}
	for _, info in WorldLayout.TreasureSpawns do
		local ground = groundAt(info.Position.X, info.Position.Z, info.RayFrom or (if info.Position.Y > 20 then info.Position.Y + 20 else nil))
		table.insert(spawns, {
			Area = info.Area,
			Position = ground,
			MinRarity = info.MinRarity,
			MaxRarity = info.MaxRarity,
		})
	end
	local guardians = {}
	for _, info in WorldLayout.GuardianSpawns do
		table.insert(guardians, {
			Type = info.Type,
			Position = groundAt(info.Position.X, info.Position.Z, 40),
			PatrolRadius = info.PatrolRadius,
		})
	end

	return {
		TreasureSpawns = spawns,
		GuardianSpawns = guardians,
		Treadmills = machines,
		ShopPrompt = shopPrompt,
		AltarPrompt = altarPrompt,
		VaultPlots = plots,
		Leaderboards = leaderboards,
	}
end

return WorldBuilder
