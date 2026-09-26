-- First-10-minutes onboarding (roadmap phase 3). New players should get, fast:
-- "I train -> find something valuable -> must get it home -> can be stopped -> earn money ->
--  get stronger -> want something better."
--   * INTRO CARD: first session only (no extraction yet) - the whole loop in four beats.
--   * JUST-IN-TIME TIPS: one short banner the first time something matters (entering the Wilds,
--     first pickup, first nightfall warning, first Shaken). Only for new players (< 3
--     extractions), once per session each, never stacked on top of each other.
-- The objective tracker (HUD) keeps pointing at the next concrete step.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local DayNight = require(Shared.Logic.DayNight)
local Zones = require(Shared.Util.Zones)

local UI = script.Parent.Parent.UI
local Theme = require(UI.Theme)
local Kit = require(UI.Kit)
local Sounds = require(UI.Sounds)
local ClientState = require(script.Parent.Parent.ClientState)
local Notifications = require(script.Parent.Notifications)

local Onboarding = {}

local player = Players.LocalPlayer
local NEW_PLAYER_EXTRACTIONS = 3
local shown: { [string]: boolean } = {}
local lastTipAt = 0

local function isNewPlayer(): boolean
	local data = ClientState.Data
	return data ~= nil and (data.Stats.Extractions or 0) < NEW_PLAYER_EXTRACTIONS
end

local function tip(id: string, title: string, text: string, tone: string?)
	if shown[id] or not isNewPlayer() or os.clock() - lastTipAt < 6 then
		return
	end
	shown[id] = true
	lastTipAt = os.clock()
	Notifications.Banner(title, text, tone or "Info", 4)
end

local function showIntro(gui: ScreenGui)
	local overlay = Kit.new("Frame", {
		Name = "Intro",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		ZIndex = 50,
		Parent = gui,
	})
	local card = Kit.panel({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(620, 300),
		ZIndex = 51,
		Parent = overlay,
	}, { Kit.padding(16, 20) })
	Kit.label({ Text = "STEAL THE TREASURE", Size = UDim2.new(1, 0, 0, 40), Font = Theme.Font.Display, TextSize = 36, TextColor3 = Theme.Color.Gold, ZIndex = 52, Parent = card })
	Kit.label({ Text = "Grab it. Run it home. Get rich.", Position = UDim2.fromOffset(0, 40), Size = UDim2.new(1, 0, 0, 22), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Body, TextColor3 = Theme.Color.TextDim, ZIndex = 52, Parent = card })
	local steps = Kit.new("Frame", {
		Position = UDim2.fromOffset(0, 74),
		Size = UDim2.new(1, 0, 0, 130),
		BackgroundTransparency = 1,
		ZIndex = 52,
		Parent = card,
	}, { Kit.list(Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center) })
	for i, beat in {
		{ "💎", "FIND", "Head out through the gate: treasure waits in the Wilds" },
		{ "🏃", "RUN IT HOME", "Back through the gate! One slap and you drop it" },
		{ "💰", "EARN", "Treasure in your Vault pays $ every second" },
		{ "💪", "TRAIN", "Lift at the gym to carry heavier, richer loot" },
	} do
		local cell = Kit.new("Frame", { LayoutOrder = i, Size = UDim2.fromOffset(134, 130), BackgroundColor3 = Theme.Color.PanelLight, ZIndex = 52, Parent = steps })
		Kit.corner(Theme.Radius.Medium).Parent = cell
		Kit.label({ Text = beat[1], Size = UDim2.new(1, 0, 0, 44), Position = UDim2.fromOffset(0, 6), TextSize = 34, ZIndex = 53, Parent = cell })
		Kit.label({ Text = beat[2], Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 20), Font = Theme.Font.Display, TextSize = 17, TextColor3 = Theme.Color.Gold, ZIndex = 53, Parent = cell })
		Kit.label({ Text = beat[3], Position = UDim2.fromOffset(6, 72), Size = UDim2.new(1, -12, 0, 52), Font = Theme.Font.Bold, TextSize = Theme.TextSize.Tiny, TextColor3 = Theme.Color.Text, ZIndex = 53, Parent = cell })
	end
	Kit.button({
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1),
		Size = UDim2.fromOffset(220, 48),
		Text = "LET'S GO!",
		Font = Theme.Font.Display,
		TextSize = 24,
		ZIndex = 52,
		Parent = card,
	}, function()
		overlay:Destroy()
	end)
	Kit.pulse(card)
	Sounds.Play("TrainPerfect", 0.6)
end

function Onboarding.Init(gui: ScreenGui)
	-- Intro once, as soon as we know this is a brand-new player.
	local introDone = false
	local function maybeIntro(data)
		if introDone or not data then
			return
		end
		introDone = true
		if (data.Stats.Extractions or 0) == 0 and not ClientState.Milestone("FirstTreasure") then
			showIntro(gui)
		end
	end
	ClientState.DataChanged:Connect(maybeIntro)
	maybeIntro(ClientState.Data)

	-- First pickup: what now, and what can go wrong.
	player:GetAttributeChangedSignal("CarryingId"):Connect(function()
		local id = player:GetAttribute("CarryingId")
		if type(id) == "string" and id ~= "" then
			tip("pickup", "🏃 GET IT HOME", "Carry it home through the gate • exit beams pay more • 1 slap = you drop it", "Reward")
		end
	end)
	player:GetAttributeChangedSignal("Stability"):Connect(function()
		if player:GetAttribute("Stability") == "Shaken" then
			tip("shaken", "⚠ YOU'RE SHAKEN", "RUN! One more hit and you drop your treasure", "Danger")
		end
	end)

	-- First steps into the Wilds, first nightfall warning.
	local wasSafe = true
	task.spawn(function()
		while true do
			task.wait(1)
			local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root then
				local safe = Zones.InSafeZone(root.Position)
				if wasSafe and not safe then
					tip("wilds", "🌿 THE WILDS", "Treasure and guardians out here • Get back before NIGHT or lose your loot", "Warn")
				end
				wasSafe = safe
			end
			local state = DayNight.State(workspace:GetServerTimeNow())
			-- A bit before the first countdown warning, so the two never stack.
			local firstWarning = GameConfig.DayNight.WarnSecondsBeforeNight[1]
			if not state.IsNight and state.SecondsLeft <= firstWarning + 30 and state.SecondsLeft > firstWarning + 2 then
				tip("night", "🌙 NIGHT IS COMING", "At nightfall all unextracted loot is lost • A fresh wave spawns at night", "Warn")
			end
		end
	end)
end

return Onboarding
