-- Shared building blocks for the Deep South (Emberfall, Rimeheart, Starfall Isles).

local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Parent.Props)

local Common = {}

Common.part, Common.cylinder = Props.part, Props.cylinder
local part = Props.part

function Common.folder(name: string, parent: Instance): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

function Common.light(parent: BasePart, color: Color3, range: number, brightness: number, nightOnly: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	if nightOnly then
		CollectionService:AddTag(parent, "NightLamp")
	end
	return l
end

function Common.emitter(parent: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = parent
	return e
end

Common.SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
Common.SMOKE = "rbxasset://textures/particles/smoke_main.dds"
Common.FIRE = "rbxasset://textures/particles/fire_main.dds"

-- Floating text sign on a small invisible anchor.
function Common.sign(parent: Instance, position: Vector3, title: string, subtitle: string?, color: Color3, width: number?)
	local anchor = part({ Name = "SignAnchor", Size = Vector3.new(0.4, 0.4, 0.4), CFrame = CFrame.new(position), Transparency = 1, CanCollide = false, CanQuery = false, Parent = parent })
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(math.min(width or 13, 14), if subtitle then 3 else 1.8)
	gui.MaxDistance = 110
	gui.LightInfluence = 0
	local function line(text: string, y: number, h: number, c: Color3)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0, y)
		label.Size = UDim2.fromScale(1, h)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = c
		label.TextStrokeTransparency = 0.15
		label.Text = text
		label.Parent = gui
		return label
	end
	line(title, 0, if subtitle then 0.6 else 1, color)
	if subtitle then
		line(subtitle, 0.6, 0.4, Color3.fromRGB(235, 235, 240))
	end
	gui.Parent = anchor
	return anchor
end

-- RUNE GATE: the Ascension lock at a region border. Two carved pillars and a lintel with a
-- glowing rune band; the client paints the runes green/red for YOU (tag "RuneGate").
function Common.runeGate(parent: Instance, ground: Vector3, facing: Vector3, requiredAscension: number, title: string, stone: Color3)
	local gate = Common.folder("RuneGate_" .. title, parent)
	local cf = CFrame.lookAt(ground, ground + Vector3.new(facing.X, 0, facing.Z))
	local width = 22
	for _, side in { -1, 1 } do
		part({ Name = "GatePillar", Size = Vector3.new(4, 22, 4), CFrame = cf * CFrame.new(side * width / 2, 11, 0), Color = stone, Material = Enum.Material.Slate, Parent = gate })
		part({ Name = "GateCap", Size = Vector3.new(5.5, 2, 5.5), CFrame = cf * CFrame.new(side * width / 2, 22.5, 0), Color = stone:Lerp(Color3.new(0, 0, 0), 0.3), Material = Enum.Material.Slate, Parent = gate })
		for i = 0, 3 do
			local rune = part({ Name = "GateRune", Size = Vector3.new(1.2, 1.6, 0.3), CFrame = cf * CFrame.new(side * width / 2, 5 + i * 4, -2.1), Color = Color3.fromRGB(255, 80, 70), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = gate })
			CollectionService:AddTag(rune, "RuneGateGlow")
			rune:SetAttribute("RequiredAscension", requiredAscension)
		end
	end
	part({ Name = "GateLintel", Size = Vector3.new(width + 6, 3, 5), CFrame = cf * CFrame.new(0, 24.5, 0), Color = stone, Material = Enum.Material.Slate, Parent = gate })
	local band = part({ Name = "GateBand", Size = Vector3.new(width - 2, 1, 0.3), CFrame = cf * CFrame.new(0, 24.5, -2.6), Color = Color3.fromRGB(255, 80, 70), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = gate })
	band:SetAttribute("RequiredAscension", requiredAscension)
	band:SetAttribute("Title", title)
	CollectionService:AddTag(band, "RuneGateGlow")
	CollectionService:AddTag(band, "RuneGate")
	Common.light(band, Color3.fromRGB(255, 120, 90), 24, 1.2)
	-- Rune dust drifting through the arch.
	Common.emitter(band, {
		Texture = Common.SPARKLE,
		Color = ColorSequence.new(Color3.fromRGB(255, 220, 160)),
		LightEmission = 1,
		Size = NumberSequence.new(0.6, 0),
		Lifetime = NumberRange.new(1.5, 2.5),
		Rate = 8,
		Speed = NumberRange.new(1, 3),
		SpreadAngle = Vector2.new(60, 60),
		EmissionDirection = Enum.NormalId.Bottom,
	})
	return gate
end

-- A tile of lava river: glowing surface (tag "Lava", HazardService) over a cracked bed.
function Common.lava(parent: Instance, cf: CFrame, size: Vector3, withLight: boolean)
	local tile = part({ Name = "Lava", Size = size, CFrame = cf, Color = Color3.fromRGB(255, 110, 25), Material = Enum.Material.Neon, CanCollide = true, Parent = parent })
	CollectionService:AddTag(tile, "Lava")
	if withLight then
		Common.light(tile, Color3.fromRGB(255, 120, 40), 26, 1.8)
		Common.emitter(tile, {
			Texture = Common.SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(255, 200, 80), Color3.fromRGB(255, 70, 20)),
			LightEmission = 1,
			Size = NumberSequence.new(0.5, 0),
			Lifetime = NumberRange.new(1, 2),
			Rate = 6,
			Speed = NumberRange.new(2, 5),
			SpreadAngle = Vector2.new(30, 30),
			EmissionDirection = Enum.NormalId.Top,
			Acceleration = Vector3.new(0, 2, 0),
		})
	end
	return tile
end

-- A large invisible sheet high above a region that sheds weather (ash, snow, stardust).
function Common.weather(parent: Instance, centre: Vector3, size: Vector2, props)
	local sheet = part({ Name = "Weather", Size = Vector3.new(size.X, 1, size.Y), CFrame = CFrame.new(centre), Transparency = 1, CanCollide = false, CanQuery = false, CastShadow = false, Parent = parent })
	props.Shape = Enum.ParticleEmitterShape.Box
	props.EmissionDirection = props.EmissionDirection or Enum.NormalId.Bottom
	Common.emitter(sheet, props)
	return sheet
end

-- Scatter `count` props over random open spots of an area (predicate `ok(x, z)` decides).
function Common.scatter(rng: Random, count: number, tries: number, bounds, ok: (number, number) -> boolean, place: (number, number) -> ())
	local placed = 0
	for _ = 1, tries do
		if placed >= count then
			break
		end
		local x = rng:NextNumber(bounds.MinX, bounds.MaxX)
		local z = rng:NextNumber(bounds.MinZ, bounds.MaxZ)
		if ok(x, z) then
			place(x, z)
			placed += 1
		end
	end
end

function Common.tooClose(avoid, x: number, z: number, extra: number?): boolean
	for _, a in avoid do
		if (Vector2.new(x, z) - a[1]).Magnitude < a[2] + (extra or 0) then
			return true
		end
	end
	return false
end

-- Distance from (x, z) to a polyline of Vector2 points.
function Common.distanceToPath(path: { Vector2 }, x: number, z: number): number
	local p = Vector2.new(x, z)
	local best = math.huge
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / ab:Dot(ab), 0, 1)
		best = math.min(best, (a + ab * t - p).Magnitude)
	end
	return best
end

-- Glowing light-bridge between two points (Starfall), or a plank bridge (Rimeheart).
function Common.bridge(parent: Instance, from: Vector3, to: Vector3, width: number, style: string)
	local delta = to - from
	local length = delta.Magnitude
	local cf = CFrame.lookAt(from + delta / 2, to)
	if style == "Light" then
		local deck = part({ Name = "LightBridge", Size = Vector3.new(width, 0.6, length), CFrame = cf, Color = Color3.fromRGB(150, 220, 255), Material = Enum.Material.Neon, Transparency = 0.35, Parent = parent })
		deck.CastShadow = false
		for _, side in { -1, 1 } do
			part({ Name = "LightRail", Size = Vector3.new(0.25, 0.25, length), CFrame = cf * CFrame.new(side * (width / 2 - 0.2), 1.6, 0), Color = Color3.fromRGB(210, 170, 255), Material = Enum.Material.Neon, CanCollide = false, CanQuery = false, Parent = parent })
		end
		Common.emitter(deck, {
			Texture = Common.SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(200, 230, 255), Color3.fromRGB(220, 160, 255)),
			LightEmission = 1,
			Size = NumberSequence.new(0.4, 0),
			Lifetime = NumberRange.new(1, 2),
			Rate = math.min(20, length / 4),
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(180, 180),
		})
		return deck
	end
	-- Planks on two ropes, a slight sag.
	local planks = math.floor(length / 1.6)
	for i = 0, planks do
		local t = i / planks
		local p = from + delta * t - Vector3.new(0, math.sin(t * math.pi) * 1.2, 0)
		part({ Name = "BridgePlank", Size = Vector3.new(width, 0.4, 1.3), CFrame = CFrame.lookAt(p, p + Vector3.new(delta.X, 0, delta.Z)), Color = Color3.fromRGB(120, 86, 56), Material = Enum.Material.WoodPlanks, Parent = parent })
	end
	for _, side in { -1, 1 } do
		part({ Name = "BridgeRope", Size = Vector3.new(0.2, 0.2, length), CFrame = cf * CFrame.new(side * width / 2, 2, 0), Color = Color3.fromRGB(170, 140, 100), Material = Enum.Material.Fabric, CanCollide = false, CanQuery = false, Parent = parent })
	end
	return nil
end

-- Upright neon crystal cluster.
function Common.crystals(parent: Instance, ground: Vector3, rng: Random, colors: { Color3 }, scale: number?)
	local s = scale or 1
	for i = 1, rng:NextInteger(3, 6) do
		local h = (if i == 1 then rng:NextNumber(5, 9) else rng:NextNumber(2, 5)) * s
		local w = h * 0.28
		local tilt = CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-25, 25)))
		local color = colors[rng:NextInteger(1, #colors)]
		local base = CFrame.new(ground + Vector3.new(rng:NextNumber(-1.5, 1.5) * s, 0, rng:NextNumber(-1.5, 1.5) * s)) * tilt
		part({ Name = "Crystal", Size = Vector3.new(w, h, w), CFrame = base * CFrame.new(0, h / 2, 0), Color = color, Material = Enum.Material.Neon, Transparency = 0.1, CanCollide = false, CanQuery = false, Parent = parent })
	end
end

return Common
