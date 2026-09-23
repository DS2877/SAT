-- Thin wrapper over AnalyticsService so gameplay code never calls it directly.
-- All calls are pcall-guarded: analytics must never break gameplay.

local AnalyticsService = game:GetService("AnalyticsService")
local RunService = game:GetService("RunService")

local Analytics = {}

local FUNNEL = {
	"FirstTraining",
	"FirstTreasure",
	"FirstExtraction",
	"FirstGadget",
	"FirstVault",
	"FirstTheft",
	"FirstAscension",
}
local funnelStep = {}
for i, name in FUNNEL do
	funnelStep[name] = i
end

local VERBOSE = RunService:IsStudio()

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
end

function Analytics.Economy(player: Player, flow: string, amount: number, balance: number, transaction: string, sku: string?)
	pcall(function()
		local flowType = if flow == "Source" then Enum.AnalyticsEconomyFlowType.Source else Enum.AnalyticsEconomyFlowType.Sink
		AnalyticsService:LogEconomyEvent(player, flowType, "Cash", amount, balance, transaction, sku)
	end)
end

return Analytics
