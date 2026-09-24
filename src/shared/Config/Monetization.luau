-- Monetisation catalogue. Pure data (shared by server + client).
--
-- PRINCIPLES (weighed against the core game):
--   * Never sell PvP power: nothing makes you hit harder, steal faster or shrug off hits.
--   * Sell TIME and CONVENIENCE on your own progress (income, training, offline, auto-collect).
--   * Sell SERVER-WIDE moments that make everyone's session better (Treasure Rain, Gold Rush):
--     the buyer gets the shout-out, the whole server gets the loot - viral, not pay-to-win.
--   * Free players get generous free boosts too (daily streak, friends, Premium, group).
--
-- Ids are the live Roblox game passes / developer products (created 2026-09-24 by the
-- "Monetization setup" workflow). Id = 0 means "not created yet": shown as SOON, no perk.
-- Prices here are for display; the real price is whatever is set on Roblox.

local Monetization = {}

-- One-time GAME PASSES.
Monetization.Passes = {
	VIP = {
		Id = 1994030514,
		Price = 299,
		Icon = "👑",
		Name = "VIP",
		Description = "+20% Vault income forever, a golden VIP title and double daily rewards.",
		IncomeMultiplier = 1.2,
		DailyRewardMultiplier = 2,
	},
	DoubleCash = {
		Id = 1996034488,
		Price = 499,
		Icon = "💰",
		Name = "2x Cash",
		Description = "Your Vault earns double, forever.",
		IncomeMultiplier = 2,
	},
	DoubleStrength = {
		Id = 1997222487,
		Price = 349,
		Icon = "💪",
		Name = "2x Strength",
		Description = "Every rep at the gym gives double Strength, forever.",
		TrainingMultiplier = 2,
	},
	OfflineVault = {
		Id = 1994660511,
		Price = 149,
		Icon = "🌙",
		Name = "Night Shift",
		Description = "While you're offline your Vault earns 100% (not 50%) for up to 4 hours (not 30 min).",
		OfflineRate = 1,
		OfflineMaxHours = 4,
	},
	AutoCollect = {
		Id = 1995998488,
		Price = 99,
		Icon = "🧲",
		Name = "Auto Collect",
		Description = "Vault cash lands in your pocket automatically - no walking to the pad.",
	},
}

-- Repeatable DEVELOPER PRODUCTS.
-- Cash packs scale with YOUR income so they are always worth the same: `Minutes` of your
-- current Vault income (with a floor so new players get a real boost too).
Monetization.Products = {
	CashSmall = { Id = 3714570437, Price = 29, Icon = "💵", Name = "Pocket Cash", Kind = "Cash", Minutes = 10, Minimum = 5000 },
	CashMedium = { Id = 3714570439, Price = 99, Icon = "💰", Name = "Treasure Sack", Kind = "Cash", Minutes = 45, Minimum = 30000 },
	CashLarge = { Id = 3714570440, Price = 399, Icon = "🏦", Name = "Dragon Hoard", Kind = "Cash", Minutes = 240, Minimum = 250000 },
	-- Server-wide: everyone profits, the buyer is celebrated.
	TreasureRain = {
		Id = 3714570441,
		Price = 149,
		Icon = "🌧",
		Name = "Treasure Rain",
		Kind = "ServerEvent",
		Event = "TreasureRain",
		Description = "Make it rain treasure for the WHOLE server (starts now, or at dawn).",
	},
	GoldRush = {
		Id = 3714570442,
		Price = 99,
		Icon = "✨",
		Name = "Gold Rush",
		Kind = "ServerEvent",
		Event = "GoldRush",
		Description = "Tonight's loot in one region is x6 more likely to be MUTATED - for everyone.",
	},
	StrengthSurge = {
		Id = 3714570443,
		Price = 49,
		Icon = "⚡",
		Name = "Strength Surge",
		Kind = "Boost",
		Boost = "Training",
		Multiplier = 3,
		Minutes = 15,
		Description = "Triple gym gains for 15 minutes.",
	},
}

-- Display order in the store.
Monetization.PassOrder = { "DoubleCash", "VIP", "DoubleStrength", "OfflineVault", "AutoCollect" }
Monetization.ProductOrder = { "TreasureRain", "GoldRush", "StrengthSurge", "CashSmall", "CashMedium", "CashLarge" }

-- FREE boosts (retention + virality, no Robux).
Monetization.Free = {
	PremiumIncomeMultiplier = 1.1, -- Roblox Premium members (also drives Premium Payouts)
	FriendIncomeBonus = 0.1, -- +10% Vault income per friend in the server...
	FriendIncomeMax = 0.3, -- ...up to +30%
	GroupId = 0, -- community group; members get GroupIncomeMultiplier (0 = off)
	GroupIncomeMultiplier = 1.1,
	-- Daily streak: log in on consecutive days (UTC). Reward = Minutes of your income, with a
	-- floor; day 7 is the jackpot, then the streak loops. Missing a day restarts at day 1.
	Daily = {
		{ Minutes = 5, Minimum = 1000 },
		{ Minutes = 8, Minimum = 2000 },
		{ Minutes = 12, Minimum = 4000 },
		{ Minutes = 16, Minimum = 7000 },
		{ Minutes = 20, Minimum = 12000 },
		{ Minutes = 25, Minimum = 20000 },
		{ Minutes = 45, Minimum = 50000, Jackpot = true },
	},
}

function Monetization.PassById(id: number)
	for key, pass in Monetization.Passes do
		if pass.Id == id and id ~= 0 then
			return key, pass
		end
	end
	return nil, nil
end

function Monetization.ProductById(id: number)
	for key, product in Monetization.Products do
		if product.Id == id and id ~= 0 then
			return key, product
		end
	end
	return nil, nil
end

-- Cash granted by a scaled reward (cash pack or daily reward): `minutes` of `income` $/s,
-- never less than `minimum`.
function Monetization.ScaledCash(income: number, minutes: number, minimum: number): number
	return math.max(minimum, math.floor(income * minutes * 60))
end

-- Total Vault income multiplier from passes + free boosts.
-- owned = { [passKey] = true }, friends = number of friends in the server.
function Monetization.IncomeMultiplier(owned, isPremium: boolean, friends: number, inGroup: boolean): number
	local multiplier = 1
	for key, pass in Monetization.Passes do
		if owned[key] and pass.IncomeMultiplier then
			multiplier *= pass.IncomeMultiplier
		end
	end
	local free = Monetization.Free
	if isPremium then
		multiplier *= free.PremiumIncomeMultiplier
	end
	if inGroup and free.GroupId ~= 0 then
		multiplier *= free.GroupIncomeMultiplier
	end
	multiplier *= 1 + math.min(free.FriendIncomeMax, friends * free.FriendIncomeBonus)
	return multiplier
end

-- Daily streak step: returns (newStreakDay, isNewDay). `lastDay`/`today` are UTC day numbers.
function Monetization.NextStreak(lastDay: number, streak: number, today: number): (number, boolean)
	if lastDay == today then
		return streak, false
	end
	if lastDay == today - 1 then
		return streak % #Monetization.Free.Daily + 1, true
	end
	return 1, true
end

return Monetization
