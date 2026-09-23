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
	Lighting.ClockTime = 14.2
	Lighting.Brightness = 2.6
	Lighting.GlobalShadows = true
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 140, 150)
	Lighting.Ambient = Color3.fromRGB(70, 70, 80)
	Lighting.EnvironmentDiffuseScale = 1
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GeographicLatitude = 20

	local atmosphere = Instance.new("Atmosphere")
	atmosphere.Density = 0.28
	atmosphere.Offset = 0.1
	atmosphere.Color = Color3.fromRGB(200, 225, 240)
	atmosphere.Decay = Color3.fromRGB(110, 150, 190)
	atmosphere.Glare = 0.3
	atmosphere.Haze = 1.2
	atmosphere.Parent = Lighting

	local bloom = Instance.new("BloomEffect")
	bloom.Intensity = 0.5
	bloom.Size = 24
	bloom.Threshold = 1.6
	bloom.Parent = Lighting

	local color = Instance.new("ColorCorrectionEffect")
	color.Saturation = 0.18
	color.Contrast = 0.06
	color.Brightness = 0.02
	color.Parent = Lighting

	local rays = Instance.new("SunRaysEffect")
	rays.Intensity = 0.06
	rays.Spread = 0.6
	rays.Parent = Lighting

	local sky = Instance.new("Sky")
	sky.SunAngularSize = 14
	sky.Parent = Lighting
end

local function buildTerrain()
	terrain.WaterColor = Color3.fromRGB(20, 170, 190)
	terrain.WaterTransparency = 0.55
	terrain.WaterWaveSize = 0.18
	terrain.WaterWaveSpeed = 8
	terrain.WaterReflectance = 0.6
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 180, 74))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 220, 160))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(120, 112, 105))
	terrain:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(160, 120, 80))

	-- Ocean (sea floor + water, top at y = 0)
	terrain:FillBlock(CFrame.new(0, -32, 0), Vector3.new(1800, 16, 1800), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -12, 0), Vector3.new(1800, 24, 1800), Enum.Material.Water)

	-- Island: beach ring, sand shelf, grass plateau (top y = 10)
	terrain:FillCylinder(CFrame.new(0, -9, 0), 22, 540, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(0, -5, 0), 26, 505, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(0, -5, 0), 30, 480, Enum.Material.Grass)

	-- Rolling hills in the Wilds (break up sightlines, create routes)
	for _, hill in {
		{ -200, -8, -100, 40 },
		{ 175, -14, 45, 40 },
		{ -70, -18, -225, 34 },
		{ -250, -12, 150, 45 },
		{ 250, -10, 150, 42 },
		{ 120, -20, -120, 30 },
	} do
		terrain:FillBall(Vector3.new(hill[1], hill[2], hill[3]), hill[4], Enum.Material.Grass)
	end

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
			Vector3.new(p.X + width / 2, 14, p.Z + width / 2)
		):ExpandToGrid(4)
		terrain:ReplaceMaterial(region, 4, Enum.Material.Grass, Enum.Material.Ground)
	end
end

-- TREASURE DISTRICT -------------------------------------------------------------

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

	-- Spawn (ForceField duration = spawn protection)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "DistrictSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.CFrame = CFrame.lookAt(WorldLayout.Spawn, Vector3.new(0, WorldLayout.Spawn.Y, 0))
	spawn.Color = C.Gold
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.6
	spawn.Duration = GameConfig.Player.SpawnProtection
	spawn.Neutral = true
	spawn.CanCollide = true
	spawn.Parent = district
	local decal = spawn:FindFirstChildOfClass("Decal")
	if decal then
		decal:Destroy()
	end

	-- Perimeter lamps make the safe-zone edge readable
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local pos = center + Vector3.new(math.cos(angle), 0, math.sin(angle)) * (GameConfig.SafeZone.Radius + 2)
		if math.abs(pos.X) > 14 or pos.Z > center.Z then -- leave the north gate open
			cylinder(pos + Vector3.new(0, 5, 0), 10, 0.8, { Name = "Lamp", Color = C.DarkWood, Parent = district })
			local bulb = part({
				Name = "Bulb",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(1.8, 1.8, 1.8),
				CFrame = CFrame.new(pos + Vector3.new(0, 10.5, 0)),
				Color = Color3.fromRGB(255, 220, 140),
				Material = Enum.Material.Neon,
				Parent = district,
			})
			bulb.CanCollide = false
		end
	end

	-- North gate towards the Wilds
	local gate = d.Gate
	for _, x in { -12, 12 } do
		part({ Name = "GatePillar", Size = Vector3.new(4, 22, 4), CFrame = CFrame.new(gate + Vector3.new(x, 11, 0)), Color = C.Sandstone, Material = Enum.Material.Sandstone, Parent = district })
	end
	local beam = part({ Name = "GateBeam", Size = Vector3.new(30, 4, 5), CFrame = CFrame.new(gate + Vector3.new(0, 23, 0)), Color = C.Wood, Material = Enum.Material.Wood, Parent = district })
	billboardSign(beam, "THE WILDS", "Treasure awaits. Danger too.", C.Gold, 250, 5, 22)

	-- How to play board (teaches the loop without walls of text)
	local board = part({
		Name = "HowToPlay",
		Size = Vector3.new(22, 12, 1),
		CFrame = CFrame.lookAt(center + Vector3.new(-26, 8, 32), Vector3.new(0, 8, WorldLayout.Spawn.Z)),
		Color = C.DarkWood,
		Material = Enum.Material.Wood,
		Parent = district,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(660, 360)
	surface.LightInfluence = 0
	surface.Parent = board
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBlack
	text.TextColor3 = Color3.fromRGB(255, 230, 160)
	text.TextScaled = true
	text.RichText = true
	text.Text = "STEAL THE TREASURE\n<font color=\"#ffffff\">1 TRAIN  •  2 FIND\n3 CARRY  •  4 EXTRACT\nDON'T GET CAUGHT</font>"
	text.Parent = surface

	for _, pillarX in { -18, 18 } do
		part({ Name = "BoardLeg", Size = Vector3.new(1, 3, 1), CFrame = board.CFrame * CFrame.new(pillarX * 0.5, -7.5, 0), Color = C.DarkWood, Parent = district })
	end

	return district
end

local function buildTrainingStations(district: Folder)
	local stations = {}
	local grounds = folder("TrainingGrounds", district)
	local colors = {
		stone_lift = Color3.fromRGB(120, 200, 255),
		chain_pull = Color3.fromRGB(255, 170, 60),
		strength_challenge = Color3.fromRGB(255, 80, 110),
	}
	for _, info in WorldLayout.TrainingStations do
		local stationCfg = GameConfig.Training.Stations[info.Id]
		local base = info.Position + Vector3.new(0, 1, 0)
		local platform = cylinder(base + Vector3.new(0, 0.5, 0), 1, 16, {
			Name = "Platform",
			Color = C.Cream,
			Material = Enum.Material.Marble,
			Parent = grounds,
		})
		cylinder(base + Vector3.new(0, 0.55, 0), 1.05, 17, {
			Name = "Rim",
			Color = colors[info.Id],
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = grounds,
		})

		local prop: BasePart
		if info.Id == "stone_lift" then
			prop = part({ Name = "Stone", Shape = Enum.PartType.Ball, Size = Vector3.new(5, 4, 5), CFrame = CFrame.new(base + Vector3.new(0, 3, -3)), Color = C.DarkStone, Material = Enum.Material.Slate, Parent = grounds })
		elseif info.Id == "chain_pull" then
			cylinder(base + Vector3.new(0, 5, -4), 10, 1.5, { Name = "Post", Color = C.DarkWood, Material = Enum.Material.Wood, Parent = grounds })
			for i = 0, 5 do
				part({ Name = "Link", Size = Vector3.new(0.6, 0.6, 1.4), CFrame = CFrame.new(base + Vector3.new(0, 1.5, -2.5 + i * 1.2)), Color = Color3.fromRGB(150, 150, 160), Material = Enum.Material.DiamondPlate, Parent = grounds })
			end
			prop = part({ Name = "Anchor", Size = Vector3.new(4, 4, 2), CFrame = CFrame.new(base + Vector3.new(0, 3, 4.5)), Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Metal, Parent = grounds })
		else
			cylinder(base + Vector3.new(0, 9, -4), 18, 1.4, { Name = "Pole", Color = C.Red, Parent = grounds })
			prop = part({ Name = "Bell", Shape = Enum.PartType.Ball, Size = Vector3.new(3.5, 3.5, 3.5), CFrame = CFrame.new(base + Vector3.new(0, 18.5, -4)), Color = C.Gold, Material = Enum.Material.Metal, Parent = grounds })
			part({ Name = "Pad", Size = Vector3.new(4, 1, 4), CFrame = CFrame.new(base + Vector3.new(0, 1.5, -1)), Color = C.Red, Material = Enum.Material.Plastic, Parent = grounds })
		end
		prop:SetAttribute("TrainingProp", info.Id)
		billboardSign(prop, stationCfg.Name:upper(), ("Requires %d Strength"):format(stationCfg.RequiredStrength), colors[info.Id], 90, 5, 11)
		local p = prompt(platform, "Train", stationCfg.Name, 0)
		p.MaxActivationDistance = 10
		table.insert(stations, { Id = info.Id, Position = base, Prompt = p, Prop = prop })
	end
	return stations
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

local function buildVaultPlots(district: Folder)
	local d = WorldLayout.District
	local plots = {}
	local vaults = folder("Vaults", district)
	local count = GameConfig.MaxPlayers
	for i = 1, count do
		local t = if count == 1 then 0.5 else (i - 1) / (count - 1)
		local angle = math.rad(-d.VaultArcDegrees / 2 + t * d.VaultArcDegrees)
		local pos = d.Center + Vector3.new(math.sin(angle) * d.VaultArcRadius, 1, math.cos(angle) * d.VaultArcRadius)
		local cf = CFrame.lookAt(pos, Vector3.new(d.Center.X, pos.Y, d.Center.Z))
		local plotFolder = folder("Vault" .. i, vaults)
		part({ Name = "Floor", Size = Vector3.new(30, 0.4, 30), CFrame = cf * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(70, 60, 90), Material = Enum.Material.Marble, Parent = plotFolder })
		part({ Name = "BackWall", Size = Vector3.new(30, 8, 1), CFrame = cf * CFrame.new(0, 4, 15), Color = C.Cream, Material = Enum.Material.Marble, Parent = plotFolder })
		for _, x in { -15, 15 } do
			part({ Name = "SideWall", Size = Vector3.new(1, 5, 30), CFrame = cf * CFrame.new(x, 2.5, 0), Color = C.Cream, Material = Enum.Material.Marble, Parent = plotFolder })
		end
		part({ Name = "Trim", Size = Vector3.new(30.4, 0.6, 1.4), CFrame = cf * CFrame.new(0, 8.2, 15), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		local signPart = part({ Name = "SignPost", Size = Vector3.new(1, 1, 1), CFrame = cf * CFrame.new(0, 10, 15), Transparency = 1, CanCollide = false, Parent = plotFolder })
		local sign = billboardSign(signPart, "EMPTY VAULT", nil, C.Gold, 120, 2, 18)
		local terminal = part({ Name = "Terminal", Size = Vector3.new(2.5, 3.5, 2.5), CFrame = cf * CFrame.new(-12.5, 1.95, -13), Color = C.Gold, Material = Enum.Material.Metal, Parent = plotFolder })
		local displays = folder("Displays", plotFolder)
		table.insert(plots, {
			Index = i,
			CFrame = cf,
			Sign = sign:FindFirstChild("Title") :: TextLabel,
			Prompt = prompt(terminal, "Edit Vault", "Vault", 0),
			Displays = displays,
			Owner = nil,
		})
	end
	return plots
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

local function buildTree(parent: Folder, ground: Vector3, palm: boolean)
	local height = rng:NextNumber(12, 22)
	local lean = if palm then math.rad(rng:NextNumber(-12, 12)) else 0
	local trunkCf = CFrame.new(ground + Vector3.new(0, height / 2, 0)) * CFrame.Angles(lean, rng:NextNumber(0, 6.28), 0)
	part({
		Name = "Trunk",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(height, if palm then 1.6 else 2.4, if palm then 1.6 else 2.4),
		CFrame = trunkCf * CFrame.Angles(0, 0, math.rad(90)),
		Color = if palm then Color3.fromRGB(160, 120, 80) else C.Wood,
		Material = Enum.Material.Wood,
		Parent = parent,
	})
	local top = (trunkCf * CFrame.new(0, height / 2, 0)).Position
	if palm then
		for i = 0, 5 do
			local a = i / 6 * math.pi * 2
			part({
				Name = "Frond",
				Size = Vector3.new(1.2, 0.4, 9),
				CFrame = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.new(0, -1, -4) * CFrame.Angles(math.rad(-20), 0, 0),
				Color = C.Leaf,
				Material = Enum.Material.Grass,
				CanCollide = false,
				CanQuery = false,
				Parent = parent,
			})
		end
	else
		for i = 1, rng:NextInteger(2, 3) do
			local size = rng:NextNumber(9, 14)
			part({
				Name = "Canopy",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size, size * 0.85, size),
				CFrame = CFrame.new(top + Vector3.new(rng:NextNumber(-3, 3), rng:NextNumber(-1, 3) + i, rng:NextNumber(-3, 3))),
				Color = if i % 2 == 0 then C.LeafDark else C.Leaf,
				Material = Enum.Material.Grass,
				CanCollide = false,
				CanQuery = false,
				Parent = parent,
			})
		end
	end
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

	local placed = 0
	local attempts = 0
	while placed < 110 and attempts < 1200 do
		attempts += 1
		local r = math.sqrt(rng:NextNumber()) * 450
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not tooClose(x, z, avoid) and not (z < -300 and math.abs(x) < 190) then
			local ground = groundAt(x, z)
			if ground.Y > 7 then
				buildTree(wilds, ground, r > 380 or x < -250)
				placed += 1
				table.insert(avoid, { Vector2.new(x, z), 10 })
			end
		end
	end

	for _ = 1, 40 do
		local r = math.sqrt(rng:NextNumber()) * 440
		local a = rng:NextNumber(0, math.pi * 2)
		local x, z = math.cos(a) * r, math.sin(a) * r
		if not tooClose(x, z, avoid) then
			local ground = groundAt(x, z)
			local size = rng:NextNumber(4, 11)
			part({
				Name = "Boulder",
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(size * 1.3, size, size * 1.1),
				CFrame = CFrame.new(ground + Vector3.new(0, size * 0.25, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
				Color = Color3.fromRGB(135, 128, 118),
				Material = Enum.Material.Slate,
				Parent = wilds,
			})
		end
	end

	-- Dirt trails from the gate toward each landmark
	local gate = WorldLayout.District.Gate
	paintPath(gate, Vector3.new(0, 10, -270), 10)
	paintPath(gate + Vector3.new(0, 0, -45), WorldLayout.Temple.Courtyard + Vector3.new(0, 0, 15), 9)
	paintPath(gate + Vector3.new(0, 0, -45), WorldLayout.Shipwreck.Center + Vector3.new(60, 0, 0), 9)

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

-- PUBLIC ------------------------------------------------------------------------

function WorldBuilder.Build()
	world = folder("World", workspace)
	buildLighting()
	buildTerrain()
	local district = buildDistrict()
	local stations = buildTrainingStations(district)
	local shopPrompt = buildShop(district)
	local altarPrompt = buildAscensionAltar(district)
	local plots = buildVaultPlots(district)
	buildWaterfall()
	buildTemple()
	buildShipwreck()
	buildLighthouse()
	buildWilds()
	buildExtractionZones()

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
		TrainingStations = stations,
		ShopPrompt = shopPrompt,
		AltarPrompt = altarPrompt,
		VaultPlots = plots,
	}
end

return WorldBuilder
