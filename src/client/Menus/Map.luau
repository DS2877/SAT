-- Full-screen island map (opened from the board by the gate). Same drawing as the board
-- (UI/MapView), scaled to fit the menu body.

local UI = script.Parent.Parent.UI
local Kit = require(UI.Kit)
local MapView = require(UI.MapView)

local Map = {}

function Map.Build(root: Frame)
	local holder = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(MapView.WIDTH, MapView.HEIGHT),
		BackgroundTransparency = 1,
		Parent = root,
	})
	local scale = Kit.new("UIScale", { Parent = holder })
	local view = MapView.Build(holder)
	-- AbsoluteSize already includes every UIScale above us (the HUD's global phone scale, the
	-- menu's pop-in); divide it back out or the map gets scaled twice and ends up tiny.
	local function inheritedScale(): number
		local product = 1
		local node: Instance? = root
		while node do
			local s = node:FindFirstChildWhichIsA("UIScale")
			if s then
				product *= s.Scale
			end
			node = node.Parent
		end
		return product
	end
	local function fit()
		local size = root.AbsoluteSize / inheritedScale()
		if size.X > 0 and size.Y > 0 then
			scale.Scale = math.min(size.X / MapView.WIDTH, size.Y / MapView.HEIGHT)
		end
	end
	root:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
	return { Refresh = view.Refresh }
end

return Map
