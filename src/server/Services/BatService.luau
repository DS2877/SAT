-- Bats (Config/Bats, Shared/BatModels): the slap weapon in everyone's hand.
--   * Gives every character the equipped bat as a real Roblox TOOL, held in hand: Roblox does
--     the grip (Config/Bats Grip) and the arm-out hold pose, like every Roblox melee game.
--     The swing itself is our own swat (Controllers/BatFx). No hotbar: the Backpack UI is
--     off (Controllers/BatFx). The bat goes ON YOUR BACK (a copy strapped across it, the Tool
--     itself waits in the Backpack) while you carry treasure - both hands are on the loot -
--     or when you sheathe it (setting "SheatheBat"); pressing SLAP draws it again (Draw).
--   * Buying (Cash, plus an Ascension level from tier 5) and equipping, from the Bat Shop.
--   * Combat asks Get(player) for the equipped bat's Knockback and Range.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Bats = require(Shared.Config.Bats)
local BatModels = require(Shared.BatModels)
local Net = require(Shared.Net)

local PlayerData = require(script.Parent.PlayerData)
local Analytics = require(script.Parent.Analytics)

local BatService = {}

function BatService.Get(player: Player): Bats.Bat
	return Bats.Equipped(PlayerData.Get(player))
end

local function toolOf(player: Player): Tool?
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		local tool = container and container:FindFirstChild("Bat")
		if tool and tool:IsA("Tool") then
			return tool
		end
	end
	return nil
end

-- The bat strapped diagonally across your back (a display copy; the Tool stays in the Backpack).
local function backModelOf(character: Model): Model?
	local model = character:FindFirstChild("BatOnBack")
	return if model and model:IsA("Model") then model else nil
end

local function setOnBack(player: Player, show: boolean)
	local character = player.Character
	if not character then
		return
	end
	local existing = backModelOf(character)
	local batId = tostring(player:GetAttribute("BatId") or Bats.StarterId)
	if existing and (not show or existing:GetAttribute("BatId") ~= batId) then
		existing:Destroy()
		existing = nil
	end
	if not show or existing then
		return
	end
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	-- Knob low on the right hip, head over the left shoulder, resting against the back (+Z).
	local offset = CFrame.new(0.8, -0.9, torso.Size.Z / 2 + 0.35) * CFrame.Angles(0, 0, math.rad(38))
	local model = BatModels.Build(batId, torso.CFrame * offset)
	model.Name = "BatOnBack"
	model:SetAttribute("BatId", batId)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		elseif d:IsA("ParticleEmitter") or d:IsA("Trail") then
			d.Enabled = false
		end
	end
	local weld = Instance.new("Weld")
	weld.Part0 = torso
	weld.Part1 = model.PrimaryPart
	weld.C0 = offset
	weld.Parent = model.PrimaryPart
	model.Parent = character
end

-- In hand, unless carrying treasure or sheathed: then it's on your back.
local function place(player: Player)
	local tool = toolOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool or not character or not humanoid or humanoid.Health <= 0 or not backpack then
		return
	end
	local data = PlayerData.Get(player)
	local sheathed = data ~= nil and data.Settings.SheatheBat == true
	local carrying = (player:GetAttribute("CarryingUid") or 0) ~= 0
	local inHand = not carrying and not sheathed
	if not inHand and tool.Parent ~= backpack then
		humanoid:UnequipTools()
		tool.Parent = backpack
	elseif inHand and tool.Parent ~= character then
		humanoid:EquipTool(tool)
	end
	setOnBack(player, not inHand)
end
BatService.Place = place

-- SLAP while sheathed: draw the bat (and remember it's out).
function BatService.Draw(player: Player)
	local data = PlayerData.Get(player)
	if data and data.Settings.SheatheBat then
		PlayerData.Update(player, function(d)
			d.Settings.SheatheBat = false
		end)
		place(player)
	end
end

local function attach(player: Player)
	local character = player.Character
	if not character or not character:FindFirstChildOfClass("Humanoid") then
		return
	end
	local old = toolOf(player)
	if old then
		old:Destroy()
	end
	local bat = BatService.Get(player)
	local model = BatModels.Build(bat.Id, CFrame.new())
	local tool = Instance.new("Tool")
	tool.Name = "Bat"
	tool.CanBeDropped = false
	tool.ManualActivationOnly = true -- the SLAP button / click goes through Combat
	tool.RequiresHandle = true
	tool.Grip = Bats.Grip
	tool:SetAttribute("BatId", bat.Id)
	local grip = model.PrimaryPart :: BasePart
	grip.Name = "Handle"
	for _, child in model:GetChildren() do
		child.Parent = tool
	end
	model:Destroy()
	for _, d in tool:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	tool.Parent = player:FindFirstChildOfClass("Backpack") or player:WaitForChild("Backpack", 5)
	player:SetAttribute("BatId", bat.Id)
	place(player)
end

local function onBuy(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local bat = Bats.Get(id)
	local data = PlayerData.Get(player)
	if not bat or not data then
		return
	end
	local problem = Bats.BuyProblem(data, bat)
	if problem == "Ascension" then
		Net.Fire("Notify", player, { Kind = "Toast", Text = ("Needs ASCENSION %d"):format(bat.RequiredAscension), Tone = "Warn" })
		return
	elseif problem ~= nil and problem ~= "Cash" then
		return
	end
	if problem == "Cash" or not PlayerData.TrySpend(player, bat.Price) then
		Net.Fire("Notify", player, { Kind = "Toast", Text = "Not enough Cash", Tone = "Warn" })
		return
	end
	PlayerData.Update(player, function(d)
		d.OwnedBats[bat.Id] = true
		d.EquippedBat = bat.Id -- a new bat goes straight into your hand
	end)
	attach(player)
	Net.Fire("Notify", player, { Kind = "Banner", Title = "🏏 NEW BAT!", Text = ("%s • slaps %d%% harder than the Wooden Bat"):format(bat.Name:upper(), math.floor((bat.Knockback / Bats.List[1].Knockback - 1) * 100 + 0.5)), Tone = "Reward" })
	Net.Fire("Feedback", player, { Type = "BatBought", BatId = bat.Id })
	if bat.Tier >= 5 then
		Net.FireAll("Notify", { Kind = "Social", Text = ("%s GOT THE %s"):format(player.DisplayName:upper(), bat.Name:upper()), Rarity = if bat.Tier >= 9 then "Mythic" elseif bat.Tier >= 7 then "Legendary" else "Epic" })
	end
	Analytics.Economy(player, "Sink", bat.Price, data.Cash, "BatShop", bat.Id)
	Analytics.Event(player, "BatBought", { Bat = bat.Id })
end

local function onEquip(player: Player, id: any)
	if type(id) ~= "string" then
		return
	end
	local bat = Bats.Get(id)
	local data = PlayerData.Get(player)
	if not bat or not data or not (bat.Price == 0 or data.OwnedBats[bat.Id]) then
		return
	end
	PlayerData.Update(player, function(d)
		d.EquippedBat = bat.Id
	end)
	attach(player)
end

-- Rebuild the bat in hand (e.g. after a save reset).
function BatService.Refresh(player: Player)
	attach(player)
end

function BatService.Init()
	Net.On("BuyBat", onBuy, 3)
	Net.On("EquipBat", onEquip, 4)
	local function watch(player: Player)
		player.CharacterAdded:Connect(function()
			task.defer(attach, player)
		end)
		player:GetAttributeChangedSignal("CarryingUid"):Connect(function()
			place(player)
		end)
		if player.Character then
			task.defer(attach, player)
		end
	end
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	PlayerData.Loaded:Connect(function(player)
		attach(player)
	end)
end

return BatService
