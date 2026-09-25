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
	k.s, k.main, k.accent, k.mat = s, main, accent, mat

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
	for i = 0, 4 do
		local t = i / 4
		local d = dia * (1 - t * 0.8)
		k.ball(d, length / 4, d, k.at(x + side * (t * 0.35 + t * t * 0.25), y + t * length * 0.8, z, 0, 0, side * -(20 + t * 35)), color, mat)
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

return TreasureModels
