-- Vault menu: what each pedestal earns, total income, SELL (tap twice to confirm) and UPGRADE.
-- Treasures land on free pedestals automatically when extracted; selling frees one up for a
-- better earner.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Mutations = require(Shared.Config.Mutations)
local Economy = require(Shared.Logic.Economy)
local Monetization = require(Shared.Config.Monetization)
local DayNight = require(Shared.Logic.DayNight)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Vault = {}

function Vault.Build(root: Frame, controller)
	local confirmSlot: number? = nil
	local latest = nil

	local header = Kit.label({ Size = UDim2.new(1, -380, 0, 22), Font = Theme.Font.Black, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.Cash, TextXAlignment = Enum.TextXAlignment.Left, RichText = true, Parent = root })
	local sub = Kit.label({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, -380, 0, 18), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
	local upgrade = Kit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.fromOffset(250, 40),
		TextSize = Theme.TextSize.Small,
		Text = "UPGRADE",
		Parent = root,
	}, function()
		Net.Get("UpgradeVault"):FireServer()
	end)

	-- Soft upsell where income matters: hidden once owned (or before the pass exists).
	local doubleCash = Kit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -258, 0, 0),
		Size = UDim2.fromOffset(112, 40),
		TextSize = Theme.TextSize.Small,
		Text = "💰 2x CASH",
		BackgroundColor3 = Theme.Color.Gold,
		TextColor3 = Color3.fromRGB(40, 28, 6),
		Parent = root,
	}, function()
		if controller then
			controller.Open("Store")
		end
	end)
	local function refreshUpsell()
		doubleCash.Visible = Monetization.Passes.DoubleCash.Id ~= 0
			and game:GetService("Players").LocalPlayer:GetAttribute("Pass_DoubleCash") ~= true
	end
	refreshUpsell()
	game:GetService("Players").LocalPlayer:GetAttributeChangedSignal("Pass_DoubleCash"):Connect(refreshUpsell)

	local grid = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, {
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(168, 124), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Kit.padding(4),
	})

	local refresh

	local function card(slot: number, value: string?, incomeMultiplier: number)
		local id, mutation = Economy.DecodeSlot(value)
		local def = id and Treasures.Get(id)
		local frame = Kit.panel({ LayoutOrder = slot, BackgroundColor3 = Theme.Color.PanelLight, Parent = grid }, { Kit.padding(6) })
		if not def then
			Kit.label({ Text = ("PEDESTAL %d"):format(slot), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, Parent = frame })
			Kit.label({ Text = "EMPTY\nExtract a treasure to fill it", Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 50), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Small, TextColor3 = Theme.Color.TextDim, Parent = frame })
			return
		end
		local info = Rarities.Info[def.Rarity]
		local mutationInfo = Mutations.Get(mutation)
		Kit.stroke(info.Color, 2, 0.2).Parent = frame
		Kit.label({
			Text = if mutationInfo then mutation :: string else " ",
			Size = UDim2.new(1, 0, 0, 14),
			Font = Theme.Font.Black,
			TextSize = Theme.TextSize.Tiny,
			TextColor3 = if mutationInfo then Mutations.Color(mutationInfo.Color) else Theme.Color.TextDim,
			Parent = frame,
		})
		Kit.label({ Text = def.Name, Position = UDim2.fromOffset(0, 14), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Font.Display, TextSize = 16, TextScaled = true, Parent = frame })
		Kit.label({ Text = def.Rarity, Position = UDim2.fromOffset(0, 34), Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Small, TextColor3 = info.Color, Parent = frame })
		local income = math.floor(Economy.Income(def, mutation) * incomeMultiplier + 0.5)
		Kit.label({ Text = ("%s/s"):format(Kit.shortCash(income)), Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 18), Font = Theme.Font.Display, TextSize = 17, TextColor3 = Theme.Color.Cash, Parent = frame })
		local price = Economy.SellPrice(def, mutation)
		local confirming = confirmSlot == slot
		Kit.button({
			AnchorPoint = Vector2.new(0.5, 1),
			Position = UDim2.fromScale(0.5, 1),
			Size = UDim2.new(1, 0, 0, 34),
			Text = if confirming then "CONFIRM SELL?" else ("SELL %s"):format(Kit.shortCash(price)),
			TextSize = Theme.TextSize.Small,
			BackgroundColor3 = if confirming then Theme.Color.Danger else Theme.Color.ButtonAlt,
			TextColor3 = Theme.Color.Text,
			Parent = frame,
		}, function()
			if confirmSlot == slot then
				confirmSlot = nil
				Net.Get("SellTreasure"):FireServer(slot)
			else
				confirmSlot = slot
				task.delay(3, function()
					if confirmSlot == slot then
						confirmSlot = nil
						if latest then
							refresh(latest)
						end
					end
				end)
			end
			refresh(latest)
		end)
	end

	refresh = function(data)
		latest = data
		local tier = GameConfig.Vault.Tiers[data.Vault.Tier] or GameConfig.Vault.Tiers[1]
		local nextTier = GameConfig.Vault.Tiers[data.Vault.Tier + 1]
		local used = 0
		for _ in data.Vault.Displays do
			used += 1
		end
		local isNight = DayNight.IsNight(workspace:GetServerTimeNow())
		local boost = game:GetService("Players").LocalPlayer:GetAttribute("IncomeBoost")
		local incomeMultiplier = Economy.IncomeMultiplier(data, Treasures.List, GameConfig.GetAscensionMultiplier(data.Ascension), if type(boost) == "number" then boost else 1)
		local income = Economy.VaultIncome(data.Vault.Displays, Treasures.Get, incomeMultiplier, isNight)
		header.Text = ("EARNING %s/s%s"):format(Kit.shortCash(income), if isNight then '  <font color="#96aaff">🌙 NIGHT x3</font>' else "")
		sub.Text = ("%d / %d PEDESTALS  •  COLLECT CASH ON THE GREEN PAD IN YOUR VAULT"):format(used, tier.Slots)
		if nextTier and nextTier.Enabled then
			upgrade.Text = ("UPGRADE TO %d  •  %s"):format(nextTier.Slots, Kit.shortCash(nextTier.Price))
			upgrade.BackgroundColor3 = if data.Cash >= nextTier.Price then Theme.Color.Button else Theme.Color.Disabled
			upgrade.Visible = true
		else
			upgrade.Visible = false
		end
		for _, child in grid:GetChildren() do
			if child:IsA("GuiObject") then
				child:Destroy()
			end
		end
		for slot = 1, tier.Slots do
			card(slot, data.Vault.Displays[tostring(slot)], incomeMultiplier)
		end
	end

	return { Refresh = refresh }
end

return Vault
