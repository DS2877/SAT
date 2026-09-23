-- Thin wrapper over AnalyticsService so gameplay code never calls it directly.
-- All calls are pcall-guarded: analytics must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Analytics = {}

-- Onboarding funnel, in the order a new player should hit them (Creator Dashboard >
-- Analytics > Funnels shows where players drop off). Each step fires once per player.
local FUNNEL = {
	"Joined",
	"FirstTraining",
	"FirstTreasure",
	"FirstExtraction",
	"FirstCollect",
	"FirstGadget",
	"FirstVaultUpgrade",
	"FirstTheft",
	"FirstAscension",
}
local funnelStep = {}
for i, name in FUNNEL do
	funnelStep[name] = i
end

local VERBOSE = RunService:IsStudio()

-- Session start per player, so every funnel step also logs how long it took to reach it.
local joinedAt: { [Player]: number } = {}
Players.PlayerAdded:Connect(function(player)
	joinedAt[player] = os.clock()
end)
Players.PlayerRemoving:Connect(function(player)
	joinedAt[player] = nil
end)

function Analytics.Event(player: Player, name: string, fields: { [string]: any }?)
	if VERBOSE then
		print(("[Analytics] %s %s"):format(player.Name, name), fields or "")
	end
	pcall(function()
		(AnalyticsService :: any):LogCustomEvent(player, name, 1, fields)
	end)
end

-- First-time funnel milestones (callers guard with PlayerData.Milestone so each fires once).
function Analytics.Funnel(player: Player, step: string)
	local index = funnelStep[step]
	if not index then
		return
	end
	if VERBOSE then
		print(("[Analytics] funnel %s %d:%s"):format(player.Name, index, step))
	end
	pcall(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, index, step)
	end)
	-- Custom event whose value is the seconds since joining (dashboard: time to each step).
	local seconds = math.floor(os.clock() - (joinedAt[player] or os.clock()))
	pcall(function()
		(AnalyticsService :: any):LogCustomEvent(player, "FunnelTime_" .. step, seconds)
	end)
end

function Analytics.Economy(player: Player, flow: string, amount: number, balance: number, transaction: string, sku: string?)
	pcall(function()
		local flowType = if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flowType, "Cash", amount, balance, transaction, sku)
	end)
end

return Analytics
