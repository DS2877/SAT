-- Bench-press panel. Training is a waiting game: lie down and the reps come by themselves
-- (server: Services/Training, maths: Logic/Lifting). This controller makes the wait feel great:
--   * a big session total that rolls up like a slot counter on every rep
--   * the PUMP meter heating up with every rep in a row (pitch and pop size rise with it)
--   * set pips filling toward SET COMPLETE (confetti + bonus)
--   * MEGA REP and the rare GOLDEN REP jackpots (flash, shake, fanfare)
--   * a "next lift" goal with an ETA, so you always know what you are waiting for
-- Pushing the joystick / movement keys (or GET UP) gets up. While lying down every proximity prompt
-- is hidden. Also announces "NEW LIFT!" whenever Strength (from any source) lets you carry a
-- heavier treasure at full speed. The lifting animation itself lives in BenchAnimator.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Lifting = require(Shared.Logic.Lifting)
local Monetization = require(Shared.Config.Monetization)
local Net = require(Shared.Net)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local RewardFX = require(UI.RewardFX)
local Notifications = require(script.Parent.Notifications)
local Effects = require(script.Parent.Effects)

local TrainingUI = {}
TrainingUI.OpenStore = nil :: (() -> ())? -- injected by Main

local cfg = GameConfig.Training
local player = Players.LocalPlayer
local gui: ScreenGui
local panel: Frame
local stopButton: TextButton
local title: TextLabel
local rateLabel: TextLabel
local totalLabel: TextLabel
local pumpFill: Frame
local pumpLabel: TextLabel
local pumpGradient: UIGradient
local pips: { Frame } = {}
local setLabel: TextLabel
local goalLabel: TextLabel
local goalFill: Frame
local flash: Frame
local boostButton: TextButton
local session = nil
local heartbeat: RBXScriptConnection? = nil

local PUMP_COLD = Color3.fromRGB(255, 170, 80)
local PUMP_HOT = Color3.fromRGB(255, 60, 40)
local PIP_EMPTY = Color3.fromRGB(60, 52, 70)

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

local function formatDuration(seconds: number): string
	if seconds < 60 then
		return ("%ds"):format(math.max(1, math.ceil(seconds)))
	elseif seconds < 3600 then
		return ("%dm %02ds"):format(seconds // 60, math.floor(seconds % 60))
	end
	return ("%dh %02dm"):format(seconds // 3600, math.floor(seconds % 3600 / 60))
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
			local eta = ""
			if session and session.RepGain > 0 then
				local rate = Lifting.ExpectedRate(session.RepGain, 600)
				eta = ("  •  ⏱ %s"):format(formatDuration((need - current) / rate))
			end
			goalLabel.Text = ('NEXT: <font color="#%s">%s</font> at full speed  •  %s 💪%s'):format(
				color:ToHex(),
				def.Name:upper(),
				Kit.bigNumber(need),
				eta
			)
			Kit.tween(goalFill, Theme.Motion.Fast, { Size = UDim2.fromScale(math.clamp(current / need, 0, 1), 1) })
			return
		end
	end
	goalLabel.Text = "YOU CAN CARRY EVERYTHING AT FULL SPEED 💪"
	goalFill.Size = UDim2.fromScale(1, 1)
end

local function setPump(pump: number)
	local t = math.clamp((pump - 1) / (cfg.PumpMax - 1), 0, 1)
	Kit.tween(pumpFill, TweenInfo.new(0.4, Enum.EasingStyle.Quad), { Size = UDim2.fromScale(math.max(0.04, t), 1) })
	pumpFill.BackgroundColor3 = PUMP_COLD:Lerp(PUMP_HOT, t)
	if t >= 1 then
		pumpLabel.Text = ("🔥🔥 MAX PUMP  x%.2f"):format(pump)
		pumpFill.BackgroundColor3 = Theme.Color.Gold
	elseif t > 0 then
		pumpLabel.Text = ("🔥 PUMP x%.2f  •  stay to heat up"):format(pump)
	else
		pumpLabel.Text = "PUMP x1.00  •  every rep in a row pays more"
	end
end

local function setPips(reps: number)
	local filled = reps % cfg.SetSize
	for i, pip in pips do
		local on = i <= filled
		pip.BackgroundColor3 = if on then Theme.Color.Strength else PIP_EMPTY
	end
end

-- Big reward number above your lifter (RewardFX: slam-in, gradient, sparks, shockwave).
local function pop(text: string, sub: string?, palette, size: number, sparks: number, y: number?)
	RewardFX.Pop(gui, {
		Text = text,
		SubText = sub,
		Position = UDim2.fromScale(0.5 + math.random(-5, 5) / 100, (y or 0.36) + math.random(-2, 2) / 100),
		Size = size,
		Palette = palette,
		Sparks = sparks,
		Spark = palette[#palette],
	})
end

-- Confetti burst from a screen point: little spinning squares flying out and falling.
local CONFETTI = {
	Color3.fromRGB(255, 200, 60),
	Color3.fromRGB(255, 110, 150),
	Color3.fromRGB(110, 220, 255),
	Color3.fromRGB(140, 255, 120),
	Color3.fromRGB(255, 150, 70),
}
local function confetti(count: number, origin: UDim2)
	for i = 1, count do
		local piece = Kit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = origin,
			Size = UDim2.fromOffset(math.random(8, 14), math.random(5, 9)),
			BackgroundColor3 = CONFETTI[i % #CONFETTI + 1],
			BorderSizePixel = 0,
			Rotation = math.random(0, 360),
			ZIndex = 19,
			Parent = gui,
		})
		local angle = math.random() * math.pi * 2
		local distance = math.random(120, 320)
		local target = origin + UDim2.fromOffset(math.cos(angle) * distance, math.sin(angle) * distance * 0.6 + 140)
		local info = TweenInfo.new(math.random(9, 14) / 10, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		Kit.tween(piece, info, { Position = target, Rotation = piece.Rotation + math.random(-540, 540), BackgroundTransparency = 1 })
		task.delay(1.5, function()
			piece:Destroy()
		end)
	end
end

local function screenFlash(color: Color3, strength_: number)
	flash.BackgroundColor3 = color
	flash.BackgroundTransparency = 1 - strength_
	flash.Visible = true
	Kit.tween(flash, TweenInfo.new(0.7, Enum.EasingStyle.Quad), { BackgroundTransparency = 1 })
	task.delay(0.72, function()
		flash.Visible = false
	end)
end

local function onRep(payload)
	if not session or type(payload) ~= "table" or type(payload.Amount) ~= "number" then
		return
	end
	local pump = tonumber(payload.Pump) or 1
	local wasMax = session.Pump >= cfg.PumpMax
	session.Pump = pump
	session.Reps = tonumber(payload.Reps) or (session.Reps + 1)
	session.Target = tonumber(payload.Total) or (session.Target + payload.Amount)
	setPump(pump)
	setPips(session.Reps)

	local heat = math.clamp((pump - 1) / (cfg.PumpMax - 1), 0, 1)
	local amount = Kit.bigNumber(payload.Amount)
	if payload.Kind == "Golden" then
		pop("+" .. amount, "✨ GOLDEN REP ✨", RewardFX.Palette.Rainbow, 104, 22, 0.32)
		screenFlash(Theme.Color.Gold, 0.55)
		confetti(40, UDim2.fromScale(0.5, 0.34))
		Effects.Shake(1.2, 0.5)
		Sounds.Play("GoldenRep")
		RewardFX.Bump(panel, 0.08)
	elseif payload.Kind == "Mega" then
		pop("+" .. amount, "💥 MEGA REP!", RewardFX.Palette.Gold, 84, 16)
		Effects.Shake(0.5, 0.25)
		Sounds.Play("MegaRep")
		RewardFX.Bump(panel, 0.05)
	else
		local sub = if heat > 0 then ("💪 PUMP x%.2f"):format(pump) else "💪"
		pop("+" .. amount, sub, if heat >= 1 then RewardFX.Palette.Hot else RewardFX.Palette.Warm, 56 + math.floor(26 * heat), 6 + math.floor(6 * heat))
		Sounds.Play("Rep", 0.8 + 0.3 * heat, 1 + 0.35 * heat)
	end
	RewardFX.Bump(totalLabel)

	local bonus = tonumber(payload.SetBonus) or 0
	if bonus > 0 then
		task.delay(0.35, function()
			pop("+" .. Kit.bigNumber(bonus), ("🏆 SET %d COMPLETE! BONUS"):format(tonumber(payload.Sets) or 0), RewardFX.Palette.Cash, 70, 12, 0.24)
			confetti(24, UDim2.fromScale(0.5, 0.3))
			Sounds.Play("SetComplete")
			for _, pip in pips do
				pip.BackgroundColor3 = Theme.Color.Gold
			end
			task.delay(0.5, function()
				if session then
					setPips(session.Reps)
				end
			end)
		end)
	end
	if not wasMax and pump >= cfg.PumpMax then
		Notifications.Banner("🔥 MAX PUMP!", "Every rep now pays the most - keep lifting", "Reward", 2.5)
		Sounds.Play("PumpMax")
	end
	refreshGoal()
end

local function stop()
	if session and session.Target >= 1 then
		Notifications.Toast(
			("+%s 💪 FROM %d REPS%s"):format(
				Kit.bigNumber(session.Target),
				session.Reps,
				if session.Sets > 0 then (" • %d SETS"):format(session.Sets) else ""
			),
			"Reward"
		)
	end
	session = nil
	panel.Visible = false
	stopButton.Visible = false
	ProximityPromptService.Enabled = true
	if heartbeat then
		heartbeat:Disconnect()
		heartbeat = nil
	end
end

local function start(payload)
	session = { Target = 0, Shown = 0, Reps = 0, Sets = 0, Pump = 1, MovingFor = 0, RepGain = tonumber(payload.RepGain) or 0 }
	title.Text = ("🏋 %s"):format(tostring(payload.Name):upper())
	rateLabel.Text = ("+%s 💪 per rep  •  relax, the reps come by themselves"):format(Kit.bigNumber(session.RepGain))
	totalLabel.Text = "+0 💪"
	setPump(1)
	setPips(0)
	setLabel.Text = ("SET BONUS +%d%% EVERY %d REPS"):format(math.floor(cfg.SetBonus * 100 + 0.5), cfg.SetSize)
	refreshGoal()
	panel.Visible = true
	stopButton.Visible = true
	ProximityPromptService.Enabled = false
	Sounds.Play("TrainPerfect", 0.6)

	if heartbeat then
		heartbeat:Disconnect()
	end
	heartbeat = RunService.Heartbeat:Connect(function(dt)
		if not session then
			return
		end
		-- Slot-machine counter: the total rolls up toward the server's figure.
		if session.Shown < session.Target then
			session.Shown = math.min(session.Target, session.Shown + math.max(1, (session.Target - session.Shown) * dt * 8))
			totalLabel.Text = ("+%s 💪"):format(Kit.bigNumber(math.floor(session.Shown)))
		end
		-- Push the stick / movement keys (or jump) to get up.
		local hum = humanoid()
		if hum and hum.Jump then
			Net.Get("StopTraining"):FireServer()
			stop()
			return
		end
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
			confetti(20, UDim2.fromScale(0.5, 0.22))
		end
	end)
end

local function bar(parent: Instance, y: number, height: number): (Frame, Frame)
	local back = Kit.new("Frame", { Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, height), BackgroundColor3 = Theme.Color.PanelLight, BorderSizePixel = 0, ClipsDescendants = true, Parent = parent })
	Kit.corner(Theme.Radius.Round).Parent = back
	local fill = Kit.new("Frame", { Size = UDim2.fromScale(0, 1), BorderSizePixel = 0, Parent = back })
	Kit.corner(Theme.Radius.Round).Parent = fill
	return back, fill
end

function TrainingUI.Init(screenGui: ScreenGui)
	gui = screenGui
	flash = Kit.new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, Visible = false, ZIndex = 18, Parent = gui })

	panel = Kit.panel({
		Name = "BenchPress",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24),
		Size = UDim2.fromOffset(400, 172),
		Visible = false,
		Parent = gui,
	}, { Kit.padding(10, 14) })
	title = Kit.label({ Text = "", Size = UDim2.new(1, -170, 0, 24), Font = Theme.Font.Display, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	rateLabel = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, -150, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, TextXAlignment = Enum.TextXAlignment.Left, TextWrapped = true, Parent = panel })
	totalLabel = Kit.label({ Text = "+0 💪", AnchorPoint = Vector2.new(1, 0), Position = UDim2.fromScale(1, 0), Size = UDim2.fromOffset(170, 42), Font = Theme.Font.Display, TextSize = 34, TextColor3 = Color3.new(1, 1, 1), TextXAlignment = Enum.TextXAlignment.Right, TextWrapped = false, Parent = panel })
	Kit.new("UIGradient", { Color = ColorSequence.new(Color3.fromRGB(255, 236, 140), Color3.fromRGB(255, 140, 50)), Rotation = 90, Parent = totalLabel })
	Kit.textStroke(Color3.fromRGB(46, 20, 6), 2.5).Parent = totalLabel

	-- Pump meter
	local pumpBar
	pumpBar, pumpFill = bar(panel, 48, 22)
	pumpGradient = Kit.new("UIGradient", {
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 0.25) }),
		Parent = pumpFill,
	})
	pumpLabel = Kit.label({ Text = "", Size = UDim2.fromScale(1, 1), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, ZIndex = 2, Parent = pumpBar })

	-- Set pips
	local pipRow = Kit.new("Frame", { Position = UDim2.fromOffset(0, 76), Size = UDim2.new(1, 0, 0, 16), BackgroundTransparency = 1, Parent = panel }, {
		Kit.list(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center),
	})
	for i = 1, cfg.SetSize do
		local pip = Kit.new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(14, 14), BackgroundColor3 = PIP_EMPTY, BorderSizePixel = 0, Parent = pipRow })
		Kit.corner(UDim.new(1, 0)).Parent = pip
		table.insert(pips, pip)
	end
	setLabel = Kit.label({ Text = "", LayoutOrder = 99, Size = UDim2.fromOffset(200, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Cash, TextXAlignment = Enum.TextXAlignment.Left, Parent = pipRow })

	-- Next lift goal + ETA
	goalLabel = Kit.label({ Text = "", Position = UDim2.fromOffset(0, 98), Size = UDim2.new(1, 0, 0, 16), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.TextDim, RichText = true, TextXAlignment = Enum.TextXAlignment.Left, Parent = panel })
	local _, fill = bar(panel, 117, 6)
	goalFill = fill
	goalFill.BackgroundColor3 = Theme.Color.Safe

	Kit.button({
		Name = "Stop",
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(0.58, -4, 0, 30),
		Text = "✖ STOP",
		TextSize = Theme.TextSize.Small,
		BackgroundColor3 = Theme.Color.Danger,
		TextColor3 = Color3.new(1, 1, 1),
		Parent = panel,
	}, function()
		Net.Get("StopTraining"):FireServer()
		stop()
	end)
	-- The big, obvious way off the bench: a red button right above the panel (thumb-sized on a
	-- phone). Walking or jumping gets you up too.
	stopButton = Kit.button({
		Name = "StopTraining",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -24 - 172 - 10),
		Size = UDim2.fromOffset(250, 50),
		Text = "✖ STOP TRAINING",
		Font = Theme.Font.Display,
		TextSize = 22,
		BackgroundColor3 = Theme.Color.Danger,
		TextColor3 = Color3.new(1, 1, 1),
		Visible = false,
		Parent = gui,
	}, function()
		Net.Get("StopTraining"):FireServer()
		stop()
	end)
	Kit.label({ Text = "or walk / jump to get up", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 1, 2), Size = UDim2.fromOffset(250, 14), Font = Theme.Font.Black, TextSize = Theme.TextSize.Tiny, TextColor3 = Color3.new(1, 1, 1), TextStrokeTransparency = 0.3, Parent = stopButton })
	-- Strength Surge (x3 for 15 min): shows the time left while active, otherwise opens the store.
	boostButton = Kit.button({
		Name = "Boost",
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.new(0.42, -4, 0, 30),
		Text = "⚡ x3 SURGE",
		TextSize = Theme.TextSize.Small,
		BackgroundColor3 = Theme.Color.Gold,
		TextColor3 = Color3.fromRGB(40, 28, 6),
		Visible = Monetization.Products.StrengthSurge.Id ~= 0,
		Parent = panel,
	}, function()
		if TrainingUI.OpenStore then
			TrainingUI.OpenStore()
		end
	end)

	-- The pump bar shimmers while you train; the surge button counts down while active.
	RunService.Heartbeat:Connect(function()
		if session then
			pumpGradient.Offset = Vector2.new(math.sin(os.clock() * 2.5) * 0.6, 0)
			local surgeUntil = tonumber(player:GetAttribute("TrainingBoostUntil")) or 0
			local left = surgeUntil - DateTime.now().UnixTimestamp
			if left > 0 then
				boostButton.Visible = true
				boostButton.Text = ("⚡ x3 %d:%02d"):format(left // 60, left % 60)
			elseif Monetization.Products.StrengthSurge.Id ~= 0 then
				boostButton.Text = "⚡ x3 SURGE"
			end
		end
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
				session.Target = tonumber(payload.Gained) or session.Target
				session.Reps = tonumber(payload.Reps) or session.Reps
				session.Sets = tonumber(payload.Sets) or session.Sets
			end
			stop()
		end
	end)
	Net.Get("TrainingRep").OnClientEvent:Connect(function(payload)
		if session and type(payload) == "table" then
			session.Sets = tonumber(payload.Sets) or session.Sets
		end
		onRep(payload)
	end)
	watchLifts()
end

return TrainingUI
