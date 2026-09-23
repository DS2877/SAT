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
local Mutations = require("../src/shared/Config/Mutations")
Economy.Use(GameConfig, Mutations)
DayNight.Use(GameConfig)
local TerrainGen = require("../src/server/World/TerrainGen")

local RARITY_ORDER = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic", "Secret" }

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
	local point = { Area = "Ruins", MinRarity = "Epic", MaxRarity = "Mythic" }
	local candidates = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, cfg.RarityWeights, cfg.RarityCaps, {})
	check(#candidates > 0, "ruins epic+ has candidates")
	for _, c in candidates do
		check(c.Def.SpawnArea == "Ruins", "area filter " .. c.Def.Id)
		check(c.Def.Rarity == "Epic" or c.Def.Rarity == "Legendary" or c.Def.Rarity == "Mythic", "rarity filter " .. c.Def.Id)
	end
	local capped = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, cfg.RarityWeights, cfg.RarityCaps, { Legendary = 1, Mythic = 1 })
	for _, c in capped do
		check(c.Def.Rarity == "Epic", "caps exclude capped rarities: " .. c.Def.Id)
	end
	local none = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, cfg.RarityWeights, cfg.RarityCaps, { Epic = 5, Legendary = 1, Mythic = 1 })
	check(#none == 0 and TreasureRoll.Pick(none, math.random) == nil, "fully capped point spawns nothing")
end)

test("rare treasure stays rare over many rolls", function()
	local cfg = GameConfig.Treasure
	local point = { Area = "Wilds", MinRarity = "Common", MaxRarity = "Rare" }
	local candidates = TreasureRoll.Candidates(Treasures.List, point, RARITY_ORDER, cfg.RarityWeights, cfg.RarityCaps, {})
	local seed = 12345
	local function rand()
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local counts = {}
	for _ = 1, 20000 do
		local def = TreasureRoll.Pick(candidates, rand)
		counts[def.Rarity] = (counts[def.Rarity] or 0) + 1
	end
	check((counts.Common or 0) > (counts.Uncommon or 0), "commons most frequent")
	check((counts.Uncommon or 0) > (counts.Rare or 0), "uncommon more frequent than rare")
	check((counts.Rare or 0) > 0, "rares do appear")
end)

test("every spawn area referenced by treasures can spawn something", function()
	local areas = {}
	for _, def in Treasures.List do
		areas[def.SpawnArea] = true
	end
	for area in areas do
		check(area == "Wilds" or area == "Ruins" or area == "Coast" or area == "Falls", "known area " .. area)
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
	-- AFK minutes to climb from a fresh reset to the next Ascension, on the best bench allowed.
	local previousRequirement = 0
	for level = 0, 6 do
		local best = 0
		for _, tier in tiers do
			if tier.RequiredAscension <= level then
				best = math.max(best, GameConfig.GetRepGain(tier, level) / GameConfig.Training.RepPeriod)
			end
		end
		local requirement = GameConfig.GetAscensionRequirement(level)
		local minutes = (requirement - GameConfig.Strength.Start) / best / 60
		check(requirement > previousRequirement, ("requirement grows at ascension %d"):format(level))
		check(minutes >= 8 and minutes <= 50, ("ascension %d climb takes %.1f min (8-50)"):format(level, minutes))
		previousRequirement = requirement
	end
	check(GameConfig.GetTrainingMultiplier(3) > GameConfig.GetTrainingMultiplier(2), "training speeds up every ascension")
	check(GameConfig.GetRepGain(tiers[1], 0) >= 5, "even the first rep pays out a satisfying number")
	check(GameConfig.Training.CritChance > 0 and GameConfig.Training.CritMultiplier > 1, "MEGA REP jackpot exists")
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
		Secret = { 10000, 100000 },
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
test("30 treasures with unique ids and spec economy ranges", function()
	check(#Treasures.List == 30, "exactly 30 treasures (MVP target)")
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
		elseif def.Rarity == "Secret" then
			check(def.Value >= 1000000, "secret is $1M+")
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

test("terrain: gameplay spots are flat, island has hills and a coast", function()
	local flat = {
		{ 0, 250, "district centre" },
		{ 0, 290, "spawn" },
		{ -62, 235, "stone lift" },
		{ 0, 55, "camp extraction" },
		{ 230, -45, "temple courtyard" },
		{ 230, -140, "temple" },
		{ 0, -285, "waterfall pool" },
		{ 40, -296, "cliff ramp foot" },
		{ -345, -10, "shipwreck" },
		{ 120, 10, "ravine bridge" },
	}
	for _, p in flat do
		local h = TerrainGen.Height(p[1], p[2])
		check(near(h, 10, 0.01), ("%s flat at 10 (got %.2f)"):format(p[3], h))
	end
	local highest, lowestInland = -math.huge, math.huge
	for x = -400, 400, 16 do
		for z = -400, 400, 16 do
			local h = TerrainGen.Height(x, z)
			highest = math.max(highest, h)
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
		local h, coast = TerrainGen.Height(math.cos(a) * 600, math.sin(a) * 600)
		check(h < 0 and coast > 0.9, ("open sea at r=600, angle %d (h=%.1f)"):format(angle, h))
	end
end)

test("ascension multipliers", function()
	check(GameConfig.GetAscensionMultiplier(0) == 1, "x1.00")
	check(GameConfig.GetAscensionMultiplier(4) == 2, "x2.00")
	check(GameConfig.GetAscensionMultiplier(6) == 2.5, "extrapolates")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end
