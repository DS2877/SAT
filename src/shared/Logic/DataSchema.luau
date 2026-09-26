-- Player save format + versioned migrations. Pure (no Roblox APIs) so it is unit-tested.
-- Never wipe data because a field was added: Reconcile fills gaps, Migrate upgrades versions.

local DataSchema = {}

DataSchema.Version = 4

function DataSchema.Default()
	return {
		Version = DataSchema.Version,
		Cash = 0,
		Strength = 1000,
		Ascension = 0,
		Collection = {}, -- [treasureId] = { Discovered = true, Count = n }
		Vault = {
			Tier = 1,
			Displays = {}, -- ["slotIndex"] = "treasureId" or "treasureId|Mutation" (Logic/Economy)
			Stored = 0, -- uncollected Vault earnings (cash waiting on the collect pad)
		},
		OwnedGadgets = {}, -- [gadgetId] = true
		OwnedBenches = {}, -- [benchTierId] = true (free tiers need no entry)
		EquippedGadgets = { "", "", "" },
		OwnedBats = {}, -- [batId] = true (the Wooden Bat is free and needs no entry)
		EquippedBat = "wooden_bat",
		OwnedCosmetics = {},
		Titles = {},
		SelectedTitle = "",
		LastOnline = 0, -- os.time() of the last moment the player was in a server (offline earnings)
		Purchases = {}, -- [receiptId] = os.time(): developer products already granted (idempotency)
		Daily = { LastDay = 0, Streak = 0 }, -- login streak (UTC day number, day 1-7)
		Boosts = { TrainingUntil = 0 }, -- timed boosts from products (os.time())
		Stats = {
			Extractions = 0,
			Thefts = 0,
			Knocks = 0,
			Deaths = 0,
			TotalEarned = 0,
			BestRarityRank = 0,
			BestTreasureId = "",
		},
		Milestones = {}, -- [milestoneName] = unix time (analytics funnel, tutorial)
		Settings = {
			Music = true,
			AutoCollect = true, -- only matters with the Auto Collect pass (can be switched off)
		},
		TutorialStep = 0,
		EventSignups = {}, -- [eventId] = os.time() signed up at the Info Board (Config/News)
		NewsSeen = "", -- id of the newest Info Board post the player has read
	}
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = deepCopy(v)
	end
	return out
end

local function reconcile(target, template)
	for key, default in template do
		local current = target[key]
		if current == nil or type(current) ~= type(default) then
			target[key] = deepCopy(default)
		elseif type(default) == "table" and next(default) ~= nil and #default == 0 then
			-- Only recurse into record-like tables with known keys (not maps/arrays).
			reconcile(current, default)
		end
	end
end

-- Ordered migrations: Migrations[n] upgrades a version n-1 save to version n.
DataSchema.Migrations = {
	-- v2: AFK training. Starting Strength rose from 1 to 10.
	[2] = function(data)
		data.Strength = math.max(tonumber(data.Strength) or 10, 10)
	end,
	-- v3: treadmills became bench presses (same tier ids); keep anything already unlocked.
	[3] = function(data)
		if type(data.OwnedTreadmills) == "table" then
			data.OwnedBenches = data.OwnedTreadmills
			data.OwnedTreadmills = nil
		end
	end,
	-- v4: Strength and treasure Weight moved to a x100 scale (bigger, more rewarding numbers).
	[4] = function(data)
		data.Strength = (tonumber(data.Strength) or 10) * 100
	end,
}

function DataSchema.Migrate(data)
	if type(data) ~= "table" then
		return DataSchema.Default()
	end
	local version = tonumber(data.Version) or 0
	for v = version + 1, DataSchema.Version do
		local migrate = DataSchema.Migrations[v]
		if migrate then
			migrate(data)
		end
	end
	data.Version = DataSchema.Version
	reconcile(data, DataSchema.Default())

	-- Sanitise values that must never be invalid.
	data.Cash = math.max(0, math.floor(tonumber(data.Cash) or 0))
	data.Strength = math.max(1, tonumber(data.Strength) or 1000)
	data.Ascension = math.max(0, math.floor(tonumber(data.Ascension) or 0))
	data.Vault.Stored = math.max(0, tonumber(data.Vault.Stored) or 0)
	data.LastOnline = math.max(0, math.floor(tonumber(data.LastOnline) or 0))
	data.Daily.LastDay = math.max(0, math.floor(tonumber(data.Daily.LastDay) or 0))
	data.Daily.Streak = math.clamp(math.floor(tonumber(data.Daily.Streak) or 0), 0, 7)
	data.Boosts.TrainingUntil = math.max(0, tonumber(data.Boosts.TrainingUntil) or 0)
	if data.EquippedBat == "" then
		data.EquippedBat = "wooden_bat"
	end
	for i = 1, 3 do
		if type(data.EquippedGadgets[i]) ~= "string" then
			data.EquippedGadgets[i] = ""
		end
	end
	return data
end

return DataSchema
