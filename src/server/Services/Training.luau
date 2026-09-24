-- Bench-press training: a waiting game. A player lies down on a bench (prompt), is held in place,
-- and the reps come by themselves. Staying pays (Logic/Lifting): the PUMP multiplier grows with
-- every rep in a row, every 10 reps a SET pays a bonus, and any rep can be a MEGA or GOLDEN REP.
-- Higher tiers are unlocked with Cash + an Ascension level; every Ascension multiplies training
-- speed (GameConfig.GetTrainingMultiplier). All gains and rolls are server-side.
-- Every client animates bench users from the "Bench"/"BenchPump"/"BenchRep" player attributes.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Lifting = require(Shared.Logic.Lifting)
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
type Session = { Machine: Machine, Progress: number, Gained: number, Reps: number, SetGained: number, Sets: number }

local TICK = 0.1

local sessions: { [Player]: Session } = {}
local random = Random.new()

local function tierIndex(id: string): number
	for i, tier in cfg.Benches do
		if tier.Id == id then
			return i
		end
	end
	return 0
end

local function stop(player: Player, reason: string)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	if session.Machine.Occupant == player then
		session.Machine.Occupant = nil
		session.Machine.Prompt.Enabled = true
	end
	Movement.SetLock(player, "Bench", false)
	player:SetAttribute("Bench", "")
	player:SetAttribute("BenchPump", 0)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		root.Anchored = false
		if reason ~= "Respawned" then
			(root.Parent :: Model):PivotTo(session.Machine.StandCFrame)
		end
	end
	Net.Fire("TrainingState", player, { Active = false, Reason = reason, Gained = session.Gained, Reps = session.Reps, Sets = session.Sets })
end

-- Base Strength per rep for this player on this bench (before pump / jackpots).
local function repGainFor(player: Player, tier): number
	local data = PlayerData.Get(player)
	local ascension = if data then data.Ascension else 0
	return GameConfig.GetRepGain(tier, ascension) * Training.MultiplierFor(player)
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
	machine.Prompt.Enabled = false -- nobody sees "Lift" on a bench that's in use
	sessions[player] = { Machine = machine, Progress = 0, Gained = 0, Reps = 0, SetGained = 0, Sets = 0 }
	local character = root.Parent :: Model
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(machine.LieCFrame)
	root.Anchored = true
	Movement.SetLock(player, "Bench", true)
	player:SetAttribute("Bench", tier.Id)
	player:SetAttribute("BenchPump", 1)
	Net.Fire("TrainingState", player, {
		Active = true,
		TierId = tier.Id,
		Name = tier.Name,
		RepGain = repGainFor(player, tier),
		RepPeriod = cfg.RepPeriod,
		PumpMax = cfg.PumpMax,
		SetSize = cfg.SetSize,
	})
	if PlayerData.Milestone(player, "FirstTraining") then
		Analytics.Funnel(player, "FirstTraining")
	end
end

local function addStrength(player: Player, amount: number)
	PlayerData.Update(player, function(d)
		d.Strength = math.min(GameConfig.Strength.Max, d.Strength + amount)
	end)
	TreasureService.RefreshCarrier(player)
end

local function rep(player: Player, session: Session)
	session.Reps += 1
	local kind = Lifting.Roll(function()
		return random:NextNumber()
	end)
	local amount = Lifting.RepAmount(repGainFor(player, session.Machine.Tier), session.Reps, kind)
	session.Gained += amount
	session.SetGained += amount
	addStrength(player, amount)
	local setBonus = 0
	if Lifting.IsSetComplete(session.Reps) then
		setBonus = Lifting.SetBonus(session.SetGained)
		session.Sets += 1
		session.SetGained = 0
		session.Gained += setBonus
		addStrength(player, setBonus)
	end
	local pump = Lifting.Pump(session.Reps + 1) -- what the NEXT rep will pay
	player:SetAttribute("BenchPump", pump)
	player:SetAttribute("BenchKind", kind)
	player:SetAttribute("BenchGain", amount + setBonus) -- set first: clients read it when BenchRep changes
	player:SetAttribute("BenchRep", session.Reps) -- every client syncs the lift animation to this
	Net.Fire("TrainingRep", player, {
		Amount = amount,
		Kind = kind,
		Pump = pump,
		Reps = session.Reps,
		SetBonus = setBonus,
		Sets = session.Sets,
		Total = session.Gained,
	})
	if kind == "Golden" then
		Net.FireAll("Notify", {
			Kind = "Social",
			Text = ("%s LANDED A GOLDEN REP  +%d 💪"):format(player.DisplayName:upper(), amount),
			Rarity = "Legendary",
		})
	end
end

local function tick(dt: number)
	for player, session in sessions do
		local root = Combat.RootOf(player)
		local data = PlayerData.Get(player)
		local bench = session.Machine.LieCFrame.Position
		local offBench = not root
			or (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(bench.X, 0, bench.Z)).Magnitude
				> cfg.LeaveDistance
		if offBench or not data then
			stop(player, "Left")
		else
			session.Progress += dt / cfg.RepPeriod
			if session.Progress >= 1 then
				session.Progress -= 1
				rep(player, session)
			end
		end
	end
end

-- Training multiplier from passes / boosts (2x Strength, Strength Surge). Set by
-- MonetizationService; 1 without it.
Training.MultiplierFor = function(_player: Player): number
	return 1
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
		player.CharacterAdded:Connect(function()
			stop(player, "Respawned")
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		stop(player, "Left")
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(TICK)
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
