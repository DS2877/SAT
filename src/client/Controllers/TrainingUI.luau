-- Bench-press panel. The server pays Strength out per rep ("TrainingRep"); this makes every rep
-- feel like a reward: a floating "+N 💪" pop (pitch rises with the combo), a combo meter that
-- fills while you keep tapping PUSH, MEGA REP jackpots, and a "next lift" goal that shows which
-- treasure you're training toward. Pushing the joystick / movement keys gets up.
-- While lying down every proximity prompt is hidden (no "Lift" button over your own bench).
-- Also announces "NEW LIFT!" whenever Strength (from any source) lets you carry a heavier
-- treasure at full speed. The lifting animation itself lives in BenchAnimator.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local Notifications = require(script.Parent.Notifications)

local TrainingUI = {}

local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local title: TextLabel
local rateLabel: TextLabel
local totalLabel: TextLabel
local comboFill: Frame
local comboLabel: TextLabel
local goalLabel: TextLabel
local goalFill: Frame
local pushButton: TextButton
local session = nil
local heartbeat: RBXScriptConnection? = nil
local ACTION = "SAT_BenchPush"

-- Treasures from lightest to heaviest: the "next lift" ladder.
local ladder = table.clone(Treasures.List)
table.sort(ladder, function(a, b)
	return a.Weight < b.Weight
end)

-- Strength needed to carry a weight at full speed.
local function easyStrength(weight: number): number
	return math.ceil(weight / GameConfig.Carry.EasyRatio)
end

local function strength(): number
	return tonumber(player:GetAttribute("Strength")) or GameConfig.Strength.Start
end

local function humanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function refreshGoal()
	if not goalLabel then
		return
	end
	local current = strength()
	for _, def in ladder do
		local need = easyStrength(def.Weight)
		if current < need then
			local color = Rarities.Info[def.Rarity] and Rarities.Info[def.Rarity].Color or Theme.Color.Text
			goalLabel.Text = ('NEXT LIFT: <font color="#%s">%s</font> at full speed  •  %s 💪'):format(
				color:ToHex(),
				def.Name:upper(),
				Kit.bigNumber(need)
			)
			goalFill.Size = UDim2.fromScale(math.clamp(current / need, 0, 1), 1)
			return
		end
	end
	goalLabel.Text = "YOU CAN CARRY EVERYTHING AT FULL SPEED 💪"
	goalFill.Size = UDim2.fromScale(1, 1)
end

local function setCombo(combo: number)
	local max = GameConfig.Training.ComboMax
	local bonus = math.floor(combo * GameConfig.Training.ComboBonusPerStack * 100 + 0.5)
	Kit.tween(comboFill, Theme.Motion.Fast, { Size = UDim2.fromScale(combo / max, 1) })
	comboFill.BackgroundColor3 = if combo >= max then Theme.Color.Gold else Theme.Color.Strength
	if combo <= 0 then
		comboLabel.Text = "TAP PUSH TO BUILD A COMBO"
	elseif combo >= max then
		comboLabel.Text = ("🔥 MAX COMBO x%d  •  +%d%%"):format(combo, bonus)
	else
		comboLabel.Text = ("COMBO x%d  •  +%d%%"):format(combo, bonus)
	end
end

-- Big floating reward text in the middle of the screen (above your lifter), so every rep lands.
local function pop(text: string, color: Color3, size: number)
	local label = Kit.label({
		Text = text,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5 + math.random(-12, 12) / 100, 0.4 + math.random(-4, 4) / 100),
		Size = UDim2.fromOffset(420, size + 12),
		Font = Theme.Font.Display,
		TextSize = size,
		TextColor3 = color,
		TextWrapped = false,
		ZIndex = 20,
		Parent = gui,
	})
	Kit.stroke(Color3.fromRGB(40, 22, 8), 3, 0).Parent = label
	local scale = Kit.new("UIScale", { Scale = 0.3, Parent = label })
	Kit.tween(scale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })
	local rise = TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	Kit.tween(label, rise, { Position = label.Position - UDim2.fromScale(0, 0.14) })
	task.delay(0.7, function()
		local fade = TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		Kit.tween(label, fade, { TextTransparency = 1 })
		local stroke = label:FindFirstChildOfClass("UIStroke")
		if stroke then
			Kit.tween(stroke, fade, { Transparency = 1 })
		end
	end)
	task.delay(1.3, function()
		label:Destroy()
	end)
end

local function onRep(payload)
	if not session or type(payload) ~= "table" or type(payload.Amount) ~= "number" then
		return
	end
	session.Total = payload.Total or (session.Total + payload.Amount)
	totalLabel.Text = ("+%s 💪"):format(Kit.bigNumber(session.Total))
	Kit.pulse(totalLabel)
	local combo = tonumber(payload.Combo) or 0
	setCombo(combo)
	if payload.Crit then
		pop(("MEGA REP!  +%s 💪"):format(Kit.bigNumber(payload.Amount)), Theme.Color.Gold, 60)
		Sounds.Play("MegaRep")
		Kit.pulse(panel)
	else
		local color = if combo > 0 then Theme.Color.Gold else Theme.Color.Strength
		pop(("+%s 💪"):format(Kit.bigNumber(payload.Amount)), color, 40 + 1.5 * math.min(combo, 10))
		Sounds.Play("Rep", 1, 1 + combo * 0.06)
	end
end

local function push()
	if not session then
		return
	end
	Net.Get("TrainingTap"):FireServer()
	Kit.pulse(pushButton)
	Sounds.Play("TrainGood", 0.4)
end

local function stop()
	if session and session.Total >= 1 then
		Notifications.Toast(("+%s 💪 STRENGTH FROM %d REPS"):format(Kit.bigNumber(session.Total), session.Reps), "Reward")
	end
	session = nil
	panel.Visible = false
	ProximityPromptService.Enabled = true
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
	ContextActionService:UnbindAction(ACTION)
end

local function start(payload)
	session = { Total = 0, Reps = 0, MovingFor = 0 }
	title.Text = ("🏋 %s"):format(tostring(payload.Name):upper())
	rateLabel.Text = ("+%s 💪 per rep  •  PUSH = 2x faster reps"):format(Kit.bigNumber(tonumber(payload.RepGain) or 0))
	totalLabel.Text = "+0 💪"
	setCombo(0)
	refreshGoal()
	panel.Visible = true
	ProximityPromptService.Enabled = false
	Sounds.Play("TrainPerfect", 0.6)

	if heartbeat then
		heartbeat:Disconnect()
	end
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not session then
			return
		end
		-- Push the stick / movement keys to get up.
		local hum = humanoid()
		if hum and hum.MoveDirection.Magnitude > 0.5 then
			session.MovingFor += dt
			if session.MovingFor > 0.25 then
				Net.Get("StopTraining"):FireServer()
				stop()
			end
		else
			session.MovingFor = 0
		end
	end)
	ContextActionService:BindActionAtPriority(ACTION, function(_, inputState)
		if inputState == Enum.UserInputState.Begin then
			push()
		end
		return Enum.ContextActionResult.Sink
	end, false, Enum.ContextActionPriority.High.Value, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
end

-- "NEW LIFT!" when Strength (training, extraction...) crosses a treasure's full-speed mark.
local function watchLifts()
	local last: number? = nil
	player:GetAttributeChangedSignal("Strength"):Connect(function()
		local current = strength()
		local previous = last
		last = current
		refreshGoal()
		if not previous or current <= previous then
			return -- first sync, or an Ascension reset
		end
		local unlocked = nil
		for _, def in ladder do
			local need = easyStrength(def.Weight)
			if previous < need and current >= need then
				unlocked = def -- ladder is sorted, so this ends on the heaviest
			end
		end
		if unlocked then
			Notifications.Banner("💪 NEW LIFT!", ("You now carry %s at full speed"):format(unlocked.Name:upper()), "Reward", 3)
			Sounds.Play("BigReward", 0.7)
		end
	end)
end

function TrainingUI.Init(screenGui: ScreenGui)
	gui = screenGui
	panel = Kit.panel({
		Name = "BenchPress",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(380, 176),
		Visible = false,
		Parent = gui,
	}, { Kit.padding(10, 14) })
	title = Kit.label({ Text = "", Size = UDim2.new(1, -130, 0, 24), Font = Theme.Font.Display, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	rateLabel = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -120, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	totalLabel = Kit.label({ Text = "+0 💪", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(150, 40), Font = Theme.Font.Display, TextSize = 28, TextColor3 = Theme.Color.Strength, TextXAlignment = Enum.TextXAlignment.Right, Parent = panel })

	-- Combo meter
	local comboBar = Kit.new("Frame", { Name = "Combo", Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 20), BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0, ClipsDescendants = true, Parent = panel })
	Kit.corner(Theme.Radius.Round).Parent = comboBar
	comboFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.Strength, BorderSizePixel = 0, Parent = comboBar })
	Kit.corner(Theme.Radius.Round).Parent = comboFill
	comboLabel = Kit.label({ Text = "", Size = UDim2.fromScale(1, 1), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, ZIndex = 2, Parent = comboBar })

	-- Next lift goal
	goalLabel = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 70), Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local goalBar = Kit.new("Frame", { Name = "Goal", Position = UDim2.fromOffset(0, 88), Size = UDim2.new(1, 0, 0, 5), BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0, Parent = panel })
	Kit.corner(Theme.Radius.Round).Parent = goalBar
	goalFill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = Theme.Color.Safe, BorderSizePixel = 0, Parent = goalBar })
	Kit.corner(Theme.Radius.Round).Parent = goalFill

	pushButton = Kit.button({
		Name = "Push",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, -66, 0, 52),
		Text = "PUSH! ⚡",
		Font = Theme.Font.Display,
		TextSize = 26,
		Parent = panel,
	}, push)
	Kit.button({
		Name = "Stop",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(56, 52),
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
			if session then
				-- Server totals are authoritative for the summary.
				session.Total = tonumber(payload.Gained) or session.Total
				session.Reps = tonumber(payload.Reps) or session.Reps
			end
			stop()
		end
	end)
	Net.Get("TrainingRep").OnClientEvent:Connect(function(payload)
		if session then
			session.Reps += 1
		end
		onRep(payload)
	end)
	watchLifts()
end

return TrainingUI
