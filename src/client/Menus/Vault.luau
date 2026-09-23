-- Vault editor: pick a pedestal, then pick which collected treasure it displays.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Vault = {}

function Vault.Build(root: Frame)
	local selectedSlot = 1
	local latest = nil

	local header = Kit.label({ Size = UDim2.new(0.6, 0, 0, 24), Font = Theme.Font.Black, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = root })
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

	local slotsFrame = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(0.5, -8, 1, -50),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, {
		Kit.new("UIGridLayout", { CellSize = UDim2.fromOffset(78, 78), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder }),
		Kit.padding(4),
	})
	local pickerTitle = Kit.label({
		Position = UDim2.new(0.5, 8, 0, 50),
		Size = UDim2.new(0.5, -8, 0, 22),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local picker = Kit.new("ScrollingFrame", {
		Position = UDim2.new(0.5, 8, 0, 76),
		Size = UDim2.new(0.5, -8, 1, -76),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, { Kit.list(Enum.FillDirection.Vertical, 6), Kit.padding(4) })

	local refresh

	local function rebuildPicker(data)
		for _, child in picker:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		local displayed = data.Vault.Displays[tostring(selectedSlot)]
		pickerTitle.Text = ("PEDESTAL %d  •  CHOOSE A TREASURE"):format(selectedSlot)
		local usage = {}
		for _, id in data.Vault.Displays do
			usage[id] = (usage[id] or 0) + 1
		end
		local order = 0
		if displayed then
			order += 1
			Kit.button({ LayoutOrder = order, Size = UDim2.new(1, -8, 0, 44), Text = "REMOVE FROM PEDESTAL", TextSize = Theme.TextSize.Small, BackgroundColor3 = Theme.Color.ButtonAlt, TextColor3 = Theme.Color.Text, Parent = picker }, function()
				Net.Get("SetVaultSlot"):FireServer(selectedSlot, "")
			end)
		end
		-- Most valuable first: the Vault is a flex.
		local list = {}
		for _, def in Treasures.List do
			local entry = data.Collection[def.Id]
			if entry and entry.Count > 0 then
				table.insert(list, def)
			end
		end
		table.sort(list, function(a, b)
			return a.Value > b.Value
		end)
		for _, def in list do
			local entry = data.Collection[def.Id]
			local free = entry.Count - (usage[def.Id] or 0)
			local info = Rarities.Info[def.Rarity]
			order += 1
			local button = Kit.button({
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 44),
				Text = ("%s %s  •  %d free"):format(info.Glyph, def.Name, free),
				TextSize = Theme.TextSize.Small,
				Font = Theme.Font.Bold,
				BackgroundColor3 = if free > 0 then Theme.Color.PanelLight else Theme.Color.Disabled,
				TextColor3 = info.Color,
				Parent = picker,
			}, function()
				if free > 0 then
					Net.Get("SetVaultSlot"):FireServer(selectedSlot, def.Id)
				end
			end)
			Kit.stroke(info.Color, 1.5, 0.5).Parent = button
		end
		if #list == 0 then
			order += 1
			Kit.new("TextButton", {
				LayoutOrder = order,
				Size = UDim2.new(1, -8, 0, 60),
				BackgroundTransparency = 1,
				Text = "Extract treasures to show them off here!",
				Font = Theme.Font.Bold,
				TextSize = Theme.TextSize.Body,
				TextColor3 = Theme.Color.TextDim,
				TextWrapped = true,
				Parent = picker,
			})
		end
	end

	refresh = function(data)
		latest = data
		local tier = GameConfig.Vault.Tiers[data.Vault.Tier] or GameConfig.Vault.Tiers[1]
		local nextTier = GameConfig.Vault.Tiers[data.Vault.Tier + 1]
		selectedSlot = math.clamp(selectedSlot, 1, tier.Slots)
		local used = 0
		for _ in data.Vault.Displays do
			used += 1
		end
		header.Text = ("%d / %d PEDESTALS FILLED  •  Visit it in the District!"):format(used, tier.Slots)
		if nextTier and nextTier.Enabled then
			upgrade.Text = ("UPGRADE TO %d  •  %s"):format(nextTier.Slots, Kit.shortCash(nextTier.Price))
			upgrade.BackgroundColor3 = if data.Cash >= nextTier.Price then Theme.Color.Button else Theme.Color.Disabled
			upgrade.Visible = true
		else
			upgrade.Visible = false
		end

		for _, child in slotsFrame:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for slot = 1, tier.Slots do
			local id = data.Vault.Displays[tostring(slot)]
			local def = id and Treasures.Get(id)
			local info = def and Rarities.Info[def.Rarity]
			local button = Kit.button({
				LayoutOrder = slot,
				Text = "",
				BackgroundColor3 = if slot == selectedSlot then Theme.Color.ButtonAlt else Theme.Color.PanelLight,
				Parent = slotsFrame,
			}, function()
				selectedSlot = slot
				refresh(latest)
			end)
			Kit.stroke(if info then info.Color else Theme.Color.PanelStroke, if slot == selectedSlot then 3 else 1.5, if info then 0.1 else 0.7).Parent = button
			Kit.label({ Text = if info then info.Glyph else tostring(slot), Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 6), TextSize = 30, TextColor3 = if info then info.Color else Theme.Color.TextDim, Parent = button })
			Kit.label({ Text = if def then def.Name else "EMPTY", Size = UDim2.new(1, -6, 0, 26), Position = UDim2.new(0, 3, 1, -30), TextSize = 11, Font = Theme.Font.Black, TextColor3 = Theme.Color.Text, Parent = button })
		end
		rebuildPicker(data)
	end

	return { Refresh = refresh }
end

return Vault
