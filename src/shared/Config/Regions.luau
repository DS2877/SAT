-- Presentation of the island's regions and secrets: names, colours, moods. Balance (danger,
-- recommended strength, rewards) lives in GameConfig.Regions / GameConfig.Secrets.
--
-- Mood is applied on the client (Controllers/Biomes) while you stand in the region:
-- Tint/Saturation/Contrast tune the colour grading, Density/Haze the atmosphere.

local Regions = {}

-- Order of the journey: the "easy" meadow first, the deadly jungle last.
Regions.Order = { "Wilds", "Coast", "Marsh", "Ruins", "Frost", "Falls" }

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
	Marsh = {
		Title = "GLOWSHROOM MARSH",
		Tagline = "A glowing bog. Something with too many legs lives in the pools.",
		Color = { 200, 130, 255 },
		Mood = { Tint = { 232, 214, 255 }, Saturation = 0.12, Contrast = 0.18, Density = 0.42, Haze = 2.6 },
	},
	Frost = {
		Title = "FROSTPEAK",
		Tagline = "Frozen peaks and a lake of ice. The golems here never thaw.",
		Color = { 190, 235, 255 },
		Mood = { Tint = { 220, 238, 255 }, Saturation = -0.08, Contrast = 0.14, Density = 0.34, Haze = 1.8 },
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
		Id = "frozen_grotto",
		Title = "THE FROZEN GROTTO",
		Text = "An ice tunnel into the mountain. It glows blue inside.",
		Area = "Frost",
		Position = Vector3.new(-215, 13, 330),
		Radius = 12,
	},
	{
		Id = "witch_hut",
		Title = "THE WITCH'S HUT",
		Text = "High above the bog. Ride the geyser - if you dare.",
		Area = "Marsh",
		Position = Vector3.new(330, 39, 150),
		Radius = 12,
	},
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
	{
		Id = "hollow_oak",
		Title = "THE HOLLOW OAK",
		Text = "Something lives in this tree. Something shiny.",
		Area = "Wilds",
		Position = Vector3.new(-60, 35, -88),
		Radius = 12,
	},
	{
		Id = "smugglers_den",
		Title = "THE SMUGGLERS' DEN",
		Text = "Just a net shed. Unless you look under the floor.",
		Area = "Coast",
		Position = Vector3.new(-372, 3, 100),
		Radius = 10,
	},
	{
		Id = "eagles_nest",
		Title = "THE EAGLE'S NEST",
		Text = "The highest point at the Falls. Don't look down.",
		Area = "Falls",
		Position = Vector3.new(110, 63, -270),
		Radius = 14,
	},
}

function Regions.Stars(danger: number): string
	return string.rep("★", danger) .. string.rep("☆", 4 - danger)
end

return Regions
