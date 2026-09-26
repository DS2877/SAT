-- Codes typed on the Info Board (Config/Codes, Menus/News CODES tab).
--   DevBoost (admins, testing): Ascension 3 and "max" Strength.
--   Reset (admins, testing): the save goes back to a brand-new account (purchase receipts are
--     kept so paid products can never be granted twice); the character respawns fresh.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Codes = require(Shared.Config.Codes)
local GameConfig = require(Shared.Config.GameConfig)
local DataSchema = require(Shared.Logic.DataSchema)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local EventService = require(script.Parent.EventService)
local VaultService = require(script.Parent.VaultService)
local BatService = require(script.Parent.BatService)
local Analytics = require(script.Parent.Analytics)

local CodeService = {}

local function toast(player: Player, text: string, tone: string)
	Net.Fire("Notify", player, { Kind = "Toast", Text = text, Tone = tone })
end

local function devStrength(): number
	local top = 0
	for _, region in GameConfig.Regions do
		top = math.max(top, region.RecommendedStrength)
	end
	return top * Codes.DevStrengthFactor
end

local ACTIONS = {}

function ACTIONS.DevBoost(player: Player)
	local strength = devStrength()
	PlayerData.Update(player, function(d)
		d.Ascension = math.max(d.Ascension, Codes.DevAscension)
		d.Strength = math.max(d.Strength, strength)
	end)
	VaultService.Render(player) -- the Ascension income multiplier changed
	Net.Fire("Notify", player, { Kind = "Banner", Title = "🛠 DEV BOOST", Text = ("Ascension %d • %s Strength"):format(Codes.DevAscension, tostring(strength)), Tone = "Reward" })
	return true
end

function ACTIONS.Reset(player: Player)
	PlayerData.Update(player, function(d)
		local receipts = d.Purchases
		local fresh = DataSchema.Default()
		for key in d do
			d[key] = nil
		end
		for key, value in fresh do
			d[key] = value
		end
		d.Purchases = receipts or {}
	end)
	PlayerData.SaveNow(player)
	VaultService.Render(player)
	pcall(player.LoadCharacterAsync, player) -- respawn fresh (the bat comes back as the starter)
	task.delay(1, function()
		BatService.Refresh(player)
	end)
	Net.Fire("Notify", player, { Kind = "Banner", Title = "🧹 ACCOUNT RESET", Text = "You're a brand-new heister again", Tone = "Info" })
	return true
end

function ACTIONS.Cash(player: Player, entry)
	local amount = tonumber(entry.Amount) or 0
	PlayerData.AddCash(player, amount)
	toast(player, ("💰 +%s from a code!"):format(tostring(amount)), "Reward")
	return true
end

local lastTry: { [Player]: number } = {}

local function onRedeem(player: Player, text: any)
	if type(text) ~= "string" or #text > 40 then
		return
	end
	-- A small pause between tries stops guessing sprees.
	if os.clock() - (lastTry[player] or 0) < 1.5 then
		return
	end
	lastTry[player] = os.clock()
	local code = string.lower((text:gsub("%s", "")))
	local entry = Codes[code]
	local data = PlayerData.Get(player)
	if type(entry) ~= "table" or not data then
		toast(player, "That code doesn't exist", "Warn")
		return
	end
	if entry.AdminOnly and not EventService.IsAdmin(player) then
		toast(player, "That code doesn't exist", "Warn")
		return
	end
	if entry.Once and data.RedeemedCodes[code] then
		toast(player, "You already used that code", "Warn")
		return
	end
	local action = ACTIONS[entry.Action]
	if action and action(player, entry) then
		if entry.Once then
			PlayerData.Update(player, function(d)
				d.RedeemedCodes[code] = os.time()
			end)
		end
		Analytics.Event(player, "CodeRedeemed", { Code = code })
	end
end

function CodeService.Init()
	Net.On("RedeemCode", onRedeem, 3)
	Players.PlayerRemoving:Connect(function(player)
		lastTry[player] = nil
	end)
end

return CodeService
