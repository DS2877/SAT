-- Attacks (PvP bat SLAPS), Guardian hits and carrier stability (STABLE -> SHAKEN -> KNOCKED).
-- Hit detection is server-side from server positions; the client only says "I swung".
--   * Not carrying: a slap sends you flying (the attacker's bat decides how far).
--   * Carrying: one slap THROWS you and you DROP it (GameConfig.Stability.HitsToKnock; at 2
--     the first slap only slows you - Shaken - and the second throws you).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Stability = require(Shared.Logic.Stability)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local TreasureService = require(script.Parent.TreasureService)
local Analytics = require(script.Parent.Analytics)
local Decoys = require(script.Parent.Decoys)
local BatService = require(script.Parent.BatService)

local Combat = {}

-- (victim, result, source) result: "Hit" | "Shaken" | "Knocked"
Combat.PlayerHit = Signal.new()

local cfg = GameConfig.Combat
local stabilityCfg = GameConfig.Stability
local states: { [Player]: Stability.State } = {}
local lastAttack: { [Player]: number } = {}

-- Guardian hook: set by GuardianService to let players bonk guardians. (attacker, rootPart) -> boolean
Combat.TryHitGuardian = nil :: ((Player, BasePart) -> boolean)?

local function stateFor(player: Player): Stability.State
	local st = states[player]
	if not st then
		st = Stability.new()
		states[player] = st
	end
	return st
end

local function publish(player: Player, st: Stability.State)
	player:SetAttribute("Stability", st.State)
end

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	if not character then
		return nil, nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or humanoid.Health <= 0 or not root then
		return nil, nil
	end
	return root, humanoid
end
Combat.RootOf = rootOf

function Combat.IsKnocked(player: Player): boolean
	local st = states[player]
	return st ~= nil and st.State == "Knocked"
end

local function hasSpawnProtection(player: Player): boolean
	return player.Character ~= nil and player.Character:FindFirstChildOfClass("ForceField") ~= nil
end

-- Is `victim` protected from player attacks at the moment?
function Combat.IsPvPProtected(victim: Player): boolean
	local root = rootOf(victim)
	if not root or hasSpawnProtection(victim) then
		return true
	end
	local carrying = TreasureService.GetCarrying(victim) ~= nil
	if Zones.InSafeZone(root.Position) and not (carrying and not cfg.SafeZoneProtectsCarriers) then
		return true
	end
	return false
end

-- Shared PvP rule for bonks and ranged gadgets: nobody gets hit inside the District unless they
-- carry treasure (config), and players standing in the District can't attack non-carriers.
function Combat.CanPlayerHit(attacker: Player, victim: Player): boolean
	local attackerRoot = rootOf(attacker)
	if not attackerRoot or Combat.IsPvPProtected(victim) then
		return false
	end
	local victimCarrying = TreasureService.GetCarrying(victim) ~= nil
	local carrierExposed = victimCarrying and not cfg.SafeZoneProtectsCarriers
	return not (Zones.InSafeZone(attackerRoot.Position) and not carrierExposed)
end

local function setShakenSlow(victim: Player, slowed: boolean)
	Movement.SetSpeed(victim, "Shaken", if slowed then stabilityCfg.ShakenSpeed else nil)
end

local function knock(victim: Player, st: Stability.State, attacker: Player?)
	setShakenSlow(victim, false)
	publish(victim, st)
	Movement.SetLock(victim, "Knocked", true)
	TreasureService.Drop(victim, "Knocked", attacker)
	Net.Fire("Feedback", victim, { Type = "Knocked", Duration = stabilityCfg.KnockedDuration })
	PlayerData.Update(victim, function(d)
		d.Stats.Knocks += 1
	end)
	Analytics.Event(victim, "Knocked", { By = attacker and "Player" or "Guardian" })
	local knockedUntil = st.KnockedUntil
	task.delay(stabilityCfg.KnockedDuration, function()
		if states[victim] == st and st.KnockedUntil == knockedUntil then
			Stability.Update(st, os.clock(), stabilityCfg)
			publish(victim, st)
			Movement.SetLock(victim, "Knocked", false)
		end
	end)
end

-- Throw multiplier for a player of `strength` in a region recommending `recommended`:
-- 1 when strong enough, up to GuardianUnderpowerMax when far too weak.
function Combat.UnderpowerThrow(strength: number, recommended: number): number
	local missing = math.clamp(1 - strength / math.max(recommended, 1), 0, 1)
	return math.min(1 + missing * cfg.GuardianUnderpowerThrow * 2, cfg.GuardianUnderpowerMax)
end

-- Applies a hit to a player.
-- source = { Attacker: Player?, Guardian: string?, Damage: number, From: Vector3,
--            Knockback: number? (x the default power), Power: number? (studs/s, a bat's) }
function Combat.ApplyHit(victim: Player, source)
	local root, humanoid = rootOf(victim)
	if not root or not humanoid or hasSpawnProtection(victim) then
		return "Ignored"
	end

	-- Guardians: no damage, ever. One hit throws you back; a carrier drops the loot on the spot.
	if source.Guardian then
		local away = root.Position - source.From
		away = Vector3.new(away.X, 0, away.Z)
		away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
		local result = "Thrown"
		if TreasureService.GetCarrying(victim) then
			local st = stateFor(victim)
			local now = os.clock()
			Stability.Update(st, now, stabilityCfg)
			if Stability.IsImmune(st, now) then
				return "Ignored"
			end
			Stability.ForceKnock(st, now, stabilityCfg)
			knock(victim, st, nil) -- drops the treasure where you stand, before the throw
			result = "Knocked"
		end
		local power = cfg.GuardianThrowBase + math.max(0, (source.Knockback or 1) - 1) * cfg.GuardianThrowPerKnockback
		-- Under-powered for this region: the guardian sends you MUCH further (go train!).
		local region = source.Area and GameConfig.Regions[source.Area]
		local data = PlayerData.Get(victim)
		if region and data then
			power *= Combat.UnderpowerThrow(data.Strength, region.RecommendedStrength)
		end
		Net.Fire("Feedback", victim, { Type = "Knockback", Direction = away, Power = power, Lift = cfg.GuardianThrowLift, Thrown = true, Dropped = result == "Knocked" })
		Combat.PlayerHit:Fire(victim, result, source)
		return result
	end

	if source.Damage and source.Damage > 0 then
		humanoid:TakeDamage(source.Damage)
	end
	local away = root.Position - source.From
	away = Vector3.new(away.X, 0, away.Z)
	away = if away.Magnitude > 0.01 then away.Unit else Vector3.new(0, 0, 1)
	local power = source.Power or cfg.KnockbackPower * (source.Knockback or 1)

	local result = "Hit"
	if TreasureService.GetCarrying(victim) then
		local st = stateFor(victim)
		local now = os.clock()
		result = Stability.Hit(st, now, stabilityCfg)
		if result == "Shaken" then
			-- First slap on a carrier: a short shove and a heavy stagger (slowed).
			power *= cfg.ShakenShove
			setShakenSlow(victim, true)
			publish(victim, st)
			Net.Fire("Feedback", victim, { Type = "Shaken", Window = stabilityCfg.ShakenWindow })
			local shakenAt = st.ShakenAt
			task.delay(stabilityCfg.ShakenWindow + 0.05, function()
				if states[victim] == st and st.ShakenAt == shakenAt and Stability.Update(st, os.clock(), stabilityCfg) then
					publish(victim, st)
					setShakenSlow(victim, false)
				end
			end)
		elseif result == "Knocked" then
			-- The knocking slap: thrown - and the treasure stays behind.
			power *= cfg.KnockThrow
			knock(victim, st, source.Attacker)
		end
	end
	Net.Fire("Feedback", victim, { Type = "Knockback", Direction = away, Power = power, Lift = 20 + power * (if result == "Knocked" then 0.35 else 0.18) })
	if result ~= "Ignored" then
		Combat.PlayerHit:Fire(victim, result, source)
	end
	return result
end

local function onAttack(attacker: Player)
	local now = os.clock()
	if now - (lastAttack[attacker] or 0) < cfg.AttackCooldown then
		return
	end
	local root = rootOf(attacker)
	if not root or Combat.IsKnocked(attacker) or Movement.IsLocked(attacker) then
		return
	end
	if TreasureService.GetCarrying(attacker) and not cfg.CarrierCanAttack then
		return
	end
	lastAttack[attacker] = now
	BatService.Draw(attacker) -- a sheathed bat comes out on the first SLAP
	local bat = BatService.Get(attacker)

	-- Everyone sees the swing (animation + sound are client-side).
	Net.FireAll("Feedback", { Type = "Swing", UserId = attacker.UserId, BatId = bat.Id })

	local range = bat.Range
	local look = root.CFrame.LookVector
	local best: Player? = nil
	local bestDistance = math.huge
	for _, other in Players:GetPlayers() do
		if other ~= attacker then
			local otherRoot = rootOf(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance <= range and distance < bestDistance then
					local flat = Vector3.new(offset.X, 0, offset.Z)
					local facing = if flat.Magnitude > 0.1 then look:Dot(flat.Unit) else 1
					if facing >= cfg.AttackArcDot then
						best = other
						bestDistance = distance
					end
				end
			end
		end
	end

	if best then
		if Combat.CanPlayerHit(attacker, best) then
			local result = Combat.ApplyHit(best, { Attacker = attacker, Damage = cfg.PvPDamage, From = root.Position, Power = bat.Knockback })
			Net.Fire("Feedback", attacker, { Type = "HitConfirm", Result = result })
			local bestRoot = rootOf(best)
			if bestRoot then
				Net.FireAll("Feedback", { Type = "SlapImpact", Position = bestRoot.Position, BatId = bat.Id, Result = result })
			end
			return
		end
	end

	if Decoys.PopNear(root.Position + look * 3, range, attacker) then
		return
	end
	if Combat.TryHitGuardian then
		Combat.TryHitGuardian(attacker, root)
	end
end

function Combat.ResetPlayer(player: Player)
	setShakenSlow(player, false)
	local st = stateFor(player)
	Stability.Reset(st)
	publish(player, st)
end

function Combat.Init()
	Net.On("Attack", onAttack, 4)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("Stability", "Stable")
		player.CharacterAdded:Connect(function()
			-- New character: new stability state (old delayed callbacks see a different table).
			states[player] = Stability.new()
			publish(player, states[player])
		end)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		lastAttack[player] = nil
	end)
end

return Combat
