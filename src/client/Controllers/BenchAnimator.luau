-- Animates EVERY player who is on a bench press (player attribute "Bench" ~= ""), locally on
-- each client: shoulder/elbow motors press up and down and a barbell follows the hands.
-- Every server rep ("BenchRep" attribute) pulls the press toward lockout so the arms hit the
-- top exactly when the Strength pops. Motor C0 edits are visual only and restored when the
-- player gets up. R6 rigs just get the bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local BenchAnimator = {}

type Lifter = {
	Character: Model,
	Motors: { { Motor: Motor6D, Original: CFrame, Kind: string } },
	Bar: Model,
	Phase: number,
}

local lifters: { [Player]: Lifter } = {}
local TIER_COLOR = {}
for _, tier in GameConfig.Training.Benches do
	TIER_COLOR[tier.Id] = Color3.fromRGB(tier.Color[1], tier.Color[2], tier.Color[3])
end

local function makeBar(color: Color3): Model
	local model = Instance.new("Model")
	model.Name = "LocalBarbell"
	local function piece(size: Vector3, partColor: Color3, material: Enum.Material): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Size = size
		p.Color = partColor
		p.Material = material
		p.Parent = model
		return p
	end
	local bar = piece(Vector3.new(7.4, 0.35, 0.35), Color3.fromRGB(205, 205, 215), Enum.Material.Metal)
	bar.Name = "Bar"
	model.PrimaryPart = bar
	for _, name in { "PlateA", "PlateB" } do
		piece(Vector3.new(0.5, 2.2, 2.2), color, Enum.Material.Metal).Name = name
	end
	model.Parent = workspace
	return model
end

local function findMotor(character: Model, partName: string, motorName: string): Motor6D?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	return if motor and motor:IsA("Motor6D") then motor else nil
end

local function start(player: Player)
	local character = player.Character
	if not character or lifters[player] then
		return
	end
	local motors = {}
	for _, spec in {
		{ "RightUpperArm", "RightShoulder", "Shoulder" },
		{ "LeftUpperArm", "LeftShoulder", "Shoulder" },
		{ "RightLowerArm", "RightElbow", "Elbow" },
		{ "LeftLowerArm", "LeftElbow", "Elbow" },
	} do
		local motor = findMotor(character, spec[1], spec[2])
		if motor then
			table.insert(motors, { Motor = motor, Original = motor.C0, Kind = spec[3] })
		end
	end
	local tierId = player:GetAttribute("Bench")
	lifters[player] = {
		Character = character,
		Motors = motors,
		Bar = makeBar(TIER_COLOR[tierId] or Color3.fromRGB(170, 120, 70)),
		Phase = math.random(),
	}
end

local function stop(player: Player)
	local lifter = lifters[player]
	if not lifter then
		return
	end
	lifters[player] = nil
	for _, entry in lifter.Motors do
		if entry.Motor.Parent then
			entry.Motor.C0 = entry.Original
		end
	end
	lifter.Bar:Destroy()
end

local function refresh(player: Player)
	local bench = player:GetAttribute("Bench")
	if type(bench) == "string" and bench ~= "" then
		start(player)
	else
		stop(player)
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Bench"):Connect(function()
		refresh(player)
	end)
	player:GetAttributeChangedSignal("BenchRep"):Connect(function()
		local lifter = lifters[player]
		if lifter then
			-- Lockout is phase 0.5: take most of the way there now, the rest shows as a snappy push.
			local err = ((0.5 - lifter.Phase + 0.5) % 1) - 0.5
			lifter.Phase = (lifter.Phase + err * 0.7) % 1
		end
	end)
	player.CharacterRemoving:Connect(function()
		stop(player)
	end)
	refresh(player)
end

function BenchAnimator.Init()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(stop)

	local period = GameConfig.Training.RepPeriod
	RunService.RenderStepped:Connect(function(dt)
		for player, lifter in lifters do
			if not lifter.Character.Parent then
				stop(player)
				continue
			end
			local boosting = player:GetAttribute("BenchBoost") == true
			lifter.Phase = (lifter.Phase + dt / (if boosting then period / 2 else period)) % 1
			-- 0 = bar at the chest, 1 = arms locked out
			local extend = 0.5 - 0.5 * math.cos(lifter.Phase * math.pi * 2)
			for _, entry in lifter.Motors do
				if entry.Kind == "Shoulder" then
					-- Upper arm swings from along the body (20°) to pointing at the sky (90°).
					entry.Motor.C0 = entry.Original * CFrame.Angles(math.rad(20 + 70 * extend), 0, 0)
				else
					-- Elbow bends 70° at the bottom so the forearms stay vertical.
					entry.Motor.C0 = entry.Original * CFrame.Angles(math.rad(70 * (1 - extend)), 0, 0)
				end
			end
			-- Bar between the hands (falls back to above the chest for R6 / missing hands).
			local right = lifter.Character:FindFirstChild("RightHand") :: BasePart?
			local left = lifter.Character:FindFirstChild("LeftHand") :: BasePart?
			local root = lifter.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local center: Vector3?
			local axis: Vector3?
			if right and left then
				center = (right.Position + left.Position) / 2
				axis = (right.Position - left.Position).Unit
			elseif root then
				center = root.Position + root.CFrame.LookVector * (1.2 + 1.6 * extend)
				axis = root.CFrame.RightVector
			end
			if center and axis then
				local barCf = CFrame.lookAt(center, center + axis) * CFrame.Angles(0, math.rad(90), 0)
				lifter.Bar.PrimaryPart.CFrame = barCf
				local plates = { lifter.Bar:FindFirstChild("PlateA") :: BasePart, lifter.Bar:FindFirstChild("PlateB") :: BasePart }
				plates[1].CFrame = barCf * CFrame.new(3.1, 0, 0)
				plates[2].CFrame = barCf * CFrame.new(-3.1, 0, 0)
			end
		end
	end)
end

return BenchAnimator
