-- What an Ascension wipes (pure, unit-tested). You start the grind over - Strength back to the
-- start, ALL Cash gone, every gadget gone (Ascension Shop gadgets stay) and every Vault treasure gone EXCEPT your best one
-- (the Heirloom, moved to pedestal 1) - in exchange for a permanent income + training
-- multiplier. Kept: Vault size, the Heirloom, Collection (+ set bonuses), benches, titles,
-- cosmetics, stats.

local AscensionReset = {}

-- The treasures kept through an Ascension: the `count` best by income. `incomeOf(slotValue)`
-- returns the $/s of a Vault slot value (Economy.Income of its treasure + mutation).
function AscensionReset.Heirlooms(displays, count: number, incomeOf: (string) -> number): { string }
	local values = {}
	for _, value in displays do
		table.insert(values, value)
	end
	table.sort(values, function(a, b)
		return incomeOf(a) > incomeOf(b)
	end)
	local kept = {}
	for i = 1, math.min(count, #values) do
		kept[i] = values[i]
	end
	return kept
end

-- Mutates `data` in place. `cfg` = GameConfig. `incomeOf` (slot value -> $/s) picks the
-- Heirloom; without it the Vault is left untouched. `keepGadget(id)`: gadgets that survive
-- (the Ascension Shop's).
function AscensionReset.Apply(data, newLevel: number, title: string, cfg, incomeOf: ((string) -> number)?, keepGadget: ((string) -> boolean)?)
	data.Strength = cfg.Strength.Start
	data.Ascension = newLevel
	if cfg.Ascension.ResetsCash then
		data.Cash = 0
		if data.Vault then
			data.Vault.Stored = 0 -- uncollected earnings on the pad are cash too
		end
	end
	if cfg.Ascension.ResetsVault and incomeOf and data.Vault then
		local kept = AscensionReset.Heirlooms(data.Vault.Displays, cfg.Ascension.HeirloomsKept or 0, incomeOf)
		data.Vault.Displays = {}
		for i, value in kept do
			data.Vault.Displays[tostring(i)] = value
		end
	end
	if cfg.Ascension.ResetsGadgets then
		-- Ascension Shop gadgets are kept (and stay equipped); the rest are reset.
		local kept = {}
		for id in data.OwnedGadgets do
			if keepGadget and keepGadget(id) then
				kept[id] = true
			end
		end
		local equipped = {}
		for _, id in data.EquippedGadgets do
			if kept[id] then
				table.insert(equipped, id)
			end
		end
		data.OwnedGadgets = kept
		data.EquippedGadgets = {}
		for i = 1, cfg.Gadgets.Slots do
			data.EquippedGadgets[i] = equipped[i] or ""
		end
	end
	if not table.find(data.Titles, title) then
		table.insert(data.Titles, title)
	end
	data.SelectedTitle = title
end

return AscensionReset
