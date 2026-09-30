-- One hand-built model per treasure: an EXAGGERATED cartoon of its name (a coin pouch
-- bursting with coins, a frog with huge bulging eyes, a cauldron bubbling over...).
-- TreasureVisual picks the builder by treasure Id (falls back to the generic Shape builders),
-- then adds rarity flair and mutation effects on top.
--
-- Every builder gets a kit `k` bound to the treasure's handle and scale. Positions are in
-- UNITS of the treasure's scale (1 unit = s studs), centred on the handle; keep models inside
-- roughly x/z -1.2..1.2 and y -0.9..1.4 so they sit on the ground and fit over a head.

local TreasureModels = {}

local rad = math.rad
local C = Color3.fromRGB

local GOLD = C(255, 200, 50)
local DARK = C(38, 30, 26)
local IRON = C(72, 72, 80)
local WHITE = C(250, 250, 250)
local BLACK = C(15, 15, 18)
local WOOD = C(120, 80, 45)

local M = Enum.Material

export type Kit = {
	s: number,
	handle: BasePart,
	main: Color3,
	accent: Color3,
	mat: Enum.Material,
	at: (x: number, y: number, z: number, rx: number?, ry: number?, rz: number?) -> CFrame,
	box: (sx: number, sy: number, sz: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> BasePart,
	ball: (sx: number, sy: number, sz: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> BasePart,
	cyl: (length: number, dia: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> BasePart,
	vcyl: (length: number, dia: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> BasePart,
	wedge: (sx: number, sy: number, sz: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> BasePart,
	torus: (radius: number, thick: number, n: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> (),
	cone: (height: number, dia: number, steps: number, cf: CFrame, color: Color3, mat: Enum.Material?, extra: any?) -> (),
	coin: (dia: number, cf: CFrame, color: Color3?) -> BasePart,
}

function TreasureModels.Kit(model: Model, handle: BasePart, s: number, main: Color3, accent: Color3, mat: Enum.Material): Kit
	local k = {} :: any
	k.s, k.main, k.accent, k.mat, k.handle = s, main, accent, mat, handle

	function k.at(x: number, y: number, z: number, rx: number?, ry: number?, rz: number?): CFrame
		return handle.CFrame * CFrame.new(x * s, y * s, z * s) * CFrame.Angles(rad(rx or 0), rad(ry or 0), rad(rz or 0))
	end

	local function make(className: string, shape: string?, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, extra): BasePart
		local p = Instance.new(className) :: BasePart
		if shape == "Ellipsoid" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere
			mesh.Parent = p
		elseif shape == "Cylinder" then
			(p :: Part).Shape = Enum.PartType.Cylinder
		end
		p.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
		p.CFrame = cf
		p.Color = color
		p.Material = material or M.SmoothPlastic
		if extra then
			p.Transparency = extra.T or 0
			p.Reflectance = extra.R or 0
		end
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.CastShadow = size.Magnitude > 3
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Massless = true
		p.Anchored = false
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		return p
	end

	function k.box(sx, sy, sz, cf, color, material, extra)
		return make("Part", nil, Vector3.new(sx, sy, sz) * s, cf, color, material, extra)
	end
	-- Ellipsoid (a real stretched sphere, unlike Ball-shaped parts).
	function k.ball(sx, sy, sz, cf, color, material, extra)
		return make("Part", "Ellipsoid", Vector3.new(sx, sy, sz) * s, cf, color, material, extra)
	end
	-- Cylinder along the CFrame's X axis.
	function k.cyl(length, dia, cf, color, material, extra)
		return make("Part", "Cylinder", Vector3.new(length, dia, dia) * s, cf, color, material, extra)
	end
	-- Cylinder along the CFrame's Y axis (upright).
	function k.vcyl(length, dia, cf, color, material, extra)
		return make("Part", "Cylinder", Vector3.new(length, dia, dia) * s, cf * CFrame.Angles(0, 0, rad(90)), color, material, extra)
	end
	function k.wedge(sx, sy, sz, cf, color, material, extra)
		return make("WedgePart", nil, Vector3.new(sx, sy, sz) * s, cf, color, material, extra)
	end
	-- Ring in the CFrame's XY plane (faces along Z), built from n short bricks.
	function k.torus(radius, thick, n, cf, color, material, extra)
		local segment = 2 * math.pi * radius / n * 1.12
		for i = 1, n do
			local a = (i - 0.5) / n * 2 * math.pi
			make("Part", nil, Vector3.new(segment, thick, thick) * s, cf * CFrame.Angles(0, 0, a) * CFrame.new(0, radius * s, 0), color, material, extra)
		end
	end
	-- Tapered spike/cone along the CFrame's Y axis: stacked cylinders narrowing to a tip.
	function k.cone(height, dia, steps, cf, color, material, extra)
		for i = 1, steps do
			local f = (i - 1) / steps
			local d = dia * (1 - f * 0.85)
			k.vcyl(height / steps * 1.05, d, cf * CFrame.new(0, (f + 0.5 / steps) * height * s, 0), color, material, extra)
		end
	end
	-- Flat coin lying in the CFrame's XZ plane.
	function k.coin(dia, cf, color)
		return k.vcyl(0.08, dia, cf, color or GOLD, M.Metal, { R = 0.25 })
	end
	return k :: Kit
end

local Models: { [string]: (Kit) -> () } = {}
TreasureModels.Builders = Models

-- SHARED PIECES ---------------------------------------------------------------------------

local function eyes(k: Kit, y: number, z: number, spread: number, size: number, pupil: Color3?)
	for _, x in { -spread, spread } do
		k.ball(size, size, size, k.at(x, y, z), WHITE, M.SmoothPlastic)
		k.ball(size * 0.45, size * 0.45, size * 0.3, k.at(x, y, z - size * 0.42), pupil or BLACK, M.SmoothPlastic)
	end
end

local function goblet(k: Kit, bowl: Color3, mat: Enum.Material, bowlDia: number, bowlH: number)
	k.vcyl(0.12, 0.95, k.at(0, -0.78, 0), bowl, mat, { R = 0.2 })
	k.vcyl(0.55, 0.16, k.at(0, -0.45, 0), bowl, mat, { R = 0.2 })
	k.ball(0.32, 0.22, 0.32, k.at(0, -0.2, 0), bowl, mat, { R = 0.2 })
	k.vcyl(bowlH, bowlDia, k.at(0, 0.1 + bowlH / 2, 0), bowl, mat, { R = 0.2 })
	k.torus(bowlDia / 2, 0.08, 12, k.at(0, 0.1 + bowlH, 0, 90, 0, 0), GOLD, M.Metal)
end

local function chest(k: Kit, wood: Color3, band: Color3)
	k.box(1.9, 0.9, 1.15, k.at(0, -0.45, 0), wood, M.WoodPlanks)
	for _, x in { -0.75, 0, 0.75 } do
		k.box(0.14, 0.94, 1.19, k.at(x, -0.45, 0), band, M.Metal)
	end
	-- Lid thrown open, loot bursting out.
	k.box(1.9, 0.12, 1.1, k.at(0, 0.35, 0.72, -70, 0, 0), wood, M.WoodPlanks)
	k.ball(1.7, 0.7, 1.0, k.at(0, 0.02, 0), GOLD, M.Metal, { R = 0.3 })
	k.box(0.3, 0.3, 0.14, k.at(0, -0.2, -0.6), GOLD, M.Metal)
end

local function coinsPile(k: Kit, y: number, n: number, spread: number)
	for i = 1, n do
		local a = i / n * 2 * math.pi
		k.coin(0.32, k.at(math.cos(a) * spread, y + (i % 3) * 0.06, math.sin(a) * spread, (i * 37) % 50 - 25, 0, (i * 53) % 50 - 25))
	end
end

-- A proper feather: quill up the middle, barbs fanning out on both sides and sweeping toward
-- the tip, widest a little above the middle, colour running from base to tip.
local function feather(k: Kit, vane: Color3, tip: Color3, quill: Color3, mat: Enum.Material)
	local frame = k.at(0.05, 0.2, 0, 0, 0, -16)
	k.vcyl(2.4, 0.08, frame * CFrame.new(0, -0.05 * k.s, 0), quill, M.SmoothPlastic)
	for i = 0, 6 do
		local t = i / 6
		local y = -0.5 + t * 1.6
		local w = math.sin(math.pi * (0.12 + 0.8 * t)) * 0.62 + 0.12
		local col = vane:Lerp(tip, t)
		for _, side in { -1, 1 } do
			k.ball(w, 0.46, 0.06, frame * CFrame.new(side * w * 0.45 * k.s, y * k.s, 0) * CFrame.Angles(0, 0, rad(side * -28)), col, mat)
		end
	end
	k.ball(0.26, 0.4, 0.06, frame * CFrame.new(0, 1.15 * k.s, 0), tip, mat)
end

-- Pointed shard (icicle, horn tip...): a thin box with a pyramid-ish cap, along the CFrame's Y.
local function shard(k: Kit, cf: CFrame, width: number, height: number, color: Color3, mat: Enum.Material, extra)
	k.box(width, height, width, cf * CFrame.new(0, height * k.s / 2, 0), color, mat, extra)
	k.wedge(width, width * 1.2, width / 2, cf * CFrame.new(0, (height + width * 0.6) * k.s, -width * 0.25 * k.s), color, mat, extra)
	k.wedge(width, width * 1.2, width / 2, cf * CFrame.new(0, (height + width * 0.6) * k.s, width * 0.25 * k.s) * CFrame.Angles(0, math.pi, 0), color, mat, extra)
end

-- A curved horn: a chain of shrinking ellipsoids bending outward.
local function horn(k: Kit, x: number, y: number, z: number, side: number, length: number, dia: number, color: Color3, mat: Enum.Material)
	for i = 0, 5 do
		local t = i / 5
		local d = dia * (1 - t * 0.75)
		local px = x + side * (t * 0.4 + t * t * 0.35) * length
		local py = y + t * length * 0.85
		k.ball(d, length * 0.4, d, k.at(px, py, z, 0, 0, side * -(15 + t * 50)), color, mat)
	end
end

local function crystal(k: Kit, x: number, z: number, height: number, width: number, tilt: number, color: Color3, mat: Enum.Material)
	local cf = k.at(x, -0.85, z, 0, 0, tilt) * CFrame.new(0, height * k.s / 2, 0)
	k.box(width, height, width, cf, color, mat, { T = if mat == M.Glass then 0.15 else 0 })
	k.wedge(width, width * 0.9, width * 0.5, cf * CFrame.new(0, (height / 2 + width * 0.45) * k.s, -width * 0.25 * k.s), color, mat)
	k.wedge(width, width * 0.9, width * 0.5, cf * CFrame.new(0, (height / 2 + width * 0.45) * k.s, width * 0.25 * k.s) * CFrame.Angles(0, math.pi, 0), color, mat)
end

local function heart(k: Kit, y: number, size: number, color: Color3, mat: Enum.Material, extra)
	k.ball(size * 0.6, size * 0.6, size * 0.46, k.at(-size * 0.2, y + size * 0.16, 0), color, mat, extra)
	k.ball(size * 0.6, size * 0.6, size * 0.46, k.at(size * 0.2, y + size * 0.16, 0), color, mat, extra)
	k.box(size * 0.54, size * 0.54, size * 0.4, k.at(0, y - size * 0.1, 0, 0, 0, 45), color, mat, extra)
end

-- THE WILDS -------------------------------------------------------------------------------

Models.coin_pouch = function(k)
	k.ball(1.5, 1.25, 1.5, k.at(0, -0.25, 0), k.main, M.Fabric)
	k.ball(0.95, 0.5, 0.95, k.at(0, 0.3, 0), k.main:Lerp(DARK, 0.15), M.Fabric)
	k.vcyl(0.16, 0.6, k.at(0, 0.5, 0), C(210, 170, 90), M.Fabric)
	k.ball(0.28, 0.28, 0.28, k.at(0.18, 0.62, -0.1), C(210, 170, 90), M.Fabric)
	k.ball(0.75, 0.4, 0.75, k.at(0, 0.7, 0), GOLD, M.Metal, { R = 0.3 })
	coinsPile(k, 0.8, 5, 0.25)
	k.coin(0.4, k.at(0.7, -0.35, -0.3, 0, 0, 70))
	k.coin(0.34, k.at(-0.55, -0.8, -0.55, 10, 0, 5))
	k.box(0.26, 0.26, 0.05, k.at(0, -0.1, -0.74), GOLD, M.Neon)
end

Models.jade_frog = function(k)
	local jade = k.main
	k.ball(1.5, 1.0, 1.4, k.at(0, -0.4, 0.1), jade, M.Glass, { T = 0.05 })
	k.ball(1.3, 0.85, 1.1, k.at(0, 0.25, -0.2), jade, M.Glass, { T = 0.05 })
	eyes(k, 0.72, -0.25, 0.38, 0.5)
	k.ball(0.8, 0.1, 0.3, k.at(0, 0.1, -0.62), DARK, M.SmoothPlastic)
	for _, x in { -1, 1 } do
		k.ball(0.55, 0.35, 0.8, k.at(x * 0.7, -0.72, 0.35), jade, M.Glass)
		k.ball(0.3, 0.45, 0.3, k.at(x * 0.42, -0.6, -0.55), jade, M.Glass)
		k.ball(0.18, 0.12, 0.08, k.at(x * 0.42, 0.22, -0.66), C(240, 130, 150), M.SmoothPlastic)
	end
end

Models.silver_goblet = function(k)
	goblet(k, k.main, M.Metal, 1.35, 0.95)
	k.ball(0.3, 0.3, 0.2, k.at(0, 0.55, -0.68), C(80, 160, 255), M.Glass)
	for _, x in { -1, 1 } do
		k.torus(0.25, 0.07, 6, k.at(x * 0.78, 0.55, 0, 0, 90, 0), k.main, M.Metal)
	end
end

Models.amber_beetle = function(k)
	k.ball(1.4, 1.8, 1.3, k.at(0, 0.05, 0), k.main, M.Glass, { T = 0.35 })
	k.ball(0.7, 0.5, 0.95, k.at(0, 0.05, 0.05), C(60, 30, 15), M.SmoothPlastic)
	k.ball(0.35, 0.3, 0.35, k.at(0, 0.1, -0.5), C(40, 20, 10), M.SmoothPlastic)
	for i = -1, 1 do
		for _, side in { -1, 1 } do
			k.box(0.45, 0.05, 0.05, k.at(side * 0.45, -0.05, i * 0.25, 0, side * 20, side * -25), C(40, 20, 10))
		end
	end
	k.ball(0.35, 0.35, 0.35, k.at(-0.3, 0.55, -0.45), C(255, 230, 160), M.Neon, { T = 0.4 })
end

Models.wind_chime = function(k)
	k.vcyl(0.14, 1.3, k.at(0, 0.95, 0), WOOD, M.Wood)
	k.box(0.05, 0.4, 0.05, k.at(0, 1.2, 0), DARK)
	k.torus(0.12, 0.05, 6, k.at(0, 1.4, 0), IRON, M.Metal)
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		local length = 0.7 + (i % 3) * 0.3
		k.box(0.03, 0.2, 0.03, k.at(math.cos(a) * 0.45, 0.8, math.sin(a) * 0.45), DARK)
		k.vcyl(length, 0.16, k.at(math.cos(a) * 0.45, 0.7 - length / 2, math.sin(a) * 0.45), k.main, M.Glass, { T = 0.1 })
	end
	k.ball(0.3, 0.3, 0.3, k.at(0, 0.2, 0), GOLD, M.Metal)
	k.box(0.5, 0.35, 0.03, k.at(0, -0.35, 0), C(255, 240, 200), M.Fabric)
end

Models.ivory_horn = function(k)
	for i = 0, 6 do
		local t = i / 6
		local a = rad(-60 + t * 140)
		k.cyl(0.42, 0.25 + t * 0.55, k.at(math.cos(a) * 0.8 - 0.1, math.sin(a) * 0.8 + 0.1, 0, 0, 0, math.deg(a) + 90), k.main, M.Marble)
		if i == 2 or i == 5 then
			k.cyl(0.1, 0.36 + t * 0.6, k.at(math.cos(a) * 0.8 - 0.1, math.sin(a) * 0.8 + 0.1, 0, 0, 0, math.deg(a) + 90), GOLD, M.Metal)
		end
	end
	k.ball(0.25, 0.25, 0.25, k.at(0.3, -0.62, 0), GOLD, M.Metal)
	k.vcyl(0.12, 0.95, k.at(-0.45, 0.95, 0, 0, 0, 55), GOLD:Lerp(WHITE, 0.2), M.Neon, { T = 0.4 })
end

Models.emerald_scarab = function(k)
	local gem = k.main
	k.ball(1.4, 0.8, 1.8, k.at(0, -0.3, 0.1), gem, M.Glass, { T = 0.05 })
	k.box(0.06, 0.1, 1.5, k.at(0, 0.1, 0.15), GOLD, M.Metal)
	k.ball(0.8, 0.55, 0.6, k.at(0, -0.3, -0.85), gem:Lerp(DARK, 0.3), M.Glass)
	for i = -1, 1 do
		for _, side in { -1, 1 } do
			k.box(0.7, 0.08, 0.08, k.at(side * 0.85, -0.6, i * 0.45, 0, side * 25, side * 30), GOLD, M.Metal)
		end
	end
	k.cyl(0.55, 0.08, k.at(-0.2, -0.1, -1.15, 0, 60, 0), GOLD, M.Metal)
	k.cyl(0.55, 0.08, k.at(0.2, -0.1, -1.15, 0, -60, 0), GOLD, M.Metal)
	k.ball(0.3, 0.12, 0.5, k.at(-0.3, 0.05, 0.2), C(200, 255, 220), M.Neon, { T = 0.4 })
end

Models.explorers_compass = function(k)
	k.cyl(0.3, 1.9, k.at(0, 0, 0, 0, 90, 0), k.main, M.Metal, { R = 0.3 })
	k.cyl(0.32, 1.55, k.at(0, 0, -0.01, 0, 90, 0), C(245, 235, 210), M.SmoothPlastic)
	k.wedge(0.12, 0.7, 0.04, k.at(0, 0.35, -0.18), C(230, 50, 50), M.SmoothPlastic)
	k.wedge(0.12, 0.7, 0.04, k.at(0, -0.35, -0.18, 0, 0, 180), WHITE, M.SmoothPlastic)
	k.ball(0.18, 0.18, 0.12, k.at(0, 0, -0.2), GOLD, M.Metal)
	k.box(0.14, 0.2, 0.05, k.at(0, 0.62, -0.18), C(230, 50, 50), M.Neon)
	k.torus(0.2, 0.08, 8, k.at(0, 1.05, 0), k.main, M.Metal)
	-- Lid flipped open behind.
	k.cyl(0.14, 1.9, k.at(0, 0.3, 0.55, 0, 90, 0) * CFrame.Angles(0, 0, rad(-55)), k.main, M.Metal)
	k.cyl(0.34, 1.6, k.at(0, 0, -0.02, 0, 90, 0), C(200, 240, 255), M.Glass, { T = 0.7 })
end

Models.oak_kings_chest = function(k)
	chest(k, k.main, C(60, 90, 40))
	coinsPile(k, 0.35, 7, 0.55)
	-- A little crown of oak leaves on the lid, emeralds in the loot.
	for i = 1, 5 do
		local x = -0.6 + (i - 1) * 0.3
		k.ball(0.28, 0.14, 0.4, k.at(x, 0.75, 0.9, -70, 0, (i - 3) * 12), C(90, 170, 60), M.Grass)
	end
	k.box(0.3, 0.3, 0.3, k.at(-0.4, 0.35, 0, 45, 0, 45), C(60, 220, 110), M.Glass)
	k.box(0.26, 0.26, 0.26, k.at(0.45, 0.3, 0.1, 45, 0, 45), C(80, 200, 255), M.Glass)
	k.ball(0.4, 0.4, 0.4, k.at(0, 0.45, -0.1), GOLD, M.Neon, { T = 0.35 })
end

-- SHIPWRECK COAST ---------------------------------------------------------------------------

Models.rusty_compass = function(k)
	local rust = k.main
	k.cyl(0.3, 1.7, k.at(0, 0, 0, 0, 90, 0), rust, M.CorrodedMetal)
	k.cyl(0.32, 1.35, k.at(0, 0, -0.01, 0, 90, 0), C(215, 200, 170), M.SmoothPlastic)
	k.wedge(0.12, 0.6, 0.04, k.at(0.1, 0.25, -0.18, 0, 0, -25), C(200, 60, 40))
	k.wedge(0.12, 0.6, 0.04, k.at(-0.1, -0.25, -0.18, 0, 0, 155), C(230, 230, 220))
	k.box(0.9, 0.04, 0.04, k.at(0.1, 0.1, -0.19, 0, 0, 35), DARK) -- crack
	k.torus(0.18, 0.08, 7, k.at(0, 0.95, 0), rust, M.CorrodedMetal)
	k.ball(0.35, 0.2, 0.2, k.at(0.55, -0.55, -0.1), C(120, 70, 40), M.CorrodedMetal)
end

Models.bronze_bell = function(k)
	local bronze = k.main
	k.vcyl(0.14, 1.9, k.at(0, -0.75, 0), bronze, M.Metal, { R = 0.25 })
	for i = 0, 9 do
		local t = i / 9
		local d = 1.75 - math.sqrt(t) * 0.85
		k.vcyl(0.18, d, k.at(0, -0.65 + t * 1.45, 0), bronze, M.Metal, { R = 0.25 })
	end
	k.ball(0.95, 0.5, 0.95, k.at(0, 0.8, 0), bronze, M.Metal, { R = 0.25 })
	k.torus(0.22, 0.09, 8, k.at(0, 1.2, 0), bronze:Lerp(DARK, 0.3), M.Metal)
	k.ball(0.4, 0.4, 0.4, k.at(0, -0.85, 0), DARK, M.Metal)
	k.torus(0.85, 0.07, 14, k.at(0, -0.55, 0, 90, 0, 0), GOLD, M.Metal)
end

Models.message_bottle = function(k)
	local glass = k.main
	k.cyl(1.5, 0.95, k.at(0, -0.35, 0, 0, 20, 12), glass, M.Glass, { T = 0.45 })
	k.cyl(0.55, 0.45, k.at(0.95, -0.14, -0.34, 0, 20, 12), glass, M.Glass, { T = 0.45 })
	k.cyl(0.25, 0.4, k.at(1.25, -0.08, -0.45, 0, 20, 12), C(170, 120, 70), M.Wood)
	k.cyl(1.0, 0.45, k.at(-0.05, -0.36, 0, 0, 20, 12), C(245, 230, 190), M.Fabric)
	k.box(0.08, 0.5, 0.08, k.at(-0.05, -0.36, 0, 0, 20, 12), C(200, 40, 40), M.Fabric)
	k.ball(0.25, 0.25, 0.25, k.at(-0.6, 0.1, -0.3), C(200, 255, 240), M.Neon, { T = 0.5 })
end

Models.captains_spyglass = function(k)
	local brass = k.main
	local base = k.at(0, 0, 0, 0, 0, 22)
	k.cyl(0.95, 0.75, base * CFrame.new(-0.7 * k.s, 0, 0), C(90, 50, 30), M.Fabric)
	k.cyl(0.8, 0.6, base * CFrame.new(0.1 * k.s, 0, 0), brass, M.Metal, { R = 0.25 })
	k.cyl(0.7, 0.45, base * CFrame.new(0.8 * k.s, 0, 0), brass, M.Metal, { R = 0.25 })
	for _, x in { -1.15, -0.25, 0.5 } do
		k.cyl(0.1, 0.82 - (x + 1.15) * 0.18, base * CFrame.new(x * k.s, 0, 0), GOLD, M.Metal)
	end
	k.cyl(0.12, 0.7, base * CFrame.new(-1.22 * k.s, 0, 0), C(150, 220, 255), M.Neon)
	k.cyl(0.1, 0.36, base * CFrame.new(1.18 * k.s, 0, 0), C(40, 40, 50), M.Glass)
end

Models.ruby_ring = function(k)
	k.torus(0.75, 0.22, 16, k.at(0, -0.15, 0), GOLD, M.Metal, { R = 0.35 })
	for _, x in { -0.25, 0.25 } do
		k.box(0.1, 0.4, 0.1, k.at(x, 0.72, 0, 0, 0, x * -60), GOLD, M.Metal)
	end
	k.box(0.75, 0.75, 0.75, k.at(0, 1.02, 0, 45, 0, 45), k.main, M.Glass, { T = 0.1 })
	k.ball(0.55, 0.55, 0.55, k.at(0, 1.02, 0), k.main:Lerp(WHITE, 0.3), M.Neon, { T = 0.35 })
end

Models.pearl_necklace = function(k)
	for i = 1, 14 do
		local a = i / 14 * 2 * math.pi
		local droop = math.max(0, -math.sin(a)) * 0.3
		k.ball(0.26, 0.26, 0.26, k.at(math.cos(a) * 0.8, math.sin(a) * 0.55 - droop, math.sin(a * 2) * 0.1), k.main, M.Marble, { R = 0.15 })
	end
	k.box(0.14, 0.2, 0.1, k.at(0, 0.6, 0), GOLD, M.Metal)
	k.box(0.08, 0.3, 0.08, k.at(0, -0.95, 0), GOLD, M.Metal)
	k.ball(0.6, 0.6, 0.6, k.at(0, -0.72, 0), C(255, 240, 250), M.Marble, { R = 0.3 })
	k.ball(0.3, 0.3, 0.3, k.at(-0.12, -0.6, -0.2), WHITE, M.Neon, { T = 0.5 })
end

Models.pirate_chest = function(k)
	chest(k, k.main, IRON)
	-- Skull and crossbones on the front.
	k.ball(0.36, 0.34, 0.1, k.at(0, -0.35, -0.6), WHITE, M.SmoothPlastic)
	for _, rz in { 40, -40 } do
		k.box(0.62, 0.08, 0.05, k.at(0, -0.62, -0.6, 0, 0, rz), WHITE)
	end
	for _, x in { -0.08, 0.08 } do
		k.ball(0.08, 0.08, 0.05, k.at(x, -0.33, -0.66), BLACK)
	end
	coinsPile(k, 0.4, 6, 0.5)
	k.box(0.24, 0.24, 0.24, k.at(0.4, 0.4, 0, 45, 0, 45), C(220, 40, 60), M.Glass)
	k.cyl(0.9, 0.1, k.at(-0.2, 0.55, 0.2, 0, 30, 60), C(200, 200, 210), M.Metal, { R = 0.4 })
end

Models.storm_anchor = function(k)
	local iron = k.main
	k.box(0.26, 1.9, 0.26, k.at(0, 0.1, 0), iron, M.Metal)
	k.torus(0.25, 0.1, 8, k.at(0, 1.25, 0), iron, M.Metal)
	k.box(1.2, 0.16, 0.2, k.at(0, 0.85, 0), WOOD, M.Wood)
	for _, side in { -1, 1 } do
		k.box(0.9, 0.22, 0.22, k.at(side * 0.4, -0.72, 0, 0, 0, side * 25), iron, M.Metal)
		k.wedge(0.24, 0.5, 0.45, k.at(side * 0.85, -0.4, 0, 0, side * 90, 0), iron, M.Metal)
	end
	-- Lightning crackling up the shank.
	for i = 0, 2 do
		k.box(0.06, 0.45, 0.06, k.at((i % 2 - 0.5) * 0.25, -0.3 + i * 0.4, -0.18, 0, 0, (i % 2 - 0.5) * 60), C(170, 230, 255), M.Neon)
	end
end

Models.sapphire_trident = function(k)
	k.vcyl(2.5, 0.14, k.at(0, 0, 0), GOLD, M.Metal)
	k.box(1.0, 0.12, 0.12, k.at(0, 0.75, 0), GOLD, M.Metal)
	for _, x in { -0.45, 0, 0.45 } do
		local height = if x == 0 then 0.75 else 0.55
		k.box(0.12, height, 0.12, k.at(x, 0.75 + height / 2, 0), k.main, M.Metal, { R = 0.3 })
		k.wedge(0.14, 0.28, 0.14, k.at(x, 0.75 + height + 0.12, 0), k.main:Lerp(WHITE, 0.3), M.Neon)
	end
	k.box(0.45, 0.45, 0.45, k.at(0, 0.62, 0, 45, 0, 45), k.main, M.Glass, { T = 0.1 })
	k.torus(0.35, 0.06, 10, k.at(0, 0.2, 0, 90, 0, 0), C(120, 200, 255), M.Neon, { T = 0.3 })
end

Models.moon_pearl = function(k)
	k.ball(1.9, 0.5, 1.5, k.at(0, -0.7, 0), C(230, 215, 225), M.Marble)
	k.ball(1.9, 0.5, 1.5, k.at(0, 0.25, 0.55, 60, 0, 0), C(230, 215, 225), M.Marble)
	for i = -2, 2 do
		k.box(0.04, 0.05, 1.3, k.at(i * 0.3, -0.5, 0, 0, i * 8, 0), C(200, 180, 200))
	end
	k.ball(1.0, 1.0, 1.0, k.at(0, -0.1, -0.1), k.main, M.Marble, { R = 0.3 })
	k.ball(0.5, 0.5, 0.5, k.at(-0.18, 0.05, -0.35), WHITE, M.Neon, { T = 0.5 })
end

Models.kraken_pearl = function(k)
	k.ball(1.45, 1.45, 1.45, k.at(0, 0.25, 0), k.main, M.Glass, { T = 0.05, R = 0.2 })
	k.ball(0.8, 0.8, 0.8, k.at(0, 0.25, 0), k.main:Lerp(WHITE, 0.4), M.Neon, { T = 0.45 })
	-- Tentacles curling up around it.
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi + 0.4
		for j = 0, 3 do
			local t = j / 3
			local r = 0.95 - t * 0.2
			local y = -0.75 + t * 1.3
			local dia = 0.34 - t * 0.2
			k.ball(dia, 0.42, dia, k.at(math.cos(a + t * 0.8) * r, y, math.sin(a + t * 0.8) * r), C(120, 60, 140), M.SmoothPlastic)
			if j < 3 then
				k.ball(dia * 0.4, dia * 0.4, dia * 0.4, k.at(math.cos(a + t * 0.8) * (r - dia * 0.4), y, math.sin(a + t * 0.8) * (r - dia * 0.4)), C(230, 170, 200))
			end
		end
	end
end

-- ANCIENT RUINS -----------------------------------------------------------------------------

Models.clay_pot = function(k)
	local clay = k.main
	k.ball(1.5, 1.4, 1.5, k.at(0, -0.2, 0), clay, M.Slate)
	k.vcyl(0.55, 0.6, k.at(0, 0.7, 0), clay, M.Slate)
	k.vcyl(0.12, 0.85, k.at(0, 1.0, 0), clay, M.Slate)
	for _, x in { -1, 1 } do
		k.torus(0.25, 0.1, 6, k.at(x * 0.55, 0.62, 0, 0, 90, 0), clay, M.Slate)
	end
	k.vcyl(0.1, 1.52, k.at(0, -0.1, 0), C(40, 30, 30), M.Slate)
	k.vcyl(0.08, 1.46, k.at(0, 0.2, 0), C(240, 220, 170), M.Slate)
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi
		k.box(0.18, 0.18, 0.05, k.at(math.cos(a) * 0.74, -0.35, math.sin(a) * 0.74, 0, -math.deg(a) + 90, 45), C(240, 220, 170))
	end
end

Models.stone_tablet = function(k)
	local stone = k.main
	k.box(1.4, 1.9, 0.32, k.at(0, 0.05, 0), stone, M.Slate)
	k.wedge(0.32, 0.4, 0.4, k.at(0.55, 0.85, 0, 0, 90, 0), stone:Lerp(WHITE, 0.1), M.Slate)
	for row = 0, 3 do
		for col = 0, 2 do
			if (row + col) % 2 == 0 or row == 1 then
				k.box(0.22, 0.14, 0.05, k.at(-0.4 + col * 0.4, 0.55 - row * 0.4, -0.17), C(255, 200, 90), M.Neon)
			end
		end
	end
	k.ball(0.5, 0.3, 0.2, k.at(-0.45, -0.75, -0.1), C(90, 140, 70), M.Grass)
end

Models.carved_mask = function(k)
	local wood = k.main
	k.ball(1.3, 1.7, 0.45, k.at(0, 0, 0), wood, M.Wood)
	for _, x in { -0.3, 0.3 } do
		k.ball(0.38, 0.28, 0.1, k.at(x, 0.25, -0.2), BLACK)
		k.ball(0.1, 0.1, 0.05, k.at(x, 0.25, -0.26), C(255, 200, 60), M.Neon)
		k.box(0.1, 0.35, 0.05, k.at(x * 1.3, -0.05, -0.2, 0, 0, x * 60), C(230, 60, 50))
	end
	k.box(0.7, 0.2, 0.1, k.at(0, -0.4, -0.2), BLACK)
	for i = -2, 2 do
		k.wedge(0.1, 0.14, 0.04, k.at(i * 0.13, -0.33, -0.25, 0, 0, 180), WHITE)
	end
	k.wedge(0.16, 0.35, 0.2, k.at(0, 0, -0.3), wood:Lerp(DARK, 0.2), M.Wood)
	for i = -2, 2 do
		k.box(0.12, 0.7, 0.04, k.at(i * 0.2, 1.05, 0.05, 0, 0, i * -14), if i % 2 == 0 then C(230, 70, 50) else C(60, 170, 220), M.Fabric)
	end
end

Models.golden_chalice = function(k)
	goblet(k, k.main, M.Metal, 1.5, 1.05)
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		k.box(0.18, 0.18, 0.18, k.at(math.cos(a) * 0.76, 0.55, math.sin(a) * 0.76, 45, 0, 45), if i % 2 == 0 then C(220, 40, 60) else C(60, 120, 255), M.Glass)
	end
	for _, x in { -1, 1 } do
		k.torus(0.3, 0.08, 7, k.at(x * 0.85, 0.6, 0, 0, 90, 0), k.main, M.Metal)
	end
	k.ball(1.2, 0.2, 1.2, k.at(0, 1.1, 0), C(150, 20, 40), M.Glass, { T = 0.2 })
end

Models.sunstone_idol = function(k)
	local stone = k.main
	k.box(1.1, 1.1, 0.8, k.at(0, -0.4, 0), stone, M.Slate)
	k.box(1.0, 0.85, 0.85, k.at(0, 0.5, 0), stone, M.Slate)
	for i = 0, 7 do
		local a = i / 8 * 2 * math.pi
		k.wedge(0.12, 0.4, 0.2, k.at(math.cos(a) * 0.7, 0.55 + math.sin(a) * 0.7, 0.15, 0, 0, math.deg(a) - 90), C(255, 200, 60), M.Neon)
	end
	for _, x in { -0.22, 0.22 } do
		k.box(0.2, 0.12, 0.05, k.at(x, 0.6, -0.44), C(255, 240, 150), M.Neon)
	end
	k.box(0.4, 0.08, 0.05, k.at(0, 0.3, -0.44), DARK)
	k.box(1.2, 0.22, 0.3, k.at(0, -0.25, -0.4), stone:Lerp(DARK, 0.2), M.Slate)
end

Models.ancient_map = function(k)
	local paper = k.main
	k.box(1.9, 0.04, 1.3, k.at(0, -0.3, 0, -20, 0, 0), paper, M.Fabric)
	for _, x in { -1, 1 } do
		k.cyl(1.5, 0.28, k.at(x * 0.98, -0.3, 0, 0, 90, 0) * CFrame.Angles(rad(-20), 0, 0), paper:Lerp(DARK, 0.2), M.Fabric)
	end
	-- Island outline, dotted path, big red X.
	k.ball(0.9, 0.05, 0.6, k.at(0, -0.26, 0.05, -20, 0, 0), C(120, 170, 90), M.Fabric)
	for i = 0, 4 do
		k.box(0.07, 0.03, 0.07, k.at(-0.5 + i * 0.2, -0.24, 0.2 - i * 0.06, -20, 0, 0), C(120, 70, 40))
	end
	for _, rz in { 45, -45 } do
		k.box(0.36, 0.05, 0.08, k.at(0.45, -0.22, -0.1, -20, rz, 0), C(230, 30, 30), M.Neon)
	end
	k.box(0.2, 0.2, 0.2, k.at(-0.7, 0.2, -0.3, 30, 20, 0), C(230, 200, 150), M.Fabric) -- torn corner
end

Models.golden_monkey = function(k)
	local gold = k.main
	k.ball(1.0, 1.1, 0.9, k.at(0, -0.4, 0), gold, M.Metal, { R = 0.3 })
	k.ball(1.0, 0.95, 0.9, k.at(0, 0.5, 0), gold, M.Metal, { R = 0.3 })
	for _, x in { -1, 1 } do
		k.ball(0.45, 0.45, 0.15, k.at(x * 0.58, 0.6, 0), gold, M.Metal)
		k.ball(0.25, 0.25, 0.1, k.at(x * 0.58, 0.6, -0.05), C(220, 150, 70), M.Metal)
		k.ball(0.28, 0.6, 0.28, k.at(x * 0.55, -0.35, -0.2, 20, 0, x * 30), gold, M.Metal)
	end
	k.ball(0.65, 0.45, 0.35, k.at(0, 0.35, -0.38), C(240, 180, 90), M.Metal)
	eyes(k, 0.65, -0.38, 0.18, 0.2, C(40, 200, 90))
	for i = 0, 3 do
		k.ball(0.18, 0.18, 0.18, k.at(0.45 + math.sin(i) * 0.25, -0.6 + i * 0.25, 0.5), gold, M.Metal)
	end
	k.ball(0.25, 0.55, 0.25, k.at(-0.55, -0.1, -0.45, 0, 0, -40), C(255, 230, 80), M.SmoothPlastic)
end

Models.golden_crown = function(k)
	local gold = k.main
	k.vcyl(0.6, 1.7, k.at(0, -0.45, 0), gold, M.Metal, { R = 0.35 })
	k.ball(1.4, 0.8, 1.4, k.at(0, -0.1, 0), C(150, 20, 40), M.Fabric)
	for i = 1, 7 do
		local a = i / 7 * 2 * math.pi
		local tall = i % 2 == 0
		local height = if tall then 0.9 else 0.6
		k.wedge(0.32, height, 0.14, k.at(math.cos(a) * 0.8, -0.15 + height / 2, math.sin(a) * 0.8, 0, -math.deg(a) - 90, 0), gold, M.Metal, { R = 0.3 })
		k.ball(0.2, 0.2, 0.2, k.at(math.cos(a) * 0.82, -0.12 + height, math.sin(a) * 0.82), if tall then C(220, 40, 60) else C(60, 130, 255), M.Glass)
	end
	k.vcyl(0.35, 0.12, k.at(0, 0.55, 0), gold, M.Metal)
	k.box(0.3, 0.1, 0.1, k.at(0, 0.65, 0), gold, M.Metal)
	k.ball(0.26, 0.26, 0.26, k.at(0, 0.82, 0), C(255, 255, 220), M.Neon)
end

Models.sun_disc = function(k)
	local gold = k.main
	local face = k.at(0, 0.1, 0, 0, 90, 0)
	k.cyl(0.22, 1.5, face, gold, M.Metal, { R = 0.3 })
	for i = 0, 11 do
		local a = i / 12 * 2 * math.pi
		k.wedge(0.1, if i % 2 == 0 then 0.55 else 0.4, 0.22, k.at(math.cos(a) * 0.95, 0.1 + math.sin(a) * 0.95, 0, 0, 0, math.deg(a) - 90), gold, M.Metal)
	end
	k.cyl(0.26, 0.85, face, C(255, 230, 120), M.Neon)
	-- Smiling sun face.
	for _, x in { -0.18, 0.18 } do
		k.ball(0.14, 0.14, 0.05, k.at(x, 0.22, -0.14), C(120, 60, 10))
	end
	k.box(0.3, 0.06, 0.05, k.at(0, -0.05, -0.14), C(120, 60, 10))
	k.vcyl(0.2, 1.0, k.at(0, -0.78, 0), gold:Lerp(DARK, 0.3), M.Metal)
end

Models.cursed_skull = function(k)
	local bone = C(225, 220, 195)
	k.ball(1.5, 1.35, 1.45, k.at(0, 0.2, 0), bone, M.Marble)
	k.box(0.95, 0.5, 0.8, k.at(0, -0.55, -0.2), bone, M.Marble)
	for _, x in { -0.32, 0.32 } do
		k.ball(0.48, 0.48, 0.2, k.at(x, 0.15, -0.66), BLACK)
		k.ball(0.26, 0.26, 0.1, k.at(x, 0.15, -0.74), k.main, M.Neon)
	end
	k.wedge(0.2, 0.25, 0.1, k.at(0, -0.15, -0.72, 0, 0, 180), BLACK)
	for i = -2, 2 do
		k.box(0.12, 0.2, 0.06, k.at(i * 0.16, -0.62, -0.62), WHITE)
	end
	k.box(0.05, 0.6, 0.05, k.at(0.35, 0.65, -0.35, 0, 0, 25), DARK) -- crack
	for _, x in { -1, 1 } do
		horn(k, x * 0.55, 0.65, 0.1, x, 0.9, 0.34, C(45, 40, 40), M.Slate)
	end
end

-- THE FALLS ---------------------------------------------------------------------------------

Models.ghost_lantern = function(k)
	k.vcyl(0.14, 1.3, k.at(0, -0.8, 0), IRON, M.Metal)
	k.vcyl(0.14, 1.3, k.at(0, 0.75, 0), IRON, M.Metal)
	k.cone(0.4, 1.1, 3, k.at(0, 0.8, 0), IRON, M.Metal)
	k.torus(0.2, 0.08, 7, k.at(0, 1.35, 0), IRON, M.Metal)
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi + rad(45)
		k.box(0.08, 1.5, 0.08, k.at(math.cos(a) * 0.58, 0, math.sin(a) * 0.58), IRON, M.Metal)
	end
	k.vcyl(1.45, 1.1, k.at(0, 0, 0), k.main, M.Glass, { T = 0.85 })
	-- The ghost inside: a wisp with a tail and eyes.
	k.ball(0.85, 0.9, 0.8, k.at(0, 0.15, 0), k.main, M.Neon, { T = 0.05 })
	k.ball(0.5, 0.6, 0.45, k.at(0.1, -0.45, 0, 0, 0, 25), k.main, M.Neon, { T = 0.25 })
	for _, x in { -0.16, 0.16 } do
		k.ball(0.16, 0.26, 0.08, k.at(x, 0.25, -0.4), BLACK)
	end
	k.ball(0.18, 0.2, 0.08, k.at(0, 0.0, -0.4), BLACK) -- "ooOOoo"
end

Models.crystal_heart = function(k)
	heart(k, 0.05, 1.9, k.main, M.Glass, { T = 0.2 })
	heart(k, 0.05, 1.0, k.main:Lerp(WHITE, 0.4), M.Neon, { T = 0.3 })
	for i = 1, 3 do
		local a = i * 2.1
		k.box(0.12, 0.12, 0.12, k.at(math.cos(a) * 1.05, 0.7 + i * 0.1, math.sin(a) * 0.3, 45, 45, 0), WHITE, M.Neon)
	end
end

Models.phoenix_feather = function(k)
	feather(k, C(255, 60, 20), C(255, 220, 60), GOLD, M.Neon)
	for i = 0, 2 do
		k.ball(0.18, 0.5, 0.06, k.at(0.55 + i * 0.12, -0.1 + i * 0.5, 0, 0, 0, -45), C(255, 200, 60), M.Neon, { T = 0.35 })
	end
end

Models.dragon_egg = function(k)
	local shell = k.main
	k.ball(1.6, 2.1, 1.6, k.at(0, 0.15, 0), shell, M.Slate)
	-- Scales in rows and glowing lava cracks.
	for row = 0, 2 do
		for i = 1, 6 do
			local a = i / 6 * 2 * math.pi + row * 0.5
			local y = -0.4 + row * 0.45
			local r = 0.78 - math.abs(y - 0.15) * 0.25
			k.wedge(0.34, 0.28, 0.1, k.at(math.cos(a) * r, y, math.sin(a) * r, -15, -math.deg(a) - 90, 0), shell:Lerp(DARK, 0.35), M.Slate)
		end
	end
	for i = 0, 2 do
		k.box(0.06, 0.45, 0.06, k.at(-0.2 + i * 0.12, 0.45 + (i % 2) * 0.2, -0.76, 0, 0, (i - 1) * 35), C(255, 140, 30), M.Neon)
	end
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		k.cyl(0.9, 0.12, k.at(math.cos(a) * 0.6, -0.85, math.sin(a) * 0.6, 0, -math.deg(a), 10), C(90, 60, 35), M.Wood)
	end
end

Models.mist_flask = function(k)
	k.ball(1.35, 1.35, 1.35, k.at(0, -0.25, 0), k.main, M.Glass, { T = 0.5 })
	k.ball(1.0, 0.9, 1.0, k.at(0, -0.35, 0), k.main:Lerp(WHITE, 0.4), M.Neon, { T = 0.55 })
	k.vcyl(0.55, 0.36, k.at(0, 0.62, 0), k.main, M.Glass, { T = 0.4 })
	k.vcyl(0.28, 0.42, k.at(0, 0.98, 0), C(160, 110, 70), M.Wood)
	k.box(0.6, 0.4, 0.04, k.at(0, -0.2, -0.68), C(240, 225, 180), M.Fabric)
	for i = 1, 3 do
		k.ball(0.18, 0.18, 0.18, k.at(-0.2 + i * 0.12, 1.2 + i * 0.12, 0), WHITE, M.Neon, { T = 0.5 })
	end
end

Models.river_charm = function(k)
	k.ball(1.5, 1.05, 0.7, k.at(0, -0.3, 0), k.main, M.Slate, { R = 0.1 })
	k.torus(0.2, 0.08, 7, k.at(0, 0.3, 0), C(170, 140, 90), M.Fabric)
	k.box(0.08, 0.5, 0.05, k.at(0, -0.3, -0.36), C(140, 255, 230), M.Neon)
	k.box(0.35, 0.08, 0.05, k.at(0, -0.2, -0.36), C(140, 255, 230), M.Neon)
	k.box(0.25, 0.08, 0.05, k.at(0, -0.42, -0.36, 0, 0, 30), C(140, 255, 230), M.Neon)
	k.box(0.05, 0.35, 0.05, k.at(0, 0.62, 0), C(170, 140, 90), M.Fabric)
end

Models.storm_feather = function(k)
	feather(k, k.main, k.main:Lerp(WHITE, 0.3), C(60, 55, 70), M.SmoothPlastic)
	for i = 0, 3 do
		k.box(0.06, 0.4, 0.06, k.at(-0.45 + i * 0.28, -0.5 + i * 0.5, -0.1, 0, 0, if i % 2 == 0 then 35 else -35), C(190, 230, 255), M.Neon)
	end
end

Models.cliff_tablet = function(k)
	local stone = k.main
	k.box(1.5, 1.9, 0.35, k.at(0, 0.05, 0, 0, 0, 4), stone, M.Slate)
	-- A carved relief map: island, waterfall line, a glowing X.
	k.ball(0.9, 0.9, 0.08, k.at(0, 0.1, -0.2), stone:Lerp(C(90, 150, 90), 0.5), M.Slate)
	k.box(0.08, 0.6, 0.05, k.at(-0.15, 0.2, -0.26), C(120, 200, 255), M.Neon)
	for _, rz in { 45, -45 } do
		k.box(0.25, 0.06, 0.05, k.at(0.25, -0.05, -0.27, 0, 0, rz), C(255, 90, 60), M.Neon)
	end
	k.ball(0.5, 0.3, 0.3, k.at(0.5, -0.8, -0.1), C(90, 140, 70), M.Grass)
end

Models.seraph_feather = function(k)
	feather(k, WHITE, k.main, GOLD, M.Neon)
	k.torus(0.4, 0.07, 12, k.at(0.1, 1.45, 0, 90, 0, 0), GOLD, M.Neon)
	for _, x in { -1, 1 } do
		k.ball(0.8, 0.35, 0.08, k.at(x * 0.55, 0.2, 0.15, 0, 0, x * -30), WHITE, M.Neon, { T = 0.35 })
	end
end

Models.heart_of_the_island = function(k)
	k.ball(1.4, 1.4, 1.4, k.at(0, 0.2, 0), WHITE, M.Neon, { T = 0.05 })
	k.ball(1.75, 1.75, 1.75, k.at(0, 0.2, 0), C(200, 240, 255), M.Glass, { T = 0.75 })
	-- A tiny island inside, rings of black and white around.
	k.ball(0.55, 0.2, 0.55, k.at(0, 0.1, 0), C(90, 170, 80), M.Grass)
	k.torus(1.05, 0.08, 16, k.at(0, 0.2, 0, 70, 0, 20), BLACK, M.SmoothPlastic)
	k.torus(1.15, 0.08, 16, k.at(0, 0.2, 0, 70, 0, -40), WHITE, M.Neon)
	k.vcyl(0.12, 1.0, k.at(0, -0.8, 0), BLACK, M.Slate)
end

-- FROSTPEAK ---------------------------------------------------------------------------------

Models.frosted_mug = function(k)
	local glass = k.main
	k.vcyl(1.3, 1.1, k.at(0, -0.2, 0), glass, M.Glass, { T = 0.35 })
	k.vcyl(1.1, 0.95, k.at(0, -0.25, 0), C(240, 180, 60), M.Glass, { T = 0.2 })
	k.torus(0.35, 0.14, 8, k.at(0.7, -0.15, 0, 0, 90, 0), glass, M.Glass, { T = 0.2 })
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.ball(0.45, 0.4, 0.45, k.at(math.cos(a) * 0.35, 0.55, math.sin(a) * 0.35), WHITE, M.SmoothPlastic)
	end
	k.ball(0.6, 0.5, 0.6, k.at(0, 0.72, 0), WHITE, M.SmoothPlastic)
	k.ball(0.3, 0.7, 0.2, k.at(-0.45, 0.2, -0.45), WHITE, M.SmoothPlastic) -- foam dripping over
	for i = 1, 3 do
		k.cone(0.3, 0.1, 2, k.at(-0.3 + i * 0.2, -0.95, -0.52, 180, 0, 0), C(220, 245, 255), M.Glass)
	end
end

Models.snowflake_brooch = function(k)
	local ice = k.main
	for i = 0, 5 do
		local a = i * 60
		local arm = k.at(0, 0.1, 0, 0, 0, a)
		k.box(0.12, 1.0, 0.08, arm * CFrame.new(0, 0.5 * k.s, 0), ice, M.Glass)
		for _, side in { -1, 1 } do
			k.box(0.08, 0.3, 0.06, arm * CFrame.new(side * 0.1 * k.s, 0.62 * k.s, 0) * CFrame.Angles(0, 0, rad(side * -45)), ice, M.Glass)
		end
		k.box(0.14, 0.14, 0.08, arm * CFrame.new(0, 1.0 * k.s, 0) * CFrame.Angles(0, 0, rad(45)), C(200, 240, 255), M.Neon)
	end
	k.box(0.4, 0.4, 0.2, k.at(0, 0.1, -0.02, 0, 0, 45), C(120, 200, 255), M.Glass)
end

Models.mammoth_tusk = function(k)
	for i = 0, 7 do
		local t = i / 7
		local a = rad(-40 + t * 150)
		local r = 0.9
		k.cyl(0.36, 0.6 - t * 0.48, k.at(math.cos(a) * r - 0.2, math.sin(a) * r * 0.9, t * 0.2, 0, 0, math.deg(a) + 90), k.main:Lerp(C(210, 190, 150), t * 0.3), M.Marble)
	end
	k.cyl(0.3, 0.7, k.at(0.52, -0.55, 0, 0, 0, 50), C(150, 110, 80), M.Fabric)
	k.ball(0.3, 0.2, 0.3, k.at(-0.9, 0.55, 0.2), WHITE, M.Snow)
end

Models.frozen_heart = function(k)
	k.box(1.7, 1.8, 1.4, k.at(0, 0.05, 0, 0, 20, 5), C(200, 240, 255), M.Glass, { T = 0.6 })
	heart(k, 0.05, 1.3, k.main, M.Neon, { T = 0.05 })
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi
		shard(k, k.at(math.cos(a) * 0.6, 0.9, math.sin(a) * 0.5, 0, 0, math.cos(a) * -25), 0.16, 0.3, C(220, 245, 255), M.Glass)
	end
end

Models.yeti_crown = function(k)
	k.torus(0.72, 0.4, 12, k.at(0, -0.55, 0, 90, 0, 0), WHITE, M.Fabric)
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		local height = if i % 2 == 0 then 1.3 else 0.9
		crystal(k, math.cos(a) * 0.65, math.sin(a) * 0.65, height, 0.26, math.cos(a) * 12, k.main, M.Glass)
	end
	k.ball(0.45, 0.45, 0.45, k.at(0, 0.1, 0), C(120, 220, 255), M.Neon)
end

Models.aurora_crystal = function(k)
	local colors = { C(0, 229, 255), C(80, 255, 170), C(170, 110, 255), C(0, 200, 255), C(120, 255, 220) }
	crystal(k, 0, 0, 2.0, 0.55, 0, colors[1], M.Neon)
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi + 0.4
		crystal(k, math.cos(a) * 0.55, math.sin(a) * 0.55, 1.0 + (i % 2) * 0.4, 0.34, math.cos(a) * 25, colors[i + 1], M.Glass)
	end
	k.ball(1.4, 0.3, 1.4, k.at(0, -0.8, 0), C(220, 240, 255), M.Snow)
end

-- GLOWSHROOM MARSH --------------------------------------------------------------------------

Models.toad_totem = function(k)
	local wood = k.main
	for i = 0, 2 do
		local y = -0.65 + i * 0.62
		local size = 1.2 - i * 0.15
		k.ball(size, 0.6, size * 0.9, k.at(0, y, 0), wood:Lerp(C(80, 140, 60), i * 0.2), M.Wood)
		eyes(k, y + 0.28, -size * 0.3, size * 0.28, 0.24, C(255, 200, 40))
		k.ball(size * 0.6, 0.08, 0.2, k.at(0, y - 0.05, -size * 0.38), DARK)
	end
	k.wedge(0.5, 0.35, 0.2, k.at(0, 1.2, 0), C(230, 80, 60), M.Wood)
end

Models.glow_jar = function(k)
	k.vcyl(1.5, 1.2, k.at(0, -0.15, 0), C(200, 230, 255), M.Glass, { T = 0.65 })
	k.vcyl(0.25, 1.28, k.at(0, 0.72, 0), C(140, 100, 70), M.Wood)
	k.box(0.14, 0.6, 0.05, k.at(0, 1.1, 0), C(200, 170, 120), M.Fabric)
	for i = 1, 8 do
		local a = i * 2.4
		k.ball(0.18, 0.18, 0.18, k.at(math.cos(a) * 0.35, -0.6 + (i % 4) * 0.3, math.sin(a) * 0.35), if i % 2 == 0 then k.main else C(255, 240, 120), M.Neon)
	end
	k.ball(0.5, 0.5, 0.5, k.at(0, -0.1, 0), k.main, M.Neon, { T = 0.6 })
end

Models.witch_cauldron = function(k)
	local iron = k.main
	k.ball(1.9, 1.5, 1.9, k.at(0, -0.2, 0), iron, M.Metal)
	k.torus(0.82, 0.14, 14, k.at(0, 0.45, 0, 90, 0, 0), iron:Lerp(BLACK, 0.3), M.Metal)
	k.vcyl(0.1, 1.55, k.at(0, 0.42, 0), C(100, 255, 80), M.Neon)
	for i = 1, 4 do
		local a = i * 1.6
		k.ball(0.28 + (i % 2) * 0.12, 0.28 + (i % 2) * 0.12, 0.28 + (i % 2) * 0.12, k.at(math.cos(a) * 0.35, 0.58 + (i % 3) * 0.1, math.sin(a) * 0.35), C(140, 255, 110), M.Neon, { T = 0.2 })
	end
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		k.box(0.14, 0.4, 0.14, k.at(math.cos(a) * 0.6, -0.85, math.sin(a) * 0.6), iron, M.Metal)
	end
	k.box(0.1, 1.3, 0.1, k.at(0.3, 0.8, 0.2, 20, 0, -25), WOOD, M.Wood)
	k.torus(0.3, 0.07, 8, k.at(0, 0.3, -0.9), iron, M.Metal)
end

Models.spore_scepter = function(k)
	k.vcyl(2.2, 0.14, k.at(0, -0.1, 0), C(90, 60, 110), M.Wood)
	k.ball(1.2, 0.6, 1.2, k.at(0, 1.05, 0), k.main, M.Neon)
	k.vcyl(0.3, 0.3, k.at(0, 0.8, 0), C(230, 210, 240), M.SmoothPlastic)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.ball(0.18, 0.1, 0.18, k.at(math.cos(a) * 0.36, 1.28, math.sin(a) * 0.36), WHITE, M.SmoothPlastic)
	end
	for i = 1, 3 do
		k.ball(0.14, 0.14, 0.14, k.at(math.cos(i * 2) * 0.5, 0.6 - i * 0.2, math.sin(i * 2) * 0.5), k.main:Lerp(WHITE, 0.4), M.Neon, { T = 0.3 })
	end
	k.torus(0.12, 0.06, 6, k.at(0, 0.4, 0, 90, 0, 0), GOLD, M.Metal)
end

Models.moonshroom = function(k)
	k.vcyl(1.1, 0.5, k.at(0, -0.4, 0), C(230, 230, 245), M.SmoothPlastic)
	k.ball(0.8, 0.3, 0.8, k.at(0, -0.85, 0), C(200, 200, 220), M.SmoothPlastic)
	k.ball(2.0, 1.0, 2.0, k.at(0, 0.45, 0), k.main, M.Neon)
	k.ball(1.9, 0.3, 1.9, k.at(0, 0.18, 0), k.main:Lerp(DARK, 0.4), M.SmoothPlastic)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.ball(0.3, 0.14, 0.3, k.at(math.cos(a) * 0.55, 0.82, math.sin(a) * 0.55), WHITE, M.Neon)
	end
	-- A little moon glowing on top.
	k.ball(0.42, 0.42, 0.42, k.at(0, 1.1, 0), C(255, 250, 200), M.Neon)
end

-- SECRET: FROSTBANE ------------------------------------------------------------------------
-- A huge two-handed runeblade driven point-first into the ground: an ice-steel blade with
-- glowing runes and a serrated upper edge, a skull crossguard with sweeping horned guards,
-- a wrapped grip and a gem pommel. Blue frost-fire, crackling sparks and sinking cold mist.

local function frostbaneFx(k: Kit)
	local handle, s = k.handle, k.s
	local ice = C(90, 210, 255)
	local light = Instance.new("PointLight")
	light.Name = "RuneLight"
	light.Color = ice
	light.Range = s * 4.5
	light.Brightness = 3
	light.Shadows = false
	light.Parent = handle
	local fire = Instance.new("Fire")
	fire.Name = "Frostfire"
	fire.Color = C(80, 190, 255)
	fire.SecondaryColor = C(20, 50, 140)
	fire.Size = s * 0.3
	fire.Heat = 4
	fire.Parent = handle
	local function emitter(name: string, props)
		local e = Instance.new("ParticleEmitter")
		e.Name = name
		e.LightInfluence = 0
		for key, value in props do
			(e :: any)[key] = value
		end
		e.Parent = handle
	end
	-- Crackling blue sparks all along the blade...
	emitter("RuneSparks", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(ice, C(230, 250, 255)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.14), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.35, 0.8),
		Rate = 45,
		Speed = NumberRange.new(s * 0.3, s * 1.2),
		SpreadAngle = Vector2.new(180, 180),
		Drag = 4,
	})
	-- ...big bright flashes like arcs of frost lightning...
	emitter("RuneFlash", {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Color = ColorSequence.new(C(200, 245, 255)),
		LightEmission = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, s * 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Lifetime = NumberRange.new(0.12, 0.22),
		Rate = 7,
		Speed = NumberRange.new(0, 0),
		Rotation = NumberRange.new(0, 90),
	})
	-- ...and cold mist rolling off it and sinking to the ground.
	emitter("ColdMist", {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Color = ColorSequence.new(C(190, 230, 255)),
		LightEmission = 0.3,
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s * 0.2), NumberSequenceKeypoint.new(1, s * 0.7) }),
		Lifetime = NumberRange.new(2, 3.2),
		Rate = 8,
		Speed = NumberRange.new(s * 0.05, s * 0.2),
		SpreadAngle = Vector2.new(180, 180),
		Acceleration = Vector3.new(0, -s * 0.15, 0),
	})
end

Models.frostbane = function(k)
	local steel = k.main
	local rim = C(40, 70, 120)
	local rune = C(90, 220, 255)
	local darkSteel = C(62, 72, 96)
	local bone = C(150, 165, 185)
	-- BLADE: point-down, broad side facing front/back, tapering to a diamond tip.
	local top, bottom, segments = 0.8, -0.76, 8
	local h = (top - bottom) / segments
	local function width(y: number): number
		return 0.54 - ((top - y) / (top - bottom)) * 0.36
	end
	for i = 0, segments - 1 do
		local y = top - (i + 0.5) * h
		local w = width(y)
		k.box(w, h * 1.04, 0.07, k.at(0, y, 0), steel, M.Metal, { R = 0.4 })
		k.box(w + 0.06, h * 1.04, 0.04, k.at(0, y, 0), rim, M.Metal)
	end
	k.box(0.19, 0.19, 0.07, k.at(0, bottom, 0, 0, 0, 45), steel, M.Metal, { R = 0.4 })
	-- Serrated upper edges: saw teeth raking back toward the hilt.
	for i = 0, 3 do
		local y = 0.7 - i * 0.18
		for _, side in { -1, 1 } do
			k.wedge(0.06, 0.16, 0.12, k.at(side * (width(y) / 2 + 0.04), y, 0, 0, side * 90, 180), steel:Lerp(WHITE, 0.25), M.Metal, { R = 0.4 })
		end
	end
	-- Glowing runes down the centre, on both faces, over a faint fuller line.
	for _, face in { -1, 1 } do
		local z = face * 0.045
		k.box(0.04, 1.45, 0.02, k.at(0, 0.02, z), rune, M.Neon, { T = 0.45 })
		for i = 0, 6 do
			local y = 0.66 - i * 0.22
			if i % 2 == 0 then
				k.box(0.07, 0.13, 0.02, k.at(0, y, z), rune, M.Neon)
			else
				k.box(0.15, 0.05, 0.02, k.at(0, y, z, 0, 0, 20), rune, M.Neon)
			end
		end
	end
	-- CROSSGUARD: a grim steel skull with slanted glowing eyes, curling horns, and guards that
	-- sweep up like frozen wings, spiked along their length.
	local skullY = 0.9
	k.ball(0.36, 0.34, 0.3, k.at(0, skullY, 0), bone, M.Metal, { R = 0.2 })
	k.box(0.24, 0.12, 0.2, k.at(0, skullY - 0.2, -0.02), bone, M.Metal, { R = 0.2 })
	for i = -1, 1 do
		k.box(0.05, 0.08, 0.04, k.at(i * 0.07, skullY - 0.27, -0.1), WHITE, M.SmoothPlastic)
	end
	for _, side in { -1, 1 } do
		-- Brow ridge in a scowl, slanted eye sockets burning blue.
		k.box(0.17, 0.05, 0.1, k.at(side * 0.08, skullY + 0.07, -0.12, 0, 0, side * -18), darkSteel, M.Metal)
		k.box(0.12, 0.07, 0.04, k.at(side * 0.08, skullY + 0.0, -0.14, 0, 0, side * -20), BLACK)
		k.box(0.08, 0.035, 0.03, k.at(side * 0.08, skullY + 0.0, -0.16, 0, 0, side * -20), rune, M.Neon)
		horn(k, side * 0.14, skullY + 0.1, 0.02, side, 0.28, 0.13, darkSteel, M.Metal)
		-- The guard arm sweeps out and up, ending in a glowing spike.
		local arm = { { 0.26, 0.86, 0.2, 10 }, { 0.46, 0.91, 0.17, 25 }, { 0.63, 1.02, 0.14, 45 }, { 0.75, 1.18, 0.1, 65 } }
		for j, seg in arm do
			k.box(0.24, seg[3], 0.12, k.at(side * seg[1], seg[2], 0, 0, 0, side * seg[4]), darkSteel, M.Metal, { R = 0.2 })
			if j == 2 or j == 3 then
				k.wedge(0.06, 0.14, 0.1, k.at(side * seg[1], seg[2] + seg[3] * 0.7, 0, 0, side * -90, side * seg[4]), darkSteel, M.Metal)
			end
		end
		k.box(0.1, 0.1, 0.1, k.at(side * 0.8, 1.3, 0, 0, 0, 45), rune, M.Neon)
		-- A fang curling down onto the blade.
		k.ball(0.08, 0.26, 0.08, k.at(side * 0.18, 0.66, -0.02, 0, 0, side * 15), bone, M.Metal)
	end
	-- GRIP and POMMEL.
	k.vcyl(0.4, 0.12, k.at(0, 1.26, 0), C(38, 34, 48), M.Fabric)
	for _, y in { 1.1, 1.26, 1.42 } do
		k.vcyl(0.035, 0.155, k.at(0, y, 0), darkSteel, M.Metal)
	end
	k.torus(0.1, 0.05, 8, k.at(0, 1.54, 0), darkSteel, M.Metal)
	k.ball(0.13, 0.13, 0.13, k.at(0, 1.54, 0), rune, M.Neon)
	for _, side in { -1, 1 } do
		k.box(0.05, 0.05, 0.12, k.at(side * 0.14, 1.54, 0, 0, 0, 45), darkSteel, M.Metal)
	end
	frostbaneFx(k)
end

-- DEEP SOUTH: shared pieces ---------------------------------------------------------------

-- Flat triangular spike in the CFrame's XY plane, base centred on the CFrame, tip along +Y.
local function spike2d(k: Kit, cf: CFrame, base: number, height: number, thick: number, color: Color3, mat: Enum.Material, extra)
	local frame = cf * CFrame.Angles(0, rad(90), 0)
	k.wedge(thick, height, base / 2, frame * CFrame.new(0, height * k.s / 2, -base * k.s / 4), color, mat, extra)
	k.wedge(thick, height, base / 2, frame * CFrame.new(0, height * k.s / 2, base * k.s / 4) * CFrame.Angles(0, math.pi, 0), color, mat, extra)
end

-- Five-point star lying in the CFrame's XY plane (faces along Z).
local function starShape(k: Kit, cf: CFrame, radius: number, thick: number, color: Color3, mat: Enum.Material, extra)
	for i = 0, 4 do
		spike2d(k, cf * CFrame.Angles(0, 0, rad(i * 72)) * CFrame.new(0, radius * 0.3 * k.s, 0), radius * 0.62, radius * 0.72, thick, color, mat, extra)
	end
	k.cyl(thick, radius * 0.75, cf * CFrame.Angles(0, rad(90), 0), color, mat, extra)
end

-- CFrame on a ring of radius r at angle a, its Y axis leaning `lean` degrees outward.
local function onRing(k: Kit, a: number, r: number, y: number, lean: number): CFrame
	return k.at(math.cos(a) * r, y, math.sin(a) * r, 0, -math.deg(a), -lean)
end

local LAVA = C(255, 110, 25)
local ICE = C(200, 240, 255)
local AURORA = { C(0, 229, 255), C(80, 255, 170), C(170, 110, 255), C(255, 120, 220), C(120, 255, 220) }

-- EMBERFALL ---------------------------------------------------------------------------------

Models.obsidian_shard = function(k)
	local glass = C(30, 22, 40)
	k.ball(1.6, 0.35, 1.3, k.at(0, -0.78, 0), C(60, 45, 40), M.Basalt)
	crystal(k, 0, 0, 1.9, 0.6, 4, glass, M.Glass)
	crystal(k, 0.45, 0.2, 1.1, 0.4, -28, glass, M.Glass)
	crystal(k, -0.45, -0.1, 1.3, 0.42, 24, glass, M.Glass)
	crystal(k, 0.1, 0.45, 0.8, 0.3, -10, glass, M.Glass)
	-- Red-hot veins glowing through the black glass.
	for i = 0, 2 do
		k.box(0.06, 0.6, 0.06, k.at(-0.08 + i * 0.08, -0.35 + i * 0.4, -0.31, 0, 0, (i - 1) * 25), C(255, 60, 20), M.Neon)
	end
	k.box(0.05, 0.4, 0.05, k.at(-0.52, -0.2, -0.3, 0, 0, 30), C(255, 90, 30), M.Neon)
end

Models.ember_lantern = function(k)
	local iron = C(50, 45, 45)
	k.box(1.1, 0.14, 1.1, k.at(0, -0.8, 0), iron, M.Metal)
	k.box(0.95, 0.12, 0.95, k.at(0, 0.55, 0), iron, M.Metal)
	for _, x in { -0.48, 0.48 } do
		for _, z in { -0.48, 0.48 } do
			k.box(0.1, 1.35, 0.1, k.at(x, -0.12, z), iron, M.Metal)
		end
	end
	k.box(0.88, 1.25, 0.88, k.at(0, -0.12, 0), C(255, 190, 120), M.Glass, { T = 0.55 })
	-- A fat, angry flame: stacked teardrops, hotter toward the tip.
	k.ball(0.6, 0.7, 0.6, k.at(0, -0.38, 0), C(255, 100, 20), M.Neon)
	k.ball(0.38, 0.6, 0.38, k.at(0, 0.0, 0), C(255, 190, 60), M.Neon)
	k.ball(0.16, 0.3, 0.16, k.at(0.04, 0.3, 0), C(255, 245, 190), M.Neon)
	k.cone(0.5, 0.95, 3, k.at(0, 0.6, 0), iron, M.Metal)
	k.torus(0.2, 0.07, 10, k.at(0, 1.22, 0), iron, M.Metal)
end

Models.salamander_scale = function(k)
	local red = k.main
	k.ball(1.9, 2.1, 0.35, k.at(0, 0.2, 0, -10, 0, 0), red, M.Glass, { R = 0.15 })
	k.ball(1.45, 1.65, 0.3, k.at(0, 0.15, -0.06, -10, 0, 0), red:Lerp(C(255, 190, 60), 0.4), M.Glass)
	-- A glowing ridge down the middle, ribs sweeping out like a leaf.
	k.box(0.1, 1.6, 0.1, k.at(0, 0.2, -0.24, -10, 0, 0), C(255, 210, 90), M.Neon)
	for _, i in { -2, -1, 1, 2 } do
		k.box(0.08, 0.6, 0.08, k.at(i * 0.28, 0.25 - math.abs(i) * 0.1, -0.22, -10, 0, i * -24), C(255, 150, 50), M.Neon)
	end
	k.box(1.0, 0.18, 0.6, k.at(0, -0.84, 0.12), C(60, 40, 35), M.Basalt)
end

Models.molten_crown = function(k)
	local rock = C(45, 35, 35)
	k.torus(0.88, 0.32, 14, k.at(0, -0.5, 0, 90, 0, 0), rock, M.Basalt)
	k.torus(0.9, 0.1, 16, k.at(0, -0.36, 0, 90, 0, 0), LAVA, M.Neon)
	for i = 1, 7 do
		local a = i / 7 * 2 * math.pi
		local tall = i % 2 == 0
		k.cone(if tall then 1.3 else 0.95, 0.36, 4, onRing(k, a, 0.88, -0.38, 12), if tall then C(255, 200, 90) else LAVA, M.Neon)
	end
	-- Lava dripping off the band.
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi + 0.3
		k.ball(0.14, 0.34, 0.14, k.at(math.cos(a) * 0.98, -0.78, math.sin(a) * 0.98), LAVA, M.Neon)
	end
	k.ball(0.4, 0.5, 0.22, k.at(0, -0.48, -1.02), C(255, 40, 20), M.Glass)
end

Models.forge_hammer = function(k)
	local steel = k.main
	k.vcyl(1.8, 0.22, k.at(0, 0, 0), C(90, 60, 40), M.Wood)
	for i = 0, 3 do
		k.vcyl(0.1, 0.27, k.at(0, -0.72 + i * 0.16, 0), C(60, 40, 30), M.Fabric)
	end
	k.vcyl(0.14, 0.36, k.at(0, -0.86, 0), steel, M.Metal)
	-- A head the size of an anvil, its faces still glowing from the forge.
	k.box(1.4, 0.8, 0.8, k.at(0, 0.95, 0), steel, M.Metal)
	for _, side in { -1, 1 } do
		k.box(0.22, 0.95, 0.95, k.at(side * 0.75, 0.95, 0), steel:Lerp(WHITE, 0.15), M.Metal)
		k.box(0.04, 0.8, 0.8, k.at(side * 0.87, 0.95, 0), C(255, 120, 30), M.Neon)
		k.box(0.08, 0.84, 0.84, k.at(side * 0.38, 0.95, 0), GOLD, M.Metal)
	end
	for i = -1, 1 do
		k.box(0.12, 0.3, 0.04, k.at(i * 0.14, 0.95, -0.41), C(255, 170, 60), M.Neon)
	end
end

Models.heart_of_cinder = function(k)
	local rock = C(40, 30, 30)
	k.ball(1.2, 0.3, 1.0, k.at(0, -0.82, 0), C(70, 50, 40), M.Basalt)
	heart(k, 0.15, 2.0, rock, M.Basalt)
	-- Lava running through the cracks.
	local cracks = {
		{ -0.4, 0.75, 30, 0.45 },
		{ -0.2, 0.4, -35, 0.45 },
		{ 0.02, 0.05, 40, 0.5 },
		{ 0.38, 0.62, -20, 0.5 },
		{ 0.22, 0.28, 55, 0.35 },
		{ 0, -0.35, -10, 0.4 },
	}
	for _, c in cracks do
		k.box(0.07, c[4], 0.06, k.at(c[1], c[2], -0.48, 0, 0, c[3]), LAVA, M.Neon)
	end
	-- Stubby veins on top, still smoking hot.
	for _, x in { -0.25, 0.15 } do
		k.vcyl(0.35, 0.28, k.at(x, 1.12, 0.05), rock, M.Basalt)
		k.vcyl(0.05, 0.2, k.at(x, 1.3, 0.05), LAVA, M.Neon)
	end
end

Models.phoenix_egg = function(k)
	k.ball(1.4, 0.3, 1.4, k.at(0, -0.8, 0), C(60, 40, 30), M.Basalt)
	-- Flame feathers cradling the egg, fanned outward.
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		local base = onRing(k, a, 0.72, -0.55, 35)
		k.ball(0.08, 0.95, 0.4, base * CFrame.new(0, 0.3 * k.s, 0), C(255, 70, 20), M.Neon)
		k.ball(0.07, 0.4, 0.22, base * CFrame.new(0, 0.8 * k.s, 0), C(255, 210, 60), M.Neon)
	end
	k.ball(1.5, 1.95, 1.5, k.at(0, 0.2, 0), C(235, 95, 30), M.Metal, { R = 0.2 })
	k.torus(0.74, 0.08, 16, k.at(0, 0.2, 0, 90, 0, 15), C(255, 210, 70), M.Neon)
	-- It's hatching: a zigzag crack of light across the front.
	for i = 0, 3 do
		k.box(0.07, 0.32, 0.06, k.at(-0.3 + i * 0.2, 0.6 + (i % 2) * 0.12, -0.72, 0, 0, if i % 2 == 0 then -40 else 40), C(255, 245, 190), M.Neon)
	end
end

-- RIMEHEART ---------------------------------------------------------------------------------

Models.glacier_pearl = function(k)
	k.ball(1.9, 0.5, 1.5, k.at(0, -0.65, 0), ICE, M.Glass, { T = 0.3 })
	k.ball(1.9, 0.5, 1.5, k.at(0, 0.3, 0.6, -55, 0, 0), ICE, M.Glass, { T = 0.3 })
	for i = -2, 2 do
		k.box(0.05, 0.05, 1.2, k.at(i * 0.3, 0.32, 0.62, -55, i * 10, 0), WHITE, M.Ice)
	end
	-- The pearl, huge and moon-bright.
	k.ball(1.0, 1.0, 1.0, k.at(0, -0.15, -0.05), C(245, 250, 255), M.SmoothPlastic, { R = 0.35 })
	k.ball(0.5, 0.5, 0.5, k.at(-0.12, 0.0, -0.3), WHITE, M.Neon, { T = 0.6 })
	for _, x in { -0.85, 0.85 } do
		shard(k, k.at(x, -0.8, -0.35, 0, 0, x * -25), 0.14, 0.35, ICE, M.Glass)
	end
end

Models.frozen_compass = function(k)
	-- A brass compass trapped in a block of ice, needle frozen mid-spin.
	k.cyl(0.2, 1.25, k.at(0, 0, 0, 0, 90, 0), GOLD, M.Metal, { R = 0.2 })
	k.cyl(0.05, 1.05, k.at(0, 0, -0.1, 0, 90, 0), C(240, 230, 200), M.SmoothPlastic)
	k.box(0.1, 0.45, 0.03, k.at(0.07, 0.19, -0.14, 0, 0, -20), C(220, 40, 40), M.Neon)
	k.box(0.1, 0.45, 0.03, k.at(-0.07, -0.19, -0.14, 0, 0, -20), WHITE, M.SmoothPlastic)
	k.torus(0.12, 0.05, 8, k.at(0, 0.7, 0), GOLD, M.Metal)
	k.box(1.75, 1.75, 1.75, k.at(0, 0, 0, 0, 20, 0), C(190, 235, 255), M.Glass, { T = 0.55 })
	k.box(1.8, 0.16, 1.8, k.at(0, 0.95, 0, 0, 20, 0), WHITE, M.Snow)
	for i = 1, 3 do
		k.box(0.08, 0.3 + i * 0.1, 0.08, k.at(-0.6 + i * 0.3, -0.72 - i * 0.02, -0.72, 0, 20, 0), WHITE, M.Ice)
	end
end

Models.wyrm_fang = function(k)
	k.vcyl(0.4, 0.95, k.at(-0.35, -0.72, 0), C(120, 170, 200), M.Ice)
	for i = 0, 8 do
		local t = i / 8
		local d = 0.85 * (1 - t * 0.85)
		k.ball(d, 0.45, d, k.at(-0.35 + t * t * 0.9, -0.62 + t * 1.85, 0, 0, 0, -t * 40), k.main:Lerp(C(255, 250, 235), t), M.Marble)
	end
	k.torus(0.4, 0.07, 10, k.at(-0.35, -0.42, 0, 90, 0, 0), C(160, 230, 255), M.Neon)
	k.ball(0.28, 0.34, 0.18, k.at(-0.35, -0.2, -0.38), C(60, 170, 255), M.Neon)
end

Models.aurora_harp = function(k)
	local frame = C(225, 240, 255)
	k.ball(1.4, 0.25, 0.8, k.at(-0.1, -0.82, 0), WHITE, M.Snow)
	k.vcyl(2.05, 0.2, k.at(-0.8, 0.22, 0), frame, M.Marble)
	-- Soundbox slanting up from the pillar's foot, a swan-neck curling across the top.
	k.box(0.3, 2.4, 0.4, k.at(0.05, 0.1, 0, 0, 0, -39.8), frame, M.Marble)
	for i = 0, 8 do
		local t = i / 8
		k.ball(0.24, 0.24, 0.24, k.at(-0.8 + 1.6 * t, 1.15 + 0.12 * math.sin(2 * math.pi * t) - 0.1 * t, 0), GOLD, M.Metal)
	end
	-- Strings of light, each a different colour of the aurora.
	for i = 0, 6 do
		local x = -0.6 + i * 0.2
		local t = (x + 0.8) / 1.6
		local top = 1.1 + 0.12 * math.sin(2 * math.pi * t) - 0.1 * t
		local bottom = -0.8 + (x + 0.7) * 1.2 + 0.12
		k.box(0.05, top - bottom, 0.05, k.at(x, (top + bottom) / 2, 0), AURORA[i % #AURORA + 1], M.Neon)
	end
end

Models.crown_of_winter = function(k)
	local silver = C(200, 215, 235)
	k.torus(0.8, 0.24, 16, k.at(0, -0.5, 0, 90, 0, 0), silver, M.Metal, { R = 0.3 })
	k.torus(0.82, 0.07, 18, k.at(0, -0.34, 0, 90, 0, 0), C(150, 230, 255), M.Neon)
	for i = 1, 9 do
		local a = i / 9 * 2 * math.pi
		local height = if i % 3 == 0 then 1.35 elseif i % 3 == 1 then 0.9 else 0.65
		shard(k, onRing(k, a, 0.8, -0.42, 10), 0.22, height, k.main, M.Glass, { T = 0.15 })
	end
	k.ball(0.45, 0.55, 0.24, k.at(0, -0.48, -0.9), C(40, 120, 255), M.Glass)
	k.ball(0.2, 0.25, 0.1, k.at(0, -0.46, -1.0), C(150, 220, 255), M.Neon)
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi + 0.4
		k.ball(0.3, 0.22, 0.3, k.at(math.cos(a) * 0.85, -0.66, math.sin(a) * 0.85), WHITE, M.Snow)
	end
end

Models.everfrost_core = function(k)
	k.ball(1.6, 0.25, 1.6, k.at(0, -0.85, 0), ICE, M.Ice)
	-- A diamond of ice standing on its tip, a cold sun burning inside.
	k.box(1.2, 1.2, 1.2, k.at(0, 0.25, 0, 45, 0, 35.26), k.main:Lerp(WHITE, 0.3), M.Glass, { T = 0.35 })
	k.ball(0.75, 0.75, 0.75, k.at(0, 0.25, 0), C(160, 245, 255), M.Neon)
	k.torus(1.05, 0.06, 20, k.at(0, 0.25, 0, 75, 0, 0), C(120, 220, 255), M.Neon, { T = 0.2 })
	k.torus(0.95, 0.05, 18, k.at(0, 0.25, 0, 75, 60, 0), C(200, 250, 255), M.Neon, { T = 0.3 })
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi + 0.5
		k.box(0.24, 0.24, 0.24, k.at(math.cos(a) * 1.0, 0.25 + math.sin(a * 2) * 0.35, math.sin(a) * 1.0, 45, 0, 35.26), ICE, M.Glass)
	end
end

-- STARFALL ISLES ----------------------------------------------------------------------------

Models.moondust_pouch = function(k)
	k.ball(1.4, 1.3, 1.3, k.at(0, -0.3, 0), k.main, M.Fabric)
	k.vcyl(0.3, 0.6, k.at(0, 0.45, 0), k.main, M.Fabric)
	k.torus(0.32, 0.08, 10, k.at(0, 0.4, 0, 90, 0, 0), GOLD, M.Metal)
	k.ball(0.85, 0.3, 0.85, k.at(0, 0.66, 0), k.main:Lerp(WHITE, 0.2), M.Fabric)
	-- A crescent moon stitched on the front.
	k.ball(0.5, 0.5, 0.05, k.at(0, -0.25, -0.66), C(255, 240, 180), M.Neon)
	k.ball(0.42, 0.42, 0.06, k.at(0.13, -0.19, -0.68), k.main, M.Fabric)
	-- Glowing dust heaped in the mouth and spilling over the side.
	k.ball(0.6, 0.35, 0.6, k.at(0, 0.8, 0), C(225, 215, 255), M.Neon)
	for i = 1, 6 do
		local t = i / 6
		local size = 0.3 * (1 - t * 0.6)
		k.ball(size, size, size, k.at(0.3 + t * 0.75, 0.75 - t * t * 1.4, -0.1), C(225, 215, 255):Lerp(C(150, 220, 255), t), M.Neon, { T = t * 0.4 })
	end
end

Models.stardust_vial = function(k)
	-- A tall vial in a little gold cage, swirling with gold dust.
	k.vcyl(1.5, 0.75, k.at(0, 0.1, 0), C(230, 240, 255), M.Glass, { T = 0.6 })
	k.ball(0.75, 0.45, 0.75, k.at(0, -0.65, 0), C(230, 240, 255), M.Glass, { T = 0.6 })
	k.vcyl(0.9, 0.6, k.at(0, -0.3, 0), C(255, 215, 100), M.Neon, { T = 0.25 })
	for i = 1, 5 do
		local a = i * 1.3
		k.box(0.08, 0.08, 0.08, k.at(math.cos(a) * 0.2, 0.2 + i * 0.1, math.sin(a) * 0.2, 45, 45, 0), WHITE, M.Neon)
	end
	k.vcyl(0.3, 0.55, k.at(0, 0.98, 0), C(160, 110, 70), M.Wood)
	for _, y in { -0.55, 0.55 } do
		k.torus(0.44, 0.07, 12, k.at(0, y, 0, 90, 0, 0), GOLD, M.Metal)
	end
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		k.box(0.07, 1.4, 0.07, k.at(math.cos(a) * 0.44, 0, math.sin(a) * 0.44), GOLD, M.Metal)
	end
	starShape(k, k.at(0.5, 0.95, -0.2, 0, 0, 15), 0.22, 0.06, GOLD, M.Metal)
end

Models.comet_shard = function(k)
	k.ball(0.55, 0.4, 0.5, k.at(0.7, -0.75, 0.2), C(70, 70, 90), M.Slate)
	-- The shard, blazing, its tail streaming up behind it.
	k.box(1.0, 1.0, 1.0, k.at(0.45, -0.28, 0, 45, 0, 35.26), C(200, 240, 255), M.Glass, { T = 0.3 })
	k.box(0.65, 0.65, 0.65, k.at(0.45, -0.28, 0, 45, 0, 35.26), C(220, 245, 255), M.Neon)
	for i = 1, 7 do
		local t = i / 7
		local size = 0.8 * (1 - t * 0.7)
		k.ball(size, size * 1.7, size, k.at(0.45 - t * 1.3, -0.25 + t * 1.45, 0, 0, 0, 41), C(150, 220, 255):Lerp(C(190, 120, 255), t), M.Neon, { T = 0.1 + t * 0.5 })
	end
	for i = 1, 4 do
		k.box(0.1, 0.1, 0.1, k.at(-0.2 + i * 0.12, 0.4 + (i % 2) * 0.35, 0.3 - i * 0.12, 45, 45, 0), WHITE, M.Neon)
	end
end

Models.astrolabe = function(k)
	local gold = k.main
	k.vcyl(0.22, 0.9, k.at(0, -0.82, 0), DARK, M.Metal)
	k.vcyl(2.05, 0.06, k.at(0, 0.3, 0), gold, M.Metal)
	-- Rings inside rings, each tilted to its own sky.
	k.torus(1.0, 0.1, 22, k.at(0, 0.3, 0), gold, M.Metal, { R = 0.3 })
	k.torus(0.8, 0.09, 18, k.at(0, 0.3, 0, 0, 60, 0), gold, M.Metal, { R = 0.3 })
	k.torus(0.62, 0.08, 14, k.at(0, 0.3, 0, 90, 0, 0), C(170, 210, 255), M.Metal, { R = 0.3 })
	k.torus(0.45, 0.07, 12, k.at(0, 0.3, 0, 40, -30, 0), gold, M.Metal)
	-- Tiny planets riding the rings.
	local planets = { { 1.0, 0.3, 0, C(255, 120, 80) }, { -0.4, 0.3 + 0.69, 0.4, C(120, 200, 255) }, { 0, 0.3, -0.62, C(170, 255, 170) } }
	for _, p in planets do
		k.ball(0.2, 0.2, 0.2, k.at(p[1], p[2], p[3]), p[4], M.Neon)
	end
	k.ball(0.32, 0.32, 0.32, k.at(0, 0.3, 0), C(255, 240, 180), M.Neon)
	starShape(k, k.at(0, 0.3, 0), 0.32, 0.06, C(255, 250, 220), M.Neon)
end

Models.nebula_orb = function(k)
	local metal = C(40, 30, 60)
	k.vcyl(0.2, 1.0, k.at(0, -0.8, 0), metal, M.Metal)
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		k.box(0.12, 0.6, 0.12, onRing(k, a, 0.45, -0.72, 35) * CFrame.new(0, 0.3 * k.s, 0), metal, M.Metal)
	end
	-- A whole galaxy in a glass ball: swirling clouds and pinprick stars.
	local clouds = {
		{ -0.3, 0.45, 0.1, 1.15, C(190, 90, 255) },
		{ 0.3, 0.15, -0.1, 1.0, C(255, 110, 210) },
		{ 0.05, 0.7, -0.25, 0.8, C(90, 220, 255) },
		{ 0, 0.1, 0.25, 0.75, C(120, 80, 255) },
	}
	for _, c in clouds do
		k.ball(c[4], c[4] * 0.7, c[4], k.at(c[1], c[2], c[3], 0, 0, 20), c[5], M.Neon, { T = 0.35 })
	end
	for i = 0, 9 do
		local a = i * 0.7
		local r = 0.1 + i * 0.06
		k.ball(0.1, 0.1, 0.1, k.at(math.cos(a) * r, 0.3 + math.sin(a * 1.7) * 0.2, math.sin(a) * r), WHITE, M.Neon)
	end
	k.ball(1.9, 1.9, 1.9, k.at(0, 0.3, 0), C(220, 200, 255), M.Glass, { T = 0.7 })
end

Models.fallen_star = function(k)
	-- Crater: a glowing floor ringed by smashed rock.
	k.ball(1.7, 0.2, 1.7, k.at(0, -0.85, 0), C(255, 180, 60), M.Neon)
	for i = 1, 9 do
		local a = i / 9 * 2 * math.pi
		k.ball(0.5, 0.3, 0.4, k.at(math.cos(a) * 0.95, -0.78, math.sin(a) * 0.95, 0, -math.deg(a), 20), C(60, 50, 60), M.Basalt)
	end
	-- The star itself, stuck in at an angle, blazing.
	local cf = k.at(0, 0.3, 0, -10, 0, 8)
	starShape(k, cf, 1.0, 0.35, k.main, M.Neon)
	k.ball(0.6, 0.6, 0.5, cf, C(255, 250, 220), M.Neon)
	starShape(k, cf * CFrame.new(0, 0, -0.2 * k.s), 0.55, 0.06, WHITE, M.Neon, { T = 0.2 })
end

Models.celestial_crown = function(k)
	local gold = C(255, 235, 170)
	local divine = C(0, 229, 255)
	k.torus(0.82, 0.28, 16, k.at(0, -0.5, 0, 90, 0, 0), gold, M.Metal, { R = 0.3 })
	k.torus(0.85, 0.07, 18, k.at(0, -0.32, 0, 90, 0, 0), divine, M.Neon)
	k.torus(0.85, 0.07, 18, k.at(0, -0.68, 0, 90, 0, 0), divine, M.Neon)
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi + math.pi / 2
		k.cone(0.9, 0.28, 4, onRing(k, a, 0.82, -0.4, 8), gold, M.Metal)
		starShape(k, k.at(math.cos(a) * 0.92, 0.62, math.sin(a) * 0.92, 0, 90 - math.deg(a), 0), 0.26, 0.08, WHITE, M.Neon)
		local b = a + math.pi / 5
		k.ball(0.22, 0.28, 0.12, k.at(math.cos(b) * 0.99, -0.5, math.sin(b) * 0.99, 0, 90 - math.deg(b), 0), if i % 2 == 0 then divine else C(200, 120, 255), M.Glass)
	end
	-- A star hovering over the crown, with a halo.
	starShape(k, k.at(0, 0.85, 0), 0.45, 0.14, C(255, 250, 220), M.Neon)
	k.torus(0.55, 0.05, 18, k.at(0, 1.32, 0, 90, 0, 0), divine, M.Neon, { T = 0.2 })
end

-- OG ----------------------------------------------------------------------------------------

Models.first_doubloon = function(k)
	local gold = k.main
	k.cyl(0.28, 2.0, k.at(0, 0.2, 0, 0, 90, 0), gold, M.Metal, { R = 0.4 })
	k.torus(0.92, 0.12, 18, k.at(0, 0.2, 0), gold:Lerp(WHITE, 0.2), M.Metal)
	-- Embossed crown and skull, a shine streak.
	k.ball(0.45, 0.42, 0.1, k.at(0, 0.05, -0.16), gold:Lerp(DARK, 0.25), M.Metal)
	for i = -1, 1 do
		k.wedge(0.12, 0.25, 0.08, k.at(i * 0.18, 0.55, -0.16), gold:Lerp(DARK, 0.25), M.Metal)
	end
	k.box(0.08, 1.4, 0.05, k.at(-0.35, 0.3, -0.17, 0, 0, -30), WHITE, M.Neon, { T = 0.3 })
	-- A stack of lesser coins it stands on.
	for i = 0, 3 do
		k.coin(1.3 - i * 0.05, k.at(0.02 * i, -0.85 + i * 0.09, 0.02 * i))
	end
end

-- THE SECOND HAUL: more treasure for every region (so you don't keep finding the same thing),
-- plus the EVENT treasures that only ever appear when an admin drops them.

local function lantern(k: Kit, frame: Color3, glow: Color3, glass: Color3)
	k.box(1.0, 0.14, 1.0, k.at(0, -0.8, 0), frame, M.Metal)
	k.box(0.85, 1.1, 0.85, k.at(0, -0.15, 0), glass, M.Glass, { T = 0.5 })
	k.ball(0.55, 0.7, 0.55, k.at(0, -0.2, 0), glow, M.Neon)
	for _, x in { -0.45, 0.45 } do
		for _, z in { -0.45, 0.45 } do
			k.box(0.08, 1.2, 0.08, k.at(x, -0.15, z), frame, M.Metal)
		end
	end
	k.wedge(1.0, 0.4, 0.5, k.at(0, 0.6, -0.25), frame, M.Metal)
	k.wedge(1.0, 0.4, 0.5, k.at(0, 0.6, 0.25, 0, 180, 0), frame, M.Metal)
	k.torus(0.2, 0.07, 8, k.at(0, 1.0, 0), frame, M.Metal)
end

-- A crown: band + points + jewels. `y`/`size` place a smaller one on top of something.
local function crown(k: Kit, band: Color3, mat: Enum.Material, points: number, jewel: Color3, y: number?, size: number?)
	local y0, f = y or -0.45, size or 1
	k.torus(0.8 * f, 0.26 * f, 16, k.at(0, y0, 0, 90, 0, 0), band, mat, { R = 0.25 })
	for i = 1, points do
		local a = i / points * 2 * math.pi
		k.cone(0.8 * f, 0.26 * f, 3, onRing(k, a, 0.8 * f, y0 + 0.1 * f, 8), band, mat)
		k.ball(0.2 * f, 0.2 * f, 0.2 * f, k.at(math.cos(a) * 0.88 * f, y0 + 0.95 * f, math.sin(a) * 0.88 * f), jewel, M.Glass)
	end
end

local function egg(k: Kit, shell: Color3, mat: Enum.Material, spots: Color3)
	k.ball(1.35, 1.8, 1.35, k.at(0, 0.05, 0), shell, mat)
	for i = 1, 7 do
		local a = i * 2.1
		local y = -0.5 + (i % 4) * 0.35
		local r = 0.64 * math.sqrt(1 - (y / 0.95) ^ 2)
		k.ball(0.26, 0.22, 0.08, k.at(math.cos(a) * r, y, math.sin(a) * r, 0, -math.deg(a) + 90, 0), spots, M.Neon)
	end
	k.ball(1.6, 0.25, 1.6, k.at(0, -0.85, 0), C(120, 100, 80), M.Grass)
end

local function orbOnStand(k: Kit, stand: Color3, orb: Color3, mat: Enum.Material, extra)
	k.vcyl(0.22, 0.95, k.at(0, -0.82, 0), stand, M.Metal)
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		k.box(0.1, 0.55, 0.1, onRing(k, a, 0.42, -0.72, 35) * CFrame.new(0, 0.28 * k.s, 0), stand, M.Metal)
	end
	return k.ball(1.4, 1.4, 1.4, k.at(0, 0.15, 0), orb, mat, extra)
end

-- WILDS ---------------------------------------------------------------------------------------

Models.acorn_cache = function(k)
	for i, spec in { { 0, -0.35, 0, 1.0 }, { -0.6, -0.55, 0.3, 0.7 }, { 0.6, -0.6, -0.1, 0.65 }, { 0.15, -0.6, 0.6, 0.6 } } do
		local s = spec[4]
		local cf = k.at(spec[1], spec[2], spec[3], 0, i * 40, (i % 2) * 15 - 7)
		k.ball(0.8 * s, 1.0 * s, 0.8 * s, cf, if i == 1 then GOLD else C(170, 110, 50), if i == 1 then M.Metal else M.Wood, { R = if i == 1 then 0.3 else 0 })
		k.ball(0.9 * s, 0.45 * s, 0.9 * s, cf * CFrame.new(0, 0.42 * s * k.s, 0), C(110, 75, 40), M.Wood)
		k.vcyl(0.25 * s, 0.1 * s, cf * CFrame.new(0, 0.7 * s * k.s, 0), C(90, 60, 30), M.Wood)
	end
	for i = 1, 3 do
		k.ball(0.55, 0.06, 0.3, k.at(-0.4 + i * 0.3, -0.85, -0.55, 0, i * 50, 0), C(200, 120, 40), M.Grass)
	end
end

Models.carved_whistle = function(k)
	-- A wooden bird whistle: round body, a beak spout, carved wings.
	k.ball(1.3, 1.0, 1.0, k.at(0, -0.2, 0), k.main, M.Wood)
	k.ball(0.7, 0.65, 0.65, k.at(-0.55, 0.3, 0), k.main, M.Wood)
	k.wedge(0.25, 0.25, 0.45, k.at(-0.95, 0.3, 0, 0, -90, 0), C(230, 170, 60), M.Wood)
	eyes(k, 0.45, -0.25, 0.18, 0.18)
	for _, z in { -0.5, 0.5 } do
		k.ball(0.7, 0.3, 0.12, k.at(0.2, -0.05, z, 0, 0, -20), k.main:Lerp(DARK, 0.25), M.Wood)
	end
	k.vcyl(0.6, 0.3, k.at(0.75, 0.05, 0, 0, 0, -60), k.main:Lerp(DARK, 0.2), M.Wood)
	k.box(0.25, 0.08, 0.08, k.at(0, -0.1, -0.52), DARK)
end

Models.lucky_horseshoe = function(k)
	for i = 0, 8 do
		local a = rad(-20 + i * 27.5)
		k.box(0.42, 0.34, 0.3, k.at(math.cos(a) * 0.72, math.sin(a) * 0.72 + 0.05, 0, 0, 0, math.deg(a) + 90), k.main, M.Metal, { R = 0.35 })
		if i % 2 == 1 then
			k.ball(0.1, 0.1, 0.06, k.at(math.cos(a) * 0.72, math.sin(a) * 0.72 + 0.05, -0.16), GOLD, M.Metal)
		end
	end
	k.ball(0.35, 0.35, 0.1, k.at(0, -0.35, -0.1), C(80, 200, 90), M.Glass) -- a four-leaf clover charm
	for i = 0, 3 do
		k.ball(0.22, 0.3, 0.06, k.at(0, -0.35, -0.12, 0, 0, i * 90) * CFrame.new(0, 0.15 * k.s, 0), C(90, 210, 90), M.Grass)
	end
	k.box(0.08, 0.35, 0.06, k.at(0, -0.62, -0.12), C(60, 140, 60))
end

Models.honey_jar = function(k)
	k.vcyl(1.4, 1.35, k.at(0, -0.2, 0), k.main, M.Glass, { T = 0.25 })
	k.vcyl(1.1, 1.15, k.at(0, -0.3, 0), C(255, 170, 30), M.Neon, { T = 0.3 })
	k.vcyl(0.25, 1.45, k.at(0, 0.6, 0), C(200, 60, 50), M.Fabric)
	k.vcyl(0.12, 1.2, k.at(0, 0.8, 0), C(230, 200, 150), M.Fabric)
	-- Honey dripping over the rim, a dipper stuck in it, a fat bee.
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi
		k.ball(0.22, 0.45, 0.22, k.at(math.cos(a) * 0.68, 0.35, math.sin(a) * 0.68), C(255, 180, 30), M.Glass, { T = 0.1 })
	end
	k.cyl(1.2, 0.1, k.at(0.3, 1.0, 0, 0, 0, 65), WOOD, M.Wood)
	k.ball(0.3, 0.3, 0.3, k.at(0.55, 1.5, 0), C(230, 170, 40), M.Wood)
	k.ball(0.4, 0.3, 0.3, k.at(-0.7, 1.1, -0.2), C(255, 210, 40))
	k.box(0.08, 0.31, 0.31, k.at(-0.7, 1.1, -0.2), BLACK)
	k.ball(0.3, 0.1, 0.2, k.at(-0.7, 1.28, -0.1, 0, 0, 20), WHITE, M.Glass, { T = 0.4 })
end

Models.owl_totem = function(k)
	k.vcyl(1.5, 1.0, k.at(0, -0.3, 0), k.main, M.Wood)
	k.ball(1.2, 0.9, 1.1, k.at(0, 0.7, 0), k.main:Lerp(C(200, 170, 120), 0.3), M.Wood)
	for _, x in { -0.3, 0.3 } do
		k.cyl(0.08, 0.5, k.at(x, 0.75, -0.5, 0, 90, 0), C(240, 220, 170), M.Wood)
		k.cyl(0.1, 0.3, k.at(x, 0.75, -0.55, 0, 90, 0), C(255, 190, 40), M.Neon)
		k.wedge(0.2, 0.4, 0.2, k.at(x * 1.3, 1.25, 0), k.main:Lerp(DARK, 0.3), M.Wood) -- ear tufts
	end
	k.wedge(0.2, 0.25, 0.2, k.at(0, 0.5, -0.58, 0, 0, 180), C(230, 170, 60), M.Wood)
	for _, x in { -0.55, 0.55 } do
		k.ball(0.25, 1.1, 0.6, k.at(x, -0.2, 0, 0, 0, x * -20), k.main:Lerp(DARK, 0.25), M.Wood)
	end
	for i = 0, 2 do
		k.box(0.6, 0.06, 0.05, k.at(0, -0.1 - i * 0.3, -0.5), k.main:Lerp(DARK, 0.4), M.Wood)
	end
end

Models.fairy_lantern = function(k)
	lantern(k, C(140, 100, 60), C(255, 170, 240), C(255, 220, 250))
	-- Wings on the tiny fairy inside, glowing through the glass.
	for _, x in { -1, 1 } do
		k.ball(0.35, 0.5, 0.05, k.at(x * 0.18, 0, -0.05, 0, 0, x * -30), C(200, 240, 255), M.Glass, { T = 0.3 })
	end
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi
		k.ball(0.12, 0.12, 0.12, k.at(math.cos(a) * 0.95, 0.4 + (i % 2) * 0.4, math.sin(a) * 0.95), C(255, 230, 120), M.Neon)
	end
	for i = 1, 3 do
		k.ball(0.3, 0.2, 0.3, k.at(-0.3 + i * 0.25, 1.15, 0.1), C(255, 150, 200), M.Grass)
	end
end

Models.treant_heart = function(k)
	-- A knot of old wood holding a glowing green heart, roots and leaves sprouting.
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.cyl(1.0, 0.3, k.at(math.cos(a) * 0.5, -0.65, math.sin(a) * 0.5, 0, -math.deg(a), -25), C(100, 70, 40), M.Wood)
	end
	k.ball(1.4, 1.6, 1.3, k.at(0, 0.05, 0.1), C(120, 85, 50), M.Wood)
	-- The hollow in its trunk, and the glowing heart inside it.
	k.ball(1.0, 1.05, 0.3, k.at(0, 0.1, -0.5), C(55, 38, 22), M.Wood)
	local glow = k.main:Lerp(WHITE, 0.25)
	k.ball(0.42, 0.42, 0.3, k.at(-0.14, 0.24, -0.62), glow, M.Neon)
	k.ball(0.42, 0.42, 0.3, k.at(0.14, 0.24, -0.62), glow, M.Neon)
	k.box(0.36, 0.36, 0.26, k.at(0, 0.06, -0.62, 0, 0, 45), glow, M.Neon)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.ball(0.45, 0.14, 0.3, k.at(math.cos(a) * 0.5, 0.95 + (i % 2) * 0.15, math.sin(a) * 0.5, 0, -math.deg(a), 25), C(90, 190, 70), M.Grass)
	end
end

Models.golden_goose = function(k)
	local gold = k.main
	k.ball(1.6, 1.1, 1.1, k.at(0.1, -0.35, 0), gold, M.Metal, { R = 0.35 })
	k.vcyl(0.9, 0.35, k.at(-0.6, 0.35, 0, 0, 0, 15), gold, M.Metal, { R = 0.35 })
	k.ball(0.55, 0.5, 0.5, k.at(-0.75, 0.85, 0), gold, M.Metal, { R = 0.35 })
	k.wedge(0.25, 0.2, 0.4, k.at(-1.1, 0.8, 0, 0, -90, 0), C(255, 140, 40), M.SmoothPlastic)
	eyes(k, 0.95, -0.2, 0.12, 0.12)
	for _, z in { -0.5, 0.5 } do
		k.ball(1.0, 0.35, 0.15, k.at(0.3, -0.1, z, 0, 0, -15), gold:Lerp(WHITE, 0.2), M.Metal, { R = 0.35 })
	end
	k.wedge(0.5, 0.4, 0.3, k.at(0.95, -0.1, 0, 0, 90, 0), gold, M.Metal)
	-- The golden egg, just laid.
	k.ball(0.55, 0.72, 0.55, k.at(0.75, -0.6, -0.55), GOLD:Lerp(WHITE, 0.3), M.Neon)
end

-- COAST ---------------------------------------------------------------------------------------

Models.sea_glass = function(k)
	local colors = { C(120, 210, 200), C(90, 160, 220), C(160, 230, 170), C(220, 250, 250), C(70, 140, 120) }
	for i = 1, 7 do
		local a = i * 0.9
		local r = 0.25 + (i % 3) * 0.25
		k.box(0.45 + (i % 2) * 0.2, 0.3, 0.35, k.at(math.cos(a) * r, -0.7 + (i % 3) * 0.18, math.sin(a) * r, i * 20, i * 35, i * 15), colors[(i % #colors) + 1], M.Glass, { T = 0.25 })
	end
	k.ball(1.8, 0.2, 1.4, k.at(0, -0.9, 0), C(230, 210, 170), M.Sand)
	k.ball(0.35, 0.45, 0.2, k.at(0.5, -0.5, 0.4, 0, 30, 0), C(255, 200, 190), M.SmoothPlastic) -- a shell
end

Models.mermaid_comb = function(k)
	k.box(1.6, 0.5, 0.18, k.at(0, 0.3, 0), k.main, M.Marble)
	for i = 0, 11 do
		k.box(0.07, 0.8, 0.08, k.at(-0.72 + i * 0.13, -0.3, 0), k.main, M.Marble)
	end
	k.ball(0.5, 0.5, 0.25, k.at(0, 0.62, 0), C(255, 240, 250), M.Marble, { R = 0.2 })
	k.ball(0.3, 0.3, 0.3, k.at(0, 0.62, -0.1), C(120, 220, 255), M.Glass)
	for _, x in { -0.6, 0.6 } do
		k.ball(0.3, 0.3, 0.2, k.at(x, 0.35, -0.1), C(255, 150, 180), M.Glass)
	end
	k.box(0.05, 1.2, 0.05, k.at(0.3, -0.2, -0.12, 0, 0, 20), C(80, 190, 150), M.Neon, { T = 0.4 }) -- a strand of hair
end

Models.coral_tiara = function(k)
	k.torus(0.7, 0.14, 14, k.at(0, -0.6, 0, 90, 0, 0), C(255, 230, 220), M.Marble)
	for i = 1, 7 do
		local a = i / 7 * 2 * math.pi
		local base = onRing(k, a, 0.7, -0.55, 10)
		local h = 0.6 + (i % 3) * 0.25
		k.box(0.16, h, 0.16, base * CFrame.new(0, h / 2 * k.s, 0), k.main, M.Marble)
		k.box(0.12, h * 0.5, 0.12, base * CFrame.new(0.15 * k.s, h * 0.7 * k.s, 0) * CFrame.Angles(0, 0, rad(-35)), k.main:Lerp(WHITE, 0.2), M.Marble)
		k.ball(0.14, 0.14, 0.14, base * CFrame.new(0, h * k.s, 0), C(255, 220, 240), M.Marble)
	end
	k.ball(0.35, 0.35, 0.35, k.at(0, -0.3, -0.72), C(245, 240, 235), M.Marble, { R = 0.4 })
end

Models.cursed_doubloons = function(k)
	local gold = k.main
	for i = 0, 5 do
		k.coin(1.1 - i * 0.03, k.at(-0.25, -0.85 + i * 0.09, 0.1))
	end
	for i = 0, 3 do
		k.coin(1.0, k.at(0.45, -0.85 + i * 0.09, -0.2))
	end
	-- The cursed one standing up, a green skull on it, smoke curling off.
	k.cyl(0.14, 1.2, k.at(0, 0.05, -0.1, 0, 90, 0), gold:Lerp(C(120, 255, 140), 0.25), M.Metal, { R = 0.3 })
	k.ball(0.45, 0.42, 0.08, k.at(0, 0.1, -0.2), C(120, 255, 150), M.Neon)
	for _, x in { -0.1, 0.1 } do
		k.ball(0.1, 0.1, 0.05, k.at(x, 0.15, -0.25), BLACK)
	end
	for i = 1, 3 do
		k.ball(0.3 + i * 0.1, 0.25, 0.3 + i * 0.1, k.at(0.05 * i, 0.6 + i * 0.28, 0), C(120, 255, 150), M.Neon, { T = 0.45 + i * 0.12 })
	end
end

Models.leviathan_scale = function(k)
	-- One great scale, overlapping plates, a ridge down its spine, still wet.
	k.ball(1.9, 2.2, 0.35, k.at(0, 0.1, 0, 0, 0, 0), k.main, M.Glass, { T = 0.1, R = 0.2 })
	for i = 0, 3 do
		k.ball(1.5 - i * 0.3, 0.5, 0.36, k.at(0, 0.7 - i * 0.45, -0.05), k.main:Lerp(C(20, 60, 80), 0.3), M.Glass, { R = 0.25 })
	end
	k.box(0.12, 2.0, 0.4, k.at(0, 0.1, 0), C(200, 250, 255), M.Neon, { T = 0.3 })
	k.ball(2.0, 0.2, 1.2, k.at(0, -0.9, 0), C(60, 120, 150), M.Glass, { T = 0.4 })
end

Models.kraken_eye = function(k)
	-- A huge golden eye in a ring of tentacles.
	local eye = k.ball(1.6, 1.6, 1.3, k.at(0, 0.2, 0), C(255, 240, 210), M.SmoothPlastic)
	local _ = eye
	k.ball(1.0, 1.0, 0.4, k.at(0, 0.2, -0.5), k.main, M.Glass, { R = 0.2 })
	k.box(0.18, 0.8, 0.1, k.at(0, 0.2, -0.72), BLACK, M.SmoothPlastic)
	k.ball(0.2, 0.2, 0.1, k.at(-0.2, 0.45, -0.72), WHITE, M.Neon)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		for j = 0, 3 do
			local r = 0.85 + j * 0.2
			local d = 0.4 - j * 0.07
			k.ball(d, d, d, k.at(math.cos(a + j * 0.25) * r, -0.6 + j * 0.25 + math.sin(a) * 0.3, math.sin(a + j * 0.25) * r * 0.8), C(150, 50, 120), M.SmoothPlastic)
		end
	end
end

-- MARSH ---------------------------------------------------------------------------------------

Models.bog_bottle = function(k)
	k.ball(1.2, 1.2, 1.2, k.at(0, -0.35, 0), k.main, M.Glass, { T = 0.35 })
	k.vcyl(0.6, 0.4, k.at(0, 0.45, 0), k.main, M.Glass, { T = 0.35 })
	k.vcyl(0.25, 0.45, k.at(0, 0.85, 0), C(150, 110, 70), M.Wood)
	k.ball(0.9, 0.9, 0.9, k.at(0, -0.4, 0), C(120, 200, 60), M.Neon, { T = 0.4 })
	for i = 1, 4 do
		k.ball(0.18, 0.18, 0.18, k.at(-0.2 + i * 0.1, -0.2 + i * 0.12, -0.3), C(220, 255, 180), M.Neon, { T = 0.3 })
	end
	k.box(0.5, 0.35, 0.03, k.at(0, -0.35, -0.61), C(230, 210, 160), M.Fabric)
	k.ball(0.2, 0.2, 0.03, k.at(0, -0.32, -0.63), C(200, 40, 40), M.SmoothPlastic)
end

Models.lily_lantern = function(k)
	k.ball(1.8, 0.14, 1.8, k.at(0, -0.85, 0), C(70, 150, 70), M.Grass)
	k.box(0.5, 0.16, 0.9, k.at(0.55, -0.85, 0, 0, 30, 0), C(40, 40, 40), M.SmoothPlastic, { T = 1 })
	-- A lotus flower opening around a glowing bulb.
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		k.ball(0.35, 0.8, 0.12, onRing(k, a, 0.35, -0.4, 35), C(255, 200, 230), M.SmoothPlastic)
	end
	k.ball(0.55, 0.55, 0.55, k.at(0, -0.35, 0), C(255, 250, 180), M.Neon)
	k.cyl(0.05, 1.8, k.at(0, -0.8, 0, 0, 90, 0), C(60, 140, 60))
end

Models.firefly_crown = function(k)
	crown(k, C(90, 150, 60), M.Grass, 6, C(230, 255, 120))
	for i = 1, 9 do
		local a = i / 9 * 2 * math.pi
		k.ball(0.16, 0.16, 0.16, k.at(math.cos(a) * (0.5 + (i % 3) * 0.3), 0.7 + (i % 2) * 0.45, math.sin(a) * (0.5 + (i % 3) * 0.3)), C(240, 255, 140), M.Neon)
	end
end

Models.hex_doll = function(k)
	local cloth = k.main
	k.ball(0.9, 1.1, 0.7, k.at(0, -0.35, 0), cloth, M.Fabric)
	k.ball(0.8, 0.8, 0.7, k.at(0, 0.55, 0), cloth:Lerp(WHITE, 0.15), M.Fabric)
	for _, x in { -0.18, 0.18 } do
		k.box(0.14, 0.03, 0.05, k.at(x, 0.62, -0.35, 0, 0, 45), BLACK)
		k.box(0.14, 0.03, 0.05, k.at(x, 0.62, -0.35, 0, 0, -45), BLACK)
	end
	k.box(0.4, 0.03, 0.05, k.at(0, 0.38, -0.35, 0, 0, 5), C(200, 40, 40)) -- stitched mouth
	for _, x in { -0.6, 0.6 } do
		k.ball(0.3, 0.7, 0.3, k.at(x, -0.25, 0, 0, 0, x * 40), cloth, M.Fabric)
	end
	-- Pins stuck in it, glowing purple.
	for i = 1, 3 do
		local cf = k.at(-0.2 + i * 0.15, -0.2 + (i % 2) * 0.3, -0.3, 30, 0, -20 + i * 15)
		k.box(0.04, 0.6, 0.04, cf, C(200, 200, 210), M.Metal)
		k.ball(0.14, 0.14, 0.14, cf * CFrame.new(0, 0.3 * k.s, 0), C(200, 90, 255), M.Neon)
	end
end

Models.mushroom_king_cap = function(k)
	k.vcyl(0.9, 0.7, k.at(0, -0.45, 0), C(245, 235, 215), M.SmoothPlastic)
	k.ball(2.0, 1.0, 2.0, k.at(0, 0.25, 0), k.main, M.SmoothPlastic)
	for i = 1, 8 do
		local a = i * 2.4
		local r = 0.25 + (i % 3) * 0.2
		k.ball(0.28, 0.1, 0.28, k.at(math.cos(a) * r, 0.62 + (0.6 - r) * 0.3, math.sin(a) * r, 0, 0, 0), WHITE, M.SmoothPlastic)
	end
	-- A tiny crown on top, and a face on the stalk.
	crown(k, GOLD, M.Metal, 5, C(255, 60, 60), 0.72, 0.4)
	eyes(k, -0.35, -0.33, 0.14, 0.14)
end

Models.frog_prince_crown = function(k)
	-- A fat frog with a crown too big for him, sitting on a lily pad.
	k.ball(1.8, 0.14, 1.8, k.at(0, -0.9, 0), C(70, 150, 70), M.Grass)
	k.ball(1.2, 0.8, 1.1, k.at(0, -0.45, 0), C(90, 170, 80), M.SmoothPlastic)
	eyes(k, 0.02, -0.25, 0.32, 0.4)
	k.ball(0.8, 0.08, 0.2, k.at(0, -0.35, -0.5), DARK)
	k.ball(0.2, 0.12, 0.05, k.at(-0.35, -0.3, -0.53), C(240, 130, 150), M.SmoothPlastic)
	k.ball(0.2, 0.12, 0.05, k.at(0.35, -0.3, -0.53), C(240, 130, 150), M.SmoothPlastic)
	local band = k.at(0, 0.45, 0, 0, 0, 10)
	k.torus(0.45, 0.12, 12, band * CFrame.Angles(rad(90), 0, 0), k.main, M.Metal, { R = 0.3 })
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		k.wedge(0.16, 0.35, 0.1, band * CFrame.new(math.cos(a) * 0.45 * k.s, 0.2 * k.s, math.sin(a) * 0.45 * k.s) * CFrame.Angles(0, -a - math.pi / 2, 0), k.main, M.Metal)
	end
	k.ball(0.18, 0.18, 0.18, band * CFrame.new(0, 0.1 * k.s, -0.45 * k.s), C(220, 40, 60), M.Glass)
end

Models.witch_broom = function(k)
	local cf = k.at(0, 0.05, 0, 0, 0, -35)
	k.cyl(2.5, 0.14, cf, C(120, 80, 50), M.Wood)
	for i = 0, 11 do
		local a = i / 12 * 2 * math.pi
		k.cyl(0.9, 0.08, cf * CFrame.new(1.3 * k.s, math.cos(a) * 0.14 * k.s, math.sin(a) * 0.14 * k.s) * CFrame.Angles(0, math.sin(a) * rad(12), math.cos(a) * rad(12)), C(200, 170, 90), M.Grass)
	end
	k.cyl(0.2, 0.36, cf * CFrame.new(0.95 * k.s, 0, 0), C(140, 60, 180), M.Fabric)
	-- Purple sparks trailing off the bristles, a star on the handle.
	for i = 1, 4 do
		k.ball(0.15, 0.15, 0.15, cf * CFrame.new((1.9 + i * 0.18) * k.s, (i % 2 - 0.5) * 0.3 * k.s, 0), C(200, 110, 255), M.Neon, { T = i * 0.15 })
	end
	starShape(k, cf * CFrame.new(-1.3 * k.s, 0, 0), 0.22, 0.06, C(255, 230, 120), M.Neon)
end

Models.unicorn_horn = function(k)
	-- A spiral horn rising from a cloud, a rainbow wrapping it.
	k.ball(1.8, 0.6, 1.4, k.at(0, -0.75, 0), C(255, 245, 250), M.SmoothPlastic)
	k.ball(1.0, 0.5, 0.9, k.at(-0.5, -0.55, 0.2), C(255, 250, 255), M.SmoothPlastic)
	k.cone(2.0, 0.75, 7, k.at(0, -0.5, 0), k.main, M.Marble, { R = 0.2 })
	local rainbow = { C(255, 90, 90), C(255, 190, 60), C(255, 255, 90), C(90, 230, 110), C(90, 170, 255), C(190, 110, 255) }
	for i = 0, 11 do
		local t = i / 11
		local a = t * 4 * math.pi
		local r = 0.36 * (1 - t * 0.8)
		k.ball(0.14, 0.14, 0.14, k.at(math.cos(a) * r, -0.35 + t * 1.8, math.sin(a) * r), rainbow[(i % #rainbow) + 1], M.Neon)
	end
	starShape(k, k.at(0, 1.4, 0), 0.25, 0.06, WHITE, M.Neon)
end

-- RUINS ---------------------------------------------------------------------------------------

Models.sand_hourglass = function(k)
	for _, y in { -0.85, 0.85 } do
		k.vcyl(0.14, 1.3, k.at(0, y, 0), WOOD, M.Wood)
	end
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		k.vcyl(1.7, 0.1, k.at(math.cos(a) * 0.55, 0, math.sin(a) * 0.55), WOOD, M.Wood)
	end
	k.ball(0.9, 0.9, 0.9, k.at(0, 0.4, 0), C(220, 240, 255), M.Glass, { T = 0.6 })
	k.ball(0.9, 0.9, 0.9, k.at(0, -0.4, 0), C(220, 240, 255), M.Glass, { T = 0.6 })
	k.ball(0.6, 0.35, 0.6, k.at(0, -0.6, 0), k.main, M.Sand)
	k.ball(0.45, 0.3, 0.45, k.at(0, 0.35, 0), k.main, M.Sand)
	k.vcyl(0.35, 0.06, k.at(0, 0, 0), k.main, M.Neon)
end

Models.cobra_idol = function(k)
	-- A coiled cobra rearing up, hood spread, jewel eyes.
	for i = 0, 2 do
		k.torus(0.55 - i * 0.12, 0.2, 12, k.at(0, -0.75 + i * 0.2, 0, 90, 0, 0), k.main, M.Slate)
	end
	k.vcyl(1.0, 0.32, k.at(0, 0.1, 0.1, -10, 0, 0), k.main, M.Slate)
	k.ball(1.1, 1.0, 0.25, k.at(0, 0.75, 0.05), k.main, M.Slate)
	k.ball(0.8, 0.7, 0.26, k.at(0, 0.75, 0.02), C(230, 200, 90), M.Slate)
	k.ball(0.45, 0.35, 0.55, k.at(0, 0.8, -0.25), k.main, M.Slate)
	for _, x in { -0.13, 0.13 } do
		k.ball(0.12, 0.12, 0.1, k.at(x, 0.88, -0.48), C(255, 60, 60), M.Neon)
	end
	k.box(0.04, 0.2, 0.04, k.at(0, 0.65, -0.55, -30, 0, 0), C(220, 40, 60))
end

Models.sun_mirror = function(k)
	k.cyl(0.14, 1.6, k.at(0, 0.3, 0, 0, 90, 0), C(230, 240, 255), M.Glass, { R = 0.6 })
	k.torus(0.82, 0.12, 18, k.at(0, 0.3, 0), k.main, M.Metal, { R = 0.35 })
	for i = 1, 12 do
		local a = i / 12 * 2 * math.pi
		k.wedge(0.1, 0.35, 0.18, k.at(math.cos(a) * 1.05, 0.3 + math.sin(a) * 1.05, 0, 0, 90, math.deg(a) - 90), k.main, M.Metal)
	end
	k.vcyl(0.6, 0.2, k.at(0, -0.7, 0), k.main, M.Metal)
	k.vcyl(0.12, 0.8, k.at(0, -0.95, 0), k.main, M.Metal)
	k.ball(0.45, 0.45, 0.1, k.at(0.25, 0.55, -0.1), WHITE, M.Neon, { T = 0.4 })
end

Models.pharaoh_mask = function(k)
	local gold = k.main
	local lapis = C(30, 60, 160)
	k.box(1.6, 2.0, 0.3, k.at(0, 0.05, 0.15), lapis, M.Metal)
	for i = 0, 5 do
		k.box(1.62, 0.12, 0.32, k.at(0, 0.8 - i * 0.3, 0.15), gold, M.Metal, { R = 0.3 })
	end
	k.ball(1.05, 1.3, 0.8, k.at(0, 0.25, -0.1), gold, M.Metal, { R = 0.35 })
	for _, x in { -0.22, 0.22 } do
		k.ball(0.26, 0.14, 0.1, k.at(x, 0.35, -0.48), WHITE, M.SmoothPlastic)
		k.ball(0.12, 0.12, 0.1, k.at(x, 0.35, -0.53), BLACK, M.SmoothPlastic)
		k.box(0.35, 0.05, 0.05, k.at(x * 1.2, 0.35, -0.5, 0, 0, x * 40), BLACK)
	end
	k.box(0.3, 0.12, 0.08, k.at(0, -0.05, -0.47), C(200, 120, 60))
	k.box(0.14, 0.6, 0.16, k.at(0, -0.55, -0.35, -10, 0, 0), lapis, M.Metal) -- the beard
	k.box(0.3, 0.35, 0.14, k.at(0, 0.95, -0.4), gold, M.Metal) -- the cobra crest
end

Models.judgement_scales = function(k)
	local gold = k.main
	k.vcyl(0.14, 0.9, k.at(0, -0.85, 0), gold, M.Metal)
	k.vcyl(1.7, 0.12, k.at(0, 0, 0), gold, M.Metal)
	k.box(1.9, 0.1, 0.1, k.at(0, 0.8, 0, 0, 0, 8), gold, M.Metal)
	k.ball(0.25, 0.25, 0.25, k.at(0, 0.9, 0), C(60, 200, 220), M.Glass)
	for side, spec in { { -0.9, 0.95 }, { 0.9, 0.62 } } do
		local x, y = spec[1], spec[2]
		k.box(0.03, 0.5, 0.03, k.at(x, y - 0.25, 0), gold)
		k.cyl(0.08, 0.7, k.at(x, y - 0.55, 0, 0, 0, 90), gold, M.Metal)
		if side == 1 then
			heart(k, y - 0.35, 0.35, C(220, 40, 60), M.Glass) -- the heart...
		else
			k.ball(0.15, 0.55, 0.1, k.at(x, y - 0.25, 0, 0, 0, 25), WHITE, M.Neon) -- ...against a feather
		end
	end
end

Models.sphinx_head = function(k)
	local stone = k.main
	k.box(1.9, 0.4, 1.4, k.at(0, -0.8, 0), stone:Lerp(DARK, 0.2), M.Sandstone)
	-- Headdress falling to the shoulders, stripes, a calm (cracked) face.
	k.box(1.7, 1.2, 1.0, k.at(0, -0.1, 0.1), stone, M.Sandstone)
	k.wedge(1.7, 0.5, 1.0, k.at(0, 0.75, 0.1, 0, 180, 0), stone, M.Sandstone)
	for i = 0, 3 do
		k.box(1.72, 0.08, 1.02, k.at(0, -0.5 + i * 0.3, 0.1), C(60, 100, 170), M.Sandstone)
	end
	k.box(0.9, 1.0, 0.3, k.at(0, 0.05, -0.45), stone:Lerp(WHITE, 0.1), M.Sandstone)
	for _, x in { -0.2, 0.2 } do
		k.box(0.2, 0.08, 0.05, k.at(x, 0.25, -0.62), DARK)
	end
	k.box(0.15, 0.3, 0.14, k.at(0, 0.05, -0.64), stone, M.Sandstone)
	k.box(0.35, 0.05, 0.05, k.at(0, -0.2, -0.62), DARK)
	k.box(0.04, 0.7, 0.05, k.at(0.3, 0, -0.62, 0, 0, 20), DARK) -- a crack
end

-- FROSTPEAK -----------------------------------------------------------------------------------

Models.snow_globe = function(k)
	k.vcyl(0.35, 1.3, k.at(0, -0.75, 0), C(140, 90, 50), M.Wood)
	k.ball(1.6, 1.6, 1.6, k.at(0, 0.25, 0), C(220, 240, 255), M.Glass, { T = 0.6 })
	k.ball(1.2, 0.3, 1.2, k.at(0, -0.4, 0), WHITE, M.Snow)
	-- A tiny Frostpeak inside with a cabin.
	k.wedge(0.8, 0.8, 0.5, k.at(-0.2, 0.0, 0.1), C(200, 220, 240), M.Snow)
	k.wedge(0.8, 0.8, 0.5, k.at(-0.2, 0.0, 0.35, 0, 180, 0), C(200, 220, 240), M.Snow)
	k.box(0.3, 0.25, 0.3, k.at(0.35, -0.15, -0.2), C(140, 90, 60), M.Wood)
	k.box(0.08, 0.08, 0.02, k.at(0.35, -0.15, -0.36), C(255, 220, 120), M.Neon)
	for i = 1, 6 do
		k.ball(0.08, 0.08, 0.08, k.at(math.cos(i) * 0.5, 0.2 + (i % 3) * 0.2, math.sin(i) * 0.5), WHITE, M.Neon)
	end
end

Models.silver_skates = function(k)
	for _, x in { -0.4, 0.4 } do
		k.box(0.5, 0.9, 1.1, k.at(x, 0, 0.05), C(245, 245, 250), M.Fabric)
		k.box(0.5, 0.35, 0.5, k.at(x, -0.2, -0.55), C(245, 245, 250), M.Fabric)
		k.box(0.06, 0.1, 1.6, k.at(x, -0.7, -0.1), k.main, M.Metal, { R = 0.5 })
		k.box(0.06, 0.25, 0.08, k.at(x, -0.55, 0.45), k.main, M.Metal)
		k.box(0.06, 0.25, 0.08, k.at(x, -0.55, -0.5), k.main, M.Metal)
		for i = 0, 2 do
			k.box(0.52, 0.03, 0.05, k.at(x, 0.25 - i * 0.2, -0.47), C(200, 60, 60))
		end
	end
	k.cyl(0.9, 0.05, k.at(0, 0.6, 0.1), C(200, 60, 60))
end

Models.penguin_statue = function(k)
	k.ball(1.2, 1.7, 1.1, k.at(0, -0.1, 0), k.main, M.Marble)
	k.ball(0.85, 1.3, 0.3, k.at(0, -0.2, -0.45), WHITE, M.Marble)
	k.ball(0.8, 0.75, 0.75, k.at(0, 0.8, 0), k.main, M.Marble)
	eyes(k, 0.9, -0.3, 0.16, 0.18)
	k.wedge(0.2, 0.15, 0.3, k.at(0, 0.72, -0.45, 0, 180, 0), C(255, 160, 40), M.SmoothPlastic)
	for _, x in { -0.62, 0.62 } do
		k.ball(0.18, 0.9, 0.4, k.at(x, -0.1, 0, 0, 0, x * -25), k.main, M.Marble)
	end
	for _, x in { -0.25, 0.25 } do
		k.ball(0.35, 0.12, 0.5, k.at(x, -0.95, -0.2), C(255, 160, 40), M.SmoothPlastic)
	end
	k.box(0.7, 0.15, 0.1, k.at(0, 0.5, -0.35, 0, 0, 5), C(220, 40, 50), M.Fabric) -- a scarf
end

Models.frost_lantern = function(k)
	lantern(k, C(180, 200, 220), C(120, 210, 255), C(220, 245, 255))
	for i = 1, 5 do
		local x = -0.4 + i * 0.16
		k.box(0.08, 0.2 + (i % 2) * 0.15, 0.08, k.at(x, -0.95 - (i % 2) * 0.07, -0.5), C(220, 245, 255), M.Glass, { T = 0.2 })
	end
	k.ball(1.1, 0.2, 1.1, k.at(0, 0.8, 0), WHITE, M.Snow)
end

Models.icicle_scepter = function(k)
	k.vcyl(2.0, 0.16, k.at(0, -0.1, 0), C(200, 220, 240), M.Metal)
	k.ball(0.4, 0.3, 0.4, k.at(0, -1.0, 0), C(200, 220, 240), M.Metal)
	-- A burst of icicles for a head.
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		shard(k, k.at(math.cos(a) * 0.12, 0.85, math.sin(a) * 0.12, math.sin(a) * 30, 0, -math.cos(a) * 30), 0.18, 0.45, k.main, M.Glass, { T = 0.1 })
	end
	shard(k, k.at(0, 0.85, 0), 0.24, 0.6, WHITE, M.Glass, { T = 0.1 })
	k.ball(0.35, 0.35, 0.35, k.at(0, 0.9, 0), C(150, 220, 255), M.Neon)
end

Models.snow_owl_egg = function(k)
	egg(k, k.main, M.Marble, C(170, 220, 255))
	-- A crack with a little owl beak poking out.
	k.box(0.5, 0.05, 0.05, k.at(0, 0.5, -0.62, 0, 0, 15), DARK)
	k.wedge(0.16, 0.14, 0.2, k.at(0, 0.62, -0.68, 0, 180, 0), C(255, 170, 40), M.SmoothPlastic)
	for i = 1, 3 do
		k.ball(0.2, 0.5, 0.05, k.at(-0.4 + i * 0.2, 1.05, -0.2, 0, 0, (i - 2) * 20), WHITE, M.SmoothPlastic)
	end
end

Models.blizzard_orb = function(k)
	orbOnStand(k, C(180, 200, 220), C(200, 230, 255), M.Glass, { T = 0.55 })
	for i = 1, 10 do
		local a = i * 1.7
		k.ball(0.08, 0.08, 0.08, k.at(math.cos(a) * 0.45, 0.15 + math.sin(i) * 0.4, math.sin(a) * 0.45), WHITE, M.Neon)
	end
	k.torus(0.4, 0.06, 12, k.at(0, 0.15, 0, 70, 0, 0), C(220, 240, 255), M.Neon, { T = 0.35 })
	k.torus(0.28, 0.05, 10, k.at(0, 0.35, 0, 70, 50, 0), WHITE, M.Neon, { T = 0.3 })
end

-- THE FALLS -----------------------------------------------------------------------------------

Models.parrot_totem = function(k)
	k.vcyl(1.0, 0.8, k.at(0, -0.5, 0), WOOD, M.Wood)
	k.ball(0.9, 1.1, 0.9, k.at(0, 0.3, 0), k.main, M.Wood)
	k.ball(0.7, 0.65, 0.7, k.at(0, 0.95, -0.05), k.main, M.Wood)
	k.wedge(0.25, 0.4, 0.35, k.at(0, 0.85, -0.45, 0, 180, 180), C(255, 210, 60), M.Wood)
	eyes(k, 1.05, -0.3, 0.2, 0.16)
	for _, x in { -1, 1 } do
		for j = 0, 2 do
			k.ball(0.25, 0.8 - j * 0.15, 0.15, k.at(x * (0.48 + j * 0.08), 0.25 - j * 0.1, 0.1, 0, 0, x * (-15 - j * 10)), ({ C(60, 160, 240), C(250, 220, 60), C(80, 200, 90) })[j + 1], M.Wood)
		end
	end
	for i = 0, 2 do
		k.box(0.12, 0.8, 0.1, k.at(-0.12 + i * 0.12, -0.2, 0.45, 20, 0, (i - 1) * 12), ({ C(230, 60, 50), C(60, 160, 240), C(250, 220, 60) })[i + 1], M.Wood)
	end
end

Models.waterfall_pearl = function(k)
	-- A shell cradling a big pearl, water pouring off it.
	for i = 0, 6 do
		local a = rad(-70 + i * 23)
		k.ball(0.3, 1.2, 0.1, k.at(math.sin(a) * 0.55, -0.2 + math.cos(a) * 0.2, 0.35, -25, 0, math.deg(a)), C(255, 225, 220), M.Marble)
	end
	k.ball(1.6, 0.4, 1.2, k.at(0, -0.65, 0), C(255, 220, 215), M.Marble)
	k.ball(0.95, 0.95, 0.95, k.at(0, -0.1, -0.1), k.main, M.Glass, { R = 0.4 })
	k.ball(0.4, 0.4, 0.4, k.at(-0.18, 0.05, -0.35), WHITE, M.Neon, { T = 0.4 })
	for i = 1, 3 do
		k.box(0.25, 0.6, 0.06, k.at(-0.6 + i * 0.3, -1.0, -0.4), C(150, 210, 255), M.Glass, { T = 0.45 })
	end
end

Models.thunder_drum = function(k)
	k.vcyl(1.3, 1.5, k.at(0, -0.3, 0), k.main, M.Wood)
	k.vcyl(0.1, 1.55, k.at(0, 0.38, 0), C(240, 225, 190), M.Fabric)
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		k.box(0.05, 1.3, 0.05, k.at(math.cos(a) * 0.77, -0.3, math.sin(a) * 0.77, 0, 0, if i % 2 == 0 then 18 else -18), C(200, 170, 110), M.Fabric)
	end
	k.torus(0.76, 0.08, 16, k.at(0, -0.9, 0, 90, 0, 0), C(200, 60, 40), M.Fabric)
	-- A lightning bolt painted on, sticks crossed on top.
	for i, spec in { { 0.1, 0.05, 30 }, { -0.05, -0.25, -30 }, { 0.1, -0.55, 30 } } do
		local _ = i
		k.box(0.12, 0.4, 0.05, k.at(spec[1], spec[2], -0.76, 0, 0, spec[3]), C(255, 240, 100), M.Neon)
	end
	for _, rz in { 35, -35 } do
		k.cyl(1.3, 0.1, k.at(0, 0.6, 0, 0, 30, rz), WOOD, M.Wood)
	end
end

Models.rainbow_prism = function(k)
	k.box(1.2, 1.2, 1.2, k.at(0, 0.1, 0, 45, 0, 35.26), WHITE, M.Glass, { T = 0.4, R = 0.3 })
	local rainbow = { C(255, 80, 80), C(255, 170, 60), C(255, 240, 80), C(80, 230, 110), C(80, 170, 255), C(170, 100, 255) }
	for i, col in rainbow do
		k.box(1.2, 0.12, 0.06, k.at(0.9, -0.25 + i * 0.14, 0, 0, 0, -15 + i * 5), col, M.Neon, { T = 0.2 })
	end
	k.box(1.0, 0.1, 0.06, k.at(-0.9, 0.2, 0, 0, 0, 10), WHITE, M.Neon, { T = 0.3 })
	k.vcyl(0.2, 1.1, k.at(0, -0.85, 0), C(200, 200, 210), M.Metal)
end

Models.tide_idol = function(k)
	local stone = k.main
	k.box(1.4, 1.9, 0.9, k.at(0, 0, 0), stone, M.Slate)
	k.ball(1.2, 0.8, 1.0, k.at(0, 0.95, 0), stone, M.Slate)
	for _, x in { -0.3, 0.3 } do
		k.box(0.3, 0.14, 0.1, k.at(x, 0.55, -0.46), C(100, 220, 255), M.Neon)
	end
	k.box(0.6, 0.12, 0.1, k.at(0, 0.1, -0.46), C(20, 40, 60))
	-- Waves carved around it, water streaming down.
	for i = 0, 2 do
		k.torus(0.8, 0.12, 14, k.at(0, -0.6 + i * 0.4, 0, 90, 0, 0), C(60, 170, 230), M.Glass, { T = 0.25 })
	end
	for _, x in { -0.5, 0.5 } do
		k.box(0.2, 1.4, 0.05, k.at(x, 0, -0.48), C(150, 220, 255), M.Glass, { T = 0.4 })
	end
end

Models.thunderbird_egg = function(k)
	egg(k, k.main, M.Slate, C(160, 220, 255))
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		for j = 0, 2 do
			k.box(0.08, 0.35, 0.08, k.at(math.cos(a) * (0.5 + j * 0.2), 0.3 + j * 0.35, math.sin(a) * (0.5 + j * 0.2), 0, -math.deg(a), if j % 2 == 0 then 30 else -30), C(200, 240, 255), M.Neon)
		end
	end
	for _, x in { -0.4, 0.4 } do
		k.ball(0.6, 1.0, 0.1, k.at(x * 1.8, 0.5, 0.2, 0, 0, x * -60), C(70, 90, 160), M.SmoothPlastic)
	end
end

-- EMBERFALL -----------------------------------------------------------------------------------

Models.magma_marble = function(k)
	k.ball(1.4, 1.4, 1.4, k.at(0, -0.15, 0), C(60, 30, 25), M.Basalt)
	for i = 1, 8 do
		local a = i * 2.2
		k.box(0.6, 0.1, 0.05, k.at(math.cos(a) * 0.55, -0.15 + math.sin(i) * 0.4, math.sin(a) * 0.55, 0, -math.deg(a) + 90, i * 30), LAVA, M.Neon)
	end
	k.ball(0.8, 0.8, 0.8, k.at(0, -0.15, 0), k.main, M.Neon, { T = 0.3 })
	k.ball(1.5, 0.2, 1.5, k.at(0, -0.9, 0), C(50, 40, 40), M.Basalt)
end

Models.fire_opal = function(k)
	k.ball(1.3, 1.0, 1.0, k.at(0, -0.1, 0), k.main, M.Glass, { T = 0.1, R = 0.3 })
	for i = 1, 5 do
		k.ball(0.4, 0.25, 0.1, k.at(-0.3 + i * 0.12, -0.1 + (i % 2) * 0.2, -0.45), ({ C(255, 60, 60), C(255, 200, 60), C(80, 230, 150), C(80, 170, 255) })[(i % 4) + 1], M.Neon, { T = 0.35 })
	end
	k.torus(0.62, 0.1, 16, k.at(0, -0.1, 0), GOLD, M.Metal, { R = 0.3 })
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi
		k.box(0.1, 0.35, 0.1, k.at(math.cos(a) * 0.68, -0.1 + math.sin(a) * 0.52, 0, 0, 0, math.deg(a)), GOLD, M.Metal)
	end
end

Models.dragon_scale_shield = function(k)
	k.cyl(0.25, 2.1, k.at(0, 0.1, 0, 0, 90, 0), C(70, 30, 25), M.Metal)
	for ring = 0, 2 do
		local r = 0.8 - ring * 0.3
		for i = 1, 6 + ring * -1 do
			local a = i / (6 - ring) * 2 * math.pi
			k.ball(0.45, 0.35, 0.15, k.at(math.cos(a) * r, 0.1 + math.sin(a) * r, -0.14 - ring * 0.02, 0, 0, math.deg(a)), k.main:Lerp(C(200, 60, 40), ring * 0.2), M.Metal, { R = 0.2 })
		end
	end
	k.ball(0.45, 0.45, 0.2, k.at(0, 0.1, -0.2), GOLD, M.Metal, { R = 0.3 })
	k.ball(0.2, 0.2, 0.1, k.at(0, 0.1, -0.3), LAVA, M.Neon)
	k.torus(1.02, 0.1, 18, k.at(0, 0.1, 0), GOLD, M.Metal)
end

Models.inferno_chalice = function(k)
	goblet(k, k.main, M.Metal, 1.4, 0.9)
	k.ball(1.1, 0.4, 1.1, k.at(0, 1.0, 0), LAVA, M.Neon)
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		k.cone(0.7, 0.3, 3, k.at(math.cos(a) * 0.3, 1.0, math.sin(a) * 0.3), C(255, 170, 40), M.Neon, { T = 0.2 })
	end
	k.cone(1.0, 0.45, 4, k.at(0, 1.0, 0), C(255, 230, 120), M.Neon, { T = 0.15 })
	for _, x in { -1, 1 } do
		horn(k, x * 0.7, 0.3, 0, x, 0.6, 0.2, C(60, 30, 25), M.Metal)
	end
end

Models.phoenix_lyre = function(k)
	local gold = k.main
	-- Two arms curving up like wings, strings of fire between.
	for _, side in { -1, 1 } do
		for i = 0, 5 do
			local t = i / 5
			k.ball(0.25, 0.45, 0.2, k.at(side * (0.3 + math.sin(t * math.pi * 0.8) * 0.5), -0.6 + t * 1.8, 0, 0, 0, side * (-20 + t * 40)), gold, M.Metal, { R = 0.3 })
		end
		k.cone(0.55, 0.3, 3, k.at(side * 0.72, 1.2, 0, 0, 0, side * -15), C(255, 150, 50), M.Neon, { T = 0.1 })
	end
	k.box(1.1, 0.15, 0.2, k.at(0, 1.1, 0), gold, M.Metal)
	k.box(0.9, 0.3, 0.3, k.at(0, -0.75, 0), gold, M.Metal)
	for i = 0, 4 do
		k.box(0.03, 1.8, 0.03, k.at(-0.28 + i * 0.14, 0.18, 0), C(255, 150, 50), M.Neon)
	end
end

Models.ifrit_lamp = function(k)
	local brass = k.main
	k.ball(1.6, 0.7, 0.9, k.at(0, -0.55, 0), brass, M.Metal, { R = 0.35 })
	k.cyl(0.9, 0.25, k.at(-0.95, -0.4, 0, 0, 0, 25), brass, M.Metal, { R = 0.35 })
	k.torus(0.3, 0.08, 8, k.at(0.9, -0.5, 0, 0, 90, 0), brass, M.Metal)
	k.vcyl(0.25, 0.6, k.at(0, -0.15, 0), brass, M.Metal)
	k.ball(0.3, 0.3, 0.3, k.at(0, 0.02, 0), GOLD, M.Metal)
	-- The genie curling out of the spout in purple smoke.
	for i = 1, 6 do
		local t = i / 6
		k.ball(0.35 + t * 0.4, 0.35 + t * 0.3, 0.35 + t * 0.4, k.at(-1.3 + t * 1.0, -0.2 + t * 1.3, math.sin(t * 5) * 0.2), C(150, 80, 220):Lerp(C(80, 180, 255), t), M.Neon, { T = 0.3 + (1 - t) * 0.2 })
	end
	eyes(k, 1.15, -0.45, 0.14, 0.15, C(255, 220, 60))
end

-- RIMEHEART -----------------------------------------------------------------------------------

Models.frost_feather = function(k)
	feather(k, C(200, 240, 255), WHITE, C(170, 210, 240), M.Glass)
	for i = 1, 4 do
		k.box(0.08, 0.08, 0.08, k.at(0.4 - i * 0.2, 0.9 - i * 0.3, -0.1, 45, 45, 0), WHITE, M.Neon)
	end
end

Models.narwhal_horn = function(k)
	k.cone(2.4, 0.6, 8, k.at(0.1, -0.95, 0, 0, 0, -12), k.main, M.Marble, { R = 0.15 })
	for i = 0, 7 do
		local t = i / 7
		k.box(0.46 * (1 - t * 0.8), 0.04, 0.46 * (1 - t * 0.8), k.at(0.1 + t * 0.5, -0.8 + t * 2.3, 0, 0, i * 30, -12), C(200, 210, 220), M.Marble)
	end
	k.ball(1.4, 0.3, 1.1, k.at(0, -0.9, 0), C(220, 240, 255), M.Ice)
end

Models.ice_dragon_egg = function(k)
	egg(k, k.main, M.Glass, C(220, 250, 255))
	for i = 1, 5 do
		local a = i / 5 * 2 * math.pi
		shard(k, k.at(math.cos(a) * 0.75, -0.85, math.sin(a) * 0.75, math.sin(a) * 25, 0, -math.cos(a) * 25), 0.2, 0.5, ICE, M.Glass, { T = 0.1 })
	end
	k.ball(0.8, 1.1, 0.8, k.at(0, 0.05, 0), C(200, 240, 255), M.Neon, { T = 0.5 })
end

Models.glacier_bell = function(k)
	for i = 0, 8 do
		local t = i / 8
		local d = 1.8 - math.sqrt(t) * 0.95
		k.vcyl(0.2, d, k.at(0, -0.7 + t * 1.5, 0), k.main, M.Glass, { T = 0.2 })
	end
	k.ball(0.9, 0.5, 0.9, k.at(0, 0.85, 0), k.main, M.Glass, { T = 0.2 })
	k.torus(0.25, 0.1, 8, k.at(0, 1.25, 0), C(220, 240, 255), M.Ice)
	k.ball(0.45, 0.45, 0.45, k.at(0, -0.8, 0), C(150, 230, 255), M.Neon)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.box(0.1, 0.35, 0.1, k.at(math.cos(a) * 0.8, -0.95, math.sin(a) * 0.8), ICE, M.Glass, { T = 0.1 })
	end
end

Models.frozen_treasure_chest = function(k)
	chest(k, C(130, 90, 60), C(160, 200, 230))
	coinsPile(k, 0.35, 6, 0.5)
	-- The whole thing encased in a block of ice.
	k.box(2.3, 1.9, 1.6, k.at(0, -0.05, 0), k.main, M.Ice, { T = 0.55 })
	for i = 1, 5 do
		k.box(0.12, 0.3, 0.12, k.at(-0.9 + i * 0.35, -1.0, -0.8), ICE, M.Glass, { T = 0.2 })
	end
end

Models.frost_titan_heart = function(k)
	heart(k, 0.2, 1.8, k.main, M.Glass, { T = 0.2 })
	heart(k, 0.2, 1.1, C(200, 245, 255), M.Neon, { T = 0.3 })
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		shard(k, k.at(math.cos(a) * 0.55, -0.9, math.sin(a) * 0.55, math.sin(a) * 35, 0, -math.cos(a) * 35), 0.22, 0.45, ICE, M.Glass, { T = 0.1 })
	end
	k.torus(1.1, 0.05, 20, k.at(0, 0.3, 0, 75, 0, 0), C(160, 230, 255), M.Neon, { T = 0.3 })
end

Models.aurora_lantern = function(k)
	lantern(k, C(40, 60, 90), C(120, 255, 200), C(200, 255, 240))
	for i = 1, 5 do
		k.box(1.4, 0.1, 0.05, k.at(0, 1.1 + i * 0.12, 0, 0, i * 36, math.sin(i) * 12), AURORA[i], M.Neon, { T = 0.35 })
	end
end

-- STARFALL ISLES ------------------------------------------------------------------------------

Models.meteorite = function(k)
	k.ball(1.5, 1.2, 1.3, k.at(0, -0.3, 0), k.main, M.Basalt)
	for i = 1, 6 do
		local a = i * 1.9
		k.ball(0.35, 0.3, 0.1, k.at(math.cos(a) * 0.6, -0.3 + math.sin(i) * 0.4, math.sin(a) * 0.55, 0, -math.deg(a) + 90, 0), C(30, 25, 35), M.Basalt)
	end
	for i = 1, 5 do
		k.box(0.5, 0.06, 0.05, k.at(-0.3 + i * 0.12, -0.3 + (i % 3) * 0.25, -0.62, 0, 0, i * 40), C(255, 150, 60), M.Neon)
	end
	for i = 1, 3 do
		k.box(0.14, 0.14, 0.14, k.at(0.4 - i * 0.2, 0.45 + i * 0.15, -0.1, 45, 45, 0), C(200, 230, 255), M.Glass)
	end
end

Models.star_chart = function(k)
	k.box(1.9, 1.5, 0.08, k.at(0, 0.1, 0), k.main, M.Fabric)
	for _, y in { -0.72, 0.92 } do
		k.cyl(2.1, 0.22, k.at(0, y, 0), C(170, 120, 70), M.Wood)
	end
	local stars = { { -0.6, 0.5 }, { -0.25, 0.25 }, { 0.1, 0.45 }, { 0.45, 0.1 }, { 0.2, -0.3 }, { -0.4, -0.25 } }
	for i, p in stars do
		k.ball(0.12, 0.12, 0.05, k.at(p[1], p[2], -0.06), C(255, 240, 180), M.Neon)
		local nxt = stars[i + 1]
		if nxt then
			local dx, dy = nxt[1] - p[1], nxt[2] - p[2]
			k.box(math.sqrt(dx * dx + dy * dy), 0.03, 0.02, k.at((p[1] + nxt[1]) / 2, (p[2] + nxt[2]) / 2, -0.05, 0, 0, math.deg(math.atan2(dy, dx))), C(150, 180, 255), M.Neon, { T = 0.3 })
		end
	end
	k.ball(0.3, 0.3, 0.05, k.at(0.65, 0.55, -0.06), C(255, 250, 220), M.Neon)
end

Models.moon_rabbit = function(k)
	local white = k.main
	k.ball(1.2, 1.1, 1.0, k.at(0, -0.45, 0), white, M.Marble)
	k.ball(0.8, 0.75, 0.75, k.at(0, 0.35, -0.1), white, M.Marble)
	for _, x in { -0.18, 0.18 } do
		k.ball(0.22, 0.95, 0.12, k.at(x, 1.05, 0, 0, 0, x * -40), white, M.Marble)
		k.ball(0.12, 0.7, 0.05, k.at(x, 1.05, -0.05, 0, 0, x * -40), C(255, 190, 210), M.SmoothPlastic)
	end
	eyes(k, 0.42, -0.42, 0.16, 0.14, C(200, 40, 80))
	-- The mortar and pestle it's pounding, and a crescent moon behind.
	k.vcyl(0.35, 0.55, k.at(0, -0.75, -0.6), C(170, 130, 90), M.Wood)
	k.cyl(0.7, 0.1, k.at(0.1, -0.3, -0.6, 0, 0, 70), C(170, 130, 90), M.Wood)
	k.ball(1.4, 1.4, 0.1, k.at(0.2, 0.3, 0.55), C(255, 240, 170), M.Neon)
	k.ball(1.2, 1.2, 0.12, k.at(0.5, 0.45, 0.52), C(30, 30, 60), M.SmoothPlastic)
end

Models.tiny_planet = function(k)
	k.ball(1.4, 1.4, 1.4, k.at(0, 0.1, 0), k.main, M.SmoothPlastic)
	for i = 1, 5 do
		local a = i * 1.3
		k.ball(0.5, 0.2, 0.5, k.at(math.cos(a) * 0.5, 0.1 + math.sin(i * 2) * 0.45, math.sin(a) * 0.5, 0, -math.deg(a), 70), C(90, 200, 90), M.Grass)
	end
	k.ball(0.35, 0.5, 0.35, k.at(0, 0.85, 0), C(80, 170, 70), M.Grass) -- a tree on top
	k.vcyl(0.3, 0.08, k.at(0, 0.7, 0), WOOD, M.Wood)
	k.torus(1.05, 0.07, 20, k.at(0, 0.1, 0, 70, 0, 15), C(255, 220, 150), M.Neon, { T = 0.25 })
	k.ball(0.25, 0.25, 0.25, k.at(1.05, 0.3, 0), C(220, 220, 230), M.Slate) -- a moon
	k.vcyl(0.2, 0.7, k.at(0, -0.85, 0), C(60, 50, 80), M.Metal)
end

Models.constellation_tiara = function(k)
	crown(k, k.main, M.Metal, 7, C(255, 250, 220))
	for i = 1, 3 do
		starShape(k, k.at(-0.5 + (i - 1) * 0.5, 0.75 + (if i == 2 then 0.3 else 0), -0.75), 0.18 + (if i == 2 then 0.08 else 0), 0.05, C(255, 250, 220), M.Neon)
	end
end

Models.void_lantern = function(k)
	lantern(k, C(30, 20, 40), C(20, 10, 30), C(120, 60, 200))
	k.torus(0.3, 0.08, 10, k.at(0, -0.2, 0, 0, 30, 0), C(170, 90, 255), M.Neon)
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		k.ball(0.1, 0.1, 0.1, k.at(math.cos(a) * 0.6, 0.9 + (i % 2) * 0.2, math.sin(a) * 0.6), C(190, 120, 255), M.Neon)
	end
end

Models.supernova_core = function(k)
	orbOnStand(k, C(60, 50, 80), C(255, 230, 170), M.Neon, { T = 0.1 })
	for i = 0, 7 do
		spike2d(k, k.at(0, 0.15, -0.1, 0, 0, i * 45) * CFrame.new(0, 0.6 * k.s, 0), 0.3, 0.7, 0.06, C(255, 250, 220), M.Neon, { T = 0.2 })
	end
	k.torus(1.1, 0.07, 20, k.at(0, 0.15, 0, 70, 0, 0), C(255, 150, 80), M.Neon, { T = 0.3 })
end

Models.galaxy_egg = function(k)
	k.ball(1.35, 1.8, 1.35, k.at(0, 0.05, 0), C(40, 25, 80), M.Glass, { T = 0.15 })
	for i = 1, 3 do
		k.torus(0.45 + i * 0.05, 0.05, 14, k.at(0, 0.05, 0, 75, i * 55, 0), ({ C(190, 90, 255), C(255, 110, 210), C(90, 220, 255) })[i], M.Neon, { T = 0.3 })
	end
	for i = 1, 9 do
		local a = i * 1.1
		k.ball(0.08, 0.08, 0.08, k.at(math.cos(a) * 0.35, -0.4 + i * 0.1, math.sin(a) * 0.35), WHITE, M.Neon)
	end
	k.ball(1.6, 0.25, 1.6, k.at(0, -0.85, 0), C(60, 50, 80), M.Slate)
end

Models.pocket_black_hole = function(k)
	-- A black sphere with a blazing accretion disc and light bending round it.
	k.ball(1.1, 1.1, 1.1, k.at(0, 0.2, 0), BLACK, M.SmoothPlastic)
	k.torus(0.9, 0.18, 22, k.at(0, 0.2, 0, 80, 0, 10), C(255, 170, 60), M.Neon)
	k.torus(1.15, 0.1, 24, k.at(0, 0.2, 0, 80, 0, 10), C(255, 90, 40), M.Neon, { T = 0.3 })
	k.torus(0.62, 0.06, 18, k.at(0, 0.2, 0, 0, 0, 0), C(255, 230, 180), M.Neon, { T = 0.35 })
	k.vcyl(0.2, 0.8, k.at(0, -0.85, 0), C(40, 40, 50), M.Metal)
	k.box(0.1, 0.8, 0.1, k.at(0, -0.45, 0), C(40, 40, 50), M.Metal)
end

-- EVENT (admin drops only) ---------------------------------------------------------------------

Models.heist_bag = function(k)
	local gold = k.main
	k.ball(1.7, 1.5, 1.5, k.at(0, -0.3, 0), C(60, 60, 70), M.Fabric)
	k.ball(1.1, 0.5, 1.0, k.at(0, 0.45, 0), C(70, 70, 80), M.Fabric)
	k.torus(0.4, 0.1, 10, k.at(0, 0.6, 0, 90, 0, 0), gold, M.Metal)
	-- The dollar sign, gold spilling out, a mask tied on.
	k.box(0.14, 0.9, 0.05, k.at(0, -0.3, -0.76), gold, M.Neon)
	for i = 0, 2 do
		k.box(0.5, 0.12, 0.05, k.at(0, -0.65 + i * 0.35, -0.77, 0, 0, if i == 1 then -25 else 25), gold, M.Neon)
	end
	k.ball(0.9, 0.5, 0.9, k.at(0, 0.8, 0), gold, M.Metal, { R = 0.35 })
	coinsPile(k, 1.0, 6, 0.3)
	k.box(1.2, 0.3, 0.1, k.at(0, 0.15, -0.7), BLACK, M.Fabric)
	for _, x in { -0.25, 0.25 } do
		k.ball(0.2, 0.14, 0.05, k.at(x, 0.15, -0.76), WHITE, M.SmoothPlastic)
	end
end

Models.cosmic_cat = function(k)
	local fur = k.main
	k.ball(1.2, 1.1, 1.0, k.at(0, -0.4, 0), fur, M.SmoothPlastic)
	k.ball(1.0, 0.9, 0.9, k.at(0, 0.45, -0.1), fur, M.SmoothPlastic)
	for _, x in { -0.3, 0.3 } do
		k.wedge(0.3, 0.45, 0.2, k.at(x, 0.95, -0.1), fur, M.SmoothPlastic)
	end
	eyes(k, 0.5, -0.5, 0.2, 0.26, C(120, 255, 200))
	for i = 1, 8 do
		local a = i * 1.7
		k.ball(0.08, 0.08, 0.05, k.at(math.cos(a) * 0.45, -0.4 + math.sin(i) * 0.4, -0.5), WHITE, M.Neon)
	end
	-- A tail curling into a ring of stars, a tiny space helmet.
	for i = 0, 6 do
		local t = i / 6
		k.ball(0.22, 0.22, 0.22, k.at(0.5 + math.sin(t * 3) * 0.4, -0.6 + t * 1.2, 0.5), fur, M.SmoothPlastic)
	end
	starShape(k, k.at(0.7, 0.7, 0.5), 0.2, 0.05, C(255, 240, 180), M.Neon)
	k.ball(1.25, 1.15, 1.15, k.at(0, 0.45, -0.1), C(200, 230, 255), M.Glass, { T = 0.7 })
end

Models.crown_of_heists = function(k)
	crown(k, k.main, M.Metal, 8, C(255, 60, 90))
	-- Every jewel a different colour, a black mask band, a floating dollar sign.
	local jewels = { C(255, 60, 90), C(60, 200, 255), C(80, 230, 110), C(255, 220, 60), C(190, 110, 255) }
	for i = 1, 10 do
		local a = i / 10 * 2 * math.pi
		k.ball(0.18, 0.22, 0.1, k.at(math.cos(a) * 0.86, -0.45, math.sin(a) * 0.86, 0, 90 - math.deg(a), 0), jewels[(i % #jewels) + 1], M.Glass)
	end
	k.box(0.12, 0.7, 0.05, k.at(0, 1.05, 0), GOLD, M.Neon)
	k.box(0.4, 0.1, 0.05, k.at(0, 1.2, 0, 0, 0, 25), GOLD, M.Neon)
	k.box(0.4, 0.1, 0.05, k.at(0, 0.9, 0, 0, 0, 25), GOLD, M.Neon)
end

Models.dev_duck = function(k)
	local gold = k.main
	k.ball(1.6, 1.1, 1.3, k.at(0, -0.45, 0.1), gold, M.Metal, { R = 0.4 })
	k.ball(1.0, 0.95, 0.95, k.at(0, 0.45, -0.25), gold, M.Metal, { R = 0.4 })
	k.ball(0.6, 0.25, 0.5, k.at(0, 0.3, -0.8), C(255, 140, 30), M.SmoothPlastic)
	eyes(k, 0.6, -0.65, 0.22, 0.24)
	k.wedge(0.8, 0.5, 0.4, k.at(0, -0.1, 0.85, 0, 0, 0), gold, M.Metal, { R = 0.4 })
	for _, x in { -0.65, 0.65 } do
		k.ball(0.25, 0.6, 0.8, k.at(x, -0.35, 0.1, 0, 0, x * -15), gold:Lerp(WHITE, 0.2), M.Metal, { R = 0.4 })
	end
	-- A tiny crown and a pair of sunglasses. Worth six million.
	crown(k, WHITE, M.Neon, 5, C(255, 60, 90), 0.98, 0.38)
	k.box(0.9, 0.2, 0.05, k.at(0, 0.62, -0.72), BLACK, M.Glass)
end

return TreasureModels
