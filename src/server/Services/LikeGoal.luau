-- 👍 LIKE GOAL: a community goal floating over the Info Board (tag "LikeGoal"). When the game's
-- likes reach the goal, EVERY server gets a free global boost (GameConfig.LikeGoal.Reward) and
-- the next goal goes up. It rewards everyone at once - nobody is paid personally for liking.
-- Likes come from a public proxy of the Roblox games API (needs "Allow HTTP Requests" in the
-- game settings); without it the board still shows the goal and the reward, just no count.
-- The reached goal is kept in DataStore "SATAdmin" key "LikeGoal", so exactly one server wins
-- the race to hand out each reward (UpdateAsync).

local CollectionService = game:GetService("CollectionService")
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)

local AdminService = require(script.Parent.AdminService)

local LikeGoal = {}

local cfg = GameConfig.LikeGoal
local STORE, KEY = "SATAdmin", "LikeGoal"

local reached = 0 -- the highest goal already rewarded
local likes: number? = nil

-- The next goal after `done` (the ladder in the config, then doubling). Pure.
function LikeGoal.NextGoal(done: number): number
	for _, goal in cfg.Goals do
		if goal > done then
			return goal
		end
	end
	local goal = cfg.Goals[#cfg.Goals]
	while goal <= done do
		goal *= 2
	end
	return goal
end

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local boards: { { Title: TextLabel, Reward: TextLabel } } = {}
local function render()
	local goal = LikeGoal.NextGoal(reached)
	local reward = GameConfig.GlobalBoosts[cfg.Reward.Boost]
	local title = if likes
		then ("👍 LIKE GOAL: %s / %s"):format(formatNumber(likes), formatNumber(goal))
		else ("👍 LIKE GOAL: %s LIKES"):format(formatNumber(goal))
	local line = ("at the goal: %s %s x%d for %d min on EVERY server"):format(reward.Icon, reward.Name, reward.Multiplier, cfg.Reward.Minutes)
	for _, board in boards do
		board.Title.Text = title
		board.Reward.Text = line
	end
	workspace:SetAttribute("LikeGoal", goal)
	workspace:SetAttribute("LikeCount", likes or -1)
end

local function buildBoard(anchor: Instance)
	local gui = Instance.new("BillboardGui")
	gui.Name = "LikeGoalBoard"
	gui.Size = UDim2.fromScale(20, 3.6)
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(20, 26, 50)
	frame.BackgroundTransparency = 0.15
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.25, 0)
	corner.Parent = frame
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 170, 255)
	stroke.Thickness = 3
	stroke.Parent = frame
	local function label(y: number, h: number, color: Color3): TextLabel
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Position = UDim2.fromScale(0.04, y)
		l.Size = UDim2.fromScale(0.92, h)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = color
		l.TextStrokeTransparency = 0.3
		l.Parent = frame
		return l
	end
	table.insert(boards, {
		Title = label(0.08, 0.52, Color3.fromRGB(120, 230, 255)),
		Reward = label(0.6, 0.32, Color3.fromRGB(255, 235, 160)),
	})
	gui.Parent = anchor
end

local function fetchLikes(): number?
	local ok, body = pcall(HttpService.GetAsync, HttpService, cfg.VotesUrl:format(game.GameId), true)
	if not ok then
		return nil
	end
	local decoded, data = pcall(HttpService.JSONDecode, HttpService, body)
	if not decoded or type(data) ~= "table" or type(data.data) ~= "table" then
		return nil
	end
	local entry = data.data[1]
	return if type(entry) == "table" and type(entry.upVotes) == "number" then entry.upVotes else nil
end

local function store(): DataStore?
	local ok, result = pcall(DataStoreService.GetDataStore, DataStoreService, STORE)
	return if ok then result else nil
end

-- Goal reached: claim it (one server wins) and hand out the reward everywhere.
local function claim(goal: number)
	local s = store()
	if not s then
		return
	end
	local won = false
	local ok = pcall(s.UpdateAsync, s, KEY, function(old)
		local done = if type(old) == "table" then tonumber(old.Reached) or 0 else 0
		if done >= goal then
			reached = math.max(reached, done)
			return nil -- someone else already did
		end
		won = true
		return { Reached = goal, At = os.time() }
	end)
	if ok and won then
		reached = goal
		AdminService.StartBoost(cfg.Reward.Boost, cfg.Reward.Minutes, true, ("👍 LIKE GOAL OF %s REACHED! Thanks for the likes!"):format(formatNumber(goal)))
	end
end

function LikeGoal.Init()
	if not cfg.Enabled then
		return
	end
	for _, anchor in CollectionService:GetTagged("LikeGoal") do
		buildBoard(anchor)
	end
	render()
	task.spawn(function()
		local s = store()
		if s then
			local ok, saved = pcall(s.GetAsync, s, KEY)
			if ok and type(saved) == "table" then
				reached = tonumber(saved.Reached) or 0
			end
		end
		while true do
			local count = fetchLikes()
			if count then
				likes = count
				local goal = LikeGoal.NextGoal(reached)
				if count >= goal then
					claim(goal)
				end
			end
			render()
			task.wait(cfg.PollSeconds)
		end
	end)
end

return LikeGoal
