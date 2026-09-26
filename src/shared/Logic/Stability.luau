-- Carrier stability state machine: STABLE -> SHAKEN -> KNOCKED.
-- Pure: the caller supplies `now` and the stability config (GameConfig.Stability).

local Stability = {}

export type State = {
	State: string, -- "Stable" | "Shaken" | "Knocked"
	ShakenAt: number,
	KnockedUntil: number,
	ImmuneUntil: number,
}

function Stability.new(): State
	return { State = "Stable", ShakenAt = -math.huge, KnockedUntil = 0, ImmuneUntil = 0 }
end

-- Applies time-based transitions. Returns true if the state changed.
function Stability.Update(st: State, now: number, config): boolean
	local knockOver = st.State == "Knocked" and now >= st.KnockedUntil
	local shakeOver = st.State == "Shaken" and now - st.ShakenAt >= config.ShakenWindow
	if knockOver or shakeOver then
		st.State = "Stable"
		return true
	end
	return false
end

function Stability.IsImmune(st: State, now: number): boolean
	return st.State == "Knocked" or now < st.ImmuneUntil
end

-- Registers a qualifying hit. Returns "Ignored" | "Shaken" | "Knocked".
function Stability.Hit(st: State, now: number, config): string
	Stability.Update(st, now, config)
	if Stability.IsImmune(st, now) then
		return "Ignored"
	end
	if st.State == "Shaken" then
		st.State = "Knocked"
		st.KnockedUntil = now + config.KnockedDuration
		st.ImmuneUntil = st.KnockedUntil + config.KnockImmunity
		return "Knocked"
	end
	st.State = "Shaken"
	st.ShakenAt = now
	return "Shaken"
end

-- Forces a knock (e.g. death is handled elsewhere; used for instant-knock hazards).
function Stability.ForceKnock(st: State, now: number, config)
	st.State = "Knocked"
	st.KnockedUntil = now + config.KnockedDuration
	st.ImmuneUntil = st.KnockedUntil + config.KnockImmunity
end

function Stability.Reset(st: State)
	st.State = "Stable"
	st.ShakenAt = -math.huge
	st.KnockedUntil = 0
	st.ImmuneUntil = 0
end

return Stability
