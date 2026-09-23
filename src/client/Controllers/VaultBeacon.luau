-- Local-only beacon over the player's own Vault: a tall gold light beam plus an always-on-top
-- "YOUR VAULT" marker with distance, so home is easy to find from anywhere on the island.

local Players = game:GetService("Players")

local VaultBeacon = {}

local player = Players.LocalPlayer
local beacon: Model? = nil

local function clear()
	if beacon then
		beacon:Destroy()
		beacon = nil
	end
end

local function build(center: Vector3): (Model, TextLabel)
	local model = Instance.new("Model")
	model.Name = "MyVaultBeacon"
	local beam = Instance.new("Part")
	beam.Name = "Beam"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(255, 200, 60)
	beam.Transparency = 0.55
	beam.Size = Vector3.new(90, 1.4, 1.4)
	beam.CFrame = CFrame.new(center + Vector3.new(0, 45, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = model

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 40)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 48, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 5000
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 210, 80)
	label.TextStrokeTransparency = 0.2
	label.Text = "🏆 YOUR VAULT"
	label.Parent = gui
	gui.Adornee = beam
	gui.Parent = beam
	model.Parent = workspace
	return model, label
end

local function refresh()
	clear()
	local index = player:GetAttribute("VaultPlot")
	if type(index) ~= "number" then
		return
	end
	local world = workspace:WaitForChild("World", 30)
	local district = world and world:WaitForChild("TreasureDistrict", 10)
	local vaults = district and district:WaitForChild("Vaults", 10)
	local plot = vaults and vaults:WaitForChild("Vault" .. index, 10)
	local center = plot and plot:GetAttribute("VaultCenter")
	if typeof(center) ~= "Vector3" then
		return
	end
	local model, label = build(center)
	beacon = model
	task.spawn(function()
		while beacon == model do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local distance = (root.Position - center).Magnitude
				-- Fade the marker out once you are standing at home.
				label.Visible = distance > 30
				label.Text = ("🏆 YOUR VAULT • %dm"):format(math.floor(distance / 3.5 + 0.5))
			end
			task.wait(0.5)
		end
	end)
end

function VaultBeacon.Init()
	player:GetAttributeChangedSignal("VaultPlot"):Connect(function()
		task.spawn(refresh)
	end)
	task.spawn(refresh)
end

return VaultBeacon
