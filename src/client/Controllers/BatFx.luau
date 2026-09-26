-- Bats on the client (Config/Bats, Services/BatService): the swing trail on everyone's bat and
-- the slap impact burst. The bat itself is a real Roblox Tool (BatService), so Roblox does the
-- hand grip, the arm-out hold and the "Slash" swing animation - the standard look of every
-- Roblox melee game. There's no hotbar (the Backpack UI is off): the SLAP button swings, and
-- the server tucks the bat away while you carry treasure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Bats = require(Shared.Config.Bats)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Sounds = require(UI.Sounds)

local BatFx = {}

local swinging: { [Trail]: boolean } = {}

local function trailOf(player: Player): Trail?
	local character = player.Character
	local tool = character and character:FindFirstChild("Bat")
	local handle = tool and tool:IsA("Tool") and tool:FindFirstChild("Handle")
	local trail = handle and handle:FindFirstChild("SwingTrail")
	return if trail and trail:IsA("Trail") then trail else nil
end

-- The swoosh behind the bat while the Slash animation plays.
local function swing(player: Player)
	local trail = trailOf(player)
	if not trail or swinging[trail] then
		return
	end
	swinging[trail] = true
	trail.Enabled = true
	task.delay(0.35, function()
		trail.Enabled = false
		swinging[trail] = nil
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
	Sounds.PlayAt("BatHit", position)
	Sounds.PlayAt("Slap", position)
	task.delay(0.7, function()
		ring:Destroy()
	end)
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
	-- No hotbar: the bat is always in hand (or tucked away while carrying).
	task.spawn(function()
		for _ = 1, 10 do
			if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then
				return
			end
			task.wait(1)
		end
	end)
end

return BatFx
