-- Carry formula. Pure: pass the carry config (GameConfig.Carry) in.
-- Carry Ratio = Treasure Weight / Player Strength

local Carry = {}

function Carry.Ratio(weight: number, strength: number): number
	return weight / math.max(strength, 1)
end

function Carry.SpeedMultiplier(weight: number, strength: number, config): number
	local ratio = Carry.Ratio(weight, strength)
	for _, band in config.Bands do
		if ratio <= band.MaxRatio then
			return band.Speed
		end
	end
	return config.Bands[#config.Bands].Speed
end

function Carry.JumpMultiplier(speedMultiplier: number, config): number
	return math.clamp(speedMultiplier, config.JumpMultiplierFloor, 1)
end

function Carry.RecommendedStrength(weight: number, config): number
	return math.ceil(weight * config.RecommendedStrengthFactor)
end

function Carry.PickupHoldDuration(weight: number, config): number
	return math.min(config.PickupHoldMax, config.PickupHoldBase + weight * config.PickupHoldPerWeight)
end

-- Short human label for the burden, used by HUD.
function Carry.BurdenLabel(speedMultiplier: number): string
	if speedMultiplier > 1 then
		return "OVERPOWERED"
	elseif speedMultiplier >= 1 then
		return "LIGHT"
	elseif speedMultiplier >= 0.75 then
		return "MANAGEABLE"
	elseif speedMultiplier >= 0.6 then
		return "HEAVY"
	elseif speedMultiplier >= 0.45 then
		return "VERY HEAVY"
	end
	return "CRUSHING"
end

return Carry
