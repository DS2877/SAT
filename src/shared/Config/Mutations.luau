-- Treasure mutations: rare variants that LOOK different (material / colour / sparkle) and
-- multiply the treasure's income and sell price. A treasure has at most one mutation.
-- Chance = probability per normal spawn. Moonlit only rolls at night (see DayNight).
-- Pure data (colours are RGB arrays, see Mutations.Color) so tests can load it.

local Mutations = {}

Mutations.Order = { "Silver", "Gold", "Diamond", "Moonlit", "Rainbow" }

Mutations.Info = {
	Silver = {
		Multiplier = 1.5,
		Chance = 0.06,
		Color = { 205, 215, 230 },
		Material = "Metal",
		Sparkle = { 235, 240, 255 },
	},
	Gold = {
		Multiplier = 2,
		Chance = 0.03,
		Color = { 255, 196, 40 },
		Material = "Metal",
		Sparkle = { 255, 225, 120 },
	},
	Diamond = {
		Multiplier = 3,
		Chance = 0.012,
		Color = { 130, 235, 255 },
		Material = "Glass",
		Sparkle = { 255, 255, 255 },
	},
	Moonlit = {
		Multiplier = 4,
		Chance = 0,
		NightChance = 0.08, -- only while it is night
		Color = { 150, 170, 255 },
		Material = "Neon",
		Sparkle = { 200, 215, 255 },
	},
	Rainbow = {
		Multiplier = 6,
		Chance = 0.003,
		Color = { 255, 255, 255 },
		Material = "SmoothPlastic",
		Rainbow = true, -- clients cycle the colours
		Sparkle = { 255, 255, 255 },
	},
}

-- Color3 of an RGB array (client/server only; tests never call this).
function Mutations.Color(rgb: { number }): Color3
	return Color3.fromRGB(rgb[1], rgb[2], rgb[3])
end

function Mutations.Get(name: string?)
	return if name then Mutations.Info[name] else nil
end

function Mutations.Multiplier(name: string?): number
	local info = Mutations.Get(name)
	return if info then info.Multiplier else 1
end

-- Rolls a mutation (or nil). `chanceBoost` multiplies every chance (events).
function Mutations.Roll(random: () -> number, isNight: boolean, chanceBoost: number?): string?
	local roll = random()
	local boost = chanceBoost or 1
	-- Rarest first so a boost can't push common mutations over the rare ones.
	for i = #Mutations.Order, 1, -1 do
		local name = Mutations.Order[i]
		local info = Mutations.Info[name]
		local chance = (info.Chance + (if isNight then info.NightChance or 0 else 0)) * boost
		if roll < chance then
			return name
		end
		roll -= chance
	end
	return nil
end

return Mutations
