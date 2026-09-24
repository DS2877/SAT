-- Robux store: passes (one-time), server gifts + boosts + cash packs (repeatable), and a
-- summary of the FREE boosts the player already has (Premium, friends, group, daily streak).
-- Purchases are prompted here; everything is granted and validated by MonetizationService.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Monetization = require(Shared.Config.Monetization)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local Store = {}

local player = Players.LocalPlayer
local ROBUX = "R$"

function Store.Build(root: Frame)
	local scroller = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 8), Kit.padding(4) })

	local order = 0
	local function nextOrder(): number
		order += 1
		return order
	end

	local function heading(text: string, sub: string?)
		Kit.label({
			LayoutOrder = nextOrder(),
			Text = text,
			Size = UDim2.new(1, -8, 0, 26),
			Font = Theme.Font.Display,
			TextSize = 22,
			TextColor3 = Theme.Color.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = scroller,
		})
		if sub then
			Kit.label({
				LayoutOrder = nextOrder(),
				Text = sub,
				Size = UDim2.new(1, -8, 0, 16),
				Font = Theme.Font.Bold,
				TextSize = Theme.TextSize.Tiny,
				TextColor3 = Theme.Color.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = scroller,
			})
		end
	end

	local buttons: { { Button: TextButton, Kind: string, Key: string, Item: any } } = {}

	local function row(kind: string, key: string, item)
		local frame = Kit.panel({ LayoutOrder = nextOrder(), Size = UDim2.new(1, -8, 0, 74), BackgroundColor3 = Theme.Color.PanelLight, Parent = scroller })
		Kit.label({ Text = item.Icon, Position = UDim2.fromOffset(6, 0), Size = UDim2.fromOffset(64, 74), TextSize = 40, Parent = frame })
		Kit.label({ Text = item.Name:upper(), Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -220, 0, 24), Font = Theme.Font.Display, TextSize = 21, TextXAlignment = Enum.TextXAlignment.Left, Parent = frame })
		local description = item.Description
		if kind == "Product" and item.Kind == "Cash" then
			description = ("%d minutes of your Vault income (at least $%s)"):format(item.Minutes, Kit.bigNumber(item.Minimum))
		end
		Kit.label({
			Text = description or "",
			Position = UDim2.fromOffset(74, 32),
			Size = UDim2.new(1, -220, 0, 36),
			Font = Theme.Font.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Color.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = frame,
		})
		local button = Kit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(130, 46),
			Text = ("%s %d"):format(ROBUX, item.Price),
			Font = Theme.Font.Display,
			TextSize = 20,
			BackgroundColor3 = Theme.Color.Cash,
			TextColor3 = Color3.fromRGB(20, 40, 20),
			Parent = frame,
		}, function()
			if item.Id == 0 then
				return
			end
			if kind == "Pass" then
				if player:GetAttribute("Pass_" .. key) then
					return
				end
				MarketplaceService:PromptGamePassPurchase(player, item.Id)
			else
				MarketplaceService:PromptProductPurchase(player, item.Id)
			end
		end)
		table.insert(buttons, { Button = button, Kind = kind, Key = key, Item = item })
	end

	heading("⭐ GAME PASSES", "One purchase, yours forever. Nothing here helps in a fight.")
	for _, key in Monetization.PassOrder do
		row("Pass", key, Monetization.Passes[key])
	end
	heading("🎉 FOR THE WHOLE SERVER", "Everyone gets the loot - you get the shout-out.")
	for _, key in Monetization.ProductOrder do
		local product = Monetization.Products[key]
		if product.Kind == "ServerEvent" then
			row("Product", key, product)
		end
	end
	heading("⚡ BOOSTS & CASH", "Cash packs scale with your income, so they are always worth it.")
	for _, key in Monetization.ProductOrder do
		local product = Monetization.Products[key]
		if product.Kind ~= "ServerEvent" then
			row("Product", key, product)
		end
	end

	heading("🎁 FREE BOOSTS")
	local freeLabel = Kit.label({
		LayoutOrder = nextOrder(),
		Text = "",
		Size = UDim2.new(1, -8, 0, 96),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		RichText = true,
		Parent = scroller,
	})

	local function refresh(data)
		for _, entry in buttons do
			local ownedPass = entry.Kind == "Pass" and player:GetAttribute("Pass_" .. entry.Key) == true
			if entry.Item.Id == 0 then
				entry.Button.Text = "SOON"
				entry.Button.BackgroundColor3 = Theme.Color.Disabled
			elseif ownedPass then
				entry.Button.Text = "OWNED ✔"
				entry.Button.BackgroundColor3 = Theme.Color.ButtonAlt
			else
				entry.Button.Text = ("%s %d"):format(ROBUX, entry.Item.Price)
				entry.Button.BackgroundColor3 = Theme.Color.Cash
			end
		end
		local free = Monetization.Free
		local premium = player.MembershipType == Enum.MembershipType.Premium
		local friends = tonumber(player:GetAttribute("FriendsInServer")) or 0
		local boost = tonumber(player:GetAttribute("IncomeBoost")) or 1
		local lines = {
			("💎 Premium: <b>+%d%%</b> Vault income %s"):format(math.floor((free.PremiumIncomeMultiplier - 1) * 100 + 0.5), if premium then "✔" else "(Roblox Premium members)"),
			("👥 Friends here: <b>%d</b> → +%d%% (max +%d%%) - play with friends!"):format(
				friends,
				math.floor(math.min(free.FriendIncomeMax, friends * free.FriendIncomeBonus) * 100 + 0.5),
				math.floor(free.FriendIncomeMax * 100 + 0.5)
			),
			("🎁 Daily streak: <b>day %d</b> - log in every day, day %d is the jackpot"):format(data and data.Daily and data.Daily.Streak or 0, #free.Daily),
			('💰 Your total income boost: <font color="#78eb78"><b>x%.2f</b></font>'):format(boost),
		}
		freeLabel.Text = table.concat(lines, "\n")
	end

	for _, key in Monetization.PassOrder do
		player:GetAttributeChangedSignal("Pass_" .. key):Connect(function()
			refresh(ClientState.Data)
		end)
	end

	return { Refresh = refresh }
end

return Store
