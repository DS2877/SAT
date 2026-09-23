-- World presentation that every client runs locally:
--   * Day/night lighting from the shared DayNight clock (server time, so everyone agrees),
--     with a readable blue night (nights are short and should feel special, not blind you).
--   * Nightfall countdown warnings (carried loot is lost at nightfall!) and banners when night
--     falls (new loot is spawning) and when the sun rises (go hunt).
--   * Rainbow-mutation treasures cycle their colours (tag "RainbowTreasure").
--   * Sell prompts on other players' Vault pedestals are hidden.

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local DayNight = require(Shared.Logic.DayNight)

local Notifications = require(script.Parent.Notifications)
local Sounds = require(script.Parent.Parent.UI.Sounds)

local Ambience = {}

local player = Players.LocalPlayer

local DAY = {
	Brightness = 2.4,
	Exposure = 0.1,
	Ambient = Color3.fromRGB(135, 138, 150),
	Atmosphere = Color3.fromRGB(200, 222, 240),
	Decay = Color3.fromRGB(110, 150, 195),
}
local NIGHT = {
	Brightness = 1.1,
	Exposure = 0.45,
	Ambient = Color3.fromRGB(80, 92, 150),
	Atmosphere = Color3.fromRGB(70, 85, 140),
	Decay = Color3.fromRGB(40, 50, 100),
}

-- 0 in full daylight, 1 in full night, smooth around dusk and dawn.
local function nightFactor(clock: number): number
	local fromNoon = math.abs(clock - 12.5)
	local t = math.clamp((fromNoon - 5) / 1.5, 0, 1)
	return t * t * (3 - 2 * t)
end

local function applyLighting(serverNow: number)
	local state = DayNight.State(serverNow)
	local f = nightFactor(state.ClockTime)
	Lighting.ClockTime = state.ClockTime
	Lighting.Brightness = DAY.Brightness + (NIGHT.Brightness - DAY.Brightness) * f
	Lighting.ExposureCompensation = DAY.Exposure + (NIGHT.Exposure - DAY.Exposure) * f
	Lighting.OutdoorAmbient = DAY.Ambient:Lerp(NIGHT.Ambient, f)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		atmosphere.Color = DAY.Atmosphere:Lerp(NIGHT.Atmosphere, f)
		atmosphere.Decay = DAY.Decay:Lerp(NIGHT.Decay, f)
	end
	return state
end

-- RAINBOW -------------------------------------------------------------------------------

local rainbowParts: { [Instance]: { BasePart } } = {}

local function trackRainbow(model: Instance)
	local parts = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(parts, d)
		end
	end
	rainbowParts[model] = parts
end

-- SELL PROMPTS ---------------------------------------------------------------------------

local function filterPrompt(prompt: Instance)
	if prompt:IsA("ProximityPrompt") and prompt.Name == "SellPrompt" then
		local owner = prompt:GetAttribute("OwnerUserId")
		if owner ~= player.UserId then
			prompt.Enabled = false -- local only: the server also checks ownership
		end
	end
end

function Ambience.Init()
	for _, model in CollectionService:GetTagged("RainbowTreasure") do
		trackRainbow(model)
	end
	CollectionService:GetInstanceAddedSignal("RainbowTreasure"):Connect(function(model)
		task.defer(trackRainbow, model) -- let the parts replicate first
	end)
	CollectionService:GetInstanceRemovedSignal("RainbowTreasure"):Connect(function(model)
		rainbowParts[model] = nil
	end)

	for _, d in workspace:GetDescendants() do
		filterPrompt(d)
	end
	workspace.DescendantAdded:Connect(filterPrompt)

	local wasNight: boolean? = nil
	local lastLeft = math.huge
	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		local now = workspace:GetServerTimeNow()
		local state = applyLighting(now)
		if wasNight ~= nil and state.IsNight ~= wasNight then
			if state.IsNight then
				Notifications.Banner(
					"🌙 NIGHT FALLS",
					("New treasure is appearing • Vaults earn x%d"):format(GameConfig.DayNight.NightIncomeMultiplier),
					"Info",
					3
				)
				Sounds.Play("Event", 0.7)
			else
				Notifications.Banner("☀ A NEW DAY", "Fresh treasure is out there • Go hunt!", "Reward", 3)
			end
		end
		if not state.IsNight and wasNight ~= nil then
			for _, warnAt in GameConfig.DayNight.WarnSecondsBeforeNight do
				if lastLeft > warnAt and state.SecondsLeft <= warnAt then
					local carrying = player:GetAttribute("CarryingId")
					local text = if type(carrying) == "string" and carrying ~= ""
						then "EXTRACT NOW or lose your treasure!"
						else "Unextracted loot will be lost"
					Notifications.Banner(("🌙 NIGHTFALL IN %ds"):format(warnAt), text, "Warn", 2.5)
					Sounds.Play("GuardianAlert", 0.5)
				end
			end
		end
		lastLeft = if state.IsNight then math.huge else state.SecondsLeft
		wasNight = state.IsNight

		local hueBase = (os.clock() * 0.25) % 1
		for model, parts in rainbowParts do
			if not model.Parent then
				rainbowParts[model] = nil
				continue
			end
			for i, part in parts do
				part.Color = Color3.fromHSV((hueBase + i * 0.08) % 1, 0.75, 1)
			end
		end
	end)
end

return Ambience
