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
	if not PlayerData.TrySpend(player, def.Price) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Not enough Cash", Tone = "Warn" })
		return
	end
	PlayerData.Update(player, function(d)
		d.OwnedGadgets[id] = true
	end)
	-- Auto-equip into the first empty slot so a purchase is immediately usable.
	for i = 1, GameConfig.Gadgets.Slots do
		if data.EquippedGadgets[i] == "" then
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
