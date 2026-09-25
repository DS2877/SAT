-- Modal menu shell: one menu open at a time, a coloured header band per menu (accent, icon,
-- title, subtitle), refresh on data change.
-- Menus opened from a place in the world (Gadget Shop counter, your Vault terminal, the
-- Ascension altar, the map board by the gate) carry that place as an Anchor and close when you walk away from it: those
-- menus are deliberately NOT available from anywhere on the map.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Net = require(ReplicatedStorage.Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local MenuController = {}

local LEAVE_DISTANCE = 22 -- studs from a world-anchored menu before it closes itself

local MENUS = {
	Collection = {
		Module = script.Parent.Collection,
		Title = "COLLECTION",
		Icon = "📖",
		Subtitle = "Discover every treasure • complete a region for +10% income forever",
		Accent = Color3.fromRGB(80, 150, 255),
	},
	Vault = {
		Module = script.Parent.Vault,
		Title = "YOUR VAULT",
		Icon = "🏆",
		Subtitle = "Sell to free a pedestal • upgrade to grow your gallery",
		Accent = Color3.fromRGB(255, 180, 40),
	},
	Shop = {
		Module = script.Parent.Shop,
		Title = "GADGET SHOP",
		Icon = "🛒",
		Subtitle = "Buy gadgets • equip up to 3 on your action bar",
		Accent = Color3.fromRGB(30, 190, 170),
	},
	Bats = {
		Module = script.Parent.Bats,
		Title = "BAT SHOP",
		Icon = "🏏",
		Subtitle = "Better bats slap people further • from tier 5 you need Ascension",
		Accent = Color3.fromRGB(230, 90, 60),
	},
	Ascension = {
		Module = script.Parent.Ascension,
		Title = "ASCENSION",
		Icon = "✨",
		Subtitle = "Start over stronger - forever",
		Accent = Color3.fromRGB(170, 90, 255),
	},
	Map = {
		Module = script.Parent.Map,
		Title = "ISLAND MAP",
		Icon = "🗺",
		Subtitle = "More danger, rarer loot • check your strength before you go",
		Accent = Color3.fromRGB(70, 170, 120),
	},
	Feedback = {
		Module = script.Parent.Feedback,
		Title = "FEEDBACK",
		Icon = "💬",
		Subtitle = "Tell us what to add or fix • we read every message",
		Accent = Color3.fromRGB(90, 160, 255),
	},
	Store = {
		Module = script.Parent.Store,
		Title = "STORE",
		Icon = "💎",
		Subtitle = "Support the game • nothing here wins fights",
		Accent = Color3.fromRGB(230, 80, 200),
	},
}

local player = Players.LocalPlayer
local overlay: Frame
local window: Frame
local windowScale: UIScale
local windowStroke: UIStroke
local header: Frame
local headerGradient: UIGradient
local footGradient: UIGradient
local iconLabel: TextLabel
local titleLabel: TextLabel
local subtitleLabel: TextLabel
local body: Frame
local current: string? = nil
local anchor: Vector3? = nil
local instances: { [string]: any } = {}

local function darker(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(0, 0, 0), amount)
end

function MenuController.Close()
	current = nil
	anchor = nil
	overlay.Visible = false
end

-- `at`: world position the menu belongs to (it closes when you walk away); nil = anywhere.
function MenuController.Open(name: string, at: Vector3?)
	local entry = MENUS[name]
	if not entry then
		return
	end
	if current == name then
		MenuController.Close()
		return
	end
	for menuName, menu in instances do
		menu.Root.Visible = menuName == name
	end
	local menu = instances[name]
	if not menu then
		local module = require(entry.Module)
		local root = Kit.new("Frame", { Name = name, BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = body })
		menu = module.Build(root, MenuController)
		menu.Root = root
		instances[name] = menu
	end
	current = name
	anchor = at
	iconLabel.Text = entry.Icon
	titleLabel.Text = entry.Title
	subtitleLabel.Text = entry.Subtitle
	header.BackgroundColor3 = entry.Accent
	local bottom = darker(entry.Accent, 0.45)
	headerGradient.Color = ColorSequence.new(entry.Accent, bottom)
	-- The foot covers the last 20 of 70 px: continue the same fade.
	footGradient.Color = ColorSequence.new(entry.Accent:Lerp(bottom, 50 / 70), bottom)
	windowStroke.Color = entry.Accent
	overlay.Visible = true
	windowScale.Scale = 0.88
	Kit.tween(windowScale, Theme.Motion.Pop, { Scale = 1 })
	if ClientState.Data then
		menu.Refresh(ClientState.Data)
	end
end

function MenuController.Init(gui: ScreenGui)
	overlay = Kit.new("Frame", {
		Name = "MenuOverlay",
		BackgroundTransparency = 1, -- no dimmed box behind menus (it only covered the scaled HUD area)
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	-- Tapping outside the window closes the menu.
	local backdrop = Kit.new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = overlay,
	})
	backdrop.Activated:Connect(MenuController.Close)

	window = Kit.new("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.52),
		Size = UDim2.fromScale(0.9, 0.86),
		BackgroundColor3 = Color3.fromRGB(24, 26, 48),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = overlay,
	}, {
		Kit.new("UISizeConstraint", { MaxSize = Vector2.new(920, 640) }),
		Kit.corner(Theme.Radius.Large),
		Kit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(34, 36, 70), Color3.fromRGB(16, 16, 32)),
		}),
	})
	windowStroke = Kit.new("UIStroke", { Thickness = 3, Transparency = 0.05, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = window })
	windowScale = Kit.new("UIScale", { Parent = window })

	-- Header band in the menu's accent colour.
	header = Kit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 70),
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = window,
	}, { Kit.corner(Theme.Radius.Large) })
	headerGradient = Kit.new("UIGradient", { Rotation = 90, Parent = header })
	-- Square off the band's bottom corners.
	local headerFoot = Kit.new("Frame", {
		Position = UDim2.new(0, 0, 1, -20),
		Size = UDim2.new(1, 0, 0, 20),
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 11,
		Parent = header,
	})
	footGradient = Kit.new("UIGradient", { Rotation = 90, Parent = headerFoot })
	local iconDisc = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(50, 50),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.15,
		ZIndex = 12,
		Parent = header,
	}, { Kit.corner(Theme.Radius.Round) })
	iconLabel = Kit.label({ Size = UDim2.fromScale(1, 1), TextSize = 30, ZIndex = 13, Parent = iconDisc })
	titleLabel = Kit.label({
		Position = UDim2.fromOffset(76, 8),
		Size = UDim2.new(1, -150, 0, 34),
		Font = Theme.Font.Display,
		TextSize = 32,
		TextColor3 = Color3.new(1, 1, 1),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = header,
	})
	Kit.textStroke(Color3.fromRGB(30, 20, 40), 2.5).Parent = titleLabel
	subtitleLabel = Kit.label({
		Position = UDim2.fromOffset(78, 42),
		Size = UDim2.new(1, -150, 0, 18),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Color3.fromRGB(255, 250, 240),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = header,
	})
	Kit.textStroke(Color3.fromRGB(30, 20, 40), 1.5).Parent = subtitleLabel
	local close = Kit.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(46, 46),
		Text = "X",
		Font = Theme.Font.Display,
		TextSize = 26,
		BackgroundColor3 = Theme.Color.Danger,
		TextColor3 = Color3.new(1, 1, 1),
		Radius = Theme.Radius.Round,
		ZIndex = 13,
		Parent = header,
	}, MenuController.Close)
	Kit.new("UIStroke", { Color = Color3.new(1, 1, 1), Thickness = 2.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = close })

	body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 82),
		Size = UDim2.new(1, -32, 1, -96),
		ZIndex = 11,
		Parent = window,
	})

	ClientState.DataChanged:Connect(function(data)
		if current and instances[current] then
			instances[current].Refresh(data)
		end
	end)
	Net.Get("OpenMenu").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Menu) == "string" and current ~= payload.Menu then
			MenuController.Open(payload.Menu, if typeof(payload.Anchor) == "Vector3" then payload.Anchor else nil)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if current and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			MenuController.Close()
		end
	end)
	-- World menus close when you walk away from the counter / terminal / altar.
	RunService.Heartbeat:Connect(function()
		if not current or not anchor then
			return
		end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root or (root.Position - (anchor :: Vector3)).Magnitude > LEAVE_DISTANCE then
			MenuController.Close()
		end
	end)
end

return MenuController
