-- Vault skin rules (Config/VaultSkins). Pure: shared by server (authority), client (menu) and
-- tests. `ownsPass(key)` answers game pass ownership (the server's own check, or the client's
-- Pass_<Key> attribute - display only).

local VaultSkinRules = {}

-- Net worth right now: cash + what's waiting on the collect pad + what everything in the vault
-- would sell for (trophy included). `sellValue(slotValue)` prices one vault slot.
function VaultSkinRules.NetWorth(data, sellValue: (string) -> number): number
	local total = (tonumber(data.Cash) or 0) + (tonumber(data.Vault and data.Vault.Stored) or 0)
	if data.Vault and type(data.Vault.Displays) == "table" then
		for _, value in data.Vault.Displays do
			if type(value) == "string" then
				total += sellValue(value)
			end
		end
	end
	return math.max(0, math.floor(total))
end

function VaultSkinRules.IsUnlocked(skin, data, ownsPass: (string) -> boolean): boolean
	local unlock = skin.Unlock
	if unlock.Kind == "Free" then
		return true
	elseif unlock.Kind == "NetWorth" then
		return (tonumber(data.Stats and data.Stats.PeakNetWorth) or 0) >= (unlock.Value or math.huge)
	elseif unlock.Kind == "Ascension" then
		return (tonumber(data.Ascension) or 0) >= (unlock.Value or math.huge)
	elseif unlock.Kind == "Pass" then
		return unlock.Pass ~= nil and ownsPass(unlock.Pass)
	end
	return false
end

-- How far along an EARNED skin is (0..1), for the menu's progress bar. Pass skins: 0.
function VaultSkinRules.Progress(skin, data): number
	local unlock = skin.Unlock
	if unlock.Kind == "NetWorth" then
		return math.clamp((tonumber(data.Stats and data.Stats.PeakNetWorth) or 0) / unlock.Value, 0, 1)
	elseif unlock.Kind == "Ascension" then
		return math.clamp((tonumber(data.Ascension) or 0) / unlock.Value, 0, 1)
	elseif unlock.Kind == "Free" then
		return 1
	end
	return 0
end

-- Short money text: 250K, 5M, 2B.
function VaultSkinRules.Short(n: number): string
	for _, step in { { 1e12, "T" }, { 1e9, "B" }, { 1e6, "M" }, { 1e3, "K" } } do
		if n >= step[1] then
			local value = n / step[1]
			return ("$%s%s"):format(if value >= 100 or value == math.floor(value) then tostring(math.floor(value)) else ("%.1f"):format(value), step[2])
		end
	end
	return "$" .. math.floor(n)
end

-- What a locked skin needs, in one line.
function VaultSkinRules.Requirement(skin): string
	local unlock = skin.Unlock
	if unlock.Kind == "NetWorth" then
		return ("REACH %s NET WORTH"):format(VaultSkinRules.Short(unlock.Value))
	elseif unlock.Kind == "Ascension" then
		return ("REACH ASCENSION %d"):format(unlock.Value)
	elseif unlock.Kind == "Pass" then
		return "ROBUX ONLY"
	end
	return "FREE"
end

-- The EARNED skins (net worth / Ascension) that `after` has and `before` didn't: for the
-- "NEW VAULT SKIN UNLOCKED" moment.
function VaultSkinRules.NewlyEarned(list, before, after): { any }
	local out = {}
	local never = function()
		return false
	end
	for _, skin in list do
		local kind = skin.Unlock.Kind
		if (kind == "NetWorth" or kind == "Ascension") and not VaultSkinRules.IsUnlocked(skin, before, never) and VaultSkinRules.IsUnlocked(skin, after, never) then
			table.insert(out, skin)
		end
	end
	return out
end

return VaultSkinRules
