-- Bats (Config/Bats, Shared/BatModels): the slap weapon in everyone's hand.
--   * Puts the equipped bat in the right hand of every character (visible to all). The weld's
--     C0 is the resting pose; clients animate it for the swing (Controllers/BatFx).
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

local function handOf(character: Model): BasePart?
	local hand = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if hand and hand:IsA("BasePart") then hand else nil
end

local function attach(player: Player)
	local character = player.Character
	if not character then
		return
	end
	local hand = handOf(character) or (character:WaitForChild("RightHand", 5) :: BasePart?)
	if not hand or not hand:IsA("BasePart") or not player.Character then
		return
	end
	local old = character:FindFirstChild("Bat")
	if old then
		old:Destroy()
	end
	local bat = BatService.Get(player)
	local model = BatModels.Build(bat.Id, hand.CFrame)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
		end
	end
	local weld = Instance.new("Weld")
	weld.Name = "BatGrip"
	weld.Part0 = hand
	weld.Part1 = model.PrimaryPart
	weld.C0 = Bats.Grip.Rest
	weld.Parent = model.PrimaryPart
	model.Parent = character
	player:SetAttribute("BatId", bat.Id)
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
