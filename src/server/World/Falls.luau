-- THE FALLS: a lush jungle river valley at the foot of the Waterfall Mountain.
--   * The river: out of the plunge pool, winding west through the jungle, with stepping
--     stones and a rope bridge.
--   * The Mist Lagoon at its end: lily pads, reeds, fireflies and low mist, and an overgrown
--     stone idol half-sunk on an island in the middle (a treasure spot - wade or hop over).
--   * Two spring cascades pouring off the mountain's mid-ledges into small pools, flanking
--     the Giant Waterfall.
--   * Jungle along the banks: towering trees, ferns, glowing mushrooms.
-- Built after the terrain and the waterfall (WorldBuilder), from TerrainGen heights.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)

local Props = require(script.Parent.Props)
local TerrainGen = require(script.Parent.TerrainGen)
local Common = require(script.Parent.DeepSouth.Common)

local Falls = {}

local part = Props.part
local WATER_TOP = 9.4
local MOSS = Color3.fromRGB(70, 120, 60)
local IDOL_STONE = Color3.fromRGB(120, 125, 118)

-- The river's course, from the plunge pool to the lagoon (x, z).
Falls.RIVER = {
	Vector2.new(-20, -287),
	Vector2.new(-45, -283),
	Vector2.new(-70, -279),
	Vector2.new(-95, -271),
	Vector2.new(-112, -263),
}
Falls.LAGOON = { Centre = Vector2.new(-128, -258), Radius = 22, Island = 8 }
Falls.IDOL = Vector2.new(-131, -261)
Falls.RIVER_WIDTH = 10

local function carveRiver(terrain: Terrain)
	for i = 1, #Falls.RIVER - 1 do
		local a, b = Falls.RIVER[i], Falls.RIVER[i + 1]
		local delta = b - a
		local steps = math.ceil(delta.Magnitude / 3)
		for s = 0, steps do
			local p = a + delta * (s / steps)
			local cf = CFrame.new(p.X, 0, p.Y) * CFrame.Angles(0, math.atan2(-delta.Y, delta.X), 0)
			terrain:FillBlock(cf + Vector3.new(0, 11.5, 0), Vector3.new(4, 5, Falls.RIVER_WIDTH + 4), Enum.Material.Air)
			terrain:FillBlock(cf + Vector3.new(0, 7.9, 0), Vector3.new(4, 3, Falls.RIVER_WIDTH), Enum.Material.Water)
			terrain:FillBlock(cf + Vector3.new(0, 6, 0), Vector3.new(4, 1, Falls.RIVER_WIDTH + 2), Enum.Material.Slate) -- a pebbly bed
		end
	end
	local l = Falls.LAGOON
	local centre = Vector3.new(l.Centre.X, 0, l.Centre.Y)
	terrain:FillCylinder(CFrame.new(centre + Vector3.new(0, 11.5, 0)), 5, l.Radius + 2, Enum.Material.Air)
	terrain:FillCylinder(CFrame.new(centre + Vector3.new(0, 7.4, 0)), 4, l.Radius, Enum.Material.Water)
	terrain:FillCylinder(CFrame.new(centre + Vector3.new(0, 5.2, 0)), 1, l.Radius, Enum.Material.Mud)
	-- The idol's island.
	terrain:FillCylinder(CFrame.new(centre + Vector3.new(0, 8, 0)), 4.4, l.Island, Enum.Material.LeafyGrass)
	terrain:FillCylinder(CFrame.new(centre + Vector3.new(0, 7.6, 0)), 3.6, l.Island + 1.5, Enum.Material.Mud)
end

-- A giant stone head half-sunk on the island, swallowed by the jungle.
local function buildIdol(parent: Instance, rng: Random)
	local f = Common.folder("SunkenIdol", parent)
	local base = CFrame.new(Falls.IDOL.X, 9.6, Falls.IDOL.Y) * CFrame.Angles(0, math.rad(35), math.rad(-9))
	part({ Name = "IdolHead", Size = Vector3.new(8, 8.5, 7.5), CFrame = base * CFrame.new(0, 2.6, 0), Color = IDOL_STONE, Material = Enum.Material.Slate, Parent = f })
	part({ Name = "IdolBrow", Size = Vector3.new(8.6, 1.4, 1.6), CFrame = base * CFrame.new(0, 4.4, -3.6), Color = IDOL_STONE:Lerp(Color3.new(0, 0, 0), 0.15), Material = Enum.Material.Slate, Parent = f })
	part({ Name = "IdolNose", Class = "WedgePart", Size = Vector3.new(1.6, 2.6, 1.6), CFrame = base * CFrame.new(0, 2.2, -4.4) * CFrame.Angles(0, math.rad(180), 0), Color = IDOL_STONE, Material = Enum.Material.Slate, Parent = f })
	part({ Name = "IdolMouth", Size = Vector3.new(4, 0.6, 0.4), CFrame = base * CFrame.new(0, 0.4, -3.8), Color = Color3.fromRGB(30, 34, 30), Material = Enum.Material.Slate, Parent = f })
	for _, side in { -1, 1 } do
		local eye = part({ Name = "IdolEye", Size = Vector3.new(1.6, 0.8, 0.3), CFrame = base * CFrame.new(side * 1.9, 3.4, -3.8), Color = Color3.fromRGB(120, 255, 170), Material = Enum.Material.Neon, CanCollide = false, Parent = f })
		if side == 1 then
			Common.light(eye, Color3.fromRGB(120, 255, 170), 18, 1, true)
		end
		part({ Name = "IdolEar", Size = Vector3.new(1, 3.4, 1.8), CFrame = base * CFrame.new(side * 4.3, 2.6, 0), Color = IDOL_STONE, Material = Enum.Material.Slate, Parent = f })
	end
	-- Moss and roots have taken it.
	for i = 1, 7 do
		local a = rng:NextNumber(0, 2 * math.pi)
		local size = rng:NextNumber(1.6, 3)
		part({ Name = "Moss", Shape = Enum.PartType.Ball, Size = Vector3.new(size, size * 0.5, size), CFrame = base * CFrame.new(math.cos(a) * 3.4, 6.4 + rng:NextNumber(-0.4, 0.6), math.sin(a) * 3.2), Color = MOSS, Material = Enum.Material.LeafyGrass, CanCollide = false, Parent = f })
		if i <= 4 then
			Props.Vine(f, (base * CFrame.new(math.cos(a) * 3.8, 6.4, math.sin(a) * 3.6)).Position, rng:NextNumber(4, 7), rng)
		end
	end
	Props.Fern(f, Vector3.new(Falls.IDOL.X + 4, 10, Falls.IDOL.Y + 4), rng)
end

-- Two spring cascades off the mountain's mid-ledges (TerrainGen.MOUNTAIN.LedgeTop).
local function buildCascades(parent: Instance, terrain: Terrain)
	local f = Common.folder("SpringCascades", parent)
	local ledge = TerrainGen.MOUNTAIN.LedgeTop
	for _, x in { -62, 58 } do
		-- Walk north from the ledge to find its lip and the foot of the lower face.
		local lipZ, footZ
		for z = -360, -240, 1 do
			local h = TerrainGen.Height(x, z)
			if not lipZ and h <= ledge - 1.5 then
				lipZ = z
			end
			if lipZ and h <= 11 then
				footZ = z
				break
			end
		end
		if lipZ and footZ then
			local top = Vector3.new(x, ledge + 0.4, lipZ - 1)
			local foot = Vector3.new(x, 9.5, footZ + 2)
			local length = (top - foot).Magnitude
			local sheet = part({
				Name = "Cascade",
				Size = Vector3.new(6, 0.6, length),
				CFrame = CFrame.lookAt((top + foot) / 2, foot) * CFrame.new(0, 0.4, 0),
				Color = Color3.fromRGB(170, 230, 250),
				Material = Enum.Material.Glass,
				Transparency = 0.35,
				CanCollide = false,
				CanQuery = false,
				CastShadow = false,
				Parent = f,
			})
			Common.emitter(sheet, {
				Texture = Common.SPARKLE,
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Size = NumberSequence.new(0.5, 0.1),
				Transparency = NumberSequence.new(0.3, 1),
				Lifetime = NumberRange.new(0.6, 1),
				Rate = 10,
				Speed = NumberRange.new(4, 8),
				SpreadAngle = Vector2.new(15, 15),
				EmissionDirection = Enum.NormalId.Back,
			})
			terrain:FillCylinder(CFrame.new(foot + Vector3.new(0, 1, 5)), 4, 7, Enum.Material.Air)
			terrain:FillCylinder(CFrame.new(foot + Vector3.new(0, -1, 5)), 3, 7, Enum.Material.Water)
			local spray = part({ Name = "CascadeSpray", Size = Vector3.new(1, 1, 1), CFrame = CFrame.new(foot + Vector3.new(0, 0.5, 3)), Transparency = 1, CanCollide = false, CanQuery = false, Parent = f })
			Common.emitter(spray, {
				Texture = Common.SMOKE,
				Color = ColorSequence.new(Color3.new(1, 1, 1)),
				Transparency = NumberSequence.new(0.55, 1),
				Size = NumberSequence.new(3, 7),
				Lifetime = NumberRange.new(1.5, 2.5),
				Rate = 5,
				Speed = NumberRange.new(1, 3),
				SpreadAngle = Vector2.new(60, 60),
				EmissionDirection = Enum.NormalId.Top,
			})
		end
	end
end

local function distanceToRiver(x: number, z: number): number
	return Common.distanceToPath(Falls.RIVER, x, z)
end

local function dressValley(parent: Instance, rng: Random, groundAt)
	local f = Common.folder("JungleValley", parent)
	-- Trees and ferns lining both banks, glowing mushrooms by the lagoon.
	for i = 1, #Falls.RIVER - 1 do
		local a, b = Falls.RIVER[i], Falls.RIVER[i + 1]
		local delta = b - a
		local normal = Vector2.new(-delta.Y, delta.X).Unit
		for s = 0, math.floor(delta.Magnitude / 10) do
			local p = a + delta * (s * 10 / delta.Magnitude)
			for _, side in { -1, 1 } do
				local spot = p + normal * side * rng:NextNumber(10, 16)
				if distanceToRiver(spot.X, spot.Y) > 8 then
					local ground = groundAt(spot.X, spot.Y)
					if ground.Y > 9 and ground.Y < 14 then
						local roll = rng:NextNumber()
						if roll < 0.3 then
							Props.JungleTree(f, ground, rng)
						elseif roll < 0.8 then
							Props.Fern(f, ground, rng)
						end
					end
				end
			end
		end
	end
	local l = Falls.LAGOON
	for i = 1, 14 do
		local a = i / 14 * 2 * math.pi + rng:NextNumber(-0.1, 0.1)
		local spot = l.Centre + Vector2.new(math.cos(a), math.sin(a)) * (l.Radius + rng:NextNumber(2, 7))
		local ground = groundAt(spot.X, spot.Y)
		if ground.Y > 8.5 and ground.Y < 14 then
			if i % 5 == 0 then
				Props.GiantMushroom(f, ground, rng)
			elseif i % 2 == 0 then
				Props.Reeds(f, ground, rng)
			else
				Props.Fern(f, ground, rng)
			end
		end
	end
	for _ = 1, 12 do
		local a, r = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(l.Island + 3, l.Radius - 2)
		Props.LilyPad(f, Vector3.new(l.Centre.X + math.cos(a) * r, WATER_TOP + 0.1, l.Centre.Y + math.sin(a) * r), rng)
	end
	for i = 2, #Falls.RIVER - 1 do
		local p = Falls.RIVER[i]
		Props.LilyPad(f, Vector3.new(p.X + rng:NextNumber(-2, 2), WATER_TOP + 0.1, p.Y + rng:NextNumber(-2, 2)), rng)
	end
	-- Stepping stones from the east bank to the island; a rope bridge over the river.
	for i = 1, 3 do
		local x = l.Centre.X + l.Radius + 1 - i * ((l.Radius - l.Island + 1) / 3.2)
		Props.cylinder(Vector3.new(x, WATER_TOP + 0.3, l.Centre.Y + (i % 2) * 1.5), 1.6, 3.2, { Name = "SteppingStone", Color = Color3.fromRGB(110, 112, 104), Material = Enum.Material.Slate, Parent = f })
	end
	for i = 1, 4 do
		local p = Falls.RIVER[2]:Lerp(Falls.RIVER[3], 0.55)
		Props.cylinder(Vector3.new(p.X - 3 + i * 1.6, WATER_TOP + 0.3, p.Y - Falls.RIVER_WIDTH / 2 + i * 2.2), 1.4, 2.8, { Name = "SteppingStone", Color = Color3.fromRGB(110, 112, 104), Material = Enum.Material.Slate, Parent = f })
	end
	local bridgeAt = Falls.RIVER[4]:Lerp(Falls.RIVER[5], 0.4)
	Common.bridge(f, Vector3.new(bridgeAt.X - 2, 10.6, bridgeAt.Y - 9), Vector3.new(bridgeAt.X + 2, 10.6, bridgeAt.Y + 9), 4, "Planks")
	-- Mist over the lagoon and fireflies over the water.
	local mist = part({ Name = "LagoonMist", Size = Vector3.new(l.Radius * 1.6, 1, l.Radius * 1.6), CFrame = CFrame.new(l.Centre.X, WATER_TOP + 1, l.Centre.Y), Transparency = 1, CanCollide = false, CanQuery = false, Parent = f })
	Common.emitter(mist, {
		Texture = Common.SMOKE,
		Color = ColorSequence.new(Color3.fromRGB(220, 240, 235)),
		Transparency = NumberSequence.new(0.8, 1),
		Size = NumberSequence.new(6, 12),
		Lifetime = NumberRange.new(4, 6),
		Rate = 2,
		Speed = NumberRange.new(0.3, 0.8),
		Shape = Enum.ParticleEmitterShape.Box,
		EmissionDirection = Enum.NormalId.Top,
		LightEmission = 0.2,
	})
	for _, p in { l.Centre, Falls.RIVER[3], Falls.RIVER[1] } do
		local anchor = part({ Name = "Fireflies", Size = Vector3.new(22, 1, 22), CFrame = CFrame.new(p.X, WATER_TOP + 3, p.Y), Transparency = 1, CanCollide = false, CanQuery = false, Parent = f })
		Common.emitter(anchor, {
			Texture = Common.SPARKLE,
			Color = ColorSequence.new(Color3.fromRGB(220, 255, 140)),
			Size = NumberSequence.new(0.35, 0),
			Lifetime = NumberRange.new(2, 4),
			Rate = 3,
			Speed = NumberRange.new(0.3, 1),
			SpreadAngle = Vector2.new(180, 180),
			Shape = Enum.ParticleEmitterShape.Box,
		})
	end
end

-- Keep-clear circles for later scatter (Vector2 centre, radius).
function Falls.Build(terrain: Terrain, parent: Instance, rng: Random, groundAt)
	local root = Common.folder("FallsValley", parent)
	carveRiver(terrain)
	buildIdol(root, rng)
	buildCascades(root, terrain)
	dressValley(root, rng, groundAt)
	local avoid = { { Falls.LAGOON.Centre, Falls.LAGOON.Radius + 6 } }
	for _, p in Falls.RIVER do
		table.insert(avoid, { p, 12 })
	end
	return { Avoid = avoid, Pool = WorldLayout.Waterfall.PoolCenter }
end

return Falls
