-- HOLD-AND-TAP GADGETS. Tap a gadget slot: it's in your hand (Services/GadgetService puts the
-- model in your fist, the bat goes on your back). Then TAP THE SCREEN (click on PC) to use it:
--   * "Self" gadgets (Speed Soda, Balloon, Disguise) go off on any tap.
--   * "Aim" gadgets fire at what you tapped. Tap on or near a player and it LOCKS ON to them.
--   * "Place" gadgets land where you tapped - a ring on the ground shows how far you can reach,
--     and on PC a ghost circle follows the mouse.
-- Tap the slot again (or SLAP) to put it away. A hint pill says what to do.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Gadgets = require(Shared.Config.Gadgets)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)

local GadgetAim = {}

local player = Players.LocalPlayer
local isTouch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
local LOCK_RADIUS = 7 -- studs from your tap line that still count as "tapped that player"

local heldSlot: number? = nil
local slotRefs = {}
local hint: Frame
local hintText: TextLabel
local folder: Folder
local rangeRing: Part
local ghost: Part
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function heldDef()
	local data = ClientState.Data
	if not heldSlot or not data then
		return nil
	end
	return Gadgets.Get(data.EquippedGadgets[heldSlot] or "")
end

local function rootPart(): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function paint()
	local def = heldDef()
	for slot, ui in slotRefs do
		local stroke = ui.Button:FindFirstChildOfClass("UIStroke")
		local holding = slot == heldSlot and def ~= nil
		if stroke then
			stroke.Thickness = if holding then 4 else 2
			stroke.Transparency = if holding then 0 else 0.4
			stroke.Color = if holding then Color3.fromRGB(255, 230, 90) else Theme.Color.Gold
		end
		local scale = ui.Button:FindFirstChild("HoldScale") :: UIScale?
		if not scale then
			scale = Instance.new("UIScale")
			scale.Name = "HoldScale"
			scale.Parent = ui.Button
		end
		(scale :: UIScale).Scale = if holding then 1.12 else 1
	end
	hint.Visible = def ~= nil
	if def then
		local verb = if isTouch then def.Hint else def.Hint:gsub("^TAP", "CLICK")
		hintText.Text = ("%s %s"):format(def.Icon, verb)
	end
	local placing = def ~= nil and def.Use == "Place"
	rangeRing.Transparency = if placing then 0.55 else 1
	ghost.Transparency = 1
	if placing then
		local reach = (def.PlaceRange or 20) * 2
		rangeRing.Size = Vector3.new(0.12, reach, reach)
	end
end

-- Put it away (locally; the server is told separately).
local function drop()
	heldSlot = nil
	paint()
end

function GadgetAim.IsHolding(): boolean
	return heldDef() ~= nil
end

-- A slot was tapped: take that gadget in hand, or put it away if it's the one you hold.
function GadgetAim.Toggle(slot: number)
	local data = ClientState.Data
	if not data then
		return
	end
	local def = Gadgets.Get(data.EquippedGadgets[slot] or "")
	if not def then
		return
	end
	if heldSlot == slot then
		drop()
		Net.Get("HoldGadget"):FireServer(0)
		Sounds.Play("Click")
		return
	end
	if ClientState.Carrying() and not def.CanUseWhileCarrying then
		Sounds.Play("Error")
		return
	end
	heldSlot = slot
	Net.Get("HoldGadget"):FireServer(slot)
	Sounds.Play("Gadget", 0.5)
	paint()
end

function GadgetAim.Release()
	if heldSlot then
		drop()
		Net.Get("HoldGadget"):FireServer(0)
	end
end

-- Screen position -> (world point, locked-on player position?). Tapping on or near a rival
-- locks onto them; otherwise the first thing the tap ray hits.
local function resolve(screen: Vector2): (Vector3?, boolean)
	local camera = workspace.CurrentCamera
	local ray = camera:ScreenPointToRay(screen.X, screen.Y)
	local best, bestDistance = nil, math.huge
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local otherRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if other ~= player and otherRoot then
			local toTarget = otherRoot.Position - ray.Origin
			local along = toTarget:Dot(ray.Direction)
			if along > 0 then
				local off = (toTarget - ray.Direction * along).Magnitude
				local allowed = LOCK_RADIUS + along * 0.03
				if off <= allowed and off < bestDistance then
					best, bestDistance = otherRoot.Position, off
				end
			end
		end
	end
	if best then
		return best, true
	end
	local exclude: { Instance } = { folder }
	if player.Character then
		table.insert(exclude, player.Character)
	end
	rayParams.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 600, rayParams)
	return if hit then hit.Position else ray.Origin + ray.Direction * 200, false
end

local function marker(at: Vector3, color: Color3)
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Shape = Enum.PartType.Cylinder
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Size = Vector3.new(0.15, 1.5, 1.5)
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	Kit.tween(ring, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.new(0.15, 7, 7), Transparency = 1 })
	task.delay(0.5, function()
		ring:Destroy()
	end)
end

-- A tap/click on the world while holding a gadget.
function GadgetAim.UseAt(screen: Vector2)
	local def = heldDef()
	local root = rootPart()
	if not def or not root or not heldSlot then
		return
	end
	local ready = ClientState.Cooldowns[def.Id] or 0
	local left = ready - workspace:GetServerTimeNow()
	if left > 0 then
		Sounds.Play("Error")
		hintText.Text = ("%s READY IN %ds"):format(def.Icon, math.ceil(left))
		task.delay(0.9, paint)
		return
	end
	if ClientState.Carrying() and not def.CanUseWhileCarrying then
		Sounds.Play("Error")
		return
	end
	local point, locked = resolve(screen)
	local aim = if point then (point - root.Position).Unit else workspace.CurrentCamera.CFrame.LookVector
	-- Turn to face where it's going (you own your character: instant, no round trip).
	if point and def.Use ~= "Self" then
		local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		if flat.Magnitude > 0.5 then
			root.CFrame = CFrame.lookAt(root.Position, root.Position + flat)
		end
	end
	if point then
		marker(point, if locked then Color3.fromRGB(255, 90, 80) elseif def.Use == "Place" then Color3.fromRGB(120, 230, 255) else Color3.fromRGB(255, 230, 120))
	end
	Net.Get("UseGadget"):FireServer(heldSlot, aim, point)
end

function GadgetAim.Init(_gui: ScreenGui, slots, anchor: GuiObject)
	slotRefs = slots
	folder = Instance.new("Folder")
	folder.Name = "LocalGadgetAim"
	folder.Parent = workspace
	local function flatPart(color: Color3): Part
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.ForceField
		p.Color = color
		p.Transparency = 1
		p.Size = Vector3.new(0.12, 4, 4)
		p.Parent = folder
		return p
	end
	rangeRing = flatPart(Color3.fromRGB(120, 220, 255))
	ghost = flatPart(Color3.fromRGB(255, 240, 150))
	ghost.Material = Enum.Material.Neon

	-- The hint pill sits right above the gadget grid.
	hint = Kit.panel({
		Name = "GadgetHint",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -110, 1, -138),
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		Radius = Theme.Radius.Round,
		BackgroundTransparency = 0.1,
		Visible = false,
		Parent = anchor,
	}, { Kit.padding(0, 14) })
	hintText = Kit.label({
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Font = Theme.Font.Black,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(255, 235, 140),
		Parent = hint,
	})

	-- Taps on the world (not on buttons) use the held gadget.
	UserInputService.TouchTap:Connect(function(positions, processed)
		if processed or not GadgetAim.IsHolding() or #positions == 0 then
			return
		end
		GadgetAim.UseAt(positions[1])
	end)

	-- The server is the truth about what's in your hand (SLAP, a pickup, respawn put it away).
	player:GetAttributeChangedSignal("HeldGadget"):Connect(function()
		local id = player:GetAttribute("HeldGadget")
		if (id == nil or id == "") and heldSlot then
			local data = ClientState.Data
			-- Ignore the brief gap while switching straight from one gadget to another.
			task.delay(0.3, function()
				local now = player:GetAttribute("HeldGadget")
				if (now == nil or now == "") and heldSlot and data then
					drop()
				end
			end)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local def = heldDef()
		local root = rootPart()
		if not def or not root then
			return
		end
		if def.Use == "Place" then
			local feet = root.Position - Vector3.new(0, 2.9, 0)
			rangeRing.CFrame = CFrame.new(feet) * CFrame.Angles(0, 0, math.rad(90))
			-- PC: a ghost circle where it would land.
			if not isTouch then
				local mouse = UserInputService:GetMouseLocation()
				local inset = game:GetService("GuiService"):GetGuiInset()
				local point = resolve(mouse - inset)
				if point then
					local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
					local reach = def.PlaceRange or 20
					if flat.Magnitude > reach then
						point = Vector3.new(root.Position.X, point.Y, root.Position.Z) + flat.Unit * reach
					end
					ghost.Size = Vector3.new(0.14, 4, 4)
					ghost.CFrame = CFrame.new(point + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90))
					ghost.Transparency = 0.35
				end
			end
		end
	end)
	paint()
end

-- Data changed (slots re-equipped, carrying): keep the hand and the hint honest.
function GadgetAim.Refresh()
	if heldSlot and not heldDef() then
		drop()
	end
	paint()
end

return GadgetAim
