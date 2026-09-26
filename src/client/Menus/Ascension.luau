-- Ascension: start over (Strength, ALL Cash and every gadget) for a permanent multiplier.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local Ascension = {}

function Ascension.Build(root: Frame, controller)
	local column = Kit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = root }, {
		Kit.list(Enum.FillDirection.Vertical, 12, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local level = Kit.label({ LayoutOrder = 1, Size = UDim2.new(1, 0, 0, 30), Font = Theme.Font.Display, TextSize = 28, TextColor3 = Theme.Color.Secret, Parent = column })
	local multiplier = Kit.label({ LayoutOrder = 2, Size = UDim2.new(1, 0, 0, 56), Font = Theme.Font.Display, TextSize = 48, TextColor3 = Theme.Color.Cash, Parent = column })
	local training = Kit.label({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), Font = Theme.Font.Display, TextSize = 24, TextColor3 = Theme.Color.Strength, Parent = column })
	local progress = Kit.label({ LayoutOrder = 4, Size = UDim2.new(1, 0, 0, 26), Font = Theme.Font.Black, TextSize = Theme.TextSize.Heading, Parent = column })
	Kit.label({
		LayoutOrder = 5,
		Size = UDim2.new(0.9, 0, 0, 72),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.TextDim,
		Text = ("⚠ A FRESH START: Strength resets to %s and you LOSE ALL CASH, EVERY GADGET and every Vault treasure except your BEST one (your Heirloom). You keep your Vault size, Collection bonuses, benches and titles - and earn + train faster forever."):format(Kit.bigNumber(GameConfig.Strength.Start)),
		Parent = column,
	})
	-- Destructive: the first tap arms it (shows exactly what you lose), the second ascends.
	local armed = false
	local refresh
	local ascend = Kit.button({ LayoutOrder = 6, Size = UDim2.fromOffset(340, 60), Text = "ASCEND", Font = Theme.Font.Display, TextSize = 26, BackgroundColor3 = Theme.Color.Secret, TextColor3 = Theme.Color.Text }, function()
		local data = ClientState.Data
		local affordable = data and data.Cash >= GameConfig.GetAscensionCost(data.Ascension + 1)
		if not (data and affordable and data.Strength >= GameConfig.GetAscensionRequirement(data.Ascension)) then
			return
		end
		if not armed then
			armed = true
			refresh(data)
			task.delay(4, function()
				if armed then
					armed = false
					if ClientState.Data then
						refresh(ClientState.Data)
					end
				end
			end)
			return
		end
		armed = false
		Net.Get("Ascend"):FireServer()
		controller.Close()
	end)
	ascend.Parent = column

	refresh = function(data)
		local nextLevel = data.Ascension + 1
		local cost = GameConfig.GetAscensionCost(nextLevel)
		local required = GameConfig.GetAscensionRequirement(data.Ascension)
		local strong = data.Strength >= required
		local ready = strong and data.Cash >= cost
		level.Text = ("ASCENSION %d  →  %d"):format(data.Ascension, nextLevel)
		multiplier.Text = ("x%.2f  →  x%.2f CASH"):format(GameConfig.GetAscensionMultiplier(data.Ascension), GameConfig.GetAscensionMultiplier(nextLevel))
		training.Text = ("TRAINING x%.2f  →  x%.2f"):format(
			GameConfig.GetTrainingMultiplier(data.Ascension),
			GameConfig.GetTrainingMultiplier(nextLevel)
		)
		progress.Text = ("STRENGTH %s / %s  •  NEED %s CASH"):format(
			Kit.bigNumber(data.Strength),
			Kit.bigNumber(required),
			Kit.shortCash(cost)
		)
		progress.TextColor3 = if ready then Theme.Color.Safe else Theme.Color.Strength
		ascend.BackgroundColor3 = if ready then Theme.Color.Secret else Theme.Color.Disabled
		ascend.Text = if ready and armed
			then ("TAP AGAIN: LOSE %s + VAULT"):format(Kit.shortCash(data.Cash + (data.Vault.Stored or 0)))
			elseif ready then "ASCEND"
			elseif strong then "NEED MORE CASH"
			else "KEEP TRAINING"
		if ready and armed then
			ascend.BackgroundColor3 = Theme.Color.Danger
		end
	end

	return { Refresh = refresh }
end

return Ascension
