-- Small component kit so screens stay consistent and short.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Sounds = require(script.Parent.Sounds)

local Kit = {}

function Kit.new(className: string, props: { [string]: any }?, children: { Instance }?): any
	local inst = Instance.new(className)
	if props then
		local parent = props.Parent
		for key, value in props do
			if key ~= "Parent" then
				(inst :: any)[key] = value
			end
		end
		if children then
			for _, child in children do
				child.Parent = inst
			end
		end
		if parent then
			inst.Parent = parent
		end
	elseif children then
		for _, child in children do
			child.Parent = inst
		end
	end
	return inst
end

function Kit.corner(radius: UDim?): UICorner
	return Kit.new("UICorner", { CornerRadius = radius or Theme.Radius.Medium })
end

function Kit.stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return Kit.new("UIStroke", {
		Color = color or Theme.Color.PanelStroke,
		Thickness = thickness or 1.5,
		Transparency = transparency or Theme.Transparency.Stroke,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function Kit.padding(all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return Kit.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function Kit.list(direction: Enum.FillDirection?, spacing: number?, hAlign: Enum.HorizontalAlignment?, vAlign: Enum.VerticalAlignment?): UIListLayout
	return Kit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, spacing or Theme.Space.S),
		HorizontalAlignment = hAlign or Enum.HorizontalAlignment.Center,
		VerticalAlignment = vAlign or Enum.VerticalAlignment.Top,
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function Kit.label(props): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Body,
		TextColor3 = Theme.Color.Text,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 24),
	}
	for k, v in props do
		defaults[k] = v
	end
	return Kit.new("TextLabel", defaults)
end

function Kit.panel(props, children: { Instance }?): Frame
	local defaults = {
		BackgroundColor3 = Theme.Color.Panel,
		BackgroundTransparency = Theme.Transparency.Panel,
		BorderSizePixel = 0,
	}
	for k, v in props do
		if k ~= "Radius" then
			defaults[k] = v
		end
	end
	local frame = Kit.new("Frame", defaults, children)
	Kit.corner(props.Radius).Parent = frame
	Kit.stroke().Parent = frame
	return frame
end

function Kit.tween(inst: Instance, info: TweenInfo, goal: { [string]: any }): Tween
	local tween = TweenService:Create(inst, info, goal)
	tween:Play()
	return tween
end

-- Chunky, touch-friendly button with press feedback. onClick receives no args.
function Kit.button(props, onClick: (() -> ())?): TextButton
	local defaults = {
		BackgroundColor3 = Theme.Color.Button,
		TextColor3 = Theme.Color.ButtonText,
		Font = Theme.Font.Black,
		TextSize = Theme.TextSize.Heading,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(160, 52),
		Text = "",
	}
	for k, v in props do
		if k ~= "Radius" then
			defaults[k] = v
		end
	end
	local button = Kit.new("TextButton", defaults)
	Kit.corner(props.Radius or Theme.Radius.Medium).Parent = button
	local scale = Kit.new("UIScale", { Parent = button })
	button.MouseButton1Down:Connect(function()
		Kit.tween(scale, Theme.Motion.Fast, { Scale = 0.92 })
	end)
	local function release()
		Kit.tween(scale, Theme.Motion.Pop, { Scale = 1 })
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
	if onClick then
		button.Activated:Connect(function()
			Sounds.Play("Click")
			onClick()
		end)
	end
	return button
end

function Kit.formatCash(n: number): string
	n = math.floor(n)
	local s = tostring(math.abs(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return (if n < 0 then "-$" else "$") .. formatted
end

function Kit.shortCash(n: number): string
	if n >= 1e6 then
		local s = ("$%.2fM"):format(n / 1e6):gsub("%.?0+M$", "M")
		return s
	elseif n >= 1e4 then
		local s = ("$%.1fK"):format(n / 1e3):gsub("%.0K$", "K")
		return s
	end
	return Kit.formatCash(n)
end

-- Temporarily pops an element (scale bump) to draw the eye to a change.
function Kit.pulse(guiObject: GuiObject)
	local scale = guiObject:FindFirstChild("PulseScale") :: UIScale?
	if not scale then
		scale = Kit.new("UIScale", { Name = "PulseScale", Parent = guiObject })
	end
	(scale :: UIScale).Scale = 1.18
	Kit.tween(scale :: UIScale, Theme.Motion.Pop, { Scale = 1 })
end

return Kit
