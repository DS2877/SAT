-- The island map board just inside the District gate (WorldLayout.MapBoard): a framed board on
-- two posts under a little roof. The map itself is drawn by each client (Controllers/MapBoard)
-- so it can show YOUR strength and secrets; the prompt opens it full screen.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)

local Props = require(script.Parent.Props)

local MapBoard = {}

local part = Props.part
local WOOD = Color3.fromRGB(96, 66, 42)
local GOLD = Color3.fromRGB(255, 200, 60)

function MapBoard.Build(parent: Instance)
	local info = WorldLayout.MapBoard
	local f = Instance.new("Folder")
	f.Name = "MapBoard"
	f.Parent = parent
	local w, h = info.Width, info.Height
	local base = CFrame.lookAt(info.Position, Vector3.new(info.Facing.X, info.Position.Y, info.Facing.Z))
	local centre = base * CFrame.new(0, info.Lift + h / 2, 0)
	for _, x in { -1, 1 } do
		part({ Name = "MapPost", Size = Vector3.new(0.9, info.Lift + h + 2.4, 0.9), CFrame = base * CFrame.new(x * (w / 2 + 0.6), (info.Lift + h + 2.4) / 2, 0.3), Color = WOOD, Material = Enum.Material.Wood, Parent = f })
	end
	part({ Name = "MapBack", Size = Vector3.new(w + 1.2, h + 1.2, 0.5), CFrame = centre * CFrame.new(0, 0, 0.45), Color = WOOD, Material = Enum.Material.WoodPlanks, Parent = f })
	part({ Name = "MapTrim", Size = Vector3.new(w + 1.6, 0.35, 0.7), CFrame = centre * CFrame.new(0, h / 2 + 0.6, 0.3), Color = GOLD, Material = Enum.Material.Metal, Parent = f })
	part({ Name = "MapTrim", Size = Vector3.new(w + 1.6, 0.35, 0.7), CFrame = centre * CFrame.new(0, -h / 2 - 0.6, 0.3), Color = GOLD, Material = Enum.Material.Metal, Parent = f })
	part({ Name = "MapRoof", Size = Vector3.new(w + 3, 0.5, 3), CFrame = centre * CFrame.new(0, h / 2 + 1.8, -0.4) * CFrame.Angles(math.rad(-14), 0, 0), Color = Color3.fromRGB(150, 50, 44), Material = Enum.Material.Slate, Parent = f })
	-- The drawing surface: its Front face shows the client's SurfaceGui.
	local board = part({ Name = "MapSurface", Size = Vector3.new(w, h, 0.2), CFrame = centre, Color = Color3.fromRGB(28, 44, 70), Material = Enum.Material.SmoothPlastic, Parent = f })
	CollectionService:AddTag(board, "WildsMap")
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "MapPrompt"
	prompt.ActionText = "Open Map"
	prompt.ObjectText = "Island Map"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.Parent = board
	return f
end

return MapBoard
