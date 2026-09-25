-- 💬 Feedback: thumbs up / down plus an optional short message, sent to the developer
-- (Services/FeedbackService). No names or ids are stored with it.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)

local Feedback = {}

local UP, DOWN = Color3.fromRGB(70, 200, 110), Color3.fromRGB(230, 80, 80)

function Feedback.Build(root: Frame, menus)
	local vote = 0
	Kit.label({
		Text = "Enjoying the game?",
		Size = UDim2.new(1, 0, 0, 30),
		Font = Theme.Font.Display,
		TextSize = 26,
		TextColor3 = Theme.Color.Gold,
		Parent = root,
	})
	local buttons = {}
	local function paint()
		for value, button in buttons do
			local selected = vote == value
			button.BackgroundColor3 = if selected then (if value == 1 then UP else DOWN) else Theme.Color.ButtonAlt
			button.BackgroundTransparency = if selected or vote == 0 then 0 else 0.4
		end
	end
	for i, entry in { { 1, "👍" }, { -1, "👎" } } do
		local value = entry[1]
		buttons[value] = Kit.button({
			AnchorPoint = Vector2.new(0.5, 0),
			Position = UDim2.new(0.5, (i - 1.5) * 130, 0, 38),
			Size = UDim2.fromOffset(110, 70),
			Text = entry[2],
			TextSize = 42,
			BackgroundColor3 = Theme.Color.ButtonAlt,
			Parent = root,
		}, function()
			vote = if vote == value then 0 else value
			paint()
			Sounds.Play("Click")
		end)
	end
	local box = Kit.new("TextBox", {
		Position = UDim2.fromOffset(0, 122),
		Size = UDim2.new(1, 0, 1, -190),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		ClearTextOnFocus = false,
		MultiLine = true,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		Font = Theme.Font.Body,
		TextSize = 18,
		TextColor3 = Theme.Color.Text,
		PlaceholderText = "What should we add or fix? (optional)",
		PlaceholderColor3 = Theme.Color.TextDim,
		Text = "",
		Parent = root,
	}, { Kit.corner(Theme.Radius.Medium), Kit.padding(10) })
	local counter = Kit.label({
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, -8),
		Size = UDim2.fromOffset(160, 20),
		Font = Theme.Font.Bold,
		TextSize = Theme.TextSize.Small,
		TextColor3 = Theme.Color.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		Text = "",
		Parent = root,
	})
	local max = GameConfig.Feedback.MaxLength
	box:GetPropertyChangedSignal("Text"):Connect(function()
		local length = utf8.len(box.Text) or #box.Text
		if length > max then
			box.Text = box.Text:sub(1, (utf8.offset(box.Text, max + 1) or (#box.Text + 1)) - 1)
			length = max
		end
		counter.Text = ("%d / %d"):format(length, max)
	end)
	counter.Text = ("0 / %d"):format(max)
	Kit.button({
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(170, 50),
		Text = "SEND",
		Font = Theme.Font.Display,
		TextSize = 24,
		BackgroundColor3 = Theme.Color.Cash,
		TextColor3 = Color3.fromRGB(20, 40, 20),
		Parent = root,
	}, function()
		local text = box.Text
		if vote == 0 and text:match("^%s*$") then
			Sounds.Play("Error")
			return
		end
		Net.Get("SendFeedback"):FireServer(vote, text)
		box.Text = ""
		vote = 0
		paint()
		menus.Close()
	end)
	paint()
	return {
		Refresh = function() end,
	}
end

return Feedback
