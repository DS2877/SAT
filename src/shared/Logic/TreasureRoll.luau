-- Server treasure selection. Pure: callers pass definitions, rarity order, weights, caps,
-- current active counts and a random function returning [0, 1).

local TreasureRoll = {}

local function rankOf(order, rarity)
	for i, name in order do
		if name == rarity then
			return i
		end
	end
	return 0
end

-- Returns a list of { Def, Weight } eligible for a spawn point.
function TreasureRoll.Candidates(defs, point, order, weights, caps, activeByRarity)
	local minRank = rankOf(order, point.MinRarity or order[1])
	local maxRank = rankOf(order, point.MaxRarity or order[#order])

	-- Count candidates per rarity so each rarity's total probability mass stays equal to its weight
	-- regardless of how many treasures share that rarity.
	local perRarity = {}
	local eligible = {}
	for _, def in defs do
		local rank = rankOf(order, def.Rarity)
		local cap = caps[def.Rarity]
		local underCap = cap == nil or (activeByRarity[def.Rarity] or 0) < cap
		if def.SpawnArea == point.Area and rank >= minRank and rank <= maxRank and underCap then
			table.insert(eligible, def)
			perRarity[def.Rarity] = (perRarity[def.Rarity] or 0) + 1
		end
	end

	local result = {}
	for _, def in eligible do
		local w = (weights[def.Rarity] or 0) / perRarity[def.Rarity]
		if w > 0 then
			table.insert(result, { Def = def, Weight = w })
		end
	end
	return result
end

function TreasureRoll.Pick(candidates, random: () -> number)
	local total = 0
	for _, c in candidates do
		total += c.Weight
	end
	if total <= 0 then
		return nil
	end
	local roll = random() * total
	for _, c in candidates do
		roll -= c.Weight
		if roll < 0 then
			return c.Def
		end
	end
	return candidates[#candidates].Def
end

return TreasureRoll
