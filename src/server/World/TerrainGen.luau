-- Heightmap island generator. Height() is pure (math.noise only) so it is unit-tested with lune;
-- Generate() writes the voxels. Gameplay areas are kept perfectly flat at y = 10 via FLAT_ZONES,
-- everything else gets rolling hills, a noisy coastline and sloped beaches.

local TerrainGen = {}

local RES = 4
local HALF = 608 -- the main generated square is [-HALF, HALF] on X and Z
-- The Deep South strip, generated too: x -384..384, z -1312..-608 (whole 64-stud chunks).
local SOUTH_STRIP = { X0 = -384, Z0 = -1312, CellsX = 192, CellsZ = 176 }
local Y_MIN = -28
local Y_MAX = 72
local GROUND = 10
local SEA_FLOOR = -16
local SEED = 7.31

-- { x, z, radius, falloff }: inside radius the ground is exactly GROUND.
TerrainGen.FLAT_ZONES = {
	{ 0, 250, 168, 45 }, -- Treasure District
	{ 0, 55, 34, 30 }, -- Expedition Camp
	{ 230, -110, 125, 45 }, -- Ancient Ruins + courtyard
	{ 60, -300, 150, 40 }, -- Waterfall basin
	{ 225, -296, 18, 16 }, -- cliff ramp foot
	{ -128, -258, 32, 22 }, -- the Mist Lagoon (World/Falls)
	{ -345, -10, 95, 35 }, -- Shipwreck Coast
	{ 120, 10, 28, 25 }, -- Ravine bridge
	{ 360, 300, 24, 20 }, -- Lighthouse
	{ 0, 100, 40, 30 }, -- District gate
	{ -205, -125, 34, 25 }, -- Old Mine (secret tunnel through a rock mound)
	{ 330, -165, 36, 25 }, -- Sky Ruins (parkour spiral)
	{ 190, -230, 42, 30 }, -- Catacombs (stairs + burial hall under the ground)
	{ -290, 250, 50, 30 }, -- Frostpeak frozen lake
	{ -195, 190, 20, 22 }, -- Frostpeak mountain pass (the trail's way through the peaks)
	{ -232, 218, 18, 20 },
	{ -215, 330, 30, 20 }, -- Frozen Grotto (secret)
	{ 270, 180, 95, 30 }, -- Glowshroom Marsh (a flat bog of pools and boardwalks)
	-- Settlements + new secrets (World/Settlements, World/Secrets)
	{ -100, 75, 32, 20 }, -- Wilds farmstead
	{ 60, -110, 14, 14 }, -- ranger watchtower
	{ -60, -200, 18, 15 }, -- campsite
	{ -60, -90, 18, 15 }, -- Hollow Oak (secret)
	{ -385, 90, 32, 18 }, -- fishing village + Smugglers' Den (secret)
	{ -240, 280, 16, 14 }, -- trapper's cabin
	{ -320, 185, 18, 16 }, -- mining outpost
	{ 110, -270, 20, 15 }, -- Eagle's Nest (secret)
	-- The Deep South (World/DeepSouth). On the glacier these flatten to the plateau height.
	{ 22, -565, 22, 16 }, -- Ashen Camp
	{ 115, -560, 20, 14 }, -- Obsidian Temple
	{ 140, -740, 26, 16 }, -- Lava Outpost
	{ -150, -735, 18, 14 }, -- mining camp
	{ -100, -650, 6, 6 }, -- (Mount Cinder's caldera, secret)
	{ -100, -700, 8, 6 }, -- (the Old King's Forge, secret)
	{ -170, -852, 8, 8 }, -- (Frostbane's Tomb, secret)
	{ -160, -915, 24, 14 }, -- the Frozen Ship (secret)
	{ 120, -915, 22, 14 }, -- Glacier Station
	{ -60, -990, 26, 14 }, -- igloo village
	{ 80, -985, 14, 10 }, -- the frozen mammoth
	{ -88, -915, 20, 12 }, -- the Heart of the Rime
	{ -145, -985, 30, 12 }, -- the frozen lake
	{ -3, -900, 17, 10 }, -- ice arch over the trail
	{ 0, -1003, 17, 10 }, -- ice arch over the trail
	{ 8, -1218, 8, 6 }, -- (the Observatory, secret: over the sea)
	{ -122, -1240, 8, 6 }, -- (the Rift, secret: over the sea)
}

-- FROSTPEAK peaks: extra-tall hills in a ring around the frozen lake.
TerrainGen.FROST = { X = -290, Z = 250, Inner = 60, Outer = 135, Height = 55 }

-- Terrain under the Treasure District is sunk to y = 8 (an exact voxel boundary, so it is
-- perfectly flat) and hidden by the District's plaza slab (top at y = 11). With ground at 10
-- the half-filled voxels rendered unevenly and poked through the slab and the spawn dais.
-- The step back up to 10 sits under the District wall (radius 150).
TerrainGen.SUNKEN = { X = 0, Z = 250, Radius = 150, Height = 8 }

-- { x, z, radius, material name }: grass-free ground under built-up areas, so animated terrain
-- grass never pokes through floors or hides treasure there.
TerrainGen.SURFACE_ZONES = {
	{ 0, 250, 162, "Pavement" }, -- Treasure District (inside the wall)
	{ 0, 55, 30, "Ground" }, -- Expedition Camp
	{ 230, -45, 44, "Sandstone" }, -- Temple courtyard
	{ 230, -140, 55, "Sandstone" }, -- Temple base
	{ -345, -10, 70, "Sand" }, -- Shipwreck beach
	{ -290, 250, 44, "Ice" }, -- Frostpeak frozen lake
}

function TerrainGen.SurfaceZone(x: number, z: number): string?
	for _, zone in TerrainGen.SURFACE_ZONES do
		if (x - zone[1]) ^ 2 + (z - zone[2]) ^ 2 <= zone[3] ^ 2 then
			return zone[4]
		end
	end
	return nil
end

local function noise2(x: number, z: number, frequency: number, offset: number): number
	return math.noise(x * frequency, z * frequency, SEED + offset)
end

local function fbm(x: number, z: number): number
	local total, amplitude, frequency, norm = 0, 1, 1 / 140, 0
	for octave = 1, 4 do
		total += math.noise(x * frequency, z * frequency, SEED + octave * 17.3) * amplitude
		norm += amplitude
		amplitude *= 0.5
		frequency *= 2
	end
	return total / norm
end

local function smoothstep(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 inside any flat zone, 1 far away from all of them.
function TerrainGen.FlatMask(x: number, z: number): number
	local mask = 1
	for _, zone in TerrainGen.FLAT_ZONES do
		local d = math.sqrt((x - zone[1]) ^ 2 + (z - zone[2]) ^ 2)
		mask = math.min(mask, smoothstep((d - zone[3]) / zone[4]))
	end
	return mask
end

-- THE WATERFALL MOUNTAIN: a sculpted massif across the island's south (replacing the old
-- rectangular cliff blocks). A grassy TERRACE at Top - a hanging valley where the river runs
-- to the Giant Waterfall - sits in a saddle between two big, eroded PEAKS whose long rocky
-- slopes run down into the jungle and the sea. The terrace is sheer only where the water
-- drops and where the cliff ramp lands; everything built on it (river, lookout, hermit's hut,
-- geyser landing, the start of the Ashen Pass) stays flat. Generated in its own, taller
-- voxel box.
TerrainGen.MOUNTAIN = {
	Top = 90,
	Box = { X0 = -320, Z0 = -576, CellsX = 160, CellsZ = 80, YMax = 164 },
	Terrace = { West = -85, East = 108, Front = -307, Back = -392 },
	FallsHalfWidth = 34, -- the sheer notch the waterfall pours over (and the pool below it)
	LedgeTop = 50, -- the grassy mid-ledge that steps the cliff face on both sides of the falls
	RampLanding = { 78, 112 }, -- x range where the cliff ramp meets the terrace
	PassX = { 15, 85 }, -- the Ashen Pass leaves the terrace here, heading south
	Peaks = {
		{ X = -165, Z = -415, Height = 150, Radius = 125 }, -- the west peak
		{ X = -85, Z = -440, Height = 112, Radius = 70 },
		{ X = -230, Z = -330, Height = 72, Radius = 70 }, -- west shoulder
		{ X = 180, Z = -420, Height = 138, Radius = 115 }, -- the east peak
		{ X = 250, Z = -350, Height = 70, Radius = 60 }, -- east shoulder
		{ X = 110, Z = -445, Height = 96, Radius = 55 },
		-- A jagged skyline right behind the falls (clear of the Ashen Pass at x 15..85).
		{ X = -30, Z = -428, Height = 124, Radius = 66 },
		{ X = 135, Z = -430, Height = 122, Radius = 45 },
		-- Spurs hugging the terrace's front corners, so it reads as a notch in the range.
		{ X = -118, Z = -330, Height = 112, Radius = 62 },
		{ X = 150, Z = -348, Height = 108, Radius = 46 },
	},
}

-- Height of the mountain at (x, z) over `ground` (the land beneath it), or nil off it. Pure.
function TerrainGen.MountainHeight(x: number, z: number, ground: number): number?
	local M = TerrainGen.MOUNTAIN
	if x < -330 or x > 350 or z > -270 or z < -580 then
		return nil
	end
	local function n(f: number, o: number): number
		return (math.noise(x * f, z * f, SEED + o) + 1) / 2 -- 0..1
	end
	local function nx(f: number, o: number): number
		return (math.noise(x * f, 0.5, SEED + o) + 1) / 2
	end
	local height = ground
	-- PEAKS: domes warped by noise, cut by gullies and ledges.
	local warp = (n(1 / 45, 301) - 0.5) * 0.35
	local gully = math.abs(math.noise(x / 28, z / 28, SEED + 303)) -- 0 in a gully, up to ~0.7
	for _, peak in M.Peaks do
		local d = math.sqrt((x - peak.X) ^ 2 + (z - peak.Z) ^ 2) / peak.Radius * (1 + warp)
		if d < 1 then
			local shape = (1 - d ^ 1.6) ^ 1.25
			local v = ground + (peak.Height - ground) * shape
			v -= (0.35 - math.min(gully, 0.35)) * 26 * d * (1 - d) * 4 -- erosion gullies down the slopes
			v += (n(1 / 18, 305) - 0.5) * 10 * shape -- rocky ledges
			height = math.max(height, v)
		end
	end
	-- THE TERRACE: its edges, ragged except where the falls drop and the ramp lands.
	local T = M.Terrace
	local inFalls = math.abs(x) < M.FallsHalfWidth
	local onLanding = x > M.RampLanding[1] and x < M.RampLanding[2]
	-- Buttresses: the face juts in and out every ~12 studs.
	local buttress = math.abs(math.noise(x / 13, 0.5, SEED + 321)) * 9
	local front = if inFalls then -306 elseif onLanding then T.Front else T.Front - 2 - nx(1 / 30, 311) * 12 + buttress
	local onPass = x > M.PassX[1] and x < M.PassX[2]
	local back = if onPass then -383 else T.Back - nx(1 / 40, 313) * 10
	local sheer = inFalls or onLanding
	local frontWidth = if sheer then 4 else 34 + nx(1 / 50, 315) * 12
	local e = math.sqrt(
		(math.max(0, z - front) / frontWidth) ^ 2
			+ (math.max(0, back - z) / 30) ^ 2
			+ (math.max(0, T.West - x) / 45) ^ 2
			+ (math.max(0, x - T.East) / 45) ^ 2
	)
	if e <= 0 then
		-- On the terrace: flat (a gentle roll), cut into the peaks' feet like a valley floor.
		return M.Top + (n(1 / 60, 317) - 0.5) * 2
	elseif e < 1 then
		-- Rounded lip, steep face, talus at the foot - and on the stepped front, a mid-ledge.
		local fall = if e < 0.12 then 1 - (e / 0.12) ^ 2 * 0.06 else 0.94 * ((1 - e) / 0.88) ^ 1.7
		local inFront = z > front and (z - front) / frontWidth >= math.max(0, back - z) / 30
		if inFront and not sheer then
			local ledge = (M.LedgeTop - ground) / (M.Top - ground)
			local ef = (z - front) / frontWidth
			fall = if ef < 0.35
				then 1 - (1 - ledge) * smoothstep(ef / 0.35) -- upper face
				elseif ef < 0.6 then ledge -- the ledge
				else ledge * (1 - smoothstep((ef - 0.6) / 0.4)) -- lower face
			fall = math.min(fall, 1 - smoothstep((e - 1) * 4 + 1)) -- still fade out at the sides
		end
		local ledges = (n(1 / 20, 319) - 0.5) * 14 * math.clamp(e * (1 - e) * 4, 0, 1)
		height = math.max(height, ground + (M.Top - ground) * fall + ledges * fall)
	end
	-- The range falls into the sea before the Sundering (the channel stays open water).
	local seaward = smoothstep((TerrainGen.SOUTH.ChannelStart + 5 - z) / 40)
	height = ground + (height - ground) * (1 - seaward)
	return if height > ground + 0.5 then height else nil
end

-- Returns (surface height, coast factor 0 = inland .. 1 = open sea)
function TerrainGen.Height(x: number, z: number): (number, number)
	local r = math.sqrt(x * x + z * z)
	local coastline = 470 + noise2(x, z, 1 / 260, 11) * 70
	local coast = smoothstep((r - (coastline - 70)) / 110)
	local base = GROUND + (SEA_FLOOR - GROUND) * coast
	local rolling = fbm(x, z) * 10
	local hills = math.max(0, noise2(x, z, 1 / 150, 29) + 0.02) * 62
	local frost = TerrainGen.FROST
	local frostDistance = math.sqrt((x - frost.X) ^ 2 + (z - frost.Z) ^ 2)
	local frostRing = smoothstep((frostDistance - frost.Inner) / 30) * (1 - smoothstep((frostDistance - frost.Outer) / 25))
	local peaks = math.max(0, noise2(x, z, 1 / 60, 91) + 0.15) * frost.Height * frostRing
	local inland = (rolling + hills + peaks) * (1 - coast) * TerrainGen.FlatMask(x, z)
	local sunken = TerrainGen.SUNKEN
	if (x - sunken.X) ^ 2 + (z - sunken.Z) ^ 2 < sunken.Radius ^ 2 then
		return sunken.Height, coast
	end
	local height = base + inland
	-- The Sundering: a sea channel between the island's south shore and the Deep South.
	local south = TerrainGen.SOUTH
	if z < south.ChannelStart then
		local t = smoothstep((south.ChannelStart - z) / 30)
		height = height * (1 - t) + SEA_FLOOR * t
		coast = math.max(coast, t)
	end
	local southHeight, southCoast = TerrainGen.SouthHeight(x, z)
	if southHeight and southHeight > height then
		height, coast = southHeight, southCoast
	end
	local mountain = TerrainGen.MountainHeight(x, z, height)
	if mountain then
		return mountain, if mountain > 12 then 0 else coast
	end
	return height, coast
end

-- THE DEEP SOUTH: a long peninsula beyond the Waterfall Mountain (docs/EXPANSION_PLAN.md).
--   Emberfall (lava lowlands, z > RimeStart) -> Rimeheart (a glacier plateau, ~40 high).
--   Starfall Isles float over the sea beyond its tip (parts, not terrain).
TerrainGen.SOUTH = {
	ChannelStart = -430, -- the main island fades into sea from here...
	Start = -505, -- ...and the peninsula begins here
	End = -1005, -- its southern tip (Starfall Isles float beyond)
	HalfWidth = 215,
	RimeStart = -790, -- the glacier rises from here
	StarStart = -1045, -- the Starfall Isles begin past the glacier tip
	PlateauHeight = 40,
	-- Rimeheart's crevasses (z of each; World/DeepSouth/Rime.CREVASSES): no relief near them.
	CrevasseZ = { -880, -950 },
}

-- RIMEHEART RELIEF: the plateau is not a table top. Soft wind-blown dunes everywhere, and
-- long PRESSURE RIDGES where the ice buckled - kept off the road down the middle, away from
-- the crevasse lips and (through FlatMask) off everything built up there. Pure.
function TerrainGen.RimeRelief(x: number, z: number): number
	local S = TerrainGen.SOUTH
	local road = smoothstep((math.abs(x - 2) - 12) / 22)
	local lips = 1
	for _, cz in S.CrevasseZ do
		lips = math.min(lips, smoothstep((math.abs(z - cz) - 10) / 16))
	end
	local dunes = (noise2(x * 0.6, z, 1 / 55, 211) + 0.35) * 4
	-- Ridged noise, stretched across the glacier (east-west), so ridges run like frozen waves.
	local ridge = 1 - math.abs(noise2(x * 0.45, z, 1 / 42, 223))
	ridge = ridge ^ 4 * 11
	return math.max(0, dunes + ridge) * road * lips
end

-- Height of the peninsula at (x, z), or nil where it doesn't reach. Pure.
function TerrainGen.SouthHeight(x: number, z: number): (number?, number)
	local S = TerrainGen.SOUTH
	if z > S.Start + 30 or z < S.End - 70 then
		return nil, 1
	end
	local half = S.HalfWidth + noise2(0, z, 1 / 90, 131) * 30 + noise2(x, z, 1 / 60, 137) * 12
	local north = smoothstep((S.Start + 25 - z) / 60)
	local southEnd = smoothstep((z - (S.End - 55)) / 70)
	half *= math.min(north, southEnd)
	if half <= 0 then
		return nil, 1
	end
	local coast = 1 - smoothstep((half - math.abs(x)) / 45)
	local ground, level
	if z > S.RimeStart then
		-- Emberfall: rough volcanic lowland with ridges.
		ground = 13 + fbm(x, z) * 6 + math.max(0, noise2(x, z, 1 / 70, 141)) * 14
		level = GROUND
	else
		-- Rimeheart: the glacier rises steeply into a high, mostly flat ice plateau.
		local rise = smoothstep((S.RimeStart - z) / 45)
		ground = 12 + rise * (S.PlateauHeight - 12) + fbm(x, z) * 2 + rise * TerrainGen.RimeRelief(x, z)
		level = 12 + rise * (S.PlateauHeight - 12) -- flat zones up here flatten to the plateau
	end
	ground = level + (ground - level) * TerrainGen.FlatMask(x, z)
	return ground * (1 - coast) + SEA_FLOOR * coast, coast
end

-- BIOMES: every region has its own ground, so crossing into a new one is visible at a glance.
-- Mirrors Zones.AreaName (District / Ruins / Coast / Frost / Marsh / Falls / Wilds) plus the Volcano's ash
-- fields, with a noisy border so the transition is ragged, not a perfect circle.
TerrainGen.BIOME_CENTERS = {
	District = { 0, 250, 150 },
	Ruins = { 230, -140, 150 },
	Coast = { -345, -10, 160 },
	Volcano = { -280, -360, 175 },
	Frost = { -290, 250, 130 },
	Marsh = { 270, 180, 125 },
}
TerrainGen.FALLS_Z = -240

function TerrainGen.Biome(x: number, z: number, jitter: number?): string
	local j = (jitter or 0) * noise2(x, z, 1 / 40, 71)
	local function within(name: string): boolean
		local c = TerrainGen.BIOME_CENTERS[name]
		local d2, r2 = (x - c[1]) ^ 2 + (z - c[2]) ^ 2, (c[3] + j) ^ 2
		-- Same edge rules as Zones: the safe zone includes its border, the others don't.
		return if name == "District" then d2 <= r2 else d2 < r2
	end
	if within("District") then
		return "District"
	elseif within("Ruins") then
		return "Ruins"
	elseif within("Coast") then
		return "Coast"
	elseif within("Frost") then
		return "Frost"
	elseif within("Marsh") then
		return "Marsh"
	elseif z < TerrainGen.SOUTH.StarStart + j then
		return "Star"
	elseif z < TerrainGen.SOUTH.RimeStart + j then
		return "Rime"
	elseif z < TerrainGen.SOUTH.Start + j then
		return "Ember"
	elseif within("Volcano") then
		return "Volcano"
	elseif z < TerrainGen.FALLS_Z + j then
		return "Falls"
	end
	return "Wilds"
end

-- Surface material per biome: { flat, slope, steep, patch?, patchThreshold? }
TerrainGen.BIOME_MATERIALS = {
	District = { "Grass", "Ground", "Rock" },
	Wilds = { "Grass", "Ground", "Rock", "Ground", 0.42 }, -- sunny meadow, a few dirt patches
	Ruins = { "Sandstone", "Limestone", "Rock", "Salt", 0.3 }, -- scorched desert
	Coast = { "Sand", "Slate", "Slate", "Salt", 0.25 }, -- grey storm shore
	Falls = { "LeafyGrass", "Mud", "Slate", "Mud", 0.25 }, -- dark, wet jungle
	Volcano = { "Basalt", "Basalt", "Rock", "CrackedLava", 0.45 }, -- ash fields
	Frost = { "Snow", "Glacier", "Rock", "Glacier", 0.45 }, -- snowfields and blue ice cliffs
	Marsh = { "Asphalt", "Mud", "Slate", "Concrete", 0.2 }, -- dark glowing bog (recoloured)
	Ember = { "Basalt", "Rock", "Slate", "CrackedLava", 0.38 }, -- black rock, glowing cracks
	Rime = { "Snow", "Glacier", "Glacier", "Glacier", 0.3 }, -- snowfields, blue ice on every rise
	Star = { "Rock", "Rock", "Slate" }, -- (only shores: the isles are built from parts)
}

TerrainGen.MOUNTAIN_MATERIALS = { "LeafyGrass", "Rock", "Rock", "Grass", 0.35 }

local function surfaceMaterial(height: number, coast: number, slope: number, x: number, z: number)
	local zone = TerrainGen.SurfaceZone(x, z)
	if zone then
		return (Enum.Material :: any)[zone]
	end
	if height < 3 or (height < 8.5 and coast > 0.12) then
		return Enum.Material.Sand
	end
	local biome = TerrainGen.Biome(x, z, 14)
	-- The Waterfall Mountain: grassy top, bare rock faces (not the jungle's mud).
	local mats = if height > 36 and biome == "Falls" then TerrainGen.MOUNTAIN_MATERIALS else TerrainGen.BIOME_MATERIALS[biome]
	local name = mats[1]
	if slope > 0.95 then
		name = mats[3]
	elseif slope > 0.6 then
		name = mats[2]
	elseif mats[4] and noise2(x, z, 1 / 55, 53) > mats[5] then
		name = mats[4]
	end
	return (Enum.Material :: any)[name]
end

local function generateRegion(terrain: Terrain, x0: number, z0: number, cellsX: number, cellsZ: number, yMax: number?)
	-- Height grid with a one-cell border for slope estimation.
	local heights: { { number } } = {}
	local coasts: { { number } } = {}
	for i = 0, cellsX + 1 do
		local hRow, cRow = {}, {}
		local x = x0 + RES * (i - 0.5)
		for j = 0, cellsZ + 1 do
			local z = z0 + RES * (j - 0.5)
			hRow[j], cRow[j] = TerrainGen.Height(x, z)
		end
		heights[i], coasts[i] = hRow, cRow
	end

	local chunk = 16
	local ny = ((yMax or Y_MAX) - Y_MIN) / RES
	for ci = 0, cellsX - 1, chunk do
		for cj = 0, cellsZ - 1, chunk do
			local materials, occupancy = {}, {}
			for a = 1, chunk do
				local i = ci + a
				local matX, occX = {}, {}
				for yi = 1, ny do
					matX[yi], occX[yi] = {}, {}
				end
				for b = 1, chunk do
					local j = cj + b
					local h = heights[i][j]
					local slope = math.max(
						math.abs(heights[i + 1][j] - heights[i - 1][j]),
						math.abs(heights[i][j + 1] - heights[i][j - 1])
					) / (RES * 2)
					local x = x0 + RES * (i - 0.5)
					local z = z0 + RES * (j - 0.5)
					local top = surfaceMaterial(h, coasts[i][j], slope, x, z)
					for yi = 1, ny do
						local bottom = Y_MIN + (yi - 1) * RES
						local fill = math.clamp((h - bottom) / RES, 0, 1)
						if fill > 0 then
							matX[yi][b] = if bottom + RES < h - 6 and top ~= Enum.Material.Sand
								then Enum.Material.Ground
								else top
							occX[yi][b] = fill
						elseif bottom < 0 then
							matX[yi][b] = Enum.Material.Water
							occX[yi][b] = 1
						else
							matX[yi][b] = Enum.Material.Air
							occX[yi][b] = 0
						end
					end
				end
				materials[a], occupancy[a] = matX, occX
			end
			local min = Vector3.new(x0 + ci * RES, Y_MIN, z0 + cj * RES)
			local region = Region3.new(min, min + Vector3.new(chunk * RES, ny * RES, chunk * RES))
			terrain:WriteVoxels(region, RES, materials, occupancy)
		end
	end
end

-- Runs synchronously on purpose: the server bootstrap must not yield before services connect
-- their PlayerAdded handlers, otherwise early joiners would miss setup.
function TerrainGen.Generate(terrain: Terrain)
	generateRegion(terrain, -HALF, -HALF, HALF * 2 / RES, HALF * 2 / RES)
	generateRegion(terrain, SOUTH_STRIP.X0, SOUTH_STRIP.Z0, SOUTH_STRIP.CellsX, SOUTH_STRIP.CellsZ)
	-- The Waterfall Mountain is taller than Y_MAX: rewrite its box with a taller column.
	local box = TerrainGen.MOUNTAIN.Box
	generateRegion(terrain, box.X0, box.Z0, box.CellsX, box.CellsZ, box.YMax)
end

return TerrainGen
