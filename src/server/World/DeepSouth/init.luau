-- THE DEEP SOUTH (docs/EXPANSION_PLAN.md): the endgame journey beyond the Waterfall Mountain.
--   Ashen Pass -> EMBERFALL (lava, Ascension 1) -> the Steamfields -> RIMEHEART (ice,
--   Ascension 2) -> the STARFALL ISLES (floating islands, Ascension 3).
-- The terrain itself comes from TerrainGen (the peninsula); this builds everything on it,
-- paints the road down its spine and drops boost rings along it.
-- Returns { Avoid, Spawns (exact secret spawn points), BoostPads }.

local Ember = require(script.Ember)
local Rime = require(script.Rime)
local Star = require(script.Star)
local Common = require(script.Common)

local Adventure = require(script.Parent.Adventure)

local DeepSouth = {}

-- The road down the middle, from the foot of the Ashen Pass to the glacier tip.
DeepSouth.SPINE = {
	Vector2.new(28, -548),
	Vector2.new(45, -600),
	Vector2.new(55, -660),
	Vector2.new(40, -720),
	Vector2.new(15, -775),
	Vector2.new(12, -786),
	Vector2.new(0, -852),
	Vector2.new(0, -880),
	Vector2.new(-5, -915),
	Vector2.new(0, -950),
	Vector2.new(0, -990),
	Vector2.new(0, -1030),
}

local RING_SPOTS = { Vector2.new(43, -585), Vector2.new(52, -690), Vector2.new(25, -752), Vector2.new(-3, -908), Vector2.new(0, -985) }

local function paintRoad(terrain: Terrain)
	for i = 1, #DeepSouth.SPINE - 1 do
		local a, b = DeepSouth.SPINE[i], DeepSouth.SPINE[i + 1]
		local delta = b - a
		local steps = math.ceil(delta.Magnitude / 6)
		for s = 0, steps do
			local p = a + delta * (s / steps)
			local region = Region3.new(Vector3.new(p.X - 4, 0, p.Y - 4), Vector3.new(p.X + 4, 72, p.Y + 4)):ExpandToGrid(4)
			for _, from in { Enum.Material.Basalt, Enum.Material.Rock, Enum.Material.CrackedLava, Enum.Material.Slate } do
				terrain:ReplaceMaterial(region, 4, from, Enum.Material.Ground)
			end
			-- On the glacier: a trodden trail of packed grey snow through the white.
			for _, from in { Enum.Material.Glacier, Enum.Material.Ice, Enum.Material.Snow } do
				terrain:ReplaceMaterial(region, 4, from, Enum.Material.Salt)
			end
		end
	end
end

function DeepSouth.Build(terrain: Terrain, parent: Instance, rng: Random, groundAt)
	local root = Common.folder("DeepSouth", parent)
	local avoid, spawns = {}, {}
	Ember.BuildPass(terrain, root, rng)
	for _, built in { Ember.Build(terrain, root, rng, groundAt, DeepSouth.SPINE), Rime.Build(terrain, root, rng, groundAt, DeepSouth.SPINE), Star.Build(root, rng) } do
		for _, a in built.Avoid do
			table.insert(avoid, a)
		end
		for _, s in built.Spawns do
			table.insert(spawns, s)
		end
	end
	paintRoad(terrain)
	local pads = {}
	local rings = Common.folder("SouthBoostRings", root)
	for _, spot in RING_SPOTS do
		table.insert(pads, Adventure.BoostRingAt(rings, groundAt(spot.X, spot.Y, 120), rng))
	end
	return { Avoid = avoid, Spawns = spawns, BoostPads = pads }
end

return DeepSouth
