-- Moment-to-moment feel of the core loop (all local presentation):
--   * EXTRACTION DRAMA: players banking an Epic+ treasure ("ExtractingRarity" attribute) get a
--     big "⚠ EXTRACTING" marker everyone can see from far away -> chase moments.
--   * HEAVY CARRY: the heavier the load (lower CarrySpeed), the more the camera sways and the
--     louder the footsteps thud.
--   * REVEALS: when the night wave drops loot, each treasure lands with a short flash column in
--     its rarity colour (not a permanent beam) and rare ones ring out if you're close.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Rarities = require(Shared.Config.Rarities)
local DayNight = require(Shared.Logic.DayNight)

local Sounds = require(script.Parent.Parent.UI.Sounds)

local GameFeel = {}

local player = Players.LocalPlayer

-- EXTRACTION MARKERS ---------------------------------------------------------------------

local markers: { [Player]: BillboardGui } = {}

local function clearMarker(other: Player)
	local gui = markers[other]
	if gui then
		gui:Destroy()
		markers[other] = nil
	end
end

local function refreshMarker(other: Player)
	clearMarker(other)
	local rarity = other:GetAttribute("ExtractingRarity")
	if other == player or type(rarity) ~= "string" or rarity == "" then
		return
	end
	local head = other.Character and other.Character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local info = Rarities.Info[rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "ExtractMarker"
	gui.Size = UDim2.fromOffset(220, 56)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 600
	gui.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = if info then info.Color else Color3.new(1, 1, 1)
	label.Text = ("⚠ EXTRACTING\n%s"):format(rarity:upper())
	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Parent = label
	label.Parent = gui
	gui.Adornee = head
	gui.Parent = head
	markers[other] = gui
	-- Pulse so it catches the eye.
	TweenService:Create(
		label,
		TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ TextTransparency = 0.35 }
	):Play()
end

local function watchPlayer(other: Player)
	other:GetAttributeChangedSignal("ExtractingRarity"):Connect(function()
		refreshMarker(other)
	end)
	other.CharacterRemoving:Connect(function()
		clearMarker(other)
	end)
	refreshMarker(other)
end

-- HEAVY CARRY --------------------------------------------------------------------------------

local stepTimer = 0
local swayTime = 0

local function updateCarry(dt: number)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid:GetAttribute("Shaking") == true then
		return -- a hit/jackpot camera shake owns the offset right now
	end
	local carrying = player:GetAttribute("CarryingId")
	local speed = tonumber(player:GetAttribute("CarrySpeed")) or 1
	-- 0 = light/normal, 1 = crushing load.
	local burden = if type(carrying) == "string" and carrying ~= "" then math.clamp((1 - speed) / 0.7, 0, 1) else 0
	local moving = humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
	if burden <= 0.05 or not moving then
		if humanoid.CameraOffset.Magnitude > 0.001 then
			humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.zero, math.min(1, dt * 8))
		end
		stepTimer = 0
		return
	end
	swayTime += dt * (6 + 4 * speed)
	local target = Vector3.new(math.sin(swayTime) * 0.18 * burden, -math.abs(math.cos(swayTime)) * 0.3 * burden, 0)
	humanoid.CameraOffset = humanoid.CameraOffset:Lerp(target, math.min(1, dt * 10))
	stepTimer += dt
	local interval = 0.32 / math.max(speed, 0.3)
	if stepTimer >= interval then
		stepTimer = 0
		Sounds.Play("HeavyStep", 0.25 + 0.6 * burden, 1 - 0.25 * burden)
	end
end

-- NIGHT WAVE REVEALS -------------------------------------------------------------------------

local function reveal(model: Instance)
	task.wait() -- let attributes and parts replicate
	if not model:IsA("Model") or model:GetAttribute("Falling") then
		return
	end
	local handle = model.PrimaryPart
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not handle or not root then
		return
	end
	local distance = (handle.Position - root.Position).Magnitude
	if distance > 500 then
		return
	end
	local info = Rarities.Info[model:GetAttribute("Rarity") or "Common"]
	local color = if info then info.Color else Color3.new(1, 1, 1)
	local rank = if info then info.Rank else 1
	local height = 30 + rank * 10
	local column = Instance.new("Part")
	column.Name = "RevealFlash"
	column.Anchored = true
	column.CanCollide = false
	column.CanQuery = false
	column.CanTouch = false
	column.CastShadow = false
	column.Shape = Enum.PartType.Cylinder
	column.Material = Enum.Material.Neon
	column.Color = color
	column.Transparency = 0.2
	column.Size = Vector3.new(height, 2.5, 2.5)
	column.CFrame = CFrame.new(handle.Position + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	column.Parent = workspace
	TweenService:Create(column, TweenInfo.new(1.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Transparency = 1,
		Size = Vector3.new(height, 0.2, 0.2),
	}):Play()
	task.delay(1.5, function()
		column:Destroy()
	end)
	if rank >= 3 and distance < 150 then
		Sounds.PlayAt("RareDiscovery", handle.Position)
	end
end

function GameFeel.Init()
	for _, other in Players:GetPlayers() do
		watchPlayer(other)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(clearMarker)

	RunService.RenderStepped:Connect(updateCarry)

	task.spawn(function()
		local folder = workspace:WaitForChild("Treasures", 30)
		if folder then
			folder.ChildAdded:Connect(function(model)
				-- Only the night wave (daytime starter loot and rain have their own moments).
				if DayNight.IsNight(workspace:GetServerTimeNow()) then
					task.spawn(reveal, model)
				end
			end)
		end
	end)
end

return GameFeel
