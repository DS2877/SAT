-- Modal menu shell: one menu open at a time, consistent header + close, refresh on data change.

local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local ClientState = require(script.Parent.Parent.ClientState)

local MenuController = {}

local MENUS = {
	Collection = { Module = script.Parent.Collection, Title = "COLLECTION", Icon = "📖" },
	Vault = { Module = script.Parent.Vault, Title = "YOUR VAULT", Icon = "🏆" },
	Shop = { Module = script.Parent.Shop, Title = "GADGET SHOP", Icon = "🛒" },
	Ascension = { Module = script.Parent.Ascension, Title = "ASCENSION", Icon = "✦" },
}

local overlay: Frame
local window: Frame
local titleLabel: TextLabel
local body: Frame
local current: string? = nil
local instances: { [string]: any } = {}

function MenuController.Close()
	current = nil
	overlay.Visible = false
end

function MenuController.Open(name: string)
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
	titleLabel.Text = ("%s  %s"):format(entry.Icon, entry.Title)
	overlay.Visible = true
	Kit.pulse(window)
	if ClientState.Data then
		menu.Refresh(ClientState.Data)
	end
end

function MenuController.Init(gui: ScreenGui)
	overlay = Kit.new("Frame", {
		Name = "MenuOverlay",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 10,
		Parent = gui,
	})
	-- Tapping the dimmed background closes the menu.
	local backdrop = Kit.new("TextButton", {
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 10,
		Parent = overlay,
	})
	backdrop.Activated:Connect(MenuController.Close)

	window = Kit.panel({
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0.9, 0, 0.86, 0),
		BackgroundTransparency = 0.04,
		ZIndex = 11,
		Parent = overlay,
	}, { Kit.new("UISizeConstraint", { MaxSize = Vector2.new(900, 620) }) })
	titleLabel = Kit.label({
		Position = UDim2.fromOffset(20, 10),
		Size = UDim2.new(1, -100, 0, 44),
		Font = Theme.Font.Display,
		TextSize = Theme.TextSize.Title,
		TextColor3 = Theme.Color.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 12,
		Parent = window,
	})
	Kit.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(48, 48),
		Text = "✕",
		BackgroundColor3 = Theme.Color.ButtonAlt,
		TextColor3 = Theme.Color.Text,
		ZIndex = 12,
		Parent = window,
	}, MenuController.Close)
	body = Kit.new("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 64),
		Size = UDim2.new(1, -32, 1, -78),
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
			MenuController.Open(payload.Menu)
		end
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if current and (input.KeyCode == Enum.KeyCode.ButtonB or (not processed and input.KeyCode == Enum.KeyCode.Escape)) then
			MenuController.Close()
		end
	end)
end

return MenuController
