-- Bats on the client (Config/Bats, Services/BatService): the swing animation on everyone's
-- bat, the slap impact burst, and hiding a bat while its owner carries treasure (both hands
-- are busy holding the loot).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Bats = require(Shared.Config.Bats)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Sounds = require(UI.Sounds)

local BatFx = {}

local swinging: { [Weld]: boolean } = {}

local function batOf(player: Player): Model?
	local character = player.Character
	local model = character and character:FindFirstChild("Bat")
	return if model and model:IsA("Model") then model else nil
end

local function swing(player: Player)
	local model = batOf(player)
	local grip = model and model.PrimaryPart
	local weld = grip and grip:FindFirstChild("BatGrip")
	if not weld or not weld:IsA("Weld") or swinging[weld] then
		return
	end
	swinging[weld] = true
	local trail = grip and grip:FindFirstChild("SwingTrail")
	TweenService:Create(weld, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = Bats.Grip.WindUp }):Play()
	task.delay(0.08, function()
		if trail and trail:IsA("Trail") then
			trail.Enabled = true
		end
		TweenService:Create(weld, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = Bats.Grip.Swing }):Play()
		task.delay(0.22, function()
			if trail and trail:IsA("Trail") then
				trail.Enabled = false
			end
			TweenService:Create(weld, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), { C0 = Bats.Grip.Rest }):Play()
			task.delay(0.26, function()
				swinging[weld] = nil
			end)
		end)
	end)
end

-- A burst where a slap lands: bigger and brighter the better the bat.
local function impact(position: Vector3, batId: string?, result: string?)
	local bat = Bats.Get(batId) or Bats.List[1]
	local color = Bats.TrailColor(bat)
	local size = 3 + bat.Tier * 0.5
	local ring = Instance.new("Part")
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.2
	ring.Shape = Enum.PartType.Ball
	ring.Size = Vector3.new(1, 1, 1)
	ring.CFrame = CFrame.new(position)
	ring.Parent = workspace
	TweenService:Create(ring, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Size = Vector3.one * size, Transparency = 1 }):Play()
	if bat.Tier >= 5 then
		local sparks = Instance.new("ParticleEmitter")
		sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparks.Color = ColorSequence.new(color, Bats.Color(bat))
		sparks.LightEmission = 1
		sparks.LightInfluence = 0
		sparks.Size = NumberSequence.new(0.6, 0)
		sparks.Lifetime = NumberRange.new(0.3, 0.6)
		sparks.Speed = NumberRange.new(10, 20 + bat.Tier * 2)
		sparks.SpreadAngle = Vector2.new(180, 180)
		sparks.Rate = 0
		sparks.Parent = ring
		sparks:Emit(8 + bat.Tier * 3)
	end
	-- "SLAP!" pops out of the hit.
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(6, 2)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 120
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Text = if result == "Knocked" then "WHAM!" elseif result == "Shaken" then "SLAP!" else "SLAP!"
	label.Rotation = math.random(-12, 12)
	label.Parent = gui
	gui.Parent = ring
	TweenService:Create(gui, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffsetWorldSpace = Vector3.new(0, 6, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	Sounds.PlayAt("Hit", position)
	task.delay(0.7, function()
		ring:Destroy()
	end)
end

-- Carriers hold their loot with both hands: hide their bat (and its particles) meanwhile.
local function refreshVisibility()
	for _, player in Players:GetPlayers() do
		local model = batOf(player)
		if model then
			local hidden = (player:GetAttribute("CarryingUid") or 0) ~= 0
			if model:GetAttribute("Hidden") ~= hidden then
				model:SetAttribute("Hidden", hidden)
				for _, d in model:GetDescendants() do
					if d:IsA("BasePart") then
						d.LocalTransparencyModifier = if hidden then 1 else 0
					elseif d:IsA("ParticleEmitter") then
						d.Enabled = not hidden
					end
				end
			end
		end
	end
end

function BatFx.Init()
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Type == "Swing" then
			local other = Players:GetPlayerByUserId(payload.UserId)
			if other then
				swing(other)
			end
		elseif payload.Type == "SlapImpact" and typeof(payload.Position) == "Vector3" then
			impact(payload.Position, payload.BatId, payload.Result)
		elseif payload.Type == "BatBought" then
			Sounds.Play("BigReward")
		end
	end)
	task.spawn(function()
		while true do
			refreshVisibility()
			task.wait(0.25)
		end
	end)
end

return BatFx
