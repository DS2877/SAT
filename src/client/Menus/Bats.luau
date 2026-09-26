-- Bat Shop (opened at the shop in the District): every bat with a 3D preview, how far it slaps,
-- and BUY -> EQUIP. Tiers 2-4 cost Cash; tiers 5-11 also need an Ascension level.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bats = require(Shared.Config.Bats)
local BatModels = require(Shared.BatModels)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)

local BatsMenu = {}

local MAX_KNOCKBACK = Bats.List[#Bats.List].Knockback

local function preview(parent: Instance, id: string)
	local viewport = Kit.new("ViewportFrame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(92, 92),
		BackgroundColor3 = Color3.fromRGB(28, 30, 44),
		Ambient = Color3.fromRGB(200, 200, 210),
		LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1),
		Parent = parent,
	}, { Kit.corner(Theme.Radius.Round) })
	local tilt = CFrame.Angles(0, 0, math.rad(-45))
	local model = BatModels.Build(id, tilt)
	model.Parent = viewport
	local centre = (tilt * CFrame.new(0, 2.3, 0)).Position
	local camera = Instance.new("Camera")
	camera.FieldOfView = 40
	camera.CFrame = CFrame.lookAt(centre + Vector3.new(0, 0, 8), centre)
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	return viewport
end

function BatsMenu.Build(root: Frame)
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
	for index, bat in Bats.List do
		local color = Bats.Color(bat)
		local row = Kit.panel({ LayoutOrder = index, Size = UDim2.new(1, -8, 0, 108), BackgroundColor3 = Theme.Color.PanelLight, Parent = scroller })
		Kit.new("UIGradient", { Color = ColorSequence.new(Color3.new(1, 1, 1):Lerp(color, 0.3), Color3.new(1, 1, 1)), Parent = row })
		local stroke = row:FindFirstChildOfClass("UIStroke")
		if stroke then
			stroke.Color = color
			stroke.Transparency = 0.4
			stroke.Thickness = 2
		end
		preview(row, bat.Id)
		Kit.label({ Text = ("%s"):format(bat.Name:upper()), Position = UDim2.fromOffset(112, 8), Size = UDim2.new(0.55, -112, 0, 26), Font = Theme.Font.Display, TextSize = 24, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		Kit.label({
			Text = ("TIER %d  •  reach %.1f"):format(bat.Tier, bat.Range),
			Position = UDim2.fromOffset(112, 34),
			Size = UDim2.new(0.55, -112, 0, 16),
			Font = Theme.Font.Black,
			TextSize = Theme.TextSize.Tiny,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		Kit.label({
			Text = bat.Tagline,
			Position = UDim2.fromOffset(112, 52),
			Size = UDim2.new(0.55, -112, 0, 18),
			Font = Theme.Font.Body,
			TextSize = Theme.TextSize.Small,
			TextColor3 = Theme.Color.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		-- How far it slaps, against the best bat in the shop.
		Kit.label({ Text = "SLAP", Position = UDim2.fromOffset(112, 76), Size = UDim2.fromOffset(40, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextXAlignment = Enum.TextXAlignment.Left, Parent = row })
		local bar = Kit.new("Frame", { Position = UDim2.fromOffset(154, 79), Size = UDim2.new(0.55, -160, 0, 10), BackgroundColor3 = Color3.fromRGB(30, 30, 40), Parent = row }, { Kit.corner(UDim.new(0.5, 0)) })
		Kit.new("Frame", { Size = UDim2.fromScale(bat.Knockback / MAX_KNOCKBACK, 1), BackgroundColor3 = color, Parent = bar }, { Kit.corner(UDim.new(0.5, 0)) })
		local actions = Kit.new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.new(0.4, 0, 0, 84), BackgroundTransparency = 1, Parent = row })
		local price = Kit.label({ Size = UDim2.new(1, 0, 0, 22), Font = Theme.Font.Display, TextSize = 20, TextColor3 = Theme.Color.Cash, TextXAlignment = Enum.TextXAlignment.Right, Parent = actions })
		local need = Kit.label({ Position = UDim2.fromOffset(0, 22), Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Secret, TextXAlignment = Enum.TextXAlignment.Right, Parent = actions })
		local state = { Action = "Buy" }
		local button = Kit.button({ AnchorPoint = Vector2.new(1, 1), Position = UDim2.fromScale(1, 1), Size = UDim2.fromOffset(150, 44), Text = "BUY", Parent = actions }, function()
			if state.Action == "Buy" then
				Net.Get("BuyBat"):FireServer(bat.Id)
			elseif state.Action == "Equip" then
				Net.Get("EquipBat"):FireServer(bat.Id)
			end
		end)
		rows[bat.Id] = { Bat = bat, Price = price, Need = need, Button = button, State = state }
	end

	local function refresh(data)
		local equipped = Bats.Equipped(data)
		for _, row in rows do
			local bat = row.Bat
			local problem = Bats.BuyProblem(data, bat)
			local button, state = row.Button, row.State
			if problem == "Owned" then
				row.Price.Text = if bat.Price == 0 then "STARTER" else "OWNED"
				row.Price.TextColor3 = Theme.Color.Gold
				row.Need.Text = ""
				if equipped.Id == bat.Id then
					state.Action = "None"
					button.Text = "IN HAND ✔"
					button.BackgroundColor3 = Theme.Color.ButtonAlt
					button.TextColor3 = Theme.Color.Gold
				else
					state.Action = "Equip"
					button.Text = "EQUIP"
					button.BackgroundColor3 = Theme.Color.Button
					button.TextColor3 = Theme.Color.ButtonText
				end
			else
				row.Price.Text = Kit.formatCash(bat.Price)
				local ascensionOk = (data.Ascension or 0) >= bat.RequiredAscension
				row.Need.Text = if bat.RequiredAscension > 0 then ("%s ASCENSION %d"):format(if ascensionOk then "✔" else "🔒", bat.RequiredAscension) else ""
				row.Need.TextColor3 = if ascensionOk then Theme.Color.Safe else Theme.Color.Secret
				if problem == nil then
					state.Action = "Buy"
					row.Price.TextColor3 = Theme.Color.Cash
					button.Text = "BUY"
					button.BackgroundColor3 = Theme.Color.Safe
					button.TextColor3 = Color3.fromRGB(10, 40, 16)
				else
					state.Action = "None"
					row.Price.TextColor3 = Theme.Color.TextDim
					button.Text = if problem == "Ascension" then ("🔒 ASCENSION %d"):format(bat.RequiredAscension) else ("NEED %s"):format(Kit.shortCash(bat.Price - (data.Cash or 0)))
					button.BackgroundColor3 = Theme.Color.Disabled
					button.TextColor3 = Theme.Color.TextDim
				end
			end
		end
	end

	return { Refresh = refresh }
end

return BatsMenu
