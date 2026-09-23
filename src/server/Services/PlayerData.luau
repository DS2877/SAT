-- Loads, holds, saves and replicates player profiles.
-- Session-locked via UpdateAsync so two servers never write the same profile.
-- Other services mutate data only through PlayerData.Update(player, fn).

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Logic.DataSchema)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local PlayerData = {}

PlayerData.Loaded = Signal.new() -- (player, data)
PlayerData.Changed = Signal.new() -- (player, data)

type Profile = { Data: any, Persistent: boolean, LastSave: number }

local profiles: { [Player]: Profile } = {}
local pendingSync: { [Player]: boolean } = {}
local jobId = game.JobId ~= "" and game.JobId or ("studio-" .. HttpService:GenerateGUID(false))

local store: DataStore? = nil
do
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.Data.StoreName, GameConfig.Data.Scope)
	end)
	if ok then
		store = result
	else
		warn("[PlayerData] DataStore unavailable, running with temporary data:", result)
	end
end

local function keyFor(player: Player): string
	return "player_" .. player.UserId
end

local function retry(attempts: number, fn: () -> any): (boolean, any)
	local lastErr
	for attempt = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		task.wait(math.min(2 ^ attempt, 8))
	end
	return false, lastErr
end

-- Acquire the session lock and load. Returns (ok, data, persistent)
local function loadProfile(player: Player): (boolean, any, boolean)
	if not store then
		return true, DataSchema.Default(), false
	end
	local ok, result = retry(GameConfig.Data.LoadRetries, function()
		local loaded
		local lockedElsewhere = false
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			old = old or {}
			local lock = old._Lock
			if lock and lock.JobId ~= jobId and os.time() - (lock.Time or 0) < GameConfig.Data.SessionLockTimeout then
				lockedElsewhere = true
				return nil -- abort write
			end
			local data = DataSchema.Migrate(old.Data)
			loaded = data
			return { Data = data, _Lock = { JobId = jobId, Time = os.time() } }
		end)
		if lockedElsewhere then
			error("profile locked by another server")
		end
		return loaded
	end)
	if not ok then
		-- Studio without API access: play with temporary data instead of blocking development.
		if RunService:IsStudio() then
			warn("[PlayerData] Studio load failed, using temporary data:", result)
			return true, DataSchema.Default(), false
		end
		return false, result, false
	end
	return true, result, true
end

local function saveProfile(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not profile.Persistent or not store then
		return
	end
	local data = profile.Data
	local ok, err = retry(3, function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			old = old or {}
			local lock = old._Lock
			if lock and lock.JobId ~= jobId then
				return nil -- another server owns it now; never overwrite
			end
			return { Data = data, _Lock = if release then nil else { JobId = jobId, Time = os.time() } }
		end)
	end)
	if ok then
		profile.LastSave = os.clock()
	else
		warn("[PlayerData] save failed for", player.Name, err)
	end
end

local function updateLeaderstats(player: Player, data)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "leaderstats"
		local cash = Instance.new("IntValue")
		cash.Name = "Cash"
		cash.Parent = stats
		local strength = Instance.new("IntValue")
		strength.Name = "Strength"
		strength.Parent = stats
		stats.Parent = player
	end
	(stats :: any).Cash.Value = data.Cash;
	(stats :: any).Strength.Value = math.floor(data.Strength)
	player:SetAttribute("Strength", data.Strength)
	player:SetAttribute("Ascension", data.Ascension)
	player:SetAttribute("Title", data.SelectedTitle)
end

local function syncNow(player: Player)
	pendingSync[player] = nil
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	updateLeaderstats(player, profile.Data)
	Net.Fire("DataSync", player, profile.Data)
end

function PlayerData.Get(player: Player)
	local profile = profiles[player]
	return profile and profile.Data
end

function PlayerData.IsLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

-- Mutate a profile. Sync is deferred to end of frame so several updates batch into one send.
function PlayerData.Update(player: Player, mutator: (any) -> ()): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	mutator(profile.Data)
	PlayerData.Changed:Fire(player, profile.Data)
	if not pendingSync[player] then
		pendingSync[player] = true
		task.defer(syncNow, player)
	end
	return true
end

function PlayerData.AddCash(player: Player, amount: number)
	return PlayerData.Update(player, function(data)
		data.Cash = math.max(0, math.floor(data.Cash + amount))
		if amount > 0 then
			data.Stats.TotalEarned += math.floor(amount)
		end
	end)
end

function PlayerData.TrySpend(player: Player, amount: number): boolean
	local data = PlayerData.Get(player)
	if not data or amount < 0 or data.Cash < amount then
		return false
	end
	PlayerData.Update(player, function(d)
		d.Cash -= amount
	end)
	return true
end

-- Records a first-time milestone. Returns true the first time only.
function PlayerData.Milestone(player: Player, name: string): boolean
	local data = PlayerData.Get(player)
	if not data or data.Milestones[name] then
		return false
	end
	PlayerData.Update(player, function(d)
		d.Milestones[name] = os.time()
	end)
	return true
end

function PlayerData.Resync(player: Player)
	syncNow(player)
end

local function onPlayerAdded(player: Player)
	local ok, data, persistent = loadProfile(player)
	if not player.Parent then
		return
	end
	if not ok then
		warn("[PlayerData] load failed for", player.Name, data)
		player:Kick("Your treasure data could not be loaded safely. Please rejoin in a moment.")
		return
	end
	profiles[player] = { Data = data, Persistent = persistent, LastSave = os.clock() }
	updateLeaderstats(player, data)
	PlayerData.Loaded:Fire(player, data)
	syncNow(player)
end

function PlayerData.Init()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	Net.On("ClientReady", function(player)
		if profiles[player] then
			syncNow(player)
		end
	end, 2)
end

-- Called by the bootstrap AFTER other services handled PlayerRemoving (so dropped treasure,
-- extraction etc. are resolved before the final save).
function PlayerData.Release(player: Player)
	if profiles[player] then
		saveProfile(player, true)
		profiles[player] = nil
		pendingSync[player] = nil
	end
end

function PlayerData.Start()
	task.spawn(function()
		while true do
			task.wait(GameConfig.Data.AutosaveInterval)
			for player in profiles do
				task.spawn(saveProfile, player, false)
			end
		end
	end)

	game:BindToClose(function()
		local threads = 0
		for player in profiles do
			threads += 1
			task.spawn(function()
				saveProfile(player, true)
				threads -= 1
			end)
		end
		local deadline = os.clock() + 25
		while threads > 0 and os.clock() < deadline do
			task.wait(0.1)
		end
	end)
end

return PlayerData
