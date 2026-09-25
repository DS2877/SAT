-- Guided first run. Until a player has banked a treasure and collected their first Vault cash,
-- the HUD objective's target gets a trail you can SEE in the world:
--   * glowing footprints on the ground from you toward the target, a light wave running along them
--   * a tall gold beacon of light standing on the target
-- On the first bank ever: a full-screen "BANKED IT!" moment that explains what just happened
-- (it earns $ every second now) and what comes next. Everything here is local and decorative.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)
local HUD = require(script.Parent.HUD)

local Guide = {}

local player = Players.LocalPlayer
local STEPS = 12 -- footprints shown
local SPACING = 5 -- studs between footprints
local FIRST = 6 -- studs ahead of you to the first one
local HIDE_WITHIN = 14 -- target this close: the path is done
local GOLD = Color3.fromRGB(255, 214, 90)

local folder: Folder
local dots: { Part } = {}
local beacon: Part
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function active(): boolean
	-- Guided until the loop has clicked: first bank AND first Vault collect.
	return ClientState.Data ~= nil and not ClientState.Milestone("FirstCollect")
end

local function decor(props): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = folder
	return p
end

local function hideAll()
	for _, dot in dots do
		dot.Transparency = 1
	end
	beacon.Transparency = 1
end

local function groundBelow(position: Vector3): Vector3?
	local hit = workspace:Raycast(position + Vector3.new(0, 12, 0), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position
end

local function update()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local target = HUD.NavTarget()
	if not root or not target or not active() then
		hideAll()
		return
	end
	rayParams.FilterDescendantsInstances = { player.Character :: Instance, folder }
	local from = root.Position
	local to = target.Position :: Vector3
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local distance = flat.Magnitude
	if distance < HIDE_WITHIN then
		hideAll()
		return
	end
	local direction = flat.Unit
	local wave = (os.clock() * 1.6) % 1
	for i, dot in dots do
		local along = FIRST + (i - 1) * SPACING
		if along > distance - 4 then
			dot.Transparency = 1
			continue
		end
		local ground = groundBelow(from + direction * along)
		if not ground then
			dot.Transparency = 1
			continue
		end
		-- A bright pulse travels from you toward the target.
		local phase = ((i - 1) / STEPS - wave) % 1
		local glow = math.max(0, 1 - phase * 4)
		dot.CFrame = CFrame.lookAt(ground + Vector3.new(0, 0.12, 0), ground + Vector3.new(0, 0.12, 0) + direction) * CFrame.Angles(0, 0, math.rad(90))
		dot.Transparency = 0.55 - glow * 0.45 + (i / STEPS) * 0.25
	end
	beacon.CFrame = CFrame.new(to + Vector3.new(0, 38, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beacon.Transparency = 0.55 + math.sin(os.clock() * 3) * 0.1
end

-- FIRST BANK -----------------------------------------------------------------------------

function Guide.Celebrate(payload, gui: ScreenGui)
	local overlay = Kit.new("Frame", {
		Name = "FirstBank",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		ZIndex = 60,
		Parent = gui,
	})
	local title = Kit.label({
		Text = "💰 BANKED IT!",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(700, 90),
		Font = Theme.Font.Display,
		TextSize = 76,
		TextColor3 = GOLD,
		ZIndex = 62,
		Parent = overlay,
	})
	Kit.textStroke(Color3.fromRGB(60, 30, 0), 4).Parent = title
	local scale = Kit.new("UIScale", { Scale = 0.2, Parent = title })
	Kit.tween(scale, TweenInfo.new(0.5, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	local lines = {
		('<font color="#78eb78"><b>+%s</b></font> finder\'s fee'):format(Kit.formatCash(payload.Reward or 0)),
		("Your treasure now earns <b>%s every second</b> in your Vault."):format(Kit.shortCash(payload.Income or 0) .. "/s"),
		"Walk onto the <b>green pad</b> at your Vault to collect it.",
		"Then train at the <b>gym</b> to carry heavier, richer loot.",
	}
	for i, text in lines do
		local label = Kit.label({
			Text = text,
			RichText = true,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.3),
			Size = UDim2.fromOffset(640, 28),
			Font = Theme.Font.Bold,
			TextSize = 22,
			TextColor3 = Color3.new(1, 1, 1),
			TextTransparency = 1,
			ZIndex = 62,
			Parent = overlay,
		})
		Kit.textStroke(Color3.fromRGB(20, 20, 30), 2).Parent = label
		task.delay(0.35 + i * 0.35, function()
			Kit.tween(label, TweenInfo.new(0.3), { TextTransparency = 0, Position = UDim2.new(0.5, 0, 0.3, 40 + i * 34) })
		end)
	end
	-- Confetti.
	local colors = { GOLD, Color3.fromRGB(80, 230, 110), Color3.fromRGB(80, 170, 255), Color3.fromRGB(255, 110, 150) }
	for _ = 1, 40 do
		local bit = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(math.random(), -0.05),
			Size = UDim2.fromOffset(math.random(8, 14), math.random(12, 20)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = colors[math.random(1, #colors)],
			BorderSizePixel = 0,
			ZIndex = 61,
			Parent = overlay,
		})
		Kit.tween(bit, TweenInfo.new(math.random(18, 30) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Position = UDim2.fromScale(math.random(), 1.1),
			Rotation = math.random(-720, 720),
		})
	end
	Sounds.Play("BigReward")
	task.delay(5.5, function()
		for _, d in overlay:GetDescendants() do
			if d:IsA("TextLabel") then
				Kit.tween(d, TweenInfo.new(0.5), { TextTransparency = 1 })
			end
		end
		task.wait(0.6)
		overlay:Destroy()
	end)
end

function Guide.Init(gui: ScreenGui)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.Type == "Extracted" and payload.First == true then
			Guide.Celebrate(payload, gui)
		end
	end)
	folder = Instance.new("Folder")
	folder.Name = "LocalGuide"
	folder.Parent = workspace
	for _ = 1, STEPS do
		table.insert(dots, decor({ Name = "GuideDot", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 2.2, 2.2), Color = GOLD, Transparency = 1 }))
	end
	beacon = decor({ Name = "GuideBeacon", Shape = Enum.PartType.Cylinder, Size = Vector3.new(80, 2.4, 2.4), Color = GOLD, Transparency = 1 })
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= 1 / 20 then
			acc = 0
			update()
		end
	end)
end

return Guide
