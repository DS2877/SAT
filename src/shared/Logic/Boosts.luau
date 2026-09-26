-- Global boosts (GameConfig.GlobalBoosts): what's running right now, for server and client.
-- State lives in workspace attributes "Boost_<Kind>" = the unix time it ends (set by
-- Services/AdminService on every server), so late joiners see it too.

local GameConfig = require(script.Parent.Parent.Config.GameConfig)

local Boosts = {}

local function now(): number
	return workspace:GetServerTimeNow()
end

-- Seconds left on a boost (0 = not running).
function Boosts.Remaining(kind: string, at: number?): number
	local endsAt = workspace:GetAttribute("Boost_" .. kind)
	if type(endsAt) ~= "number" then
		return 0
	end
	return math.max(0, endsAt - (at or now()))
end

-- The boost's multiplier while it runs, 1 otherwise.
function Boosts.Multiplier(kind: string, at: number?): number
	local info = GameConfig.GlobalBoosts[kind]
	if not info or Boosts.Remaining(kind, at) <= 0 then
		return 1
	end
	return info.Multiplier
end

-- { { Kind, Info, Remaining } } for every running boost, in display order.
function Boosts.Active(at: number?)
	local list = {}
	for _, kind in GameConfig.GlobalBoosts.Order do
		local left = Boosts.Remaining(kind, at)
		if left > 0 then
			table.insert(list, { Kind = kind, Info = GameConfig.GlobalBoosts[kind], Remaining = left })
		end
	end
	return list
end

return Boosts
