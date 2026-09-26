-- In-game player feedback (the 💬 button): a thumbs up/down and an optional short message.
-- Stored in the DataStore GameConfig.Feedback.StoreName, one key per UTC day ("2026-09-25")
-- holding a capped list, so the developer can read it with Open Cloud
-- (.github/workflows/feedback.yml). Entries carry no user id or name: only the vote, the
-- text and a little game context (region danger reached, extractions, ascension).

local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

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

function FeedbackService.Init()
	Net.On("SendFeedback", function(player: Player, vote: any, text: any)
		if type(vote) ~= "number" or (vote ~= 1 and vote ~= -1 and vote ~= 0) then
			return
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
