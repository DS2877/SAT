-- Ascension: reset Strength for a permanent Cash multiplier. Everything else is kept.

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
	local progress = Kit.label({ LayoutOrder = 3, Size = UDim2.new(1, 0, 0, 26), Font = Theme.Font.Black, TextSize = Theme.TextSize.Heading, Parent = column })
	Kit.label({
		LayoutOrder = 4,
		Size = UDim2.new(0.9, 0, 0, 44),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.TextDim,
		Text = "Strength resets to 1. You KEEP your Collection, Vault, gadgets and titles.",
		Parent = column,
	})
	local ascend = Kit.button({ LayoutOrder = 5, Size = UDim2.fromOffset(260, 60), Text = "ASCEND", Font = Theme.Font.Display, TextSize = 30, BackgroundColor3 = Theme.Color.Secret, TextColor3 = Theme.Color.Text }, function()
		local data = ClientState.Data
		local affordable = data and data.Cash >= GameConfig.GetAscensionCost(data.Ascension + 1)
		if data and affordable and data.Strength >= GameConfig.Ascension.RequiredStrength then
			Net.Get("Ascend"):FireServer()
			controller.Close()
		end
	end)
	ascend.Parent = column

	local function refresh(data)
		local nextLevel = data.Ascension + 1
		local cost = GameConfig.GetAscensionCost(nextLevel)
		local strong = data.Strength >= GameConfig.Ascension.RequiredStrength
		local ready = strong and data.Cash >= cost
		level.Text = ("ASCENSION %d  →  %d"):format(data.Ascension, nextLevel)
		multiplier.Text = ("x%.2f  →  x%.2f CASH"):format(GameConfig.GetAscensionMultiplier(data.Ascension), GameConfig.GetAscensionMultiplier(nextLevel))
		progress.Text = ("STRENGTH %d / %d  •  COST %s"):format(
			math.floor(data.Strength),
			GameConfig.Ascension.RequiredStrength,
			Kit.formatCash(cost)
		)
		progress.TextColor3 = if ready then Theme.Color.Safe else Theme.Color.Strength
		ascend.BackgroundColor3 = if ready then Theme.Color.Secret else Theme.Color.Disabled
		ascend.Text = if ready then "ASCEND" elseif strong then "NEED MORE CASH" else "KEEP TRAINING"
	end

	return { Refresh = refresh }
end

return Ascension
