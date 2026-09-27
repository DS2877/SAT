-- In-game player feedback: the 💬 button (a thumbs up/down and a short message) and the Info
-- Board's FEEDBACK tab (a kind - idea / bug / love it / not fun - and a message).
-- Stored in the DataStore GameConfig.Feedback.StoreName, one key per UTC day ("2026-09-25")
-- holding a capped list. READ IT in the 🛡 Admin panel (💬 PLAYER FEEDBACK), or outside the
-- game with Open Cloud (.github/workflows/feedback.yml). Entries carry no user id or name:
-- only the vote, the kind, the text and a little game context (extractions, ascension).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)
local EventService = require(script.Parent.EventService)

local FeedbackService = {}

local cfg = GameConfig.Feedback
local lastSent: { [Player]: number } = {}

-- Trim, drop control characters and cap the length (in characters, not bytes).
local function clean(text: string): string
	text = text:gsub("%c", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if utf8.len(text) == nil then
		return "" -- invalid UTF-8
	end
	local cut = utf8.offset(text, cfg.MaxLength + 1)
	if cut then
		text = text:sub(1, cut - 1)
	end
	return text
end

local function store(entry)
	local key = os.date("!%Y-%m-%d") :: string
	local ok, err = pcall(function()
		DataStoreService:GetDataStore(cfg.StoreName):UpdateAsync(key, function(list)
			list = if type(list) == "table" then list else {}
			if #list >= cfg.MaxPerDay then
				return nil -- full for today: keep what we have
			end
			table.insert(list, entry)
			return list
		end)
	end)
	if not ok then
		warn("[Feedback] save failed:", err)
	end
end

local KINDS = {}
for _, kind in cfg.Kinds do
	KINDS[kind.Id] = kind
end

-- The last `days` days of feedback, newest first (at most AdminMax). Yields.
function FeedbackService.Recent(days: number)
	local entries = {}
	local ok, storeOrErr = pcall(DataStoreService.GetDataStore, DataStoreService, cfg.StoreName)
	if not ok then
		return entries, "The DataStore is unavailable (in Studio: turn on API access)"
	end
	local now = os.time()
	for i = 0, days - 1 do
		local key = os.date("!%Y-%m-%d", now - i * 86400) :: string
		local got, list = pcall(storeOrErr.GetAsync, storeOrErr, key)
		if got and type(list) == "table" then
			for _, entry in list do
				if type(entry) == "table" then
					table.insert(entries, entry)
				end
			end
		elseif not got then
			return entries, "Couldn't read the feedback - try again in a minute"
		end
	end
	table.sort(entries, function(a, b)
		return (tonumber(a.t) or 0) > (tonumber(b.t) or 0)
	end)
	while #entries > cfg.AdminMax do
		table.remove(entries)
	end
	return entries, nil
end

-- 🛡 Admin panel: send the latest feedback to an admin (checked here, not trusted from the client).
function FeedbackService.SendToAdmin(player: Player)
	if not EventService.IsAdmin(player) then
		return
	end
	local entries, err = FeedbackService.Recent(cfg.AdminDays)
	Net.Fire("AdminFeedback", player, { Entries = entries, Error = err, Days = cfg.AdminDays })
end

function FeedbackService.Init()
	Net.On("SendFeedback", function(player: Player, vote: any, text: any, kind: any)
		if type(vote) ~= "number" or (vote ~= 1 and vote ~= -1 and vote ~= 0) then
			return
		end
		kind = if type(kind) == "string" and KINDS[kind] then kind else nil
		if kind then
			vote = KINDS[kind].Vote
		end
		text = if type(text) == "string" then clean(text) else ""
		if vote == 0 and text == "" then
			return
		end
		local now = os.clock()
		if now - (lastSent[player] or -math.huge) < cfg.Cooldown then
			Net.Fire("Notify", player, { Kind = "Toast", Text = "Thanks - you can send more in a minute", Tone = "Info" })
			return
		end
		lastSent[player] = now
		local data = PlayerData.Get(player)
		local entry = {
			t = os.time(),
			v = vote,
			m = text,
			k = kind,
			x = data and data.Stats.Extractions or 0,
			a = data and data.Ascension or 0,
			p = math.floor((workspace.DistributedGameTime or 0) / 60), -- server age in minutes
		}
		task.spawn(store, entry)
		Analytics.Event(player, "Feedback", { Vote = vote })
		Net.Fire("Notify", player, { Kind = "Banner", Title = "💬 THANK YOU!", Text = "We read every message - it shapes the next update", Tone = "Reward", Duration = 3 })
	end, 0.5)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		lastSent[player] = nil
	end)
end

return FeedbackService
