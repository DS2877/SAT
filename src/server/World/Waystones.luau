-- Waystones (WorldLayout.Waystones): a rune dais in the District with one standing stone per
-- Deep South region, and a return stone at each region's arrival point. Every stone is tagged
-- "Waystone" with Area (where it takes you: a region, or "District") and Destination (where
-- you land); Services/WaystoneService decides who may travel. The rune band is tagged
-- "RuneGateGlow" so each client paints it green/red for its own Ascension, like the gates.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local WorldLayout = require(Shared.Config.WorldLayout)
local GameConfig = require(Shared.Config.GameConfig)
local Regions = require(Shared.Config.Regions)

local Props = require(script.Parent.Props)

local Waystones = {}

local part, cylinder = Props.part, Props.cylinder
local STONE = Color3.fromRGB(96, 92, 110)
local DARK_STONE = Color3.fromRGB(60, 56, 70)

-- One standing stone at `ground` facing `facing`; returns the stone.
local function stone(parent: Instance, ground: Vector3, facing: Vector3, color: Color3, area: string, destination: Vector3, title: string, subtitle: string, required: number)
	local cf = CFrame.lookAt(ground, Vector3.new(facing.X, ground.Y, facing.Z))
	part({ Name = "WaystoneBase", Size = Vector3.new(5, 1, 5), CFrame = cf * CFrame.new(0, 0.5, 0), Color = DARK_STONE, Material = Enum.Material.Slate, Parent = parent })
	local body = part({ Name = "Waystone", Size = Vector3.new(3, 9, 2), CFrame = cf * CFrame.new(0, 5.5, 0) * CFrame.Angles(0, 0, math.rad(2)), Color = STONE, Material = Enum.Material.Slate, Parent = parent })
	part({ Name = "WaystoneCap", Size = Vector3.new(2.2, 1.4, 1.6), CFrame = body.CFrame * CFrame.new(0, 5.1, 0) * CFrame.Angles(0, 0, math.rad(45)), Color = STONE, Material = Enum.Material.Slate, Parent = parent })
	-- Carved runes down the face, lit in the region's colour.
	for i = 0, 3 do
		local rune = part({ Name = "WaystoneRune", Size = Vector3.new(1, 0.9, 0.2), CFrame = body.CFrame * CFrame.new(0, 2.8 - i * 1.7, -1.05), Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = parent })
		if required > 0 then
			CollectionService:AddTag(rune, "RuneGateGlow")
			rune:SetAttribute("RequiredAscension", required)
		end
	end
	-- A shard hovering over the stone, spinning.
	local shard = part({ Name = "WaystoneShard", Size = Vector3.new(1.4, 2.4, 1.4), CFrame = body.CFrame * CFrame.new(0, 7.8, 0) * CFrame.Angles(0, math.rad(45), 0), Color = color, Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = parent })
	shard:SetAttribute("Spin", 1.2)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 14
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = shard
	local sparkle = Instance.new("ParticleEmitter")
	sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkle.Color = ColorSequence.new(color)
	sparkle.LightEmission = 1
	sparkle.LightInfluence = 0
	sparkle.Size = NumberSequence.new(0.35, 0)
	sparkle.Lifetime = NumberRange.new(1, 1.8)
	sparkle.Rate = 5
	sparkle.Speed = NumberRange.new(0.5, 1.5)
	sparkle.SpreadAngle = Vector2.new(180, 180)
	sparkle.Parent = shard
	-- Label over the stone.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(9, 2.2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 12.5, 0)
	gui.MaxDistance = 60
	gui.LightInfluence = 0
	for i, line in { { title, color, 0, 0.6 }, { subtitle, Color3.fromRGB(235, 235, 240), 0.6, 0.4 } } do
		local label = Instance.new("TextLabel")
		label.Name = if i == 1 then "Title" else "Subtitle"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, line[3])
		label.Size = UDim2.fromScale(1, line[4])
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line[2]
		label.TextStrokeTransparency = 0.15
		label.Text = line[1]
		label.Parent = gui
	end
	gui.Parent = body

	body:SetAttribute("Area", area)
	body:SetAttribute("Destination", destination)
	body:SetAttribute("Title", title)
	CollectionService:AddTag(body, "Waystone")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "WaystonePrompt"
	prompt.ActionText = "Travel"
	prompt.ObjectText = title
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = body
	return body
end

-- `groundAt(x, z, from)` finds the ground (WorldBuilder's raycast).
function Waystones.Build(parent: Instance, groundAt)
	local info = WorldLayout.Waystones
	local f = Instance.new("Folder")
	f.Name = "Waystones"
	f.Parent = parent

	-- THE DAIS in the District.
	local centre = info.Circle
	cylinder(centre + Vector3.new(0, 0.3, 0), 0.6, (info.Radius + 3) * 2, { Name = "WaystoneDais", Color = Color3.fromRGB(80, 76, 96), Material = Enum.Material.Slate, Parent = f })
	cylinder(centre + Vector3.new(0, 0.35, 0), 0.62, (info.Radius + 3) * 2 - 1.5, { Name = "WaystoneDaisInlay", Color = Color3.fromRGB(110, 104, 130), Material = Enum.Material.Pavement, Parent = f })
	local core = part({ Name = "WaystoneHeart", Size = Vector3.new(2, 3, 2), CFrame = CFrame.new(centre + Vector3.new(0, 4, 0)) * CFrame.Angles(0, 0, math.rad(45)), Color = Color3.fromRGB(220, 200, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = f })
	core:SetAttribute("Spin", 0.8)
	local sign = part({ Name = "SignAnchor", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(centre + Vector3.new(0, 9, 0)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = f })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(18, 4)
	gui.MaxDistance = 90
	gui.LightInfluence = 0
	for i, line in { { "✨ WAYSTONES", Color3.fromRGB(220, 190, 255), 0, 0.6 }, { "Fast travel to the Deep South • reach a region on foot once to attune it", Color3.fromRGB(235, 235, 240), 0.6, 0.4 } } do
		local label = Instance.new("TextLabel")
		label.Name = if i == 1 then "Title" else "Subtitle"
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, line[3])
		label.Size = UDim2.fromScale(1, line[4])
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = line[2]
		label.TextStrokeTransparency = 0.15
		label.Text = line[1]
		label.Parent = gui
	end
	gui.Parent = sign

	local count = #info.Regions
	local home = centre + Vector3.new(-info.Radius - 4, 0, 0) -- on the avenue side of the dais
	for i, region in info.Regions do
		local balance = GameConfig.Regions[region.Area]
		local regionInfo = Regions.Info[region.Area]
		local color = Color3.fromRGB(regionInfo.Color[1], regionInfo.Color[2], regionInfo.Color[3])
		-- District stone: spread on the arc facing the avenue.
		local a = math.rad(180 + (i - (count + 1) / 2) * 38)
		local at = centre + Vector3.new(math.cos(a) * info.Radius, 0, math.sin(a) * info.Radius)
		local arrival = groundAt(region.Stone.X, region.Stone.Z, region.Stone.Y + 60)
		-- Step off the stone toward home - on the ground THERE (the slope can rise in 5 studs).
		local landing = groundAt(region.Stone.X, region.Stone.Z + 5, region.Stone.Y + 60)
		stone(f, at + Vector3.new(0, 0.6, 0), at + (at - centre), color, region.Area, landing, regionInfo.Title, ("%s • ASCENSION %d"):format(region.Name, balance.RequiredAscension), balance.RequiredAscension)
		-- Return stone at the arrival point, facing north (home).
		stone(f, arrival, arrival + Vector3.new(0, 0, 10), Color3.fromRGB(220, 200, 255), "District", home, "WAYSTONE", "Back to the District • hands empty", 0)
	end
	return f
end

return Waystones
