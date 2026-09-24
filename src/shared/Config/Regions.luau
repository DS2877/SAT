-- Presentation of the island's regions and secrets: names, colours, moods. Balance (danger,
-- recommended strength, rewards) lives in GameConfig.Regions / GameConfig.Secrets.
--
-- Mood is applied on the client (Controllers/Biomes) while you stand in the region:
-- Tint/Saturation/Contrast tune the colour grading, Density/Haze the atmosphere.

local Regions = {}

-- Order of the journey: the "easy" meadow first, the deadly jungle last.
Regions.Order = { "Wilds", "Coast", "Ruins", "Falls" }

Regions.Info = {
	District = {
		Title = "TREASURE DISTRICT",
		Tagline = "Safe zone. Train, collect, upgrade.",
		Color = { 120, 220, 255 },
		Mood = { Tint = { 255, 252, 245 }, Saturation = 0.18, Contrast = 0.1, Density = 0.22, Haze = 0.6 },
	},
	Wilds = {
		Title = "THE WILDS",
		Tagline = "Sunny meadows. Dire wolves hunt the treeline.",
		Color = { 140, 230, 90 },
		Mood = { Tint = { 255, 250, 232 }, Saturation = 0.24, Contrast = 0.1, Density = 0.22, Haze = 0.5 },
	},
	Coast = {
		Title = "SHIPWRECK COAST",
		Tagline = "Storm-grey shores. Goblin brutes loot the wreck.",
		Color = { 90, 190, 255 },
		Mood = { Tint = { 222, 234, 255 }, Saturation = -0.02, Contrast = 0.16, Density = 0.34, Haze = 1.6 },
	},
	Ruins = {
		Title = "ANCIENT RUINS",
		Tagline = "Scorching desert. The Stone Golem never sleeps.",
		Color = { 255, 176, 70 },
		Mood = { Tint = { 255, 228, 188 }, Saturation = 0.2, Contrast = 0.14, Density = 0.3, Haze = 2 },
	},
	Falls = {
		Title = "THE FALLS",
		Tagline = "Dark jungle. Giant spiders nest by the water.",
		Color = { 110, 255, 150 },
		Mood = { Tint = { 208, 250, 218 }, Saturation = 0.06, Contrast = 0.2, Density = 0.4, Haze = 2.4 },
	},
}

-- Secret places. Position = trigger centre (found when you get within Radius, incl. height).
Regions.Secrets = {
	{
		Id = "old_mine",
		Title = "THE OLD MINE",
		Text = "A forgotten tunnel through the hill - and a crystal cave inside.",
		Area = "Wilds",
		Position = Vector3.new(-205, 13, -125),
		Radius = 14,
	},
	{
		Id = "sky_ruins",
		Title = "THE SKY RUINS",
		Text = "Only the brave climb this high.",
		Area = "Ruins",
		Position = Vector3.new(330, 67, -165),
		Radius = 16,
	},
	{
		Id = "catacombs",
		Title = "THE CATACOMBS",
		Text = "The Golem guards the stairs for a reason.",
		Area = "Ruins",
		Position = Vector3.new(190, -11, -254),
		Radius = 16,
	},
}

function Regions.Stars(danger: number): string
	return string.rep("★", danger) .. string.rep("☆", 4 - danger)
end

return Regions
