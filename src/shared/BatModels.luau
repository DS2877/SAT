-- One hand-built model per bat (Config/Bats), from a plain Wooden Bat to The Big Bang. Each
-- tier looks cooler than the last: better materials, glowing parts, then particles.
--
-- Build(id, cframe) returns a Model whose PrimaryPart "Grip" is an invisible handle at the
-- hand; the bat runs up its +Y axis (knob just below the grip, barrel on top). Every other
-- part is welded to the Grip, so moving/welding the Grip moves the whole bat. Two attachments
-- (TrailA at the top of the handle, TrailB at the tip) carry a disabled "SwingTrail" that the
-- client switches on during a swing.

local TreasureModels = require(script.Parent.TreasureModels)
local Bats = require(script.Parent.Config.Bats)

local BatModels = {}

local C = Color3.fromRGB
local M = Enum.Material

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

type Kit = TreasureModels.Kit

-- The shared bat shape: knob, taped handle, a barrel that swells to `maxD` at `length`.
local function body(k: Kit, spec)
	local length, maxD = spec.Length, spec.MaxD
	k.vcyl(0.18, 0.52, k.at(0, -0.3, 0), spec.Knob or spec.Grip, spec.KnobMat or M.SmoothPlastic)
	k.vcyl(1.75, 0.28, k.at(0, 0.6, 0), spec.Handle or spec.Color, spec.HandleMat or spec.Mat)
	for i = 0, 3 do
		k.vcyl(0.16, 0.33, k.at(0, -0.05 + i * 0.36, 0), spec.Grip, M.Fabric)
	end
	local segments = 9
	local from = 1.4
	local step = (length - from) / segments
	for i = 0, segments - 1 do
		local t = (i + 0.5) / segments
		local d = 0.32 + (maxD - 0.32) * math.sqrt(t)
		local color = if spec.Gradient then spec.Gradient(t) else spec.Color
		k.vcyl(step * 1.08, d, k.at(0, from + step * (i + 0.5), 0), color, spec.Mat, spec.Extra)
	end
	k.ball(maxD, maxD * 0.55, maxD, k.at(0, length, 0), spec.Cap or spec.Color, spec.CapMat or spec.Mat, spec.Extra)
end

-- A spike pointing straight out from the barrel at angle a (radians), height y.
local function spikeOut(k: Kit, a: number, y: number, r: number, height: number, dia: number, color: Color3, mat: Enum.Material, tilt: number?)
	k.cone(height, dia, 3, k.at(math.cos(a) * r, y, math.sin(a) * r, 0, -math.deg(a), -90 + (tilt or 0)), color, mat)
end

local function emitter(k: Kit, y: number, props)
	local anchor = k.box(0.1, 0.1, 0.1, k.at(0, y, 0), C(0, 0, 0), M.SmoothPlastic, { T = 1 })
	anchor.Name = "FxAnchor"
	local e = Instance.new("ParticleEmitter")
	e.LightEmission = 1
	e.LightInfluence = 0
	for key, value in props do
		(e :: any)[key] = value
	end
	e.Parent = anchor
	return e
end

local Builders: { [string]: (Kit) -> number } = {}

Builders.wooden_bat = function(k)
	body(k, { Length = 4.2, MaxD = 0.62, Color = C(190, 140, 85), Mat = M.Wood, Grip = C(70, 45, 30) })
	k.box(0.3, 0.5, 0.06, k.at(0, 3.2, -0.3), C(90, 55, 30), M.Wood) -- burnt-in logo
	return 4.2
end

Builders.spiked_club = function(k)
	body(k, { Length = 4.2, MaxD = 0.9, Color = C(125, 85, 52), Mat = M.Wood, Grip = C(160, 130, 90) })
	k.vcyl(0.14, 0.86, k.at(0, 2.4, 0), C(80, 80, 88), M.Metal)
	for row, y in { 2.8, 3.35, 3.9 } do
		for i = 1, 6 do
			local a = (i + row * 0.5) / 6 * 2 * math.pi
			spikeOut(k, a, y, 0.38, 0.45, 0.16, C(200, 200, 210), M.Metal)
		end
	end
	spikeOut(k, 0, 4.35, 0, 0.5, 0.2, C(200, 200, 210), M.Metal, 90)
	return 4.3
end

Builders.iron_slugger = function(k)
	body(k, { Length = 4.3, MaxD = 0.64, Color = C(150, 155, 170), Mat = M.Metal, Extra = { R = 0.25 }, Grip = C(25, 25, 30), Cap = C(30, 30, 35) })
	for _, y in { 2.1, 3.85 } do
		k.vcyl(0.16, 0.64, k.at(0, y, 0), C(220, 40, 40), M.SmoothPlastic)
	end
	k.vcyl(0.9, 0.05, k.at(0, 3.0, -0.3), C(255, 255, 255), M.SmoothPlastic)
	return 4.3
end

Builders.golden_slugger = function(k)
	body(k, { Length = 4.4, MaxD = 0.66, Color = C(255, 200, 50), Mat = M.Metal, Extra = { R = 0.35 }, Grip = C(245, 245, 245), Knob = C(255, 200, 50), KnobMat = M.Metal })
	k.ball(0.32, 0.32, 0.32, k.at(0, -0.45, 0), C(255, 40, 70), M.Neon)
	for i = 1, 4 do
		local a = i / 4 * 2 * math.pi
		k.box(0.14, 0.14, 0.14, k.at(math.cos(a) * 0.3, 3.3, math.sin(a) * 0.3, 45, 45, 0), C(255, 255, 255), M.Neon)
	end
	emitter(k, 3.4, { Texture = SPARKLE, Color = ColorSequence.new(C(255, 230, 120)), Size = NumberSequence.new(0.3, 0), Lifetime = NumberRange.new(0.6, 1), Rate = 4, Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180) })
	return 4.4
end

Builders.frostbite = function(k)
	body(k, { Length = 4.5, MaxD = 0.7, Color = C(170, 230, 255), Mat = M.Glass, Extra = { T = 0.2 }, Handle = C(90, 120, 160), HandleMat = M.Metal, Grip = C(40, 60, 100), Cap = C(210, 245, 255) })
	k.vcyl(2.7, 0.3, k.at(0, 3.0, 0), C(90, 220, 255), M.Neon)
	for i = 1, 7 do
		local a = i / 7 * 2 * math.pi
		spikeOut(k, a, 2.6 + (i % 3) * 0.55, 0.3, 0.55 + (i % 2) * 0.25, 0.17, C(200, 245, 255), M.Glass, 35)
	end
	emitter(k, 3.6, { Texture = SPARKLE, Color = ColorSequence.new(C(220, 250, 255)), Size = NumberSequence.new(0.35, 0), Lifetime = NumberRange.new(0.8, 1.4), Rate = 6, Speed = NumberRange.new(0.2, 0.6), Acceleration = Vector3.new(0, -2, 0), SpreadAngle = Vector2.new(180, 180) })
	return 4.5
end

Builders.magma_mauler = function(k)
	body(k, { Length = 4.5, MaxD = 0.8, Color = C(45, 38, 38), Mat = M.Basalt, Grip = C(90, 30, 20), Cap = C(255, 120, 30), CapMat = M.Neon })
	for i = 1, 6 do
		local a = i / 6 * 2 * math.pi
		local r = 0.36
		k.box(0.07, 0.9, 0.07, k.at(math.cos(a) * r, 2.3 + (i % 3) * 0.6, math.sin(a) * r, 0, 0, (i % 2) * 30 - 15), C(255, 110, 25), M.Neon)
	end
	k.vcyl(0.12, 0.84, k.at(0, 1.9, 0), C(255, 140, 40), M.Neon)
	emitter(k, 4.4, { Texture = FIRE, Color = ColorSequence.new(C(255, 180, 60), C(255, 60, 20)), Size = NumberSequence.new(0.8, 0.1), Lifetime = NumberRange.new(0.4, 0.7), Rate = 10, Speed = NumberRange.new(1, 2.5), SpreadAngle = Vector2.new(25, 25), EmissionDirection = Enum.NormalId.Top })
	return 4.5
end

Builders.thunderclap = function(k)
	body(k, { Length = 4.6, MaxD = 0.72, Color = C(55, 58, 75), Mat = M.Metal, Extra = { R = 0.2 }, Grip = C(255, 210, 40), Cap = C(255, 235, 80), CapMat = M.Neon })
	-- A lightning bolt zig-zagging up the barrel.
	for i = 0, 5 do
		local y = 1.9 + i * 0.45
		local a = i * 1.1
		k.box(0.09, 0.55, 0.09, k.at(math.cos(a) * 0.36, y, math.sin(a) * 0.36, 0, 0, if i % 2 == 0 then 35 else -35), C(255, 240, 90), M.Neon)
	end
	for i = 1, 3 do
		local a = i / 3 * 2 * math.pi
		spikeOut(k, a, 4.55, 0.22, 0.5, 0.14, C(255, 240, 90), M.Neon, 60)
	end
	emitter(k, 4.3, { Texture = SPARKLE, Color = ColorSequence.new(C(255, 255, 160), C(120, 200, 255)), Size = NumberSequence.new(0.45, 0), Lifetime = NumberRange.new(0.15, 0.35), Rate = 14, Speed = NumberRange.new(3, 6), SpreadAngle = Vector2.new(180, 180) })
	return 4.6
end

Builders.crystal_crusher = function(k)
	body(k, { Length = 4.4, MaxD = 0.6, Color = C(120, 60, 190), Mat = M.Glass, Extra = { T = 0.1 }, Handle = C(60, 40, 90), HandleMat = M.Metal, Grip = C(30, 20, 50), Cap = C(200, 130, 255), CapMat = M.Neon })
	-- A crown of crystals grown out of the barrel.
	local colors = { C(200, 120, 255), C(255, 140, 230), C(150, 110, 255) }
	for i = 1, 8 do
		local a = i / 8 * 2 * math.pi
		local h = 0.6 + (i % 3) * 0.3
		local cf = k.at(math.cos(a) * 0.25, 3.2 + (i % 2) * 0.55, math.sin(a) * 0.25, 0, -math.deg(a), -32)
		k.box(0.2, h, 0.2, cf * CFrame.new(0, h / 2 * k.s, 0), colors[i % 3 + 1], M.Neon, { T = 0.1 })
	end
	k.box(0.32, 1.0, 0.32, k.at(0, 4.8, 0, 0, 45, 0), C(230, 170, 255), M.Neon)
	emitter(k, 4.3, { Texture = SPARKLE, Color = ColorSequence.new(C(230, 170, 255)), Size = NumberSequence.new(0.4, 0), Lifetime = NumberRange.new(0.6, 1), Rate = 8, Speed = NumberRange.new(0.5, 1.2), SpreadAngle = Vector2.new(180, 180) })
	return 4.8
end

Builders.void_breaker = function(k)
	body(k, { Length = 4.7, MaxD = 0.78, Color = C(22, 16, 34), Mat = M.Metal, Extra = { R = 0.3 }, Grip = C(120, 50, 200), Cap = C(10, 8, 16) })
	for _, y in { 2.2, 3.1, 4.0 } do
		k.vcyl(0.1, 0.74, k.at(0, y, 0), C(170, 80, 255), M.Neon)
	end
	-- A ring of force orbiting the barrel, a void eye on the tip.
	k.torus(0.72, 0.07, 18, k.at(0, 3.6, 0, 70, 0, 20), C(200, 120, 255), M.Neon)
	k.ball(0.5, 0.5, 0.5, k.at(0, 4.95, 0), C(5, 0, 10), M.SmoothPlastic)
	k.torus(0.27, 0.06, 12, k.at(0, 4.95, 0, 90, 0, 0), C(200, 120, 255), M.Neon)
	emitter(k, 4.2, { Texture = SMOKE, Color = ColorSequence.new(C(120, 50, 200), C(20, 0, 40)), Size = NumberSequence.new(0.6, 1.4), Transparency = NumberSequence.new(0.4, 1), Lifetime = NumberRange.new(0.8, 1.2), Rate = 8, Speed = NumberRange.new(0.3, 0.8), SpreadAngle = Vector2.new(180, 180), LightEmission = 0.4 })
	return 5.0
end

Builders.dragons_tail = function(k)
	body(k, { Length = 4.7, MaxD = 0.82, Color = C(190, 35, 35), Mat = M.SmoothPlastic, Grip = C(60, 20, 20), Handle = C(240, 225, 190), HandleMat = M.Marble, Cap = C(150, 25, 25) })
	-- Scales in rows, bone spikes down the back, horns at the tip.
	for row = 0, 4 do
		for i = 1, 6 do
			local a = (i + row * 0.5) / 6 * 2 * math.pi
			local y = 2.0 + row * 0.55
			local r = 0.3 + row * 0.02
			k.wedge(0.26, 0.3, 0.1, k.at(math.cos(a) * r, y, math.sin(a) * r, -15, -math.deg(a) - 90, 0), C(120, 20, 20), M.SmoothPlastic)
		end
	end
	for i = 0, 4 do
		spikeOut(k, math.pi / 2, 2.1 + i * 0.6, 0.38, 0.5 - i * 0.04, 0.2, C(240, 230, 200), M.Marble, 40)
	end
	for _, side in { -1, 1 } do
		for i = 0, 3 do
			local t = i / 3
			k.ball(0.18 - t * 0.1, 0.4, 0.18 - t * 0.1, k.at(side * (0.2 + t * 0.45), 4.8 + t * 0.35 - t * t * 0.3, 0.05, 0, 0, side * -(35 + t * 50)), C(240, 230, 200), M.Marble)
		end
	end
	k.ball(0.16, 0.16, 0.16, k.at(0, 4.55, -0.38), C(255, 200, 40), M.Neon) -- a dragon eye
	emitter(k, 4.8, { Texture = FIRE, Color = ColorSequence.new(C(255, 200, 80), C(255, 40, 20)), Size = NumberSequence.new(1, 0.1), Lifetime = NumberRange.new(0.4, 0.8), Rate = 14, Speed = NumberRange.new(1.5, 3), SpreadAngle = Vector2.new(20, 20), EmissionDirection = Enum.NormalId.Top })
	return 5.1
end

Builders.big_bang = function(k)
	local deep, mid, hot = C(70, 110, 255), C(170, 90, 255), C(255, 120, 220)
	body(k, {
		Length = 4.8,
		MaxD = 0.8,
		Color = mid,
		Mat = M.Neon,
		Gradient = function(t: number): Color3
			return if t < 0.5 then deep:Lerp(mid, t * 2) else mid:Lerp(hot, (t - 0.5) * 2)
		end,
		Handle = C(240, 240, 255),
		HandleMat = M.Marble,
		Grip = C(30, 25, 60),
		Cap = C(255, 255, 255),
	})
	-- A glass shell over the galaxy, stars inside, a ringed planet orbiting the tip.
	k.vcyl(3.1, 0.92, k.at(0, 3.1, 0), C(210, 220, 255), M.Glass, { T = 0.6 })
	for i = 1, 8 do
		local a = i * 2.2
		k.box(0.1, 0.1, 0.1, k.at(math.cos(a) * 0.48, 1.9 + i * 0.33, math.sin(a) * 0.48, 45, 45, 0), C(255, 255, 255), M.Neon)
	end
	k.ball(0.42, 0.42, 0.42, k.at(0.7, 4.6, 0), C(255, 190, 90), M.SmoothPlastic)
	k.torus(0.36, 0.05, 14, k.at(0.7, 4.6, 0, 75, 0, 25), C(255, 230, 180), M.Neon)
	k.torus(0.9, 0.05, 20, k.at(0, 3.8, 0, 80, 0, -15), C(255, 255, 255), M.Neon, { T = 0.3 })
	emitter(k, 4.4, {
		Texture = SPARKLE,
		Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, C(120, 200, 255)), ColorSequenceKeypoint.new(0.5, C(255, 140, 230)), ColorSequenceKeypoint.new(1, C(255, 240, 150)) }),
		Size = NumberSequence.new(0.5, 0),
		Lifetime = NumberRange.new(0.8, 1.4),
		Rate = 16,
		Speed = NumberRange.new(0.6, 1.6),
		SpreadAngle = Vector2.new(180, 180),
	})
	return 5.0
end

BatModels.Builders = Builders

-- Builds bat `id` with its Grip at `cframe`. Parts are unanchored and massless (welded to the
-- Grip); anchor the Grip for a display.
function BatModels.Build(id: string, cframe: CFrame): Model
	local bat = Bats.Get(id) or Bats.Get(Bats.StarterId)
	assert(bat, "no starter bat")
	local model = Instance.new("Model")
	model.Name = "Bat"
	model:SetAttribute("BatId", bat.Id)
	local grip = Instance.new("Part")
	grip.Name = "Grip"
	grip.Size = Vector3.new(0.3, 0.3, 0.3)
	grip.Transparency = 1
	grip.CanCollide = false
	grip.CanQuery = false
	grip.CanTouch = false
	grip.Massless = true
	grip.CFrame = cframe
	grip.Parent = model
	model.PrimaryPart = grip
	local color = Bats.Color(bat)
	local k = TreasureModels.Kit(model, grip, 1, color, color, Enum.Material.SmoothPlastic)
	local tip = (Builders[bat.Id] or Builders.wooden_bat)(k)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CastShadow = false
		end
	end
	local a = Instance.new("Attachment")
	a.Name = "TrailA"
	a.Position = Vector3.new(0, 1.6, 0)
	a.Parent = grip
	local b = Instance.new("Attachment")
	b.Name = "TrailB"
	b.Position = Vector3.new(0, tip, 0)
	b.Parent = grip
	local trail = Instance.new("Trail")
	trail.Name = "SwingTrail"
	trail.Attachment0 = a
	trail.Attachment1 = b
	trail.Color = ColorSequence.new(Bats.TrailColor(bat))
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.Lifetime = 0.25
	trail.LightEmission = if bat.Tier >= 5 then 1 else 0.3
	trail.FaceCamera = true
	trail.Enabled = false
	trail.Parent = grip
	return model
end

return BatModels
