-- All RemoteEvents live here. The server creates them; clients wait for them.
-- Server handlers are wrapped with per-player rate limiting and error isolation.
-- Every client->server handler must still validate its own arguments.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(script.Parent.Config.GameConfig)

local Net = {}

-- Server -> Client
Net.ServerToClient = {
	"DataSync", -- full profile snapshot (sent on change)
	"Feedback", -- gameplay feedback events: { Type = "...", ... }
	"Notify", -- toast / banner / social feed messages
	"TrainingState", -- training set start/stop
	"TrainingRep", -- one bench rep paid out (amount, jackpot kind, pump, set bonus)
	"ExtractionState",
	"GadgetState", -- cooldowns / effects
	"OpenMenu",
}

-- Client -> Server
Net.ClientToServer = {
	"ClientReady",
	"Attack",
	"UseGadget",
	"BuyGadget",
	"EquipGadget",
	"BuyBat", -- (batId) at the Bat Shop
	"EquipBat", -- (batId) an owned bat into your hand
	"SellTreasure",
	"SetTrophy", -- (slot) put pedestal `slot` on the trophy pedestal outside; 0 = take it back in
	"UpgradeVault",
	"Ascend",
	"StopTraining",
	"TutorialProgress",
	"SetSetting", -- (name, value) player preferences, e.g. Music on/off
	"DropTreasure", -- put down the treasure you are carrying
	"SendFeedback", -- (vote -1/0/1, text) from the 💬 menu
	"EventSignup", -- (eventId, wantIn) at the Info Board
	"NewsSeen", -- (postId) the newest post the player has read on the Info Board
}

local FOLDER_NAME = "Remotes"
local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	local found: Folder
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER_NAME) :: Folder?
		if existing then
			found = existing
		else
			found = Instance.new("Folder")
			found.Name = FOLDER_NAME
			found.Parent = ReplicatedStorage
		end
	else
		found = ReplicatedStorage:WaitForChild(FOLDER_NAME) :: Folder
	end
	folder = found
	return found
end

function Net.Init()
	assert(RunService:IsServer(), "Net.Init is server-only")
	local root = getFolder()
	for _, list in { Net.ServerToClient, Net.ClientToServer } do
		for _, name in list do
			if not root:FindFirstChild(name) then
				local remote = Instance.new("RemoteEvent")
				remote.Name = name
				remote.Parent = root
			end
		end
	end
end

function Net.Get(name: string): RemoteEvent
	local root = getFolder()
	if RunService:IsServer() then
		return root:FindFirstChild(name) :: RemoteEvent
	end
	return root:WaitForChild(name) :: RemoteEvent
end

-- Server: connect a rate-limited handler. handler(player, ...)
local buckets: { [Player]: { [string]: { Tokens: number, Last: number } } } = {}

function Net.On(name: string, handler: (Player, ...any) -> (), ratePerSecond: number?)
	local rate = ratePerSecond or GameConfig.Remotes.DefaultRate
	Net.Get(name).OnServerEvent:Connect(function(player, ...)
		local playerBuckets = buckets[player]
		if not playerBuckets then
			playerBuckets = {}
			buckets[player] = playerBuckets
		end
		local now = os.clock()
		local bucket = playerBuckets[name]
		if not bucket then
			bucket = { Tokens = rate, Last = now }
			playerBuckets[name] = bucket
		end
		bucket.Tokens = math.min(rate, bucket.Tokens + (now - bucket.Last) * rate)
		bucket.Last = now
		if bucket.Tokens < 1 then
			return -- silently drop spam
		end
		bucket.Tokens -= 1
		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[Net] %s handler error for %s: %s"):format(name, player.Name, tostring(err)))
		end
	end)
end

function Net.Fire(name: string, player: Player, ...)
	Net.Get(name):FireClient(player, ...)
end

function Net.FireAll(name: string, ...)
	Net.Get(name):FireAllClients(...)
end

if RunService:IsServer() then
	Players.PlayerRemoving:Connect(function(player)
		buckets[player] = nil
	end)
end

return Net
