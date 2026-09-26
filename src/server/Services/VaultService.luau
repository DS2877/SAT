-- Physical Vaults = your money makers. Each player gets a plot in the Treasure District; every
-- extracted treasure sits on a pedestal and EARNS $/s (rarity x mutation x Ascension, x3 at
-- night). Earnings pile up on the plot's COLLECT pad until the owner steps on it. The owner can
-- sell a treasure (pedestal prompt or Vault menu) to free the pedestal for a better one.
-- Others can walk in and look (social flex).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Rarities = require(Shared.Config.Rarities)
local Treasures = require(Shared.Config.Treasures)
local TreasureVisual = require(Shared.TreasureVisual)
local TreasureLabel = require(Shared.TreasureLabel)
local Economy = require(Shared.Logic.Economy)
local DayNight = require(Shared.Logic.DayNight)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local Extraction = require(script.Parent.Extraction)
local Analytics = require(script.Parent.Analytics)

local VaultService = {}

local cfg = GameConfig.Vault
local plots = {} -- from WorldBuilder: { CFrame, Sign: TextLabel, Prompt, Displays: Folder, Owner }
local plotOf: { [Player]: any } = {}

-- Income boost from passes / Premium / friends / group, published by MonetizationService.
local function boostOf(player: Player?): number
	local boost = player and player:GetAttribute("IncomeBoost")
	return if type(boost) == "number" and boost > 0 then boost else 1
end

-- Hooks set by MonetizationService (defaults = no pass).
-- OfflineTerms(player) -> (rate, maxHours); AutoCollect(player) -> boolean.
VaultService.OfflineTerms = function(_player: Player): (number, number)
	return GameConfig.Economy.OfflineIncomeRate, GameConfig.Economy.OfflineMaxHours
end
VaultService.AutoCollect = function(_player: Player): boolean
	return false
end

local function slotsFor(data): number
	local tier = cfg.Tiers[data.Vault.Tier] or cfg.Tiers[1]
	return tier.Slots
end
VaultService.SlotsFor = slotsFor

local function formatCash(n: number): string
	local s = tostring(math.floor(n)):reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. (s:gsub("^,", ""))
end

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
	x += (if col < cfg.Columns / 2 then -1 else 1) * (cfg.AisleWidth or 0) / 2 -- central aisle
	local z = (row - (rows - 1) / 2) * cfg.RowSpacing + cfg.GridOffsetZ -- forward: stairs behind
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

-- Stair flight f (floor f -> f + 1): which band at the back (z) and which way it climbs (x).
-- Flights alternate between two bands so each one lands next to the start of the next.
local function stairBand(f: number): number
	return cfg.Stairs.BandsZ[(f - 1) % 2 + 1]
end
local function stairDirection(f: number): number
	return if f % 2 == 1 then 1 else -1
end
local sellSlot -- forward declaration (pedestal sell prompts)

-- owner/slot are set for filled pedestals (sell prompt); income = the owner's actual $/s.
local function buildPedestal(parent: Instance, base: CFrame, def, ghost: boolean, mutation: string?, owner: Player?, slot: number?, income: number?)
	local marble = Color3.fromRGB(235, 228, 210)
	local t = if ghost then 0.82 else 0
	newPart(parent, { Name = "Plinth", Size = Vector3.new(3.6, 0.5, 3.6), CFrame = base * CFrame.new(0, 0.25, 0), Color = Color3.fromRGB(70, 60, 95), Material = Enum.Material.Marble, Transparency = t, CanCollide = not ghost })
	local column = newPart(parent, { Name = "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(2.4, 2.2, 2.2), CFrame = base * CFrame.new(0, 1.7, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = marble, Material = Enum.Material.Marble, Transparency = t, CanCollide = not ghost })
	newPart(parent, { Name = "Cap", Size = Vector3.new(3.2, 0.4, 3.2), CFrame = base * CFrame.new(0, 3.1, 0), Color = Color3.fromRGB(255, 196, 50), Material = Enum.Material.Metal, Transparency = t, CanCollide = not ghost })
	if def then
		local info = Rarities.Info[def.Rarity]
		newPart(parent, { Name = "Rim", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.15, 3.3, 3.3), CFrame = base * CFrame.new(0, 3.35, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = info.Color, Material = Enum.Material.Neon, CanCollide = false })
		local s = math.min(TreasureVisual.Scale(def), cfg.DisplayMaxScale)
		local model = TreasureVisual.Build(def, base * CFrame.new(0, 3.5 + s * 0.9, 0), cfg.DisplayMaxScale, mutation, { Display = true })
		model:SetAttribute("TreasureId", def.Id)
		model:SetAttribute("VaultDisplay", true)
		local handle = model.PrimaryPart :: BasePart
		handle:SetAttribute("Spin", 0.6)
		model.Parent = parent
		-- Same name tag as in the world, but only readable up close so rows don't overlap.
		local tag = TreasureLabel.Build(def, mutation, {
			MaxDistance = GameConfig.Treasure.VaultLabelDistance,
			Height = s * 1.1 + 1,
			Income = income,
		})
		tag.Adornee = handle
		tag.Parent = handle
		if owner and slot then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "SellPrompt"
			prompt.ActionText = ("Sell %s"):format(formatShort(Economy.SellPrice(def, mutation)))
			prompt.ObjectText = if mutation then mutation .. " " .. def.Name else def.Name
			prompt.HoldDuration = 1.2
			-- E / X like every other prompt (F is SLAP and Y is gadget 3: a held attack must never sell).
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
			prompt.MaxActivationDistance = 6
			prompt.RequiresLineOfSight = false
			-- Clients hide sell prompts on other players' Vaults (VaultBeacon).
			prompt:SetAttribute("OwnerUserId", owner.UserId)
			prompt.Parent = column
			prompt.Triggered:Connect(function(player)
				if player == owner then
					sellSlot(player, slot)
				end
			end)
		end
	end
end

-- TROPHY PEDESTAL outside the gate (left; the collect pad is on the right): your BEST treasure
-- (highest $/s in the Vault, mutation included) at more than full size, with every rarity and
-- mutation effect, under a spotlight - a flex for everyone walking the plaza.
local TROPHY_SCALE = 1.5

local function bestSlot(data): (any, string?, number)
	local best, bestMutation, bestIncome = nil, nil, -1
	for _, value in data.Vault.Displays do
		local id, mutation = Economy.DecodeSlot(value)
		local def = id and Treasures.Get(id)
		if def then
			local income = Economy.Income(def, mutation)
			if income > bestIncome then
				best, bestMutation, bestIncome = def, mutation, income
			end
		end
	end
	return best, bestMutation, bestIncome
end

local function buildTrophy(plot, player: Player, data, incomeMultiplier: number)
	local half = cfg.PlotDepth / 2
	local base = plot.CFrame * CFrame.new(-11.5, 0, -half - 5)
	local def, mutation, income = bestSlot(data)
	local gold = Color3.fromRGB(255, 196, 50)
	local marble = Color3.fromRGB(240, 234, 220)
	-- A stepped plinth with a gold rim.
	newPart(plot.Displays, { Name = "TrophyStep", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.8, 7, 7), CFrame = base * CFrame.new(0, 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(60, 50, 80), Material = Enum.Material.Marble })
	newPart(plot.Displays, { Name = "TrophyColumn", Shape = Enum.PartType.Cylinder, Size = Vector3.new(3.4, 4, 4), CFrame = base * CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = marble, Material = Enum.Material.Marble })
	newPart(plot.Displays, { Name = "TrophyTop", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 5.4, 5.4), CFrame = base * CFrame.new(0, 4.45, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = Enum.Material.Metal, Reflectance = 0.2 })
	if not def then
		local sign = newPart(plot.Displays, { Name = "TrophyEmpty", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 6.5, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		label(sign, "🏆 YOUR BEST TREASURE GOES HERE", Color3.fromRGB(255, 225, 140), 0, 40, 8)
		return
	end
	local info = Rarities.Info[def.Rarity]
	local model = TreasureVisual.Build(def, base * CFrame.new(0, 4.7, 0), nil, mutation, { Display = true })
	model.Name = "Trophy"
	model:ScaleTo(TROPHY_SCALE)
	-- Stand it on the plinth, whatever its size.
	local _, size = model:GetBoundingBox()
	model:PivotTo(base * CFrame.new(0, 4.7 + size.Y / 2 + 0.3, 0))
	model.Parent = plot.Displays
	-- A soft spotlight column in the treasure's rarity colour.
	local beam = newPart(plot.Displays, {
		Name = "TrophyLight",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(18, 6, 6),
		CFrame = base * CFrame.new(0, 13.7, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = info.Color,
		Material = Enum.Material.Neon,
		Transparency = 0.9,
		CanCollide = false,
		CanQuery = false,
		CastShadow = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Left -- the cylinder's -X points down
	spot.Color = info.Color
	spot.Brightness = 3
	spot.Range = 20
	spot.Angle = 50
	spot.Parent = beam
	-- A small nameplate on the plinth: whose, what, how much.
	local plate = newPart(plot.Displays, { Name = "TrophyPlate", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 1.6, -2.3), Transparency = 1, CanCollide = false, CanQuery = false })
	local mutationText = if mutation and mutation ~= "" then mutation:upper() .. " " else ""
	label(plate, ("%s • %s%s"):format(player.DisplayName, mutationText, def.Name:upper()), info.Color, 0, 70, 7)
	local rate = newPart(plot.Displays, { Name = "TrophyRate", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 0.7, -2.3), Transparency = 1, CanCollide = false, CanQuery = false })
	label(rate, ("%s %s • %s/s"):format(info.Glyph or "", def.Rarity:upper(), formatShort(math.floor(income * incomeMultiplier + 0.5))), Color3.fromRGB(120, 235, 120), 0, 45, 5)
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
	local halfW, halfD = cfg.PlotWidth / 2, cfg.PlotDepth / 2
	local half = halfD
	local nextTier = cfg.Tiers[data.Vault.Tier + 1]

	-- UPPER FLOORS: solid marble with glass rails when unlocked (with a stairwell where the stairs
	-- from below come up); floors still to buy are only a thin glowing outline, so nothing hides
	-- the treasure names and earnings on the floors below.
	local stairs = cfg.Stairs
	for f = 2, maxFloors do
		local floorCf = plot.CFrame * CFrame.new(0, (f - 1) * cfg.FloorHeight, 0)
		if f <= floorsUnlocked then
			local band = stairBand(f - 1)
			local x0, x1 = -halfW + 1, halfW - 1
			local z0, z1 = -halfD + 1, halfD - 1
			local bandMin, bandMax = band - stairs.Width / 2, band + stairs.Width / 2
			for _, slab in {
				{ x0, x1, z0, bandMin }, -- in front of the stairwell (the gallery)
				{ x0, x1, bandMax, z1 }, -- behind it
				{ x0, -stairs.Run / 2, bandMin, bandMax }, -- either end of it
				{ stairs.Run / 2, x1, bandMin, bandMax },
			} do
				local sx, sz = slab[2] - slab[1], slab[4] - slab[3]
				if sx > 0.05 and sz > 0.05 then
					newPart(plot.Displays, {
						Name = "Floor" .. f,
						Size = Vector3.new(sx, 0.6, sz),
						CFrame = floorCf * CFrame.new((slab[1] + slab[2]) / 2, -0.3, (slab[3] + slab[4]) / 2),
						Color = Color3.fromRGB(62, 52, 88),
						Material = Enum.Material.Marble,
					})
				end
			end
			local glass = Color3.fromRGB(200, 235, 255)
			local rails = {
				{ Vector3.new(halfW * 2 - 2, 3, 0.4), CFrame.new(0, 1.5, -halfD + 1) },
				{ Vector3.new(0.4, 3, halfD * 2 - 2), CFrame.new(-halfW + 1, 1.5, 0) },
				{ Vector3.new(0.4, 3, halfD * 2 - 2), CFrame.new(halfW - 1, 1.5, 0) },
				-- Around the stairwell (open only where the stairs arrive).
				{ Vector3.new(stairs.Run, 3, 0.3), CFrame.new(0, 1.5, bandMin) },
				{ Vector3.new(stairs.Run, 3, 0.3), CFrame.new(0, 1.5, bandMax) },
				{ Vector3.new(0.3, 3, stairs.Width), CFrame.new(-stairDirection(f - 1) * stairs.Run / 2, 1.5, band) },
			}
			for _, rail in rails do
				newPart(plot.Displays, { Name = "GlassRail", Size = rail[1], CFrame = floorCf * rail[2], Color = glass, Material = Enum.Material.Glass, Transparency = 0.6 })
			end
		else
			-- A floor still to buy: just a glowing outline where it will be.
			for _, bar in {
				{ Vector3.new(halfW * 2 - 2, 0.25, 0.25), CFrame.new(0, 0, -halfD + 1) },
				{ Vector3.new(halfW * 2 - 2, 0.25, 0.25), CFrame.new(0, 0, halfD - 1) },
				{ Vector3.new(0.25, 0.25, halfD * 2 - 2), CFrame.new(-halfW + 1, 0, 0) },
				{ Vector3.new(0.25, 0.25, halfD * 2 - 2), CFrame.new(halfW - 1, 0, 0) },
			} do
				newPart(plot.Displays, {
					Name = "FutureFloorEdge",
					Size = bar[1],
					CFrame = floorCf * CFrame.new(0, -0.3, 0) * bar[2],
					Color = Color3.fromRGB(150, 210, 255),
					Material = Enum.Material.Neon,
					Transparency = 0.45,
					CanCollide = false,
					CanQuery = false,
					CastShadow = false,
				})
			end
			local marker = newPart(plot.Displays, { Name = "LockedFloor", Size = Vector3.new(1, 1, 1), CFrame = floorCf * CFrame.new(0, 2, halfD - 3), Transparency = 1, CanCollide = false, CanQuery = false })
			label(marker, ("🔒 FLOOR %d"):format(f), Color3.fromRGB(190, 225, 255), 0, 90, 10)
		end
	end

	-- STAIRS: a wide switchback staircase at the back of the gallery, one flight per floor.
	for f = 1, floorsUnlocked - 1 do
		local band = stairBand(f)
		local direction = stairDirection(f)
		local steps = math.floor(cfg.FloorHeight + 0.5)
		local rise = cfg.FloorHeight / steps
		local run = stairs.Run / steps
		local base = plot.CFrame * CFrame.new(0, (f - 1) * cfg.FloorHeight, band)
		for i = 1, steps do
			local x = direction * (-stairs.Run / 2 + (i - 0.5) * run)
			newPart(plot.Displays, {
				Name = "Stair",
				Size = Vector3.new(run + 0.05, rise, stairs.Width),
				CFrame = base * CFrame.new(x, (i - 0.5) * rise, 0),
				Color = if i % 2 == 0 then Color3.fromRGB(235, 228, 210) else Color3.fromRGB(222, 214, 196),
				Material = Enum.Material.Marble,
			})
			newPart(plot.Displays, {
				Name = "StairNosing",
				Size = Vector3.new(0.2, 0.12, stairs.Width),
				CFrame = base * CFrame.new(x + direction * (run / 2 - 0.1), i * rise + 0.02, 0),
				Color = Color3.fromRGB(255, 196, 50),
				Material = Enum.Material.Metal,
				CanCollide = false,
				CanQuery = false,
			})
		end
		-- A sloped glass handrail on the gallery side.
		local length = math.sqrt(stairs.Run ^ 2 + cfg.FloorHeight ^ 2)
		local slope = math.atan2(cfg.FloorHeight, stairs.Run) * direction
		newPart(plot.Displays, {
			Name = "StairRail",
			Size = Vector3.new(length, 2.6, 0.3),
			CFrame = base * CFrame.new(0, cfg.FloorHeight / 2 + 1.6, -stairs.Width / 2 - 0.2) * CFrame.Angles(0, 0, slope),
			Color = Color3.fromRGB(200, 235, 255),
			Material = Enum.Material.Glass,
			Transparency = 0.6,
		})
		local sign = newPart(plot.Displays, { Name = "StairSign", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(-direction * (stairs.Run / 2 - 1), 3, 0), Transparency = 1, CanCollide = false, CanQuery = false })
		label(sign, ("⬆ FLOOR %d"):format(f + 1), Color3.fromRGB(255, 225, 140), 0, 40, 5)
	end

	-- Columns hold up the unlocked upper floors (only as tall as the vault actually is).
	if floorsUnlocked > 1 then
		local columnHeight = (floorsUnlocked - 1) * cfg.FloorHeight
		for _, x in { -halfW + 1, halfW - 1 } do
			for _, z in { -halfD + 1, halfD - 1 } do
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
	local incomeMultiplier = Economy.IncomeMultiplier(data, Treasures.List, GameConfig.GetAscensionMultiplier(data.Ascension), boostOf(player))
	for index = 1, floorsUnlocked * cfg.PerFloor do
		local _, offset = slotPlacement(index)
		local base = plot.CFrame * offset
		if index <= slots then
			local id, mutation = Economy.DecodeSlot(data.Vault.Displays[tostring(index)])
			local def = id and Treasures.Get(id)
			local income = if def
				then math.floor(Economy.Income(def, mutation) * incomeMultiplier + 0.5)
				else nil
			buildPedestal(plot.Displays, base, def, false, mutation, player, index, income)
		else
			buildPedestal(plot.Displays, base, nil, true)
			if not shownNextSign and nextTier and nextTier.Enabled then
				shownNextSign = true
				local anchor = newPart(plot.Displays, { Name = "NextTier", Size = Vector3.new(1, 1, 1), CFrame = base * CFrame.new(0, 4, 0), Transparency = 1, CanCollide = false, CanQuery = false })
				label(anchor, ("🔒 UPGRADE • %d SLOTS • %s"):format(nextTier.Slots, formatShort(nextTier.Price)), Color3.fromRGB(255, 210, 80), 1, 60, 12)
			end
		end
	end

	buildTrophy(plot, player, data, incomeMultiplier)

	-- COLLECT pad OUTSIDE the entrance (right of the gate) with a sign board facing the plaza:
	-- inside the Vault the text got cut by the gate posts and clashed with the treasure tags.
	local padCf = plot.CFrame * CFrame.new(11.5, 0, -half - 4.5)
	newPart(plot.Displays, {
		Name = "CollectPad",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.5, 5, 5),
		CFrame = padCf * CFrame.new(0, -0.35, 0) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 235, 110),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local board = newPart(plot.Displays, {
		Name = "CollectBoard",
		Size = Vector3.new(6, 3.4, 0.4),
		CFrame = plot.CFrame * CFrame.new(11.5, 4.6, -half - 1.3),
		Color = Color3.fromRGB(28, 36, 30),
		Material = Enum.Material.SmoothPlastic,
		CanCollide = false,
	})
	newPart(plot.Displays, {
		Name = "CollectBoardTrim",
		Size = Vector3.new(6.4, 3.8, 0.3),
		CFrame = plot.CFrame * CFrame.new(11.5, 4.6, -half - 1.05),
		Color = Color3.fromRGB(255, 196, 50),
		Material = Enum.Material.Metal,
		CanCollide = false,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front -- -Z: towards the plaza
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 50
	surface.LightInfluence = 0
	surface.MaxDistance = 120
	local function text(name: string, y: number, height: number, color: Color3, value: string)
		local label = Instance.new("TextLabel")
		label.Name = name
		label.BackgroundTransparency = 1
		label.Position = UDim2.fromScale(0.04, y)
		label.Size = UDim2.fromScale(0.92, height)
		label.Font = Enum.Font.FredokaOne
		label.TextScaled = true
		label.TextColor3 = color
		label.Text = value
		local outline = Instance.new("UIStroke")
		outline.Thickness = 3
		outline.Parent = label
		label.Parent = surface
		return label
	end
	text("Title", 0.04, 0.22, Color3.fromRGB(255, 220, 110), "💰 COLLECT")
	local amount = text("Amount", 0.28, 0.42, Color3.fromRGB(80, 255, 90), "$0")
	local rate = text("Rate", 0.72, 0.22, Color3.new(1, 1, 1), "")
	surface.Parent = board
	plot.CollectPosition = (padCf * CFrame.new(0, -0.35, 0)).Position
	plot.CollectAmount = amount
	plot.CollectRate = rate

	plot.Sign.Text = ("%s'S VAULT"):format(player.DisplayName:upper())
end

sellSlot = function(player: Player, slot: any)
	local data = PlayerData.Get(player)
	if not data or type(slot) ~= "number" or slot ~= math.floor(slot) then
		return
	end
	local key = tostring(slot)
	local id, mutation = Economy.DecodeSlot(data.Vault.Displays[key])
	local def = id and Treasures.Get(id)
	if not def then
		return
	end
	local price = Economy.SellPrice(def, mutation)
	PlayerData.Update(player, function(d)
		d.Vault.Displays[key] = nil
		d.Cash += price
		d.Stats.TotalEarned += price
	end)
	Net.Fire("Feedback", player, { Type = "Sold", TreasureId = def.Id, Mutation = mutation, Amount = price })
	Analytics.Economy(player, "Source", price, data.Cash, "Gameplay", "sell_" .. def.Id)
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
	if PlayerData.Milestone(player, "FirstVaultUpgrade") then
		Analytics.Funnel(player, "FirstVaultUpgrade")
	end
	Net.Fire("Notify", player, {
		Kind = "Banner",
		Title = "VAULT UPGRADED",
		Text = ("%d DISPLAY SLOTS"):format(nextTier.Slots),
		Tone = "Reward",
	})
	Analytics.Economy(player, "Sink", nextTier.Price, data.Cash, "Shop", "vault_tier_" .. (data.Vault.Tier))
	render(player)
end

-- After a successful extraction the player is brought home to their Vault, proudly holding
-- the treasure overhead for a moment (cosmetic only: the treasure is already banked).
-- Teleports a player to the plaza in front of their Vault, facing it. Returns their root.
local function sendHome(player: Player): BasePart?
	local plot = plotOf[player]
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not plot or not character or not root then
		return nil
	end
	local standAt = (plot.CFrame * CFrame.new(0, 3.5, -cfg.HomeStandDistance)).Position
	local lookAt = Vector3.new(plot.CFrame.Position.X, standAt.Y, plot.CFrame.Position.Z)
	root.AssemblyLinearVelocity = Vector3.zero
	character:PivotTo(CFrame.lookAt(standAt, lookAt))
	return root
end
VaultService.SendHome = sendHome

local function bringHome(player: Player, def, mutation: string?)
	local root = sendHome(player)
	local character = player.Character
	if not root or not character then
		return
	end

	local s = TreasureVisual.Scale(def)
	local trophy = TreasureVisual.Build(def, root.CFrame * CFrame.new(0, 3.2 + s * 0.8, 0), nil, mutation, { Display = true })
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

local function onExtracted(player: Player, def, mutation: string?, placedSlot: number?, soldFor: number)
	render(player)
	if not placedSlot then
		Net.Fire("Notify", player, {
			Kind = "Banner",
			Title = "VAULT FULL",
			Text = ("Sold for %s • Upgrade or sell to make room"):format(formatShort(soldFor)),
			Tone = "Warn",
		})
	end
	if cfg.TeleportHomeOnExtract then
		bringHome(player, def, mutation)
	end
end

-- EARNINGS ------------------------------------------------------------------------------

-- Pending cash per player (not yet collected). Mirrored into data.Vault.Stored so it survives
-- leaving; mutated directly (no DataSync every second) because only the pad sign shows it.
-- `dayRate`: ignore the night bonus (scaled rewards must not be worth 3x at night).
local function incomeOf(data, player: Player?, dayRate: boolean?): number
	return Economy.VaultIncome(
		data.Vault.Displays,
		Treasures.Get,
		Economy.IncomeMultiplier(data, Treasures.List, GameConfig.GetAscensionMultiplier(data.Ascension), boostOf(player)),
		not dayRate and DayNight.IsNight(workspace:GetServerTimeNow())
	)
end
VaultService.IncomeOf = incomeOf

local function collect(player: Player, data, quiet: boolean?)
	local amount = math.floor(data.Vault.Stored)
	if amount < 1 then
		return
	end
	PlayerData.Update(player, function(d)
		d.Vault.Stored -= amount
		d.Cash += amount
		d.Stats.TotalEarned += amount
	end)
	if quiet then
		return -- Auto Collect / still standing on the pad: no banner every second
	end
	Net.Fire("Feedback", player, { Type = "Collected", Amount = amount })
	if PlayerData.Milestone(player, "FirstCollect") then
		Analytics.Funnel(player, "FirstCollect")
	end
	Analytics.Economy(player, "Source", amount, data.Cash, "Gameplay", "vault_income")
end

local function earningsTick(dt: number)
	for player, plot in plotOf do
		local data = PlayerData.Get(player)
		if data then
			local income = incomeOf(data, player)
			data.Vault.Stored += income * dt
			data.LastOnline = os.time() -- saved with the profile; drives offline earnings
			player:SetAttribute("VaultIncome", income)
			if VaultService.AutoCollect(player) and data.Vault.Stored >= 1 then
				collect(player, data, true)
			end
			if plot.CollectAmount then
				plot.CollectAmount.Text = formatCash(data.Vault.Stored)
				plot.CollectRate.Text = ("+%s/s • STEP ON THE PAD"):format(formatCash(income))
			end
		end
	end
end

-- COLLECT PAD: checked 10x a second so the cash pops the instant you step on it. Stepping ON
-- plays the big "COLLECTED" moment; staying on it keeps banking new income quietly.
local onPad: { [Player]: boolean } = {}
local function padTick()
	for player, plot in plotOf do
		local data = PlayerData.Get(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local standing = false
		if data and root and plot.CollectPosition then
			local offset = root.Position - plot.CollectPosition
			standing = Vector2.new(offset.X, offset.Z).Magnitude <= GameConfig.Economy.CollectRadius and math.abs(offset.Y) < 6
		end
		if standing and data then
			collect(player, data, onPad[player] == true)
			if plot.CollectAmount then
				plot.CollectAmount.Text = formatCash(data.Vault.Stored)
			end
		end
		onPad[player] = standing
	end
end

-- Offline earnings at the offline rate, paid onto the collect pad when the player comes back.
local function payOffline(player: Player)
	local data = PlayerData.Get(player)
	if not data then
		return
	end
	-- Passes (Night Shift) and boosts are checked asynchronously on join: give them a moment.
	local waited = 0
	while player.Parent and not player:GetAttribute("MonetizationReady") and waited < 10 do
		waited += task.wait(0.5)
	end
	local income = Economy.VaultIncome(
		data.Vault.Displays,
		Treasures.Get,
		Economy.IncomeMultiplier(data, Treasures.List, GameConfig.GetAscensionMultiplier(data.Ascension), boostOf(player)),
		false
	)
	local now = os.time()
	local rate, hours = VaultService.OfflineTerms(player)
	local amount, seconds = Economy.OfflineEarnings(income, data.LastOnline, now, rate, hours)
	PlayerData.Update(player, function(d)
		d.Vault.Stored += amount
		d.LastOnline = now
	end)
	if amount > 0 then
		task.delay(5, function()
			if player.Parent then
				Net.Fire("Notify", player, {
					Kind = "Banner",
					Title = "💤 WELCOME BACK",
					Text = ("Your Vault earned %s while you were away (%d%% for %s) • collect it on your pad"):format(
						formatCash(amount),
						math.floor(rate * 100 + 0.5),
						if seconds >= 3600 then ("%.1fh"):format(seconds / 3600) else ("%dm"):format(seconds // 60)
					),
					Tone = "Reward",
				})
			end
		end)
		Analytics.Event(player, "OfflineEarnings", { Amount = amount, Seconds = seconds })
	end
end

local function assign(player: Player)
	task.spawn(payOffline, player)
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
		plot.CollectPosition = nil
		plot.CollectAmount = nil
		plot.CollectRate = nil
		plotOf[player] = nil
	end
end

-- Redraw a player's Vault after its contents changed elsewhere (e.g. Ascension).
function VaultService.Render(player: Player)
	if plotOf[player] then
		render(player)
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
				Net.Fire("OpenMenu", player, { Menu = "Vault", Anchor = (plot.Prompt.Parent :: BasePart).Position })
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
	Net.On("SellTreasure", sellSlot, 4)
	Net.On("UpgradeVault", onUpgrade, 2)

	task.spawn(function()
		while true do
			task.wait(0.1)
			local ok, err = pcall(padTick)
			if not ok then
				warn("[Vault] pad tick error:", err)
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		onPad[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(1)
			local now = os.clock()
			local ok, err = pcall(earningsTick, now - last)
			last = now
			if not ok then
				warn("[Vault] earnings tick error:", err)
			end
		end
	end)
end

return VaultService
