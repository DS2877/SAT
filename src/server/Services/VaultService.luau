-- Physical trophy Vaults. Each player gets a plot in the Treasure District with pedestals
-- showing treasures from their Collection. Others can walk in and look (social flex).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local TreasureVisual = require(Shared.TreasureVisual)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local Extraction = require(script.Parent.Extraction)
local Analytics = require(script.Parent.Analytics)

local VaultService = {}

local cfg = GameConfig.Vault
local plots = {} -- from WorldBuilder: { CFrame, Sign: TextLabel, Prompt, Displays: Folder, Owner }
local plotOf: { [Player]: any } = {}

local function slotsFor(data): number
	local tier = cfg.Tiers[data.Vault.Tier] or cfg.Tiers[1]
	return tier.Slots
end
VaultService.SlotsFor = slotsFor

local function formatShort(n: number): string
	if n >= 1e6 then
		return ("$%gM"):format(math.floor(n / 1e5) / 10)
	elseif n >= 1e3 then
		return ("$%gK"):format(math.floor(n / 1e2) / 10)
	end
	return "$" .. n
end

-- Slot index -> (floor number, local CFrame offset on that floor)
local function slotPlacement(index: number): (number, CFrame)
	local floorIndex = (index - 1) // cfg.PerFloor + 1
	local j = (index - 1) % cfg.PerFloor
	local col = j % cfg.Columns
	local row = j // cfg.Columns
	local rows = math.ceil(cfg.PerFloor / cfg.Columns)
	local x = (col - (cfg.Columns - 1) / 2) * cfg.ColumnSpacing
	local z = (row - (rows - 1) / 2) * cfg.RowSpacing
	return floorIndex, CFrame.new(x, (floorIndex - 1) * cfg.FloorHeight, z)
end

local function maxEnabledSlots(): number
	local maxSlots = 0
	for _, tier in cfg.Tiers do
		if tier.Enabled then
			maxSlots = math.max(maxSlots, tier.Slots)
		end
	end
	return maxSlots
end

local function newPart(parent: Instance, props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(p :: any)[key] = value
	end
	p.Parent = parent
	return p
end

local function label(parent: Instance, text: string, color: Color3, offsetY: number, maxDistance: number, width: number?)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromScale(width or 7, (width or 7) * 0.2) -- studs: shrinks with distance
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.MaxDistance = maxDistance
	gui.LightInfluence = 0
	local text1 = Instance.new("TextLabel")
	text1.BackgroundTransparency = 1
	text1.Size = UDim2.fromScale(1, 1)
	text1.Font = Enum.Font.GothamBold
	text1.TextScaled = true
	text1.TextColor3 = color
	text1.TextStrokeTransparency = 0.3
	text1.Text = text
	text1.Parent = gui
	gui.Parent = parent
	return gui
end

local teleportPlayerToFloor -- forward declaration (lift pads)

local function buildPedestal(parent: Instance, base: CFrame, def, ghost: boolean)
	local marble = Color3.fromRGB(235, 228, 210)
	local t = if ghost then 0.82 else 0
	newPart(parent, { Name = "Plinth", Size = Vector3.new(3.6, 0.5, 3.6), CFrame = base * CFrame.new(0, 0.25, 0), Color = Color3.fromRGB(70, 60, 95), Material = Enum.Material.Marble, Transparency = t, CanCollide = not ghost })
	newPart(parent, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.2, 2.2), CFrame = base * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = marble, Material = Enum.Material.Marble, Transparency = t, CanCollide = not ghost })
	newPart(parent, { Name = "Cap", Size = Vector3.new(3.2, 0.4, 3.2), CFrame = base * CFrame.new(0, 3.1, 0), Color = Color3.fromRGB(255, 196, 50), Material = Enum.Material.Metal, Transparency = t, CanCollide = not ghost })
	if def then
		local info = Rarities.Info[def.Rarity]
		newPart(parent, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 3.3, 3.3), CFrame = base * CFrame.new(0, 3.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = info.Color, Material = Enum.Material.Neon, CanCollide = false })
		local s = math.min(TreasureVisual.Scale(def), cfg.DisplayMaxScale)
		local model = TreasureVisual.Build(def, base * CFrame.new(0, 3.5 + s * 0.9, 0), cfg.DisplayMaxScale)
		model:SetAttribute("TreasureId", def.Id)
		model:SetAttribute("VaultDisplay", true)
		local handle = model.PrimaryPart :: BasePart
		handle:SetAttribute("Spin", 0.6)
		model.Parent = parent
		-- Name plaque on the front of the pedestal (floating billboards overlapped each other).
		local plaque = newPart(parent, {
			Name = "Plaque",
			Size = Vector3.new(3.2, 0.9, 0.12),
			CFrame = base * CFrame.new(0, 0.95, -1.4),
			Color = Color3.fromRGB(40, 32, 60),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 60
		gui.LightInfluence = 0
		gui.MaxDistance = 60
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.new(1, -12, 1, -6)
		text.Position = UDim2.fromOffset(6, 3)
		text.Font = Enum.Font.GothamBlack
		text.TextScaled = true
		text.TextColor3 = info.Color
		text.Text = def.Name:upper()
		text.Parent = gui
		gui.Parent = plaque
	end
end

local function render(player: Player)
	local plot = plotOf[player]
	local data = PlayerData.Get(player)
	if not plot or not data then
		return
	end
	plot.Displays:ClearAllChildren()
	local slots = slotsFor(data)
	local floorsUnlocked = math.ceil(slots / cfg.PerFloor)
	local maxFloors = math.ceil(maxEnabledSlots() / cfg.PerFloor)
	local half = cfg.PlotSize / 2
	local nextTier = cfg.Tiers[data.Vault.Tier + 1]

	-- Upper floors: solid when unlocked, ghostly outlines when still to come.
	for f = 2, maxFloors do
		local unlocked = f <= floorsUnlocked
		local floorCf = plot.CFrame * CFrame.new(0, (f - 1) * cfg.FloorHeight, 0)
		newPart(plot.Displays, {
			Name = "Floor" .. f,
			Size = Vector3.new(cfg.PlotSize - 2, 0.6, cfg.PlotSize - 2),
			CFrame = floorCf * CFrame.new(0, -0.3, 0),
			Color = if unlocked then Color3.fromRGB(62, 52, 88) else Color3.fromRGB(150, 200, 255),
			Material = if unlocked then Enum.Material.Marble else Enum.Material.Glass,
			Transparency = if unlocked then 0 else 0.85,
			CanCollide = unlocked,
		})
		if unlocked then
			for _, rail in {
				{ Vector3.new(cfg.PlotSize - 2, 3, 0.4), CFrame.new(0, 1.5, -half + 1) },
				{ Vector3.new(0.4, 3, cfg.PlotSize - 2), CFrame.new(-half + 1, 1.5, 0) },
				{ Vector3.new(0.4, 3, cfg.PlotSize - 2), CFrame.new(half - 1, 1.5, 0) },
			} do
				newPart(plot.Displays, { Name = "GlassRail", Size = rail[1], CFrame = floorCf * rail[2], Color = Color3.fromRGB(200, 235, 255), Material = Enum.Material.Glass, Transparency = 0.6 })
			end
		else
			local marker = newPart(plot.Displays, { Name = "LockedFloor", Size = Vector3.new(1, 1, 1), CFrame = floorCf * CFrame.new(0, 2, 0), Transparency = 1, CanCollide = false, CanQuery = false })
			label(marker, ("🔒 FLOOR %d"):format(f), Color3.fromRGB(190, 225, 255), 0, 90, 10)
		end
	end

	-- Columns hold up the unlocked upper floors (only as tall as the vault actually is).
	if floorsUnlocked > 1 then
		local columnHeight = (floorsUnlocked - 1) * cfg.FloorHeight
		for _, x in { -half + 1, half - 1 } do
			for _, z in { -half + 1, half - 1 } do
				newPart(plot.Displays, {
					Name = "Column",
					Size = Vector3.new(1.6, columnHeight, 1.6),
					CFrame = plot.CFrame * CFrame.new(x, columnHeight / 2, z),
					Color = Color3.fromRGB(235, 228, 210),
					Material = Enum.Material.Marble,
				})
			end
		end
	end

	-- Pedestals: filled slots, then ghost pedestals for the rest of the unlocked floors.
	local shownNextSign = false
	for index = 1, floorsUnlocked * cfg.PerFloor do
		local _, offset = slotPlacement(index)
		local base = plot.CFrame * offset
		if index <= slots then
			local id = data.Vault.Displays[tostring(index)]
			buildPedestal(plot.Displays, base, id and Treasures.Get(id), false)
		else
			buildPedestal(plot.Displays, base, nil, true)
			if not shownNextSign and nextTier and nextTier.Enabled then
				shownNextSign = true
				local anchor = newPart(plot.Displays, { Name = "NextTier", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false, CanQuery = false })
				label(anchor, ("🔒 UPGRADE • %d SLOTS • %s"):format(nextTier.Slots, formatShort(nextTier.Price)), Color3.fromRGB(255, 210, 80), 1, 60, 12)
			end
		end
	end

	-- Lift pads between unlocked floors (front-right corner of every floor).
	if floorsUnlocked > 1 then
		for f = 1, floorsUnlocked do
			local padCf = plot.CFrame * CFrame.new(half - 3.5, (f - 1) * cfg.FloorHeight, -half + 3.5)
			local pad = newPart(plot.Displays, {
				Name = "LiftPad" .. f,
				Shape = Enum.PartType.Cylinder,
				Size = Vector3.new(0.3, 4, 4),
				CFrame = padCf * CFrame.new(0, 0.15, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color = Color3.fromRGB(120, 220, 255),
				Material = Enum.Material.Neon,
				CanCollide = false,
			})
			for _, direction in { 1, -1 } do
				local target = f + direction
				if target >= 1 and target <= floorsUnlocked then
					local lift = Instance.new("ProximityPrompt")
					lift.ActionText = if direction > 0 then "Go Up" else "Go Down"
					lift.ObjectText = ("Floor %d"):format(target)
					lift.KeyboardKeyCode = if direction > 0 then Enum.KeyCode.E else Enum.KeyCode.Q
					lift.GamepadKeyCode = if direction > 0 then Enum.KeyCode.ButtonX else Enum.KeyCode.ButtonY
					lift.MaxActivationDistance = 8
					lift.RequiresLineOfSight = false
					lift.Parent = pad
					lift.Triggered:Connect(function(visitor)
						teleportPlayerToFloor(visitor, plot, target)
					end)
				end
			end
		end
	end
	plot.Sign.Text = ("%s'S VAULT"):format(player.DisplayName:upper())
end

teleportPlayerToFloor = function(player: Player, plot, floorIndex: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not character or not root then
		return
	end
	local half = cfg.PlotSize / 2
	local target = plot.CFrame * CFrame.new(half - 3.5, (floorIndex - 1) * cfg.FloorHeight + 3.5, -half + 7)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(target.Position, (plot.CFrame * CFrame.new(0, (floorIndex - 1) * cfg.FloorHeight + 3.5, 0)).Position))
end

local function countDisplayed(data, id: string, exceptSlot: string?): number
	local n = 0
	for slot, displayed in data.Vault.Displays do
		if displayed == id and slot ~= exceptSlot then
			n += 1
		end
	end
	return n
end

local function onSetSlot(player: Player, slot: any, id: any)
	local data = PlayerData.Get(player)
	if not data or type(slot) ~= "number" or slot ~= math.floor(slot) or type(id) ~= "string" then
		return
	end
	if slot < 1 or slot > slotsFor(data) then
		return
	end
	local key = tostring(slot)
	if id ~= "" then
		local entry = data.Collection[id]
		if not Treasures.Get(id) or not entry or entry.Count < countDisplayed(data, id, key) + 1 then
			return
		end
	end
	PlayerData.Update(player, function(d)
		d.Vault.Displays[key] = if id == "" then nil else id
	end)
	render(player)
end

local function onUpgrade(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	local nextTier = cfg.Tiers[data.Vault.Tier + 1]
	if not nextTier or not nextTier.Enabled then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Vault is at max size (for now!)", Tone = "Info" })
		return
	end
	if not PlayerData.TrySpend(player, nextTier.Price) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Not enough Cash", Tone = "Warn" })
		return
	end
	PlayerData.Update(player, function(d)
		d.Vault.Tier += 1
	end)
	Net.Fire("Notify", player, {
		Kind = "Banner",
		Title = "VAULT UPGRADED",
		Text = ("%d DISPLAY SLOTS"):format(nextTier.Slots),
		Tone = "Reward",
	})
	Analytics.Economy(player, "Sink", nextTier.Price, data.Cash, "Shop", "vault_tier_" .. (data.Vault.Tier))
	render(player)
end

local function autoPlace(player: Player, def)
	local data = PlayerData.Get(player)
	if not data or not cfg.AutoPlaceNewTreasures then
		return
	end
	for index = 1, slotsFor(data) do
		local key = tostring(index)
		if data.Vault.Displays[key] == nil then
			PlayerData.Update(player, function(d)
				d.Vault.Displays[key] = def.Id
			end)
			render(player)
			if PlayerData.Milestone(player, "FirstVault") then
				Analytics.Funnel(player, "FirstVault")
			end
			Net.Fire("Notify", player, { Kind = "Toast", Text = "🏆 ON DISPLAY IN YOUR VAULT", Tone = "Reward" })
			return
		end
	end
end

-- After a successful extraction the player is brought home to their Vault, proudly holding
-- the treasure overhead for a moment (cosmetic only: the treasure is already banked).
local function bringHome(player: Player, def)
	local plot = plotOf[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not character or not root then
		return
	end
	local standAt = (plot.CFrame * CFrame.new(0, 3.5, -cfg.HomeStandDistance)).Position
	local lookAt = Vector3.new(plot.CFrame.Position.X, standAt.Y, plot.CFrame.Position.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(standAt, lookAt))

	local s = TreasureVisual.Scale(def)
	local trophy = TreasureVisual.Build(def, root.CFrame * CFrame.new(0, 3.2 + s * 0.8, 0))
	trophy.Name = "HomeTrophy"
	local handle = trophy.PrimaryPart :: BasePart
	for _, d in trophy:GetDescendants() do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	handle.Anchored = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = handle
	weld.Parent = handle
	trophy.Parent = character
	task.delay(cfg.HomeTrophySeconds, function()
		trophy:Destroy()
	end)
end

local function onExtracted(player: Player, def)
	autoPlace(player, def)
	if cfg.TeleportHomeOnExtract then
		bringHome(player, def)
	end
end

local function assign(player: Player)
	for _, plot in plots do
		if not plot.Owner then
			plot.Owner = player
			plotOf[player] = plot
			player:SetAttribute("VaultPlot", plot.Index)
			render(player)
			return
		end
	end
	warn("[Vault] no free plot for", player.Name)
end

local function release(player: Player)
	local plot = plotOf[player]
	if plot then
		plot.Owner = nil
		plot.Displays:ClearAllChildren()
		plot.Sign.Text = "EMPTY VAULT"
		plotOf[player] = nil
	end
end

function VaultService.GetPlot(player: Player)
	return plotOf[player]
end

function VaultService.Init(builtPlots)
	plots = builtPlots
	for _, plot in plots do
		plot.Prompt.Triggered:Connect(function(player)
			if plot.Owner == player then
				Net.Fire("OpenMenu", player, { Menu = "Vault" })
			elseif plot.Owner then
				Net.Fire("Notify", player, {
					Kind = "Toast",
					Text = ("You're visiting %s's Vault"):format(plot.Owner.DisplayName),
					Tone = "Info",
				})
			end
		end)
	end
	PlayerData.Loaded:Connect(assign)
	Players.PlayerRemoving:Connect(release)
	Extraction.Completed:Connect(onExtracted)
	Net.On("SetVaultSlot", onSetSlot, 8)
	Net.On("UpgradeVault", onUpgrade, 2)
end

return VaultService
