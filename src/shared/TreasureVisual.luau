-- Procedural treasure models (placeholder art until real meshes exist).
-- Build(def) returns a Model whose PrimaryPart "Handle" is the pickup/weld root.
-- All parts are welded to Handle; anchoring Handle anchors the whole treasure.

local Rarities = require(script.Parent.Config.Rarities)
local Treasures = require(script.Parent.Config.Treasures)

local TreasureVisual = {}

local function color(def)
	local c = def.Color
	return Color3.fromRGB(c[1], c[2], c[3])
end

local function material(def): Enum.Material
	local ok, value = pcall(function()
		return (Enum.Material :: any)[def.Material]
	end)
	return ok and value or Enum.Material.SmoothPlastic
end

local function part(model: Model, handle: BasePart?, props)
	local p: BasePart
	if props.Shape == "Wedge" then
		p = Instance.new("WedgePart")
	else
		p = Instance.new("Part")
		if props.Shape then
			(p :: Part).Shape = props.Shape
		end
	end
	p.Size = props.Size
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.CFrame = props.CFrame
	p.Transparency = props.Transparency or 0
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Parent = model
	if handle then
		p.Anchored = false
		p.Massless = true
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
	end
	return p
end

-- Each shape builder receives (model, handle, scale s, main color, accent color, material)
local Shapes = {}

function Shapes.Pouch(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1, 1.2) * s, Color = c, Material = mat, CFrame = h.CFrame })
	part(m, h, { Size = Vector3.new(0.5, 0.35, 0.5) * s, Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.new(0, 0.55 * s, 0) })
end

function Shapes.Disc(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25 * s, 1.6 * s, 1.6 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.Angles(0, math.rad(90), 0) })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, 0.7 * s, 0.7 * s), Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.Angles(0, math.rad(90), 0) })
end

function Shapes.Pot(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.4, 1.3, 1.4) * s, Color = c, Material = mat, CFrame = h.CFrame })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5 * s, 0.7 * s, 0.7 * s), Color = a, Material = mat, CFrame = h.CFrame * CFrame.new(0, 0.7 * s, 0) * CFrame.Angles(0, 0, math.rad(90)) })
end

function Shapes.Goblet(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15 * s, 0.9 * s, 0.9 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, -0.6 * s, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7 * s, 0.2 * s, 0.2 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, -0.2 * s, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7 * s, 1.0 * s, 1.0 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, 0.4 * s, 0) * CFrame.Angles(0, 0, math.rad(90)) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(0, 0.3 * s, -0.5 * s) })
end

function Shapes.Lantern(m, h, s, c, a, mat)
	part(m, h, { Size = Vector3.new(0.9, 1.2, 0.9) * s, Color = c, Material = mat, Transparency = 0.2, CFrame = h.CFrame })
	part(m, h, { Size = Vector3.new(1.05, 0.15, 1.05) * s, Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.new(0, 0.65 * s, 0) })
	part(m, h, { Size = Vector3.new(1.05, 0.15, 1.05) * s, Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.new(0, -0.65 * s, 0) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4) * s, Color = c, Material = Enum.Material.Neon, CFrame = h.CFrame })
end

function Shapes.Idol(m, h, s, c, a, mat)
	part(m, h, { Size = Vector3.new(0.8, 1.1, 0.6) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, -0.2 * s, 0) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, 0.6 * s, 0) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(-0.18 * s, 0.68 * s, -0.36 * s) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(0.18 * s, 0.68 * s, -0.36 * s) })
end

function Shapes.Horn(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.4 * s, 0.35 * s, 0.35 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(25)) })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3 * s, 0.6 * s, 0.6 * s), Color = a, Material = mat, CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(25)) * CFrame.new(0.75 * s, 0, 0) })
end

function Shapes.Tablet(m, h, s, c, a, mat)
	part(m, h, { Size = Vector3.new(1.3, 1.6, 0.3) * s, Color = c, Material = mat, CFrame = h.CFrame })
	part(m, h, { Size = Vector3.new(0.8, 0.12, 0.32) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(0, 0.3 * s, 0) })
	part(m, h, { Size = Vector3.new(0.6, 0.12, 0.32) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(0, -0.1 * s, 0) })
end

function Shapes.Gem(m, h, s, c, _a, _mat)
	part(m, h, { Size = Vector3.new(0.9, 0.9, 0.9) * s, Color = c, Material = Enum.Material.Glass, Transparency = 0.15, CFrame = h.CFrame * CFrame.Angles(math.rad(45), 0, math.rad(45)) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45) * s, Color = c, Material = Enum.Material.Neon, CFrame = h.CFrame })
end

function Shapes.Ring(m, h, s, c, a, _mat)
	for i = 0, 7 do
		local angle = i / 8 * math.pi * 2
		part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35) * s, Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.new(math.cos(angle) * 0.55 * s, math.sin(angle) * 0.55 * s, 0) })
	end
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55) * s, Color = c, Material = Enum.Material.Glass, CFrame = h.CFrame * CFrame.new(0, 0.75 * s, 0) })
end

function Shapes.Chest(m, h, s, c, a, mat)
	part(m, h, { Size = Vector3.new(1.6, 0.9, 1.0) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, -0.1 * s, 0) })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.6 * s, 1.0 * s, 1.0 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, 0.35 * s, 0) })
	part(m, h, { Size = Vector3.new(1.65, 0.15, 1.05) * s, Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.new(0, 0.3 * s, 0) })
	part(m, h, { Size = Vector3.new(0.25, 0.3, 0.1) * s, Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.new(0, 0.2 * s, -0.53 * s) })
	part(m, h, { Size = Vector3.new(1.3, 0.2, 0.7) * s, Color = Color3.fromRGB(255, 210, 60), Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(0, 0.62 * s, 0) })
end

function Shapes.Trident(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4 * s, 0.18 * s, 0.18 * s), Color = a, Material = Enum.Material.Metal, CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(90)) })
	for _, x in { -0.35, 0, 0.35 } do
		part(m, h, { Size = Vector3.new(0.12, 0.7, 0.12) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(x * s, 1.4 * s, 0) })
	end
	part(m, h, { Size = Vector3.new(0.85, 0.12, 0.12) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0, 1.05 * s, 0) })
end

function Shapes.Feather(m, h, s, c, a, _mat)
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 2.0, 0.15) * s, Color = c, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(20)) })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.1 * s, 0.08 * s, 0.08 * s), Color = a, Material = Enum.Material.SmoothPlastic, CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(110)) })
end

function Shapes.Crown(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6 * s, 1.4 * s, 1.4 * s), Color = c, Material = mat, CFrame = h.CFrame * CFrame.Angles(0, 0, math.rad(90)) })
	for i = 0, 4 do
		local angle = i / 5 * math.pi * 2
		part(m, h, { Size = Vector3.new(0.22, 0.55, 0.22) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(math.cos(angle) * 0.6 * s, 0.5 * s, math.sin(angle) * 0.6 * s) })
		part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.22, 0.22, 0.22) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(math.cos(angle) * 0.6 * s, 0.82 * s, math.sin(angle) * 0.6 * s) })
	end
end

function Shapes.Egg(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.6, 1.2) * s, Color = c, Material = mat, CFrame = h.CFrame })
	for i = 0, 3 do
		local angle = i / 4 * math.pi * 2
		part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.25, 0.4, 0.25) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(math.cos(angle) * 0.52 * s, 0.1 * s, math.sin(angle) * 0.52 * s) })
	end
end

function Shapes.Skull(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.2, 1.1, 1.2) * s, Color = Color3.fromRGB(230, 225, 205), Material = Enum.Material.Marble, CFrame = h.CFrame })
	part(m, h, { Size = Vector3.new(0.8, 0.45, 0.8) * s, Color = Color3.fromRGB(230, 225, 205), Material = Enum.Material.Marble, CFrame = h.CFrame * CFrame.new(0, -0.5 * s, -0.1 * s) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(-0.25 * s, 0.05 * s, -0.5 * s) })
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.3, 0.3, 0.3) * s, Color = c, Material = mat, CFrame = h.CFrame * CFrame.new(0.25 * s, 0.05 * s, -0.5 * s) })
	part(m, h, { Size = Vector3.new(0.12, 0.12, 0.12) * s, Color = a, Material = Enum.Material.Neon, CFrame = h.CFrame * CFrame.new(0, -0.2 * s, -0.58 * s) })
end

function Shapes.Orb(m, h, s, c, a, mat)
	part(m, h, { Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3) * s, Color = c, Material = mat, Transparency = 0.05, CFrame = h.CFrame })
	part(m, h, { Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12 * s, 1.7 * s, 1.7 * s), Color = a, Material = Enum.Material.Neon, Transparency = 0.3, CFrame = h.CFrame * CFrame.Angles(0, math.rad(90), math.rad(30)) })
end

local function accentFor(def)
	local info = Rarities.Info[def.Rarity]
	return info and info.Color or Color3.new(1, 1, 1)
end

function TreasureVisual.Scale(def): number
	return Treasures.DisplayScale[def.DisplaySize] or 1.5
end

-- Returns Model with PrimaryPart "Handle" (invisible root). Handle is left Anchored = true.
function TreasureVisual.Build(def, cframe: CFrame?): Model
	local model = Instance.new("Model")
	model.Name = def.Name
	local s = TreasureVisual.Scale(def)
	local root = cframe or CFrame.new()

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.6, 1.6, 1.6) * s
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanTouch = false
	handle.Anchored = true
	handle.CFrame = root
	handle.Parent = model
	model.PrimaryPart = handle

	local builder = Shapes[def.Shape] or Shapes.Gem
	builder(model, handle, s, color(def), accentFor(def), material(def))

	local info = Rarities.Info[def.Rarity]
	if info and info.Glow then
		local light = Instance.new("PointLight")
		light.Color = info.Color
		light.Range = 8 + info.Rank * 2
		light.Brightness = 1.2 + info.Rank * 0.25
		light.Shadows = false
		light.Parent = handle
	end
	return model
end

return TreasureVisual
