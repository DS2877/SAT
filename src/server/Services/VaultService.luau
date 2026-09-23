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

local function pedestalOffset(index: number): CFrame
	local i = index - 1
	local col = i % cfg.Columns
	local row = i // cfg.Columns
	local x = (col - (cfg.Columns - 1) / 2) * cfg.Spacing
	local z = -9 + row * cfg.Spacing
	return CFrame.new(x, 0, z)
end

local function label(parent: Instance, text: string, color: Color3, offsetY: number, maxDistance: number)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(150, 36)
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

local function render(player: Player)
	local plot = plotOf[player]
	local data = PlayerData.Get(player)
	if not plot or not data then
		return
	end
	plot.Displays:ClearAllChildren()
	local slots = slotsFor(data)
	for index = 1, slots do
		local base = plot.CFrame * pedestalOffset(index)
		local pedestal = Instance.new("Part")
		pedestal.Name = "Pedestal" .. index
		pedestal.Shape = Enum.PartType.Cylinder
		pedestal.Size = Vector3.new(2.6, 3.6, 3.6)
		pedestal.CFrame = base * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90))
		pedestal.Anchored = true
		pedestal.Material = Enum.Material.Marble
		pedestal.Color = Color3.fromRGB(235, 228, 210)
		pedestal.Parent = plot.Displays

		local id = data.Vault.Displays[tostring(index)]
		local def = id and Treasures.Get(id)
		if def then
			local info = Rarities.Info[def.Rarity]
			local rim = Instance.new("Part")
			rim.Name = "Rim"
			rim.Shape = Enum.PartType.Cylinder
			rim.Size = Vector3.new(0.3, 3.9, 3.9)
			rim.CFrame = base * CFrame.new(0, 2.65, 0) * CFrame.Angles(0, 0, math.rad(90))
			rim.Anchored = true
			rim.Material = Enum.Material.Neon
			rim.Color = info.Color
			rim.CanCollide = false
			rim.Parent = plot.Displays
			local s = TreasureVisual.Scale(def)
			local model = TreasureVisual.Build(def, base * CFrame.new(0, 2.8 + s * 0.9, 0))
			model:SetAttribute("TreasureId", def.Id)
			model:SetAttribute("VaultDisplay", true)
			model.Parent = plot.Displays
			label(model.PrimaryPart, ("%s %s"):format(info.Glyph, def.Name), info.Color, s + 1.5, 45)
		end
	end
	plot.Sign.Text = ("%s'S VAULT"):format(player.DisplayName:upper())
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
				Net.Fire("Notify", player, {
					Kind = "Banner",
					Title = "ON DISPLAY IN YOUR VAULT",
					Text = def.Name:upper(),
					Tone = "Reward",
				})
			end
			return
		end
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
	Extraction.Completed:Connect(autoPlace)
	Net.On("SetVaultSlot", onSetSlot, 8)
	Net.On("UpgradeVault", onUpgrade, 2)
end

return VaultService
