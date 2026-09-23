-- Authoritative treasure lifecycle: WORLD -> CARRIED -> DROPPED -> (CARRIED | WORLD respawn) -> EXTRACTED
-- The server alone decides which treasure spawns, who holds it and where it is.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local Carry = require(Shared.Logic.Carry)
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
}

local cfg = GameConfig.Treasure
local records: { [number]: Record } = {}
local carrying: { [Player]: Record } = {}
local spawnPoints = {}
local folder: Folder
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
	local def = record.Def
	local info = Rarities.Info[def.Rarity]
	local gui = Instance.new("BillboardGui")
	gui.Name = "TreasureTag"
	gui.Size = UDim2.fromOffset(220, 58)
	gui.StudsOffsetWorldSpace = Vector3.new(0, TreasureVisual.Scale(def) * 1.4 + 1.5, 0)
	gui.MaxDistance = info.BillboardDistance
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false

	local rarity = Instance.new("TextLabel")
	rarity.Name = "Rarity"
	rarity.BackgroundTransparency = 1
	rarity.Size = UDim2.new(1, 0, 0.4, 0)
	rarity.Font = Enum.Font.GothamBlack
	rarity.TextScaled = true
	rarity.TextColor3 = info.Color
	rarity.TextStrokeTransparency = 0.3
	rarity.Text = ("%s %s"):format(info.Glyph, def.Rarity:upper())
	rarity.Parent = gui

	local name = Instance.new("TextLabel")
	name.Name = "Title"
	name.BackgroundTransparency = 1
	name.Position = UDim2.fromScale(0, 0.4)
	name.Size = UDim2.new(1, 0, 0.6, 0)
	name.Font = Enum.Font.GothamBold
	name.TextScaled = true
	name.TextColor3 = Color3.new(1, 1, 1)
	name.TextStrokeTransparency = 0.2
	name.Text = ("%s  •  %s"):format(def.Name, formatCash(def.Value))
	name.Parent = gui

	gui.Adornee = record.Handle
	gui.Parent = record.Handle
	return gui
end

local function makePrompt(record: Record)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickupPrompt"
	prompt.ActionText = "Pick Up"
	prompt.ObjectText = record.Def.Name
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

local function spawnAt(point, def)
	nextUid += 1
	local s = TreasureVisual.Scale(def)
	local cframe = CFrame.new(point.Position + Vector3.new(0, s * 0.9 + 0.3, 0))
		* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0)
	local model = TreasureVisual.Build(def, cframe)
	model.Name = def.Id .. "_" .. nextUid
	model:SetAttribute("TreasureId", def.Id)
	model:SetAttribute("Uid", nextUid)
	model:SetAttribute("Rarity", def.Rarity)

	local record: Record = {
		Uid = nextUid,
		Def = def,
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
	model.Parent = folder
	point.Occupied = record
	records[record.Uid] = record
	return record
end

local function trySpawnOne(): boolean
	local now = os.clock()
	local free = {}
	for _, point in spawnPoints do
		if not point.Occupied and now >= point.NextSpawnAt then
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
			TreasureRoll.Candidates(Treasures.List, point, Rarities.Order, cfg.RarityWeights, cfg.RarityCaps, counts)
		local def = TreasureRoll.Pick(candidates, function()
			return rng:NextNumber()
		end)
		if def then
			spawnAt(point, def)
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
	Movement.SetSpeed(player, "Carry", speed)
	Movement.SetJump(player, "Carry", Carry.JumpMultiplier(speed, GameConfig.Carry))
	player:SetAttribute("CarrySpeed", speed)
end

local function setPlayerCarryAttributes(player: Player, record: Record?)
	player:SetAttribute("CarryingUid", record and record.Uid or 0)
	player:SetAttribute("CarryingId", record and record.Def.Id or "")
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
	record.Billboard.MaxDistance = if record.Def.SpecialEffect == "RevealsCarrier" then 2000 else 160
	record.Billboard.AlwaysOnTop = record.Def.SpecialEffect == "RevealsCarrier"
	carrying[player] = record
	setState(record, "Carried")
	setPlayerCarryAttributes(player, record)
	applyCarrierMovement(player, record)

	Net.Fire("Feedback", player, { Type = "PickedUp", Uid = uid, TreasureId = record.Def.Id })
	PlayerData.Milestone(player, "FirstTreasure")
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

	local now = os.clock()
	record.Carrier = nil
	record.DroppedAt = now
	record.ProtectedFor = player
	record.ProtectedUntil = now + cfg.ReclaimProtection
	record.KnockedFrom = if reason == "Knocked" then player else nil
	record.Prompt.Enabled = true
	record.Billboard.MaxDistance = Rarities.Info[record.Def.Rarity].BillboardDistance
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

-- Consumes the carried treasure for extraction. Returns the definition, or nil if invalid.
function TreasureService.Consume(player: Player, expectedUid: number)
	local record = carrying[player]
	if not record or record.Uid ~= expectedUid or record.State ~= "Carried" then
		return nil
	end
	carrying[player] = nil
	setState(record, "Extracted")
	setPlayerCarryAttributes(player, nil)
	applyCarrierMovement(player, nil)
	remove(record, "Extracted")
	return record.Def
end

-- Re-applies carry speed (e.g. after Strength changed while carrying).
function TreasureService.RefreshCarrier(player: Player)
	applyCarrierMovement(player, carrying[player])
end

function TreasureService.Init(points)
	folder = Instance.new("Folder")
	folder.Name = "Treasures"
	folder.Parent = workspace
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
end

function TreasureService.Start()
	local initial = math.floor(cfg.MaxActive * cfg.InitialFillFraction)
	for _ = 1, initial do
		if not trySpawnOne() then
			break
		end
	end
	task.spawn(function()
		while true do
			task.wait(cfg.SpawnTick)
			if activeCount() < cfg.MaxActive then
				trySpawnOne()
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
