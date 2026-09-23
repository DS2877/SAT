-- Gadget shop: BUY -> OWNED -> EQUIP to slot 1/2/3. No upgrade trees.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gadgets = require(Shared.Config.Gadgets)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Shop = {}

function Shop.Build(root: Frame)
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
		local row = Kit.panel({
			LayoutOrder = if def.Implemented then index else 100 + index,
			Size = UDim2.new(1, -8, 0, 96),
			BackgroundColor3 = Theme.Color.PanelLight,
			Parent = scroller,
		})
		Kit.label({ Text = def.Icon, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(80, 96), TextSize = 48, Parent = row })
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
		local equipRow = Kit.new("Frame", {
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.fromScale(1, 1),
			Size = UDim2.fromOffset(170, 46),
			BackgroundTransparency = 1,
			Visible = false,
			Parent = actions,
		}, { Kit.list(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right) })
		local slotButtons = {}
		for slot = 1, GameConfig.Gadgets.Slots do
			slotButtons[slot] = Kit.button({
				LayoutOrder = slot,
				Size = UDim2.fromOffset(52, 46),
				Text = tostring(slot),
				BackgroundColor3 = Theme.Color.ButtonAlt,
				TextColor3 = Theme.Color.Text,
				Parent = equipRow,
			}, function()
				Net.Get("EquipGadget"):FireServer(def.Id, slot)
			end)
		end
		rows[def.Id] = { Price = price, Buy = buy, EquipRow = equipRow, Slots = slotButtons, Def = def }
	end

	local function refresh(data)
		for id, row in rows do
			local def = row.Def
			local owned = data.OwnedGadgets[id] == true
			if not def.Implemented then
				row.Price.Text = "SOON"
				row.Price.TextColor3 = Theme.Color.TextDim
				row.Buy.Visible = false
				row.EquipRow.Visible = false
			elseif owned then
				row.Price.Text = "OWNED • EQUIP TO SLOT"
				row.Price.TextColor3 = Theme.Color.Gold
				row.Buy.Visible = false
				row.EquipRow.Visible = true
				for slot, button in row.Slots do
					local equipped = data.EquippedGadgets[slot] == id
					button.BackgroundColor3 = if equipped then Theme.Color.Button else Theme.Color.ButtonAlt
					button.TextColor3 = if equipped then Theme.Color.ButtonText else Theme.Color.Text
				end
			else
				local affordable = data.Cash >= def.Price
				row.Price.Text = Kit.formatCash(def.Price)
				row.Price.TextColor3 = if affordable then Theme.Color.Cash else Theme.Color.Danger
				row.Buy.Visible = true
				row.Buy.BackgroundColor3 = if affordable then Theme.Color.Button else Theme.Color.Disabled
				row.EquipRow.Visible = false
			end
		end
	end

	return { Refresh = refresh }
end

return Shop
