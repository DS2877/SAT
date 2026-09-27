-- VAULT SKIN SHOWPIECES (Config/VaultSkins): the things that make a skin more than a repaint -
-- obelisks and torches, a dragon's head breathing fire, a floating diamond with sky beams...
-- Built by Services/VaultService into the plot's own Decor folder (only when the skin changes,
-- not on every vault re-render).
--
-- Plot space (the plot's floor CFrame): x across (-15..15), z from the entrance (-22, the gate,
-- facing the plaza = -Z) to the back wall (22); y up from the floor. Kept clear on purpose:
-- the pedestal grid (|x| < 12, z -16..8), the stairs (z 9..20), the trophy (x -11.5, z -27), the
-- collect pad and board (x 11.5, z -23..-27) and the carpet (|x| < 2.5). Showpieces go on the
-- facade (the arch crest, the posts, either side of the carpet), the back wall, the back
-- corners and the sky above. Phones render ten of these at once: every skin stays within a
-- few dozen parts, a couple of lights and emitters.
--
-- Client animations by attribute (Controllers/Effects): Spin (turns), Bob (floats up and down),
-- Orbit + OrbitCenter + OrbitRadius (circles a point), Pulse (neon breathes).

local CollectionService = game:GetService("CollectionService")

local Props = require(script.Parent.Props)

local VaultSkinDecor = {}

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

type Ctx = {
	Folder: Folder,
	F: CFrame, -- the plot floor
	P: { [string]: Color3 }, -- palette colours
	Owner: string, -- the owner's display name
	Rng: Random,
}

local function rgb(t: { number }): Color3
	return Color3.fromRGB(t[1], t[2], t[3])
end

-- Every showpiece part: anchored, no collision unless asked, out of raycasts, no tiny shadows.
local function part(ctx: Ctx, props): BasePart
	local class = props.Class or "Part"
	local p = Instance.new(class) :: BasePart
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "Class" and key ~= "At" then
			(p :: any)[key] = value
		end
	end
	if props.At then
		p.CFrame = ctx.F * props.At
	end
	local size = p.Size
	if math.max(size.X, size.Y, size.Z) < 4 then
		p.CastShadow = false
	end
	p.Parent = ctx.Folder
	return p
end

local function merge(props: { [string]: any }, extra: { [string]: any }?)
	if extra then
		for k, v in extra do
			props[k] = v
		end
	end
end

local function ball(ctx: Ctx, at: CFrame, size: Vector3, color: Color3, material: Enum.Material, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Name = "Ball", Shape = Enum.PartType.Ball, Size = size, At = at, Color = color, Material = material }
	merge(props, extra)
	return part(ctx, props)
end

-- A vertical cylinder (Roblox cylinders lie along X).
local function cyl(ctx: Ctx, at: CFrame, height: number, diameter: number, color: Color3, material: Enum.Material, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Name = "Cylinder", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), At = at * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = material }
	merge(props, extra)
	return part(ctx, props)
end

-- A disc facing the plaza (axis along Z).
local function disc(ctx: Ctx, at: CFrame, thickness: number, diameter: number, color: Color3, material: Enum.Material, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Name = "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(thickness, diameter, diameter), At = at * CFrame.Angles(0, math.rad(90), 0), Color = color, Material = material }
	merge(props, extra)
	return part(ctx, props)
end

local function box(ctx: Ctx, at: CFrame, size: Vector3, color: Color3, material: Enum.Material, extra: { [string]: any }?): BasePart
	local props: { [string]: any } = { Name = "Block", Size = size, At = at, Color = color, Material = material }
	merge(props, extra)
	return part(ctx, props)
end

-- A four-sided point (two crossed wedge ridges), base centred on `at`, pointing up its Y.
-- A WedgePart is full height at its +Z face and slopes down to its -Z edge: two of them back
-- to back (tall faces meeting in the middle) make a ridge; a second, slimmer ridge turned 90°
-- makes the point read as four-sided from every angle.
local function spike(ctx: Ctx, at: CFrame, width: number, height: number, color: Color3, material: Enum.Material, extra: { [string]: any }?)
	for _, turn in { 0, 90 } do
		local across = if turn == 0 then width else width * 0.7
		for _, side in { -1, 1 } do
			local props: { [string]: any } = {
				Name = "Spike",
				Class = "WedgePart",
				Size = Vector3.new(across, height, width / 2),
				At = at * CFrame.Angles(0, math.rad(turn), 0) * CFrame.new(0, height / 2, side * width / 4) * CFrame.Angles(0, if side > 0 then math.pi else 0, 0),
				Color = color,
				Material = material,
			}
			merge(props, extra)
			part(ctx, props)
		end
	end
end

-- A flat triangle a-b-c (plot space) from two wedges.
local function triangle(ctx: Ctx, a: Vector3, b: Vector3, c: Vector3, thickness: number, props)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	for i, spec in { { (a + b) / 2, right, math.abs(ab:Dot(back)), back }, { (a + c) / 2, -right, math.abs(ac:Dot(back)), -back } } do
		local w: { [string]: any } = { Name = "Membrane" .. i, Class = "WedgePart", Size = Vector3.new(thickness, height, spec[3]), At = CFrame.fromMatrix(spec[1], spec[2], up, spec[4]) }
		for k, v in props do
			w[k] = v
		end
		part(ctx, w)
	end
end

-- A BRILLIANT-CUT DIAMOND around `center`: a table on top, eight faceted crown panels, the
-- girdle, and eight pavilion facets down to the point. Every part turns about the same axis
-- (Orbit with a shared centre), so the whole stone spins and floats as one piece.
local function brilliant(ctx: Ctx, center: CFrame, radius: number, color: Color3, core: Color3, spin: number, bob: number)
	local world = ctx.F * center
	local axis = world.Position
	local made: { BasePart } = {}
	local function track(p: BasePart)
		table.insert(made, p)
	end
	local glass = { Color = color, Material = Enum.Material.Glass, Transparency = 0.12, Reflectance = 0.45 }
	local crownHeight, pavilionDepth, tableRadius = radius * 0.36, radius * 1.05, radius * 0.6
	local sides = 8
	local function rim(i: number, r: number, y: number): Vector3
		local a = (i + 0.5) / sides * 2 * math.pi
		return (center * CFrame.new(math.cos(a) * r, y, math.sin(a) * r)).Position
	end
	local before = #ctx.Folder:GetChildren()
	for i = 0, sides - 1 do
		local a0, a1 = rim(i, radius, 0), rim(i + 1, radius, 0)
		local t0, t1 = rim(i, tableRadius, crownHeight), rim(i + 1, tableRadius, crownHeight)
		triangle(ctx, a0, a1, t1, 0.05, glass)
		triangle(ctx, a0, t1, t0, 0.05, glass)
		triangle(ctx, a0, a1, (center * CFrame.new(0, -pavilionDepth, 0)).Position, 0.05, glass)
	end
	local children = ctx.Folder:GetChildren()
	for i = before + 1, #children do
		local child = children[i]
		if child:IsA("BasePart") then
			track(child)
		end
	end
	track(cyl(ctx, center * CFrame.new(0, crownHeight - 0.03, 0), 0.08, tableRadius * 2, Color3.new(1, 1, 1), Enum.Material.Glass, { Transparency = 0.3, Reflectance = 0.5 }))
	track(cyl(ctx, center, 0.18, radius * 2 + 0.05, color:Lerp(Color3.new(1, 1, 1), 0.5), Enum.Material.Glass, { Transparency = 0.2, Reflectance = 0.5 }))
	local heart = ball(ctx, center * CFrame.new(0, -pavilionDepth * 0.25, 0), Vector3.new(radius * 0.8, radius * 0.8, radius * 0.8), core, Enum.Material.Neon, { Transparency = 0.1 })
	track(heart)
	for _, p in made do
		p:SetAttribute("Orbit", spin)
		p:SetAttribute("OrbitCenter", axis)
		p:SetAttribute("Phase", 0)
		if bob ~= 0 then
			p:SetAttribute("Bob", bob)
			p:SetAttribute("BobSpeed", 0.7)
		end
	end
	return heart
end

-- A cut gem: a cube balanced on its corner (reads as a diamond from every side), with an
-- optional glowing core.
local function gem(ctx: Ctx, at: CFrame, size: number, color: Color3, core: Color3?, extra: { [string]: any }?): BasePart
	local tilt = CFrame.Angles(math.rad(45), 0, math.rad(35.26))
	local props: { [string]: any } = { Name = "Gem", Size = Vector3.new(size, size, size), At = at * tilt, Color = color, Material = Enum.Material.Glass, Transparency = 0.2, Reflectance = 0.35 }
	merge(props, extra)
	local shell = part(ctx, props)
	if core then
		local coreProps: { [string]: any } = { Name = "GemCore", Size = Vector3.new(size * 0.5, size * 0.5, size * 0.5), At = at * CFrame.Angles(0, math.rad(45), 0) * tilt, Color = core, Material = Enum.Material.Neon }
		if extra then
			for k, v in extra do
				if k ~= "Transparency" and k ~= "Reflectance" and k ~= "Material" and k ~= "Color" then
					coreProps[k] = v
				end
			end
		end
		part(ctx, coreProps)
	end
	return shell
end

-- A ring of `count` blocks (a halo / wheel rim), in the plane facing the plaza unless `flat`.
local function ring(ctx: Ctx, center: CFrame, radius: number, count: number, thickness: number, color: Color3, material: Enum.Material, flat: boolean?, extra: { [string]: any }?)
	local seg = 2 * math.pi * radius / count * 1.08
	for i = 0, count - 1 do
		local a = i / count * 2 * math.pi
		local placement = if flat
			then CFrame.Angles(0, a, 0) * CFrame.new(radius, 0, 0)
			else CFrame.Angles(0, 0, a) * CFrame.new(radius, 0, 0)
		local props: { [string]: any } = { Name = "RingSegment", Size = if flat then Vector3.new(thickness, thickness, seg) else Vector3.new(thickness, seg, thickness), At = center * placement, Color = color, Material = material }
		merge(props, extra)
		part(ctx, props)
	end
end

local function light(p: BasePart, color: Color3, range: number, brightness: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = shadows == true
	l.Parent = p
	return l
end

local function emitter(p: Instance, props): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = p
	return e
end

-- An invisible anchor for emitters / beams / lights.
local function anchor(ctx: Ctx, at: CFrame, size: Vector3?): BasePart
	return part(ctx, { Name = "DecorAnchor", Size = size or Vector3.new(1, 1, 1), At = at, Transparency = 1 })
end

-- A light beam between two plot-space points (Beams have no parts to render: cheap and bright).
local function lightBeam(ctx: Ctx, from: Vector3, to: Vector3, props)
	local a = anchor(ctx, CFrame.new(from))
	local b = anchor(ctx, CFrame.new(to))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = a, b
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1 = a0, a1
	beam.LightInfluence = 0
	beam.FaceCamera = true
	for key, value in props do
		(beam :: any)[key] = value
	end
	beam.Parent = a
	return beam
end

-- Sparkles/snow/embers over the whole vault.
local function skyEmitter(ctx: Ctx, y: number, props)
	local a = anchor(ctx, CFrame.new(0, y, 0), Vector3.new(30, 1, 44))
	return emitter(a, props)
end

local function float(p: BasePart, bob: number, speed: number?, phase: number?)
	p:SetAttribute("Bob", bob)
	p:SetAttribute("BobSpeed", speed or 1.2)
	p:SetAttribute("Phase", phase or 0)
end

local function orbit(p: BasePart, center: Vector3, radius: number, speed: number, phase: number)
	p:SetAttribute("Orbit", speed)
	p:SetAttribute("OrbitCenter", center)
	p:SetAttribute("OrbitRadius", radius)
	p:SetAttribute("Phase", phase)
end

local function pulse(p: BasePart, speed: number, phase: number?)
	p:SetAttribute("Pulse", speed)
	p:SetAttribute("Phase", phase or 0)
end

local FRONT, BACK = -22, 22
local SIDES = { -1, 1 }
-- Either side of the carpet, just outside the gate.
local function flank(side: number): CFrame
	return CFrame.new(side * 5.2, 0, FRONT - 3.4)
end
-- Above the arch plaque (its top trim is at y ~14.2).
local CREST = CFrame.new(0, 14.6, FRONT - 0.6)

local Builders: { [string]: (Ctx) -> () } = {}

-- CLASSIC: today's vault, untouched.
Builders.classic = function(_ctx: Ctx) end

-- PHARAOH'S TOMB ------------------------------------------------------------------------------
Builders.pharaoh = function(ctx: Ctx)
	local sand, gold, lapis, turq = ctx.P.Wall, ctx.P.Trim, ctx.P.Carpet, ctx.P.Glow
	local sandDark = sand:Lerp(Color3.new(0, 0, 0), 0.18)
	for _, side in SIDES do
		-- An obelisk either side of the carpet, glyphs glowing up its face, a gold tip.
		local base = flank(side)
		box(ctx, base * CFrame.new(0, 0.5, 0), Vector3.new(2.6, 1, 2.6), sandDark, Enum.Material.Sandstone, { CanCollide = true })
		box(ctx, base * CFrame.new(0, 1.3, 0), Vector3.new(2, 0.6, 2), gold, Enum.Material.Metal)
		box(ctx, base * CFrame.new(0, 5.1, 0), Vector3.new(1.6, 7, 1.6), sand, Enum.Material.Sandstone, { CanCollide = true })
		box(ctx, base * CFrame.new(0, 9.4, 0), Vector3.new(1.3, 1.6, 1.3), sand, Enum.Material.Sandstone)
		spike(ctx, base * CFrame.new(0, 10.2, 0), 1.3, 1.5, gold, Enum.Material.Metal, { Reflectance = 0.2 })
		for i = 0, 4 do
			local glyph = box(ctx, base * CFrame.new(0, 2.6 + i * 1.3, -0.82), Vector3.new(if i % 2 == 0 then 0.9 else 0.5, 0.55, 0.06), turq, Enum.Material.Neon)
			pulse(glyph, 1.4, i * 0.6)
		end
		-- A torch on each arch post, flames licking up.
		local torch = CFrame.new(side * 6, 8.4, FRONT - 1.3)
		box(ctx, torch * CFrame.new(0, -0.8, 0.3), Vector3.new(0.4, 0.4, 0.9), gold, Enum.Material.Metal)
		cyl(ctx, torch * CFrame.new(0, -0.3, 0), 1, 0.9, gold, Enum.Material.Metal)
		local flame = cyl(ctx, torch * CFrame.new(0, 0.3, 0), 0.3, 0.7, Color3.fromRGB(255, 150, 50), Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 3
		fire.Heat = 7
		fire.Parent = flame
		light(flame, Color3.fromRGB(255, 170, 80), 16, 1.2, false)
		-- A palm at each back corner.
		local palm = CFrame.new(side * 16, 0, BACK + 0.8)
		local lean = CFrame.Angles(0, 0, math.rad(side * 8))
		for i = 0, 5 do
			cyl(ctx, palm * lean * CFrame.new(0, 1 + i * 2, 0), 2.1, 1.1 - i * 0.07, Color3.fromRGB(150, 110, 70), Enum.Material.Wood)
		end
		local crown = (palm * lean * CFrame.new(0, 12.4, 0)).Position
		for i = 0, 5 do
			local yaw = i / 6 * 2 * math.pi
			part(ctx, {
				Name = "PalmLeaf",
				Class = "WedgePart",
				Size = Vector3.new(0.3, 1.2, 6),
				At = CFrame.new(crown) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, -0.5, 3),
				Color = Color3.fromRGB(70, 150, 60),
				Material = Enum.Material.Grass,
			})
		end
	end
	-- THE WINGED SUN over the gate.
	local sun = CREST * CFrame.new(0, 2.2, 0)
	disc(ctx, sun, 0.5, 3, gold, Enum.Material.Metal, { Reflectance = 0.25 })
	local halo = disc(ctx, sun * CFrame.new(0, 0, 0.3), 0.2, 4, turq, Enum.Material.Neon, { Transparency = 0.2 })
	light(halo, turq, 18, 1.2)
	for _, side in SIDES do
		for i = 1, 3 do
			local length = 5.2 - i * 1.1
			box(ctx, sun * CFrame.new(side * (1.4 + length / 2), 0.9 - i * 0.55, 0) * CFrame.Angles(0, 0, math.rad(side * (8 + i * 3))), Vector3.new(length, 0.5, 0.3), if i % 2 == 1 then gold else lapis, Enum.Material.Metal)
		end
	end
	-- Two cobras rearing on the plaque ends.
	for _, side in SIDES do
		local cobra = CFrame.new(side * 7.4, 14.4, FRONT - 0.6)
		cyl(ctx, cobra * CFrame.new(0, 0.9, 0), 1.8, 0.6, gold, Enum.Material.Metal)
		box(ctx, cobra * CFrame.new(0, 2, -0.1), Vector3.new(1.3, 1, 0.3), gold, Enum.Material.Metal)
		box(ctx, cobra * CFrame.new(0, 2.05, -0.28), Vector3.new(0.5, 0.4, 0.1), lapis, Enum.Material.Metal)
	end
	-- Hieroglyphs along the back wall.
	for i = -6, 6 do
		local glyph = box(ctx, CFrame.new(i * 1.9, 7.6, BACK - 0.55), Vector3.new(if i % 3 == 0 then 0.5 else 0.9, if i % 2 == 0 then 1.4 else 0.8, 0.08), if i % 2 == 0 then turq else lapis, if i % 2 == 0 then Enum.Material.Neon else Enum.Material.Metal)
		if i % 2 == 0 then
			pulse(glyph, 0.8, i * 0.4)
		end
	end
	-- Warm desert dust drifting through.
	skyEmitter(ctx, 18, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(240, 210, 160)), Transparency = NumberSequence.new(0.85, 1), Size = NumberSequence.new(3, 6), Lifetime = NumberRange.new(5, 8), Rate = 2, Speed = NumberRange.new(0.5, 1.5), Acceleration = Vector3.new(1, -0.2, 0), LightInfluence = 1 })
end

-- LOST TEMPLE ---------------------------------------------------------------------------------
Builders.jungle = function(ctx: Ctx)
	local stone, moss, glow = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local leaf = Color3.fromRGB(70, 140, 50)
	local dark = stone:Lerp(Color3.new(0, 0, 0), 0.35)
	for _, side in SIDES do
		-- A stone idol head either side of the carpet, eyes burning green.
		local base = flank(side)
		box(ctx, base * CFrame.new(0, 0.7, 0), Vector3.new(2.8, 1.4, 2.8), dark, Enum.Material.Cobblestone, { CanCollide = true })
		box(ctx, base * CFrame.new(0, 3, 0), Vector3.new(2.5, 3.2, 2.3), stone, Enum.Material.Slate, { CanCollide = true })
		box(ctx, base * CFrame.new(0, 4.1, -1.05), Vector3.new(2.6, 0.5, 0.5), dark, Enum.Material.Slate) -- brow
		for _, x in { -0.55, 0.55 } do
			local eye = box(ctx, base * CFrame.new(x, 3.55, -1.18), Vector3.new(0.5, 0.35, 0.1), glow, Enum.Material.Neon)
			pulse(eye, 0.9, side)
		end
		box(ctx, base * CFrame.new(0, 2.75, -1.25), Vector3.new(0.5, 0.9, 0.35), stone, Enum.Material.Slate) -- nose
		box(ctx, base * CFrame.new(0, 1.95, -1.17), Vector3.new(1.5, 0.35, 0.1), Color3.fromRGB(20, 24, 18), Enum.Material.Slate) -- mouth
		box(ctx, base * CFrame.new(0, 4.75, 0), Vector3.new(2.7, 0.35, 2.5), moss, Enum.Material.Grass) -- moss cap
		local glowAnchor = anchor(ctx, base * CFrame.new(0, 3.5, -1.8))
		light(glowAnchor, glow, 10, 1)
		-- Ferns and bushes at the back corners.
		for i = 0, 4 do
			local c = CFrame.new(side * (15.4 + (i % 2) * 0.6), 0.8 + (i % 3) * 0.9, BACK - 2 - i * 2.2)
			ball(ctx, c, Vector3.new(2.6, 2.2, 2.6), leaf:Lerp(Color3.fromRGB(40, 100, 40), (i % 3) / 3), Enum.Material.LeafyGrass)
		end
	end
	-- Vines hanging off the arch plaque and the back wall, swaying leaves on them.
	for _, spot in { { -5, FRONT - 1.2, 11.2 }, { -2, FRONT - 1.2, 11.2 }, { 3, FRONT - 1.2, 11.2 }, { 6.4, FRONT - 1.2, 11.2 }, { -9, BACK - 0.7, 9.4 }, { -1, BACK - 0.7, 9.4 }, { 8, BACK - 0.7, 9.4 } } do
		local length = 3 + (math.abs(spot[1]) % 3)
		local top = CFrame.new(spot[1], spot[3], spot[2])
		box(ctx, top * CFrame.new(0, -length / 2, 0) * CFrame.Angles(0, 0, math.rad(spot[1] % 5 - 2)), Vector3.new(0.22, length, 0.22), Color3.fromRGB(60, 110, 40), Enum.Material.Grass)
		for j = 1, 3 do
			part(ctx, { Name = "Leaf", Class = "WedgePart", Size = Vector3.new(0.1, 0.5, 0.8), At = top * CFrame.new(0.2 * (if j % 2 == 0 then 1 else -1), -j * length / 3.4, 0) * CFrame.Angles(0, math.rad(j * 70), math.rad(30)), Color = leaf, Material = Enum.Material.Grass })
		end
	end
	-- Leaves creeping along the side balustrades.
	for _, x in { -15, 15 } do
		for z = -18, 18, 6 do
			ball(ctx, CFrame.new(x, 3.5, z), Vector3.new(1.6, 0.8, 2.4), leaf, Enum.Material.LeafyGrass)
		end
	end
	-- THE SUN MASK over the gate.
	local mask = CREST * CFrame.new(0, 2.6, 0)
	disc(ctx, mask, 0.8, 5, stone, Enum.Material.Slate)
	for i = 0, 7 do
		local a = i / 8 * 2 * math.pi
		box(ctx, mask * CFrame.Angles(0, 0, a) * CFrame.new(0, 3, 0), Vector3.new(0.9, 1.4, 0.6), dark, Enum.Material.Slate)
	end
	for _, x in { -0.9, 0.9 } do
		local eye = box(ctx, mask * CFrame.new(x, 0.5, -0.45), Vector3.new(0.7, 0.45, 0.1), glow, Enum.Material.Neon)
		pulse(eye, 0.7)
	end
	box(ctx, mask * CFrame.new(0, -1, -0.45), Vector3.new(1.8, 0.35, 0.1), Color3.fromRGB(20, 24, 18), Enum.Material.Slate)
	light(anchor(ctx, mask * CFrame.new(0, 0, -2)), glow, 14, 1)
	-- Fireflies.
	skyEmitter(ctx, 6, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(220, 255, 120)), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.35), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(3, 6), Rate = 6, Speed = NumberRange.new(0.3, 1), SpreadAngle = Vector2.new(180, 180) })
end

-- FROST PALACE --------------------------------------------------------------------------------
Builders.frost = function(ctx: Ctx)
	local ice, frost, glow = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local snow = Color3.fromRGB(245, 250, 255)
	-- A crown of ice spires on the gate, the middle one tallest.
	for i, spec in { { 0, 8, 2 }, { -3.2, 5.5, 1.5 }, { 3.2, 5.5, 1.5 }, { -6.3, 3.5, 1.2 }, { 6.3, 3.5, 1.2 } } do
		local base = CFrame.new(spec[1], 14.3, FRONT - 0.6)
		box(ctx, base * CFrame.new(0, spec[2] * 0.3, 0), Vector3.new(spec[3], spec[2] * 0.6, spec[3]), ice, Enum.Material.Ice, { Transparency = 0.1 })
		spike(ctx, base * CFrame.new(0, spec[2] * 0.6, 0), spec[3], spec[2] * 0.5, frost, Enum.Material.Glass, { Transparency = 0.15 })
		if i == 1 then
			local star = gem(ctx, base * CFrame.new(0, spec[2] * 1.1 + 0.9, 0), 1.3, Color3.fromRGB(220, 250, 255), glow)
			star:SetAttribute("Spin", 0.8)
			light(star, glow, 22, 1.4)
		end
	end
	-- Icicles along the arch trim and the back wall top.
	for x = -6.5, 6.5, 1.3 do
		local length = 0.9 + (math.abs(x * 7) % 5) * 0.28
		part(ctx, { Name = "Icicle", Class = "WedgePart", Size = Vector3.new(0.35, length, 0.35), At = CFrame.new(x, 11 - length / 2, FRONT - 1.2) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(220, 245, 255), Material = Enum.Material.Glass, Transparency = 0.15 })
	end
	for x = -13.5, 13.5, 1.8 do
		local length = 0.8 + (math.abs(x * 5) % 4) * 0.3
		part(ctx, { Name = "Icicle", Class = "WedgePart", Size = Vector3.new(0.35, length, 0.35), At = CFrame.new(x, 9.2 - length / 2, BACK - 0.7) * CFrame.Angles(math.pi, 0, 0), Color = Color3.fromRGB(220, 245, 255), Material = Enum.Material.Glass, Transparency = 0.15 })
	end
	-- Snow lying on every rail.
	for _, x in { -15, 15 } do
		box(ctx, CFrame.new(x, 3.55, 0), Vector3.new(1.7, 0.4, 43), snow, Enum.Material.Snow)
	end
	for _, side in SIDES do
		box(ctx, CFrame.new(side * 10.75, 3.55, FRONT), Vector3.new(7.8, 0.4, 1.7), snow, Enum.Material.Snow)
		-- A cluster of ice crystals either side of the carpet.
		local base = flank(side)
		for j, spec in { { 0, 0, 5, 1.4, 0 }, { 0.8, 0.5, 3.2, 1, 18 }, { -0.8, 0.3, 3.6, 1.1, -15 }, { 0.2, -0.9, 2.6, 0.9, 10 } } do
			local c = base * CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(math.rad(spec[5]), j, math.rad(-spec[5]))
			box(ctx, c * CFrame.new(0, spec[3] / 2, 0), Vector3.new(spec[4], spec[3], spec[4]), ice:Lerp(Color3.new(1, 1, 1), 0.2), Enum.Material.Ice, { Transparency = 0.15, CanCollide = j == 1 })
			spike(ctx, c * CFrame.new(0, spec[3], 0), spec[4], spec[4] * 1.2, frost, Enum.Material.Glass, { Transparency = 0.15 })
		end
		light(anchor(ctx, base * CFrame.new(0, 3, 0)), glow, 12, 1.1)
		-- Frozen fountains of snow at the back corners.
		local corner = CFrame.new(side * 15.8, 0, BACK + 0.6)
		cyl(ctx, corner * CFrame.new(0, 3, 0), 6, 1.6, ice, Enum.Material.Ice, { Transparency = 0.1 })
		spike(ctx, corner * CFrame.new(0, 6, 0), 1.6, 3, frost, Enum.Material.Glass, { Transparency = 0.15 })
	end
	-- Its own snowfall, and a cold mist rolling out of the gate.
	skyEmitter(ctx, 34, { Texture = SPARKLE, Color = ColorSequence.new(Color3.new(1, 1, 1)), LightEmission = 0.4, Size = NumberSequence.new(0.35, 0.25), Lifetime = NumberRange.new(7, 9), Rate = 22, Speed = NumberRange.new(3, 5), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(15, 15), Acceleration = Vector3.new(0.6, 0, 0.3) })
	local mist = anchor(ctx, CFrame.new(0, 0.6, FRONT - 2), Vector3.new(10, 1, 3))
	emitter(mist, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(220, 245, 255)), Transparency = NumberSequence.new(0.8, 1), Size = NumberSequence.new(2, 5), Lifetime = NumberRange.new(3, 5), Rate = 3, Speed = NumberRange.new(0.5, 1), EmissionDirection = Enum.NormalId.Front, LightInfluence = 1 })
end

-- GOLDEN PALACE -------------------------------------------------------------------------------
Builders.royal = function(ctx: Ctx)
	local gold, velvet, white = ctx.P.Wall, ctx.P.Carpet, ctx.P.Glow
	local black = ctx.P.Floor
	local jewels = { Color3.fromRGB(230, 30, 60), Color3.fromRGB(40, 110, 255), Color3.fromRGB(30, 210, 110), Color3.fromRGB(230, 30, 60), Color3.fromRGB(40, 110, 255) }
	-- THE CROWN over the gate: velvet cap in a gold band, five jewelled points, an orb on top.
	local crown = CREST * CFrame.new(0, 0.2, 0)
	cyl(ctx, crown * CFrame.new(0, 0.8, 0), 1.6, 6.4, gold, Enum.Material.Foil, { Reflectance = 0.3 })
	ball(ctx, crown * CFrame.new(0, 1.7, 0), Vector3.new(5.6, 4, 5.6), velvet, Enum.Material.Fabric)
	for i = 0, 4 do
		local a = (i - 2) * math.rad(34)
		local tip = crown * CFrame.new(math.sin(a) * 3, 1.6, -math.cos(a) * 3) * CFrame.Angles(0, -a, 0)
		spike(ctx, tip, 1.1, 2.4, gold, Enum.Material.Foil, { Reflectance = 0.3 })
		local jewel = ball(ctx, tip * CFrame.new(0, 2.7, 0), Vector3.new(0.9, 0.9, 0.9), jewels[i + 1], Enum.Material.Glass, { Reflectance = 0.3 })
		pulse(jewel, 1.1, i)
		ball(ctx, crown * CFrame.new(math.sin(a) * 3.25, 0.8, -math.cos(a) * 3.25), Vector3.new(0.7, 0.7, 0.7), jewels[i + 1], Enum.Material.Glass)
	end
	local orb = ball(ctx, crown * CFrame.new(0, 4.2, 0), Vector3.new(1.3, 1.3, 1.3), gold, Enum.Material.Foil, { Reflectance = 0.35 })
	box(ctx, crown * CFrame.new(0, 5.3, 0), Vector3.new(0.3, 1.2, 0.3), gold, Enum.Material.Foil)
	box(ctx, crown * CFrame.new(0, 5.4, 0), Vector3.new(0.9, 0.3, 0.3), gold, Enum.Material.Foil)
	light(orb, Color3.fromRGB(255, 225, 150), 24, 1.4)
	emitter(orb, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 230, 140), Color3.new(1, 1, 1)), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(1.5, 2.5), Rate = 10, Speed = NumberRange.new(1, 3), SpreadAngle = Vector2.new(180, 180) })
	for _, side in SIDES do
		-- Gold urns on black marble, a fountain of glitter out of each.
		local base = flank(side)
		box(ctx, base * CFrame.new(0, 0.9, 0), Vector3.new(2.4, 1.8, 2.4), black, Enum.Material.Marble, { CanCollide = true })
		box(ctx, base * CFrame.new(0, 1.9, 0), Vector3.new(2.6, 0.25, 2.6), gold, Enum.Material.Foil)
		cyl(ctx, base * CFrame.new(0, 2.4, 0), 0.8, 1.2, gold, Enum.Material.Foil)
		ball(ctx, base * CFrame.new(0, 3.9, 0), Vector3.new(2.6, 2.4, 2.6), gold, Enum.Material.Foil, { Reflectance = 0.3, CanCollide = true })
		cyl(ctx, base * CFrame.new(0, 5.2, 0), 0.9, 1.2, gold, Enum.Material.Foil)
		local lip = cyl(ctx, base * CFrame.new(0, 5.75, 0), 0.3, 1.9, gold, Enum.Material.Foil)
		emitter(lip, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)), LightEmission = 1, Size = NumberSequence.new(0.45, 0), Lifetime = NumberRange.new(1.2, 1.8), Rate = 14, Speed = NumberRange.new(5, 7), SpreadAngle = Vector2.new(18, 18), Acceleration = Vector3.new(0, -9, 0), EmissionDirection = Enum.NormalId.Top })
		-- Royal banners hanging off the gate posts.
		local banner = CFrame.new(side * 6, 6.6, FRONT - 1.15)
		box(ctx, banner, Vector3.new(1.8, 6.4, 0.12), velvet, Enum.Material.Fabric)
		box(ctx, banner * CFrame.new(0, 3.25, 0), Vector3.new(2.2, 0.3, 0.3), gold, Enum.Material.Foil)
		for _, x in { -0.85, 0.85 } do
			box(ctx, banner * CFrame.new(x, 0, -0.07), Vector3.new(0.12, 6.4, 0.05), gold, Enum.Material.Foil)
		end
		part(ctx, { Name = "BannerTip", Class = "WedgePart", Size = Vector3.new(0.12, 0.9, 0.9), At = banner * CFrame.new(0, -3.6, 0) * CFrame.Angles(0, math.rad(90), math.pi), Color = velvet, Material = Enum.Material.Fabric })
		spike(ctx, banner * CFrame.new(0, 0.6, -0.1), 0.7, 0.9, gold, Enum.Material.Foil)
		box(ctx, banner * CFrame.new(0, 0.4, -0.1), Vector3.new(0.9, 0.35, 0.1), gold, Enum.Material.Foil)
		-- Gold lions' pillars at the back corners.
		local corner = CFrame.new(side * 15.8, 0, BACK + 0.6)
		cyl(ctx, corner * CFrame.new(0, 4.5, 0), 9, 1.6, gold, Enum.Material.Foil, { Reflectance = 0.25 })
		ball(ctx, corner * CFrame.new(0, 9.6, 0), Vector3.new(1.8, 1.8, 1.8), gold, Enum.Material.Foil, { Reflectance = 0.3 })
	end
	-- Gold edges down the velvet carpet.
	for _, x in { -1.95, 1.95 } do
		box(ctx, CFrame.new(x, 0.1, 0), Vector3.new(0.25, 0.06, 42), gold, Enum.Material.Foil)
		box(ctx, CFrame.new(x * 1.3, -0.5, FRONT - 4), Vector3.new(0.25, 0.08, 8), gold, Enum.Material.Foil)
	end
	-- Glitter in the air.
	skyEmitter(ctx, 20, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 225, 130), white), LightEmission = 1, Size = NumberSequence.new(0.3, 0), Lifetime = NumberRange.new(3, 5), Rate = 12, Speed = NumberRange.new(0.5, 1.5), SpreadAngle = Vector2.new(180, 180) })
end

-- EMBERFALL FORGE -----------------------------------------------------------------------------
Builders.ember = function(ctx: Ctx)
	local basalt, lava = ctx.P.Wall, ctx.P.Glow
	local iron = Color3.fromRGB(60, 58, 62)
	for _, side in SIDES do
		-- Braziers either side of the carpet.
		local base = flank(side)
		box(ctx, base * CFrame.new(0, 0.9, 0), Vector3.new(2.2, 1.8, 2.2), basalt, Enum.Material.Basalt, { CanCollide = true })
		cyl(ctx, base * CFrame.new(0, 2.6, 0), 1.6, 0.9, iron, Enum.Material.Metal)
		cyl(ctx, base * CFrame.new(0, 3.7, 0), 0.8, 3, iron, Enum.Material.Metal)
		local coals = cyl(ctx, base * CFrame.new(0, 4.05, 0), 0.2, 2.5, lava, Enum.Material.Neon)
		local fire = Instance.new("Fire")
		fire.Size = 6
		fire.Heat = 12
		fire.Color = Color3.fromRGB(255, 120, 30)
		fire.SecondaryColor = Color3.fromRGB(255, 220, 90)
		fire.Parent = coals
		light(coals, Color3.fromRGB(255, 130, 50), 20, 1.6)
		-- Magma cracks down the gate posts.
		for i = 0, 3 do
			local crack = box(ctx, CFrame.new(side * 6 + (if i % 2 == 0 then 0.25 else -0.25), 1.5 + i * 2.4, FRONT - 1.03) * CFrame.Angles(0, 0, math.rad(if i % 2 == 0 then 22 else -22)), Vector3.new(0.18, 2.6, 0.06), lava, Enum.Material.Neon)
			pulse(crack, 0.7, i * 0.8 + side)
		end
		-- Basalt columns with lava at their feet at the back corners.
		local corner = CFrame.new(side * 15.9, 0, BACK + 0.5)
		for j, h in { 8, 5.5, 3.5 } do
			local off = CFrame.new((j - 2) * 0.9 * side, 0, (j - 2) * 0.7)
			part(ctx, { Name = "BasaltColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, 1.5, 1.5), At = corner * off * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = basalt:Lerp(Color3.new(0, 0, 0), j * 0.08), Material = Enum.Material.Basalt })
		end
	end
	-- Lava falls down the back wall into a glowing pool.
	for _, x in { -8, 0.5, 9 } do
		local fall = box(ctx, CFrame.new(x, 4.7, BACK - 0.58), Vector3.new(1.2, 9.4, 0.12), lava, Enum.Material.Neon)
		pulse(fall, 0.5, x)
		cyl(ctx, CFrame.new(x, 0.05, BACK - 1.2), 0.1, 2.6, lava, Enum.Material.Neon)
	end
	-- THE ANVIL over the gate with two crossed hammers behind it.
	local anvil = CREST * CFrame.new(0, 0, 0)
	box(ctx, anvil * CFrame.new(0, 0.6, 0), Vector3.new(3, 1.2, 2), iron, Enum.Material.Metal)
	box(ctx, anvil * CFrame.new(0, 1.6, 0), Vector3.new(1.6, 1, 1.4), iron, Enum.Material.Metal)
	box(ctx, anvil * CFrame.new(0.4, 2.55, 0), Vector3.new(4.2, 0.9, 1.8), iron, Enum.Material.Metal)
	part(ctx, { Name = "AnvilHorn", Class = "WedgePart", Size = Vector3.new(1.4, 0.9, 2.2), At = anvil * CFrame.new(-2.7, 2.55, 0) * CFrame.Angles(0, math.rad(-90), 0), Color = iron, Material = Enum.Material.Metal })
	local hot = box(ctx, anvil * CFrame.new(0.4, 3.05, 0), Vector3.new(2, 0.15, 0.6), lava, Enum.Material.Neon)
	pulse(hot, 1.3)
	for _, side in SIDES do
		local handle = anvil * CFrame.new(0, 3.4, 0.9) * CFrame.Angles(0, 0, math.rad(side * 40))
		box(ctx, handle, Vector3.new(0.35, 6, 0.35), Color3.fromRGB(90, 60, 40), Enum.Material.Wood)
		box(ctx, handle * CFrame.new(0, 3, 0), Vector3.new(2, 1.1, 1.1), iron, Enum.Material.Metal)
	end
	light(hot, Color3.fromRGB(255, 140, 50), 16, 1.2)
	-- Embers rising off the lava carpet.
	local river = anchor(ctx, CFrame.new(0, 0.3, 0), Vector3.new(3, 0.5, 40))
	emitter(river, { Texture = FIRE, Color = ColorSequence.new(Color3.fromRGB(255, 180, 60), Color3.fromRGB(255, 60, 20)), LightEmission = 1, Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(1.5, 3), Rate = 10, Speed = NumberRange.new(2, 4), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top, Acceleration = Vector3.new(0.5, 1, 0) })
	skyEmitter(ctx, 8, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 150, 60)), LightEmission = 1, Size = NumberSequence.new(0.3, 0), Lifetime = NumberRange.new(3, 5), Rate = 8, Speed = NumberRange.new(1, 2.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40) })
end

-- RIMEHEART CITADEL ---------------------------------------------------------------------------
Builders.rime = function(ctx: Ctx)
	local blue, white, aurora = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	-- THE AURORA over the vault (Controllers/WorldLife brightens "Aurora" beams at night).
	for i, spec in { { 36, 70, -60 }, { 42, -60, 50 } } do
		local beam = lightBeam(ctx, Vector3.new(-17, spec[1], BACK), Vector3.new(17, spec[1], FRONT + 6), {
			Color = if i == 1
				then ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 255, 170)), ColorSequenceKeypoint.new(0.5, Color3.fromRGB(90, 220, 255)), ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 120, 255)) })
				else ColorSequence.new(Color3.fromRGB(120, 255, 200), Color3.fromRGB(100, 200, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.45), NumberSequenceKeypoint.new(0.75, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Texture = SMOKE,
			TextureMode = Enum.TextureMode.Wrap,
			TextureLength = 24,
			TextureSpeed = if i == 1 then 0.08 else -0.06,
			LightEmission = 1,
			Width0 = 10,
			Width1 = 14,
			CurveSize0 = spec[2],
			CurveSize1 = spec[3],
			Segments = 20,
		})
		CollectionService:AddTag(beam, "Aurora")
	end
	-- THE FROZEN HEART over the gate.
	local heart = CREST * CFrame.new(0, 3.2, 0)
	local shellColor = Color3.fromRGB(160, 240, 255)
	local pieces = {
		ball(ctx, heart * CFrame.new(-0.9, 0.6, 0), Vector3.new(2.4, 2.4, 1.6), shellColor, Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.2 }),
		ball(ctx, heart * CFrame.new(0.9, 0.6, 0), Vector3.new(2.4, 2.4, 1.6), shellColor, Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.2 }),
		box(ctx, heart * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(45)), Vector3.new(2.3, 2.3, 1.5), shellColor, Enum.Material.Glass, { Transparency = 0.25, Reflectance = 0.2 }),
	}
	local core = ball(ctx, heart * CFrame.new(0, 0.1, 0), Vector3.new(1.4, 1.4, 1), aurora, Enum.Material.Neon)
	table.insert(pieces, core)
	for _, p in pieces do
		float(p, 0.35, 1)
	end
	pulse(core, 1.1)
	light(core, aurora, 22, 1.6)
	emitter(core, { Texture = SPARKLE, Color = ColorSequence.new(aurora, Color3.new(1, 1, 1)), LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(1.5, 2.5), Rate = 8, Speed = NumberRange.new(1, 2), SpreadAngle = Vector2.new(180, 180) })
	-- Jagged ice either side of the carpet and at the back corners.
	for _, side in SIDES do
		for _, base in { flank(side), CFrame.new(side * 15.8, 0, BACK + 0.6) } do
			for j = 1, 4 do
				local h = 5 - j * 0.8
				local tilt = CFrame.Angles(math.rad((j - 2.5) * 12), j * 1.3, math.rad((j - 2) * 10 * side))
				local shard = base * CFrame.new(((j % 2) - 0.5) * 1.2, 0, ((j // 2) - 0.5) * 1.1) * tilt
				box(ctx, shard * CFrame.new(0, h / 2, 0), Vector3.new(1.1, h, 1.1), blue:Lerp(Color3.new(1, 1, 1), 0.25 * (j % 2)), Enum.Material.Glacier, { CanCollide = j == 1 })
				spike(ctx, shard * CFrame.new(0, h, 0), 1.1, 1.2, white, Enum.Material.Ice)
			end
		end
		box(ctx, CFrame.new(side * 15, 3.55, 0), Vector3.new(1.7, 0.4, 43), white, Enum.Material.Snow)
		box(ctx, CFrame.new(side * 10.75, 3.55, FRONT), Vector3.new(7.8, 0.4, 1.7), white, Enum.Material.Snow)
	end
	local mist = anchor(ctx, CFrame.new(0, 0.6, 0), Vector3.new(24, 1, 40))
	emitter(mist, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(200, 255, 240)), Transparency = NumberSequence.new(0.88, 1), Size = NumberSequence.new(3, 6), Lifetime = NumberRange.new(4, 6), Rate = 3, Speed = NumberRange.new(0.2, 0.6), LightInfluence = 1 })
end

-- STARFALL SANCTUM ----------------------------------------------------------------------------
Builders.starfall = function(ctx: Ctx)
	local violet, gold, glow = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local cyan = ctx.P.Screen
	-- A PLANET over the gate, ringed, with crystals orbiting it.
	local planetAt = CREST * CFrame.new(0, 5.5, -1)
	local planet = ball(ctx, planetAt, Vector3.new(6, 6, 6), Color3.fromRGB(90, 70, 190), Enum.Material.SmoothPlastic)
	float(planet, 0.5, 0.6)
	local band = ball(ctx, planetAt * CFrame.new(0, 0.6, 0), Vector3.new(6.05, 1.1, 6.05), Color3.fromRGB(150, 110, 240), Enum.Material.SmoothPlastic)
	float(band, 0.5, 0.6)
	local ringPart = part(ctx, { Name = "PlanetRing", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 10, 10), At = planetAt * CFrame.Angles(math.rad(18), 0, math.rad(90 + 12)), Color = gold, Material = Enum.Material.Neon, Transparency = 0.45 })
	float(ringPart, 0.5, 0.6)
	light(planet, glow, 26, 1.3)
	local center = (ctx.F * planetAt).Position
	for i = 0, 4 do
		local crystal = gem(ctx, planetAt * CFrame.new(6.5, 0, 0), 0.9, if i % 2 == 0 then glow else cyan, nil, { Material = Enum.Material.Neon, Transparency = 0, Reflectance = 0 })
		orbit(crystal, center + Vector3.new(0, (i - 2) * 0.6, 0), 6.5 + (i % 2), 0.45 + i * 0.05, i / 5 * 2 * math.pi)
	end
	-- Crystal pylons either side of the carpet, floating over their bases.
	for _, side in SIDES do
		local base = flank(side)
		cyl(ctx, base * CFrame.new(0, 0.5, 0), 1, 2.6, violet:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Slate, { CanCollide = true })
		cyl(ctx, base * CFrame.new(0, 1.05, 0), 0.1, 2.2, glow, Enum.Material.Neon)
		for j, spec in { { 3.2, 1.6 }, { 5.4, 1.1 }, { 7, 0.7 } } do
			local g = gem(ctx, base * CFrame.new(0, spec[1], 0), spec[2], Color3.fromRGB(210, 180, 255), glow)
			float(g, 0.4, 0.9, j + side)
			g:SetAttribute("Spin", 0.5 * side)
		end
		light(anchor(ctx, base * CFrame.new(0, 4, 0)), glow, 12, 1.2)
	end
	-- Stars set into the floor margins and a constellation on the back wall.
	local rng = ctx.Rng
	for _ = 1, 22 do
		local x = if rng:NextNumber() < 0.5 then rng:NextNumber(-14.3, -12.2) else rng:NextNumber(12.2, 14.3)
		local star = cyl(ctx, CFrame.new(x, 0.05, rng:NextNumber(-20, 9)), 0.06, rng:NextNumber(0.25, 0.55), if rng:NextNumber() < 0.6 then Color3.new(1, 1, 1) else glow, Enum.Material.Neon)
		pulse(star, rng:NextNumber(0.6, 1.6), rng:NextNumber(0, 6))
	end
	local points = { Vector2.new(-11, 6), Vector2.new(-7, 8.4), Vector2.new(-3, 7.2), Vector2.new(1, 8.8), Vector2.new(5, 6.4), Vector2.new(9, 8), Vector2.new(12, 5.6) }
	for i, p in points do
		local star = ball(ctx, CFrame.new(p.X, p.Y, BACK - 0.6), Vector3.new(0.45, 0.45, 0.45), Color3.new(1, 1, 1), Enum.Material.Neon)
		pulse(star, 1.2, i)
		local nextPoint = points[i + 1]
		if nextPoint then
			local a, b = Vector3.new(p.X, p.Y, BACK - 0.58), Vector3.new(nextPoint.X, nextPoint.Y, BACK - 0.58)
			box(ctx, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.08, 0.08, (b - a).Magnitude), glow, Enum.Material.Neon, { Transparency = 0.4 })
		end
	end
	skyEmitter(ctx, 28, { Texture = SPARKLE, Color = ColorSequence.new(Color3.new(1, 1, 1), glow), LightEmission = 1, Size = NumberSequence.new(0.4, 0), Lifetime = NumberRange.new(6, 9), Rate = 14, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(30, 30) })
end

-- CANDY KINGDOM -------------------------------------------------------------------------------
Builders.candy = function(ctx: Ctx)
	local pink, white, hot = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local red = Color3.fromRGB(235, 50, 70)
	local sweets = { Color3.fromRGB(255, 90, 150), Color3.fromRGB(120, 210, 255), Color3.fromRGB(255, 220, 90), Color3.fromRGB(150, 240, 150), Color3.fromRGB(200, 140, 255) }
	for _, side in SIDES do
		-- A giant spinning lollipop either side of the carpet.
		local base = flank(side)
		cyl(ctx, base * CFrame.new(0, 3.2, 0), 6.4, 0.5, white, Enum.Material.SmoothPlastic, { CanCollide = true })
		local head = base * CFrame.new(0, 7.8, 0)
		for j, spec in { { 5, if side < 0 then hot else Color3.fromRGB(120, 210, 255) }, { 3.9, white }, { 2.8, if side < 0 then hot else Color3.fromRGB(120, 210, 255) }, { 1.7, white }, { 0.7, if side < 0 then hot else Color3.fromRGB(120, 210, 255) } } do
			local d = disc(ctx, head, 0.8 + j * 0.06, spec[1], spec[2], Enum.Material.SmoothPlastic)
			d:SetAttribute("Spin", 0.7 * side)
		end
		-- Candy canes in front of the gate posts, hooks turned outwards.
		local cane = CFrame.new(side * 7.6, 0, FRONT - 1.3)
		for i = 0, 8 do
			cyl(ctx, cane * CFrame.new(0, 0.55 + i * 1.05, 0), 1.05, 0.7, if i % 2 == 0 then red else white, Enum.Material.SmoothPlastic)
		end
		for i = 1, 4 do
			local a = math.rad(i * 45)
			local hook = cane * CFrame.new(side * (1 - math.cos(a)) * 1.1, 9.5 + math.sin(a) * 1.1, 0) * CFrame.Angles(0, 0, -side * a)
			cyl(ctx, hook, 0.95, 0.7, if i % 2 == 0 then red else white, Enum.Material.SmoothPlastic)
		end
		-- Cotton candy trees at the back corners.
		local corner = CFrame.new(side * 15.8, 0, BACK + 0.6)
		cyl(ctx, corner * CFrame.new(0, 3, 0), 6, 0.4, white, Enum.Material.SmoothPlastic)
		for j = 0, 4 do
			ball(ctx, corner * CFrame.new(math.cos(j * 1.3) * 1, 6.6 + (j % 2) * 0.8, math.sin(j * 1.3) * 1), Vector3.new(2.8, 2.4, 2.8), if side < 0 then Color3.fromRGB(255, 190, 225) else Color3.fromRGB(190, 225, 255), Enum.Material.SmoothPlastic)
		end
	end
	-- Gumdrops along the rails.
	for i, spot in { { -15, -16 }, { -15, -6 }, { -15, 4 }, { -15, 14 }, { 15, -16 }, { 15, -6 }, { 15, 4 }, { 15, 14 }, { -9, FRONT }, { -12.5, FRONT } } do
		ball(ctx, CFrame.new(spot[1], 3.7, spot[2]), Vector3.new(1.2, 1, 1.2), sweets[(i % #sweets) + 1], Enum.Material.Glass, { Transparency = 0.1 })
	end
	-- Frosting dripping off the back wall.
	for x = -14, 14, 1.6 do
		ball(ctx, CFrame.new(x, 9.5, BACK), Vector3.new(1.8, 1, 1.6), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		if math.floor(x) % 3 == 0 then
			ball(ctx, CFrame.new(x, 8.6, BACK - 0.6), Vector3.new(0.6, 1.4, 0.5), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
		end
	end
	-- THE CUPCAKE over the gate, a cherry on top.
	local cake = CREST * CFrame.new(0, 0.2, 0)
	for i = 0, 11 do
		local a = i / 12 * 2 * math.pi
		box(ctx, cake * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.2, -2.1), Vector3.new(1.2, 2.4, 0.3), if i % 2 == 0 then hot else pink, Enum.Material.SmoothPlastic)
	end
	cyl(ctx, cake * CFrame.new(0, 1.2, 0), 2.4, 4, pink, Enum.Material.SmoothPlastic)
	for j, spec in { { 2.7, 5.2 }, { 3.7, 4.2 }, { 4.6, 3 }, { 5.4, 1.8 } } do
		ball(ctx, cake * CFrame.new(0, spec[1], 0), Vector3.new(spec[2], 1.5, spec[2]), if j % 2 == 0 then Color3.fromRGB(255, 240, 245) else Color3.fromRGB(255, 200, 225), Enum.Material.SmoothPlastic)
	end
	local cherry = ball(ctx, cake * CFrame.new(0, 6.5, 0), Vector3.new(1.3, 1.3, 1.3), red, Enum.Material.Glass, { Reflectance = 0.2 })
	box(ctx, cake * CFrame.new(0.3, 7.4, 0) * CFrame.Angles(0, 0, math.rad(-25)), Vector3.new(0.12, 1, 0.12), Color3.fromRGB(80, 140, 60), Enum.Material.SmoothPlastic)
	light(cherry, hot, 16, 1)
	for i = 0, 9 do
		local a = i / 10 * 2 * math.pi
		box(ctx, cake * CFrame.new(math.cos(a) * 1.8, 3.2 + (i % 3) * 0.6, math.sin(a) * 1.8) * CFrame.Angles(a, a * 2, 0), Vector3.new(0.12, 0.45, 0.12), sweets[(i % #sweets) + 1], Enum.Material.Neon)
	end
	-- A sprinkle storm.
	skyEmitter(ctx, 26, { Texture = SPARKLE, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 150)), ColorSequenceKeypoint.new(0.33, Color3.fromRGB(120, 210, 255)), ColorSequenceKeypoint.new(0.66, Color3.fromRGB(255, 220, 90)), ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 240, 150)) }), LightEmission = 0.6, Size = NumberSequence.new(0.35, 0.3), Lifetime = NumberRange.new(5, 7), Rate = 16, Speed = NumberRange.new(3, 5), EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(25, 25), RotSpeed = NumberRange.new(-180, 180), Rotation = NumberRange.new(0, 360) })
end

-- NEON CYBER ----------------------------------------------------------------------------------
Builders.neon = function(ctx: Ctx)
	local cyan, magenta, dark = ctx.P.Trim, ctx.P.Glow, ctx.P.Wall
	-- Neon outlines on the gate posts and the plaque.
	for _, side in SIDES do
		for _, dx in { -1, 1 } do
			local edge = box(ctx, CFrame.new(side * 6 + dx * 1.02, 5.4, FRONT - 1.02), Vector3.new(0.12, 11, 0.12), cyan, Enum.Material.Neon)
			pulse(edge, 1.5, dx)
		end
		-- Server towers either side of the carpet, blinking.
		local base = flank(side)
		box(ctx, base * CFrame.new(0, 3.6, 0), Vector3.new(2.2, 7.2, 2.2), dark, Enum.Material.DiamondPlate, { CanCollide = true })
		for row = 0, 5 do
			for col = 0, 1 do
				local led = box(ctx, base * CFrame.new((col - 0.5) * 0.9, 1.2 + row * 1.05, -1.12), Vector3.new(0.6, 0.16, 0.06), if (row + col) % 3 == 0 then magenta else cyan, Enum.Material.Neon)
				pulse(led, 2 + ((row * 2 + col) % 5) * 0.6, row + col * 2)
			end
		end
		box(ctx, base * CFrame.new(0, 7.35, 0), Vector3.new(2.4, 0.3, 2.4), cyan, Enum.Material.Neon)
		box(ctx, base * CFrame.new(0.6, 8.6, 0.6), Vector3.new(0.12, 2.2, 0.12), Color3.fromRGB(120, 120, 130), Enum.Material.Metal)
		local blink = ball(ctx, base * CFrame.new(0.6, 9.8, 0.6), Vector3.new(0.4, 0.4, 0.4), Color3.fromRGB(255, 40, 60), Enum.Material.Neon)
		pulse(blink, 3, side)
		light(anchor(ctx, base * CFrame.new(0, 4, -2)), if side < 0 then cyan else magenta, 12, 1.2)
		-- Neon pylons at the back corners.
		local corner = CFrame.new(side * 15.8, 0, BACK + 0.6)
		box(ctx, corner * CFrame.new(0, 6, 0), Vector3.new(1.2, 12, 1.2), dark, Enum.Material.DiamondPlate)
		for y = 1, 11, 2 do
			box(ctx, corner * CFrame.new(0, y, 0), Vector3.new(1.4, 0.2, 1.4), if y % 4 == 1 then cyan else magenta, Enum.Material.Neon)
		end
	end
	for _, y in { 11.05, 13.55 } do
		box(ctx, CFrame.new(0, y, FRONT - 1.05), Vector3.new(14.6, 0.14, 0.12), magenta, Enum.Material.Neon)
	end
	-- LASER GATE across the entrance (beams: you walk straight through).
	for i, y in { 1.2, 2.6, 4 } do
		lightBeam(ctx, Vector3.new(-5, y, FRONT - 0.2), Vector3.new(5, y + (if i == 2 then 0 else (i - 2) * 0.6), FRONT - 0.2), { Color = ColorSequence.new(Color3.fromRGB(255, 40, 80)), LightEmission = 1, Width0 = 0.15, Width1 = 0.15, Transparency = NumberSequence.new(0.1), Segments = 1 })
	end
	-- THE HOLO RING over the door: segments orbiting, a hologram cube spinning inside.
	local center = (ctx.F * (CREST * CFrame.new(0, 4.5, -0.4))).Position
	for i = 0, 13 do
		local seg = box(ctx, CREST * CFrame.new(3.8, 4.5, -0.4), Vector3.new(0.25, 0.25, 1.6), if i % 2 == 0 then cyan else magenta, Enum.Material.Neon)
		orbit(seg, center, 3.8, 0.8, i / 14 * 2 * math.pi)
	end
	local holo = box(ctx, CREST * CFrame.new(0, 4.5, -0.4) * CFrame.Angles(math.rad(35), math.rad(45), 0), Vector3.new(2, 2, 2), cyan, Enum.Material.ForceField)
	holo:SetAttribute("Spin", 1.2)
	local core = box(ctx, CREST * CFrame.new(0, 4.5, -0.4), Vector3.new(0.9, 0.9, 0.9), magenta, Enum.Material.Neon)
	core:SetAttribute("Spin", -1.6)
	light(core, magenta, 20, 1.5)
	-- Floor grid glow along the margins.
	for _, x in { -13.2, 13.2 } do
		local line = box(ctx, CFrame.new(x, 0.04, -5), Vector3.new(0.14, 0.05, 32), cyan, Enum.Material.Neon)
		pulse(line, 0.8, x)
	end
	skyEmitter(ctx, 3, { Texture = SPARKLE, Color = ColorSequence.new(cyan, magenta), LightEmission = 1, Size = NumberSequence.new(0.25, 0), Lifetime = NumberRange.new(2, 4), Rate = 8, Speed = NumberRange.new(1, 3), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10) })
end

-- HAUNTED CRYPT -------------------------------------------------------------------------------
Builders.crypt = function(ctx: Ctx)
	local stone, iron, ghost = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local bone = Color3.fromRGB(230, 222, 200)
	for _, side in SIDES do
		-- Crooked tombstones either side of the carpet.
		local base = flank(side) * CFrame.Angles(math.rad(side * 4), math.rad(side * 8), math.rad(side * 5))
		box(ctx, base * CFrame.new(0, 0.3, 0.6), Vector3.new(2.4, 0.6, 3.4), Color3.fromRGB(70, 90, 60), Enum.Material.Grass)
		box(ctx, base * CFrame.new(0, 1.9, 0), Vector3.new(2.2, 3.2, 0.7), stone, Enum.Material.Slate, { CanCollide = true })
		part(ctx, { Name = "TombTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.7, 2.2, 2.2), At = base * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, math.rad(90), 0), Color = stone, Material = Enum.Material.Slate })
		box(ctx, base * CFrame.new(0, 2.5, -0.37), Vector3.new(0.25, 1.4, 0.05), Color3.fromRGB(30, 30, 30), Enum.Material.Slate)
		box(ctx, base * CFrame.new(0, 2.8, -0.37), Vector3.new(0.9, 0.25, 0.05), Color3.fromRGB(30, 30, 30), Enum.Material.Slate)
		-- Iron spikes along the front rails.
		for x = 8, 14, 1.5 do
			local at = CFrame.new(side * x, 3.4, FRONT)
			box(ctx, at * CFrame.new(0, 0.8, 0), Vector3.new(0.18, 1.6, 0.18), iron, Enum.Material.CorrodedMetal)
			spike(ctx, at * CFrame.new(0, 1.6, 0), 0.35, 0.5, iron, Enum.Material.CorrodedMetal)
		end
		-- A dead tree at each back corner.
		Props.DeadTree(ctx.Folder, (ctx.F * CFrame.new(side * 16.2, 0, BACK + 1)).Position, ctx.Rng, Color3.fromRGB(70, 62, 56))
		-- A green-flamed lantern hanging off each gate post.
		local lantern = CFrame.new(side * 7.3, 7.6, FRONT - 1.2)
		box(ctx, lantern * CFrame.new(-side * 0.6, 1.2, 0), Vector3.new(1.3, 0.15, 0.15), iron, Enum.Material.CorrodedMetal)
		box(ctx, lantern * CFrame.new(0, 0.6, 0), Vector3.new(0.1, 1, 0.1), iron, Enum.Material.CorrodedMetal)
		local glass = box(ctx, lantern, Vector3.new(0.8, 1.1, 0.8), ghost, Enum.Material.Neon, { Transparency = 0.2 })
		pulse(glass, 1.8, side)
		light(glass, ghost, 14, 1.3)
		-- Cobwebs in the upper corners of the gate.
		part(ctx, { Name = "Cobweb", Class = "WedgePart", Size = Vector3.new(0.05, 2.2, 2.2), At = CFrame.new(side * 4.6, 10, FRONT - 0.2) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(math.pi, 0, if side > 0 then 0 else math.pi), Color = Color3.fromRGB(230, 230, 230), Material = Enum.Material.SmoothPlastic, Transparency = 0.55 })
	end
	-- THE SKULL AND BONES over the gate.
	local skull = CREST * CFrame.new(0, 2.4, 0)
	for _, side in SIDES do
		local b = skull * CFrame.new(0, 0, 0.6) * CFrame.Angles(0, 0, math.rad(side * 45))
		box(ctx, b, Vector3.new(0.6, 6, 0.6), bone, Enum.Material.SmoothPlastic)
		for _, y in { -3, 3 } do
			for _, x in { -0.35, 0.35 } do
				ball(ctx, b * CFrame.new(x, y, 0), Vector3.new(0.9, 0.9, 0.9), bone, Enum.Material.SmoothPlastic)
			end
		end
	end
	ball(ctx, skull * CFrame.new(0, 0.6, 0), Vector3.new(3.4, 3.2, 3), bone, Enum.Material.SmoothPlastic)
	box(ctx, skull * CFrame.new(0, -1, -0.2), Vector3.new(2, 1.2, 1.8), bone, Enum.Material.SmoothPlastic)
	for _, x in { -0.75, 0.75 } do
		ball(ctx, skull * CFrame.new(x, 0.5, -1.2), Vector3.new(0.9, 1, 0.5), Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
		local pupil = ball(ctx, skull * CFrame.new(x, 0.5, -1.45), Vector3.new(0.35, 0.35, 0.2), ghost, Enum.Material.Neon)
		pulse(pupil, 2.2, x)
	end
	box(ctx, skull * CFrame.new(0, -0.25, -1.35), Vector3.new(0.4, 0.5, 0.2), Color3.fromRGB(15, 15, 15), Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		box(ctx, skull * CFrame.new(i * 0.32, -1.25, -1.12), Vector3.new(0.22, 0.4, 0.1), Color3.fromRGB(245, 240, 225), Enum.Material.SmoothPlastic)
	end
	-- Ghost wisps circling the vault.
	for i = 0, 3 do
		local wisp = ball(ctx, CFrame.new(10, 7, 0), Vector3.new(0.9, 0.9, 0.9), ghost, Enum.Material.Neon, { Transparency = 0.15 })
		orbit(wisp, (ctx.F * CFrame.new(0, 6 + i * 1.5, -3)).Position, 10 + i * 1.5, 0.25 + i * 0.07, i * 1.6)
		emitter(wisp, { Texture = SPARKLE, Color = ColorSequence.new(ghost), LightEmission = 1, Size = NumberSequence.new(0.6, 0), Lifetime = NumberRange.new(0.8, 1.2), Rate = 12, Speed = NumberRange.new(0, 0.3) })
		if i % 2 == 0 then
			light(wisp, ghost, 10, 0.9)
		end
	end
	-- The fog.
	local fog = anchor(ctx, CFrame.new(0, 0.8, -6), Vector3.new(30, 1, 36))
	emitter(fog, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(170, 210, 180)), Transparency = NumberSequence.new(0.82, 1), Size = NumberSequence.new(4, 8), Lifetime = NumberRange.new(5, 8), Rate = 4, Speed = NumberRange.new(0.2, 0.5), LightInfluence = 1 })
end

-- PIRATE'S COVE -------------------------------------------------------------------------------
Builders.pirate = function(ctx: Ctx)
	local wood, brass, lantern = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local iron = Color3.fromRGB(45, 45, 50)
	local rope = Color3.fromRGB(200, 170, 120)
	for _, side in SIDES do
		-- A cannon either side of the carpet, aimed at the plaza, a stack of shot beside it.
		local base = flank(side)
		box(ctx, base * CFrame.new(0, 0.9, 0.3), Vector3.new(1.8, 0.9, 2.6), wood:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.WoodPlanks, { CanCollide = true })
		for _, x in { -1, 1 } do
			for _, z in { -0.6, 1.1 } do
				part(ctx, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, 1.3, 1.3), At = base * CFrame.new(x * 1, 0.65, z), Color = wood, Material = Enum.Material.Wood })
			end
		end
		local barrel = base * CFrame.new(0, 1.85, -0.3) * CFrame.Angles(math.rad(10), 0, 0)
		part(ctx, { Name = "CannonBarrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.6, 1.1, 1.1), At = barrel * CFrame.Angles(0, math.rad(90), 0), Color = iron, Material = Enum.Material.Metal })
		part(ctx, { Name = "CannonMuzzle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 1.35, 1.35), At = barrel * CFrame.new(0, 0, -1.7) * CFrame.Angles(0, math.rad(90), 0), Color = iron, Material = Enum.Material.Metal })
		ball(ctx, barrel * CFrame.new(0, 0, 1.9), Vector3.new(0.8, 0.8, 0.8), iron, Enum.Material.Metal)
		for i, off in { { 1.6, 0.35, 1.3 }, { 2.3, 0.35, 1.3 }, { 1.95, 0.35, 0.7 }, { 1.95, 0.9, 1.1 } } do
			ball(ctx, base * CFrame.new(side * off[1], off[2], off[3] - 0.4 + i * 0.01), Vector3.new(0.65, 0.65, 0.65), iron, Enum.Material.Metal)
		end
		-- Lanterns on the gate posts.
		local hang = CFrame.new(side * 7.4, 8, FRONT - 1.2)
		box(ctx, hang * CFrame.new(-side * 0.6, 1.3, 0), Vector3.new(1.3, 0.2, 0.2), brass, Enum.Material.Metal)
		box(ctx, hang * CFrame.new(0, 0.75, 0), Vector3.new(0.9, 0.2, 0.9), brass, Enum.Material.Metal)
		local glass = box(ctx, hang, Vector3.new(0.7, 1, 0.7), lantern, Enum.Material.Neon, { Transparency = 0.15 })
		box(ctx, hang * CFrame.new(0, -0.6, 0), Vector3.new(0.9, 0.2, 0.9), brass, Enum.Material.Metal)
		light(glass, lantern, 16, 1.3)
		-- Rope along the front rails.
		part(ctx, { Name = "Rope", Shape = Enum.PartType.Cylinder, Size = Vector3.new(7.6, 0.35, 0.35), At = CFrame.new(side * 10.75, 3.6, FRONT), Color = rope, Material = Enum.Material.Fabric })
	end
	-- The treasure chest spilling gold, just inside the gate.
	local chest = CFrame.new(-13, 0, -19) * CFrame.Angles(0, math.rad(30), 0)
	box(ctx, chest * CFrame.new(0, 0.8, 0), Vector3.new(2.6, 1.6, 1.7), Color3.fromRGB(110, 70, 40), Enum.Material.WoodPlanks, { CanCollide = true })
	for _, x in { -1.1, 1.1 } do
		box(ctx, chest * CFrame.new(x, 0.8, 0), Vector3.new(0.2, 1.65, 1.75), brass, Enum.Material.Metal)
	end
	box(ctx, chest * CFrame.new(0, 2, 1.1) * CFrame.Angles(math.rad(-60), 0, 0), Vector3.new(2.6, 0.3, 1.7), Color3.fromRGB(110, 70, 40), Enum.Material.WoodPlanks)
	local gold = Color3.fromRGB(255, 200, 60)
	for i = 0, 13 do
		local a = i * 2.4
		local r = (i % 4) * 0.35
		cyl(ctx, chest * CFrame.new(math.cos(a) * r, 1.65 + (i % 3) * 0.12, math.sin(a) * r * 0.6) * CFrame.Angles(math.rad(i * 9), 0, math.rad(i * 7)), 0.08, 0.5, gold, Enum.Material.Metal, { Reflectance = 0.3 })
	end
	for i = 0, 9 do
		cyl(ctx, chest * CFrame.new(1.3 + (i % 3) * 0.4, 0.05 + (i // 3) * 0.08, -1 - (i % 4) * 0.3), 0.08, 0.5, gold, Enum.Material.Metal)
	end
	local sparkle = anchor(ctx, chest * CFrame.new(0, 2, 0))
	emitter(sparkle, { Texture = SPARKLE, Color = ColorSequence.new(gold), LightEmission = 1, Size = NumberSequence.new(0.4, 0), Lifetime = NumberRange.new(1, 1.6), Rate = 5, Speed = NumberRange.new(0.5, 1), SpreadAngle = Vector2.new(180, 180) })
	-- THE SHIP'S WHEEL over the gate.
	local wheel = CREST * CFrame.new(0, 2.8, 0)
	ring(ctx, wheel, 2.6, 16, 0.45, wood, Enum.Material.Wood)
	for i = 0, 3 do
		local a = i / 4 * math.pi
		box(ctx, wheel * CFrame.Angles(0, 0, a), Vector3.new(0.35, 7, 0.35), wood, Enum.Material.Wood)
		for _, y in { -3.6, 3.6 } do
			ball(ctx, wheel * CFrame.Angles(0, 0, a) * CFrame.new(0, y, 0), Vector3.new(0.6, 0.9, 0.6), wood, Enum.Material.Wood)
		end
	end
	disc(ctx, wheel * CFrame.new(0, 0, -0.1), 0.6, 1.4, brass, Enum.Material.Metal, { Reflectance = 0.2 })
	-- The mast with the Jolly Roger at the back-left corner.
	local mast = CFrame.new(-16, 0, BACK + 1)
	cyl(ctx, mast * CFrame.new(0, 11, 0), 22, 0.9, wood, Enum.Material.Wood)
	box(ctx, mast * CFrame.new(0, 17, 0), Vector3.new(0.5, 0.5, 8), wood, Enum.Material.Wood)
	cyl(ctx, mast * CFrame.new(0, 19.5, 0), 1.2, 2.4, wood, Enum.Material.WoodPlanks)
	box(ctx, mast * CFrame.new(0, 20.3, -2.2) * CFrame.Angles(0, math.rad(90), 0), Vector3.new(4, 2.6, 0.1), Color3.fromRGB(20, 20, 22), Enum.Material.Fabric)
	ball(ctx, mast * CFrame.new(0.1, 20.6, -2.2), Vector3.new(0.9, 0.8, 0.8), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	for _, a in { 35, -35 } do
		box(ctx, mast * CFrame.new(0.08, 19.8, -2.2) * CFrame.Angles(math.rad(a), 0, 0), Vector3.new(0.1, 0.2, 2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	end
	-- Barrels at the back-right corner.
	Props.Barrel(ctx.Folder, ctx.F * CFrame.new(16.2, 0, BACK))
	Props.Barrel(ctx.Folder, ctx.F * CFrame.new(16.4, 0, BACK - 3))
	Props.Barrel(ctx.Folder, ctx.F * CFrame.new(16.3, 3, BACK - 1.5))
end

-- DRAGON'S HOARD ------------------------------------------------------------------------------
Builders.dragon = function(ctx: Ctx)
	local obsidian, gold, fireColor = ctx.P.Wall, ctx.P.Trim, ctx.P.Glow
	local scale = Color3.fromRGB(110, 20, 26)
	local scaleDark = Color3.fromRGB(70, 12, 18)
	local horn = Color3.fromRGB(235, 220, 190)
	-- THE DRAGON'S HEAD over the gate, jaws open, breathing fire at the plaza.
	local head = CREST * CFrame.new(0, 3.4, -1.8)
	box(ctx, head, Vector3.new(4.2, 3.2, 4.4), scale, Enum.Material.Slate)
	box(ctx, head * CFrame.new(0, 1.7, 0.4), Vector3.new(3.6, 0.6, 3.6), scaleDark, Enum.Material.Slate)
	box(ctx, head * CFrame.new(0, 0.3, -3.6), Vector3.new(3, 1.8, 3.4), scale, Enum.Material.Slate) -- snout
	box(ctx, head * CFrame.new(0, 1.3, -3.4), Vector3.new(2.6, 0.5, 2.8), scaleDark, Enum.Material.Slate)
	for _, x in { -0.7, 0.7 } do
		box(ctx, head * CFrame.new(x, 1.1, -5.25), Vector3.new(0.45, 0.3, 0.1), Color3.fromRGB(20, 8, 8), Enum.Material.Slate) -- nostrils
	end
	local jaw = head * CFrame.new(0, -1.7, -2.2) * CFrame.Angles(math.rad(26), 0, 0)
	box(ctx, jaw * CFrame.new(0, 0, -1.2), Vector3.new(2.8, 0.9, 4.2), scaleDark, Enum.Material.Slate)
	-- The fire in its throat, seen through the open jaws.
	local throat = box(ctx, head * CFrame.new(0, -1.05, -3.2), Vector3.new(2.2, 0.8, 3.2), fireColor, Enum.Material.Neon)
	pulse(throat, 1.6)
	for _, x in { -1.2, 1.2 } do
		part(ctx, { Name = "Fang", Class = "WedgePart", Size = Vector3.new(0.45, 1.4, 0.45), At = head * CFrame.new(x, -1.2, -5.05) * CFrame.Angles(math.pi, 0, 0), Color = horn, Material = Enum.Material.SmoothPlastic })
	end
	for i = 0, 4 do
		local z = -3 + i * 0.9
		for _, x in { -1.15, 1.15 } do
			part(ctx, { Name = "Tooth", Class = "WedgePart", Size = Vector3.new(0.3, 0.6, 0.3), At = head * CFrame.new(x, -0.85, z - 1.3) * CFrame.Angles(math.pi, 0, 0), Color = horn, Material = Enum.Material.SmoothPlastic })
			part(ctx, { Name = "Tooth", Class = "WedgePart", Size = Vector3.new(0.28, 0.5, 0.28), At = jaw * CFrame.new(x * 0.9, 0.65, z - 0.4), Color = horn, Material = Enum.Material.SmoothPlastic })
		end
	end
	for _, side in SIDES do
		local eye = box(ctx, head * CFrame.new(side * 1.5, 1.05, -2.25), Vector3.new(0.7, 0.4, 0.2), Color3.fromRGB(255, 200, 40), Enum.Material.Neon)
		pulse(eye, 0.6, side)
		box(ctx, head * CFrame.new(side * 1.55, 1.45, -2.1) * CFrame.Angles(0, 0, math.rad(side * -18)), Vector3.new(1.2, 0.35, 0.8), scaleDark, Enum.Material.Slate) -- brow
		-- Horns sweeping back.
		for j, spec in { { 1.6, 2.2, 3.2, 35 }, { 1.9, 1.2, 2.4, 55 } } do
			part(ctx, { Name = "Horn", Class = "WedgePart", Size = Vector3.new(0.7, spec[3], 1), At = head * CFrame.new(side * spec[1], spec[2], 1.6 + j * 0.4) * CFrame.Angles(math.rad(-spec[4]), 0, math.rad(side * -18)), Color = horn, Material = Enum.Material.SmoothPlastic })
		end
		-- Frills along the jaw.
		for j = 0, 2 do
			part(ctx, { Name = "Frill", Class = "WedgePart", Size = Vector3.new(0.15, 1.3 - j * 0.25, 1), At = head * CFrame.new(side * 2.15, -0.3 - j * 0.5, 0.8 + j * 0.4) * CFrame.Angles(0, math.rad(side * 20), 0), Color = gold, Material = Enum.Material.Foil })
		end
		-- WINGS spread either side of the head over the gate.
		local shoulder = head * CFrame.new(side * 2.2, 0.4, 2)
		local tipPoints = { CFrame.new(side * 12, 6.5, 1.5), CFrame.new(side * 13.5, 1.5, 2), CFrame.new(side * 10, -3.5, 2) }
		for k, tip in tipPoints do
			local a = (shoulder).Position
			local b = (head * tip).Position
			box(ctx, CFrame.lookAt((a + b) / 2, b), Vector3.new(0.35, 0.35, (b - a).Magnitude), scaleDark, Enum.Material.Slate)
			if k < #tipPoints then
				-- The membrane between two finger bones.
				triangle(ctx, a, b, (head * tipPoints[k + 1]).Position, 0.1, { Color = Color3.fromRGB(150, 30, 30), Material = Enum.Material.Fabric, Transparency = 0.15 })
			end
		end
		-- Gold hoards either side of the carpet.
		local base = flank(side)
		for i = 0, 17 do
			local ring2 = i // 6
			local a = (i % 6) / 6 * 2 * math.pi + ring2
			local r = 1.3 - ring2 * 0.45
			cyl(ctx, base * CFrame.new(math.cos(a) * r, 0.25 + ring2 * 0.55, math.sin(a) * r) * CFrame.Angles(math.rad((i * 37) % 30 - 15), 0, math.rad((i * 53) % 30 - 15)), 0.12, 0.8, gold, Enum.Material.Foil, { Reflectance = 0.3 })
		end
		ball(ctx, base * CFrame.new(0, 0.6, 0), Vector3.new(2.8, 1.4, 2.8), gold, Enum.Material.Foil, { Reflectance = 0.25, CanCollide = true })
		gem(ctx, base * CFrame.new(0.3, 1.9, -0.2), 0.7, Color3.fromRGB(230, 30, 60), nil)
		gem(ctx, base * CFrame.new(-0.6, 1.5, 0.5), 0.55, Color3.fromRGB(40, 200, 110), nil)
		local glint = anchor(ctx, base * CFrame.new(0, 1.5, 0))
		emitter(glint, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 220, 120)), LightEmission = 1, Size = NumberSequence.new(0.45, 0), Lifetime = NumberRange.new(0.8, 1.4), Rate = 6, Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180) })
		-- Claws gripping the plaque's ends.
		for j = 0, 2 do
			part(ctx, { Name = "Claw", Class = "WedgePart", Size = Vector3.new(0.35, 1.3, 0.6), At = CFrame.new(side * (7.6 + j * 0.05), 12.6 - j * 0.1, FRONT - 0.3 - j * 0.55) * CFrame.Angles(0, 0, math.rad(side * 150)), Color = horn, Material = Enum.Material.SmoothPlastic })
		end
		-- Banners on the gate posts.
		local banner = CFrame.new(side * 6, 6.2, FRONT - 1.15)
		box(ctx, banner, Vector3.new(1.8, 6.4, 0.12), Color3.fromRGB(140, 14, 22), Enum.Material.Fabric)
		box(ctx, banner * CFrame.new(0, 3.25, 0), Vector3.new(2.2, 0.3, 0.3), gold, Enum.Material.Foil)
		gem(ctx, banner * CFrame.new(0, 0.8, -0.2), 0.8, gold, fireColor)
		-- Obsidian spires at the back corners.
		local corner = CFrame.new(side * 15.8, 0, BACK + 0.6)
		box(ctx, corner * CFrame.new(0, 4, 0), Vector3.new(1.6, 8, 1.6), obsidian, Enum.Material.Glass, { Reflectance = 0.2 })
		spike(ctx, corner * CFrame.new(0, 8, 0), 1.6, 3, gold, Enum.Material.Foil)
	end
	-- Fire in its throat, flames and embers pouring out.
	local mouth = anchor(ctx, head * CFrame.new(0, -0.6, -4.2))
	local fire = Instance.new("Fire")
	fire.Size = 5
	fire.Heat = 0
	fire.Color = Color3.fromRGB(255, 110, 30)
	fire.SecondaryColor = Color3.fromRGB(255, 230, 100)
	fire.Parent = mouth
	emitter(mouth, { Texture = FIRE, Color = ColorSequence.new(Color3.fromRGB(255, 220, 90), Color3.fromRGB(255, 60, 20)), LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 3) }), Transparency = NumberSequence.new(0.1, 1), Lifetime = NumberRange.new(0.5, 0.9), Rate = 30, Speed = NumberRange.new(8, 12), SpreadAngle = Vector2.new(12, 12), EmissionDirection = Enum.NormalId.Front, Acceleration = Vector3.new(0, 3, 0) })
	light(mouth, fireColor, 24, 2)
	local nose = anchor(ctx, head * CFrame.new(0, 1.2, -5.4))
	emitter(nose, { Texture = SMOKE, Color = ColorSequence.new(Color3.fromRGB(80, 70, 70)), Transparency = NumberSequence.new(0.6, 1), Size = NumberSequence.new(0.5, 2), Lifetime = NumberRange.new(1.5, 2.5), Rate = 3, Speed = NumberRange.new(1, 2), EmissionDirection = Enum.NormalId.Top, LightInfluence = 1 })
	skyEmitter(ctx, 6, { Texture = SPARKLE, Color = ColorSequence.new(Color3.fromRGB(255, 160, 60)), LightEmission = 1, Size = NumberSequence.new(0.3, 0), Lifetime = NumberRange.new(3, 5), Rate = 8, Speed = NumberRange.new(1, 2.5), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40) })
end

-- DIAMOND ROYALE (the flex) -------------------------------------------------------------------
Builders.diamond = function(ctx: Ctx)
	local white, glow = ctx.P.Trim, ctx.P.Glow
	local diamondColor = Color3.fromRGB(215, 245, 255)
	local rainbow = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
		ColorSequenceKeypoint.new(0.25, Color3.fromRGB(150, 220, 255)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.75, Color3.fromRGB(170, 255, 220)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 170, 255)),
	})
	-- THE DIAMOND: huge, spinning, floating over the gate, smaller diamonds orbiting it.
	local gemAt = CREST * CFrame.new(0, 7.5, -1.5)
	local big = brilliant(ctx, gemAt, 4.2, diamondColor, Color3.fromRGB(235, 250, 255), 0.5, 0.8)
	light(big, Color3.fromRGB(210, 240, 255), 40, 2.2)
	emitter(big, { Texture = SPARKLE, Color = rainbow, LightEmission = 1, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 1.2), NumberSequenceKeypoint.new(1, 0) }), Lifetime = NumberRange.new(1.5, 2.5), Rate = 22, Speed = NumberRange.new(2, 5), SpreadAngle = Vector2.new(180, 180) })
	local center = (ctx.F * gemAt).Position
	for i = 0, 5 do
		local small = gem(ctx, gemAt * CFrame.new(7, 0, 0), 1.3, diamondColor, nil, { Transparency = 0.1, Reflectance = 0.5 })
		orbit(small, center + Vector3.new(0, math.sin(i) * 1.5, 0), 7, 0.55, i / 6 * 2 * math.pi)
		small:SetAttribute("Spin", 1.5)
	end
	-- A tiara of diamond spikes along the plaque.
	for i = -3, 3 do
		local h = 2.6 - math.abs(i) * 0.5
		spike(ctx, CFrame.new(i * 2.1, 14.3, FRONT - 0.6), 0.9, h, diamondColor, Enum.Material.Glass, { Transparency = 0.1, Reflectance = 0.4 })
	end
	-- SKY BEAMS from the four corners - you can see this vault from anywhere in the District.
	for _, spec in { { -15, BACK, -40, 60 }, { 15, BACK, 40, 60 }, { -15, FRONT, -30, -40 }, { 15, FRONT, 30, -40 } } do
		lightBeam(ctx, Vector3.new(spec[1], 1, spec[2]), Vector3.new(spec[1] + spec[3], 260, spec[2] + spec[4]), {
			Color = ColorSequence.new(Color3.fromRGB(230, 250, 255), Color3.fromRGB(170, 220, 255)),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(0.6, 0.7), NumberSequenceKeypoint.new(1, 1) }),
			LightEmission = 1,
			Width0 = 2.5,
			Width1 = 9,
			Segments = 1,
		})
	end
	-- Diamond pillars either side of the carpet.
	for _, side in SIDES do
		local base = flank(side)
		cyl(ctx, base * CFrame.new(0, 0.4, 0), 0.8, 2.8, white, Enum.Material.Marble, { CanCollide = true })
		cyl(ctx, base * CFrame.new(0, 0.85, 0), 0.1, 2.4, glow, Enum.Material.Neon)
		box(ctx, base * CFrame.new(0, 3.8, 0) * CFrame.Angles(0, math.rad(45), 0), Vector3.new(1.4, 6, 1.4), diamondColor, Enum.Material.Glass, { Transparency = 0.15, Reflectance = 0.4, CanCollide = true })
		local core = box(ctx, base * CFrame.new(0, 3.8, 0), Vector3.new(0.5, 5.6, 0.5), Color3.fromRGB(235, 250, 255), Enum.Material.Neon)
		pulse(core, 1, side)
		local top = gem(ctx, base * CFrame.new(0, 8, 0), 1.8, diamondColor, Color3.fromRGB(235, 250, 255), { Reflectance = 0.45 })
		top:SetAttribute("Spin", 0.9 * side)
		float(top, 0.3, 1)
		light(core, Color3.fromRGB(210, 240, 255), 14, 1.3)
		-- Crystal clusters crowning the back corners.
		local corner = CFrame.new(side * 15.8, 0, BACK + 0.6)
		for j, h in { 9, 6.5, 5 } do
			local tilt = CFrame.Angles(math.rad((j - 2) * 12), j, math.rad(side * (j - 1) * 8))
			box(ctx, corner * tilt * CFrame.new(0, h / 2, 0), Vector3.new(1.3, h, 1.3), diamondColor, Enum.Material.Glass, { Transparency = 0.12, Reflectance = 0.4 })
			spike(ctx, corner * tilt * CFrame.new(0, h, 0), 1.3, 1.6, diamondColor, Enum.Material.Glass, { Transparency = 0.12, Reflectance = 0.4 })
		end
	end
	-- Diamond dust edging down the carpet, glitter everywhere.
	for _, x in { -1.95, 1.95 } do
		box(ctx, CFrame.new(x, 0.1, 0), Vector3.new(0.2, 0.06, 42), Color3.fromRGB(235, 250, 255), Enum.Material.Neon)
	end
	skyEmitter(ctx, 22, { Texture = SPARKLE, Color = rainbow, LightEmission = 1, Size = NumberSequence.new(0.5, 0), Lifetime = NumberRange.new(4, 6), Rate = 24, Speed = NumberRange.new(0.5, 2), SpreadAngle = Vector2.new(180, 180) })
	-- The name in lights, readable from across the District.
	local sign = anchor(ctx, gemAt * CFrame.new(0, 6.5, 0))
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(26, 4)
	gui.MaxDistance = 700
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(225, 248, 255)
	label.Text = ("💎 %s'S DIAMOND VAULT"):format(ctx.Owner:upper())
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(40, 90, 160)
	stroke.Thickness = 3
	stroke.Parent = label
	local gradient = Instance.new("UIGradient")
	gradient.Color = rainbow
	gradient.Parent = label
	CollectionService:AddTag(gradient, "RarityShimmer") -- (Controllers/Ambience slides it)
	label.Parent = gui
	gui.Parent = sign
end

-- Builds skin `skin`'s showpieces for a plot. `palette` = the skin's palette as Color3s.
function VaultSkinDecor.Build(skin, folder: Folder, floor: CFrame, palette: { [string]: Color3 }, owner: string)
	folder:ClearAllChildren()
	local builder = Builders[skin.Decor] or Builders.classic
	builder({ Folder = folder, F = floor, P = palette, Owner = owner, Rng = Random.new(#skin.Id * 7919) })
end

-- Converts a Config/VaultSkins palette to Color3s (materials stay names).
function VaultSkinDecor.Colors(palette): { [string]: Color3 }
	local out = {}
	for key, value in palette do
		if type(value) == "table" then
			out[key] = rgb(value)
		end
	end
	return out
end

VaultSkinDecor.Builders = Builders

return VaultSkinDecor
