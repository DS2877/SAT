-- Bench-press maths (pure, unit-tested). Training is a WAITING game that pays you for staying:
--   * PUMP: every rep in a row raises the multiplier (+PumpPerRep) up to PumpMax. Getting up
--     resets it, so a long session is always worth more than many short ones.
--   * SETS: every SetSize reps completes a set, paying SetBonus x what that set earned.
--   * JACKPOTS: any rep can roll a MEGA REP (x CritMultiplier) or, rarely, a GOLDEN REP.
-- The server rolls and pays; the client only presents (TrainingUI / BenchAnimator).

local Lifting = {}

-- In Roblox the config is required via `script`; Lune tests inject it with Lifting.Use.
local GameConfig
if script then
	GameConfig = require(script.Parent.Parent.Config.GameConfig)
end

function Lifting.Use(gameConfig)
	GameConfig = gameConfig
end

-- Pump multiplier for the Nth rep of a session (rep 1 = x1).
function Lifting.Pump(rep: number): number
	local cfg = GameConfig.Training
	return math.min(cfg.PumpMax, 1 + math.max(0, rep - 1) * cfg.PumpPerRep)
end

-- Reps needed to reach full pump.
function Lifting.RepsToMaxPump(): number
	local cfg = GameConfig.Training
	return math.ceil((cfg.PumpMax - 1) / cfg.PumpPerRep) + 1
end

-- "Golden" | "Mega" | "Normal". `random()` in [0, 1).
function Lifting.Roll(random: () -> number): string
	local cfg = GameConfig.Training
	local roll = random()
	if roll < cfg.GoldenChance then
		return "Golden"
	elseif roll < cfg.GoldenChance + cfg.CritChance then
		return "Mega"
	end
	return "Normal"
end

function Lifting.KindMultiplier(kind: string): number
	local cfg = GameConfig.Training
	if kind == "Golden" then
		return cfg.GoldenMultiplier
	elseif kind == "Mega" then
		return cfg.CritMultiplier
	end
	return 1
end

-- Strength paid for one rep. `base` = GameConfig.GetRepGain(tier, ascension) x pass.
function Lifting.RepAmount(base: number, rep: number, kind: string): number
	return math.max(1, math.floor(base * Lifting.Pump(rep) * Lifting.KindMultiplier(kind) + 0.5))
end

function Lifting.IsSetComplete(rep: number): boolean
	return rep > 0 and rep % GameConfig.Training.SetSize == 0
end

-- Bonus paid when a set completes, from the Strength earned during that set.
function Lifting.SetBonus(setGained: number): number
	return math.floor(setGained * GameConfig.Training.SetBonus + 0.5)
end

-- Expected Strength per second over a session of `seconds` (jackpots and set bonuses
-- averaged in). Used by the pacing tests and the UI's "next lift" estimate.
function Lifting.ExpectedRate(base: number, seconds: number): number
	local cfg = GameConfig.Training
	local reps = math.max(1, math.floor(seconds / cfg.RepPeriod))
	local luck = 1 + cfg.CritChance * (cfg.CritMultiplier - 1) + cfg.GoldenChance * (cfg.GoldenMultiplier - 1)
	local total = 0
	for rep = 1, reps do
		total += base * Lifting.Pump(rep) * luck
	end
	total *= 1 + cfg.SetBonus * math.floor(reps / cfg.SetSize) * cfg.SetSize / reps
	return total / (reps * cfg.RepPeriod)
end

return Lifting
