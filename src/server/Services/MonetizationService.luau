-- Robux + free boosts (catalogue and principles: Config/Monetization).
--   * Game passes: ownership checked on join and on purchase; perks exposed through hooks
--     (VaultService.OfflineTerms / AutoCollect, Training.MultiplierFor) and the player
--     attribute "IncomeBoost" (passes x Premium x friends x group), read by server and client.
--   * Developer products: ProcessReceipt is idempotent (data.Purchases) and saves before it
--     reports PurchaseGranted. Server-wide events are queued until they can run.
--   * Daily streak: granted once per UTC day on join.
-- Attributes for the client: Pass_<Key> (owned), IncomeBoost, TrainingBoostUntil,
-- MonetizationReady (ownership checks done).

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Monetization = require(Shared.Config.Monetization)
local DayNight = require(Shared.Logic.DayNight)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local VaultService = require(script.Parent.VaultService)
local Training = require(script.Parent.Training)
local EventService = require(script.Parent.EventService)
local Analytics = require(script.Parent.Analytics)

local MonetizationService = {}

local owned: { [Player]: { [string]: boolean } } = {}
local inGroup: { [Player]: boolean } = {}
local eventQueue: { { Event: string, Buyer: string } } = {}
local MAX_RECEIPTS = 200 -- remembered receipt ids per player (older ones are pruned)

local function formatCash(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (s:gsub("^,", ""))
end

local function owns(player: Player, key: string): boolean
	local set = owned[player]
	return set ~= nil and set[key] == true
end
MonetizationService.Owns = owns

local function friendsInServer(player: Player): number
	local count = 0
	for _, other in Players:GetPlayers() do
		if other ~= player then
			local ok, isFriend = pcall(function()
				return player:IsFriendsWithAsync(other.UserId)
			end)
			if ok and isFriend then
				count += 1
			end
		end
	end
	return count
end

local function refreshBoost(player: Player)
	if not player.Parent then
		return
	end
	local friends = friendsInServer(player)
	player:SetAttribute("FriendsInServer", friends)
	player:SetAttribute(
		"IncomeBoost",
		Monetization.IncomeMultiplier(owned[player] or {}, player.MembershipType == Enum.MembershipType.Premium, friends, inGroup[player] == true)
	)
end

local function grantPass(player: Player, key: string)
	owned[player] = owned[player] or {}
	owned[player][key] = true
	player:SetAttribute("Pass_" .. key, true)
end

-- Community membership (+10% income). Also re-checked right after the in-game join prompt
-- (RecheckGroup), so joining pays off at once - no rejoin needed.
local function checkGroup(player: Player)
	local groupId = Monetization.Free.GroupId
	if groupId == 0 then
		return
	end
	local ok, member = pcall(function()
		return player:IsInGroupAsync(groupId)
	end)
	if ok then
		inGroup[player] = member == true
	end
	player:SetAttribute("InCommunity", inGroup[player] == true)
end

local lastGroupCheck: { [Player]: number } = {}

local function checkOwnership(player: Player)
	owned[player] = owned[player] or {}
	for key, pass in Monetization.Passes do
		if pass.Id ~= 0 then
			local ok, has = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.Id)
			end)
			if ok and has then
				grantPass(player, key)
			end
		end
	end
	checkGroup(player)
	refreshBoost(player)
	player:SetAttribute("MonetizationReady", true)
end

-- DAILY STREAK --------------------------------------------------------------------------

local function dailyReward(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local today = math.floor(os.time() / 86400)
	local streak, isNew = Monetization.NextStreak(data.Daily.LastDay, data.Daily.Streak, today)
	if not isNew then
		return
	end
	local step = Monetization.Free.Daily[streak]
	local income = VaultService.IncomeOf(data, player, true)
	local amount = Monetization.ScaledCash(income, step.Minutes, step.Minimum)
	if owns(player, "VIP") then
		amount *= Monetization.Passes.VIP.DailyRewardMultiplier
	end
	PlayerData.Update(player, function(d)
		d.Daily.LastDay = today
		d.Daily.Streak = streak
	end)
	PlayerData.AddCash(player, amount)
	Analytics.Economy(player, "Source", amount, data.Cash, "Gameplay", "daily_" .. streak)
	task.delay(6, function()
		if player.Parent then
			Net.Fire("Notify", player, {
				Kind = "Banner",
				Title = if step.Jackpot then ("🎁 DAY %d JACKPOT!"):format(streak) else ("🎁 DAY %d STREAK"):format(streak),
				Text = ("+%s%s  •  come back tomorrow for day %d"):format(
					formatCash(amount),
					if owns(player, "VIP") then " (VIP x2)" else "",
					streak % #Monetization.Free.Daily + 1
				),
				Tone = "Reward",
				Duration = 5,
			})
		end
	end)
end

-- SERVER EVENTS (Treasure Rain / Gold Rush bought for everyone) ----------------------------

local function canStart(eventId: string): boolean
	if EventService.IsActive() then
		return false
	end
	if eventId == "TreasureRain" then
		local state = DayNight.State(workspace:GetServerTimeNow())
		return not state.IsNight and state.SecondsLeft > GameConfig.Events.TreasureRain.Duration + 15
	end
	return true
end

local function runQueue()
	local nextEvent = eventQueue[1]
	if nextEvent and canStart(nextEvent.Event) and EventService.Start(nextEvent.Event) then
		table.remove(eventQueue, 1)
		Net.FireAll("Notify", {
			Kind = "Social",
			Text = ("🎉 %s STARTED A %s FOR EVERYONE!"):format(nextEvent.Buyer:upper(), Monetization.Products[nextEvent.Event].Name:upper()),
			Rarity = "Legendary",
		})
	end
end

-- DEVELOPER PRODUCTS ---------------------------------------------------------------------

local function grantProduct(player: Player, key: string, product): boolean
	local data = PlayerData.Get(player)
	if not data then
		return false
	end
	if product.Kind == "Cash" then
		local amount = Monetization.ScaledCash(VaultService.IncomeOf(data, player, true), product.Minutes, product.Minimum)
		PlayerData.AddCash(player, amount)
		Net.Fire("Notify", player, { Kind = "Banner", Title = product.Icon .. " " .. product.Name:upper(), Text = "+" .. formatCash(amount), Tone = "Reward" })
	elseif product.Kind == "Boost" and product.Boost == "Training" then
		local now = os.time()
		PlayerData.Update(player, function(d)
			d.Boosts.TrainingUntil = math.max(now, d.Boosts.TrainingUntil) + product.Minutes * 60
		end)
		player:SetAttribute("TrainingBoostUntil", data.Boosts.TrainingUntil)
		Net.Fire("Notify", player, { Kind = "Banner", Title = "⚡ STRENGTH SURGE", Text = ("x%d gym gains for %d minutes"):format(product.Multiplier, product.Minutes), Tone = "Reward" })
	elseif product.Kind == "ServerEvent" then
		table.insert(eventQueue, { Event = product.Event, Buyer = player.DisplayName })
		Net.FireAll("Notify", {
			Kind = "Banner",
			Title = ("%s %s!"):format(product.Icon, product.Name:upper()),
			Text = if canStart(product.Event) and #eventQueue == 1
				then ("%s bought it for the whole server!"):format(player.DisplayName)
				else ("%s bought it for the whole server - starting soon!"):format(player.DisplayName),
			Tone = "Reward",
		})
		task.defer(runQueue)
	else
		return false
	end
	Analytics.Event(player, "ProductGranted", { Product = key })
	return true
end

local function processReceipt(receipt)
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local data = player and PlayerData.Get(player)
	if not player or not data then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- Roblox retries when they're back
	end
	local receiptId = tostring(receipt.PurchaseId)
	if data.Purchases[receiptId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted -- already granted earlier
	end
	local key, product = Monetization.ProductById(receipt.ProductId)
	if not key or not product then
		warn("[Monetization] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local ok, granted = pcall(grantProduct, player, key, product)
	if not ok or not granted then
		warn("[Monetization] grant failed", key, granted)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	PlayerData.Update(player, function(d)
		d.Purchases[receiptId] = os.time()
		-- Keep the receipt log bounded: drop the oldest entries.
		local ids = {}
		for id in d.Purchases do
			table.insert(ids, id)
		end
		if #ids > MAX_RECEIPTS then
			table.sort(ids, function(a, b)
				return d.Purchases[a] < d.Purchases[b]
			end)
			for i = 1, #ids - MAX_RECEIPTS do
				d.Purchases[ids[i]] = nil
			end
		end
	end)
	PlayerData.SaveNow(player)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

local function onRecheckGroup(player: Player)
	if os.clock() - (lastGroupCheck[player] or 0) < 5 then
		return
	end
	lastGroupCheck[player] = os.clock()
	local was = inGroup[player] == true
	checkGroup(player)
	refreshBoost(player)
	if not was and inGroup[player] then
		Net.Fire("Notify", player, { Kind = "Banner", Title = "👥 WELCOME TO THE CREW!", Text = "+10% income for as long as you're in the community", Tone = "Reward" })
	end
end

function MonetizationService.Init()
	Net.On("RecheckGroup", onRecheckGroup, 1)
	-- Perk hooks.
	VaultService.OfflineTerms = function(player: Player)
		if owns(player, "OfflineVault") then
			local pass = Monetization.Passes.OfflineVault
			return pass.OfflineRate, pass.OfflineMaxHours
		end
		return GameConfig.Economy.OfflineIncomeRate, GameConfig.Economy.OfflineMaxHours
	end
	-- Pass owners can switch it off (the collect pad is half the fun). Note: the experience's
	-- creator owns every pass automatically.
	VaultService.AutoCollect = function(player: Player)
		local data = PlayerData.Get(player)
		return owns(player, "AutoCollect") and data ~= nil and data.Settings.AutoCollect ~= false
	end
	Training.MultiplierFor = function(player: Player)
		local multiplier = if owns(player, "DoubleStrength") then Monetization.Passes.DoubleStrength.TrainingMultiplier else 1
		local data = PlayerData.Get(player)
		if data and data.Boosts.TrainingUntil > os.time() then
			multiplier *= Monetization.Products.StrengthSurge.Multiplier
		end
		return multiplier
	end

	MarketplaceService.ProcessReceipt = processReceipt
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased then
			return
		end
		local key, pass = Monetization.PassById(passId)
		if key and pass then
			grantPass(player, key)
			refreshBoost(player)
			Net.Fire("Notify", player, { Kind = "Banner", Title = pass.Icon .. " " .. pass.Name:upper() .. " UNLOCKED!", Text = pass.Description, Tone = "Reward", Duration = 5 })
			Net.FireAll("Notify", { Kind = "Social", Text = ("%s GOT %s %s"):format(player.DisplayName:upper(), pass.Icon, pass.Name:upper()) })
			Analytics.Event(player, "PassBought", { Pass = key })
		end
	end)

	PlayerData.Loaded:Connect(function(player)
		task.spawn(checkOwnership, player)
		local data = PlayerData.Get(player)
		if data then
			player:SetAttribute("TrainingBoostUntil", data.Boosts.TrainingUntil)
		end
		task.delay(4, dailyReward, player)
		-- Friends boost changes for everyone already here.
		for _, other in Players:GetPlayers() do
			if other ~= player then
				task.spawn(refreshBoost, other)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		owned[player] = nil
		inGroup[player] = nil
		lastGroupCheck[player] = nil
		for _, other in Players:GetPlayers() do
			if other ~= player then
				task.defer(refreshBoost, other)
			end
		end
	end)
	Players.PlayerMembershipChanged:Connect(refreshBoost)

	task.spawn(function()
		while true do
			task.wait(5)
			local ok, err = pcall(runQueue)
			if not ok then
				warn("[Monetization] event queue:", err)
			end
		end
	end)
end

return MonetizationService
