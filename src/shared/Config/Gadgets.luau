-- Gadget definitions. Implemented=false gadgets are designed but not yet sold.
-- CARRIER = RUN / ESCAPE (CanUseWhileCarrying = true)
-- CHASER = STOP / CONTROL (CanUseWhileCarrying = false)

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
		Price = 20000,
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
		Icon = "🫧",
		Price = 40000,
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
		Icon = "🪝",
		Price = 80000,
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
		Icon = "🥸",
		Price = 400000,
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
		Price = 600000,
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
		Icon = "🪃",
		Price = 250000,
		Cooldown = 10,
		Range = 45,
		AimDot = 0.93, -- how precisely it must be aimed (camera centre)
		Damage = 5,
		CanUseWhileCarrying = false,
		NeedsAim = true,
		Implemented = true,
		Description = "A ranged BONK. Counts as a hit — shake a runner from afar.",
	},
	{
		Id = "decoy_duck",
		Name = "Decoy Duck",
		Role = "Misdirection",
		Icon = "🦆",
		Price = 150000,
		Cooldown = 30,
		Duration = 7,
		Speed = 17,
		GuardianLureRange = 70, -- guardians chase the duck instead of players
		CanUseWhileCarrying = true,
		Implemented = true,
		Description = "A duck carrying a FAKE treasure waddles off. Guardians and players chase it.",
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
