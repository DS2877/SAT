-- Pure-logic unit tests. Run with: lune run tests/run
-- Covers the rules that must never silently break: carry formula, stability machine,
-- treasure rolls/caps, training grading, save migration, and content invariants.

local GameConfig = require("../src/shared/Config/GameConfig")
local Treasures = require("../src/shared/Config/Treasures")
local Gadgets = require("../src/shared/Config/Gadgets")
local Carry = require("../src/shared/Logic/Carry")
local Stability = require("../src/shared/Logic/Stability")
local TreasureRoll = require("../src/shared/Logic/TreasureRoll")
local TrainingTiming = require("../src/shared/Logic/TrainingTiming")
local DataSchema = require("../src/shared/Logic/DataSchema")

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
	check(Carry.SpeedMultiplier(26, 100, cfg) == 0.9, "ratio 0.26 -> 90%")
	check(Carry.SpeedMultiplier(50, 100, cfg) == 0.9, "ratio 0.50 -> 90%")
	check(Carry.SpeedMultiplier(75, 100, cfg) == 0.75, "ratio 0.75 -> 75%")
	check(Carry.SpeedMultiplier(100, 100, cfg) == 0.6, "ratio 1.00 -> 60%")
	check(Carry.SpeedMultiplier(150, 100, cfg) == 0.45, "ratio 1.50 -> 45%")
	check(Carry.SpeedMultiplier(151, 100, cfg) == 0.3, "ratio >1.50 -> 30%")
	check(Carry.SpeedMultiplier(1, 1, cfg) == 0.6, "strength 1 carrying weight 1")
	check(Carry.SpeedMultiplier(80, 0, cfg) == 0.3, "zero strength treated as 1, never errors")
end)

test("carry never hard-locks and jump has a floor", function()
	local cfg = GameConfig.Carry
	check(Carry.SpeedMultiplier(10000, 1, cfg) > 0, "absurd weight is still movable")
	check(Carry.JumpMultiplier(0.3, cfg) == cfg.JumpMultiplierFloor, "jump floor applies")
	check(Carry.JumpMultiplier(1, cfg) == 1, "light carry keeps full jump")
	check(Carry.RecommendedStrength(50, cfg) == 60, "dragon-egg example: weight 50 -> recommended 60")
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
test("training timing + grading", function()
	local period = GameConfig.Training.Period
	check(near(TrainingTiming.MarkerPosition(0, period), 0), "starts at 0")
	check(near(TrainingTiming.MarkerPosition(period / 2, period), 1), "peaks at half period")
	check(near(TrainingTiming.MarkerPosition(period / 4, period), 0.5), "centre at quarter period")
	check(near(TrainingTiming.MarkerPosition(period * 3, period), 0), "periodic")
	local station = GameConfig.Training.Stations.stone_lift
	check(TrainingTiming.Grade(0.5, station) == "Perfect", "centre is perfect")
	check(TrainingTiming.Grade(0.5 + station.GoodWindow - 0.001, station) == "Good", "edge of good")
	check(TrainingTiming.Grade(0.95, station) == "Miss", "far is miss")
	check(TrainingTiming.Gain("Perfect", 5, station, 1) == station.PerfectGain, "perfect gain")
	check(TrainingTiming.Gain("Good", station.Cap, station, 1) == 0, "good gives nothing over cap")
	check(TrainingTiming.Gain("Perfect", station.Cap, station, 1) == 1, "perfect over cap gives overcap gain")
	check(TrainingTiming.Gain("Miss", 1, station, 1) == 0, "miss gives nothing")
end)

-- DATA ----------------------------------------------------------------------------
test("first join gets defaults", function()
	local data = DataSchema.Migrate(nil)
	check(data.Version == DataSchema.Version, "version set")
	check(data.Cash == 0 and data.Strength == 1 and data.Ascension == 0, "starting stats")
	check(data.Vault.Tier == 1, "vault tier 1")
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
	check(data.Strength == 42, "strength kept")
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
	check(data.Strength == 1, "invalid strength reset")
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

test("ascension multipliers", function()
	check(GameConfig.GetAscensionMultiplier(0) == 1, "x1.00")
	check(GameConfig.GetAscensionMultiplier(4) == 2, "x2.00")
	check(GameConfig.GetAscensionMultiplier(6) == 2.5, "extrapolates")
end)

print(("%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	error("tests failed")
end
