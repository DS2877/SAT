-- Simple, reliable Guardian AI using server-owned Humanoid NPCs (smooth replication).
-- PATROL -> DETECT -> CHASE -> ATTACK -> (KNOCK) -> RETURN. Carriers are preferred targets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Guardians = require(Shared.Config.Guardians)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local Combat = require(script.Parent.Combat)
local TreasureService = require(script.Parent.TreasureService)

local GuardianService = {}

type Guardian = {
	Type: string,
	Def: any,
	Model: Model,
	Root: BasePart,
	Humanoid: Humanoid,
	Home: Vector3,
	PatrolRadius: number,
	State: string, -- "Patrol" | "Chase" | "Return" | "Stunned"
	Target: Player?,
	NextPatrolAt: number,
	LastAttack: number,
	StateUntil: number,
}

local guardians: { Guardian } = {}
local rng = Random.new()
local TICK = 0.2

local function rgb(t)
	return Color3.fromRGB(t[1], t[2], t[3])
end

local function addPart(model: Model, root: BasePart, props)
	local p = Instance.new("Part")
	p.Name = props.Name or "Part"
	p.Shape = props.Shape or Enum.PartType.Block
	p.Size = props.Size
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CFrame = root.CFrame * props.Offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = p
	weld.Parent = p
	p.Parent = model
	return p
end

local function build(typeName: string, def, position: Vector3): (Model, BasePart, Humanoid)
	local model = Instance.new("Model")
	model.Name = def.Name
	local size = Vector3.new(def.Size[1], def.Size[2], def.Size[3])

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = size
	root.Color = rgb(def.BodyColor)
	root.Material = Enum.Material.SmoothPlastic
	root.CFrame = CFrame.new(position + Vector3.new(0, def.HipHeight + size.Y / 2 + 0.5, 0))
	root.Parent = model
	model.PrimaryPart = root

	local body, accent, eye = rgb(def.BodyColor), rgb(def.AccentColor), rgb(def.EyeColor)
	if typeName == "Wolf" then
		addPart(model, root, { Name = "Head", Size = Vector3.new(1.8, 1.7, 1.9), Color = body, Offset = CFrame.new(0, 0.9, -2.6) })
		addPart(model, root, { Size = Vector3.new(1, 0.8, 1.2), Color = accent, Offset = CFrame.new(0, 0.5, -3.8) })
		for _, x in { -0.55, 0.55 } do
			addPart(model, root, { Size = Vector3.new(0.4, 0.8, 0.3), Color = body, Offset = CFrame.new(x, 2.0, -2.4) })
			addPart(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = eye, Material = Enum.Material.Neon, Offset = CFrame.new(x * 0.8, 1.1, -3.55) })
		end
		addPart(model, root, { Size = Vector3.new(0.5, 0.5, 2), Color = accent, Offset = CFrame.new(0, 0.9, 3) * CFrame.Angles(math.rad(30), 0, 0) })
		for _, x in { -0.8, 0.8 } do
			for _, z in { -1.6, 1.6 } do
				addPart(model, root, { Size = Vector3.new(0.5, def.HipHeight + 0.4, 0.5), Color = body, Offset = CFrame.new(x, -size.Y / 2 - def.HipHeight / 2 + 0.2, z) })
			end
		end
	elseif typeName == "Goblin" then
		addPart(model, root, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(2.2, 2.2, 2.2), Color = body, Offset = CFrame.new(0, 2.4, 0) })
		for _, x in { -1.3, 1.3 } do
			addPart(model, root, { Size = Vector3.new(1.2, 0.3, 0.5), Color = body, Offset = CFrame.new(x, 2.6, 0) * CFrame.Angles(0, 0, math.rad(x > 0 and 20 or -20)) })
		end
		for _, x in { -0.45, 0.45 } do
			addPart(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.4, 0.4, 0.4), Color = eye, Material = Enum.Material.Neon, Offset = CFrame.new(x, 2.6, -0.95) })
			addPart(model, root, { Size = Vector3.new(0.7, def.HipHeight + 0.3, 0.7), Color = accent, Offset = CFrame.new(x, -size.Y / 2 - def.HipHeight / 2 + 0.15, 0) })
		end
		addPart(model, root, { Size = Vector3.new(0.4, 3, 0.4), Color = Color3.fromRGB(110, 70, 40), Material = Enum.Material.Wood, Offset = CFrame.new(1.6, 0.4, -0.6) * CFrame.Angles(math.rad(-30), 0, 0) })
	else -- Spider
		addPart(model, root, { Name = "Head", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 1.6, 2), Color = body, Offset = CFrame.new(0, 0, -2.6) })
		addPart(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.new(4.5, 3, 5), Color = accent, Offset = CFrame.new(0, 0.6, 1.6) })
		for i = -1, 1 do
			addPart(model, root, { Shape = Enum.PartType.Ball, Size = Vector3.new(0.35, 0.35, 0.35), Color = eye, Material = Enum.Material.Neon, Offset = CFrame.new(i * 0.4, 0.3, -3.5) })
		end
		for side = -1, 1, 2 do
			for leg = -1.5, 1.5, 1 do
				addPart(model, root, { Size = Vector3.new(3.5, 0.3, 0.3), Color = body, Offset = CFrame.new(side * 2.8, -0.6, leg) * CFrame.Angles(0, 0, math.rad(side * -35)) })
			end
		end
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.BreakJointsOnDeath = false
	humanoid.HipHeight = def.HipHeight
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.WalkSpeed = def.PatrolSpeed
	humanoid.AutoRotate = true
	for _, state in {
		Enum.HumanoidStateType.FallingDown,
		Enum.HumanoidStateType.Ragdoll,
		Enum.HumanoidStateType.Climbing,
		Enum.HumanoidStateType.Swimming,
		Enum.HumanoidStateType.Seated,
		Enum.HumanoidStateType.Dead,
	} do
		humanoid:SetStateEnabled(state, false)
	end
	humanoid.Parent = model

	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(120, 26)
	tag.StudsOffset = Vector3.new(0, size.Y + 2.5, 0)
	tag.MaxDistance = 70
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 90, 90)
	label.TextStrokeTransparency = 0.3
	label.Text = "⚠ " .. def.Name:upper()
	label.Name = "Label"
	label.Parent = tag
	tag.Name = "GuardianTag"
	tag.Parent = root

	model:SetAttribute("GuardianType", typeName)
	return model, root, humanoid
end

local function attractsGuardians(player: Player): boolean
	local record = TreasureService.GetCarrying(player)
	return record ~= nil and record.Def.SpecialEffect == "AttractsGuardians"
end

local function findTarget(g: Guardian): (Player?, BasePart?)
	local best, bestRoot, bestScore = nil, nil, math.huge
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and not player.Character:FindFirstChildOfClass("ForceField") and not Zones.InSafeZone(root.Position) then
			local detect = g.Def.DetectRange * (if attractsGuardians(player) then 2.5 else 1)
			local distance = (root.Position - g.Root.Position).Magnitude
			local fromHome = (root.Position - g.Home).Magnitude
			if distance <= detect and fromHome <= g.Def.LeashRange and not Combat.IsKnocked(player) then
				local score = distance - (if TreasureService.GetCarrying(player) then 30 else 0)
				if score < bestScore then
					best, bestRoot, bestScore = player, root, score
				end
			end
		end
	end
	return best, bestRoot
end

local function setState(g: Guardian, state: string, target: Player?)
	if g.State ~= state or g.Target ~= target then
		if state == "Chase" and target and g.Target ~= target then
			Net.Fire("Feedback", target, { Type = "GuardianAlert", Name = g.Def.Name })
		end
		g.State = state
		g.Target = target
		g.Model:SetAttribute("State", state)
	end
end

local function step(g: Guardian, now: number)
	if not g.Model.Parent then
		return
	end
	if g.State == "Stunned" then
		if now < g.StateUntil then
			g.Humanoid:MoveTo(g.Root.Position)
			return
		end
		setState(g, "Return", nil)
	end
	if g.State == "Return" and now < g.StateUntil then
		g.Humanoid.WalkSpeed = g.Def.PatrolSpeed * 1.4
		g.Humanoid:MoveTo(g.Home)
		return
	end

	local target, targetRoot = findTarget(g)
	if target and targetRoot then
		setState(g, "Chase", target)
		g.Humanoid.WalkSpeed = g.Def.ChaseSpeed
		g.Humanoid:MoveTo(targetRoot.Position)
		local reach = g.Def.AttackRange + g.Root.Size.Z / 2
		if (targetRoot.Position - g.Root.Position).Magnitude <= reach and now - g.LastAttack >= g.Def.AttackCooldown then
			g.LastAttack = now
			local result = Combat.ApplyHit(target, { Guardian = g.Type, Damage = g.Def.Damage, From = g.Root.Position })
			Net.FireAll("Feedback", { Type = "GuardianAttack", Position = g.Root.Position })
			if result == "Knocked" then
				-- Back off so the victim gets a fair chance to reclaim.
				setState(g, "Return", nil)
				g.StateUntil = now + g.Def.RetreatAfterKnock
			end
		end
		return
	end

	local fromHome = (g.Root.Position - g.Home).Magnitude
	if fromHome > g.PatrolRadius + 10 then
		setState(g, "Return", nil)
		g.StateUntil = now + 1
		g.Humanoid.WalkSpeed = g.Def.PatrolSpeed * 1.4
		g.Humanoid:MoveTo(g.Home)
		return
	end
	setState(g, "Patrol", nil)
	g.Humanoid.WalkSpeed = g.Def.PatrolSpeed
	if now >= g.NextPatrolAt then
		g.NextPatrolAt = now + rng:NextNumber(3, 7)
		local angle = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, g.PatrolRadius)
		g.Humanoid:MoveTo(g.Home + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r))
	end
end

local function tryHitGuardian(attacker: Player, attackerRoot: BasePart): boolean
	local look = attackerRoot.CFrame.LookVector
	for _, g in guardians do
		local offset = g.Root.Position - attackerRoot.Position
		local reach = GameConfig.Combat.AttackRange + g.Root.Size.Z / 2
		local flat = Vector3.new(offset.X, 0, offset.Z)
		if offset.Magnitude <= reach and (flat.Magnitude < 0.1 or look:Dot(flat.Unit) >= GameConfig.Combat.AttackArcDot) then
			g.State = "Stunned"
			g.Target = nil
			g.StateUntil = os.clock() + GameConfig.Combat.GuardianStunDuration
			g.Model:SetAttribute("State", "Stunned")
			Net.Fire("Feedback", attacker, { Type = "HitConfirm", Result = "Guardian" })
			return true
		end
	end
	return false
end

function GuardianService.Init(spawns)
	local folder = Instance.new("Folder")
	folder.Name = "Guardians"
	folder.Parent = workspace
	for _, spawnInfo in spawns do
		local def = Guardians[spawnInfo.Type]
		if def then
			local model, root, humanoid = build(spawnInfo.Type, def, spawnInfo.Position)
			model.Parent = folder
			pcall(function()
				root:SetNetworkOwner(nil)
			end)
			table.insert(guardians, {
				Type = spawnInfo.Type,
				Def = def,
				Model = model,
				Root = root,
				Humanoid = humanoid,
				Home = spawnInfo.Position,
				PatrolRadius = spawnInfo.PatrolRadius or 30,
				State = "Patrol",
				Target = nil,
				NextPatrolAt = 0,
				LastAttack = 0,
				StateUntil = 0,
			})
		end
	end
	Combat.TryHitGuardian = tryHitGuardian
end

function GuardianService.Start()
	task.spawn(function()
		while true do
			task.wait(TICK)
			local now = os.clock()
			for _, g in guardians do
				local ok, err = pcall(step, g, now)
				if not ok then
					warn("[Guardian] step error:", err)
				end
			end
		end
	end)
end

return GuardianService
