-- Pure-logic unit tests. Run with: lune run tests/run
-- Covers the rules that must never silently break: carry formula, stability machine,
-- treasure rolls/caps, training grading, save migration, and content invariants.

local GameConfig = require("../src/shared/Config/GameConfig")
local Treasures = require("../src/shared/Config/Treasures")
local Gadgets = require("../src/shared/Config/Gadgets")
local Carry = require("../src/shared/Logic/Carry")
local Stability = require("../src/shared/Logic/Stability")
local TreasureRoll = require("../src/shared/Logic/TreasureRoll")
local DataSchema = require("../src/shared/Logic/DataSchema")
local Economy = require("../src/shared/Logic/Economy")
local DayNight = require("../src/shared/Logic/DayNight")
local Lifting = require("../src/shared/Logic/Lifting")
local AscensionReset = require("../src/shared/Logic/AscensionReset")
local Monetization = require("../src/shared/Config/Monetization")
local Mutations = require("../src/shared/Config/Mutations")
local Music = require("../src/shared/Config/Music")
Economy.Use(GameConfig, Mutations)
DayNight.Use(GameConfig)
Lifting.Use(GameConfig)
local TerrainGen = require("../src/server/World/TerrainGen")

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Divine", "Secret", "OG" }

local passed, failed = 0, 0
local currentTest = ""

local function check(condition: boolean, message: string)
	if condition then
		passed += 1
	else
		failed += 1
		print(("  FAIL [%s] %s"):format(currentTest, message))
	end
end

local function near(a: number, b: number, eps: number?): boolean
	return math.abs(a - b) <= (eps or 1e-6)
end

local function test(name: string, fn: () -> ())
	currentTest = name
	local ok, err = pcall(fn)
	if not ok then
		failed += 1
		print(("  ERROR [%s] %s"):format(name, tostring(err)))
	end
end

-- CARRY -------------------------------------------------------------------------
test("carry bands match spec", function()
	local cfg = GameConfig.Carry
	check(Carry.SpeedMultiplier(25, 100, cfg) == 1.0, "ratio 0.25 -> 100%")
	check(Carry.SpeedMultiplier(10, 100, cfg) == 1.05, "ratio 0.10 -> 105% (overpowered)")
	check(Carry.SpeedMultiplier(5, 100, cfg) == 1.1, "ratio 0.05 -> 110% (overpowered)")
	check(Carry.SpeedMultiplier(26, 100, cfg) == 0.9, "ratio 0.26 -> 90%")
	check(Carry.SpeedMultiplier(50, 100, cfg) == 0.9, "ratio 0.50 -> 90%")
	check(Carry.SpeedMultiplier(75, 100, cfg) == 0.75, "ratio 0.75 -> 75%")
	check(Carry.SpeedMultiplier(100, 100, cfg) == 0.6, "ratio 1.00 -> 60%")
	check(Carry.SpeedMultiplier(150, 100, cfg) == 0.45, "ratio 1.50 -> 45%")
	check(Carry.SpeedMultiplier(151, 100, cfg) == 0.3, "ratio >1.50 -> 30%")
	check(Carry.SpeedMultiplier(1, 1, cfg) == 0.6, "strength 1 carrying weight 1")
	check(Carry.SpeedMultiplier(80, 0, cfg) == 0.3, "zero strength treated as 1, never errors")
	for _, def in Treasures.List do
		if def.Rarity == "Common" then
			check(Carry.SpeedMultiplier(def.Weight, GameConfig.Strength.Start, cfg) >= 0.9, "a new player carries " .. def.Id .. " at 90%+")
		end
	end
end)

test("carry never hard-locks and jump has a floor", function()
	local cfg = GameConfig.Carry
	check(Carry.SpeedMultiplier(10000, 1, cfg) > 0, "absurd weight is still movable")
	check(Carry.JumpMultiplier(0.3, cfg) == cfg.JumpMultiplierFloor, "jump floor applies")
	check(Carry.JumpMultiplier(1, cfg) == 1, "light carry keeps full jump")
	check(Carry.RecommendedStrength(5000, cfg) == 6000, "weight 5,000 -> recommended 6,000")
end)

-- STABILITY ---------------------------------------------------------------------
test("stable -> shaken -> knocked", function()
	local cfg = GameConfig.Stability
	local st = Stability.new()
	check(Stability.Hit(st, 0, cfg) == "Shaken", "first hit shakes")
	check(Stability.Hit(st, 1, cfg) == "Knocked", "second hit inside window knocks")
	check(st.KnockedUntil == 1 + cfg.KnockedDuration, "knock duration")
	check(Stability.Hit(st, 1.5, cfg) == "Ignored", "no chain-stun while knocked")
	local recover = 1 + cfg.KnockedDuration
	check(Stability.Hit(st, recover + 0.1, cfg) == "Ignored", "knock immunity after recovery")
	check(st.State == "Stable", "recovered to stable")
	check(Stability.Hit(st, recover + cfg.KnockImmunity + 0.01, cfg) == "Shaken", "hits count again after immunity")
end)

test("shaken decays back to stable", function()
	local cfg = GameConfig.Stability
	local st = Stability.new()
	Stability.Hit(st, 10, cfg)
	check(Stability.Update(st, 10 + cfg.ShakenWindow - 0.01, cfg) == false, "still shaken inside window")
	check(Stability.Update(st, 10 + cfg.ShakenWindow, cfg) == true, "decays at window end")
	check(Stability.Hit(st, 20, cfg) == "Shaken", "fresh hit after decay only shakes")
end)

-- TREASURE ROLL -------------------------------------------------------------------
test("rolls respect area, rarity range and caps", function()
	local cfg = GameConfig.Treasure
	local weights, anywhere = TreasureRoll.WeightsFor(cfg, 3)
	local point = { Area = "Ruins", MinRarity = "Epic", MaxRarity = "Mythic" }
	local candidates = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, weights, cfg.RarityCaps, {})
	check(#candidates > 0, "ruins epic+ has candidates")
	for _, c in candidates do
		check(c.Def.SpawnArea == "Ruins", "area filter " .. c.Def.Id)
		check(c.Def.Rarity == "Epic" or c.Def.Rarity == "Legendary" or c.Def.Rarity == "Mythic", "rarity filter " .. c.Def.Id)
	end
	local capped = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, weights, cfg.RarityCaps, { Legendary = 2, Mythic = 1 })
	for _, c in capped do
		check(c.Def.Rarity == "Epic", "caps exclude capped rarities: " .. c.Def.Id)
	end
	local none = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, weights, cfg.RarityCaps, { Epic = 5, Legendary = 2, Mythic = 1 })
	check(#none == 0 and TreasureRoll.Pick(none, math.random) == nil, "fully capped point spawns nothing")
	-- Mythic and above ignore the region: a Wilds point can roll them.
	local wilds = TreasureRoll.Candidates(Treasures.List, { Area = "Wilds" }, RARITY_ORDER, weights, cfg.RarityCaps, {}, anywhere)
	local foreignMythic, foreignRare = false, false
	for _, c in wilds do
		if c.Def.SpawnArea ~= "Wilds" then
			if table.find(RARITY_ORDER, c.Def.Rarity) >= table.find(RARITY_ORDER, "Mythic") then
				foreignMythic = true
			else
				foreignRare = true
			end
		end
	end
	check(foreignMythic, "Mythic+ can spawn outside their home region")
	check(not foreignRare, "Common..Legendary stay in their home region")
end)

test("loot follows the region's danger", function()
	local cfg = GameConfig.Treasure
	local function seeded()
		local seed = 12345
		return function()
			seed = (seed * 1103515245 + 12345) % 2147483648
			return seed / 2147483648
		end
	end
	local function share(area: string, danger: number)
		local weights, anywhere = TreasureRoll.WeightsFor(cfg, danger)
		local candidates = TreasureRoll.Candidates(Treasures.List, { Area = area }, RARITY_ORDER, weights, {}, {}, anywhere)
		local counts, rand = {}, seeded()
		for _ = 1, 20000 do
			local def = TreasureRoll.Pick(candidates, rand)
			counts[def.Rarity] = (counts[def.Rarity] or 0) + 1
		end
		for rarity, n in counts do
			counts[rarity] = n / 20000
		end
		return counts
	end
	local wilds, falls, frost = share("Wilds", 1), share("Falls", 4), share("Frost", 3)
	check((wilds.Common or 0) > 0.45, "the Wilds are mostly Common")
	check((wilds.Epic or 0) > 0 and (wilds.Epic or 0) < 0.03, "Epic is rare in the Wilds")
	check((falls.Uncommon or 0) > 0.05, "Uncommons still turn up in the hardest region")
	check((falls.Common or 0) == 0, "no Commons at the Falls")
	check((falls.Epic or 0) > 0.3, "the Falls are Epic country")
	check((frost.Rare or 0) + (frost.Epic or 0) > 0.5, "Frostpeak is mostly Rare/Epic")
	local mythicPlus = function(t)
		return (t.Mythic or 0) + (t.Divine or 0) + (t.Secret or 0) + (t.OG or 0)
	end
	check(mythicPlus(wilds) > 0 and mythicPlus(wilds) < 0.01, "Mythic+ is a rare surprise anywhere")
	for danger, row in cfg.RarityByDanger do
		local total = 0
		for _, w in row do
			total += w
		end
		check(math.abs(total - 100) < 0.01, ("danger %d weights sum to 100"):format(danger))
	end
	for rarity in cfg.AnywhereWeights do
		check(table.find(RARITY_ORDER, rarity) >= table.find(RARITY_ORDER, "Mythic"), "only Mythic+ roam: " .. rarity)
	end
end)

test("every spawn area referenced by treasures can spawn something", function()
	local areas = {}
	for _, def in Treasures.List do
		areas[def.SpawnArea] = true
	end
	for area in areas do
		local known = { Wilds = true, Ruins = true, Coast = true, Falls = true, Frost = true, Marsh = true, Ember = true, Rime = true, Star = true }
		check(known[area] == true, "known area " .. area)
	end
end)

-- TRAINING ------------------------------------------------------------------------
test("bench tiers: ordered, ascension-gated, and every ascension climb takes a sensible time", function()
	local tiers = GameConfig.Training.Benches
	check(#tiers >= 4, "at least four bench tiers")
	for i, tier in tiers do
		check(tier.RepGain >= 1 and tier.Count > 0, "valid tier " .. tier.Id)
		if i > 1 then
			check(tier.RepGain > tiers[i - 1].RepGain, "rep gain increases " .. tier.Id)
			check(tier.Price > tiers[i - 1].Price, "price increases " .. tier.Id)
			check(tier.RequiredAscension >= tiers[i - 1].RequiredAscension, "gate never goes down " .. tier.Id)
		end
	end
	-- Minutes on the bench (10-minute sessions: pump, sets and jackpots averaged in) to climb from a
	-- fresh reset to the next Ascension, on the best bench allowed.
	local previousRequirement = 0
	for level = 0, 6 do
		local best = 0
		for _, tier in tiers do
			if tier.RequiredAscension <= level then
				best = math.max(best, Lifting.ExpectedRate(GameConfig.GetRepGain(tier, level), 600))
			end
		end
		local requirement = GameConfig.GetAscensionRequirement(level)
		local minutes = (requirement - GameConfig.Strength.Start) / best / 60
		check(requirement > previousRequirement, ("requirement grows at ascension %d"):format(level))
		-- The first Ascension is deliberately quick (10K): a new player should reach it early.
		local low = if level == 0 then 3 else 8
		check(minutes >= low and minutes <= 50, ("ascension %d climb takes %.1f min (%d-50)"):format(level, minutes, low))
		previousRequirement = requirement
	end
	check(GameConfig.GetAscensionRequirement(0) == 10000, "the first Ascension needs 10,000 Strength")
	-- Banking treasure makes you stronger too: worth a real chunk of benching, never more than it.
	for level = 0, 3 do
		local bestBench = 0
		for _, tier in tiers do
			if tier.RequiredAscension <= level then
				bestBench = math.max(bestBench, Lifting.ExpectedRate(GameConfig.GetRepGain(tier, level), 600))
			end
		end
		local rareBank = GameConfig.ExtractionStrength(1000, level)
		local seconds = rareBank / bestBench
		check(seconds >= 3 and seconds <= 120, ("banking a Rare at Ascension %d = %.0f s of your best bench (3-120)"):format(level, seconds))
	end
	check(GameConfig.ExtractionStrength(300, 0) >= 250, "even a Common bank gives a real Strength bump")
	check(GameConfig.GetTrainingMultiplier(3) > GameConfig.GetTrainingMultiplier(2), "training speeds up every ascension")
	check(GameConfig.GetRepGain(tiers[1], 0) >= 5, "even the first rep pays out a satisfying number")
	check(GameConfig.Training.CritChance > 0 and GameConfig.Training.CritMultiplier > 1, "MEGA REP jackpot exists")
end)

test("training is a waiting game that rewards staying", function()
	local cfg = GameConfig.Training
	check(cfg.TapBoost == nil and cfg.ComboMax == nil, "no tapping mechanic left")
	check(Lifting.Pump(1) == 1, "first rep is x1")
	check(Lifting.Pump(10) > Lifting.Pump(2), "pump grows rep by rep")
	check(Lifting.Pump(1000) == cfg.PumpMax, "pump is capped")
	local toMax = Lifting.RepsToMaxPump() * cfg.RepPeriod
	check(toMax >= 20 and toMax <= 90, ("max pump in %.0f s (20-90)"):format(toMax))
	check(Lifting.RepAmount(10, 1, "Normal") == 10, "plain rep")
	check(Lifting.RepAmount(10, 1, "Mega") == 10 * cfg.CritMultiplier, "mega rep")
	check(Lifting.RepAmount(10, 1, "Golden") == 10 * cfg.GoldenMultiplier, "golden rep")
	check(Lifting.RepAmount(0.1, 1, "Normal") == 1, "a rep always pays something")
	check(not Lifting.IsSetComplete(cfg.SetSize - 1) and Lifting.IsSetComplete(cfg.SetSize), "set every SetSize reps")
	check(Lifting.IsSetComplete(cfg.SetSize * 3) and not Lifting.IsSetComplete(0), "sets repeat, rep 0 is not a set")
	check(Lifting.SetBonus(100) == math.floor(100 * cfg.SetBonus + 0.5), "set bonus")
	-- Rolls: golden rarest, then mega, then normal.
	check(Lifting.Roll(function() return 0 end) == "Golden", "lowest roll = golden")
	check(Lifting.Roll(function() return cfg.GoldenChance + cfg.CritChance / 2 end) == "Mega", "mega band")
	check(Lifting.Roll(function() return 0.99 end) == "Normal", "normal")
	-- Staying longer is always worth more per second.
	check(Lifting.ExpectedRate(10, 600) > Lifting.ExpectedRate(10, 60), "long sessions pay more per second")
	check(Lifting.ExpectedRate(10, 60) > Lifting.ExpectedRate(10, 10), "even a minute beats hopping on and off")
	check(Lifting.ExpectedRate(10, 600) < 10 / cfg.RepPeriod * 5, "but it stays sane (< x5 base)")
end)

test("ascension cash requirement keeps up with the economy", function()
	-- The best income a full 60-slot Vault of Legendaries could make, at that ascension.
	local legendary = 0
	for _, def in Treasures.List do
		if def.Rarity == "Legendary" then
			legendary = math.max(legendary, Economy.Income(def))
		end
	end
	for level = 1, 5 do
		local cost = GameConfig.GetAscensionCost(level)
		if level > 1 then
			check(cost > GameConfig.GetAscensionCost(level - 1), "cost grows " .. level)
		end
		local minutes = cost / (20 * legendary * GameConfig.GetAscensionMultiplier(level - 1)) / 60
		check(minutes >= 1, ("ascension %d cash is a real goal (%.1f min for 20 Legendaries)"):format(level, minutes))
	end
	check(GameConfig.Ascension.ResetsVault and GameConfig.Ascension.HeirloomsKept >= 1, "rebirth keeps an Heirloom")
	check(GameConfig.GetAscensionMultiplier(1) >= 1.5, "the first ascension is worth the reset")
	local tiers = GameConfig.Vault.Tiers
	for i = 2, #tiers do
		check(tiers[i].Price >= tiers[i - 1].Price * 10, ("vault tier %d is a real step up"):format(i))
	end
end)

test("monetisation is fair, scaled and idempotent-friendly", function()
	-- No PvP power for sale: only income / training / offline / convenience / server events.
	local allowed = { IncomeMultiplier = true, DailyRewardMultiplier = true, TrainingMultiplier = true, OfflineRate = true, OfflineMaxHours = true }
	for key, pass in Monetization.Passes do
		check(pass.Price > 0 and type(pass.Id) == "number", "pass configured: " .. key)
		for field in pass do
			if not ({ Id = true, Price = true, Icon = true, Name = true, Description = true })[field] then
				check(allowed[field] == true, ("pass %s only sells progress/convenience (%s)"):format(key, field))
			end
		end
		check(table.find(Monetization.PassOrder, key) ~= nil, "pass listed in the store: " .. key)
	end
	for key, product in Monetization.Products do
		check(product.Price > 0, "product priced: " .. key)
		check(({ Cash = true, ServerEvent = true, Boost = true })[product.Kind] == true, "product kind: " .. key)
		check(table.find(Monetization.ProductOrder, key) ~= nil, "product listed in the store: " .. key)
	end
	-- Cash packs: bigger pack = better value per Robux, and they scale with income.
	local small, large = Monetization.Products.CashSmall, Monetization.Products.CashLarge
	check(large.Minutes / large.Price > small.Minutes / small.Price, "bulk cash is better value")
	check(Monetization.ScaledCash(0, 10, 5000) == 5000, "new players get the floor")
	check(Monetization.ScaledCash(1000, 10, 5000) == 600000, "10 minutes of $1K/s")
	-- Income boost stacking.
	check(Monetization.IncomeMultiplier({}, false, 0, false) == 1, "no boost by default")
	check(math.abs(Monetization.IncomeMultiplier({ DoubleCash = true }, false, 0, false) - 2) < 1e-9, "2x cash")
	check(math.abs(Monetization.IncomeMultiplier({}, false, 10, false) - 1.3) < 1e-9, "friend boost capped at +30%")
	check(Monetization.IncomeMultiplier({}, true, 0, false) > 1, "premium boost")
	-- Daily streak.
	check(select(1, Monetization.NextStreak(0, 0, 100)) == 1, "first login = day 1")
	check(select(1, Monetization.NextStreak(99, 3, 100)) == 4, "consecutive day advances")
	check(select(1, Monetization.NextStreak(97, 3, 100)) == 1, "missed a day resets")
	check(select(2, Monetization.NextStreak(100, 3, 100)) == false, "only once per day")
	check(select(1, Monetization.NextStreak(99, #Monetization.Free.Daily, 100)) == 1, "streak loops after the jackpot")
	check(Monetization.Free.Daily[#Monetization.Free.Daily].Jackpot == true, "last day is the jackpot")
	-- Id 0 = not created yet: never matched.
	check(Monetization.PassById(0) == nil and Monetization.ProductById(0) == nil, "placeholder ids never match")
end)

test("adventure: boost pads and geysers are sane", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	local boost = GameConfig.Boost
	check(boost.SpeedMultiplier > 1.2 and boost.SpeedMultiplier < 1.8, "boost is noticeable but not absurd")
	check(boost.Duration >= 2 and boost.Duration <= 6, "boost is a burst, not a mode")
	check(boost.Cooldown >= 1, "no boost chaining on one pad")
	check(boost.Count >= 12 and boost.Count <= 40, "enough rings to find, not a carpet")
	check(boost.MinSpacing * boost.MinSpacing * boost.Count < math.pi * boost.MaxDistance ^ 2 * 0.5, "ring spacing leaves room to place them all")
	check(boost.SpeedMultiplier * GameConfig.Player.BaseWalkSpeed < 30, "a boosted player can still be caught by a boosted chaser")
	local cliffTop = WorldLayout.Waterfall.CliffCenter.Y + WorldLayout.Waterfall.CliffSize.Y / 2
	local templeTop = WorldLayout.Temple.Center.Y + WorldLayout.Temple.Tiers * WorldLayout.Temple.TierHeight
	local found = {}
	for _, pad in WorldLayout.LaunchPads do
		found[pad.Name] = pad
		local dy = pad.Target.Y - pad.Position.Y
		check(dy > 0 and dy < 100, pad.Name .. " launches upward within reason")
		local flat = Vector3.new(pad.Target.X - pad.Position.X, 0, pad.Target.Z - pad.Position.Z).Magnitude
		check(flat > 10 and flat < 70, pad.Name .. " lands near, not across the map")
	end
	check(found["Cliff Geyser"] and math.abs(found["Cliff Geyser"].Target.Y - cliffTop) <= 3, "cliff geyser lands on the cliff top")
	check(found["Temple Geyser"] and math.abs(found["Temple Geyser"].Target.Y - templeTop) <= 2, "temple geyser lands on the temple top")
	-- Frostpeak and the Marsh sit beside the District without touching its wall.
	for _, region in { WorldLayout.Frostpeak, WorldLayout.Marsh } do
		local d = Vector3.new(region.Center.X - WorldLayout.District.Center.X, 0, region.Center.Z - WorldLayout.District.Center.Z).Magnitude
		check(d > GameConfig.SafeZone.Radius + 60, "new region centre is well outside the District")
		check(Vector3.new(region.Center.X, 0, region.Center.Z).Magnitude + region.Radius * 0.5 < 470, "new region fits on the island")
	end
end)

test("offline earnings are capped and reduced", function()
	local cfg = GameConfig.Economy
	check(cfg.OfflineIncomeRate > 0 and cfg.OfflineIncomeRate <= 1, "offline rate is a fraction")
	check(cfg.OfflineMaxHours > 0 and cfg.OfflineMaxHours <= 4, "offline cap is short")
	local amount, seconds = Economy.OfflineEarnings(1000, 1000000, 1000000 + 1200)
	check(seconds == 1200 and amount == math.floor(1000 * cfg.OfflineIncomeRate * 1200), "20 minutes offline at the offline rate")
	local capped = Economy.OfflineEarnings(1000, 1000000, 1000000 + 7 * 24 * 3600)
	check(capped == math.floor(1000 * cfg.OfflineIncomeRate * cfg.OfflineMaxHours * 3600), "capped at OfflineMaxHours")
	check(Economy.OfflineEarnings(1000, 0, 5000000) == 0, "first join / old saves earn nothing")
	check(Economy.OfflineEarnings(1000, 1000000, 1000000 + 20) == 0, "a quick rejoin earns nothing")
	check(Economy.OfflineEarnings(1000, 2000000, 1000000) == 0, "clock going backwards earns nothing")
	check(DataSchema.Default().LastOnline == 0, "LastOnline defaults to 0")
	check(DataSchema.Migrate({ LastOnline = "junk" }).LastOnline == 0, "LastOnline sanitised")
end)

test("ascension is a real fresh start", function()
	local data = DataSchema.Migrate({
		Cash = 987654,
		Strength = 99999,
		Ascension = 0,
		OwnedGadgets = { balloon = true, speed_soda = true },
		EquippedGadgets = { "balloon", "speed_soda", "" },
		OwnedBenches = { iron = true },
		Vault = { Tier = 2, Displays = { ["1"] = "coin_pouch", ["2"] = "golden_crown", ["3"] = "ruby_ring|Gold" }, Stored = 5000 },
		Collection = { golden_crown = { Discovered = true, Count = 1 } },
	})
	local function incomeOf(value)
		local id, mutation = Economy.DecodeSlot(value)
		local def = id and Treasures.Get(id)
		return if def then Economy.Income(def, mutation) else 0
	end
	AscensionReset.Apply(data, 1, "Ascended", GameConfig, incomeOf)
	check(data.Ascension == 1 and data.SelectedTitle == "Ascended", "level + title")
	check(data.Strength == GameConfig.Strength.Start, "strength reset")
	check(data.Cash == 0 and data.Vault.Stored == 0, "ALL cash lost (incl. uncollected)")
	check(next(data.OwnedGadgets) == nil, "every gadget lost")
	check(data.EquippedGadgets[1] == "" and data.EquippedGadgets[2] == "" and data.EquippedGadgets[3] == "", "loadout cleared")
	check(data.OwnedBenches.iron == true, "benches kept")
	check(data.Vault.Tier == 2, "vault size kept")
	check(data.Vault.Displays["1"] == "golden_crown", "the best treasure is kept as the Heirloom on pedestal 1")
	check(data.Vault.Displays["2"] == nil and data.Vault.Displays["3"] == nil, "every other treasure is gone")
	check(data.Collection.golden_crown ~= nil, "collection kept")
	AscensionReset.Apply(data, 2, "Ascended", GameConfig, incomeOf)
	local count = 0
	for _, title in data.Titles do
		if title == "Ascended" then
			count += 1
		end
	end
	check(count == 1, "titles not duplicated")
end)

test("uncapped strength keeps making carrying easier (within limits)", function()
	local cfg = GameConfig.Carry
	check(GameConfig.Strength.Max == math.huge, "strength is uncapped")
	check(Carry.SpeedMultiplier(70, 1000, cfg) > Carry.SpeedMultiplier(70, 100, cfg), "more strength = faster carry")
	check(Carry.SpeedMultiplier(1, 10000, cfg) <= 1.1, "overpowered bonus stays small (chaseable)")
	check(Carry.JumpMultiplier(Carry.SpeedMultiplier(1, 10000, cfg), cfg) == 1, "jump never boosted")
end)

-- ECONOMY -------------------------------------------------------------------------
test("vault income by rarity follows the genre ranges and mutations multiply it", function()
	local ranges = { -- $/s, loosely Steal a Brainrot's bands
		Common = { 1, 14 },
		Uncommon = { 5, 40 },
		Rare = { 15, 120 },
		Epic = { 75, 500 },
		Legendary = { 200, 2500 },
		Mythic = { 2500, 20000 },
		Divine = { 10000, 25000 },
		Secret = { 10000, 100000 },
		OG = { 40000, 200000 },
	}
	for _, def in Treasures.List do
		local income = Economy.Income(def)
		local r = ranges[def.Rarity]
		check(income >= r[1] and income <= r[2], ("%s earns $%d/s (%s range)"):format(def.Id, income, def.Rarity))
		check(Economy.Income(def, "Gold") > income, "gold mutation earns more " .. def.Id)
		check(Economy.SellPrice(def) == income * GameConfig.Economy.SellIncomeSeconds, "sell price = income window " .. def.Id)
	end
	local previous = 0
	for _, name in Mutations.Order do
		local mult = Mutations.Multiplier(name)
		check(mult > 1, name .. " multiplies income")
		if name ~= "Rainbow" and name ~= "Moonlit" then
			check(mult > previous, name .. " rarer mutation, bigger multiplier")
			previous = mult
		end
	end
end)

test("vault slots encode treasure + mutation and read old saves", function()
	check(Economy.EncodeSlot("jade_frog", nil) == "jade_frog", "plain id")
	local id, mutation = Economy.DecodeSlot(Economy.EncodeSlot("jade_frog", "Gold"))
	check(id == "jade_frog" and mutation == "Gold", "round trip")
	id, mutation = Economy.DecodeSlot("golden_crown")
	check(id == "golden_crown" and mutation == nil, "legacy plain id")
	id, mutation = Economy.DecodeSlot("golden_crown|Nonsense")
	check(id == "golden_crown" and mutation == nil, "unknown mutation ignored")
	check(Economy.DecodeSlot(nil) == nil, "empty slot")
	local byId = {}
	for _, def in Treasures.List do
		byId[def.Id] = def
	end
	local function lookup(x)
		return byId[x]
	end
	local displays = { ["1"] = "jade_frog", ["2"] = "jade_frog|Gold" }
	local base = Economy.VaultIncome(displays, lookup, 1, false)
	check(base == Economy.Income(byId.jade_frog) + Economy.Income(byId.jade_frog, "Gold"), "vault sums its pedestals")
	check(Economy.VaultIncome(displays, lookup, 1, true) == base * GameConfig.DayNight.NightIncomeMultiplier, "night multiplies income")
	check(Economy.VaultIncome(displays, lookup, 2, false) == base * 2, "ascension multiplies income")
end)

test("risky extractions can bless a treasure; streaks grow the fee", function()
	local function fixed(values)
		local i = 0
		return function()
			i += 1
			return values[i] or 0
		end
	end
	check(Economy.RollExtractionMutation("Safe", nil, fixed({ 0, 0 })) == nil, "safe zone never blesses")
	check(Economy.RollExtractionMutation("Dangerous", nil, fixed({ 0, 0 })) == "Silver", "dangerous can bless (most common first)")
	check(Economy.RollExtractionMutation("Secret", nil, fixed({ 0.3, 0.95 })) == "Diamond", "secret can give Diamond")
	check(Economy.RollExtractionMutation("Dangerous", nil, fixed({ 0.5, 0 })) == nil, "roll above the zone chance = nothing")
	check(Economy.RollExtractionMutation("Secret", "Gold", fixed({ 0, 0 })) == nil, "already mutated treasure is unchanged")
	local zones = GameConfig.Extraction.Categories
	check(zones.Secret.MutationChance > zones.Dangerous.MutationChance, "secret is the best gamble")
	check(zones.Dangerous.MutationChance > zones.Safe.MutationChance, "danger pays")
	check(Economy.StreakMultiplier(1) == 1, "first run of the day: x1")
	check(Economy.StreakMultiplier(3) > Economy.StreakMultiplier(2), "streak grows")
	check(Economy.StreakMultiplier(100) == Economy.StreakMultiplier(GameConfig.Extraction.StreakMax), "streak is capped")
	check(Economy.StreakMultiplier(100) <= 3, "cap stays sane")
end)

test("mutation rolls: rare, night-only Moonlit, event boost", function()
	check(Mutations.Roll(function()
		return 0
	end, false) == "Rainbow", "lowest roll = rarest mutation")
	check(Mutations.Roll(function()
		return 0.99
	end, false) == nil, "most spawns are not mutated")
	local total, night = 0, 0
	for _, name in Mutations.Order do
		total += Mutations.Info[name].Chance
		night += Mutations.Info[name].Chance + (Mutations.Info[name].NightChance or 0)
	end
	check(total < 0.15, "under 15% of daytime spawns are mutated")
	check(night > total, "night adds Moonlit")
	check(Mutations.Info.Moonlit.Chance == 0, "Moonlit never rolls by day")
	check(Mutations.Roll(function()
		return total * 2
	end, false, 6) ~= nil, "a Gold Rush boost makes a normal roll mutate")
end)

test("day/night clock", function()
	local cfg = GameConfig.DayNight
	local day = DayNight.State(0)
	check(not day.IsNight and near(day.ClockTime, cfg.DayStartClock), "cycle starts at dawn")
	local night = DayNight.State(cfg.CycleSeconds - cfg.NightSeconds + 1)
	check(night.IsNight, "night at the end of the cycle")
	check(night.SecondsLeft <= cfg.NightSeconds and night.SecondsLeft > 0, "night countdown")
	for t = 0, cfg.CycleSeconds, 7 do
		local st = DayNight.State(t + 1e6)
		check(st.ClockTime >= 0 and st.ClockTime < 24, "valid clock time")
	end
	check(cfg.NightSeconds < cfg.CycleSeconds / 2, "nights are short")
	check(cfg.CycleSeconds - cfg.NightSeconds == 300 and cfg.NightSeconds == 30, "5 minute day, 30 second night")
	check(cfg.WaveFillFraction > 0 and cfg.WaveFillFraction < 1, "loot wave lands before the night ends")
	for _, warnAt in cfg.WarnSecondsBeforeNight do
		check(warnAt < cfg.CycleSeconds - cfg.NightSeconds, "nightfall warning inside the day")
	end
	check(GameConfig.Events.TreasureRain.Duration + 15 < cfg.CycleSeconds - cfg.NightSeconds, "a Treasure Rain fits in a day")
end)

test("money pacing: first gadget quick, upgrades are real goals", function()
	local function average(rarity)
		local sum, n = 0, 0
		for _, def in Treasures.List do
			if def.Rarity == rarity then
				sum += Economy.Income(def)
				n += 1
			end
		end
		return sum / n
	end
	local common, uncommon, rare = average("Common"), average("Uncommon"), average("Rare")
	local cheapest = math.huge
	for _, def in Gadgets.List do
		cheapest = math.min(cheapest, def.Price)
	end
	-- two Commons on pedestals
	local minutes = cheapest / (2 * common) / 60
	check(minutes <= 4, ("first gadget in %.1f min with two Commons"):format(minutes))
	-- five early pedestals (Commons + Uncommons) -> first Vault upgrade
	local early = 5 * (common + uncommon) / 2
	local vault2 = GameConfig.Vault.Tiers[2].Price / early / 60
	check(vault2 >= 5 and vault2 <= 40, ("first vault upgrade takes %.1f min"):format(vault2))
	-- ten Rares -> third tier should still take a while
	local vault3 = GameConfig.Vault.Tiers[3].Price / (10 * rare) / 60
	check(vault3 >= 5 and vault3 <= 60, ("20-slot vault takes %.1f min with ten Rares"):format(vault3))
	check(GameConfig.Economy.FindersFeeSeconds < GameConfig.Economy.SellIncomeSeconds, "keeping a treasure beats instant cash")
end)

test("vault gallery layout fits the plot with an aisle", function()
	local v = GameConfig.Vault
	local pedestalHalf = 1.8
	local outerX = (v.Columns - 1) / 2 * v.ColumnSpacing + v.AisleWidth / 2 + pedestalHalf
	local innerX = v.ColumnSpacing / 2 + v.AisleWidth / 2 - pedestalHalf
	local rows = math.ceil(v.PerFloor / v.Columns)
	local outerZ = (rows - 1) / 2 * v.RowSpacing + pedestalHalf
	check(outerX < v.PlotWidth / 2 - 2, "pedestals clear the side railings")
	check(innerX >= 2, ("central aisle is walkable (%.1f studs each side)"):format(innerX))
	local front = v.GridOffsetZ - outerZ
	local back = v.GridOffsetZ + outerZ
	check(front > -v.PlotDepth / 2 + 4, "pedestals clear the front gate")
	-- Stairs: two 5+ wide bands behind the gallery, inside the back wall, climbing gently.
	local s = v.Stairs
	check(s.Width >= 5, "stairs are wide")
	check(s.Run <= v.PlotWidth - 4 and s.Run / 2 < v.PlotWidth / 2 - 1.5, "a flight fits across the plot")
	check(math.deg(math.atan2(v.FloorHeight, s.Run)) <= 32, "a flight climbs at a comfortable angle")
	local nearest, farthest = math.huge, -math.huge
	for _, band in s.BandsZ do
		nearest = math.min(nearest, band - s.Width / 2)
		farthest = math.max(farthest, band + s.Width / 2)
	end
	check(nearest > back + 1, ("stairs start behind the last pedestal row (%.1f > %.1f)"):format(nearest, back))
	check(farthest < v.PlotDepth / 2 - 0.5, "stairs clear the back wall")
	check(math.abs(s.BandsZ[1] - s.BandsZ[2]) >= s.Width, "the two stair bands don't overlap")
	check(v.HomeStandDistance > v.PlotDepth / 2 + 2, "the home spot stands outside the deep plot")
	local maxSlots = 0
	for _, tier in v.Tiers do
		maxSlots = math.max(maxSlots, tier.Slots)
	end
	check(math.ceil(maxSlots / v.PerFloor) <= 4, "biggest vault is at most 4 floors")
end)

test("music config is well-formed", function()
	check(Music.Volume > 0 and Music.Volume <= 1, "volume in range")
	check(Music.CrossfadeSeconds > 0, "crossfade")
	for _, track in Music.Playlist do
		check(type(track.Name) == "string" and type(track.Id) == "string", "playlist entry has Name + Id")
		check(track.Id == "" or track.Id:match("^rbxassetid://%d+$") ~= nil, "asset id format " .. tostring(track.Id))
	end
	check(type(Music.CarryTheme) == "table" and type(Music.CarryTheme.Id) == "string", "carry theme slot exists")
	for _, slot in { "CarryTheme", "SuccessSting", "FailSting", "FinalMinute", "Night", "Training" } do
		local track = (Music :: any)[slot]
		check(type(track) == "table" and track.Id:match("^rbxassetid://%d+$") ~= nil, slot .. " has a real asset id")
	end
	check(#Music.Playlist >= 5, "playlist has enough variety")
	-- Every session opens with Für Elise: the configured first track must be in the playlist.
	local found = false
	for _, track in Music.Playlist do
		found = found or track.Name == Music.FirstTrack
	end
	check(found, "the first track (" .. tostring(Music.FirstTrack) .. ") is in the playlist")
	check(Music.FinalMinuteSeconds >= 30 and Music.FinalMinuteSeconds < GameConfig.DayNight.CycleSeconds - GameConfig.DayNight.NightSeconds, "final-minute cue fits in the day")
	-- Mix: background at half volume, the carry theme 50% above full volume.
	check(Music.PlaylistVolume == 0.5, "playlist at 50%")
	check(Music.CarryTheme.Volume == 1.5, "carry theme at 150%")
	check(Music.CarryTheme.StartAt == 15, "carry theme skips its first 15 s")
	local seen = {}
	for _, track in Music.Playlist do
		check(not seen[track.Id], "no duplicate playlist track: " .. track.Name)
		seen[track.Id] = true
	end
end)

test("collection sets and special treasures have a purpose", function()
	for _, def in Treasures.List do
		if def.SpecialEffect then
			check(Treasures.EffectLabels[def.SpecialEffect] ~= nil, "effect explained on the tag: " .. def.Id)
		end
	end
	local byId = {}
	for _, def in Treasures.List do
		byId[def.Id] = def
	end
	local function lookup(id)
		return byId[id]
	end
	-- Nocturnal earns extra only at night.
	local displays = { ["1"] = "moon_pearl" }
	local day = Economy.VaultIncome(displays, lookup, 1, false)
	local night = Economy.VaultIncome(displays, lookup, 1, true)
	check(night == day * GameConfig.DayNight.NightIncomeMultiplier * GameConfig.Treasure.NocturnalMultiplier, "moon pearl doubles again at night")
	-- Sets.
	local collection = {}
	check(Economy.SetBonus(collection, Treasures.List) == 1, "no sets, no bonus")
	for _, def in Treasures.List do
		if def.SpawnArea == "Wilds" then
			collection[def.Id] = { Discovered = true, Count = 1 }
		end
	end
	local sets = Economy.SetProgress(collection, Treasures.List)
	check(sets.Wilds.Found == sets.Wilds.Total, "wilds set complete")
	check(sets.Coast.Found == 0 and sets.Coast.Total > 0, "coast untouched")
	check(Economy.CompletedSets(collection, Treasures.List) == 1, "one set done")
	check(near(Economy.SetBonus(collection, Treasures.List), 1 + GameConfig.Collection.SetBonusPerSet), "set bonus applies")
	check(near(Economy.IncomeMultiplier({ Collection = collection }, Treasures.List, 2), 2 * (1 + GameConfig.Collection.SetBonusPerSet)), "ascension x sets")
	for _, area in { "Wilds", "Ruins", "Coast", "Falls" } do
		check(sets[area] ~= nil and sets[area].Total >= 5, area .. " set has enough treasures to chase")
	end
end)

test("every treasure can actually spawn somewhere", function()
	-- WorldLayout uses Vector3; borrow Roblox datatypes from Lune for this test.
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	local cfg = GameConfig.Treasure
	for _, def in Treasures.List do
		local ok = false
		local rank = table.find(RARITY_ORDER, def.Rarity) or 0
		for _, point in WorldLayout.TreasureSpawns do
			local region = GameConfig.Regions[point.Area]
			local weights, anywhere = TreasureRoll.WeightsFor(cfg, region.Danger)
			local inArea = point.Area == def.SpawnArea or anywhere[def.Rarity]
			local minRank = table.find(RARITY_ORDER, point.MinRarity or "Common") or 0
			local maxRank = table.find(RARITY_ORDER, point.MaxRarity or "OG") or 0
			if inArea and rank >= minRank and rank <= maxRank and (weights[def.Rarity] or 0) > 0 then
				ok = true
				break
			end
		end
		check(ok, "spawnable: " .. def.Id)
	end
	local perArea = {}
	for _, point in WorldLayout.TreasureSpawns do
		perArea[point.Area] = (perArea[point.Area] or 0) + 1
	end
	for area in GameConfig.Regions do
		check((perArea[area] or 0) >= 7, area .. " has plenty of spawn points")
	end
end)

-- WORLD OVERHAUL: biomes, guardians, regions, secrets --------------------------------------
test("biome ground follows the gameplay regions", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	-- Reference copy of Zones.AreaId (Zones itself needs `script`).
	local function areaId(x: number, z: number): string
		local function within(c: Vector3, r: number): boolean
			return (x - c.X) ^ 2 + (z - c.Z) ^ 2 < r * r
		end
		if (x - WorldLayout.District.Center.X) ^ 2 + (z - WorldLayout.District.Center.Z) ^ 2 <= GameConfig.SafeZone.Radius ^ 2 then
			return "District"
		elseif within(WorldLayout.Temple.Center, 150) then
			return "Ruins"
		elseif within(WorldLayout.Shipwreck.Center, 160) then
			return "Coast"
		elseif within(WorldLayout.Frostpeak.Center, WorldLayout.Frostpeak.Radius) then
			return "Frost"
		elseif within(WorldLayout.Marsh.Center, WorldLayout.Marsh.Radius) then
			return "Marsh"
		elseif z < -240 then
			return "Falls"
		end
		return "Wilds"
	end
	local centers = TerrainGen.BIOME_CENTERS
	check(centers.Ruins[1] == WorldLayout.Temple.Center.X and centers.Ruins[2] == WorldLayout.Temple.Center.Z, "desert centred on the temple")
	check(centers.Coast[1] == WorldLayout.Shipwreck.Center.X and centers.Coast[2] == WorldLayout.Shipwreck.Center.Z, "coast centred on the wreck")
	check(centers.District[3] == GameConfig.SafeZone.Radius, "district biome = safe zone")
	local mismatches = 0
	for x = -500, 500, 10 do
		for z = -500, 500, 10 do
			local biome = TerrainGen.Biome(x, z)
			if biome ~= "Volcano" and biome ~= areaId(x, z) then
				mismatches += 1
			end
		end
	end
	check(mismatches == 0, ("terrain biome matches Zones everywhere (%d mismatches)"):format(mismatches))
	for name, mats in TerrainGen.BIOME_MATERIALS do
		check(#mats >= 3, "materials for " .. name)
	end
	check(TerrainGen.BIOME_MATERIALS.Ruins[1] ~= TerrainGen.BIOME_MATERIALS.Wilds[1], "desert looks different from the meadow")
	check(TerrainGen.BIOME_MATERIALS.Falls[1] ~= TerrainGen.BIOME_MATERIALS.Wilds[1], "jungle looks different from the meadow")
end)

test("guardians are big, scary and still fair", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local Guardians = require("../src/shared/Config/Guardians")
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	for id, def in Guardians do
		check(def.Scale >= 1.5, id .. " is bigger than a player")
		check(def.ChaseSpeed < GameConfig.Player.BaseWalkSpeed, id .. " can be outrun without a load")
		local reach = def.AttackRange + def.Size[3] * def.Scale / 2
		check(reach >= 5 and reach <= 10, ("%s reach %.1f is sane"):format(id, reach))
		check(def.Damage < GameConfig.Player.MaxHealth / 3, id .. " never three-shots a player")
		check(def.LeashRange > def.DetectRange, id .. " leash beyond detection")
	end
	check(Guardians.Golem ~= nil and Guardians.Golem.Scale > Guardians.Wolf.Scale, "the Golem towers over the rest")
	for _, spawnInfo in WorldLayout.GuardianSpawns do
		check(Guardians[spawnInfo.Type] ~= nil, "guardian type exists: " .. spawnInfo.Type)
	end
	local perArea = {}
	for _, spawnInfo in WorldLayout.GuardianSpawns do
		local biome = TerrainGen.Biome(spawnInfo.Position.X, spawnInfo.Position.Z)
		perArea[biome] = (perArea[biome] or 0) + 1
	end
	for _, area in { "Wilds", "Coast", "Ruins", "Falls", "Frost", "Marsh" } do
		check((perArea[area] or 0) >= 2, ("%s is guarded (%d)"):format(area, perArea[area] or 0))
	end
	check((perArea.District or 0) == 0, "no guardian in the safe zone")
end)

test("regions escalate and secrets pay off", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local Regions = require("../src/shared/Config/Regions")
	local previous = nil
	for _, area in Regions.Order do
		local balance = GameConfig.Regions[area]
		check(balance ~= nil and Regions.Info[area] ~= nil, "configured: " .. area)
		if previous then
			check(balance.Danger >= previous.Danger, area .. " is never safer than the region before")
			check(balance.RecommendedStrength > previous.RecommendedStrength, area .. " asks for more strength")
			check(balance.DiscoveryReward > previous.DiscoveryReward, area .. " pays more for discovery")
		end
		previous = balance
	end
	check(Regions.Stars(3) == "★★★☆☆☆☆", "danger stars")
	for _, secret in Regions.Secrets do
		check(GameConfig.Secrets[secret.Id] and GameConfig.Secrets[secret.Id].Reward > 0, "reward for " .. secret.Id)
		check(TerrainGen.Biome(secret.Position.X, secret.Position.Z) == secret.Area, secret.Id .. " lies in " .. secret.Area)
		check(TerrainGen.FlatMask(secret.Position.X, secret.Position.Z) == 0, secret.Id .. " sits in a flat zone")
	end
	-- Mirrors the spawn points in World/Secrets.luau: each must be able to roll something.
	for _, point in {
		{ Area = "Wilds", MinRarity = "Rare" },
		{ Area = "Ruins", MinRarity = "Epic" },
		{ Area = "Ruins", MinRarity = "Legendary" },
		{ Area = "Frost", MinRarity = "Epic" },
		{ Area = "Marsh", MinRarity = "Epic" },
		{ Area = "Coast", MinRarity = "Rare" },
		{ Area = "Falls", MinRarity = "Epic" },
	} do
		local weights, anywhere = TreasureRoll.WeightsFor(GameConfig.Treasure, GameConfig.Regions[point.Area].Danger)
		local candidates = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, weights, {}, {}, anywhere)
		local local_ = 0
		for _, c in candidates do
			if c.Def.SpawnArea == point.Area then
				local_ += 1
			end
		end
		check(local_ > 0, ("secret spawn %s %s+ can roll local loot"):format(point.Area, point.MinRarity))
	end
end)

-- DATA ----------------------------------------------------------------------------
test("first join gets defaults", function()
	local data = DataSchema.Migrate(nil)
	check(data.Version == DataSchema.Version, "version set")
	check(data.Cash == 0 and data.Strength == GameConfig.Strength.Start and data.Ascension == 0, "starting stats")
	check(data.Vault.Tier == 1, "vault tier 1")
	check(data.Vault.Stored == 0, "no uncollected earnings")
	check(#data.EquippedGadgets == 3, "three gadget slots")
end)

test("partial / old saves are reconciled, never wiped", function()
	local old = {
		Cash = 5000,
		Strength = 42,
		Collection = { golden_crown = { Discovered = true, Count = 2 } },
		Vault = { Displays = { ["1"] = "golden_crown" } },
		Stats = { Extractions = 7 },
	}
	local data = DataSchema.Migrate(old)
	check(data.Cash == 5000, "cash kept")
	check(data.Strength == 4200, "strength kept (rescaled x100)")
	check(data.Collection.golden_crown.Count == 2, "collection kept")
	check(data.Vault.Displays["1"] == "golden_crown", "vault displays kept")
	check(data.Vault.Tier == 1, "missing vault tier filled")
	check(data.Stats.Extractions == 7, "existing stat kept")
	check(data.Stats.Thefts == 0, "missing stat filled")
	check(type(data.Milestones) == "table", "missing table filled")
end)

test("corrupt values are sanitised", function()
	local data = DataSchema.Migrate({ Cash = -50, Strength = "abc", Ascension = 2.7, EquippedGadgets = { 5, nil, "balloon" } })
	check(data.Cash == 0, "negative cash clamped")
	check(data.Strength == 1000, "invalid strength reset to the starting value")
	check(data.Ascension == 2, "ascension floored")
	check(data.EquippedGadgets[1] == "" and data.EquippedGadgets[3] == "balloon", "slots sanitised")
end)

-- CONTENT INVARIANTS -----------------------------------------------------------------
test("every treasure has its own hand-built model", function()
	local source = require("@lune/fs").readFile("src/shared/TreasureModels.luau")
	for _, def in Treasures.List do
		check(source:find("Models." .. def.Id .. " = function", 1, true) ~= nil, "custom model for " .. def.Id)
	end
end)

test("ascension keeps tutorial progress (milestones, tutorial step, stats)", function()
	local AscensionReset = require("../src/shared/Logic/AscensionReset")
	local data = DataSchema.Default()
	data.Milestones = { FirstTraining = 1, FirstTreasure = 2, FirstExtraction = 3, FirstCollect = 4, FirstGadgetBought = 5 }
	data.TutorialStep = 7
	data.Stats.Extractions = 12
	data.OwnedGadgets = { speed_soda = true }
	AscensionReset.Apply(data, 1, "Ascended", GameConfig, function()
		return 1
	end)
	check(next(data.OwnedGadgets) == nil, "gadgets are wiped by Ascension")
	for name in { FirstTraining = true, FirstTreasure = true, FirstExtraction = true, FirstCollect = true, FirstGadgetBought = true } do
		check(data.Milestones[name] ~= nil, name .. " survives Ascension")
	end
	check(data.TutorialStep == 7 and data.Stats.Extractions == 12, "tutorial step and stats survive")
end)

test("bats: a free starter, 3 cash upgrades, 7 more behind Ascension, each slapping further", function()
	local roblox = require("@lune/roblox") :: any
	CFrame = roblox.CFrame
	Color3 = roblox.Color3
	local Bats = require("../src/shared/Config/Bats")
	check(#Bats.List == 11, "11 bats")
	check(Bats.List[1].Id == Bats.StarterId and Bats.List[1].Price == 0 and Bats.List[1].RequiredAscension == 0, "you start with the Wooden Bat for free")
	for i = 2, 4 do
		check(Bats.List[i].Price > 0 and Bats.List[i].RequiredAscension == 0, Bats.List[i].Id .. " is a Cash-only upgrade")
	end
	for i = 5, 11 do
		local bat, prev = Bats.List[i], Bats.List[i - 1]
		check(bat.RequiredAscension > 0 and bat.RequiredAscension > prev.RequiredAscension, bat.Id .. " needs a higher Ascension than the last")
	end
	for i = 2, #Bats.List do
		local bat, prev = Bats.List[i], Bats.List[i - 1]
		check(bat.Tier == i, bat.Id .. " tier in order")
		check(bat.Price > prev.Price, bat.Id .. " costs more than the last")
		check(bat.Knockback > prev.Knockback, bat.Id .. " slaps further than the last")
		check(bat.Range >= prev.Range and bat.Range <= 12.5, bat.Id .. " reach grows a little")
	end
	-- Each Ascension-gated bat is affordable within that Ascension's run (Cash resets on Ascending).
	for _, bat in Bats.List do
		if bat.RequiredAscension > 0 then
			check(bat.Price < GameConfig.GetAscensionCost(bat.RequiredAscension + 1), bat.Id .. " costs less than the next Ascension")
		end
	end
	local source = require("@lune/fs").readFile("src/shared/BatModels.luau")
	for _, bat in Bats.List do
		check(source:find("Builders." .. bat.Id .. " = function", 1, true) ~= nil, "hand-built model for " .. bat.Id)
	end
	-- Buying rules.
	local data = DataSchema.Default()
	check(data.EquippedBat == Bats.StarterId and next(data.OwnedBats) == nil, "new players hold the Wooden Bat")
	check(Bats.BuyProblem(data, Bats.List[1]) == "Owned", "the starter is always owned")
	check(Bats.BuyProblem(data, Bats.List[2]) == "Cash", "broke players can't buy")
	data.Cash = 1e13
	check(Bats.BuyProblem(data, Bats.List[4]) == nil, "Cash buys the first upgrades")
	check(Bats.BuyProblem(data, Bats.List[5]) == "Ascension", "tier 5 needs Ascension 1")
	data.Ascension = 1
	check(Bats.BuyProblem(data, Bats.List[5]) == nil, "Ascension 1 unlocks tier 5")
	data.EquippedBat = "big_bang"
	check(Bats.Equipped(data).Id == Bats.StarterId, "an unowned equipped bat falls back to the starter")
	data.OwnedBats.big_bang = true
	check(Bats.Equipped(data).Id == "big_bang", "an owned bat is held")
	-- Carrier rule: 1st slap slows, 2nd throws further than a normal slap.
	check(GameConfig.Stability.ShakenSpeed < 1 and GameConfig.Combat.KnockThrow > 1 and GameConfig.Combat.ShakenShove < 1, "slap 1 slows, slap 2 throws")
end)

test("rarity palette + every tier can spawn", function()
	local source = require("@lune/fs").readFile("src/shared/Config/Rarities.luau")
	local palette = {
		Common = "#9E9E9E",
		Uncommon = "#4CAF50",
		Rare = "#2196F3",
		Epic = "#9C27B0",
		Legendary = "#FFC107",
		Mythic = "#F44336",
		Divine = "#00E5FF",
		Secret = "#111111",
		OG = "#FFD700",
	}
	for rarity, code in palette do
		check(source:find(code, 1, true) ~= nil, "palette colour " .. rarity)
	end
	check(source:find('"Divine", "Secret", "OG" }', 1, true) ~= nil, "rarity order ends Divine > Secret > OG")
	local weights = TreasureRoll.WeightsFor(GameConfig.Treasure, 2)
	for i, rarity in RARITY_ORDER do
		check((weights[rarity] or 0) > 0, "spawn weight " .. rarity)
		if i > 2 then
			check(weights[rarity] < weights[RARITY_ORDER[i - 1]], "rarer tier spawns less often " .. rarity)
		end
		local found = false
		for _, def in Treasures.List do
			found = found or def.Rarity == rarity
		end
		check(found, "at least one treasure of " .. rarity)
	end
end)

test("30 treasures with unique ids and spec economy ranges", function()
	check(#Treasures.List >= 34, "30 MVP treasures + the purposeful phase-4 additions")
	local ranges = {
		Common = { 100, 500, 1, 5 },
		Uncommon = { 500, 2000, 3, 10 },
		Rare = { 2000, 10000, 6, 20 },
		Epic = { 10000, 50000, 10, 30 },
		Legendary = { 50000, 250000, 20, 50 },
		Mythic = { 250000, 1000000, 35, 80 },
	}
	for _, r in ranges do
		r[3] *= 100 -- weights live on the x100 Strength scale
		r[4] *= 100
	end
	local seen = {}
	for _, def in Treasures.List do
		check(not seen[def.Id], "unique id " .. def.Id)
		seen[def.Id] = true
		check(Treasures.DisplayScale[def.DisplaySize] ~= nil, "display size " .. def.Id)
		local r = ranges[def.Rarity]
		if r then
			check(def.Value >= r[1] and def.Value <= r[2], "value in range " .. def.Id)
			check(def.Weight >= r[3] and def.Weight <= r[4], "weight in range " .. def.Id)
		elseif def.Rarity == "Divine" then
			check(def.Value >= 1000000 and def.Value <= 2000000, "divine is $1-2M " .. def.Id)
		elseif def.Rarity == "Secret" then
			check(def.Value >= 1000000, "secret is $1M+")
		elseif def.Rarity == "OG" then
			check(def.Value >= 5000000, "OG is $5M+")
		else
			check(false, "unknown rarity " .. def.Rarity)
		end
	end
end)

test("first gadget is cheap, the rest stay expensive", function()
	local cheapest, second = math.huge, math.huge
	for _, def in Gadgets.List do
		if def.Price < cheapest then
			cheapest, second = def.Price, cheapest
		elseif def.Price < second then
			second = def.Price
		end
	end
	check(cheapest <= 1000, "first gadget within reach of a couple of early extractions")
	check(second >= 10000, "later gadgets stay a real goal")
end)

test("save v4 rescales strength x100 exactly once", function()
	local data = DataSchema.Migrate({ Version = 3, Strength = 57.5 })
	check(data.Strength == 5750, "old strength x100")
	check(DataSchema.Migrate(data).Strength == 5750, "already-migrated save untouched")
end)

test("save v3 keeps unlocked treadmills as benches", function()
	local data = DataSchema.Migrate({ Version = 2, Strength = 30, OwnedTreadmills = { iron = true } })
	check(data.OwnedBenches.iron == true, "iron bench unlocked")
	check(data.OwnedTreadmills == nil, "old field removed")
end)

test("gadget config", function()
	local implemented = 0
	for _, def in Gadgets.List do
		if def.Implemented then
			implemented += 1
			check(def.Price >= 0 and def.Cooldown > 0, "valid price/cooldown " .. def.Id)
		end
	end
	check(#Gadgets.List == 8, "8 gadgets designed")
	check(implemented >= 2, "at least 2 gadgets implemented")
	check(Gadgets.Get("speed_soda").CanUseWhileCarrying, "soda usable while carrying")
	check(not Gadgets.Get("bubble_blaster").CanUseWhileCarrying, "bubble blaster is chaser-only")
end)

test("grapple hook config", function()
	local grapple = Gadgets.Get("grapple_hook")
	check(grapple.Implemented, "grapple implemented")
	check(grapple.CanUseWhileCarrying, "grapple is an escape tool")
	check(grapple.NeedsAim, "grapple needs aim direction")
	check(grapple.Range > grapple.MinDistance, "range > min distance")
	check(grapple.CarriedSpeedFloor > 0 and grapple.CarriedSpeedFloor <= 1, "carried speed floor sane")
end)

test("leaderboard config + unique treasure values", function()
	check(#GameConfig.Leaderboards.Boards == 5, "five boards (spec)")
	local values = {}
	for _, def in Treasures.List do
		check(not values[def.Value], "unique value (Rarest board maps value -> treasure) " .. def.Id)
		values[def.Value] = true
	end
end)

test("deep south: a channel, then Emberfall lowlands, then a high glacier", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	local south = WorldLayout.DeepSouth
	check(TerrainGen.SOUTH.Start == south.EmberStart and TerrainGen.SOUTH.RimeStart == south.RimeStart, "terrain and zones agree on the borders")
	local channel = TerrainGen.Height(0, -470)
	check(channel < 0, ("the Sundering is open sea (h=%.1f)"):format(channel))
	local ember = TerrainGen.Height(0, -640)
	check(ember > 8 and ember < 40, ("Emberfall is lowland (h=%.1f)"):format(ember))
	local glacier = TerrainGen.Height(0, -900)
	check(glacier > 34 and glacier < 72, ("Rimeheart is a high plateau (h=%.1f)"):format(glacier))
	check(TerrainGen.Height(0, -1150) < 0, "open sea under the Starfall Isles")
	check(TerrainGen.Height(300, -700) < 0, "the peninsula stays narrow")
	check(TerrainGen.Biome(0, -640) == "Ember" and TerrainGen.Biome(0, -900) == "Rime", "south biomes")
	for area, need in { Ember = 1, Rime = 2, Star = 3 } do
		check(GameConfig.Regions[area].RequiredAscension == need, area .. " needs Ascension " .. need)
	end
end)

test("exits are big, and no treasure spawns inside one", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	for _, zone in WorldLayout.ExtractionZones do
		check(zone.Radius >= 13, zone.Id .. " is an easy-to-hit circle")
		for _, spawn in WorldLayout.TreasureSpawns do
			local d = Vector3.new(spawn.Position.X - zone.Position.X, 0, spawn.Position.Z - zone.Position.Z).Magnitude
			check(d > zone.Radius + 2, ("spawn at (%d, %d) is outside %s"):format(spawn.Position.X, spawn.Position.Z, zone.Id))
		end
	end
end)

test("waystones: a dais in the District, one stone per south region", function()
	local roblox = require("@lune/roblox") :: any
	Vector3 = roblox.Vector3
	local WorldLayout = require("../src/shared/Config/WorldLayout")
	local info = WorldLayout.Waystones
	local district = WorldLayout.District
	local fromCentre = (Vector3.new(info.Circle.X, 0, info.Circle.Z) - Vector3.new(district.Center.X, 0, district.Center.Z)).Magnitude
	check(fromCentre + info.Radius + 4 < district.WallRadius, "the dais fits inside the District wall")
	check(fromCentre + info.Radius + 4 < GameConfig.SafeZone.Radius, "arriving home lands in the safe zone")
	local seen = {}
	for _, region in info.Regions do
		seen[region.Area] = true
		check(GameConfig.Regions[region.Area] and (GameConfig.Regions[region.Area].RequiredAscension or 0) > 0, region.Area .. " stone leads to a sealed region")
		check(TerrainGen.Biome(region.Stone.X, region.Stone.Z) == region.Area, region.Area .. " stone stands in its own region")
	end
	for _, area in { "Ember", "Rime", "Star" } do
		check(seen[area] == true, "a waystone for " .. area)
	end
end)

test("deep south storms: one per region, loot always possible", function()
	local events = GameConfig.Events
	for id, weight in events.DaytimeWeights do
		check(weight > 0 and (id == "TreasureRain" or events.Storms[id] ~= nil), "daytime event " .. id .. " exists")
	end
	for id, storm in events.Storms do
		check(events.DaytimeWeights[id] ~= nil, id .. " is scheduled")
		check(GameConfig.Regions[storm.Area] ~= nil, id .. " hits a real region")
		check(storm.Duration + 15 < GameConfig.DayNight.CycleSeconds - GameConfig.DayNight.NightSeconds, id .. " fits in a day")
		check(storm.Warning >= 1.5, id .. " gives time to dodge")
		check(storm.LootChance > 0 and storm.LootChance < 1, id .. " loot is a gamble")
		for rarity, w in storm.Loot do
			local found = false
			for _, def in Treasures.List do
				if def.SpawnArea == storm.Area and def.Rarity == rarity then
					found = true
				end
			end
			check(w > 0 and found, ("%s can drop a %s from %s"):format(id, rarity, storm.Area))
		end
	end
end)

test("the Waterfall Mountain: a terrace between peaks, inside its own voxel box", function()
	local M = TerrainGen.MOUNTAIN
	local box = M.Box
	check((box.X0 % 64) == 0 and (box.Z0 % 64) == 0 and box.CellsX % 16 == 0 and box.CellsZ % 16 == 0, "the box is whole terrain chunks")
	local highest, outside = -math.huge, 0
	for x = -340, 360, 8 do
		for z = -600, -260, 8 do
			local h = TerrainGen.Height(x, z)
			local inBox = x >= box.X0 and x < box.X0 + box.CellsX * 4 and z >= box.Z0 and z < box.Z0 + box.CellsZ * 4
			if inBox then
				highest = math.max(highest, h)
			elseif h > 70 then
				outside += 1
			end
		end
	end
	check(highest < box.YMax - 4, ("the peaks fit the mountain box (max %.1f)"):format(highest))
	check(highest > M.Top + 30, ("real peaks rise over the terrace (max %.1f)"):format(highest))
	check(outside == 0, "nothing tall is left outside the box")
	for _, p in { { -40, -345, "lookout" }, { -70, -350, "hermit's hut" }, { -42, -334, "geyser landing" }, { 50, -380, "Ashen Pass start" }, { 95, -307, "ramp landing" }, { -40, -345, "cliff-top treasure" } } do
		check(math.abs(TerrainGen.Height(p[1], p[2]) - M.Top) < 1.5, p[3] .. " is on the terrace")
	end
	-- The falls drop sheer: the terrace edge, then the pool right below.
	check(TerrainGen.Height(0, -309) > M.Top - 2 and TerrainGen.Height(0, -300) < 12, "a sheer drop where the water falls")
	-- The foot of the cliff stays playable.
	for _, p in { { -45, -266, "Cliff Geyser" }, { -72, -262, "jungle treasure" }, { 170, -266, "ramp-side treasure" }, { 0, -285, "plunge pool" } } do
		check(math.abs(TerrainGen.Height(p[1], p[2]) - 10) < 0.5, p[3] .. " on flat ground")
	end
end)

test("terrain: gameplay spots are flat, island has hills and a coast", function()
	-- Under the District slab the terrain is sunk to an exact voxel boundary (no poke-through).
	for _, p in { { 0, 250, "district centre" }, { 0, 290, "spawn" }, { -62, 235, "gym" }, { 100, 330, "vaults" } } do
		local h = TerrainGen.Height(p[1], p[2])
		check(h == TerrainGen.SUNKEN.Height and h % 4 == 0, ("%s terrain sunk under the slab (got %.2f)"):format(p[3], h))
		check(h < 11 - 2, p[3] .. " terrain well below the slab top")
	end
	check(near(TerrainGen.Height(0, 95), 10, 0.01), "outside the gate back at ground level")
	local flat = {
		{ 0, 55, "camp extraction" },
		{ 230, -45, "temple courtyard" },
		{ 230, -140, "temple" },
		{ 0, -285, "waterfall pool" },
		{ 225, -296, "cliff ramp foot" },
		{ -345, -10, "shipwreck" },
		{ 120, 10, "ravine bridge" },
	}
	for _, p in flat do
		local h = TerrainGen.Height(p[1], p[2])
		check(near(h, 10, 0.01), ("%s flat at 10 (got %.2f)"):format(p[3], h))
	end
	local highest, lowestInland = -math.huge, math.huge
	local box = TerrainGen.MOUNTAIN.Box
	local function inMountainBox(x: number, z: number): boolean
		return x >= box.X0 and x < box.X0 + box.CellsX * 4 and z >= box.Z0 and z < box.Z0 + box.CellsZ * 4
	end
	for x = -400, 400, 16 do
		for z = -400, 400, 16 do
			local h = TerrainGen.Height(x, z)
			if not inMountainBox(x, z) then
				highest = math.max(highest, h) -- (the mountain has its own, taller voxel box)
			end
			if x * x + z * z < 300 * 300 then
				lowestInland = math.min(lowestInland, h)
			end
		end
	end
	check(highest > 22, ("island has real hills (max %.1f)"):format(highest))
	check(highest < 72, "hills fit inside the generated voxel range")
	check(lowestInland > 2, ("inland never dips below sea level (min %.1f)"):format(lowestInland))
	check(TerrainGen.SurfaceZone(0, 290) == "Pavement", "spawn sits on grass-free pavement")
	check(TerrainGen.SurfaceZone(0, -60) == nil, "the Wilds keep their grass")
	for angle = 0, 350, 10 do
		local a = math.rad(angle)
		local x, z = math.cos(a) * 600, math.sin(a) * 600
		-- (Straight south the Deep South peninsula reaches past r=600 on purpose.)
		if not (z < -430 and math.abs(x) < 260) then
			local h, coast = TerrainGen.Height(x, z)
			check(h < 0 and coast > 0.9, ("open sea at r=600, angle %d (h=%.1f)"):format(angle, h))
		end
	end
end)

test("ascension multipliers", function()
	check(GameConfig.GetAscensionMultiplier(0) == 1, "x1.00")
	check(GameConfig.GetAscensionMultiplier(4) == 3, "x3.00")
	check(GameConfig.GetAscensionMultiplier(6) == 4, "extrapolates")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end
