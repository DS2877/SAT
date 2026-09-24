-- Juicy reward moments for numbers that should feel great (training reps, jackpots):
--   RewardFX.Pop(gui, opts)  - a big number that slams in with an overshoot, a gold gradient and
--                              a thick outline, shoots sparks, rings a shockwave, then floats up
--   RewardFX.Bump(label)     - squash-and-stretch on an existing counter
-- Pure UI (no gameplay). Everything cleans itself up.

local Theme = require(script.Parent.Theme)
local Kit = require(script.Parent.Kit)

local RewardFX = {}

local OUTLINE = Color3.fromRGB(46, 20, 6)

-- Gradient presets: top -> bottom.
RewardFX.Palette = {
	Warm = { Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 150, 50) },
	Hot = { Color3.fromRGB(255, 220, 120), Color3.fromRGB(255, 70, 40) },
	Gold = { Color3.fromRGB(255, 255, 210), Color3.fromRGB(255, 190, 30) },
	Cash = { Color3.fromRGB(220, 255, 190), Color3.fromRGB(60, 210, 90) },
	Rainbow = {
		Color3.fromRGB(255, 90, 90),
		Color3.fromRGB(255, 210, 60),
		Color3.fromRGB(100, 255, 120),
		Color3.fromRGB(90, 200, 255),
		Color3.fromRGB(200, 110, 255),
	},
}

local function gradient(colors: { Color3 }, rotation: number): UIGradient
	local points = {}
	for i, color in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / math.max(1, #colors - 1), color))
	end
	return Kit.new("UIGradient", { Color = ColorSequence.new(points), Rotation = rotation })
end

-- Sparks shooting out of a point (little rounded bars that fly and fade).
function RewardFX.Sparks(parent: Instance, position: UDim2, color: Color3, count: number, reach: number)
	for i = 1, count do
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local length = math.random(14, 26)
		local spark = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = position,
			Size = UDim2.fromOffset(length, 5),
			Rotation = math.deg(angle),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
			ZIndex = 21,
			Parent = parent,
		})
		Kit.corner(UDim.new(1, 0)).Parent = spark
		local distance = reach * (0.7 + math.random() * 0.5)
		local target = position + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance)
		Kit.tween(spark, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Position = target,
			Size = UDim2.fromOffset(4, 3),
			BackgroundTransparency = 1,
		})
		task.delay(0.5, function()
			spark:Destroy()
		end)
	end
end

-- An expanding ring (shockwave) behind the number.
function RewardFX.Ring(parent: Instance, position: UDim2, color: Color3, size: number)
	local ring = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = position,
		Size = UDim2.fromOffset(size * 0.3, size * 0.3),
		BackgroundTransparency = 1,
		ZIndex = 19,
		Parent = parent,
	})
	Kit.corner(UDim.new(1, 0)).Parent = ring
	local stroke = Kit.new("UIStroke", { Color = color, Thickness = 6, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = ring })
	local info = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Kit.tween(ring, info, { Size = UDim2.fromOffset(size * 1.6, size * 1.6) })
	Kit.tween(stroke, info, { Transparency = 1, Thickness = 1 })
	task.delay(0.55, function()
		ring:Destroy()
	end)
end

-- opts: { Text, SubText?, Position (UDim2), Size (text px), Palette ({Color3}), Sparks?, Ring?,
--         Hold? (seconds before it floats away), Spark (Color3) }
function RewardFX.Pop(parent: Instance, opts)
	local size = opts.Size or 56
	local holder = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = opts.Position,
		Size = UDim2.fromOffset(600, size * 1.9),
		BackgroundTransparency = 1,
		ZIndex = 20,
		Parent = parent,
	})
	local scale = Kit.new("UIScale", { Scale = 0.2, Parent = holder })
	local main = Kit.label({
		Text = opts.Text,
		Size = UDim2.new(1, 0, 0, size + 8),
		Font = Theme.Font.Display,
		TextSize = size,
		TextColor3 = Color3.new(1, 1, 1),
		TextWrapped = false,
		ZIndex = 22,
		Parent = holder,
	})
	gradient(opts.Palette or RewardFX.Palette.Warm, 90).Parent = main
	local outline = Kit.textStroke(OUTLINE, math.max(3, size / 14))
	outline.Parent = main
	local sub: TextLabel? = nil
	if opts.SubText then
		sub = Kit.label({
			Text = opts.SubText,
			Position = UDim2.fromOffset(0, size + 2),
			Size = UDim2.new(1, 0, 0, math.floor(size * 0.42)),
			Font = Theme.Font.Display,
			TextSize = math.floor(size * 0.42),
			TextColor3 = Color3.fromRGB(255, 245, 225),
			TextWrapped = false,
			ZIndex = 22,
			Parent = holder,
		})
		Kit.textStroke(OUTLINE, 2.5).Parent = sub :: TextLabel
	end

	-- Slam in with an overshoot and a little tilt, then settle.
	holder.Rotation = math.random(-9, 9)
	Kit.tween(scale, TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Scale = 1.35 })
	task.delay(0.13, function()
		Kit.tween(scale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
		Kit.tween(holder, TweenInfo.new(0.22, Enum.EasingStyle.Back), { Rotation = 0 })
	end)
	local center = opts.Position
	if opts.Ring ~= false then
		RewardFX.Ring(parent, center, opts.Spark or Color3.fromRGB(255, 210, 90), size * 2)
	end
	if opts.Sparks and opts.Sparks > 0 then
		RewardFX.Sparks(parent, center, opts.Spark or Color3.fromRGB(255, 220, 110), opts.Sparks, size * 2.2)
	end

	-- Float up and fade.
	local hold = opts.Hold or 0.55
	task.delay(hold, function()
		local info = TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.tween(holder, info, { Position = holder.Position - UDim2.fromOffset(0, size * 1.4) })
		Kit.tween(main, info, { TextTransparency = 1 })
		Kit.tween(outline, info, { Transparency = 1 })
		Kit.tween(scale, info, { Scale = 0.85 })
		if sub then
			Kit.tween(sub, info, { TextTransparency = 1 })
			local subStroke = sub:FindFirstChildOfClass("UIStroke")
			if subStroke then
				Kit.tween(subStroke, info, { Transparency = 1 })
			end
		end
	end)
	task.delay(hold + 0.65, function()
		holder:Destroy()
	end)
	return holder
end

-- Squash-and-stretch bump on a counter (needs no setup; adds its own UIScale once).
function RewardFX.Bump(label: GuiObject, amount: number?)
	local scale = label:FindFirstChild("BumpScale") :: UIScale?
	if not scale then
		scale = Kit.new("UIScale", { Name = "BumpScale", Parent = label })
	end
	local s = scale :: UIScale
	s.Scale = 1 + (amount or 0.28)
	Kit.tween(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
end

return RewardFX
