-- Deep South storms (GameConfig.Events.Storms), run by EventService as daytime events:
--   * ERUPTION over Emberfall: Mount Cinder lobs lava bombs.
--   * BLIZZARD over Rimeheart: falling ice (the client adds the wind and the whiteout).
--   * METEOR SHOWER over the Starfall Isles: shooting stars crash onto the isles.
-- Every strike paints a warning ring on the ground first, then something falls onto it. Be
-- inside when it lands and you're flung - and DROP what you carry. Some strikes crack open
-- with treasure from the region, so the brave run INTO the storm. Half the strikes aim near
-- players in the region (it should feel like it's hunting you), half at the region's
-- treasure spots.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local WorldLayout = require(Shared.Config.WorldLayout)
local TreasureRoll = require(Shared.Logic.TreasureRoll)
local Zones = require(Shared.Util.Zones)
local Net = require(Shared.Net)

local TreasureService = require(script.Parent.TreasureService)
local Combat = require(script.Parent.Combat)

local RegionStorms = {}

local rng = Random.new()
local LOOT_LIFETIME = 45

-- Someone on the server has the Ascension to go where this storm hits.
function RegionStorms.Eligible(stormId: string): boolean
	local storm = GameConfig.Events.Storms[stormId]
	local need = GameConfig.Regions[storm.Area].RequiredAscension or 0
	for _, player in Players:GetPlayers() do
		if (player:GetAttribute("Ascension") or 0) >= need then
			return true
		end
	end
	return false
end

local function rollLoot(storm)
	local perRarity = {}
	for _, def in Treasures.List do
		if def.SpawnArea == storm.Area and storm.Loot[def.Rarity] then
			perRarity[def.Rarity] = (perRarity[def.Rarity] or 0) + 1
		end
	end
	local candidates = {}
	for _, def in Treasures.List do
		local w = storm.Loot[def.Rarity]
		if w and def.SpawnArea == storm.Area then
			table.insert(candidates, { Def = def, Weight = w / perRarity[def.Rarity] })
		end
	end
	return TreasureRoll.Pick(candidates, function()
		return rng:NextNumber()
	end)
end

-- Where the next strike lands (before finding the ground).
local function pickTarget(storm): Vector3?
	local hunted = {}
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and Zones.AreaId(root.Position) == storm.Area then
			table.insert(hunted, root.Position)
		end
	end
	if #hunted > 0 and rng:NextNumber() < 0.5 then
		local near = hunted[rng:NextInteger(1, #hunted)]
		local a, d = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(4, 22)
		return near + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
	end
	local spots = {}
	for _, info in WorldLayout.TreasureSpawns do
		if info.Area == storm.Area then
			table.insert(spots, info.Position)
		end
	end
	if #spots == 0 then
		return nil
	end
	local spot = spots[rng:NextInteger(1, #spots)]
	local a, d = rng:NextNumber(0, 2 * math.pi), rng:NextNumber(0, 20)
	return spot + Vector3.new(math.cos(a) * d, 0, math.sin(a) * d)
end

local function newPart(props): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	for key, value in props do
		(p :: any)[key] = value
	end
	return p
end

-- The thing that falls: lava bomb, ice chunk or shooting star.
local function projectile(stormId: string, color: Color3, parent: Instance): BasePart
	local bomb = newPart({
		Name = "StormStrike",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(4, 4, 4),
		Color = if stormId == "Eruption" then Color3.fromRGB(50, 35, 30) elseif stormId == "Blizzard" then Color3.fromRGB(200, 240, 255) else color,
		Material = if stormId == "Eruption" then Enum.Material.CrackedLava elseif stormId == "Blizzard" then Enum.Material.Ice else Enum.Material.Neon,
		Parent = parent,
	})
	local trail = Instance.new("ParticleEmitter")
	trail.Texture = if stormId == "Eruption" then "rbxasset://textures/particles/fire_main.dds" else "rbxasset://textures/particles/sparkles_main.dds"
	trail.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	trail.LightEmission = 1
	trail.LightInfluence = 0
	trail.Size = NumberSequence.new(if stormId == "Blizzard" then 1.2 else 2.6, 0)
	trail.Lifetime = NumberRange.new(0.4, 0.8)
	trail.Rate = 60
	trail.Speed = NumberRange.new(1, 3)
	trail.SpreadAngle = Vector2.new(25, 25)
	trail.Parent = bomb
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 18
	light.Brightness = 2
	light.Shadows = false
	light.Parent = bomb
	return bomb
end

local function impact(storm, stormId: string, ground: Vector3, color: Color3, parent: Instance)
	local blast = Instance.new("Explosion")
	blast.Position = ground + Vector3.new(0, 1, 0)
	blast.BlastRadius = storm.BlastRadius
	blast.BlastPressure = 0
	blast.DestroyJointRadiusPercent = 0
	blast.ExplosionType = Enum.ExplosionType.NoCraters
	blast.Visible = true
	blast.Parent = parent
	for _, player in Players:GetPlayers() do
		local root = Combat.RootOf(player)
		if root and not Zones.InSafeZone(root.Position) then
			local offset = root.Position - ground
			local flat = Vector3.new(offset.X, 0, offset.Z)
			if flat.Magnitude <= storm.BlastRadius and math.abs(offset.Y) < 12 then
				local away = if flat.Magnitude > 0.1 then flat.Unit else Vector3.new(0, 0, 1)
				local carried = TreasureService.GetCarrying(player)
				TreasureService.Drop(player, "Storm")
				Net.Fire("Feedback", player, { Type = "Knockback", Direction = away, Power = storm.Knockback })
				Net.Fire("Feedback", player, { Type = "Hazard", Kind = if stormId == "Eruption" then "Lava" else "Storm" })
				Net.Fire("Notify", player, {
					Kind = "Toast",
					Text = ("%s DIRECT HIT!%s"):format(storm.Icon, if carried then " You dropped your treasure" else ""),
					Tone = "Danger",
				})
			end
		end
	end
	if rng:NextNumber() < storm.LootChance then
		local def = rollLoot(storm)
		if def then
			TreasureService.SpawnFalling(def, ground, 6, 0.35, LOOT_LIFETIME, storm.Area)
			if Rarities.AtLeast(def.Rarity, "Legendary") then
				Net.FireAll("Notify", {
					Kind = "Social",
					Text = ("%s %s CRASHED DOWN IN %s"):format(Rarities.Info[def.Rarity].Glyph, def.Name:upper(), storm.Site),
					Rarity = def.Rarity,
				})
			end
		end
	end
	-- A scorch / frost / stardust mark that fades.
	local mark = newPart({
		Name = "StormMark",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.2, storm.BlastRadius * 1.4, storm.BlastRadius * 1.4),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color:Lerp(Color3.new(0, 0, 0), if stormId == "Eruption" then 0.6 else 0.1),
		Material = if stormId == "Blizzard" then Enum.Material.Ice else Enum.Material.Slate,
		Transparency = 0.2,
		Parent = parent,
	})
	TweenService:Create(mark, TweenInfo.new(8), { Transparency = 1 }):Play()
	task.delay(8.5, function()
		mark:Destroy()
	end)
end

local function strike(storm, stormId: string, ground: Vector3, parent: Instance)
	local color = Color3.fromRGB(storm.Color[1], storm.Color[2], storm.Color[3])
	-- Warning ring, pulsing.
	local ring = newPart({
		Name = "StormWarning",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, storm.BlastRadius * 2, storm.BlastRadius * 2),
		CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.55,
		Parent = parent,
	})
	TweenService:Create(ring, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { Transparency = 0.2 }):Play()
	-- The strike comes in at an angle (from the volcano, or out of the sky).
	local from = if stormId == "Eruption"
		then ground + (Vector3.new(-100, 0, -650) - ground) * Vector3.new(0.35, 0, 0.35) + Vector3.new(0, 110, 0)
		else ground + Vector3.new(rng:NextNumber(-50, 50), 140, rng:NextNumber(-50, 50))
	local bomb = projectile(stormId, color, parent)
	bomb.CFrame = CFrame.new(from)
	TweenService:Create(bomb, TweenInfo.new(storm.Warning, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { CFrame = CFrame.new(ground + Vector3.new(0, 2, 0)) }):Play()
	task.delay(storm.Warning, function()
		ring:Destroy()
		bomb:Destroy()
		impact(storm, stormId, ground, color, parent)
	end)
end

-- Runs a storm to the end. `publish(id, name, site, endsAt)` is EventService's.
function RegionStorms.Run(stormId: string, publish, groundAt: (Vector3) -> Vector3?)
	local storm = GameConfig.Events.Storms[stormId]
	local centre = if stormId == "Eruption"
		then Vector3.new(-100, 100, -650)
		elseif stormId == "Blizzard" then Vector3.new(0, 40, -915)
		else Vector3.new(0, 60, -1150)
	local site = { Area = storm.Area, Name = storm.Site, Position = centre }
	publish(stormId, storm.Name, site, workspace:GetServerTimeNow() + storm.Duration)
	Net.FireAll("Notify", { Kind = "Banner", Title = ("%s %s!"):format(storm.Icon, storm.Name), Text = storm.Text, Tone = "Danger" })
	Net.FireAll("Feedback", { Type = "EventStarted", EventId = stormId })
	local folder = Instance.new("Folder")
	folder.Name = "Storm_" .. stormId
	folder.Parent = workspace
	local interval = storm.Duration / storm.Strikes
	for _ = 1, storm.Strikes do
		local target = pickTarget(storm)
		local ground = target and groundAt(target)
		if ground and Zones.AreaId(ground) == storm.Area then
			strike(storm, stormId, ground, folder)
		end
		task.wait(interval * rng:NextNumber(0.6, 1.4))
	end
	task.wait(storm.Warning + 1)
	folder:Destroy()
end

return RegionStorms
