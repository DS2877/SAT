-- All treasure definitions. Data only. Visual fields (Shape/Color/Material/DisplaySize)
-- drive the procedural TreasureVisual builder until real models exist.
--
-- SpawnArea must match an area used by spawn points in WorldLayout:
--   Wilds, Ruins, Coast, Falls, Frost, Marsh
-- SpecialEffect (optional): RevealsCarrier, RevealsTreasures, AttractsGuardians, Radiant,
--   Swift (carrier +speed), Nocturnal (earns x2 at night in the Vault). Every special treasure
--   has a gameplay/economic purpose; EffectLabels explains it on the name tag.

local Treasures = {}

Treasures.List = {
	-- COMMON ($100–500, weight 1–5)
	{ Id = "coin_pouch", Name = "Coin Pouch", Rarity = "Common", Value = 150, Weight = 200, SpawnArea = "Wilds", Shape = "Pouch", Color = { 150, 104, 60 }, Material = "Fabric", DisplaySize = "Small", Lore = "Somebody dropped this in a hurry." },
	{ Id = "rusty_compass", Name = "Rusty Compass", Rarity = "Common", Value = 120, Weight = 100, SpawnArea = "Coast", Shape = "Disc", Color = { 168, 110, 70 }, Material = "Metal", DisplaySize = "Small", Lore = "Still points somewhere. Just not north." },
	{ Id = "clay_pot", Name = "Painted Clay Pot", Rarity = "Common", Value = 260, Weight = 500, SpawnArea = "Ruins", Shape = "Pot", Color = { 190, 110, 70 }, Material = "Slate", DisplaySize = "Medium", Lore = "Painted with tiny dancing monkeys." },
	{ Id = "bronze_bell", Name = "Bronze Bell", Rarity = "Common", Value = 340, Weight = 400, SpawnArea = "Coast", Shape = "Goblet", Color = { 205, 140, 70 }, Material = "Metal", DisplaySize = "Small", Lore = "Rang on a ship that never came home." },
	{ Id = "message_bottle", Name = "Message in a Bottle", Rarity = "Common", Value = 400, Weight = 100, SpawnArea = "Coast", Shape = "Lantern", Color = { 120, 200, 170 }, Material = "Glass", DisplaySize = "Small", Lore = "The message says: 'DIG NEAR THE WATERFALL'." },
	{ Id = "jade_frog", Name = "Jade Frog", Rarity = "Common", Value = 480, Weight = 300, SpawnArea = "Wilds", Shape = "Idol", Color = { 80, 170, 110 }, Material = "Glass", DisplaySize = "Small", Lore = "Carved for luck. Mostly unlucky." },

	-- UNCOMMON ($500–2,000, weight 3–10)
	{ Id = "silver_goblet", Name = "Silver Goblet", Rarity = "Uncommon", Value = 650, Weight = 400, SpawnArea = "Wilds", Shape = "Goblet", Color = { 210, 215, 225 }, Material = "Metal", DisplaySize = "Small", Lore = "Fancy enough for a pirate king's juice." },
	{ Id = "captains_spyglass", Name = "Captain's Spyglass", Rarity = "Uncommon", Value = 900, Weight = 300, SpawnArea = "Coast", Shape = "Horn", Color = { 190, 150, 80 }, Material = "Metal", DisplaySize = "Small", Lore = "Spotted the island first." },
	{ Id = "stone_tablet", Name = "Stone Tablet", Rarity = "Uncommon", Value = 1100, Weight = 1000, SpawnArea = "Ruins", Shape = "Tablet", Color = { 140, 140, 130 }, Material = "Slate", DisplaySize = "Medium", Lore = "Heavy homework from an ancient school." },
	{ Id = "carved_mask", Name = "Carved Mask", Rarity = "Uncommon", Value = 1250, Weight = 700, SpawnArea = "Ruins", Shape = "Tablet", Color = { 170, 90, 50 }, Material = "Wood", DisplaySize = "Medium", Lore = "It smiles. You wish it didn't." },
	{ Id = "amber_beetle", Name = "Amber Beetle", Rarity = "Uncommon", Value = 1500, Weight = 300, SpawnArea = "Wilds", Shape = "Gem", Color = { 240, 160, 40 }, Material = "Glass", DisplaySize = "Small", Lore = "A beetle frozen mid-sneeze." },
	{ Id = "ruby_ring", Name = "Ruby Ring", Rarity = "Uncommon", Value = 1900, Weight = 300, SpawnArea = "Coast", Shape = "Ring", Color = { 220, 40, 60 }, Material = "Glass", DisplaySize = "Small", Lore = "Way too big for any finger." },
	{ Id = "wind_chime", Name = "Wind Chime", Rarity = "Uncommon", Value = 1300, Weight = 300, SpawnArea = "Wilds", Shape = "Lantern", Color = { 170, 230, 255 }, Material = "Glass", DisplaySize = "Small", SpecialEffect = "Swift", Lore = "Rings when the wind is on your side. Carriers run faster." },

	-- RARE ($2,000–10,000, weight 6–20)
	{ Id = "ivory_horn", Name = "Ivory Horn", Rarity = "Rare", Value = 3000, Weight = 1400, SpawnArea = "Wilds", Shape = "Horn", Color = { 240, 230, 210 }, Material = "Marble", DisplaySize = "Medium", Lore = "One blow calls every wolf on the island." },
	{ Id = "golden_chalice", Name = "Golden Chalice", Rarity = "Rare", Value = 4500, Weight = 800, SpawnArea = "Ruins", Shape = "Goblet", Color = { 255, 200, 60 }, Material = "Metal", DisplaySize = "Medium", Lore = "Temple priests drank sunlight from it." },
	{ Id = "pearl_necklace", Name = "Pearl Necklace", Rarity = "Rare", Value = 6500, Weight = 600, SpawnArea = "Coast", Shape = "Ring", Color = { 245, 240, 235 }, Material = "Marble", DisplaySize = "Small", Lore = "Each pearl from a different ocean." },
	{ Id = "pirate_chest", Name = "Pirate Chest", Rarity = "Rare", Value = 7500, Weight = 2000, SpawnArea = "Coast", Shape = "Chest", Color = { 120, 76, 40 }, Material = "Wood", DisplaySize = "Large", Lore = "Classic. Heavy. Worth it." },
	{ Id = "sunstone_idol", Name = "Sunstone Idol", Rarity = "Rare", Value = 8000, Weight = 1800, SpawnArea = "Ruins", Shape = "Idol", Color = { 255, 150, 50 }, Material = "Slate", DisplaySize = "Medium", Lore = "Warm to the touch. Always." },
	{ Id = "emerald_scarab", Name = "Emerald Scarab", Rarity = "Rare", Value = 9500, Weight = 700, SpawnArea = "Wilds", Shape = "Gem", Color = { 40, 200, 110 }, Material = "Glass", DisplaySize = "Small", Lore = "Light, tiny, and absurdly valuable." },
	{ Id = "explorers_compass", Name = "Explorer's Compass", Rarity = "Rare", Value = 5200, Weight = 600, SpawnArea = "Wilds", Shape = "Disc", Color = { 230, 190, 90 }, Material = "Metal", DisplaySize = "Medium", SpecialEffect = "RevealsTreasures", Lore = "The needle swings toward anything that glitters." },
	{ Id = "storm_anchor", Name = "Storm Anchor", Rarity = "Rare", Value = 9800, Weight = 2000, SpawnArea = "Coast", Shape = "Trident", Color = { 70, 80, 95 }, Material = "Metal", DisplaySize = "Large", Lore = "The heaviest haul on the coast. Train before you try." },

	-- EPIC ($10,000–50,000, weight 10–30)
	{ Id = "ancient_map", Name = "Ancient Map", Rarity = "Epic", Value = 12000, Weight = 1000, SpawnArea = "Ruins", Shape = "Tablet", Color = { 225, 200, 150 }, Material = "Fabric", DisplaySize = "Medium", Lore = "Marks a vault nobody has opened... yet." },
	{ Id = "ghost_lantern", Name = "Ghost Lantern", Rarity = "Epic", Value = 18000, Weight = 1000, SpawnArea = "Falls", Shape = "Lantern", Color = { 120, 255, 220 }, Material = "Neon", DisplaySize = "Medium", SpecialEffect = "RevealsTreasures", Lore = "Its flame leans toward nearby treasure." },
	{ Id = "golden_monkey", Name = "Golden Monkey", Rarity = "Epic", Value = 25000, Weight = 1600, SpawnArea = "Ruins", Shape = "Idol", Color = { 255, 205, 70 }, Material = "Metal", DisplaySize = "Medium", Lore = "The temple's mischievous mascot." },
	{ Id = "crystal_heart", Name = "Crystal Heart", Rarity = "Epic", Value = 32000, Weight = 2200, SpawnArea = "Falls", Shape = "Gem", Color = { 150, 220, 255 }, Material = "Glass", DisplaySize = "Large", Lore = "Beats once a minute. Nobody knows why." },
	{ Id = "sapphire_trident", Name = "Sapphire Trident", Rarity = "Epic", Value = 42000, Weight = 2800, SpawnArea = "Coast", Shape = "Trident", Color = { 40, 90, 230 }, Material = "Metal", DisplaySize = "Large", Lore = "Pulled from the wreck by very brave hands." },
	{ Id = "moon_pearl", Name = "Moon Pearl", Rarity = "Epic", Value = 28000, Weight = 1000, SpawnArea = "Coast", Shape = "Orb", Color = { 190, 200, 255 }, Material = "Glass", DisplaySize = "Medium", SpecialEffect = "Nocturnal", Lore = "Glows brighter when the moon is up - and so does its value." },

	-- LEGENDARY ($50,000–250,000, weight 20–50)
	{ Id = "phoenix_feather", Name = "Phoenix Feather", Rarity = "Legendary", Value = 65000, Weight = 2000, SpawnArea = "Falls", Shape = "Feather", Color = { 255, 110, 40 }, Material = "Neon", DisplaySize = "Medium", Lore = "Light as air. Carries like a furnace." },
	{ Id = "kraken_pearl", Name = "Kraken Pearl", Rarity = "Legendary", Value = 90000, Weight = 2400, SpawnArea = "Coast", Shape = "Orb", Color = { 200, 120, 255 }, Material = "Glass", DisplaySize = "Large", Lore = "Something in the deep wants it back." },
	{ Id = "golden_crown", Name = "Golden Crown", Rarity = "Legendary", Value = 150000, Weight = 3000, SpawnArea = "Ruins", Shape = "Crown", Color = { 255, 200, 40 }, Material = "Metal", DisplaySize = "Large", SpecialEffect = "RevealsCarrier", Lore = "Shines so bright everyone knows who has it." },
	{ Id = "sun_disc", Name = "Sun Disc", Rarity = "Legendary", Value = 210000, Weight = 4800, SpawnArea = "Ruins", Shape = "Disc", Color = { 255, 180, 30 }, Material = "Metal", DisplaySize = "Huge", Lore = "The temple's heart. Enormous. Heavy. Glorious." },

	-- MYTHIC ($250,000–1,000,000, weight 35–80)
	{ Id = "cursed_skull", Name = "Cursed Skull", Rarity = "Mythic", Value = 400000, Weight = 6000, SpawnArea = "Ruins", Shape = "Skull", Color = { 90, 255, 120 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "AttractsGuardians", Lore = "Every Guardian on the island can hear it whisper." },
	{ Id = "dragon_egg", Name = "Dragon Egg", Rarity = "Mythic", Value = 600000, Weight = 7000, SpawnArea = "Falls", Shape = "Egg", Color = { 200, 40, 40 }, Material = "Slate", DisplaySize = "Huge", Lore = "It's warm. It's moving. It's worth a fortune." },

	-- FROSTPEAK (new region)
	{ Id = "frosted_mug", Name = "Frosted Mug", Rarity = "Common", Value = 300, Weight = 300, SpawnArea = "Frost", Shape = "Goblet", Color = { 200, 230, 255 }, Material = "Glass", DisplaySize = "Small", Lore = "Still full of hot cocoa. Frozen solid." },
	{ Id = "snowflake_brooch", Name = "Snowflake Brooch", Rarity = "Uncommon", Value = 1400, Weight = 300, SpawnArea = "Frost", Shape = "Ring", Color = { 230, 245, 255 }, Material = "Glass", DisplaySize = "Small", Lore = "No two are alike. This one is priceless." },
	{ Id = "mammoth_tusk", Name = "Mammoth Tusk", Rarity = "Rare", Value = 8800, Weight = 2000, SpawnArea = "Frost", Shape = "Horn", Color = { 245, 235, 215 }, Material = "Marble", DisplaySize = "Large", Lore = "Ancient, enormous and very, very heavy." },
	{ Id = "frozen_heart", Name = "Frozen Heart", Rarity = "Epic", Value = 30000, Weight = 1800, SpawnArea = "Frost", Shape = "Gem", Color = { 120, 210, 255 }, Material = "Glass", DisplaySize = "Medium", Lore = "It beats once a winter." },
	{ Id = "yeti_crown", Name = "Yeti King's Crown", Rarity = "Legendary", Value = 120000, Weight = 3200, SpawnArea = "Frost", Shape = "Crown", Color = { 170, 225, 255 }, Material = "Glass", DisplaySize = "Large", Lore = "Carved from glacier ice for a king nobody saw twice." },

	-- GLOWSHROOM MARSH (new region)
	{ Id = "toad_totem", Name = "Toad Totem", Rarity = "Common", Value = 220, Weight = 300, SpawnArea = "Marsh", Shape = "Idol", Color = { 110, 170, 90 }, Material = "Wood", DisplaySize = "Small", Lore = "Croaks when nobody is looking." },
	{ Id = "glow_jar", Name = "Glow Jar", Rarity = "Uncommon", Value = 1000, Weight = 300, SpawnArea = "Marsh", Shape = "Lantern", Color = { 200, 120, 255 }, Material = "Neon", DisplaySize = "Small", Lore = "Fireflies that never sleep." },
	{ Id = "witch_cauldron", Name = "Witch's Cauldron", Rarity = "Rare", Value = 7000, Weight = 2000, SpawnArea = "Marsh", Shape = "Pot", Color = { 60, 55, 70 }, Material = "Metal", DisplaySize = "Large", Lore = "Still bubbling. Don't sniff it." },
	{ Id = "spore_scepter", Name = "Spore Queen's Scepter", Rarity = "Epic", Value = 22000, Weight = 1400, SpawnArea = "Marsh", Shape = "Trident", Color = { 190, 90, 255 }, Material = "Neon", DisplaySize = "Medium", Lore = "One wave and the whole bog glows." },
	{ Id = "moonshroom", Name = "Moonshroom", Rarity = "Legendary", Value = 80000, Weight = 2200, SpawnArea = "Marsh", Shape = "Egg", Color = { 150, 190, 255 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "Nocturnal", Lore = "Only blooms under the moon - and so does its price." },

	-- SECRET ($1,000,000+)
	{ Id = "heart_of_the_island", Name = "Heart of the Island", Rarity = "Secret", Value = 2500000, Weight = 4000, SpawnArea = "Falls", Shape = "Orb", Color = { 255, 255, 255 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "Radiant", Lore = "They said it was a myth." },
}

Treasures.ById = {}
for _, def in Treasures.List do
	Treasures.ById[def.Id] = def
end

-- World size of treasure models. Big on purpose: treasure must read clearly through grass.
Treasures.DisplayScale = {
	Small = 3.2,
	Medium = 4.2,
	Large = 5.2,
	Huge = 6.6,
}

-- Short line shown on the name tag so a special treasure's purpose is obvious.
Treasures.EffectLabels = {
	Swift = "💨 +15% SPEED WHILE CARRIED",
	RevealsTreasures = "🧭 REVEALS NEARBY TREASURE",
	Nocturnal = "🌙 EARNS x2 AT NIGHT",
	RevealsCarrier = "👁 EVERYONE SEES THE CARRIER",
	AttractsGuardians = "☠ GUARDIANS HUNT THE CARRIER",
	Radiant = "✨ RADIANT",
}

function Treasures.Get(id: string)
	return Treasures.ById[id]
end

return Treasures
