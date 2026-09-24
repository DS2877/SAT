-- Money rules (pure, unit-tested). Treasures don't pay a big lump sum any more: they EARN
-- $/s while displayed in your Vault (like Steal a Brainrot), by rarity x mutation x Ascension,
-- and triple at night. Extraction pays a small finder's fee; selling frees a pedestal.
--
-- Vault slots store "treasureId" or "treasureId|Mutation" (old saves are plain ids).

local Economy = {}

-- In Roblox the configs are required via `script`; the Lune test runner (no `script`) injects
-- them with Economy.Use instead.
local GameConfig, Mutations
if script then
	GameConfig = require(script.Parent.Parent.Config.GameConfig)
	Mutations = require(script.Parent.Parent.Config.Mutations)
end

function Economy.Use(gameConfig, mutations)
	GameConfig, Mutations = gameConfig, mutations
end

-- Base income ($/s) of a treasure before Ascension / night multipliers.
function Economy.Income(def, mutation: string?): number
	return math.max(1, math.floor(def.Value / GameConfig.Economy.IncomeDivisor * Mutations.Multiplier(mutation) + 0.5))
end

function Economy.SellPrice(def, mutation: string?): number
	return Economy.Income(def, mutation) * GameConfig.Economy.SellIncomeSeconds
end

function Economy.FindersFee(def, mutation: string?, zoneBonus: number?, ascensionMultiplier: number?): number
	return math.floor(
		Economy.Income(def, mutation) * GameConfig.Economy.FindersFeeSeconds * (zoneBonus or 1) * (ascensionMultiplier or 1) + 0.5
	)
end

-- Finder's fee multiplier for the Nth extraction of the day (streak 1 = x1).
function Economy.StreakMultiplier(streak: number): number
	local cfg = GameConfig.Extraction
	local steps = math.clamp(streak, 1, cfg.StreakMax) - 1
	return 1 + steps * cfg.StreakBonusPerRun
end

-- Risky extraction: chance for an UNmutated treasure to gain a mutation. `random()` in [0, 1).
function Economy.RollExtractionMutation(category: string, current: string?, random: () -> number): string?
	local cfg = GameConfig.Extraction
	local zone = cfg.Categories[category]
	if current or not zone or random() >= (zone.MutationChance or 0) then
		return nil
	end
	local total = 0
	for _, weight in cfg.MutationWeights do
		total += weight
	end
	local roll = random() * total
	-- Iterate in a fixed order so results are deterministic for a given roll.
	for _, name in Mutations.Order do
		local weight = cfg.MutationWeights[name]
		if weight then
			roll -= weight
			if roll < 0 then
				return name
			end
		end
	end
	return nil
end

function Economy.EncodeSlot(id: string, mutation: string?): string
	return if mutation then id .. "|" .. mutation else id
end

function Economy.DecodeSlot(value: string?): (string?, string?)
	if type(value) ~= "string" or value == "" then
		return nil, nil
	end
	local id, mutation = string.match(value, "^([^|]+)|(.+)$")
	if id then
		return id, if Mutations.Info[mutation] then mutation else nil
	end
	return value, nil
end

-- Total $/s of a Vault. `lookup(id)` returns a treasure definition (Treasures.Get).
function Economy.VaultIncome(displays, lookup, ascensionMultiplier: number, isNight: boolean): number
	local total = 0
	for _, value in displays do
		local id, mutation = Economy.DecodeSlot(value)
		local def = id and lookup(id)
		if def then
			local income = Economy.Income(def, mutation)
			if isNight and def.SpecialEffect == "Nocturnal" then
				income *= GameConfig.Treasure.NocturnalMultiplier
			end
			total += income
		end
	end
	local night = if isNight then GameConfig.DayNight.NightIncomeMultiplier else 1
	return math.floor(total * ascensionMultiplier * night + 0.5)
end

-- Cash a Vault earned while its owner was offline, at the reduced offline rate and capped.
-- `income` = base $/s (day rate, all multipliers), times are os.time() seconds.
-- Returns (amount, secondsCounted).
function Economy.OfflineEarnings(income: number, lastOnline: number, now: number): (number, number)
	local cfg = GameConfig.Economy
	if lastOnline <= 0 or now <= lastOnline then
		return 0, 0
	end
	local seconds = math.min(now - lastOnline, cfg.OfflineMaxHours * 3600)
	if seconds < cfg.OfflineMinSeconds then
		return 0, 0
	end
	return math.floor(income * cfg.OfflineIncomeRate * seconds), seconds
end

-- COLLECTION SETS -------------------------------------------------------------------------

-- { [area] = { Found = n, Total = m } } for every region's set. `list` = Treasures.List.
function Economy.SetProgress(collection, list)
	local sets = {}
	for _, def in list do
		local area = def.SpawnArea
		local set = sets[area]
		if not set then
			set = { Found = 0, Total = 0 }
			sets[area] = set
		end
		set.Total += 1
		local entry = collection[def.Id]
		if entry and entry.Discovered then
			set.Found += 1
		end
	end
	return sets
end

function Economy.CompletedSets(collection, list): number
	local done = 0
	for _, set in Economy.SetProgress(collection, list) do
		if set.Found >= set.Total then
			done += 1
		end
	end
	return done
end

-- Everything that scales a player's Vault income except night: Ascension x collection sets.
-- `ascensionMultiplier` comes from GameConfig.GetAscensionMultiplier(data.Ascension).
function Economy.IncomeMultiplier(data, list, ascensionMultiplier: number): number
	return ascensionMultiplier * Economy.SetBonus(data.Collection, list)
end

-- Permanent Vault income multiplier from completed collection sets.
function Economy.SetBonus(collection, list): number
	return 1 + Economy.CompletedSets(collection, list) * GameConfig.Collection.SetBonusPerSet
end

return Economy
