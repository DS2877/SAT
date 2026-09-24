-- The island map board by the gate (built by World/MapBoard, tag "WildsMap"): draws the map
-- onto it for THIS player (their strength, their secrets) and opens it full screen from the
-- board's prompt. The full-screen view closes when you walk away (world-anchored menu).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local UI = script.Parent.Parent.UI
local MapView = require(UI.MapView)
local ClientState = require(script.Parent.Parent.ClientState)
local MenuController = require(script.Parent.Parent.Menus.MenuController)

local MapBoard = {}

local player = Players.LocalPlayer
local views = {}

local function attach(board: Instance)
	if not board:IsA("BasePart") then
		return
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name = "IslandMap"
	gui.Adornee = board
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	gui.CanvasSize = Vector2.new(MapView.WIDTH, MapView.HEIGHT)
	gui.LightInfluence = 0
	gui.MaxDistance = 140
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")
	local view = MapView.Build(gui :: any)
	view.Refresh(ClientState.Data)
	table.insert(views, view)
	local prompt = board:FindFirstChild("MapPrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function()
			MenuController.Open("Map", board.Position)
		end)
	end
end

function MapBoard.Init()
	for _, board in CollectionService:GetTagged("WildsMap") do
		task.spawn(attach, board)
	end
	CollectionService:GetInstanceAddedSignal("WildsMap"):Connect(attach)
	ClientState.DataChanged:Connect(function(data)
		for _, view in views do
			view.Refresh(data)
		end
	end)
end

return MapBoard
