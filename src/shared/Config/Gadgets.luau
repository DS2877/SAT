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
		Price = 400,
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
		Price = 2500,
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
		Price = 6000,
		Cooldown = 15,
		Range = 32,
		ArcDot = 0.6,
		TrapDuration = 2.5,
		TrapImmunity = 4,
		CanUseWhileCarrying = false,
		Implemented = true,
		Description = "Trap a runner in a bubble. Then go get that treasure.",
	},
	{ Id = "grapple_hook", Name = "Grapple Hook", Role = "Mobility", Icon = "🪝", Price = 8000, Cooldown = 12, CanUseWhileCarrying = true, Implemented = false, Description = "Zip to ledges." },
	{ Id = "disguise", Name = "Disguise", Role = "Misdirection", Icon = "🥸", Price = 12000, Cooldown = 45, Duration = 10, CanUseWhileCarrying = true, Implemented = false, Description = "Hide what you carry." },
	{ Id = "bee_box", Name = "Bee Box", Role = "Area Disruption", Icon = "🐝", Price = 15000, Cooldown = 30, CanUseWhileCarrying = false, Implemented = false, Description = "Bees. Everywhere." },
	{ Id = "boomerang", Name = "Boomerang", Role = "Utility", Icon = "🪃", Price = 10000, Cooldown = 10, CanUseWhileCarrying = false, Implemented = false, Description = "Bonk from range." },
	{ Id = "decoy_duck", Name = "Decoy Duck", Role = "Misdirection", Icon = "🦆", Price = 9000, Cooldown = 30, CanUseWhileCarrying = true, Implemented = false, Description = "Quack. Look over there." },
}

Gadgets.ById = {}
for _, def in Gadgets.List do
	Gadgets.ById[def.Id] = def
end

function Gadgets.Get(id: string)
	return Gadgets.ById[id]
end

return Gadgets
