-- Heightmap island generator. Height() is pure (math.noise only) so it is unit-tested with lune;
-- Generate() writes the voxels. Gameplay areas are kept perfectly flat at y = 10 via FLAT_ZONES,
-- everything else gets rolling hills, a noisy coastline and sloped beaches.

local TerrainGen = {}

local RES = 4
local HALF = 608 -- generated square is [-HALF, HALF] on X and Z
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
	{ 60, -300, 150, 40 }, -- Waterfall basin + cliff ramp
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
	return base + inland, coast
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
}

local function surfaceMaterial(height: number, coast: number, slope: number, x: number, z: number)
	local zone = TerrainGen.SurfaceZone(x, z)
	if zone then
		return (Enum.Material :: any)[zone]
	end
	if height < 3 or (height < 8.5 and coast > 0.12) then
		return Enum.Material.Sand
	end
	local mats = TerrainGen.BIOME_MATERIALS[TerrainGen.Biome(x, z, 14)]
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

-- Runs synchronously on purpose: the server bootstrap must not yield before services connect
-- their PlayerAdded handlers, otherwise early joiners would miss setup.
function TerrainGen.Generate(terrain: Terrain)
	local cells = HALF * 2 / RES
	-- Height grid with a one-cell border for slope estimation.
	local heights: { { number } } = {}
	local coasts: { { number } } = {}
	for i = 0, cells + 1 do
		local hRow, cRow = {}, {}
		local x = -HALF + RES * (i - 0.5)
		for j = 0, cells + 1 do
			local z = -HALF + RES * (j - 0.5)
			hRow[j], cRow[j] = TerrainGen.Height(x, z)
		end
		heights[i], coasts[i] = hRow, cRow
	end

	local chunk = 16
	local ny = (Y_MAX - Y_MIN) / RES
	for ci = 0, cells - 1, chunk do
		for cj = 0, cells - 1, chunk do
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
					local x = -HALF + RES * (i - 0.5)
					local z = -HALF + RES * (j - 0.5)
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
			local min = Vector3.new(-HALF + ci * RES, Y_MIN, -HALF + cj * RES)
			local region = Region3.new(min, min + Vector3.new(chunk * RES, ny * RES, chunk * RES))
			terrain:WriteVoxels(region, RES, materials, occupancy)
		end
	end
end

return TerrainGen
