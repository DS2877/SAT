-- Codes players can type on the Info Board (CODES tab). Case doesn't matter.
--   Action: what it does (Services/CodeService).
--   AdminOnly: only owners/admins can use it (EventService.IsAdmin: Studio, the owner of a
--     user-owned place, GameConfig.Events.AdminUserIds) - the testing codes below are, so
--     nobody else can give themselves Ascension 3 or wipe their save by accident.
--   Once: a player can redeem it one time (remembered in their save).
-- Future player codes look like: summer = { Action = "Cash", Amount = 50000, Once = true }

local Codes = {
	devdev = { Action = "DevBoost", AdminOnly = true }, -- Ascension 3 + max Strength (testing)
	nodev = { Action = "Reset", AdminOnly = true }, -- back to a brand-new account (testing)
}

-- "Max Strength" for DevBoost: twice what the hardest region recommends.
Codes.DevStrengthFactor = 2
Codes.DevAscension = 3

return Codes
