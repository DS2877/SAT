-- Tells the server when the player is AWAY so the Vault drops to the away income rate
-- (GameConfig.Economy.AwayIncomeRate): the app went to the background / the window lost focus,
-- or Roblox reports 2 minutes without input (Player.Idled). Any input brings you back.
-- Honest reporting is the default: a client that never reports "away" just earns as today.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)
local Notifications = require(script.Parent.Notifications)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local Presence = {}

local player = Players.LocalPlayer
local away = false
local awaySince = 0

local function setAway(value: boolean)
	if away == value then
		return
	end
	away = value
	Net.Get("SetAway"):FireServer(value)
	if value then
		awaySince = os.clock()
	elseif os.clock() - awaySince > 30 then
		Notifications.Toast(
			("💤 Welcome back! While away your Vault earned %d%%"):format(math.floor(GameConfig.Economy.AwayIncomeRate * 100 + 0.5)),
			"Info"
		)
	end
end

function Presence.Init()
	UserInputService.WindowFocusReleased:Connect(function()
		setAway(true)
	end)
	UserInputService.WindowFocused:Connect(function()
		setAway(false)
	end)
	player.Idled:Connect(function()
		setAway(true)
	end)
	UserInputService.InputBegan:Connect(function()
		setAway(false)
	end)
	UserInputService.TouchStarted:Connect(function()
		setAway(false)
	end)
end

return Presence
