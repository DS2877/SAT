-- Gadget shop (opened at the shop counter in the District): BUY -> OWNED -> EQUIP. No upgrade
-- trees. The same list, filtered, is the ASCENSION SHOP (premium gadgets, Ascension-locked):
-- Menus/AscensionShop calls Shop.BuildList(root, true).

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gadgets = require(Shared.Config.Gadgets)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Shop = {}

function Shop.BuildList(root: Frame, premium: boolean)
	local scroller = Kit.new("ScrollingFrame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 10), Kit.padding(4) })

	local rows = {}
	for index, def in Gadgets.List do
		if (def.AscensionShop == true) ~= premium then
			continue
		end
		local row = Kit.panel({
			LayoutOrder = if def.Implemented then index else 100 + index,
			Size = UDim2.new(1, -8, 0, 96),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = scroller,
		})
		-- Role colour: blue = escape tools (usable while carrying), orange = chaser tools.
		local roleColor = if def.CanUseWhileCarrying then Color3.fromRGB(70, 170, 255) else Color3.fromRGB(255, 140, 60)
		Kit.new("UIGradient", {
			Rotation = 0,
			Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(roleColor, 0.35), Color3.new(1, 1, 1)),
			Parent = row,
		})
		local stroke = row:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = roleColor
			stroke.Transparency = 0.45
			stroke.Thickness = 2
		end
		local badge = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 10, 0.5, 0),
			Size = UDim2.fromOffset(72, 72),
			BackgroundColor3 = roleColor,
			Parent = row,
		}, {
			Kit.corner(Theme.Radius.Round),
			Kit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)) }),
		})
		Kit.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2, Transparency = 0.3, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = badge })
		Kit.label({ Text = def.Icon, Size = UDim2.fromScale(1, 1), TextSize = 40, Parent = badge })
		Kit.label({ Text = def.Name:upper(), Position = UDim2.fromOffset(92, 10), Size = UDim2.new(0.5, -92, 0, 26), Font = Theme.Font.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local carryText = if def.CanUseWhileCarrying then "✔ usable while carrying" else "✖ not while carrying"
		Kit.label({
			Text = ("%s  •  %s"):format(def.Role:upper(), carryText),
			Position = UDim2.fromOffset(92, 36),
			Size = UDim2.new(0.6, -92, 0, 18),
			Font = Theme.Font.Black,
			TextSize = Theme.TextSize.Tiny,
			TextColor3 = if def.CanUseWhileCarrying then Theme.Color.Safe else Theme.Color.Warn,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Kit.label({
			Text = if def.Implemented then ("%s  (cooldown %ds)"):format(def.Description, def.Cooldown) else "Coming soon",
			Position = UDim2.fromOffset(92, 56),
			Size = UDim2.new(0.6, -92, 0, 34),
			Font = Theme.Font.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Color.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = row,
		})
		local actions = Kit.new("Frame", {
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.new(0.4, 0, 0, 76),
			BackgroundTransparency = 1,
			Parent = row,
		})
		local price = Kit.label({ Size = UDim2.new(1, 0, 0, 22), Font = Theme.Font.Display, TextSize = 20, TextColor3 = Theme.Color.Cash, TextXAlignment = Enum.TextXAlignment.Right, Parent = actions })
		local buy = Kit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(130, 46),
			Text = "BUY",
			Parent = actions,
		}, function()
			Net.Get("BuyGadget"):FireServer(def.Id)
		end)
		-- One EQUIP / UNEQUIP toggle (6 slots don't fit as buttons on a phone): equips into the
		-- first free slot, or the last slot when all six are full.
		local equipped: number? = nil
		local equipButton = Kit.button({
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(150, 46),
			Text = "EQUIP",
			Visible = false,
			Parent = actions,
		}, function()
			local data = ClientState.Data
			if not data then
				return
			end
			if equipped then
				Net.Get("EquipGadget"):FireServer("", equipped)
				return
			end
			local slot = GameConfig.Gadgets.Slots
			for i = 1, GameConfig.Gadgets.Slots do
				if (data.EquippedGadgets[i] or "") == "" then
					slot = i
					break
				end
			end
			Net.Get("EquipGadget"):FireServer(def.Id, slot)
		end)
		rows[def.Id] = {
			Price = price,
			Buy = buy,
			Equip = equipButton,
			SetEquipped = function(slot: number?)
				equipped = slot
			end,
			Def = def,
		}
	end

	local function refresh(data)
		for id, row in rows do
			local def = row.Def
			local owned = data.OwnedGadgets[id] == true
			local locked = (data.Ascension or 0) < (def.RequiredAscension or 0)
			if not def.Implemented then
				row.Price.Text = "SOON"
				row.Price.TextColor3 = Theme.Color.TextDim
				row.Buy.Visible = false
				row.Equip.Visible = false
			elseif owned then
				local slot = table.find(data.EquippedGadgets, id)
				row.SetEquipped(slot)
				row.Price.Text = if slot then ("OWNED • IN SLOT %d"):format(slot) else "OWNED"
				row.Price.TextColor3 = Theme.Color.Gold
				row.Buy.Visible = false
				row.Equip.Visible = true
				row.Equip.Text = if slot then "UNEQUIP" else "EQUIP"
				row.Equip.BackgroundColor3 = if slot then Theme.Color.ButtonAlt else Theme.Color.Button
				row.Equip.TextColor3 = if slot then Theme.Color.Text else Theme.Color.ButtonText
			elseif locked then
				row.Price.Text = Kit.formatCash(def.Price)
				row.Price.TextColor3 = Theme.Color.TextDim
				row.Buy.Visible = true
				row.Buy.BackgroundColor3 = Theme.Color.Disabled
				row.Buy.TextColor3 = Theme.Color.TextDim
				row.Buy.Text = ("🔒 ASCENSION %d"):format(def.RequiredAscension)
				row.Equip.Visible = false
			else
				local affordable = data.Cash >= def.Price
				row.Price.Text = Kit.formatCash(def.Price)
				row.Price.TextColor3 = if affordable then Theme.Color.Cash else Theme.Color.TextDim
				row.Buy.Visible = true
				row.Buy.BackgroundColor3 = if affordable then Theme.Color.Safe else Theme.Color.Disabled
				row.Buy.TextColor3 = if affordable then Color3.fromRGB(10, 40, 16) else Theme.Color.TextDim
				row.Buy.Text = if affordable then "BUY" else ("NEED %s"):format(Kit.shortCash(def.Price - data.Cash))
				row.Equip.Visible = false
			end
		end
	end

	return { Refresh = refresh }
end

function Shop.Build(root: Frame)
	return Shop.BuildList(root, false)
end

return Shop
