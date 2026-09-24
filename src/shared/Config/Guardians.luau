-- Guardian (PvE) archetypes. Reliability over complexity:
-- PATROL -> DETECT -> CHASE -> ATTACK -> (KNOCK) -> RETURN
--
-- Size / HipHeight are in "design units": GuardianService multiplies them (and every body
-- part) by Scale, so a guardian can be made bigger or smaller without redesigning it.
-- The collision box is Size x Scale; attack reach adds half its depth.
-- Danger grows with the region: Wilds (wolves) -> Coast (goblins) -> Ruins (goblins + golem)
-- -> Falls (spiders).

return {
	Wolf = {
		Name = "Dire Wolf",
		Scale = 1.7,
		PatrolSpeed = 9,
		ChaseSpeed = 15, -- slower than an unburdened player (18), faster than a heavy carrier
		DetectRange = 45,
		LeashRange = 110,
		AttackRange = 4,
		AttackCooldown = 1.3,
		Damage = 10,
		RetreatAfterKnock = 4,
		BodyColor = { 58, 56, 66 },
		AccentColor = { 190, 186, 176 },
		EyeColor = { 255, 200, 40 },
		Size = { 2.4, 2.4, 4.6 },
		HipHeight = 1.6,
	},
	Goblin = {
		Name = "Goblin Brute",
		Scale = 1.7,
		PatrolSpeed = 8,
		ChaseSpeed = 14,
		DetectRange = 42,
		LeashRange = 90,
		AttackRange = 5,
		AttackCooldown = 1.1,
		Damage = 12,
		RetreatAfterKnock = 4,
		BodyColor = { 86, 128, 52 },
		AccentColor = { 96, 64, 38 },
		EyeColor = { 255, 50, 40 },
		Size = { 2.4, 3, 2 },
		HipHeight = 1.4,
	},
	Golem = {
		Name = "Stone Golem",
		Scale = 2.1,
		PatrolSpeed = 6,
		ChaseSpeed = 12, -- slow: outrun it, but never let it reach you
		DetectRange = 38,
		LeashRange = 70,
		AttackRange = 5,
		AttackCooldown = 2.2,
		Damage = 25,
		Knockback = 1.8,
		RetreatAfterKnock = 5,
		BodyColor = { 98, 94, 104 },
		AccentColor = { 78, 120, 60 },
		EyeColor = { 255, 120, 30 },
		Size = { 3, 3.4, 2.4 },
		HipHeight = 1.8,
	},
	Spider = {
		Name = "Giant Cave Spider",
		Scale = 1.8,
		PatrolSpeed = 7,
		ChaseSpeed = 14,
		DetectRange = 38,
		LeashRange = 65,
		AttackRange = 4,
		AttackCooldown = 1.6,
		Damage = 16,
		RetreatAfterKnock = 5,
		BodyColor = { 34, 24, 40 },
		AccentColor = { 70, 30, 90 },
		EyeColor = { 120, 255, 110 },
		Size = { 4, 2, 4 },
		HipHeight = 1.4,
	},
}
