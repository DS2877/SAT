-- Treadmill panel. While running: running animation, live Strength counter, SPRINT button
-- (tap / Space / A / click) and STOP. Pushing the joystick or movement keys also steps off.
-- The counter is a local estimate between server commits; the Strength pill is authoritative.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local Notifications = require(script.Parent.Notifications)

local TrainingUI = {}

local player = Players.LocalPlayer
local panel: Frame
local title: TextLabel
local rateLabel: TextLabel
local gainedLabel: TextLabel
local sprintButton: TextButton
local session = nil
local heartbeat: RBXScriptConnection? = nil
local runTrack: AnimationTrack? = nil
local ACTION = "SAT_TreadmillSprint"

-- Default Roblox run animations (R15 / R6).
local RUN_ANIMATION = { R15 = "rbxassetid://913376220", R6 = "rbxassetid://180426354" }

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function playRun()
	local hum = humanoid()
	local animator = hum and hum:FindFirstChildOfClass("Animator")
	if not hum or not animator then
		return
	end
	local animation = Instance.new("Animation")
	animation.AnimationId = if hum.RigType == Enum.HumanoidRigType.R15 then RUN_ANIMATION.R15 else RUN_ANIMATION.R6
	local ok, track = pcall(function()
		return (animator :: Animator):LoadAnimation(animation)
	end)
	if ok and track then
		track.Looped = true
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.2)
		runTrack = track
	end
end

local function stopRun()
	if runTrack then
		runTrack:Stop(0.2)
		runTrack = nil
	end
end

local function sprint()
	if not session then
		return
	end
	session.SprintUntil = os.clock() + GameConfig.Training.SprintDuration
	Net.Get("TrainingTap"):FireServer()
	Kit.pulse(sprintButton)
	Sounds.Play("TrainGood", 0.5)
end

local function stop()
	if session and session.Gained >= 1 then
		Notifications.Toast(("+%d 💪 STRENGTH FROM TRAINING"):format(math.floor(session.Gained)), "Reward")
	end
	session = nil
	panel.Visible = false
	stopRun()
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	ContextActionService:UnbindAction(ACTION)
end

local function start(payload)
	session = {
		Rate = payload.Rate,
		Multiplier = payload.SprintMultiplier or 2,
		Position = payload.Position,
		LeaveDistance = payload.LeaveDistance or 6,
		Gained = 0,
		SprintUntil = 0,
		MovingFor = 0,
	}
	title.Text = ("🏃 %s"):format(tostring(payload.Name):upper())
	rateLabel.Text = ("+%.2f 💪 per second"):format(payload.Rate)
	gainedLabel.Text = "+0.0"
	panel.Visible = true
	stopRun()
	playRun()
	Sounds.Play("TrainPerfect", 0.6)

	if heartbeat then
		heartbeat:Disconnect()
	end
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not session then
			return
		end
		local sprinting = os.clock() < session.SprintUntil
		session.Gained += session.Rate * dt * (if sprinting then session.Multiplier else 1)
		gainedLabel.Text = ("+%.1f"):format(session.Gained)
		gainedLabel.TextColor3 = if sprinting then Theme.Color.Gold else Theme.Color.Strength
		if runTrack then
			runTrack:AdjustSpeed(if sprinting then 1.7 else 1)
		end
		-- Push the stick / movement keys to step off.
		local hum = humanoid()
		if hum and hum.MoveDirection.Magnitude > 0.5 then
			session.MovingFor += dt
			if session.MovingFor > 0.25 then
				Net.Get("StopTraining"):FireServer()
				stop()
			end
		elseif session then
			session.MovingFor = 0
		end
	end)
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			sprint()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

function TrainingUI.Init(gui: ScreenGui)
	panel = Kit.panel({
		Name = "Treadmill",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(360, 118),
		Visible = false,
		Parent = gui,
	}, { Kit.padding(10, 14) })
	title = Kit.label({ Text = "", Size = UDim2.new(1, -110, 0, 24), Font = Theme.Font.Display, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	rateLabel = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -110, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	gainedLabel = Kit.label({ Text = "+0.0", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(110, 40), Font = Theme.Font.Display, TextSize = 30, TextColor3 = Theme.Color.Strength, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })
	sprintButton = Kit.button({
		Name = "Sprint",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -66, 0, 50),
		Text = "SPRINT! ⚡",
		Font = Theme.Font.Display,
		TextSize = 26,
		Parent = panel,
	}, sprint)
	Kit.button({
		Name = "Stop",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(56, 50),
		Text = "✕",
		BackgroundColor3 = Theme.Color.ButtonAlt,
		TextColor3 = Theme.Color.Text,
		Parent = panel,
	}, function()
		Net.Get("StopTraining"):FireServer()
		stop()
	end)

	Net.Get("TrainingState").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Active then
			start(payload)
		else
			if session and type(payload.Gained) == "number" then
				session.Gained = payload.Gained -- server total is authoritative for the summary
			end
			stop()
		end
	end)
end

return TrainingUI
