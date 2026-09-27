-- Gadget ownership, equipping, server-authoritative cooldowns and effects.
-- Adding a gadget = config entry in Shared.Config.Gadgets + an Effects[id] function here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gadgets = require(Shared.Config.Gadgets)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local TreasureVisual = require(Shared.TreasureVisual)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)
local Decoys = require(script.Parent.Decoys)

local GadgetService = {}

local cooldowns: { [Player]: { [string]: number } } = {} -- gadgetId -> server time ready
local trapImmuneUntil: { [Player]: number } = {}
local effectTokens: { [Player]: { [string]: number } } = {}

local function token(player: Player, key: string): number
	effectTokens[player] = effectTokens[player] or {}
	local t = (effectTokens[player][key] or 0) + 1
	effectTokens[player][key] = t
	return t
end

local function tokenValid(player: Player, key: string, t: number): boolean
	return effectTokens[player] ~= nil and effectTokens[player][key] == t
end

local function weldVisual(root: BasePart, part: BasePart, offset: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CFrame = root.CFrame * offset
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = part
	weld.Parent = part
end

local Effects = {}

function Effects.speed_soda(player: Player, def, root: BasePart): boolean
	local t = token(player, "SpeedSoda")
	Movement.SetSpeed(player, "SpeedSoda", def.SpeedMultiplier)
	local trail = Instance.new("Sparkles")
	trail.SparkleColor = Color3.fromRGB(255, 120, 60)
	trail.Name = "SpeedSodaFx"
	trail.Parent = root
	task.delay(def.Duration, function()
		trail:Destroy()
		if tokenValid(player, "SpeedSoda", t) then
			Movement.SetSpeed(player, "SpeedSoda", nil)
		end
	end)
	return true
end

function Effects.balloon(player: Player, def, root: BasePart): boolean
	local character = root.Parent :: Model
	local attachment = Instance.new("Attachment")
	attachment.Name = "BalloonAttachment"
	attachment.Parent = root

	local mass = 0
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") and not p.Massless then
			mass += p:GetMass()
		end
	end
	local lift = Instance.new("LinearVelocity")
	lift.Name = "BalloonLift"
	lift.Attachment0 = attachment
	lift.VelocityConstraintMode = Enum.VelocityConstraintMode.Line
	lift.LineDirection = Vector3.new(0, 1, 0)
	lift.LineVelocity = def.RiseSpeed
	lift.MaxForce = math.max(mass, 10) * workspace.Gravity * 2.5
	lift.RelativeTo = Enum.ActuatorRelativeTo.World
	lift.Parent = root

	local balloon = Instance.new("Part")
	balloon.Name = "BalloonFx"
	balloon.Shape = Enum.PartType.Ball
	balloon.Size = Vector3.new(4, 4.6, 4)
	balloon.Color = Color3.fromRGB(255, 70, 90)
	balloon.Material = Enum.Material.SmoothPlastic
	weldVisual(root, balloon, CFrame.new(1.5, 8, 0))
	balloon.Parent = character
	local rope = Instance.new("Part")
	rope.Name = "BalloonString"
	rope.Size = Vector3.new(0.1, 5, 0.1)
	rope.Color = Color3.new(1, 1, 1)
	weldVisual(root, rope, CFrame.new(0.8, 4, 0) * CFrame.Angles(0, 0, math.rad(-15)))
	rope.Parent = character

	Net.Fire("Feedback", player, { Type = "Balloon" })
	task.delay(def.RiseDuration, function()
		if lift.Parent then
			lift.LineVelocity = def.GlideSpeed
		end
	end)
	task.delay(def.RiseDuration + def.GlideDuration, function()
		lift:Destroy()
		attachment:Destroy()
		balloon:Destroy()
		rope:Destroy()
	end)
	return true
end

function Effects.bubble_blaster(player: Player, def, root: BasePart): boolean
	if Zones.InSafeZone(root.Position) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "No bubbles in the District", Tone = "Warn" })
		return false
	end
	local look = root.CFrame.LookVector
	local target: Player? = nil
	local bestScore = math.huge
	local now = os.clock()
	for _, other in Players:GetPlayers() do
		if other ~= player and not Combat.IsPvPProtected(other) and now >= (trapImmuneUntil[other] or 0) then
			local otherRoot = Combat.RootOf(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= def.Range and distance > 0.1 and look:Dot(offset.Unit) >= def.ArcDot then
					-- Prefer carriers, then the closest.
					local score = distance - (if TreasureService.GetCarrying(other) then 100 else 0)
					if score < bestScore then
						bestScore = score
						target = other
					end
				end
			end
		end
	end
	if not target then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "No target in front of you", Tone = "Warn" })
		return false
	end
	local victim = target :: Player
	local victimRoot = Combat.RootOf(victim) :: BasePart
	trapImmuneUntil[victim] = now + def.TrapDuration + def.TrapImmunity
	local t = token(victim, "Bubble")
	Movement.SetLock(victim, "Bubble", true)

	local bubble = Instance.new("Part")
	bubble.Name = "BubbleFx"
	bubble.Shape = Enum.PartType.Ball
	bubble.Size = Vector3.new(8, 8, 8)
	bubble.Color = Color3.fromRGB(150, 220, 255)
	bubble.Material = Enum.Material.Glass
	bubble.Transparency = 0.55
	weldVisual(victimRoot, bubble, CFrame.new())
	bubble.Parent = victim.Character

	Net.Fire("Feedback", victim, { Type = "Bubbled", Duration = def.TrapDuration, By = player.DisplayName })
	Net.FireAll("Feedback", { Type = "BubbleShot", From = root.Position, To = victimRoot.Position })
	task.delay(def.TrapDuration, function()
		bubble:Destroy()
		if tokenValid(victim, "Bubble", t) then
			Movement.SetLock(victim, "Bubble", false)
		end
	end)
	return true
end

function Effects.grapple_hook(player: Player, def, root: BasePart, aim: Vector3?): boolean
	if not aim then
		return false
	end
	local character = root.Parent :: Model
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Treasures", "Guardians" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local hit = workspace:Raycast(origin, aim * def.Range, params)
	if not hit or (hit.Position - origin).Magnitude < def.MinDistance then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Nothing to hook onto — aim at a cliff or tree", Tone = "Warn" })
		return false
	end
	local target = hit.Position + hit.Normal * 2.5

	local rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "GrappleAttachment"
	rootAttachment.Parent = root
	local anchor = Instance.new("Attachment")
	anchor.Name = "GrappleAnchor"
	anchor.WorldPosition = hit.Position
	anchor.Parent = workspace.Terrain
	local rope = Instance.new("Beam")
	rope.Attachment0 = rootAttachment
	rope.Attachment1 = anchor
	rope.Width0 = 0.25
	rope.Width1 = 0.25
	rope.FaceCamera = true
	rope.Color = ColorSequence.new(Color3.fromRGB(150, 110, 70))
	rope.Parent = anchor

	local carrySpeed = player:GetAttribute("CarrySpeed") or 1
	local speed = def.PullSpeed * math.max(def.CarriedSpeedFloor, carrySpeed)
	local mass = 0
	for _, p in character:GetDescendants() do
		if p:IsA("BasePart") and not p.Massless then
			mass += p:GetMass()
		end
	end
	local pull = Instance.new("LinearVelocity")
	pull.Name = "GrapplePull"
	pull.Attachment0 = rootAttachment
	pull.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	pull.RelativeTo = Enum.ActuatorRelativeTo.World
	pull.MaxForce = math.max(mass, 10) * workspace.Gravity * 8
	pull.VectorVelocity = (target - root.Position).Unit * speed
	pull.Parent = root
	Net.Fire("Feedback", player, { Type = "Grapple" })

	task.spawn(function()
		local started = os.clock()
		while pull.Parent and root.Parent and os.clock() - started < def.MaxDuration do
			local offset = target - root.Position
			if offset.Magnitude <= def.ArriveDistance or Combat.IsKnocked(player) or Movement.IsLocked(player) then
				break
			end
			pull.VectorVelocity = offset.Unit * speed
			task.wait(0.05)
		end
		pull:Destroy()
		anchor:Destroy()
		rootAttachment:Destroy()
		if root.Parent then
			-- Small hop at the end so the player lands on ledges instead of sliding off.
			root.AssemblyLinearVelocity = Vector3.new(0, 22, 0)
		end
	end)
	return true
end

local function cosmeticPart(props): Part
	local p = Instance.new("Part")
	p.Name = props.Name or "Fx"
	p.Shape = props.Shape or Enum.PartType.Ball
	p.Size = props.Size
	p.Color = props.Color
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	return p
end

-- DECOY DUCK: waddles away carrying a convincing fake treasure tag. Guardians chase it; a bonk pops it.
function Effects.decoy_duck(player: Player, def, root: BasePart): boolean
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local model = Instance.new("Model")
	model.Name = "DecoyDuck"
	local body = cosmeticPart({ Name = "Body", Size = Vector3.new(2.6, 2.2, 3.2), Color = Color3.fromRGB(255, 220, 60) })
	body.Anchored = true
	body.Massless = false
	body.CFrame = CFrame.lookAt(root.Position, root.Position + direction)
	body.Parent = model
	model.PrimaryPart = body
	local function attach(part: BasePart, offset: CFrame)
		part.CFrame = body.CFrame * offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = body
		weld.Part1 = part
		weld.Parent = part
		part.Parent = model
	end
	attach(cosmeticPart({ Name = "Head", Size = Vector3.new(1.6, 1.6, 1.6), Color = Color3.fromRGB(255, 220, 60) }), CFrame.new(0, 1.4, -1.2))
	attach(cosmeticPart({ Name = "Beak", Shape = Enum.PartType.Block, Size = Vector3.new(0.8, 0.3, 0.8), Color = Color3.fromRGB(255, 140, 30) }), CFrame.new(0, 1.3, -2.1))
	for _, x in { -0.4, 0.4 } do
		attach(cosmeticPart({ Name = "Eye", Size = Vector3.new(0.3, 0.3, 0.3), Color = Color3.new(0, 0, 0) }), CFrame.new(x, 1.7, -1.9))
	end

	-- The fake: a real-looking Rare/Epic treasure and tag.
	local pool = {}
	for _, t in Treasures.List do
		if t.Rarity == "Rare" or t.Rarity == "Epic" then
			table.insert(pool, t)
		end
	end
	local fake = pool[math.random(1, #pool)]
	local fakeModel = TreasureVisual.Build(fake, body.CFrame * CFrame.new(0, 3.6, 0))
	for _, d in fakeModel:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanQuery = false
			d.Massless = true
		end
	end
	attach(fakeModel.PrimaryPart :: BasePart, (body.CFrame:Inverse() * (fakeModel.PrimaryPart :: BasePart).CFrame))
	for _, d in fakeModel:GetChildren() do
		d.Parent = model
	end
	fakeModel:Destroy()
	local info = Rarities.Info[fake.Rarity]
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(150, 38)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	tag.MaxDistance = 160
	tag.LightInfluence = 0
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = info.Color
	label.TextStrokeTransparency = 0.2
	label.Text = ("%s %s"):format(info.Glyph, fake.Name)
	label.Parent = tag
	tag.Parent = body
	model.Parent = workspace

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = false
	local decoy = { Root = body :: BasePart, Owner = player, Popped = false }
	function decoy.Pop(self, by: Player?)
		if self.Popped then
			return
		end
		self.Popped = true
		Decoys.Remove(self)
		Net.FireAll("Feedback", { Type = "DecoyPopped", Position = body.Position })
		if by then
			Net.Fire("Notify", by, { Kind = "Toast", Text = "🦆 QUACK! IT WAS A DECOY!", Tone = "Warn" })
		end
		model:Destroy()
	end
	Decoys.Add(decoy :: any)

	task.spawn(function()
		local started = os.clock()
		local position = body.Position
		while not decoy.Popped and os.clock() - started < def.Duration do
			local exclude: { Instance } = { model }
			for _, p in Players:GetPlayers() do
				if p.Character then
					table.insert(exclude, p.Character)
				end
			end
			params.FilterDescendantsInstances = exclude
			local nextPosition = position + direction * def.Speed * 0.1
			local ground = workspace:Raycast(nextPosition + Vector3.new(0, 8, 0), Vector3.new(0, -40, 0), params)
			if not ground or ground.Position.Y - position.Y > 5 then
				-- Wall or cliff ahead: waddle off at an angle instead.
				direction = (CFrame.Angles(0, math.rad(math.random(60, 120)) * (if math.random() < 0.5 then 1 else -1), 0) * direction).Unit
			else
				position = ground.Position + Vector3.new(0, 1.2, 0)
				body.CFrame = CFrame.lookAt(position, position + direction)
			end
			task.wait(0.1)
		end
		decoy:Pop(nil)
	end)
	return true
end

-- DISGUISE: become a bush. Hides the carried treasure + name tag until hit, drop, or timeout.
type DisguiseState = { Token: number, Bush: Instance, Hidden: { [BasePart]: number }, Billboard: BillboardGui? }
local disguises: { [Player]: DisguiseState } = {}

local function endDisguise(player: Player)
	local state = disguises[player]
	if not state then
		return
	end
	disguises[player] = nil
	state.Bush:Destroy()
	for part, transparency in state.Hidden do
		if part.Parent then
			part.Transparency = transparency
		end
	end
	if state.Billboard and state.Billboard.Parent then
		state.Billboard.Enabled = true
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	end
	player:SetAttribute("Disguised", false)
end
GadgetService.EndDisguise = endDisguise

function Effects.disguise(player: Player, def, root: BasePart): boolean
	endDisguise(player)
	local character = root.Parent :: Model
	local bush = Instance.new("Model")
	bush.Name = "DisguiseBush"
	for _, info in {
		{ Size = Vector3.new(6.5, 6, 6.5), Offset = CFrame.new(0, -0.3, 0), Color = Color3.fromRGB(70, 160, 70) },
		{ Size = Vector3.new(3.5, 3.5, 3.5), Offset = CFrame.new(1.8, 1.8, 0.6), Color = Color3.fromRGB(45, 120, 60) },
		{ Size = Vector3.new(3, 3, 3), Offset = CFrame.new(-1.6, 1.6, -0.8), Color = Color3.fromRGB(90, 180, 80) },
	} do
		local leaf = cosmeticPart({ Name = "Leaves", Size = info.Size, Color = info.Color, Material = Enum.Material.Grass })
		leaf.CFrame = root.CFrame * info.Offset
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = leaf
		weld.Parent = leaf
		leaf.Parent = bush
	end
	bush.Parent = character

	local state: DisguiseState = { Token = os.clock(), Bush = bush, Hidden = {}, Billboard = nil }
	local record = TreasureService.GetCarrying(player)
	if record then
		for _, d in record.Model:GetDescendants() do
			if d:IsA("BasePart") then
				state.Hidden[d] = d.Transparency
				d.Transparency = 1
			end
		end
		record.Billboard.Enabled = false
		state.Billboard = record.Billboard
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	disguises[player] = state
	player:SetAttribute("Disguised", true)
	local token = state.Token
	task.delay(def.Duration, function()
		local current = disguises[player]
		if current and current.Token == token then
			endDisguise(player)
		end
	end)
	return true
end

local function characterExclusions(): { Instance }
	local exclude: { Instance } = {}
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	for _, name in { "Treasures", "Guardians" } do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(exclude, folder)
		end
	end
	return exclude
end

-- BEE BOX: a swarm zone in front of the thrower. Slows + stings everyone else inside.
function Effects.bee_box(player: Player, def, root: BasePart): boolean
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterExclusions()
	local aimPoint = root.Position + direction * def.ThrowDistance
	local hit = workspace:Raycast(aimPoint + Vector3.new(0, 20, 0), Vector3.new(0, -60, 0), params)
	local center = if hit then hit.Position else aimPoint
	if Zones.InSafeZone(center) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "No bees in the District", Tone = "Warn" })
		return false
	end

	local swarm = cosmeticPart({
		Name = "BeeSwarm",
		Size = Vector3.one * def.Radius * 2,
		Color = Color3.fromRGB(255, 210, 60),
		Material = Enum.Material.ForceField,
	})
	swarm.Anchored = true
	swarm.Transparency = 0.6
	swarm.Position = center
	local hive = cosmeticPart({
		Name = "Hive",
		Size = Vector3.new(2.4, 3, 2.4),
		Color = Color3.fromRGB(230, 170, 40),
		Material = Enum.Material.Wood,
	})
	hive.Anchored = true
	hive.Position = center + Vector3.new(0, 1.5, 0)
	local bees = Instance.new("ParticleEmitter")
	bees.Color = ColorSequence.new(Color3.fromRGB(255, 220, 40), Color3.fromRGB(30, 30, 30))
	bees.Size = NumberSequence.new(0.35)
	bees.Rate = 60
	bees.Lifetime = NumberRange.new(0.8, 1.4)
	bees.Speed = NumberRange.new(4, 9)
	bees.SpreadAngle = Vector2.new(180, 180)
	bees.LightEmission = 0.4
	bees.Parent = hive
	swarm.Parent = workspace
	hive.Parent = swarm
	Net.FireAll("Feedback", { Type = "BeeSwarm", Position = center })

	task.spawn(function()
		local started = os.clock()
		local warned: { [Player]: boolean } = {}
		while os.clock() - started < def.Duration do
			for _, other in Players:GetPlayers() do
				local otherRoot, humanoid = Combat.RootOf(other)
				if
					other ~= player
					and otherRoot
					and humanoid
					and (otherRoot.Position - center).Magnitude <= def.Radius
					and Combat.CanPlayerHit(player, other)
				then
					humanoid:TakeDamage(def.DamagePerTick)
					local t = token(other, "Bees")
					Movement.SetSpeed(other, "Bees", def.SlowMultiplier)
					task.delay(def.TickRate + 0.25, function()
						if tokenValid(other, "Bees", t) then
							Movement.SetSpeed(other, "Bees", nil)
						end
					end)
					if not warned[other] then
						warned[other] = true
						Net.Fire("Feedback", other, { Type = "Stung" })
					end
				end
			end
			task.wait(def.TickRate)
		end
		swarm:Destroy()
	end)
	return true
end

-- BOOMERANG: ranged bonk along the camera aim. Counts as a qualifying hit (can Shake/Knock).
function Effects.boomerang(player: Player, def, root: BasePart, aim: Vector3?): boolean
	if not aim then
		return false
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterExclusions()

	local target: Player? = nil
	local targetRoot: BasePart? = nil
	local bestScore = math.huge
	for _, other in Players:GetPlayers() do
		local otherRoot = Combat.RootOf(other)
		if other ~= player and otherRoot then
			local offset = otherRoot.Position - origin
			local distance = offset.Magnitude
			local alignment = if distance > 0.1 then aim:Dot(offset.Unit) else 0
			if distance <= def.Range and alignment >= def.AimDot then
				local blocked = workspace:Raycast(origin, offset, params)
				local score = distance * (2 - alignment)
				if not blocked and score < bestScore then
					target, targetRoot, bestScore = other, otherRoot, score
				end
			end
		end
	end

	local endPoint = origin + aim * def.Range
	local wall = workspace:Raycast(origin, aim * def.Range, params)
	if wall then
		endPoint = wall.Position
	end
	if target and targetRoot then
		endPoint = targetRoot.Position
		if Combat.CanPlayerHit(player, target) then
			local result = Combat.ApplyHit(target, { Attacker = player, Damage = def.Damage, From = origin })
			Net.Fire("Feedback", player, { Type = "HitConfirm", Result = result })
		end
	else
		-- Decoys along the flight path pop.
		local length = (endPoint - origin).Magnitude
		for d = 5, length, 5 do
			if Decoys.PopNear(origin + aim * d, 4, player) then
				break
			end
		end
	end
	Net.FireAll("Feedback", { Type = "Boomerang", From = origin, To = endPoint })
	return true
end

-- PLACED & AREA WEAPONS ------------------------------------------------------------------
-- Bear Trap (everyone), and the Ascension Shop: Auto-Cannon, Freeze Ray, Tornado, Thunder Totem.
-- Everything placed lives in workspace.PlacedGadgets; cannons can be slapped apart.

local placedFolder: Folder? = nil
local function placed(): Folder
	if not placedFolder or not placedFolder.Parent then
		local f = Instance.new("Folder")
		f.Name = "PlacedGadgets"
		f.Parent = workspace
		placedFolder = f
	end
	return placedFolder :: Folder
end

local function solid(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- Ground a few studs in front of the player (or right under them).
local function groundAhead(root: BasePart, distance: number): Vector3
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterExclusions()
	local at = root.Position + direction * distance
	local hit = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -30, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 3, 0)
end

-- A weapon hit on `victim` from `from`: the same rules as a slap (a carrier is knocked and
-- drops the treasure). Returns the hit result, or nil if the victim can't be hit.
local function strike(owner: Player, victim: Player, from: Vector3, power: number): string?
	if victim == owner or not Combat.CanPlayerHit(owner, victim) then
		return nil
	end
	local result = Combat.ApplyHit(victim, { Attacker = owner, Damage = 0, From = from, Power = power })
	if owner.Parent then
		Net.Fire("Feedback", owner, { Type = "HitConfirm", Result = result })
	end
	return result
end

-- Rivals near `position` (not the owner, not protected), nearest first.
local function rivalsNear(owner: Player, position: Vector3, radius: number): { { Player: Player, Root: BasePart, Distance: number } }
	local list = {}
	for _, other in Players:GetPlayers() do
		local otherRoot = Combat.RootOf(other)
		if other ~= owner and otherRoot and not Combat.IsPvPProtected(other) then
			local distance = (otherRoot.Position - position).Magnitude
			if distance <= radius then
				table.insert(list, { Player = other, Root = otherRoot, Distance = distance })
			end
		end
	end
	table.sort(list, function(a, b)
		return a.Distance < b.Distance
	end)
	return list
end

local function hold(victim: Player, key: string, seconds: number)
	local t = token(victim, key)
	Movement.SetLock(victim, key, true)
	task.delay(seconds, function()
		if tokenValid(victim, key, t) then
			Movement.SetLock(victim, key, false)
		end
	end)
end

local function noPlacingHere(player: Player, position: Vector3, what: string): boolean
	if Zones.InSafeZone(position) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = ("No %s in the District"):format(what), Tone = "Warn" })
		return true
	end
	return false
end

-- Slappable placed gadgets (cannons): { Model, Owner, Health, Position }.
local breakables: { any } = {}

local function removeBreakable(entry)
	local index = table.find(breakables, entry)
	if index then
		table.remove(breakables, index)
	end
	if entry.Model.Parent then
		entry.Model:Destroy()
	end
end

-- BEAR TRAP: a steel trap on the ground. The first rival to step in is stuck in place, and a
-- carrier drops the treasure. Two per player; the third replaces the oldest.
local traps: { [Player]: { Model } } = {}

function Effects.bear_trap(player: Player, def, root: BasePart): boolean
	local center = groundAhead(root, 4)
	if noPlacingHere(player, center, "traps") then
		return false
	end
	local list = traps[player] or {}
	traps[player] = list
	while #list >= def.MaxActive do
		local oldest = table.remove(list, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	local model = Instance.new("Model")
	model.Name = "BearTrap"
	local steel = Color3.fromRGB(90, 88, 84)
	solid({ Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.25, 3.6, 3.6), CFrame = CFrame.new(center + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = steel, Material = Enum.Material.DiamondPlate, Parent = model })
	local jaws = {}
	for _, side in { -1, 1 } do
		local jaw = solid({ Name = "Jaw", Size = Vector3.new(3.4, 0.2, 0.9), CFrame = CFrame.new(center + Vector3.new(0, 0.3, side * 1.2)) * CFrame.Angles(math.rad(side * 60), 0, 0), Color = Color3.fromRGB(150, 145, 140), Material = Enum.Material.Metal, Parent = model })
		for i = -1, 1 do
			solid({ Name = "Tooth", Size = Vector3.new(0.25, 0.5, 0.25), CFrame = jaw.CFrame * CFrame.new(i * 1.1, 0.3, -side * 0.35), Color = Color3.fromRGB(210, 205, 200), Material = Enum.Material.Metal, Parent = model })
		end
		table.insert(jaws, jaw)
	end
	solid({ Name = "Trigger", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, 1, 1), CFrame = CFrame.new(center + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(200, 60, 50), Material = Enum.Material.SmoothPlastic, Parent = model })
	model.Parent = placed()
	table.insert(list, model)

	task.spawn(function()
		local started = os.clock()
		while model.Parent and os.clock() - started < def.Lifetime do
			for _, other in Players:GetPlayers() do
				local otherRoot = Combat.RootOf(other)
				if other ~= player and otherRoot and not Combat.IsPvPProtected(other) then
					local offset = otherRoot.Position - center
					if Vector3.new(offset.X, 0, offset.Z).Magnitude <= def.TriggerRadius and math.abs(offset.Y) < 6 then
						-- SNAP!
						for i, jaw in jaws do
							local side = if i == 1 then -1 else 1
							jaw.CFrame = CFrame.new(center + Vector3.new(0, 1, side * 0.3)) * CFrame.Angles(math.rad(side * 10), 0, 0)
						end
						hold(other, "BearTrap", def.HoldDuration)
						strike(player, other, center, def.Power)
						Net.Fire("Feedback", other, { Type = "Trapped", Duration = def.HoldDuration })
						Net.FireAll("Feedback", { Type = "TrapSnap", Position = center })
						if player.Parent then
							Net.Fire("Notify", player, { Kind = "Toast", Text = ("🪤 Your trap caught %s!"):format(other.DisplayName), Tone = "Reward" })
						end
						task.delay(def.HoldDuration, function()
							model:Destroy()
						end)
						local index = table.find(list, model)
						if index then
							table.remove(list, index)
						end
						return
					end
				end
			end
			task.wait(0.1)
		end
		local index = table.find(list, model)
		if index then
			table.remove(list, index)
		end
		model:Destroy()
	end)
	return true
end

-- AUTO-CANNON: a turret that shoots the nearest rival in range for Duration seconds. Three
-- slaps break it. One per player (a new one replaces the old).
local cannons: { [Player]: any } = {}

function Effects.auto_cannon(player: Player, def, root: BasePart): boolean
	local center = groundAhead(root, 5)
	if noPlacingHere(player, center, "cannons") then
		return false
	end
	if cannons[player] then
		removeBreakable(cannons[player])
	end
	local model = Instance.new("Model")
	model.Name = "AutoCannon"
	local wood = Color3.fromRGB(110, 72, 42)
	local iron = Color3.fromRGB(45, 45, 52)
	solid({ Name = "Base", Size = Vector3.new(4, 1.2, 4), CFrame = CFrame.new(center + Vector3.new(0, 0.6, 0)), Color = wood, Material = Enum.Material.WoodPlanks, CanCollide = true, CanQuery = true, Parent = model })
	for _, side in { -1, 1 } do
		solid({ Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.6, 2.6), CFrame = CFrame.new(center + Vector3.new(side * 2.2, 1.3, 0)), Color = wood, Material = Enum.Material.Wood, Parent = model })
	end
	local pivot = CFrame.new(center + Vector3.new(0, 2.4, 0))
	local barrel = solid({ Name = "Barrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(4, 1.6, 1.6), CFrame = pivot * CFrame.Angles(0, math.rad(90), 0) * CFrame.new(-1.2, 0, 0), Color = iron, Material = Enum.Material.Metal, Parent = model })
	local flag = solid({ Name = "OwnerFlag", Size = Vector3.new(0.12, 1.2, 1.8), CFrame = CFrame.new(center + Vector3.new(-1.6, 3.6, 1.6)), Color = Color3.fromRGB(220, 60, 60), Material = Enum.Material.Fabric, Parent = model })
	local tag = Instance.new("BillboardGui")
	tag.Size = UDim2.fromOffset(160, 26)
	tag.StudsOffset = Vector3.new(0, 3, 0)
	tag.MaxDistance = 90
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = Color3.fromRGB(255, 120, 100)
	label.TextStrokeTransparency = 0.2
	label.Text = ("💣 %s'S CANNON"):format(player.DisplayName:upper())
	label.Parent = tag
	tag.Parent = flag
	model.Parent = placed()
	local entry = { Model = model, Owner = player, Health = def.Health, Position = center }
	table.insert(breakables, entry)
	cannons[player] = entry

	task.spawn(function()
		local started = os.clock()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		while model.Parent and player.Parent and os.clock() - started < def.Duration do
			local muzzle = pivot.Position
			params.FilterDescendantsInstances = { model, placed(), table.unpack(characterExclusions()) }
			for _, candidate in rivalsNear(player, muzzle, def.Range) do
				local target = candidate.Root.Position
				if not workspace:Raycast(muzzle, target - muzzle, params) and Combat.CanPlayerHit(player, candidate.Player) then
					-- Swing the barrel round and fire.
					local aim = CFrame.lookAt(muzzle, target)
					barrel.CFrame = aim * CFrame.new(0, 0, -1.2) * CFrame.Angles(0, math.rad(90), 0)
					local ball = solid({ Name = "Cannonball", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.3, 1.3), CFrame = CFrame.new(muzzle), Color = Color3.fromRGB(25, 25, 30), Material = Enum.Material.Metal, Parent = placed() })
					local flight = math.clamp(candidate.Distance / 90, 0.12, 0.45)
					game:GetService("TweenService"):Create(ball, TweenInfo.new(flight, Enum.EasingStyle.Linear), { CFrame = CFrame.new(target) }):Play()
					Net.FireAll("Feedback", { Type = "CannonFire", Position = muzzle })
					local victim = candidate.Player
					task.delay(flight, function()
						ball:Destroy()
						local victimRoot = Combat.RootOf(victim)
						if victimRoot and (victimRoot.Position - target).Magnitude < 9 then
							strike(player, victim, muzzle, def.Power)
						end
					end)
					break
				end
			end
			task.wait(def.FireInterval)
		end
		if cannons[player] == entry then
			cannons[player] = nil
		end
		removeBreakable(entry)
	end)
	return true
end

-- A slap near a placed cannon (not your own) dents it; enough slaps and it breaks.
local function tryHitPlaced(attacker: Player, attackerRoot: BasePart): boolean
	for _, entry in breakables do
		if entry.Owner ~= attacker and (entry.Position - attackerRoot.Position).Magnitude <= GameConfig.Combat.AttackRange + 2 then
			entry.Health -= 1
			Net.FireAll("Feedback", { Type = "SlapImpact", Position = entry.Position + Vector3.new(0, 2, 0), BatId = "", Result = "Hit" })
			if entry.Health <= 0 then
				Net.Fire("Notify", attacker, { Kind = "Toast", Text = "💥 Cannon destroyed!", Tone = "Reward" })
				removeBreakable(entry)
			else
				Net.Fire("Notify", attacker, { Kind = "Toast", Text = ("💣 Cannon hit! %d more"):format(entry.Health), Tone = "Info" })
			end
			return true
		end
	end
	return false
end

-- FREEZE RAY: aimed beam; the target is frozen solid (can't move), and a carrier drops the loot.
function Effects.freeze_ray(player: Player, def, root: BasePart, aim: Vector3?): boolean
	if not aim then
		return false
	end
	local origin = root.Position + Vector3.new(0, 1.5, 0)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = characterExclusions()
	local now = os.clock()
	local target: Player? = nil
	local targetRoot: BasePart? = nil
	local bestScore = math.huge
	for _, other in Players:GetPlayers() do
		local otherRoot = Combat.RootOf(other)
		if other ~= player and otherRoot and now >= (trapImmuneUntil[other] or 0) then
			local offset = otherRoot.Position - origin
			local distance = offset.Magnitude
			local alignment = if distance > 0.1 then aim:Dot(offset.Unit) else 0
			if distance <= def.Range and alignment >= def.AimDot and not workspace:Raycast(origin, offset, params) then
				local score = distance * (2 - alignment)
				if score < bestScore then
					target, targetRoot, bestScore = other, otherRoot, score
				end
			end
		end
	end
	local endPoint = if targetRoot then targetRoot.Position else origin + aim * def.Range
	local beam = solid({ Name = "FreezeBeam", Size = Vector3.new(0.5, 0.5, (endPoint - origin).Magnitude), CFrame = CFrame.lookAt((origin + endPoint) / 2, endPoint), Color = Color3.fromRGB(150, 230, 255), Material = Enum.Material.Neon, Transparency = 0.2, Parent = placed() })
	task.delay(0.25, function()
		beam:Destroy()
	end)
	if not target or not targetRoot or not Combat.CanPlayerHit(player, target) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Missed - aim right at them", Tone = "Warn" })
		return true
	end
	local victim = target :: Player
	trapImmuneUntil[victim] = now + def.FreezeDuration + def.Immunity
	strike(player, victim, origin, 12)
	hold(victim, "Frozen", def.FreezeDuration)
	local ice = cosmeticPart({ Name = "IceBlock", Shape = Enum.PartType.Block, Size = Vector3.new(5, 7, 5), Color = Color3.fromRGB(170, 225, 255), Material = Enum.Material.Glass })
	ice.Transparency = 0.35
	weldVisual(targetRoot, ice, CFrame.new(0, -0.5, 0))
	ice.Parent = victim.Character
	Net.Fire("Feedback", victim, { Type = "Frozen", Duration = def.FreezeDuration, By = player.DisplayName })
	task.delay(def.FreezeDuration, function()
		ice:Destroy()
	end)
	return true
end

-- TORNADO: a twister that tears ahead; everyone it touches is flung (carriers drop).
function Effects.tornado(player: Player, def, root: BasePart): boolean
	local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
	local direction = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local position = groundAhead(root, 3)
	if noPlacingHere(player, position, "tornadoes") then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "Tornado"
	local rings = {}
	for i = 0, 5 do
		local w = 3 + i * 1.7
		local ring = solid({ Name = "Funnel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.2, w, w), Color = Color3.fromRGB(190, 195, 205), Material = Enum.Material.SmoothPlastic, Transparency = 0.45 + i * 0.05, Parent = model })
		table.insert(rings, { Part = ring, Height = 1.2 + i * 2.2 })
	end
	local dust = Instance.new("ParticleEmitter")
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 200, 205))
	dust.Size = NumberSequence.new(3, 7)
	dust.Transparency = NumberSequence.new(0.5, 1)
	dust.Lifetime = NumberRange.new(0.8, 1.4)
	dust.Rate = 30
	dust.Speed = NumberRange.new(4, 8)
	dust.SpreadAngle = Vector2.new(180, 30)
	dust.Parent = rings[1].Part
	model.Parent = placed()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	task.spawn(function()
		local started = os.clock()
		local hit: { [Player]: boolean } = {}
		local spin = 0
		while os.clock() - started < def.Duration do
			params.FilterDescendantsInstances = { model, table.unpack(characterExclusions()) }
			local nextPosition = position + direction * def.Speed * 0.05
			local ground = workspace:Raycast(nextPosition + Vector3.new(0, 10, 0), Vector3.new(0, -30, 0), params)
			if ground and ground.Position.Y - position.Y < 6 then
				position = ground.Position
			else
				break -- a wall or a cliff stops it
			end
			spin += 0.6
			for _, ring in rings do
				ring.Part.CFrame = CFrame.new(position + Vector3.new(0, ring.Height, 0)) * CFrame.Angles(0, spin, math.rad(90))
			end
			for _, candidate in rivalsNear(player, position + Vector3.new(0, 3, 0), def.Radius) do
				if not hit[candidate.Player] then
					hit[candidate.Player] = true
					strike(player, candidate.Player, position - direction * 3, def.Power)
					Net.Fire("Feedback", candidate.Player, { Type = "Knockback", Direction = direction, Power = 10, Lift = def.Lift })
				end
			end
			task.wait(0.05)
		end
		model:Destroy()
	end)
	return true
end

-- THUNDER TOTEM: plant it; lightning strikes every rival around it, three times.
function Effects.thunder_totem(player: Player, def, root: BasePart): boolean
	local center = groundAhead(root, 0)
	if noPlacingHere(player, center, "totems") then
		return false
	end
	local model = Instance.new("Model")
	model.Name = "ThunderTotem"
	solid({ Name = "Pole", Size = Vector3.new(1.2, 6, 1.2), CFrame = CFrame.new(center + Vector3.new(0, 3, 0)), Color = Color3.fromRGB(70, 60, 90), Material = Enum.Material.Slate, Parent = model })
	local orb = solid({ Name = "Orb", Shape = Enum.PartType.Ball, Size = Vector3.new(2, 2, 2), CFrame = CFrame.new(center + Vector3.new(0, 6.8, 0)), Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon, Parent = model })
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 240, 150)
	glow.Range = 20
	glow.Brightness = 2
	glow.Parent = orb
	local ring = solid({ Name = "Reach", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.2, def.Radius * 2, def.Radius * 2), CFrame = CFrame.new(center + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(255, 230, 90), Material = Enum.Material.Neon, Transparency = 0.8, Parent = model })
	model.Parent = placed()
	task.spawn(function()
		task.wait(def.Warmup)
		for _ = 1, def.Strikes do
			for _, candidate in rivalsNear(player, center, def.Radius) do
				local at = candidate.Root.Position
				local bolt = solid({ Name = "Lightning", Size = Vector3.new(0.8, 80, 0.8), CFrame = CFrame.new(at + Vector3.new(0, 40, 0)) * CFrame.Angles(0, 0, math.rad(math.random(-6, 6))), Color = Color3.fromRGB(255, 250, 200), Material = Enum.Material.Neon, Parent = placed() })
				task.delay(0.2, function()
					bolt:Destroy()
				end)
				strike(player, candidate.Player, center, def.Power)
			end
			Net.FireAll("Feedback", { Type = "Thunder", Position = center })
			ring.Transparency = 0.5
			task.wait(0.15)
			ring.Transparency = 0.8
			task.wait(def.StrikeInterval)
		end
		model:Destroy()
	end)
	return true
end

local function sendCooldowns(player: Player)
	Net.Fire("GadgetState", player, { Cooldowns = cooldowns[player] or {} })
end

local function onUse(player: Player, slot: any, aim: any)
	if type(slot) ~= "number" or slot ~= math.floor(slot) or slot < 1 or slot > GameConfig.Gadgets.Slots then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local id = data.EquippedGadgets[slot]
	local def = id and Gadgets.Get(id)
	local effect = def and Effects[id]
	if not def or not effect or not data.OwnedGadgets[id] then
		return
	end
	local root = Combat.RootOf(player)
	if not root or Combat.IsKnocked(player) or Movement.IsLocked(player) then
		return
	end
	local now = workspace:GetServerTimeNow()
	local playerCooldowns = cooldowns[player] or {}
	cooldowns[player] = playerCooldowns
	if now < (playerCooldowns[id] or 0) then
		sendCooldowns(player) -- resync a client that thinks it's ready
		return
	end
	if TreasureService.GetCarrying(player) and not def.CanUseWhileCarrying then
		Net.Fire("Notify", player, {
			Kind = "Toast",
			Text = ("Can't use %s while carrying"):format(def.Name:upper()),
			Tone = "Warn",
		})
		return
	end
	local aimDirection: Vector3? = nil
	if typeof(aim) == "Vector3" and aim.Magnitude > 0.5 and aim.Magnitude < 1.5 then
		aimDirection = aim.Unit
	end
	if def.NeedsAim and not aimDirection then
		return
	end
	if effect(player, def, root, aimDirection) then
		playerCooldowns[id] = now + def.Cooldown
		sendCooldowns(player)
		Net.FireAll("Feedback", { Type = "GadgetUsed", UserId = player.UserId, GadgetId = id })
		if PlayerData.Milestone(player, "FirstGadgetUse") then
			Analytics.Funnel(player, "FirstGadget")
		end
		Analytics.Event(player, "GadgetUsed", { Gadget = id })
	end
end

local function equip(player: Player, id: string, slot: number)
	PlayerData.Update(player, function(d)
		for i = 1, GameConfig.Gadgets.Slots do
			if d.EquippedGadgets[i] == id then
				d.EquippedGadgets[i] = ""
			end
		end
		d.EquippedGadgets[slot] = id
	end)
end

local function onBuy(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local def = Gadgets.Get(id)
	local data = PlayerData.Get(player)
	if not def or not def.Implemented or not data or data.OwnedGadgets[id] then
		return
	end
	if (data.Ascension or 0) < (def.RequiredAscension or 0) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = ("Needs ASCENSION %d"):format(def.RequiredAscension), Tone = "Warn" })
		return
	end
	if not PlayerData.TrySpend(player, def.Price) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Not enough Cash", Tone = "Warn" })
		return
	end
	PlayerData.Update(player, function(d)
		d.OwnedGadgets[id] = true
	end)
	PlayerData.Milestone(player, "FirstGadgetBought") -- tutorials key off milestones: Ascension wipes gadgets, not these
	-- Auto-equip into the first empty slot so a purchase is immediately usable.
	for i = 1, GameConfig.Gadgets.Slots do
		if (data.EquippedGadgets[i] or "") == "" then
			equip(player, id, i)
			break
		end
	end
	Net.Fire("Notify", player, { Kind = "Banner", Title = "GADGET UNLOCKED", Text = def.Name:upper(), Tone = "Reward" })
	Analytics.Economy(player, "Sink", def.Price, data.Cash, "Shop", id)
	Analytics.Event(player, "GadgetBought", { Gadget = id })
end

local function onEquip(player: Player, id: any, slot: any)
	if type(id) ~= "string" or type(slot) ~= "number" or slot ~= math.floor(slot) then
		return
	end
	if slot < 1 or slot > GameConfig.Gadgets.Slots then
		return
	end
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	if id == "" then
		PlayerData.Update(player, function(d)
			d.EquippedGadgets[slot] = ""
		end)
		return
	end
	if not data.OwnedGadgets[id] then
		return
	end
	equip(player, id, slot)
end

function GadgetService.Init()
	Combat.TryHitPlaced = tryHitPlaced
	Net.On("UseGadget", onUse, 6)
	Net.On("BuyGadget", onBuy, 3)
	Net.On("EquipGadget", onEquip, 5)
	PlayerData.Loaded:Connect(function(player)
		sendCooldowns(player)
	end)
	-- Disguise breaks on any hit, drop or new pickup.
	Combat.PlayerHit:Connect(function(victim)
		endDisguise(victim)
	end)
	TreasureService.Dropped:Connect(function(player)
		endDisguise(player)
	end)
	TreasureService.PickedUp:Connect(function(player)
		endDisguise(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		disguises[player] = nil
		cooldowns[player] = nil
		trapImmuneUntil[player] = nil
		effectTokens[player] = nil
		local playerTraps = traps[player]
		if playerTraps then
			for _, model in playerTraps do
				model:Destroy()
			end
		end
		traps[player] = nil
		if cannons[player] then
			removeBreakable(cannons[player])
			cannons[player] = nil
		end
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Invalidate running effects; Movement clears its temporary modifiers itself.
			effectTokens[player] = nil
			if disguises[player] then
				endDisguise(player)
			end
		end)
	end)
end

return GadgetService
