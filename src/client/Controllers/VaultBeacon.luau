-- Local-only marker for the player's own Vault, deliberately subtle: a thin soft light beam
-- that fades out as it rises, plus a small "🏆 YOUR VAULT • 48m" tag. Both fade away as you
-- get close (you can see the Vault itself by then).

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

local GOLD = Color3.fromRGB(255, 205, 90)

local function build(center: Vector3): (Model, TextLabel, { Beam })
	local model = Instance.new("Model")
	model.Name = "MyVaultBeacon"
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CastShadow = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(center)
	anchor.Parent = model
	local bottom = Instance.new("Attachment")
	bottom.Parent = anchor
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 55, 0)
	top.Parent = anchor
	local beam = Instance.new("Beam")
	beam.Attachment0 = bottom
	beam.Attachment1 = top
	beam.Color = ColorSequence.new(GOLD)
	beam.LightEmission = 0.8
	beam.LightInfluence = 0
	beam.FaceCamera = true
	beam.Width0 = 1.1
	beam.Width1 = 0.4
	beam.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	beam.Parent = anchor

	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 22)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 22, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 5000
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = GOLD
	label.TextTransparency = 0.15
	label.TextStrokeTransparency = 0.5
	label.Text = "🏆 YOUR VAULT"
	label.Parent = gui
	gui.Adornee = anchor
	gui.Parent = anchor
	model.Parent = workspace
	return model, label, { beam }
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
	local model, label, beams = build(center)
	beacon = model
	task.spawn(function()
		while beacon == model do
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local distance = (root.Position - center).Magnitude
				-- Gone when you're at home; the beam only really shows from afar.
				label.Visible = distance > 45
				label.Text = ("🏆 YOUR VAULT • %dm"):format(math.floor(distance / 3.5 + 0.5))
				for _, beam in beams do
					beam.Enabled = distance > 30
				end
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
