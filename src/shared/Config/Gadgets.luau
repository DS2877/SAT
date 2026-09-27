-- Gadget definitions. Implemented=false gadgets are designed but not yet sold.
-- CARRIER = RUN / ESCAPE (CanUseWhileCarrying = true)
-- CHASER = STOP / CONTROL (CanUseWhileCarrying = false)
-- AscensionShop = true: sold in the ASCENSION SHOP (not the Gadget Shop), needs
-- RequiredAscension, and is KEPT when you Ascend. Placed gadgets live in workspace.PlacedGadgets.

local Gadgets = {}

Gadgets.List = {
	{
		Id = "speed_soda",
		Name = "Speed Soda",
		Role = "Mobility",
		Icon = "🥤",
		Price = 500, -- deliberately cheap: the first gadget should arrive within the first runs
		Cooldown = 20,
		Duration = 5,
		SpeedMultiplier = 1.45,
		CanUseWhileCarrying = true,
		Implemented = true,
		Description = "Fizzy burst of speed. Great for escapes.",
	},
	{
		Id = "balloon",
		Name = "Balloon",
		Role = "Vertical Mobility",
		Icon = "🎈",
		Price = 25000,
		Cooldown = 25,
		RiseSpeed = 14,
		RiseDuration = 2.2,
		GlideSpeed = -5,
		GlideDuration = 3,
		CanUseWhileCarrying = true,
		Implemented = true,
		Description = "Float up, drift down. Reach cliffs, dodge chasers.",
	},
	{
		Id = "bubble_blaster",
		Name = "Bubble Blaster",
		Role = "Control",
		Icon = "🔵", -- older emoji: renders on every phone
		Price = 60000,
		Cooldown = 15,
		Range = 32,
		ArcDot = 0.6,
		TrapDuration = 2.5,
		TrapImmunity = 4,
		CanUseWhileCarrying = false,
		Implemented = true,
		Description = "Trap a runner in a bubble. Then go get that treasure.",
	},
	{
		Id = "grapple_hook",
		Name = "Grapple Hook",
		Role = "Mobility",
		Icon = "🎣",
		Price = 150000,
		Cooldown = 12,
		Range = 80, -- studs; aim with the camera (centre of screen)
		MinDistance = 8,
		PullSpeed = 75,
		CarriedSpeedFloor = 0.55, -- heavy treasure slows the pull, but never below this fraction
		MaxDuration = 1.8,
		ArriveDistance = 5,
		CanUseWhileCarrying = true,
		NeedsAim = true,
		Implemented = true,
		Description = "Aim at a cliff, tree or roof and zip there. Great escape tool.",
	},
	{
		Id = "disguise",
		Name = "Disguise",
		Role = "Misdirection",
		Icon = "🌿",
		Price = 1500000,
		Cooldown = 45,
		Duration = 10,
		GuardianDetectMultiplier = 0.3, -- guardians barely notice a bush
		CanUseWhileCarrying = true,
		Implemented = true,
		Description = "Become a bush. Your treasure and name vanish until you get hit.",
	},
	{
		Id = "bee_box",
		Name = "Bee Box",
		Role = "Area Disruption",
		Icon = "🐝",
		Price = 3000000,
		Cooldown = 30,
		Duration = 6,
		ThrowDistance = 18,
		Radius = 12,
		SlowMultiplier = 0.55,
		DamagePerTick = 2,
		TickRate = 0.5,
		CanUseWhileCarrying = false,
		Implemented = true,
		Description = "Throw a hive. Anyone in the swarm is slowed and stung. Block a path!",
	},
	{
		Id = "boomerang",
		Name = "Boomerang",
		Role = "Utility",
		Icon = "💫",
		Price = 750000,
		Cooldown = 10,
		Range = 45,
		AimDot = 0.93, -- how precisely it must be aimed (camera centre)
		Damage = 5,
		CanUseWhileCarrying = false,
		NeedsAim = true,
		Implemented = true,
		Description = "A ranged SLAP. Counts as a hit — slow a runner from afar.",
	},
	{
		Id = "decoy_duck",
		Name = "Decoy Duck",
		Role = "Misdirection",
		Icon = "🦆",
		Price = 400000,
		Cooldown = 30,
		Duration = 7,
		Speed = 17,
		GuardianLureRange = 70, -- guardians chase the duck instead of players
		CanUseWhileCarrying = true,
		Implemented = true,
		Description = "A duck carrying a FAKE treasure waddles off. Guardians and players chase it.",
	},
	{
		Id = "bear_trap",
		Name = "Bear Trap",
		Role = "Trap",
		Icon = "🪤",
		Price = 12000,
		Cooldown = 12,
		Lifetime = 60, -- seconds it waits on the ground
		MaxActive = 2, -- a third one replaces your oldest
		TriggerRadius = 3.2,
		HoldDuration = 2.5, -- snapped: stuck in place this long
		Power = 25, -- a small jolt (a carrier is knocked and DROPS the treasure)
		CanUseWhileCarrying = true,
		Implemented = true,
		Description = "Drop it on a path. Whoever steps in is stuck - and drops their treasure.",
	},
	-- ASCENSION SHOP ------------------------------------------------------------------
	{
		Id = "auto_cannon",
		Name = "Auto-Cannon",
		Role = "Turret",
		Icon = "💣",
		Price = 8000000,
		RequiredAscension = 1,
		AscensionShop = true,
		Cooldown = 75,
		Duration = 45, -- it guards the spot this long
		Range = 42,
		FireInterval = 1.3,
		Power = 80,
		Health = 3, -- slaps to break it
		CanUseWhileCarrying = false,
		Implemented = true,
		Description = "Place a cannon that blasts anyone who comes close for 45 s. Guard your route!",
	},
	{
		Id = "freeze_ray",
		Name = "Freeze Ray",
		Role = "Control",
		Icon = "❄",
		Price = 60000000,
		RequiredAscension = 2,
		AscensionShop = true,
		Cooldown = 20,
		Range = 70,
		AimDot = 0.94,
		FreezeDuration = 3,
		Immunity = 5,
		CanUseWhileCarrying = false,
		NeedsAim = true,
		Implemented = true,
		Description = "Aim and freeze a player solid for 3 s. Frozen carriers drop their loot.",
	},
	{
		Id = "tornado",
		Name = "Tornado",
		Role = "Area Launch",
		Icon = "🌪",
		Price = 500000000,
		RequiredAscension = 3,
		AscensionShop = true,
		Cooldown = 40,
		Speed = 24,
		Duration = 3.2, -- travels about 75 studs
		Radius = 7,
		Power = 130,
		Lift = 60,
		CanUseWhileCarrying = false,
		Implemented = true,
		Description = "Unleash a twister that tears ahead and flings everyone in its way.",
	},
	{
		Id = "thunder_totem",
		Name = "Thunder Totem",
		Role = "Area Strike",
		Icon = "⚡",
		Price = 2500000000,
		RequiredAscension = 4,
		AscensionShop = true,
		Cooldown = 60,
		Radius = 30,
		Strikes = 3,
		StrikeInterval = 1.6,
		Warmup = 1,
		Power = 95,
		CanUseWhileCarrying = false,
		Implemented = true,
		Description = "Plant a totem: lightning hits EVERY rival around you, three times.",
	},
}

Gadgets.ById = {}
for _, def in Gadgets.List do
	Gadgets.ById[def.Id] = def
end

function Gadgets.Get(id: string)
	return Gadgets.ById[id]
end

return Gadgets
