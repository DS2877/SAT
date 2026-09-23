-- Timing-bar training minigame. Marker position comes from server time so the client shows
-- exactly what the server will grade. Tap: big button (touch), Space/click (PC), A (gamepad).

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local TrainingTiming = require(Shared.Logic.TrainingTiming)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)

local TrainingUI = {}

local panel: Frame
local marker: Frame
local perfectZone: Frame
local goodZone: Frame
local title: TextLabel
local repsLabel: TextLabel
local popup: TextLabel
local session = nil
local renderConnection: RBXScriptConnection? = nil
local ACTION = "SAT_TrainTap"

local GRADE_STYLE = {
	Perfect = { Text = "PERFECT!", Color = Theme.Color.Gold, Sound = "TrainPerfect" },
	Good = { Text = "GOOD", Color = Theme.Color.Safe, Sound = "TrainGood" },
	Miss = { Text = "MISS", Color = Theme.Color.TextDim, Sound = "TrainMiss" },
}

local function tap()
	if not session then
		return
	end
	Net.Get("TrainingTap"):FireServer(workspace:GetServerTimeNow())
end

local function stop()
	session = nil
	panel.Visible = false
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	ContextActionService:UnbindAction(ACTION)
end

local function start(payload)
	session = payload
	local stationCfg = GameConfig.Training.Stations[payload.StationId]
	title.Text = (stationCfg and stationCfg.Name or "TRAINING"):upper()
	repsLabel.Text = ("0 / %d"):format(payload.Reps)
	perfectZone.Size = UDim2.fromScale(payload.PerfectWindow * 2, 1)
	goodZone.Size = UDim2.fromScale(payload.GoodWindow * 2, 1)
	panel.Visible = true
	if renderConnection then
		renderConnection:Disconnect()
	end
	renderConnection = RunService.RenderStepped:Connect(function()
		if session then
			local position = TrainingTiming.MarkerPosition(workspace:GetServerTimeNow() - session.StartedAt, session.Period)
			marker.Position = UDim2.fromScale(position, 0.5)
		end
	end)
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			tap()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA, Enum.UserInputType.MouseButton1)
end

local function showRep(payload)
	local style = GRADE_STYLE[payload.Grade] or GRADE_STYLE.Miss
	Sounds.Play(style.Sound)
	popup.Text = if payload.Gain > 0 then ("%s  +%d 💪"):format(style.Text, payload.Gain) else style.Text
	popup.TextColor3 = style.Color
	popup.Visible = true
	Kit.pulse(popup)
	if session then
		repsLabel.Text = ("%d / %d"):format(payload.Rep, session.Reps)
	end
	local token = {}
	TrainingUI._popupToken = token
	task.delay(0.7, function()
		if TrainingUI._popupToken == token then
			popup.Visible = false
		end
	end)
end

function TrainingUI.Init(gui: ScreenGui)
	panel = Kit.panel({
		Name = "Training",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -130),
		Size = UDim2.fromOffset(440, 170),
		Visible = false,
		Parent = gui,
	}, { Kit.padding(12, 16) })
	title = Kit.label({ Text = "STONE LIFT", Size = UDim2.new(1, -90, 0, 28), Font = Theme.Font.Display, TextSize = 26, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	repsLabel = Kit.label({ Text = "0 / 8", Position = UDim2.new(1, -90, 0, 0), Size = UDim2.fromOffset(90, 28), Font = Theme.Font.Display, TextSize = 22, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })

	local bar = Kit.new("Frame", {
		Name = "Bar",
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundColor3 = Theme.Color.PanelLight,
		BorderSizePixel = 0,
		Parent = panel,
	}, { Kit.corner(Theme.Radius.Small) })
	goodZone = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Theme.Color.Safe, BackgroundTransparency = 0.45, BorderSizePixel = 0, Parent = bar })
	perfectZone = Kit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), BackgroundColor3 = Theme.Color.Gold, BorderSizePixel = 0, Parent = bar })
	marker = Kit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.new(0, 8, 1, 14),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = bar,
	}, { Kit.corner(Theme.Radius.Round), Kit.stroke(Color3.new(0, 0, 0), 2, 0.3) })

	Kit.button({
		Name = "Tap",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, 0),
		Size = UDim2.new(0.62, 0, 0, 56),
		Text = "LIFT!",
		Font = Theme.Font.Display,
		TextSize = 30,
		Parent = panel,
	}, tap)
	Kit.button({
		Name = "Close",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 0, 1, 0),
		Size = UDim2.fromOffset(56, 56),
		Text = "✕",
		BackgroundColor3 = Theme.Color.ButtonAlt,
		TextColor3 = Theme.Color.Text,
		Parent = panel,
	}, function()
		Net.Get("StopTraining"):FireServer()
	end)
	popup = Kit.label({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -8),
		Size = UDim2.fromOffset(400, 44),
		Font = Theme.Font.Display,
		TextSize = 38,
		TextStrokeTransparency = 0.2,
		Visible = false,
		Parent = panel,
	})

	Net.Get("TrainingState").OnClientEvent:Connect(function(payload)
		if payload.Active then
			start(payload)
		else
			stop()
		end
	end)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.Type == "TrainingRep" then
			showRep(payload)
		end
	end)
end

return TrainingUI
