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
			total += Economy.Income(def, mutation)
		end
	end
	local night = if isNight then GameConfig.DayNight.NightIncomeMultiplier else 1
	return math.floor(total * ascensionMultiplier * night + 0.5)
end

return Economy
