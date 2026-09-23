-- Premium treasure catalogue. Discovered treasures render in 3D; undiscovered are silhouettes.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Economy = require(Shared.Logic.Economy)
local TreasureVisual = require(Shared.TreasureVisual)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local Collection = {}

local function viewport(def, discovered: boolean): ViewportFrame
	local vp = Kit.new("ViewportFrame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 96),
		Ambient = Color3.fromRGB(200, 200, 200),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
	})
	local model = TreasureVisual.Build(def, CFrame.new())
	if not discovered then
		for _, d in model:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = Color3.fromRGB(20, 22, 30)
				d.Material = Enum.Material.SmoothPlastic
			elseif d:IsA("Light") then
				d:Destroy()
			end
		end
	end
	model.Parent = vp
	local camera = Instance.new("Camera")
	local s = TreasureVisual.Scale(def)
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(Vector3.new(s * 1.6, s * 1.1, -s * 3.2), Vector3.new(0, 0, 0))
	camera.Parent = vp
	vp.CurrentCamera = camera
	return vp
end

function Collection.Build(root: Frame)
	local header = Kit.label({
		Size = UDim2.new(1, 0, 0, 24),
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = root,
	})
	local scroller = Kit.new("ScrollingFrame", {
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		Parent = root,
	}, {
		Kit.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(150, 186),
			CellPadding = UDim2.fromOffset(10, 10),
			SortOrder = Enum.SortOrder.LayoutOrder,
			HorizontalAlignment = Enum.HorizontalAlignment.Center,
		}),
		Kit.padding(4),
	})

	local cards = {}
	local lastKey = ""

	local function refresh(data)
		-- Only rebuild cards whose discovered/count state changed.
		local found, total = 0, 0
		local keyParts = {}
		for _, def in Treasures.List do
			total += 1
			local entry = data.Collection[def.Id]
			if entry and entry.Discovered then
				found += 1
			end
			table.insert(keyParts, entry and entry.Count or 0)
		end
		header.Text = ("DISCOVERED %d / %d  •  Extract a treasure to add it forever"):format(found, total)
		local key = table.concat(keyParts, ",")
		if key == lastKey then
			return
		end
		lastKey = key

		for index, def in Treasures.List do
			local entry = data.Collection[def.Id]
			local discovered = entry ~= nil and entry.Discovered
			local count = entry and entry.Count or 0
			local card = cards[def.Id]
			if card and card.Discovered == discovered and card.Count == count then
				continue
			end
			if card then
				card.Frame:Destroy()
			end
			local info = Rarities.Info[def.Rarity]
			local frame = Kit.panel({
				LayoutOrder = index,
				BackgroundColor3 = Theme.Color.PanelLight,
				Radius = Theme.Radius.Medium,
				Parent = scroller,
			})
			Kit.stroke(info.Color, 2, if discovered then 0.2 else 0.7).Parent = frame
			local vp = viewport(def, discovered)
			vp.Position = UDim2.fromOffset(0, 4)
			vp.Parent = frame
			Kit.label({
				Text = ("%s %s"):format(Rarities.PipString(def.Rarity), def.Rarity:upper()),
				Position = UDim2.fromOffset(0, 100),
				Size = UDim2.new(1, 0, 0, 16),
				Font = Theme.Font.Black,
				TextSize = Theme.TextSize.Tiny,
				TextColor3 = info.Color,
				Parent = frame,
			})
			Kit.label({
				Text = if discovered then def.Name else "???",
				Position = UDim2.fromOffset(6, 116),
				Size = UDim2.new(1, -12, 0, 36),
				Font = Theme.Font.Display,
				TextSize = 17,
				Parent = frame,
			})
			Kit.label({
				Text = if discovered then ("%s/s  •  x%d"):format(Kit.shortCash(Economy.Income(def)), count) else def.SpawnArea:upper(),
				Position = UDim2.fromOffset(0, 154),
				Size = UDim2.new(1, 0, 0, 20),
				Font = Theme.Font.Black,
				TextSize = Theme.TextSize.Small,
				TextColor3 = if discovered then Theme.Color.Cash else Theme.Color.TextDim,
				Parent = frame,
			})
			cards[def.Id] = { Frame = frame, Discovered = discovered, Count = count }
		end
	end

	return { Refresh = refresh }
end

return Collection
