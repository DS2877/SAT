-- Small local life around YOU (decorative, never replicated, cheap):
--   * critters that fit the region: rabbits in the Wilds, crabs on the Coast, frogs in the
--     Marsh and at the Falls, lizards in the Ruins, penguins in Frostpeak. They hop / scuttle
--     around and scatter when you run at them. A handful near you at a time, recycled.
--   * windmill sails and mine wheels turn (tag "Spinner", built by World/Settlements).

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Zones = require(ReplicatedStorage.Shared.Util.Zones)

local Critters = {}

local player = Players.LocalPlayer
local MAX_CRITTERS = 8
local SPAWN_MIN, SPAWN_MAX = 25, 70 -- studs from you
local DESPAWN = 120
local FLEE_DISTANCE = 12
local SPIN_DISTANCE = 260

local folder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include

type Species = {
	Build: () -> Model,
	Hop: number, -- studs per move
	Height: number, -- hop arc height (0 = scuttle)
	Duration: number, -- seconds per move
	Waddle: number?, -- side-to-side rock while moving (radians)
}

local function piece(model: Model, props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = model
	return p
end

-- Every critter is built facing -Z around its body at the origin; PivotTo moves it.
local function body(name: string, size: Vector3, color: Color3): (Model, Part)
	local model = Instance.new("Model")
	model.Name = name
	local main = piece(model, { Name = "Body", Shape = Enum.PartType.Ball, Size = size, Color = color, CFrame = CFrame.new(0, size.Y / 2, 0) })
	model.PrimaryPart = main
	return model, main
end

local SPECIES: { [string]: Species } = {
	Rabbit = {
		Build = function()
			local fur = if math.random() < 0.3 then Color3.fromRGB(240, 238, 232) else Color3.fromRGB(150, 116, 84)
			local model, main = body("Rabbit", Vector3.new(1.1, 1, 1.5), fur)
			local head = piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.8, 0.8, 0.8), Color = fur, CFrame = main.CFrame * CFrame.new(0, 0.45, -0.75) })
			for _, x in { -0.18, 0.18 } do
				piece(model, { Size = Vector3.new(0.18, 0.8, 0.1), Color = fur, CFrame = head.CFrame * CFrame.new(x, 0.65, 0.1) * CFrame.Angles(math.rad(-10), 0, math.rad(x * 40)) })
			end
			piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = Color3.new(1, 1, 1), CFrame = main.CFrame * CFrame.new(0, 0.1, 0.75) })
			return model
		end,
		Hop = 2.4,
		Height = 1.1,
		Duration = 0.3,
	},
	Crab = {
		Build = function()
			local red = Color3.fromRGB(220, 80, 50)
			local model, main = body("Crab", Vector3.new(1.4, 0.55, 1), red)
			for _, x in { -0.85, 0.85 } do
				piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.4, 0.5), Color = red, CFrame = main.CFrame * CFrame.new(x, 0.05, -0.55) })
				piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.18, 0.18, 0.18), Color = Color3.new(0, 0, 0), CFrame = main.CFrame * CFrame.new(x * 0.25, 0.35, -0.35) })
			end
			return model
		end,
		Hop = 3,
		Height = 0,
		Duration = 0.5,
	},
	Frog = {
		Build = function()
			local green = Color3.fromRGB(90, 190, 90):Lerp(Color3.fromRGB(150, 220, 60), math.random())
			local model, main = body("Frog", Vector3.new(1, 0.7, 1.1), green)
			for _, x in { -0.28, 0.28 } do
				piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.34, 0.34, 0.34), Color = Color3.fromRGB(250, 240, 120), CFrame = main.CFrame * CFrame.new(x, 0.35, -0.35) })
			end
			return model
		end,
		Hop = 2,
		Height = 1.3,
		Duration = 0.32,
	},
	Lizard = {
		Build = function()
			local tan = Color3.fromRGB(190, 160, 100)
			local model, main = body("Lizard", Vector3.new(0.5, 0.35, 1.6), tan)
			piece(model, { Size = Vector3.new(0.2, 0.18, 1.4), Color = tan, CFrame = main.CFrame * CFrame.new(0, -0.05, 1.4) })
			piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.35, 0.55), Color = tan, CFrame = main.CFrame * CFrame.new(0, 0.02, -0.95) })
			return model
		end,
		Hop = 4,
		Height = 0,
		Duration = 0.35,
	},
	Penguin = {
		Build = function()
			local model, main = body("Penguin", Vector3.new(1, 1.6, 0.9), Color3.fromRGB(30, 32, 40))
			piece(model, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.75, 1.3, 0.5), Color = Color3.fromRGB(245, 245, 245), CFrame = main.CFrame * CFrame.new(0, -0.05, -0.25) })
			piece(model, { Size = Vector3.new(0.2, 0.15, 0.35), Color = Color3.fromRGB(250, 170, 40), CFrame = main.CFrame * CFrame.new(0, 0.45, -0.55) })
			return model
		end,
		Hop = 1.4,
		Height = 0.15,
		Duration = 0.45,
		Waddle = math.rad(12),
	},
}

local BY_AREA = { Wilds = "Rabbit", Coast = "Crab", Marsh = "Frog", Falls = "Frog", Ruins = "Lizard", Frost = "Penguin" }

type Critter = { Model: Model, Species: Species, Position: Vector3, Yaw: number, From: Vector3, To: Vector3, T: number, Moving: boolean, Idle: number }

local critters: { Critter } = {}

local function groundAt(x: number, z: number, fromY: number): Vector3?
	local hit = workspace:Raycast(Vector3.new(x, fromY + 30, z), Vector3.new(0, -90, 0), rayParams)
	if hit and hit.Material ~= Enum.Material.Water then
		return hit.Position
	end
	return nil
end

local function place(critter: Critter, position: Vector3, yaw: number, lift: number, roll: number)
	local main = critter.Model.PrimaryPart
	local half = if main then main.Size.Y / 2 else 0.5
	critter.Model:PivotTo(CFrame.new(position + Vector3.new(0, lift, 0)) * CFrame.Angles(0, yaw, roll) * CFrame.new(0, half, 0))
end

local function spawnNear(center: Vector3)
	local angle = math.random() * math.pi * 2
	local distance = SPAWN_MIN + math.random() * (SPAWN_MAX - SPAWN_MIN)
	local x, z = center.X + math.cos(angle) * distance, center.Z + math.sin(angle) * distance
	local probe = Vector3.new(x, center.Y, z)
	if Zones.InSafeZone(probe) then
		return
	end
	local species = SPECIES[BY_AREA[Zones.AreaId(probe)] or "Rabbit"]
	local ground = groundAt(x, z, center.Y)
	if not ground then
		return
	end
	local model = species.Build()
	model.Parent = folder
	local critter: Critter = { Model = model, Species = species, Position = ground, Yaw = math.random() * 6.28, From = ground, To = ground, T = 0, Moving = false, Idle = math.random() * 2 }
	place(critter, ground, critter.Yaw, 0, 0)
	table.insert(critters, critter)
end

local function startMove(critter: Critter, direction: Vector3, steps: number)
	local target = critter.Position + direction * critter.Species.Hop * steps
	local ground = groundAt(target.X, target.Z, critter.Position.Y)
	if not ground or math.abs(ground.Y - critter.Position.Y) > 3 then
		critter.Idle = 0.5
		return
	end
	critter.From, critter.To, critter.T, critter.Moving = critter.Position, ground, 0, true
	critter.Yaw = math.atan2(-direction.X, -direction.Z)
end

local function update(dt: number, root: BasePart?)
	for i = #critters, 1, -1 do
		local critter = critters[i]
		if not root or (critter.Position - root.Position).Magnitude > DESPAWN then
			critter.Model:Destroy()
			table.remove(critters, i)
			continue
		end
		local species = critter.Species
		if critter.Moving then
			critter.T += dt / species.Duration
			local t = math.min(critter.T, 1)
			local p = critter.From:Lerp(critter.To, t)
			local roll = if species.Waddle then math.sin(t * math.pi * 2) * species.Waddle else 0
			place(critter, p, critter.Yaw, math.sin(t * math.pi) * species.Height, roll)
			if t >= 1 then
				critter.Position, critter.Moving = critter.To, false
				critter.Idle = 0.2 + math.random() * 2.2
			end
		else
			local away = critter.Position - root.Position
			local flat = Vector3.new(away.X, 0, away.Z)
			if flat.Magnitude < FLEE_DISTANCE and flat.Magnitude > 0.1 then
				-- Scatter away from you, quicker.
				local jitter = CFrame.Angles(0, (math.random() - 0.5) * 0.8, 0)
				startMove(critter, jitter:VectorToWorldSpace(flat.Unit), 1.5)
			else
				critter.Idle -= dt
				if critter.Idle <= 0 then
					local a = math.random() * math.pi * 2
					startMove(critter, Vector3.new(math.cos(a), 0, math.sin(a)), 1)
				end
			end
		end
	end
end

-- SPINNERS ------------------------------------------------------------------------------

local spinners: { [Model]: CFrame } = {}

local function addSpinner(inst: Instance)
	local home = inst:GetAttribute("Home")
	if inst:IsA("Model") and typeof(home) == "CFrame" then
		spinners[inst] = home
	end
end

function Critters.Init()
	folder = Instance.new("Folder")
	folder.Name = "LocalCritters"
	folder.Parent = workspace
	rayParams.FilterDescendantsInstances = { workspace.Terrain }

	for _, inst in CollectionService:GetTagged("Spinner") do
		addSpinner(inst)
	end
	CollectionService:GetInstanceAddedSignal("Spinner"):Connect(addSpinner)
	CollectionService:GetInstanceRemovedSignal("Spinner"):Connect(function(inst)
		spinners[inst :: Model] = nil
	end)

	local spawnTimer = 0
	RunService.RenderStepped:Connect(function(dt)
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		update(dt, root)
		spawnTimer -= dt
		if spawnTimer <= 0 then
			spawnTimer = 0.8
			if root and #critters < MAX_CRITTERS then
				spawnNear(root.Position)
			end
		end
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local t = os.clock()
		for model, home in spinners do
			if (home.Position - eye).Magnitude < SPIN_DISTANCE then
				model:PivotTo(home * CFrame.Angles(0, 0, t * (model:GetAttribute("Speed") or 1)))
			end
		end
	end)
end

return Critters
