-- Authoritative treasure lifecycle: WORLD -> CARRIED -> DROPPED -> (CARRIED | WORLD respawn) -> EXTRACTED
-- The server alone decides which treasure spawns, who holds it and where it is.
-- Loot only spawns during the NIGHT (one wave per night, see GameConfig.DayNight); nightfall
-- wipes whatever is left, carried or not (ClearAll). A fresh server gets one initial fill so
-- the first day isn't empty. Daytime exceptions: Treasure Rain (SpawnFalling) and the starter
-- spawn points near the gate (Commons/Uncommons) so newcomers always find a first treasure.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Mutations = require(Shared.Config.Mutations)
local Carry = require(Shared.Logic.Carry)
local DayNight = require(Shared.Logic.DayNight)
local TreasureLabel = require(Shared.TreasureLabel)
local TreasureRoll = require(Shared.Logic.TreasureRoll)
local TreasureVisual = require(Shared.TreasureVisual)
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)

local Movement = require(script.Parent.Movement)
local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

local TreasureService = {}

TreasureService.PickedUp = Signal.new() -- (player, record, stolenFrom: Player?)
TreasureService.Dropped = Signal.new() -- (player, record, reason)
TreasureService.Removed = Signal.new() -- (record, reason) reason: "Extracted" | "Timeout"

export type Record = {
	Uid: number,
	Def: any,
	Mutation: string?, -- Mutations name (changes the look and multiplies income)
	State: string, -- "World" | "Carried" | "Dropped" | "Extracted"
	Model: Model,
	Handle: BasePart,
	Prompt: ProximityPrompt,
	Billboard: BillboardGui,
	SpawnPoint: any,
	Carrier: Player?,
	Weld: WeldConstraint?,
	DroppedAt: number,
	ProtectedFor: Player?,
	ProtectedUntil: number,
	KnockedFrom: Player?, -- who lost it through a knock (theft detection)
	Marker: Model?, -- soft ground ring while the treasure lies in the world
}

local cfg = GameConfig.Treasure
local records: { [number]: Record } = {}
local carrying: { [Player]: Record } = {}
local spawnPoints = {}
local folder: Folder
local markerFolder: Folder
local nextUid = 0
local rng = Random.new()

local function formatCash(n: number): string
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end
TreasureService.FormatCash = formatCash

local function setState(record: Record, state: string)
	record.State = state
	record.Model:SetAttribute("State", state)
	record.Model:SetAttribute("CarrierUserId", record.Carrier and record.Carrier.UserId or 0)
end

local function makeBillboard(record: Record)
	local gui = TreasureLabel.Build(record.Def, record.Mutation, {
		MaxDistance = cfg.LabelDistance,
		Height = TreasureVisual.Scale(record.Def) * 1.1 + 1.5,
	})
	gui.Adornee = record.Handle
	gui.Parent = record.Handle
	return gui
end

local function makePrompt(record: Record)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = if record.Mutation then record.Mutation .. " " .. record.Def.Name else record.Def.Name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = Carry.PickupHoldDuration(record.Def.Weight, GameConfig.Carry)
	prompt.MaxActivationDistance = GameConfig.Carry.PickupRange
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Default
	prompt.Parent = record.Handle
	prompt.Triggered:Connect(function(player)
		TreasureService.TryPickup(player, record.Uid)
	end)
	return prompt
end

local function activeByRarity()
	local counts = {}
	for _, record in records do
		counts[record.Def.Rarity] = (counts[record.Def.Rarity] or 0) + 1
	end
	return counts
end

local function activeCount(): number
	local n = 0
	for _ in records do
		n += 1
	end
	return n
end

-- point: a spawn point (normal spawns) or nil for free spawns (events), which pass `ground`.
-- Ground marker: a soft glowing ring in the rarity colour so treasure reads through grass.
-- (No sky beams: size, glow and aura particles on the treasure itself carry the rarity.)
-- Removed while carried.
local function clearMarker(record: Record)
	if record.Marker then
		record.Marker:Destroy()
		record.Marker = nil
	end
end

local function placeMarker(record: Record, ground: Vector3)
	clearMarker(record)
	local info = Rarities.Info[record.Def.Rarity]
	local s = TreasureVisual.Scale(record.Def)
	local marker = Instance.new("Model")
	marker.Name = "Marker_" .. record.Uid
	local function glow(size: Vector3, cframe: CFrame, transparency: number)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.Shape = Enum.PartType.Cylinder
		p.Material = Enum.Material.Neon
		p.Color = info.Color
		p.Transparency = transparency
		p.Size = size
		p.CFrame = cframe
		p.Parent = marker
		return p
	end
	local upright = CFrame.Angles(0, 0, math.rad(90))
	local diameter = s * 2.4 + 2
	glow(Vector3.new(0.15, diameter, diameter), CFrame.new(ground + Vector3.new(0, 0.12, 0)) * upright, 0.55)
	glow(Vector3.new(0.18, diameter - 1.2, diameter - 1.2), CFrame.new(ground + Vector3.new(0, 0.14, 0)) * upright, 0.85)
	marker.Parent = markerFolder
	record.Marker = marker
end

local function spawnAt(point, def, ground: Vector3?, mutation: string?)
	nextUid += 1
	local s = TreasureVisual.Scale(def)
	local base = if point then point.Position else ground :: Vector3
	local cframe = CFrame.new(base + Vector3.new(0, s * 0.9 + 0.3, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model = TreasureVisual.Build(def, cframe, nil, mutation)
	model.Name = def.Id .. "_" .. nextUid
	model:SetAttribute("TreasureId", def.Id)
	model:SetAttribute("Uid", nextUid)
	model:SetAttribute("Rarity", def.Rarity)

	local record: Record = {
		Uid = nextUid,
		Def = def,
		Mutation = mutation,
		State = "World",
		Model = model,
		Handle = model.PrimaryPart :: BasePart,
		Prompt = nil :: any,
		Billboard = nil :: any,
		SpawnPoint = point,
		Carrier = nil,
		Weld = nil,
		DroppedAt = 0,
		ProtectedFor = nil,
		ProtectedUntil = 0,
		KnockedFrom = nil,
	}
	record.Prompt = makePrompt(record)
	record.Billboard = makeBillboard(record)
	if def.SpecialEffect == "Radiant" or def.Rarity == "Secret" then
		local sparkles = Instance.new("Sparkles")
		sparkles.SparkleColor = Color3.new(1, 1, 1)
		sparkles.Parent = record.Handle
	end
	setState(record, "World")
	placeMarker(record, base)
	model.Parent = folder
	if point then
		point.Occupied = record
	end
	records[record.Uid] = record
	return record
end

-- Regional event modifiers (Cursed Hour, Gold Rush): only spawn points in `Area` are affected.
type RegionBoost = { Area: string, Rarity: { [string]: number }?, Mutation: number? }
local regionBoost: RegionBoost? = nil

function TreasureService.SetRegionBoost(boost: RegionBoost?)
	regionBoost = boost
	if boost then
		-- Let empty spawn points in the region refill right away so the event is felt immediately.
		for _, point in spawnPoints do
			if not point.Occupied and point.Area == boost.Area then
				point.NextSpawnAt = 0
			end
		end
	end
end

local function weightsFor(area: string)
	local weights = table.clone(cfg.RarityWeights)
	local function apply(mults)
		for rarity, mult in mults do
			if weights[rarity] then
				weights[rarity] *= mult
			end
		end
	end
	if regionBoost and regionBoost.Area == area and regionBoost.Rarity then
		apply(regionBoost.Rarity)
	end
	return weights
end

local function rollMutation(area: string?): string?
	local isNight = DayNight.IsNight(workspace:GetServerTimeNow())
	local boost = if regionBoost and area and regionBoost.Area == area then regionBoost.Mutation or 1 else 1
	return Mutations.Roll(function()
		return rng:NextNumber()
	end, isNight, boost)
end
TreasureService.RollMutation = rollMutation

local function isStarter(point): boolean
	return point.MaxRarity ~= nil and Rarities.Rank(point.MaxRarity) <= Rarities.Rank(cfg.StarterMaxRarity)
end

-- starterOnly: daytime refill of the low-rarity spawn points near the gate.
local function trySpawnOne(starterOnly: boolean?): boolean
	local now = os.clock()
	local free = {}
	for _, point in spawnPoints do
		if not point.Occupied and now >= point.NextSpawnAt and (not starterOnly or isStarter(point)) then
			table.insert(free, point)
		end
	end
	if #free == 0 then
		return false
	end
	local counts = activeByRarity()
	-- Try a few random free points (some may have no eligible treasure due to caps).
	for _ = 1, math.min(#free, 6) do
		local point = table.remove(free, rng:NextInteger(1, #free))
		local candidates =
			TreasureRoll.Candidates(Treasures.List, point, Rarities.Order, weightsFor(point.Area), cfg.RarityCaps, counts)
		local def = TreasureRoll.Pick(candidates, function()
			return rng:NextNumber()
		end)
		if def then
			spawnAt(point, def, nil, rollMutation(point.Area))
			return true
		end
		point.NextSpawnAt = now + 5
	end
	return false
end

local function freeSpawnPoint(record: Record)
	local point = record.SpawnPoint
	if point and point.Occupied == record then
		point.Occupied = nil
		point.NextSpawnAt = os.clock() + rng:NextNumber(cfg.RespawnDelayMin, cfg.RespawnDelayMax)
	end
end

local function remove(record: Record, reason: string)
	if records[record.Uid] == nil then
		return
	end
	records[record.Uid] = nil
	if record.Carrier and carrying[record.Carrier] == record then
		carrying[record.Carrier] = nil
	end
	freeSpawnPoint(record)
	clearMarker(record)
	record.Model:Destroy()
	TreasureService.Removed:Fire(record, reason)
end

local function applyCarrierMovement(player: Player, record: Record?)
	if not record then
		Movement.SetSpeed(player, "Carry", nil)
		Movement.SetJump(player, "Carry", nil)
		return
	end
	local data = PlayerData.Get(player)
	local strength = data and data.Strength or 1
	local speed = Carry.SpeedMultiplier(record.Def.Weight, strength, GameConfig.Carry)
	if record.Def.SpecialEffect == "Swift" then
		speed *= cfg.SwiftSpeedBonus -- the "getaway" treasure
	end
	Movement.SetSpeed(player, "Carry", speed)
	Movement.SetJump(player, "Carry", Carry.JumpMultiplier(speed, GameConfig.Carry))
	player:SetAttribute("CarrySpeed", speed)
end

local function setPlayerCarryAttributes(player: Player, record: Record?)
	player:SetAttribute("CarryingUid", record and record.Uid or 0)
	player:SetAttribute("CarryingId", record and record.Def.Id or "")
	player:SetAttribute("CarryingMutation", record and record.Mutation or "")
	if not record then
		player:SetAttribute("CarrySpeed", 1)
	end
end

-- PUBLIC API ------------------------------------------------------------------

function TreasureService.GetCarrying(player: Player): Record?
	return carrying[player]
end

function TreasureService.GetRecord(uid: number): Record?
	return records[uid]
end

function TreasureService.All()
	return records
end

function TreasureService.TryPickup(player: Player, uid: number): (boolean, string?)
	local record = records[uid]
	if not record or (record.State ~= "World" and record.State ~= "Dropped") then
		return false, "Unavailable"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return false, "Dead"
	end
	if carrying[player] then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "You can only carry ONE treasure", Tone = "Warn" })
		return false, "AlreadyCarrying"
	end
	if player:GetAttribute("Stability") == "Knocked" then
		return false, "Knocked"
	end
	if (root.Position - record.Handle.Position).Magnitude > GameConfig.Carry.PickupRange + 4 then
		return false, "TooFar"
	end
	local now = os.clock()
	if record.State == "Dropped" and now < record.ProtectedUntil and record.ProtectedFor ~= player then
		Net.Fire("Notify", player, {
			Kind = "Toast",
			Text = ("PROTECTED • %.1fs"):format(record.ProtectedUntil - now),
			Tone = "Warn",
		})
		return false, "Protected"
	end

	local wasInWorld = record.State == "World"
	local stolenFrom: Player? = nil
	if record.State == "Dropped" and record.KnockedFrom and record.KnockedFrom ~= player then
		stolenFrom = record.KnockedFrom
	end

	-- Attach above the head. Parts are massless and non-colliding so the carrier's physics stay sane.
	local handle = record.Handle
	local height = 3.2 + handle.Size.Y * 0.5
	handle.Anchored = false
	handle.CFrame = root.CFrame * CFrame.new(0, height, 0)
	for _, descendant in record.Model:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Massless = true
			descendant.CanCollide = false
			descendant.CanQuery = false
		end
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = handle
	weld.Parent = handle
	record.Weld = weld
	pcall(function()
		handle:SetNetworkOwner(player)
	end)

	record.Carrier = player
	record.ProtectedFor = nil
	record.ProtectedUntil = 0
	record.KnockedFrom = nil
	record.Prompt.Enabled = false
	clearMarker(record)
	record.Billboard.MaxDistance = if record.Def.SpecialEffect == "RevealsCarrier" then 2000 else cfg.CarriedLabelDistance
	record.Billboard.AlwaysOnTop = record.Def.SpecialEffect == "RevealsCarrier"
	carrying[player] = record
	setState(record, "Carried")
	setPlayerCarryAttributes(player, record)
	applyCarrierMovement(player, record)

	Net.Fire("Feedback", player, { Type = "PickedUp", Uid = uid, TreasureId = record.Def.Id })
	if PlayerData.Milestone(player, "FirstTreasure") then
		Analytics.Funnel(player, "FirstTreasure")
	end
	Analytics.Event(player, "TreasurePickedUp", { Treasure = record.Def.Id, Rarity = record.Def.Rarity })

	if stolenFrom then
		PlayerData.Update(player, function(d)
			d.Stats.Thefts += 1
		end)
		if PlayerData.Milestone(player, "FirstTheft") then
			Analytics.Funnel(player, "FirstTheft")
		end
		Net.Fire("Notify", stolenFrom, {
			Kind = "Banner",
			Title = "TREASURE STOLEN",
			Text = ("%s took your %s"):format(player.DisplayName, record.Def.Name:upper()),
			Tone = "Danger",
		})
		if Rarities.AtLeast(record.Def.Rarity, cfg.BroadcastMinRarity) then
			Net.FireAll("Notify", {
				Kind = "Social",
				Text = ("%s STOLE THE %s"):format(player.DisplayName:upper(), record.Def.Name:upper()),
				Rarity = record.Def.Rarity,
			})
		end
	elseif wasInWorld and Rarities.AtLeast(record.Def.Rarity, "Legendary") then
		Net.FireAll("Notify", {
			Kind = "Social",
			Text = ("%s FOUND A %s TREASURE"):format(player.DisplayName:upper(), record.Def.Rarity:upper()),
			Rarity = record.Def.Rarity,
		})
	end
	TreasureService.PickedUp:Fire(player, record, stolenFrom)
	return true
end

local function groundBelow(position: Vector3, exclude: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = false
	local result = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -200, 0), params)
	if result then
		return result.Position
	end
	return position
end

-- Drops the carried treasure where the player stands. reason: "Knocked" | "Died" | "Left" | "Manual"
function TreasureService.Drop(player: Player, reason: string, knockedBy: Player?): Record?
	local record = carrying[player]
	if not record then
		return nil
	end
	carrying[player] = nil
	local handle = record.Handle
	local fromPosition = handle.Position
	if record.Weld then
		record.Weld:Destroy()
		record.Weld = nil
	end

	local exclude: { Instance } = { folder }
	for _, p in Players:GetPlayers() do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local ground = groundBelow(fromPosition - Vector3.new(0, handle.Size.Y * 0.5 + 2.5, 0), exclude)
	handle.Anchored = true
	handle.CFrame = CFrame.new(ground + Vector3.new(0, TreasureVisual.Scale(record.Def) * 0.9 + 0.3, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	placeMarker(record, ground)

	local now = os.clock()
	record.Carrier = nil
	record.DroppedAt = now
	record.ProtectedFor = player
	record.ProtectedUntil = now + cfg.ReclaimProtection
	record.KnockedFrom = if reason == "Knocked" then player else nil
	record.Prompt.Enabled = true
	record.Billboard.MaxDistance = cfg.LabelDistance
	record.Billboard.AlwaysOnTop = false
	record.Model:SetAttribute("ProtectedUntil", workspace:GetServerTimeNow() + cfg.ReclaimProtection)
	record.Model:SetAttribute("ProtectedForUserId", player.UserId)
	setState(record, "Dropped")
	setPlayerCarryAttributes(player, nil)
	applyCarrierMovement(player, nil)

	Net.Fire("Feedback", player, { Type = "Dropped", Uid = record.Uid, Reason = reason })
	TreasureService.Dropped:Fire(player, record, reason, knockedBy)

	local droppedAt = now
	task.delay(cfg.DroppedTimeout, function()
		if records[record.Uid] == record and record.State == "Dropped" and record.DroppedAt == droppedAt then
			remove(record, "Timeout")
		end
	end)
	return record
end

-- Consumes the carried treasure for extraction. Returns (definition, mutation), or nil if invalid.
function TreasureService.Consume(player: Player, expectedUid: number): (any, string?)
	local record = carrying[player]
	if not record or record.Uid ~= expectedUid or record.State ~= "Carried" then
		return nil
	end
	carrying[player] = nil
	setState(record, "Extracted")
	setPlayerCarryAttributes(player, nil)
	applyCarrierMovement(player, nil)
	remove(record, "Extracted")
	return record.Def, record.Mutation
end

-- Event spawn outside the spawn-point system. The treasure falls from the sky onto `ground`,
-- can't be picked up until it lands, and despawns after `lifetime` if nobody took it.
function TreasureService.SpawnFalling(
	def,
	ground: Vector3,
	dropHeight: number,
	fallTime: number,
	lifetime: number,
	area: string?
)
	local record = spawnAt(nil, def, ground, rollMutation(area))
	local landed = record.Handle.CFrame
	record.Handle.CFrame = landed + Vector3.new(0, dropHeight, 0)
	record.Prompt.Enabled = false
	record.Model:SetAttribute("Falling", true)
	local tween = TweenService:Create(
		record.Handle,
		TweenInfo.new(fallTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = landed }
	)
	tween.Completed:Connect(function()
		if records[record.Uid] == record and record.State == "World" then
			record.Prompt.Enabled = true
			record.Model:SetAttribute("Falling", false)
		end
	end)
	tween:Play()
	task.delay(fallTime + lifetime, function()
		if records[record.Uid] == record and record.State == "World" then
			remove(record, "Timeout")
		end
	end)
	return record
end

-- Nightfall: every treasure still in the world is lost - dropped, lying around or CARRIED
-- (only extracted loot is safe). Spawn points are reset so the night wave can use them all.
-- Returns the players who lost a carried treasure.
function TreasureService.ClearAll(reason: string): { Player }
	local losers = {}
	for player, record in carrying do
		carrying[player] = nil
		record.Carrier = nil
		setPlayerCarryAttributes(player, nil)
		applyCarrierMovement(player, nil)
		table.insert(losers, player)
	end
	for _, record in records do
		remove(record, reason)
	end
	for _, point in spawnPoints do
		point.Occupied = nil
		point.NextSpawnAt = 0
	end
	return losers
end

-- Re-applies carry speed (e.g. after Strength changed while carrying).
function TreasureService.RefreshCarrier(player: Player)
	applyCarrierMovement(player, carrying[player])
end

function TreasureService.Init(points)
	folder = Instance.new("Folder")
	folder.Name = "Treasures"
	folder.Parent = workspace
	markerFolder = Instance.new("Folder")
	markerFolder.Name = "TreasureMarkers"
	markerFolder.Parent = workspace
	for _, point in points do
		table.insert(spawnPoints, {
			Area = point.Area,
			Position = point.Position,
			MinRarity = point.MinRarity,
			MaxRarity = point.MaxRarity,
			Occupied = nil,
			NextSpawnAt = 0,
		})
	end

	Players.PlayerRemoving:Connect(function(player)
		TreasureService.Drop(player, "Left")
	end)
	Players.PlayerAdded:Connect(function(player)
		player:SetAttribute("CarryingUid", 0)
		player:SetAttribute("CarryingId", "")
		player.CharacterAdded:Connect(function(character)
			-- Safety: a fresh character never carries anything.
			if carrying[player] then
				TreasureService.Drop(player, "Died")
			end
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				TreasureService.Drop(player, "Died")
			end)
		end)
	end)
	-- Manual drop: put the treasure down (e.g. to grab a better one or run faster).
	Net.On("DropTreasure", function(player)
		if carrying[player] then
			TreasureService.Drop(player, "Manual")
		end
	end, 2)
end

function TreasureService.Start()
	local initial = math.floor(cfg.MaxActive * cfg.InitialFillFraction)
	for _ = 1, initial do
		if not trySpawnOne() then
			break
		end
	end
	task.spawn(function()
		local dayNight = GameConfig.DayNight
		while true do
			task.wait(cfg.SpawnTick)
			-- Night wave: ramp up to MaxActive over the first part of the night.
			local state = DayNight.State(workspace:GetServerTimeNow())
			if state.IsNight then
				local target = math.ceil(cfg.MaxActive * math.min(1, state.Progress / dayNight.WaveFillFraction))
				for _ = 1, 4 do
					if activeCount() >= target or not trySpawnOne() then
						break
					end
				end
			elseif activeCount() < cfg.MaxActive then
				trySpawnOne(true)
			end
			-- Safety net: treasure that fell out of the world goes back to the spawn system.
			for _, record in records do
				if record.State ~= "Carried" and record.Handle.Position.Y < workspace.FallenPartsDestroyHeight + 20 then
					remove(record, "Timeout")
				end
			end
		end
	end)
end

return TreasureService
