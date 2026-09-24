-- What an Ascension wipes (pure, unit-tested). You start the grind over - Strength back to the
-- start, ALL Cash gone and every gadget gone - in exchange for a permanent income + training
-- multiplier. Kept: Vault + its treasures, Collection, benches, titles, cosmetics, stats.

local AscensionReset = {}

-- Mutates `data` in place. `cfg` = GameConfig.
function AscensionReset.Apply(data, newLevel: number, title: string, cfg)
	data.Strength = cfg.Strength.Start
	data.Ascension = newLevel
	if cfg.Ascension.ResetsCash then
		data.Cash = 0
		if data.Vault then
			data.Vault.Stored = 0 -- uncollected earnings on the pad are cash too
		end
	end
	if cfg.Ascension.ResetsGadgets then
		data.OwnedGadgets = {}
		data.EquippedGadgets = { "", "", "" }
	end
	if not table.find(data.Titles, title) then
		table.insert(data.Titles, title)
	end
	data.SelectedTitle = title
end

return AscensionReset
