-- Bats (Config/Bats, Shared/BatModels): the slap weapon in everyone's hand.
--   * Gives every character the equipped bat as a real Roblox TOOL, held in hand: Roblox does
--     the grip (Config/Bats Grip) and the arm-out hold pose, like every Roblox melee game.
--     The swing itself is our own swat (Controllers/BatFx). No hotbar: the Backpack UI is
--     off (Controllers/BatFx), and while you carry treasure the bat goes to your back pocket
--     (Backpack) - both hands are on the loot - and comes back when you're done.
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

-- In hand unless carrying treasure (then in the Backpack).
local function place(player: Player)
	local tool = toolOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not tool or not humanoid or humanoid.Health <= 0 or not backpack then
		return
	end
	local carrying = (player:GetAttribute("CarryingUid") or 0) ~= 0
	if carrying and tool.Parent ~= backpack then
		tool.Parent = backpack
	elseif not carrying and tool.Parent ~= character then
		humanoid:EquipTool(tool)
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
