-- "Bring your friends" at the moments people WANT to share, never as a pop-up wall:
-- a Legendary+ find, an Epic+ bank (and your very first bank), a server event starting, a
-- secret found. A small card slides in with one button that opens Roblox's own invite
-- dialog. Friends in the server already pay +10% income each (Monetization.Free), so the
-- card says so. Throttled hard: a few minutes apart, a few per session, and not at all once
-- you already have a full friend bonus or can't send invites.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Monetization = require(Shared.Config.Monetization)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)

local Invites = {}

local player = Players.LocalPlayer
local COOLDOWN = 360 -- seconds between cards
local MAX_PER_SESSION = 3
local SHOW_FOR = 9

local canInvite = false
local lastShown = -math.huge
local shownCount = 0
local card: Frame
local headline: TextLabel

local function friendBonusFull(): boolean
	local free = Monetization.Free
	local friends = tonumber(player:GetAttribute("FriendsInServer")) or 0
	return friends * free.FriendIncomeBonus >= free.FriendIncomeMax - 1e-6
end

-- The card is anchored on its right edge, so "off screen" means a whole card-width past it.
local HIDDEN = UDim2.new(1, 320, 0.36, 0)
local hideToken = 0

local function hide()
	hideToken += 1
	local token = hideToken
	lastShown = os.clock() -- also cancels a pending auto-hide
	Kit.tween(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = HIDDEN })
	task.delay(0.26, function()
		if token == hideToken then
			card.Visible = false
		end
	end)
end

local function offer(reason: string, delaySeconds: number?)
	if not canInvite or shownCount >= MAX_PER_SESSION or os.clock() - lastShown < COOLDOWN or friendBonusFull() then
		return
	end
	lastShown = os.clock()
	shownCount += 1
	task.delay(delaySeconds or 1.5, function()
		hideToken += 1 -- a new card wins over a hide still finishing
		headline.Text = reason
		card.Position = HIDDEN
		card.Visible = true
		Kit.tween(card, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Position = UDim2.new(1, -12, 0.36, 0) })
		Sounds.Play("Swipe")
		local shownAt = lastShown
		task.delay(SHOW_FOR, function()
			if lastShown == shownAt then
				hide()
			end
		end)
	end)
end

local function build(gui: ScreenGui)
	card = Kit.panel({
		Name = "InviteCard",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = HIDDEN,
		Size = UDim2.fromOffset(270, 96),
		Visible = false,
		ZIndex = 30,
		Parent = gui,
	})
	Kit.stroke(Color3.fromRGB(90, 200, 255), 2.5, 0.05).Parent = card
	headline = Kit.label({
		Text = "",
		Position = UDim2.fromOffset(12, 8),
		Size = UDim2.new(1, -40, 0, 20),
		Font = Theme.Font.Display,
		TextSize = 18,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
		Parent = card,
	})
	Kit.label({
		Text = ("Play together: +%d%% income per friend here"):format(math.floor(Monetization.Free.FriendIncomeBonus * 100 + 0.5)),
		Position = UDim2.fromOffset(12, 28),
		Size = UDim2.new(1, -24, 0, 16),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Tiny,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 31,
		Parent = card,
	})
	Kit.button({
		Position = UDim2.fromOffset(12, 50),
		Size = UDim2.new(1, -24, 0, 38),
		Text = "📨 INVITE FRIENDS",
		Font = Theme.Font.Display,
		TextSize = 18,
		BackgroundColor3 = Color3.fromRGB(60, 160, 255),
		TextColor3 = Color3.new(1, 1, 1),
		ZIndex = 31,
		Parent = card,
	}, function()
		hide()
		pcall(function()
			SocialService:PromptGameInvite(player)
		end)
	end)
	Kit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -6, 0, 6),
		Size = UDim2.fromOffset(24, 24),
		Text = "X",
		Font = Theme.Font.Black,
		TextSize = 14,
		BackgroundColor3 = Theme.Color.ButtonAlt,
		ZIndex = 32,
		Parent = card,
	}, hide)
end

local function rank(treasureId): number
	local def = Treasures.Get(treasureId)
	return if def then Rarities.Rank(def.Rarity) else 0
end

function Invites.Init(gui: ScreenGui)
	build(gui)
	task.spawn(function()
		local ok, result = pcall(function()
			return SocialService:CanSendGameInviteAsync(player)
		end)
		canInvite = ok and result == true
	end)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "PickedUp" and rank(payload.TreasureId) >= Rarities.Rank("Legendary") then
			offer("🤑 SHOW THEM THIS FIND!", 2.5)
		elseif payload.Type == "Extracted" and (payload.First or rank(payload.TreasureId) >= Rarities.Rank("Epic")) then
			offer(if payload.First then "🎉 YOUR FIRST BANK!" else "💰 BIG BANK!", if payload.First then 7 else 3)
		elseif payload.Type == "EventStarted" then
			offer("🎉 EVENT ON - BRING FRIENDS!", 1)
		elseif payload.Type == "SecretFound" then
			offer("🔍 SECRET FOUND - SHOW THEM!", 3)
		end
	end)
end

return Invites
