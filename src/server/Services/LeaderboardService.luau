-- Physical leaderboards in the Treasure District. Global scores come from OrderedDataStores;
-- players in this server are merged in live so the boards react immediately.
-- If DataStores are unavailable the boards still work with in-server players only.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)

local PlayerData = require(script.Parent.PlayerData)

local LeaderboardService = {}

local cfg = GameConfig.Leaderboards
local boardRows: { [string]: Frame } = {}
local stores: { [string]: OrderedDataStore } = {}
local globalTop: { [string]: { { UserId: number, Score: number } } } = {}
local names: { [number]: string } = {}
local lastWrite: { [Player]: number } = {}

-- Treasure values are unique, so the "Rarest" score (best treasure value) maps back to a name.
local treasureByValue = {}
for _, def in Treasures.List do
	treasureByValue[def.Value] = def
end

function LeaderboardService.Score(boardId: string, data): number
	if boardId == "Richest" then
		-- Lifetime earnings: current Cash is wiped by every Ascension.
		return math.floor(data.Stats.TotalEarned)
	elseif boardId == "Strongest" then
		return math.floor(data.Strength)
	elseif boardId == "Rarest" then
		local def = Treasures.Get(data.Stats.BestTreasureId)
		return if def then def.Value else 0
	elseif boardId == "Extractions" then
		return data.Stats.Extractions
	elseif boardId == "Ascended" then
		return data.Ascension
	end
	return 0
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local player = Players:GetPlayerByUserId(userId)
	if player then
		names[userId] = player.DisplayName
		return player.DisplayName
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	names[userId] = if ok then result else "Explorer"
	return names[userId]
end

local function formatScore(format: string, score: number): (string, Color3)
	if format == "Cash" then
		local s = tostring(score):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
		return "$" .. s, Color3.fromRGB(120, 235, 120)
	elseif format == "Treasure" then
		local def = treasureByValue[score]
		if def then
			local info = Rarities.Info[def.Rarity]
			return info.Glyph .. " " .. def.Name, info.Color
		end
		return "—", Color3.fromRGB(180, 180, 190)
	end
	return tostring(score), Color3.new(1, 1, 1)
end

local function merged(boardId: string)
	local byUser: { [number]: number } = {}
	local top = globalTop[boardId]
	for _, entry in if top then top else {} :: { { UserId: number, Score: number } } do
		byUser[entry.UserId] = entry.Score
	end
	for _, player in Players:GetPlayers() do
		local data = PlayerData.Get(player)
		if data then
			byUser[player.UserId] = LeaderboardService.Score(boardId, data)
		end
	end
	local list = {}
	for userId, score in byUser do
		if score > 0 then
			table.insert(list, { UserId = userId, Score = score })
		end
	end
	table.sort(list, function(a, b)
		return a.Score > b.Score
	end)
	return list
end

local function row(parent: Frame, rank: number, name: string, value: string, valueColor: Color3, highlight: boolean)
	local frame = Instance.new("Frame")
	frame.LayoutOrder = rank
	frame.Size = UDim2.new(1, 0, 0, 36)
	frame.BackgroundColor3 = if highlight then Color3.fromRGB(70, 60, 30) else Color3.fromRGB(40, 46, 72)
	frame.BackgroundTransparency = if rank % 2 == 0 then 0.5 else 0.2
	frame.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame
	local rankColors = { Color3.fromRGB(255, 205, 60), Color3.fromRGB(210, 215, 225), Color3.fromRGB(215, 140, 80) }
	local function text(content: string, x: number, width: number, color: Color3, align: Enum.TextXAlignment)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Position = UDim2.new(x, 6, 0, 0)
		label.Size = UDim2.new(width, -12, 1, 0)
		label.Font = Enum.Font.GothamBold
		label.TextScaled = true
		label.TextColor3 = color
		label.TextXAlignment = align
		label.Text = content
		label.Parent = frame
		local constraint = Instance.new("UITextSizeConstraint")
		constraint.MaxTextSize = 24
		constraint.Parent = label
	end
	text("#" .. rank, 0, 0.14, rankColors[rank] or Color3.fromRGB(180, 186, 205), Enum.TextXAlignment.Left)
	text(name, 0.14, 0.46, Color3.new(1, 1, 1), Enum.TextXAlignment.Left)
	text(value, 0.6, 0.4, valueColor, Enum.TextXAlignment.Right)
	frame.Parent = parent
end

local drawing = false
local redrawAgain = false

local function drawBoards()
	local online = {}
	for _, player in Players:GetPlayers() do
		online[player.UserId] = true
	end
	for _, def in cfg.Boards do
		local rows = boardRows[def.Id]
		if rows then
			for _, child in rows:GetChildren() do
				if child:IsA("Frame") then
					child:Destroy()
				end
			end
			local list = merged(def.Id)
			for rank = 1, math.min(cfg.Rows, #list) do
				local entry = list[rank]
				local value, color = formatScore(def.Format, entry.Score)
				row(rows, rank, nameFor(entry.UserId), value, color, online[entry.UserId] == true)
			end
		end
	end
end

-- Name lookups can yield, so never let two redraws interleave (duplicate rows).
local function redraw()
	if drawing then
		redrawAgain = true
		return
	end
	drawing = true
	repeat
		redrawAgain = false
		local ok, err = pcall(drawBoards)
		if not ok then
			warn("[Leaderboard] redraw failed:", err)
		end
	until not redrawAgain
	drawing = false
end

local function fetchGlobal()
	for _, def in cfg.Boards do
		local store = stores[def.Id]
		if store then
			local ok, pages = pcall(function()
				return store:GetSortedAsync(false, cfg.Rows)
			end)
			if ok and pages then
				local list = {}
				for _, item in pages:GetCurrentPage() do
					local userId = tonumber(string.match(item.key, "%d+"))
					if userId then
						table.insert(list, { UserId = userId, Score = item.value })
					end
				end
				globalTop[def.Id] = list
			end
		end
	end
end

local function upload(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	lastWrite[player] = os.clock()
	for _, def in cfg.Boards do
		local store = stores[def.Id]
		if store then
			local score = LeaderboardService.Score(def.Id, data)
			pcall(function()
				store:SetAsync("u_" .. player.UserId, score)
			end)
		end
	end
end

function LeaderboardService.Init(builtBoards)
	boardRows = builtBoards
	for _, def in cfg.Boards do
		local ok, store = pcall(function()
			return DataStoreService:GetOrderedDataStore(cfg.StorePrefix .. def.Id)
		end)
		if ok then
			stores[def.Id] = store
		end
	end
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(upload, player)
		lastWrite[player] = nil
	end)
end

function LeaderboardService.Start()
	task.spawn(function()
		while true do
			fetchGlobal()
			redraw()
			local waited = 0
			while waited < cfg.RefreshInterval do
				waited += task.wait(5)
				local now = os.clock()
				for _, player in Players:GetPlayers() do
					if now - (lastWrite[player] or 0) >= cfg.WriteInterval then
						task.spawn(upload, player)
					end
				end
			end
		end
	end)
	-- Live players move up the boards without waiting for the global refresh.
	local pending = false
	PlayerData.Changed:Connect(function()
		if not pending then
			pending = true
			task.delay(3, function()
				pending = false
				redraw()
			end)
		end
	end)
end

return LeaderboardService
