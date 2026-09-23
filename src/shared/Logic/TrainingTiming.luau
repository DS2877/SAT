-- Timing-bar training. The marker sweeps 0 -> 1 -> 0 once per period (triangle wave),
-- synchronised through server time. Hitting near the centre (0.5) is Perfect.

local TrainingTiming = {}

function TrainingTiming.MarkerPosition(elapsed: number, period: number): number
	local phase = (elapsed % period) / period
	return 1 - math.abs(2 * phase - 1)
end

-- Returns "Perfect" | "Good" | "Miss"
function TrainingTiming.Grade(position: number, station): string
	local distance = math.abs(position - 0.5)
	if distance <= station.PerfectWindow then
		return "Perfect"
	elseif distance <= station.GoodWindow then
		return "Good"
	end
	return "Miss"
end

function TrainingTiming.Gain(grade: string, strength: number, station, overCapGain: number): number
	if grade == "Miss" then
		return 0
	end
	if strength >= station.Cap then
		return grade == "Perfect" and overCapGain or 0
	end
	return grade == "Perfect" and station.PerfectGain or station.GoodGain
end

return TrainingTiming
