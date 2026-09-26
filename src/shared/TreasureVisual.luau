-- Treasure look. Build(def) returns a Model whose PrimaryPart "Handle" is the pickup/weld root.
-- All parts are welded to Handle; anchoring Handle anchors the whole treasure.
--
-- You read a treasure from its LOOK:
--   * BODY: a hand-built, exaggerated model of the thing itself (Shared/TreasureModels); the
--     generic Shape builders below are only a fallback.
--   * RARITY: much bigger the rarer it is, Rare+ glow, every tier above Common has its aura,
--     and the top tiers get FLAIR on top: Epic orbiting gems, Legendary a golden halo,
--     Mythic dark shards and flames, Divine wings, Secret black/white orbit rings, OG a crown
--     and a ring of coins. (Clients spin and bob world treasure, so orbits really orbit.)
--   * MUTATION: re-skins the body (Silver/Gold metal, Diamond glass, Moonlit neon, Rainbow
--     cycling) and adds glow, a coloured light, sparks, glints and an outline.

local CollectionService = game:GetService("CollectionService")

local Rarities = require(script.Parent.Config.Rarities)
local Treasures = require(script.Parent.Config.Treasures)
local Mutations = require(script.Parent.Config.Mutations)
local TreasureModels = require(script.Parent.TreasureModels)

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

-- Aura per rarity: { particle colour alpha, rate, size, speed }. Common has none.
local AURA = {
	Uncommon = { Rate = 4, Size = 0.35, Speed = 1 },
	Rare = { Rate = 8, Size = 0.45, Speed = 1.5 },
	Epic = { Rate = 14, Size = 0.55, Speed = 2 },
	Legendary = { Rate = 22, Size = 0.7, Speed = 2.5 },
	Mythic = { Rate = 30, Size = 0.8, Speed = 3 },
	Divine = { Rate = 36, Size = 0.85, Speed = 3 },
	Secret = { Rate = 40, Size = 0.9, Speed = 3 },
	OG = { Rate = 48, Size = 1, Speed = 3.5 },
}

-- Bigger for rarer treasure so a Legendary looks like a prize from far away: +12% per tier
-- (an OG is about twice the size of a Common of the same kind).
TreasureVisual.RARITY_GROWTH = 0.12

function TreasureVisual.Scale(def): number
	local base = Treasures.DisplayScale[def.DisplaySize] or 1.5
	return base * (1 + TreasureVisual.RARITY_GROWTH * (Rarities.Rank(def.Rarity) - 1))
end

function TreasureVisual.RarityAura(handle: BasePart, def): ParticleEmitter?
	local aura = AURA[def.Rarity]
	local info = Rarities.Info[def.Rarity]
	if not aura or not info then
		return nil
	end
	local s = handle.Size.X
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "RarityAura"
	emitter.Color = if info.Aura then ColorSequence.new(info.Aura[1], info.Aura[2]) else ColorSequence.new(info.Color)
	emitter.LightEmission = 0.8
	emitter.LightInfluence = 0
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, aura.Size * s * 0.4), NumberSequenceKeypoint.new(1, 0) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(0.8, 1.6)
	emitter.Rate = aura.Rate
	emitter.Speed = NumberRange.new(aura.Speed * 0.5, aura.Speed)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Shape = Enum.ParticleEmitterShape.Sphere
	emitter.Parent = handle
	return emitter
end

-- RARITY FLAIR ------------------------------------------------------------------------------

local GOLD = Color3.fromRGB(255, 205, 60)

local function flair(k: TreasureModels.Kit, handle: BasePart, def, display: boolean)
	local rank = Rarities.Rank(def.Rarity)
	local info = Rarities.Info[def.Rarity]
	local neon = Enum.Material.Neon
	-- Epic, Legendary: little gems orbiting the treasure.
	if rank == 4 or rank == 5 then
		for i = 1, 3 do
			local a = i / 3 * 2 * math.pi
			k.box(0.2, 0.2, 0.2, k.at(math.cos(a) * 1.3, 0.25 + (i % 2) * 0.3, math.sin(a) * 1.3, 45, 0, 45), info.Color, Enum.Material.Glass)
		end
	end
	-- Showcase copies (vault pedestals, trophies) don't glow: a vault full of neon halos and
	-- rings turns into glare. Same shapes, just no light.
	local glow = if display then Enum.Material.Glass else neon
	-- Legendary and up: a golden halo.
	if rank >= 5 and rank ~= 8 then
		k.torus(0.5, 0.07, 14, k.at(0, 1.55, 0, 90, 0, 0), if rank == 7 then Color3.new(1, 1, 1) else GOLD, glow)
	end
	-- Mythic: dark shards circling, and flames.
	if rank == 6 then
		for i = 1, 5 do
			local a = i / 5 * 2 * math.pi
			k.wedge(0.16, 0.45, 0.16, k.at(math.cos(a) * 1.35, 0.1 + (i % 2) * 0.35, math.sin(a) * 1.35, 0, 0, (i % 2) * 180), Color3.fromRGB(40, 0, 10), glow)
		end
		if not display then
			local fire = Instance.new("Fire")
			fire.Color = info.Color
			fire.SecondaryColor = Color3.fromRGB(40, 0, 0)
			fire.Size = handle.Size.X * 0.35
			fire.Heat = 6
			fire.Parent = handle
		end
	end
	-- Divine: glowing wings.
	if rank == 7 then
		for _, x in { -1, 1 } do
			for j = 0, 2 do
				k.ball(0.9 - j * 0.2, 0.3, 0.06, k.at(x * (0.75 + j * 0.3), 0.55 + j * 0.2, 0.35, 0, 0, x * (-25 - j * 12)), Color3.new(1, 1, 1), glow, { T = 0.25 + j * 0.15 })
			end
		end
	end
	-- Secret: black and white orbit rings.
	if rank == 8 then
		k.torus(1.4, 0.07, 18, k.at(0, 0.2, 0, 75, 0, 25), Color3.fromRGB(17, 17, 17), Enum.Material.SmoothPlastic)
		k.torus(1.5, 0.07, 18, k.at(0, 0.2, 0, 75, 0, -35), Color3.new(1, 1, 1), glow)
	end
	-- OG: a floating crown and a ring of gold coins.
	if rank >= 9 then
		k.vcyl(0.22, 0.75, k.at(0, 1.6, 0), GOLD, Enum.Material.Metal, { R = 0.3 })
		for i = 1, 5 do
			local a = i / 5 * 2 * math.pi
			k.wedge(0.14, 0.3, 0.08, k.at(math.cos(a) * 0.33, 1.83, math.sin(a) * 0.33, 0, -math.deg(a) - 90, 0), GOLD, Enum.Material.Metal)
		end
		for i = 1, 6 do
			local a = i / 6 * 2 * math.pi
			k.coin(0.34, k.at(math.cos(a) * 1.35, 0.2 + math.sin(a * 2) * 0.15, math.sin(a) * 1.35, 90, -math.deg(a), 0))
		end
	end
end

-- MUTATIONS ---------------------------------------------------------------------------------

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"

local function emitter(handle: BasePart, name: string, props)
	local e = Instance.new("ParticleEmitter")
	e.Name = name
	e.Texture = SPARKLE
	e.LightEmission = 1
	e.LightInfluence = 0
	e.SpreadAngle = Vector2.new(180, 180)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = handle
	return e
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 70, 70)),
	ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 200, 40)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 255, 90)),
	ColorSequenceKeypoint.new(0.75, Color3.fromRGB(60, 180, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 90, 255)),
})

local function applyMutation(model: Model, handle: BasePart, mutation: string?, display: boolean)
	local info = Mutations.Get(mutation)
	if not info then
		return
	end
	local color = Mutations.Color(info.Color)
	local sparkColor = Mutations.Color(info.Sparkle)
	local material = (Enum.Material :: any)[info.Material] or Enum.Material.SmoothPlastic
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= handle and d.Material ~= Enum.Material.Neon then
			d.Material = material
			d.Color = color
			if info.Material == "Glass" then
				d.Transparency = math.max(d.Transparency, 0.2)
				d.Reflectance = 0.35
			elseif info.Material == "Metal" then
				d.Reflectance = 0.45
			end
		end
	end
	local s = handle.Size.X
	local sparks = if info.Rainbow then RAINBOW else ColorSequence.new(sparkColor)
	-- Sparks bursting off it...
	emitter(handle, "MutationSparkles", {
		Color = sparks,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.18), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.5, 1.1),
		Rate = if display then 10 else 26,
		Speed = NumberRange.new(s * 0.4, s * 1.1),
		Drag = 3,
	})
	-- ...big star glints flashing on its surface...
	emitter(handle, "MutationGlint", {
		Color = sparks,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, s * 0.45), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.25, 0.4),
		Rate = if display then 2 else 5,
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 90),
	})
	-- ...Moonlit also sheds drifting motes of moonlight.
	if mutation == "Moonlit" then
		emitter(handle, "Moonmotes", {
			Texture = "rbxasset://textures/particles/smoke_main.dds",
			Color = ColorSequence.new(sparkColor),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.1), NumberSequenceKeypoint.new(1, s * 0.35) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Lifetime = NumberRange.new(1.5, 2.5),
			Rate = 6,
			Speed = NumberRange.new(0.5, 1.5),
			SpreadAngle = Vector2.new(20, 20),
			Acceleration = Vector3.new(0, 1, 0),
		})
	end
	-- A glow you see from afar, and an outline that makes it pop (world treasure only: the
	-- engine renders a limited number of outlines at once).
	local light = Instance.new("PointLight")
	light.Name = "MutationLight"
	light.Color = if info.Rainbow then Color3.new(1, 1, 1) else sparkColor
	light.Range = s * (if display then 1.8 else 3.5)
	light.Brightness = if display then 0.7 else 2.2
	light.Shadows = false
	light.Parent = handle
	if not display then
		local outline = Instance.new("Highlight")
		outline.Name = "MutationOutline"
		outline.Adornee = model
		outline.FillColor = if info.Rainbow then Color3.new(1, 1, 1) else color
		outline.FillTransparency = 0.8
		outline.OutlineColor = if info.Rainbow then Color3.new(1, 1, 1) else sparkColor
		outline.OutlineTransparency = 0.1
		outline.DepthMode = Enum.HighlightDepthMode.Occluded
		outline.Parent = model
	end
	model:SetAttribute("Mutation", mutation)
	if info.Rainbow then
		CollectionService:AddTag(model, "RainbowTreasure")
	end
end

-- Returns Model with PrimaryPart "Handle" (invisible root). Handle is left Anchored = true.
-- maxScale caps the size (e.g. Vault pedestals). mutation: Mutations name or nil.
-- opts.Display: a showcase copy (Vault pedestal, trophies): lighter effects, no outline.
function TreasureVisual.Build(def, cframe: CFrame?, maxScale: number?, mutation: string?, opts: { Display: boolean? }?): Model
	local display = opts ~= nil and opts.Display == true
	local model = Instance.new("Model")
	model.Name = def.Name
	local s = math.min(TreasureVisual.Scale(def), maxScale or math.huge)
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

	local kit = TreasureModels.Kit(model, handle, s, color(def), accentFor(def), material(def))
	local custom = TreasureModels.Builders[def.Id]
	if custom then
		custom(kit)
	else
		local builder = Shapes[def.Shape] or Shapes.Gem
		builder(model, handle, s, color(def), accentFor(def), material(def))
	end
	flair(kit, handle, def, display)

	local info = Rarities.Info[def.Rarity]
	if info and info.Glow then
		local light = Instance.new("PointLight")
		light.Color = info.Color
		light.Range = if display then 5 + info.Rank else 8 + info.Rank * 2.5
		light.Brightness = if display then 0.5 + info.Rank * 0.06 else 1.2 + info.Rank * 0.25
		light.Shadows = false
		light.Parent = handle
	end
	local aura = TreasureVisual.RarityAura(handle, def)
	if aura and display then
		aura.Rate *= 0.3 -- a gentle shimmer on a pedestal, not a snow globe
	end
	applyMutation(model, handle, mutation, display)
	return model
end

return TreasureVisual
