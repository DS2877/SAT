-- Gadget ownership, equipping, server-authoritative cooldowns and effects.
-- Adding a gadget = config entry in Shared.Config.Gadgets + an Effects[id] function here.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Gadgets = require(Shared.Config.Gadgets)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)

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
	Players.PlayerRemoving:Connect(function(player)
		cooldowns[player] = nil
		trapImmuneUntil[player] = nil
		effectTokens[player] = nil
	end)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- Invalidate running effects; Movement clears its temporary modifiers itself.
			effectTokens[player] = nil
		end)
	end)
end

return GadgetService
