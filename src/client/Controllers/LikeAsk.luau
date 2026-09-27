-- 👍 "Like the game" - asked at a happy moment, twice at most, never as a wall:
--   * after your 3rd bank (you've got the loop and just got paid), and
--   * after your 15th, unless you said you already did.
-- Roblox has no in-game "like" button, so the card asks for a 👍 on the game page and offers
-- Roblox's own FAVORITE prompt (that one works right here). It shows the community Like Goal
-- (Services/LikeGoal) - the reward is for everyone, nobody is paid personally for liking.

local AvatarEditorService = game:GetService("AvatarEditorService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)

local LikeAsk = {}

local player = Players.LocalPlayer
local ASK_AT = { [1] = 3, [2] = 15 } -- banks
local DELAY = 5 -- seconds after the bank, so the reward popup plays first

local card: Frame
local goalLabel: TextLabel
local stageShown = 0

local function formatNumber(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function goalText(): string
	local goal = workspace:GetAttribute("LikeGoal")
	local count = workspace:GetAttribute("LikeCount")
	local reward = GameConfig.GlobalBoosts[GameConfig.LikeGoal.Reward.Boost]
	if type(goal) ~= "number" or not reward then
		return ""
	end
	local progress = if type(count) == "number" and count >= 0 then ("%s / %s likes"):format(formatNumber(count), formatNumber(goal)) else ("%s likes"):format(formatNumber(goal))
	return ("LIKE GOAL: %s → %s %s x%d for EVERYONE"):format(progress, reward.Icon, reward.Name, reward.Multiplier)
end

local function close(done: boolean)
	Kit.tween(card, TweenInfo.new(0.2), { Position = UDim2.fromScale(0.5, 1.4) })
	task.delay(0.21, function()
		card.Visible = false
	end)
	Net.Get("LikeAskSeen"):FireServer(stageShown, done)
end

local function show(stage: number)
	stageShown = stage
	goalLabel.Text = goalText()
	card.Position = UDim2.fromScale(0.5, 1.4)
	card.Visible = true
	Kit.tween(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.fromScale(0.5, 0.5) })
	Sounds.Play("Notify")
end

local function build(gui: ScreenGui)
	card = Kit.panel({
		Name = "LikeAsk",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 1.4),
		Size = UDim2.fromScale(0.9, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Color3.fromRGB(24, 30, 60),
		BackgroundTransparency = 0.02,
		Radius = Theme.Radius.Large,
		Visible = false,
		ZIndex = 40,
		Parent = gui,
	}, {
		Kit.padding(16, 18),
		Kit.list(Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center),
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(440, math.huge) }),
	})
	local stroke = card:FindFirstChildOfClass("UIStroke")
	if stroke then
		stroke.Color = Color3.fromRGB(90, 200, 255)
		stroke.Thickness = 3
	end
	Kit.label({ Text = "👍", LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 56), TextSize = 50, ZIndex = 41, Parent = card })
	Kit.label({ Text = "ENJOYING THE GAME?", LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 32), Font = Theme.Font.Display, TextSize = 28, TextColor3 = Theme.Color.Gold, ZIndex = 41, Parent = card })
	Kit.label({
		Text = "Give us a 👍 LIKE on the game page - it's the #1 way to help a new game grow. Thank you!",
		LayoutOrder = 3,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Bold,
		TextSize = 19,
		TextWrapped = true,
		ZIndex = 41,
		Parent = card,
	})
	goalLabel = Kit.label({
		LayoutOrder = 4,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Font.Black,
		TextSize = 15,
		TextWrapped = true,
		TextColor3 = Color3.fromRGB(120, 230, 255),
		ZIndex = 41,
		Parent = card,
	})
	local row = Kit.new("Frame", { LayoutOrder = 5, Size = UDim2.new(1, 0, 0, 50), BackgroundTransparency = 1, ZIndex = 41, Parent = card }, {
		Kit.list(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	Kit.button({ LayoutOrder = 1, Size = UDim2.new(0.5, -4, 1, 0), Text = "⭐ FAVORITE", Font = Theme.Font.Display, TextSize = 20, BackgroundColor3 = Theme.Color.Gold, TextColor3 = Color3.fromRGB(40, 28, 6), ZIndex = 41, Parent = row }, function()
		pcall(function()
			AvatarEditorService:PromptSetFavorite(game.PlaceId, Enum.AvatarItemType.Asset, true)
		end)
	end)
	Kit.button({ LayoutOrder = 2, Size = UDim2.new(0.5, -4, 1, 0), Text = "👍 I LIKED IT!", Font = Theme.Font.Display, TextSize = 20, BackgroundColor3 = Color3.fromRGB(70, 190, 110), TextColor3 = Color3.new(1, 1, 1), ZIndex = 41, Parent = row }, function()
		close(true)
	end)
	Kit.button({ LayoutOrder = 6, Size = UDim2.new(0.6, 0, 0, 34), Text = "Maybe later", TextSize = Theme.TextSize.Small, BackgroundColor3 = Theme.Color.ButtonAlt, TextColor3 = Theme.Color.TextDim, ZIndex = 41, Parent = card }, function()
		close(false)
	end)
end

function LikeAsk.Init(gui: ScreenGui)
	build(gui)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or payload.Type ~= "Extracted" or card.Visible then
			return
		end
		local data = ClientState.Data
		if not data or ClientState.Milestone("LikeAskDone") then
			return
		end
		-- Stats arrive with the next DataSync: this bank is one more than what we have.
		local banks = (data.Stats.Extractions or 0) + 1
		for stage = 2, 1, -1 do
			if banks >= ASK_AT[stage] and not ClientState.Milestone("LikeAsk" .. stage) and (stage == 1 or ClientState.Milestone("LikeAsk1")) then
				task.delay(DELAY, function()
					local carrying = player:GetAttribute("CarryingId")
					if not card.Visible and (carrying == nil or carrying == "") then
						show(stage)
					end
				end)
				return
			end
		end
	end)
end

return LikeAsk
