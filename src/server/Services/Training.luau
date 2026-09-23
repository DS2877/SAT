-- Bench-press training: AFK-friendly Strength gain. A player lies down on a bench (prompt), is
-- held in place, and earns Strength every tick. Tapping PUSH briefly multiplies the rate.
-- Higher tiers are unlocked with Cash + an Ascension level; every Ascension multiplies training
-- speed (GameConfig.GetTrainingMultiplier). All gains are server-side.
-- Every client animates bench users from the "Bench"/"BenchBoost" player attributes.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Net = require(Shared.Net)

local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)
local Analytics = require(script.Parent.Analytics)

local Training = {}

local cfg = GameConfig.Training

-- LieCFrame: root pose lying on the bench (looking at the sky, head toward the rack).
-- StandCFrame: where the player is put back on their feet afterwards.
type Machine = { Tier: any, LieCFrame: CFrame, StandCFrame: CFrame, Prompt: ProximityPrompt, Occupant: Player? }
type Session = { Machine: Machine, Pending: number, SprintUntil: number, Gained: number }

local sessions: { [Player]: Session } = {}
local passMultiplier: { [Player]: number } = {}

local function tierIndex(id: string): number
	for i, tier in cfg.Benches do
		if tier.Id == id then
			return i
		end
	end
	return 0
end

local function commit(player: Player, session: Session)
	if session.Pending <= 0 then
		return
	end
	local amount = session.Pending
	session.Pending = 0
	PlayerData.Update(player, function(d)
		d.Strength = math.min(GameConfig.Strength.Max, d.Strength + amount)
	end)
	TreasureService.RefreshCarrier(player)
end

local function stop(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	commit(player, session)
	if session.Machine.Occupant == player then
		session.Machine.Occupant = nil
	end
	Movement.SetLock(player, "Bench", false)
	player:SetAttribute("Bench", "")
	player:SetAttribute("BenchBoost", false)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
		if reason ~= "Respawned" then
			(root.Parent :: Model):PivotTo(session.Machine.StandCFrame)
		end
	end
	Net.Fire("TrainingState", player, { Active = false, Reason = reason, Gained = session.Gained })
end

local function rateFor(player: Player, tier): number
	local data = PlayerData.Get(player)
	local ascension = if data then data.Ascension else 0
	return tier.Rate * GameConfig.GetTrainingMultiplier(ascension) * (passMultiplier[player] or 1)
end

local function owns(data, tier): boolean
	return tier.Price <= 0 or data.OwnedBenches[tier.Id] == true
end

local function start(player: Player, machine: Machine)
	local data = PlayerData.Get(player)
	local root = Combat.RootOf(player)
	if not data or not root or Combat.IsKnocked(player) then
		return
	end
	if TreasureService.GetCarrying(player) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Extract your treasure before training", Tone = "Warn" })
		return
	end
	if machine.Occupant and machine.Occupant ~= player and sessions[machine.Occupant] then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Someone is already lifting here", Tone = "Info" })
		return
	end
	local tier = machine.Tier
	if data.Ascension < tier.RequiredAscension then
		Net.Fire("Notify", player, {
			Kind = "Toast",
			Text = ("%s unlocks at ASCENSION %d"):format(tier.Name:upper(), tier.RequiredAscension),
			Tone = "Warn",
		})
		return
	end
	if not owns(data, tier) then
		if not PlayerData.TrySpend(player, tier.Price) then
			Net.Fire("Notify", player, {
				Kind = "Toast",
				Text = ("%s costs $%d"):format(tier.Name:upper(), tier.Price),
				Tone = "Warn",
			})
			return
		end
		PlayerData.Update(player, function(d)
			d.OwnedBenches[tier.Id] = true
		end)
		Net.Fire("Notify", player, { Kind = "Banner", Title = "UNLOCKED", Text = tier.Name:upper(), Tone = "Reward" })
		Analytics.Economy(player, "Sink", tier.Price, data.Cash, "Shop", "bench_" .. tier.Id)
	end

	stop(player, "Switched")
	machine.Occupant = player
	sessions[player] = { Machine = machine, Pending = 0, SprintUntil = 0, Gained = 0 }
	local character = root.Parent :: Model
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(machine.LieCFrame)
	root.Anchored = true
	Movement.SetLock(player, "Bench", true)
	player:SetAttribute("Bench", tier.Id)
	Net.Fire("TrainingState", player, {
		Active = true,
		TierId = tier.Id,
		Name = tier.Name,
		Rate = rateFor(player, tier),
		SprintMultiplier = cfg.SprintMultiplier,
		Position = machine.LieCFrame.Position,
		LeaveDistance = cfg.LeaveDistance,
	})
	if PlayerData.Milestone(player, "FirstTraining") then
		Analytics.Funnel(player, "FirstTraining")
	end
end

local function tick(dt: number)
	local now = os.clock()
	for player, session in sessions do
		local root = Combat.RootOf(player)
		local data = PlayerData.Get(player)
		local belt = session.Machine.LieCFrame.Position
		local offBelt = not root
			or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(belt.X, 0, belt.Z)).Magnitude
				> cfg.LeaveDistance
		if offBelt or not data then
			stop(player, "Left")
		else
			local sprinting = now < session.SprintUntil
			local gain = rateFor(player, session.Machine.Tier) * dt * (if sprinting then cfg.SprintMultiplier else 1)
			session.Pending += gain
			session.Gained += gain
			-- Commit whenever the displayed (whole) Strength would change, so the HUD ticks up
			-- without a data sync every second.
			if math.floor(data.Strength + session.Pending) > math.floor(data.Strength) then
				commit(player, session)
			end
		end
	end
end

local function onSprint(player: Player)
	local session = sessions[player]
	if session then
		local untilTime = os.clock() + cfg.SprintDuration
		session.SprintUntil = untilTime
		player:SetAttribute("BenchBoost", true)
		task.delay(cfg.SprintDuration, function()
			if sessions[player] == session and session.SprintUntil == untilTime then
				player:SetAttribute("BenchBoost", false)
			end
		end)
	end
end

local function loadPass(player: Player)
	if cfg.StrengthPassId <= 0 then
		return
	end
	local ok, owned = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, cfg.StrengthPassId)
	end)
	if ok and owned then
		passMultiplier[player] = cfg.StrengthPassMultiplier
	end
end

function Training.TierIndex(id: string): number
	return tierIndex(id)
end

function Training.Init(machines: { Machine })
	for _, machine in machines do
		machine.Prompt.Triggered:Connect(function(player)
			start(player, machine)
		end)
	end
	Net.On("TrainingTap", onSprint, cfg.MaxTapsPerSecond)
	Net.On("StopTraining", function(player)
		stop(player, "Stopped")
	end, 4)
	TreasureService.PickedUp:Connect(function(player)
		stop(player, "Carrying")
	end)
	Combat.PlayerHit:Connect(function(victim)
		stop(victim, "Hit")
	end)
	Players.PlayerAdded:Connect(function(player)
		task.spawn(loadPass, player)
		player.CharacterAdded:Connect(function()
			stop(player, "Respawned")
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		stop(player, "Left")
		passMultiplier[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(cfg.TickRate)
			local now = os.clock()
			local ok, err = pcall(tick, now - last)
			last = now
			if not ok then
				warn("[Training] tick error:", err)
			end
		end
	end)
end

return Training
