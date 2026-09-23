-- Presentation-only reactions to authoritative server feedback: knockback, knocked fall,
-- swings, gadget visuals, rare treasure discovery highlights, reclaim-protection labels.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)
local HUD = require(script.Parent.HUD)
local Notifications = require(script.Parent.Notifications)

local Effects = {}

local player = Players.LocalPlayer
local announced: { [number]: boolean } = {}
local highlights: { [Instance]: Highlight } = {}
local protectionTags: { [Instance]: BillboardGui } = {}
local DISCOVERY_RANGE = 55
local DISCOVERY_MIN_RARITY = "Rare"

local function myRoot(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function myHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function shakeCamera(intensity: number, duration: number)
	local humanoid = myHumanoid()
	if not humanoid then
		return
	end
	task.spawn(function()
		local t = 0
		while t < duration do
			local falloff = 1 - t / duration
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * intensity * falloff,
				(math.random() - 0.5) * intensity * falloff,
				0
			)
			t += task.wait()
		end
		humanoid.CameraOffset = Vector3.zero
	end)
end

local function swingEffect(root: BasePart)
	local arc = Instance.new("Part")
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CanTouch = false
	arc.CastShadow = false
	arc.Material = Enum.Material.Neon
	arc.Color = Color3.new(1, 1, 1)
	arc.Transparency = 0.35
	arc.Shape = Enum.PartType.Cylinder
	arc.Size = Vector3.new(0.3, 5, 5)
	arc.CFrame = root.CFrame * CFrame.new(0, 0, -3.2) * CFrame.Angles(0, math.rad(90), 0)
	arc.Parent = workspace
	Kit.tween(arc, TweenInfo.new(0.18), { Size = Vector3.new(0.1, 8, 8), Transparency = 1 })
	task.delay(0.2, function()
		arc:Destroy()
	end)
end

local function beam(from: Vector3, to: Vector3, color: Color3)
	local distance = (to - from).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = 0.3
	p.Size = Vector3.new(0.6, 0.6, distance)
	p.CFrame = CFrame.lookAt((from + to) / 2, to)
	p.Parent = workspace
	Kit.tween(p, TweenInfo.new(0.3), { Transparency = 1, Size = Vector3.new(0.1, 0.1, distance) })
	task.delay(0.35, function()
		p:Destroy()
	end)
end

local handlers = {}

function handlers.PickedUp(payload)
	Sounds.Play("Pickup")
	local def = Treasures.Get(payload.TreasureId)
	if def then
		local info = Rarities.Info[def.Rarity]
		HUD.ShowStatus(("%s %s"):format(info.Glyph, def.Name:upper()), "NOW GET IT HOME!", info.Color, 1.6)
	end
	HUD.RefreshObjective()
end

function handlers.Dropped(payload)
	Sounds.Play("Drop")
	if payload.Reason == "Manual" then
		HUD.ShowStatus("TREASURE DROPPED", nil, Theme.Color.Warn, 1.5)
	end
end

function handlers.Knockback(payload)
	local root = myRoot()
	if root and typeof(payload.Direction) == "Vector3" then
		local power = math.clamp(tonumber(payload.Power) or 40, 0, 80)
		root.AssemblyLinearVelocity = payload.Direction * power + Vector3.new(0, 22, 0)
	end
	Sounds.Play("Hit")
	shakeCamera(0.6, 0.2)
end

function handlers.Shaken(payload)
	Sounds.Play("Shaken")
	HUD.ShowStatus("SHAKEN!", "One more hit and you DROP IT", Theme.Color.Warn, payload.Window or 3)
	HUD.FlashDanger(0.55, payload.Window or 3)
	shakeCamera(1, 0.35)
end

function handlers.Knocked(payload)
	local duration = payload.Duration or GameConfig.Stability.KnockedDuration
	Sounds.Play("Knocked")
	HUD.ShowStatus("KNOCKED!", ("Grab it back — %ds protection"):format(GameConfig.Treasure.ReclaimProtection), Theme.Color.Danger, duration + 1)
	HUD.FlashDanger(0.9, duration + 0.5)
	shakeCamera(1.6, 0.5)
	local humanoid = myHumanoid()
	if humanoid then
		humanoid.PlatformStand = true
		local root = myRoot()
		if root then
			root.AssemblyAngularVelocity = Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		end
		task.delay(duration, function()
			if humanoid.Parent then
				humanoid.PlatformStand = false
				humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
			end
		end)
	end
end

function handlers.Swing(payload)
	local other = Players:GetPlayerByUserId(payload.UserId)
	local character = other and other.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		swingEffect(root)
		if other == player then
			Sounds.Play("Swing")
		else
			Sounds.PlayAt("Swing", root.Position)
		end
	end
end

function handlers.HitConfirm(payload)
	Sounds.Play("Hit", 0.8)
	if payload.Result == "Knocked" then
		HUD.ShowStatus("THEY DROPPED IT!", "Grab it when protection ends", Theme.Color.Gold, 1.8)
	elseif payload.Result == "Shaken" then
		Notifications.Toast("SHAKEN! Hit them again!", "Reward")
	elseif payload.Result == "Guardian" then
		Notifications.Toast("GUARDIAN STUNNED", "Info")
	end
end

function handlers.GuardianAlert(payload)
	Sounds.Play("GuardianAlert")
	Notifications.Toast(("⚠ %s SPOTTED YOU!"):format(tostring(payload.Name):upper()), "Danger")
end

function handlers.GuardianAttack(payload)
	if typeof(payload.Position) == "Vector3" then
		Sounds.PlayAt("Hit", payload.Position)
	end
end

function handlers.Extracted(payload)
	Notifications.Reward(payload)
end

function handlers.Balloon()
	Sounds.Play("Gadget")
	local humanoid = myHumanoid()
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
	end
end

function handlers.Grapple()
	Sounds.Play("Gadget")
	local humanoid = myHumanoid()
	if humanoid then
		humanoid:ChangeState(Enum.HumanoidStateType.Freefall)
	end
end

function handlers.Bubbled(payload)
	Sounds.Play("Splash")
	HUD.ShowStatus("BUBBLED!", ("by %s"):format(tostring(payload.By)), Theme.Color.Info, payload.Duration or 2)
end

function handlers.BubbleShot(payload)
	if typeof(payload.From) == "Vector3" and typeof(payload.To) == "Vector3" then
		beam(payload.From, payload.To, Color3.fromRGB(150, 220, 255))
		Sounds.PlayAt("Splash", payload.To)
	end
end

function handlers.GadgetUsed(payload)
	if payload.UserId == player.UserId then
		Sounds.Play("Gadget")
	end
end

function handlers.Ascended(payload)
	Sounds.Play("Ascend")
	Notifications.Banner("ASCENDED!", ("%s • x%.2f CASH FOREVER"):format(tostring(payload.Title):upper(), payload.Multiplier or 1), "Reward", 4)
end

-- DISCOVERY + DROPPED TREASURE LABELS ------------------------------------------------

local function setHighlight(model: Model, color: Color3?)
	local existing = highlights[model]
	if color then
		if not existing then
			existing = Instance.new("Highlight")
			existing.FillTransparency = 0.7
			existing.OutlineTransparency = 0
			existing.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			existing.Parent = model
			highlights[model] = existing
		end
		(existing :: Highlight).OutlineColor = color;
		(existing :: Highlight).FillColor = color
	elseif existing then
		existing:Destroy()
		highlights[model] = nil
	end
end

local function protectionTag(model: Model, remaining: number?)
	local tag = protectionTags[model]
	if remaining and remaining > 0 and model.PrimaryPart then
		if not tag then
			tag = Instance.new("BillboardGui")
			tag.Size = UDim2.fromOffset(120, 26)
			tag.StudsOffset = Vector3.new(0, -1.5, 0)
			tag.AlwaysOnTop = true
			tag.LightInfluence = 0
			tag.MaxDistance = 80
			Kit.label({ Name = "Text", Size = UDim2.fromScale(1, 1), Font = Theme.Font.Black, TextSize = 16, TextColor3 = Theme.Color.Warn, TextStrokeTransparency = 0.2, Parent = tag })
			tag.Adornee = model.PrimaryPart
			tag.Parent = model
			protectionTags[model] = tag
		end
		local mine = model:GetAttribute("ProtectedForUserId") == player.UserId
		local label = (tag :: BillboardGui):FindFirstChild("Text") :: TextLabel
		label.Text = if mine then ("YOURS • %.1f"):format(remaining) else ("🔒 %.1f"):format(remaining)
		label.TextColor3 = if mine then Theme.Color.Safe else Theme.Color.Warn
	elseif tag then
		tag:Destroy()
		protectionTags[model] = nil
	end
end

local function scanTreasures()
	local folder = workspace:FindFirstChild("Treasures")
	local root = myRoot()
	if not folder or not root then
		return
	end
	local carrying = ClientState.Carrying()
	local lanternActive = carrying ~= nil and carrying.SpecialEffect == "RevealsTreasures"
	local serverNow = workspace:GetServerTimeNow()
	for _, model in folder:GetChildren() do
		local primary = (model :: Model).PrimaryPart
		if primary then
			local state = model:GetAttribute("State")
			local rarity = model:GetAttribute("Rarity") or "Common"
			local info = Rarities.Info[rarity]
			local distance = (primary.Position - root.Position).Magnitude
			local grounded = state == "World" or state == "Dropped"

			-- Discovery moment for valuable treasure (once per treasure instance)
			local uid = model:GetAttribute("Uid")
			if grounded and uid and not announced[uid] and distance <= DISCOVERY_RANGE and Rarities.AtLeast(rarity, DISCOVERY_MIN_RARITY) then
				announced[uid] = true
				local def = Treasures.Get(model:GetAttribute("TreasureId"))
				if def then
					Sounds.Play("RareDiscovery")
					Notifications.Toast(("%s %s TREASURE NEARBY — %s %s"):format(info.Glyph, rarity:upper(), def.Name:upper(), Kit.formatCash(def.Value)), "Reward")
				end
			end

			local highlightColor = nil
			if grounded and ((distance <= DISCOVERY_RANGE and info.Rank >= 3) or (lanternActive and distance <= 160)) then
				highlightColor = info.Color
			end
			setHighlight(model :: Model, highlightColor)

			local protectedUntil = model:GetAttribute("ProtectedUntil")
			protectionTag(model :: Model, if state == "Dropped" and protectedUntil then protectedUntil - serverNow else nil)
		end
	end
	for model in highlights do
		if not model.Parent then
			highlights[model] = nil
		end
	end
	for model in protectionTags do
		if not model.Parent then
			protectionTags[model] = nil
		end
	end
end

function Effects.Init()
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local handler = handlers[payload.Type]
		if handler then
			handler(payload)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.2)
			local ok, err = pcall(scanTreasures)
			if not ok then
				warn("[Effects] scan error:", err)
			end
		end
	end)

	-- Spinning showpieces (District coin, altar gem). Client-side only.
	task.spawn(Effects.StartSpinners)
end

function Effects.StartSpinners()
	local spinners = {}
	local function track(inst: Instance)
		if inst:IsA("BasePart") and inst:GetAttribute("Spin") then
			table.insert(spinners, { Part = inst, Speed = inst:GetAttribute("Spin"), Base = inst.CFrame })
		end
	end
	local world = workspace:WaitForChild("World", 30)
	if world then
		for _, d in world:GetDescendants() do
			track(d)
		end
	end
	if #spinners > 0 then
		local angle = 0
		RunService.Heartbeat:Connect(function(dt)
			angle += dt
			for _, s in spinners do
				s.Part.CFrame = CFrame.new(s.Base.Position) * CFrame.Angles(0, angle * s.Speed, 0) * s.Base.Rotation
			end
		end)
	end
end

return Effects
