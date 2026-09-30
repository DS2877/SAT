-- All treasure definitions. Data only. Visual fields (Shape/Color/Material/DisplaySize)
-- drive the procedural TreasureVisual builder until real models exist.
--
-- SpawnArea must match an area used by spawn points in WorldLayout:
--   Wilds, Ruins, Coast, Falls, Frost, Marsh, Ember, Rime, Star ("Event" = admin drops only,
--   AdminOnly = true: never rolled by the spawner)
-- Fx: the treasure's signature particles (TreasureVisual.SIGNATURES): Sparkle, Coins, Leaves,
--   Notes, Fireflies, Bubbles, Spores, Sand, Souls, Snow, Frost, Flames, Embers, Water,
--   Lightning, Stars, Void, Rainbow, Magic, Feathers, Aurora.
-- SpecialEffect (optional): RevealsCarrier, RevealsTreasures, AttractsGuardians, Radiant,
--   Swift (carrier +speed), Nocturnal (earns x2 at night in the Vault). Every special treasure
--   has a gameplay/economic purpose; EffectLabels explains it on the name tag.

local Treasures = {}

Treasures.List = {
	-- COMMON ($100–500, weight 1–5)
	{ Id = "coin_pouch", Name = "Coin Pouch", Rarity = "Common", Value = 150, Weight = 200, SpawnArea = "Wilds", Shape = "Pouch", Color = { 150, 104, 60 }, Material = "Fabric", DisplaySize = "Small", Fx = "Coins", Lore = "Somebody dropped this in a hurry." },
	{ Id = "rusty_compass", Name = "Rusty Compass", Rarity = "Common", Value = 120, Weight = 100, SpawnArea = "Coast", Shape = "Disc", Color = { 168, 110, 70 }, Material = "Metal", DisplaySize = "Small", Fx = "Sparkle", Lore = "Still points somewhere. Just not north." },
	{ Id = "clay_pot", Name = "Painted Clay Pot", Rarity = "Common", Value = 260, Weight = 500, SpawnArea = "Ruins", Shape = "Pot", Color = { 190, 110, 70 }, Material = "Slate", DisplaySize = "Medium", Fx = "Sand", Lore = "Painted with tiny dancing monkeys." },
	{ Id = "bronze_bell", Name = "Bronze Bell", Rarity = "Common", Value = 340, Weight = 400, SpawnArea = "Coast", Shape = "Goblet", Color = { 205, 140, 70 }, Material = "Metal", DisplaySize = "Small", Fx = "Notes", Lore = "Rang on a ship that never came home." },
	{ Id = "message_bottle", Name = "Message in a Bottle", Rarity = "Common", Value = 400, Weight = 100, SpawnArea = "Coast", Shape = "Lantern", Color = { 120, 200, 170 }, Material = "Glass", DisplaySize = "Small", Fx = "Bubbles", Lore = "The message says: 'DIG NEAR THE WATERFALL'." },
	{ Id = "jade_frog", Name = "Jade Frog", Rarity = "Common", Value = 480, Weight = 300, SpawnArea = "Wilds", Shape = "Idol", Color = { 80, 170, 110 }, Material = "Glass", DisplaySize = "Small", Fx = "Leaves", Lore = "Carved for luck. Mostly unlucky." },

	-- UNCOMMON ($500–2,000, weight 3–10)
	{ Id = "silver_goblet", Name = "Silver Goblet", Rarity = "Uncommon", Value = 650, Weight = 400, SpawnArea = "Wilds", Shape = "Goblet", Color = { 210, 215, 225 }, Material = "Metal", DisplaySize = "Small", Fx = "Sparkle", Lore = "Fancy enough for a pirate king's juice." },
	{ Id = "captains_spyglass", Name = "Captain's Spyglass", Rarity = "Uncommon", Value = 900, Weight = 300, SpawnArea = "Coast", Shape = "Horn", Color = { 190, 150, 80 }, Material = "Metal", DisplaySize = "Small", Fx = "Sparkle", Lore = "Spotted the island first." },
	{ Id = "stone_tablet", Name = "Stone Tablet", Rarity = "Uncommon", Value = 1100, Weight = 1000, SpawnArea = "Ruins", Shape = "Tablet", Color = { 140, 140, 130 }, Material = "Slate", DisplaySize = "Medium", Fx = "Sand", Lore = "Heavy homework from an ancient school." },
	{ Id = "carved_mask", Name = "Carved Mask", Rarity = "Uncommon", Value = 1250, Weight = 700, SpawnArea = "Ruins", Shape = "Tablet", Color = { 170, 90, 50 }, Material = "Wood", DisplaySize = "Medium", Fx = "Souls", Lore = "It smiles. You wish it didn't." },
	{ Id = "amber_beetle", Name = "Amber Beetle", Rarity = "Uncommon", Value = 1500, Weight = 300, SpawnArea = "Wilds", Shape = "Gem", Color = { 240, 160, 40 }, Material = "Glass", DisplaySize = "Small", Fx = "Fireflies", Lore = "A beetle frozen mid-sneeze." },
	{ Id = "ruby_ring", Name = "Ruby Ring", Rarity = "Uncommon", Value = 1900, Weight = 300, SpawnArea = "Coast", Shape = "Ring", Color = { 220, 40, 60 }, Material = "Glass", DisplaySize = "Small", Fx = "Sparkle", Lore = "Way too big for any finger." },
	{ Id = "wind_chime", Name = "Wind Chime", Rarity = "Uncommon", Value = 1300, Weight = 300, SpawnArea = "Wilds", Shape = "Lantern", Color = { 170, 230, 255 }, Material = "Glass", DisplaySize = "Small", SpecialEffect = "Swift", Fx = "Notes", Lore = "Rings when the wind is on your side. Carriers run faster." },

	-- RARE ($2,000–10,000, weight 6–20)
	{ Id = "ivory_horn", Name = "Ivory Horn", Rarity = "Rare", Value = 3000, Weight = 1400, SpawnArea = "Wilds", Shape = "Horn", Color = { 240, 230, 210 }, Material = "Marble", DisplaySize = "Medium", Fx = "Notes", Lore = "One blow calls every wolf on the island." },
	{ Id = "golden_chalice", Name = "Golden Chalice", Rarity = "Rare", Value = 4500, Weight = 800, SpawnArea = "Ruins", Shape = "Goblet", Color = { 255, 200, 60 }, Material = "Metal", DisplaySize = "Medium", Fx = "Coins", Lore = "Temple priests drank sunlight from it." },
	{ Id = "pearl_necklace", Name = "Pearl Necklace", Rarity = "Rare", Value = 6500, Weight = 600, SpawnArea = "Coast", Shape = "Ring", Color = { 245, 240, 235 }, Material = "Marble", DisplaySize = "Small", Fx = "Bubbles", Lore = "Each pearl from a different ocean." },
	{ Id = "pirate_chest", Name = "Pirate Chest", Rarity = "Rare", Value = 7500, Weight = 2000, SpawnArea = "Coast", Shape = "Chest", Color = { 120, 76, 40 }, Material = "Wood", DisplaySize = "Large", Fx = "Coins", Lore = "Classic. Heavy. Worth it." },
	{ Id = "sunstone_idol", Name = "Sunstone Idol", Rarity = "Rare", Value = 8000, Weight = 1800, SpawnArea = "Ruins", Shape = "Idol", Color = { 255, 150, 50 }, Material = "Slate", DisplaySize = "Medium", Fx = "Flames", Lore = "Warm to the touch. Always." },
	{ Id = "emerald_scarab", Name = "Emerald Scarab", Rarity = "Rare", Value = 9500, Weight = 700, SpawnArea = "Wilds", Shape = "Gem", Color = { 40, 200, 110 }, Material = "Glass", DisplaySize = "Small", Fx = "Magic", Lore = "Light, tiny, and absurdly valuable." },
	{ Id = "explorers_compass", Name = "Explorer's Compass", Rarity = "Rare", Value = 5200, Weight = 600, SpawnArea = "Wilds", Shape = "Disc", Color = { 230, 190, 90 }, Material = "Metal", DisplaySize = "Medium", SpecialEffect = "RevealsTreasures", Fx = "Magic", Lore = "The needle swings toward anything that glitters." },
	{ Id = "storm_anchor", Name = "Storm Anchor", Rarity = "Rare", Value = 9800, Weight = 2000, SpawnArea = "Coast", Shape = "Trident", Color = { 70, 80, 95 }, Material = "Metal", DisplaySize = "Large", Fx = "Lightning", Lore = "The heaviest haul on the coast. Train before you try." },

	-- EPIC ($10,000–50,000, weight 10–30)
	{ Id = "ancient_map", Name = "Ancient Map", Rarity = "Epic", Value = 12000, Weight = 1000, SpawnArea = "Ruins", Shape = "Tablet", Color = { 225, 200, 150 }, Material = "Fabric", DisplaySize = "Medium", Fx = "Sand", Lore = "Marks a vault nobody has opened... yet." },
	{ Id = "ghost_lantern", Name = "Ghost Lantern", Rarity = "Epic", Value = 18000, Weight = 1000, SpawnArea = "Falls", Shape = "Lantern", Color = { 120, 255, 220 }, Material = "Neon", DisplaySize = "Medium", SpecialEffect = "RevealsTreasures", Fx = "Souls", Lore = "Its flame leans toward nearby treasure." },
	{ Id = "golden_monkey", Name = "Golden Monkey", Rarity = "Epic", Value = 25000, Weight = 1600, SpawnArea = "Ruins", Shape = "Idol", Color = { 255, 205, 70 }, Material = "Metal", DisplaySize = "Medium", Fx = "Coins", Lore = "The temple's mischievous mascot." },
	{ Id = "crystal_heart", Name = "Crystal Heart", Rarity = "Epic", Value = 32000, Weight = 2200, SpawnArea = "Falls", Shape = "Gem", Color = { 150, 220, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Magic", Lore = "Beats once a minute. Nobody knows why." },
	{ Id = "sapphire_trident", Name = "Sapphire Trident", Rarity = "Epic", Value = 42000, Weight = 2800, SpawnArea = "Coast", Shape = "Trident", Color = { 40, 90, 230 }, Material = "Metal", DisplaySize = "Large", Fx = "Water", Lore = "Pulled from the wreck by very brave hands." },
	{ Id = "moon_pearl", Name = "Moon Pearl", Rarity = "Epic", Value = 28000, Weight = 1000, SpawnArea = "Coast", Shape = "Orb", Color = { 190, 200, 255 }, Material = "Glass", DisplaySize = "Medium", SpecialEffect = "Nocturnal", Fx = "Stars", Lore = "Glows brighter when the moon is up - and so does its value." },

	-- LEGENDARY ($50,000–250,000, weight 20–50)
	{ Id = "phoenix_feather", Name = "Phoenix Feather", Rarity = "Legendary", Value = 65000, Weight = 2000, SpawnArea = "Falls", Shape = "Feather", Color = { 255, 110, 40 }, Material = "Neon", DisplaySize = "Medium", Fx = "Flames", Lore = "Light as air. Carries like a furnace." },
	{ Id = "kraken_pearl", Name = "Kraken Pearl", Rarity = "Legendary", Value = 90000, Weight = 2400, SpawnArea = "Coast", Shape = "Orb", Color = { 200, 120, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Water", Lore = "Something in the deep wants it back." },
	{ Id = "golden_crown", Name = "Golden Crown", Rarity = "Legendary", Value = 150000, Weight = 3000, SpawnArea = "Ruins", Shape = "Crown", Color = { 255, 200, 40 }, Material = "Metal", DisplaySize = "Large", SpecialEffect = "RevealsCarrier", Fx = "Coins", Lore = "Shines so bright everyone knows who has it." },
	{ Id = "sun_disc", Name = "Sun Disc", Rarity = "Legendary", Value = 210000, Weight = 4800, SpawnArea = "Ruins", Shape = "Disc", Color = { 255, 180, 30 }, Material = "Metal", DisplaySize = "Huge", Fx = "Flames", Lore = "The temple's heart. Enormous. Heavy. Glorious." },

	-- MYTHIC ($250,000–1,000,000, weight 35–80)
	{ Id = "cursed_skull", Name = "Cursed Skull", Rarity = "Mythic", Value = 400000, Weight = 6000, SpawnArea = "Ruins", Shape = "Skull", Color = { 90, 255, 120 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "AttractsGuardians", Fx = "Souls", Lore = "Every Guardian on the island can hear it whisper." },
	{ Id = "dragon_egg", Name = "Dragon Egg", Rarity = "Mythic", Value = 600000, Weight = 7000, SpawnArea = "Falls", Shape = "Egg", Color = { 200, 40, 40 }, Material = "Slate", DisplaySize = "Huge", Fx = "Embers", Lore = "It's warm. It's moving. It's worth a fortune." },

	-- FROSTPEAK (new region)
	{ Id = "frosted_mug", Name = "Frosted Mug", Rarity = "Common", Value = 300, Weight = 300, SpawnArea = "Frost", Shape = "Goblet", Color = { 200, 230, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Snow", Lore = "Still full of hot cocoa. Frozen solid." },
	{ Id = "snowflake_brooch", Name = "Snowflake Brooch", Rarity = "Uncommon", Value = 1400, Weight = 300, SpawnArea = "Frost", Shape = "Ring", Color = { 230, 245, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Snow", Lore = "No two are alike. This one is priceless." },
	{ Id = "mammoth_tusk", Name = "Mammoth Tusk", Rarity = "Rare", Value = 8800, Weight = 2000, SpawnArea = "Frost", Shape = "Horn", Color = { 245, 235, 215 }, Material = "Marble", DisplaySize = "Large", Fx = "Frost", Lore = "Ancient, enormous and very, very heavy." },
	{ Id = "frozen_heart", Name = "Frozen Heart", Rarity = "Epic", Value = 30000, Weight = 1800, SpawnArea = "Frost", Shape = "Gem", Color = { 120, 210, 255 }, Material = "Glass", DisplaySize = "Medium", Fx = "Frost", Lore = "It beats once a winter." },
	{ Id = "yeti_crown", Name = "Yeti King's Crown", Rarity = "Legendary", Value = 120000, Weight = 3200, SpawnArea = "Frost", Shape = "Crown", Color = { 170, 225, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Snow", Lore = "Carved from glacier ice for a king nobody saw twice." },

	-- GLOWSHROOM MARSH (new region)
	{ Id = "toad_totem", Name = "Toad Totem", Rarity = "Common", Value = 220, Weight = 300, SpawnArea = "Marsh", Shape = "Idol", Color = { 110, 170, 90 }, Material = "Wood", DisplaySize = "Small", Fx = "Bubbles", Lore = "Croaks when nobody is looking." },
	{ Id = "glow_jar", Name = "Glow Jar", Rarity = "Uncommon", Value = 1000, Weight = 300, SpawnArea = "Marsh", Shape = "Lantern", Color = { 200, 120, 255 }, Material = "Neon", DisplaySize = "Small", Fx = "Fireflies", Lore = "Fireflies that never sleep." },
	{ Id = "witch_cauldron", Name = "Witch's Cauldron", Rarity = "Rare", Value = 7000, Weight = 2000, SpawnArea = "Marsh", Shape = "Pot", Color = { 60, 55, 70 }, Material = "Metal", DisplaySize = "Large", Fx = "Bubbles", Lore = "Still bubbling. Don't sniff it." },
	{ Id = "spore_scepter", Name = "Spore Queen's Scepter", Rarity = "Epic", Value = 22000, Weight = 1400, SpawnArea = "Marsh", Shape = "Trident", Color = { 190, 90, 255 }, Material = "Neon", DisplaySize = "Medium", Fx = "Spores", Lore = "One wave and the whole bog glows." },
	{ Id = "moonshroom", Name = "Moonshroom", Rarity = "Legendary", Value = 80000, Weight = 2200, SpawnArea = "Marsh", Shape = "Egg", Color = { 150, 190, 255 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "Nocturnal", Fx = "Spores", Lore = "Only blooms under the moon - and so does its price." },

	-- Lower tiers for the far regions / the odd big find in the Wilds (loot follows danger).
	{ Id = "oak_kings_chest", Name = "Oak King's Chest", Rarity = "Epic", Value = 18700, Weight = 1600, SpawnArea = "Wilds", Shape = "Chest", Color = { 130, 90, 50 }, Material = "Wood", DisplaySize = "Medium", Fx = "Leaves", Lore = "Buried under the oldest tree in the Wilds. Somebody dug it up." },
	{ Id = "mist_flask", Name = "Mist Flask", Rarity = "Uncommon", Value = 1600, Weight = 400, SpawnArea = "Falls", Shape = "Goblet", Color = { 170, 220, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Water", Lore = "Bottled spray from the falls. Never runs dry." },
	{ Id = "river_charm", Name = "River Stone Charm", Rarity = "Uncommon", Value = 1170, Weight = 350, SpawnArea = "Falls", Shape = "Ring", Color = { 90, 140, 160 }, Material = "Slate", DisplaySize = "Small", Fx = "Water", Lore = "Smoothed by a thousand years of water." },
	{ Id = "storm_feather", Name = "Storm Eagle Feather", Rarity = "Rare", Value = 7650, Weight = 700, SpawnArea = "Falls", Shape = "Feather", Color = { 120, 110, 140 }, Material = "SmoothPlastic", DisplaySize = "Medium", Fx = "Lightning", Lore = "Crackles before every storm." },
	{ Id = "cliff_tablet", Name = "Cliffside Tablet", Rarity = "Rare", Value = 9000, Weight = 1900, SpawnArea = "Falls", Shape = "Tablet", Color = { 150, 150, 160 }, Material = "Slate", DisplaySize = "Medium", Fx = "Sparkle", Lore = "Carved with a map of the island - before the island existed." },

	-- EMBERFALL (the Deep South, danger 5)
	{ Id = "obsidian_shard", Name = "Obsidian Shard", Rarity = "Uncommon", Value = 1950, Weight = 800, SpawnArea = "Ember", Shape = "Gem", Color = { 40, 30, 50 }, Material = "Glass", DisplaySize = "Small", Fx = "Embers", Lore = "Volcanic glass, still warm, sharp enough to shave with." },
	{ Id = "ember_lantern", Name = "Ember Lantern", Rarity = "Rare", Value = 9400, Weight = 1400, SpawnArea = "Ember", Shape = "Lantern", Color = { 255, 140, 60 }, Material = "Neon", DisplaySize = "Medium", Fx = "Flames", Lore = "Its flame was lit in Mount Cinder. It has never gone out." },
	{ Id = "salamander_scale", Name = "Salamander Scale", Rarity = "Rare", Value = 8900, Weight = 900, SpawnArea = "Ember", Shape = "Disc", Color = { 230, 80, 30 }, Material = "Glass", DisplaySize = "Medium", Fx = "Embers", Lore = "Shed by a salamander the size of a horse. Fireproof." },
	{ Id = "molten_crown", Name = "Molten Crown", Rarity = "Epic", Value = 46000, Weight = 2600, SpawnArea = "Ember", Shape = "Crown", Color = { 255, 120, 40 }, Material = "Metal", DisplaySize = "Large", Fx = "Flames", Lore = "Forged for a fire king. It never quite set." },
	{ Id = "forge_hammer", Name = "The Old King's Hammer", Rarity = "Epic", Value = 43000, Weight = 2900, SpawnArea = "Ember", Shape = "Trident", Color = { 90, 90, 100 }, Material = "Metal", DisplaySize = "Large", Fx = "Embers", Lore = "It rang for a thousand years in the forge under the mountain." },
	{ Id = "heart_of_cinder", Name = "Heart of Cinder", Rarity = "Legendary", Value = 230000, Weight = 4600, SpawnArea = "Ember", Shape = "Gem", Color = { 255, 80, 30 }, Material = "Neon", DisplaySize = "Large", Fx = "Flames", Lore = "Mount Cinder's heartbeat, cooled into stone. It still pulses." },
	{ Id = "phoenix_egg", Name = "Phoenix Egg", Rarity = "Mythic", Value = 900000, Weight = 7200, SpawnArea = "Ember", Shape = "Egg", Color = { 255, 120, 40 }, Material = "Neon", DisplaySize = "Huge", Fx = "Flames", Lore = "Laid in the lava. It hatches when the world ends." },
	-- RIMEHEART (the Deep South, danger 6)
	{ Id = "glacier_pearl", Name = "Glacier Pearl", Rarity = "Uncommon", Value = 1935, Weight = 700, SpawnArea = "Rime", Shape = "Orb", Color = { 200, 240, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Frost", Lore = "A pearl grown in ice instead of an oyster." },
	{ Id = "frozen_compass", Name = "Frozen Compass", Rarity = "Rare", Value = 9600, Weight = 1100, SpawnArea = "Rime", Shape = "Disc", Color = { 150, 210, 240 }, Material = "Glass", DisplaySize = "Medium", Fx = "Frost", Lore = "Frozen solid, still pointing south. Always south." },
	{ Id = "wyrm_fang", Name = "Wyrm Fang", Rarity = "Rare", Value = 9835, Weight = 1700, SpawnArea = "Rime", Shape = "Horn", Color = { 230, 240, 250 }, Material = "Marble", DisplaySize = "Large", Fx = "Frost", Lore = "Pulled from something that swims through ice." },
	{ Id = "aurora_harp", Name = "Aurora Harp", Rarity = "Epic", Value = 48000, Weight = 2400, SpawnArea = "Rime", Shape = "Tablet", Color = { 120, 255, 200 }, Material = "Neon", DisplaySize = "Large", Fx = "Aurora", Lore = "Pluck it and the northern lights answer." },
	{ Id = "crown_of_winter", Name = "Crown of Winter", Rarity = "Legendary", Value = 240000, Weight = 4200, SpawnArea = "Rime", Shape = "Crown", Color = { 190, 235, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Snow", Lore = "Whoever wears it never feels warm again. Worth it." },
	{ Id = "everfrost_core", Name = "Everfrost Core", Rarity = "Mythic", Value = 950000, Weight = 6800, SpawnArea = "Rime", Shape = "Gem", Color = { 120, 220, 255 }, Material = "Neon", DisplaySize = "Large", Fx = "Frost", Lore = "The glacier's frozen heart. The ice grows back around it." },
	-- THE STARFALL ISLES (the Deep South, danger 7)
	{ Id = "moondust_pouch", Name = "Pouch of Moondust", Rarity = "Uncommon", Value = 1980, Weight = 500, SpawnArea = "Star", Shape = "Pouch", Color = { 200, 190, 255 }, Material = "Fabric", DisplaySize = "Small", Fx = "Stars", Lore = "Swept off the isles after a meteor shower." },
	{ Id = "stardust_vial", Name = "Vial of Stardust", Rarity = "Rare", Value = 9900, Weight = 800, SpawnArea = "Star", Shape = "Goblet", Color = { 255, 230, 160 }, Material = "Glass", DisplaySize = "Small", Fx = "Stars", Lore = "Shake it and it glows brighter. Don't shake it." },
	{ Id = "comet_shard", Name = "Comet Shard", Rarity = "Epic", Value = 49000, Weight = 2200, SpawnArea = "Star", Shape = "Gem", Color = { 150, 220, 255 }, Material = "Neon", DisplaySize = "Medium", Fx = "Stars", Lore = "A piece of a comet that forgot to stop." },
	{ Id = "astrolabe", Name = "Astrolabe of Ages", Rarity = "Epic", Value = 47500, Weight = 2800, SpawnArea = "Star", Shape = "Ring", Color = { 230, 190, 90 }, Material = "Metal", DisplaySize = "Large", Fx = "Stars", Lore = "It maps stars that haven't been born yet." },
	{ Id = "nebula_orb", Name = "Nebula Orb", Rarity = "Legendary", Value = 245000, Weight = 3800, SpawnArea = "Star", Shape = "Orb", Color = { 190, 120, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Void", Lore = "A whole nebula, swirling in a ball of glass." },
	{ Id = "fallen_star", Name = "Fallen Star", Rarity = "Mythic", Value = 980000, Weight = 6000, SpawnArea = "Star", Shape = "Orb", Color = { 255, 230, 120 }, Material = "Neon", DisplaySize = "Large", Fx = "Stars", Lore = "It fell. It's still falling, somehow." },
	{ Id = "celestial_crown", Name = "Celestial Crown", Rarity = "Divine", Value = 1900000, Weight = 5000, SpawnArea = "Star", Shape = "Crown", Color = { 255, 240, 200 }, Material = "Metal", DisplaySize = "Large", Fx = "Stars", Lore = "The crown of the sky itself. The stars bow to it." },

	-- DIVINE ($1,000,000-2,000,000)
	{ Id = "aurora_crystal", Name = "Aurora Crystal", Rarity = "Divine", Value = 1200000, Weight = 5000, SpawnArea = "Frost", Shape = "Gem", Color = { 0, 229, 255 }, Material = "Neon", DisplaySize = "Large", Fx = "Aurora", Lore = "The northern lights, frozen mid-dance." },
	{ Id = "seraph_feather", Name = "Seraph Feather", Rarity = "Divine", Value = 1600000, Weight = 3000, SpawnArea = "Falls", Shape = "Feather", Color = { 180, 250, 255 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "Swift", Fx = "Feathers", Lore = "Fell from somewhere much higher than the cliff." },

	-- SECRET ($1,000,000+)
	{ Id = "heart_of_the_island", Name = "Heart of the Island", Rarity = "Secret", Value = 2500000, Weight = 4000, SpawnArea = "Falls", Shape = "Orb", Color = { 255, 255, 255 }, Material = "Neon", DisplaySize = "Large", SpecialEffect = "Radiant", Fx = "Rainbow", Lore = "They said it was a myth." },
	{ Id = "frostbane", Name = "Frostbane", Rarity = "Secret", Value = 3000000, Weight = 6500, SpawnArea = "Frost", Shape = "Trident", Color = { 170, 205, 235 }, Material = "Metal", DisplaySize = "Medium", Fx = "Frost", Lore = "A runeblade forged in the heart of a glacier. It hungers. It whispers. It never thaws." },

	-- OG ($5,000,000+) - the rarest thing on the island
	{ Id = "first_doubloon", Name = "The First Doubloon", Rarity = "OG", Value = 5000000, Weight = 3500, SpawnArea = "Falls", Shape = "Disc", Color = { 255, 215, 0 }, Material = "Metal", DisplaySize = "Large", SpecialEffect = "Radiant", Fx = "Coins", Lore = "The coin that started every treasure hunt. There is only one." },
	-- THE SECOND HAUL: more of everything, so no region keeps handing you the same thing.
	-- WILDS
	{ Id = "acorn_cache", Name = "Golden Acorn Cache", Rarity = "Common", Value = 180, Weight = 250, SpawnArea = "Wilds", Shape = "Pouch", Color = { 190, 140, 70 }, Material = "Wood", DisplaySize = "Small", Fx = "Leaves", Lore = "A squirrel's life savings. One acorn is solid gold." },
	{ Id = "carved_whistle", Name = "Carved Bird Whistle", Rarity = "Common", Value = 210, Weight = 100, SpawnArea = "Wilds", Shape = "Horn", Color = { 170, 120, 70 }, Material = "Wood", DisplaySize = "Small", Fx = "Notes", Lore = "Blow it and every bird in the Wilds answers." },
	{ Id = "lucky_horseshoe", Name = "Lucky Horseshoe", Rarity = "Common", Value = 330, Weight = 200, SpawnArea = "Wilds", Shape = "Ring", Color = { 200, 200, 210 }, Material = "Metal", DisplaySize = "Small", Fx = "Sparkle", Lore = "Seven nails, seven wishes. Two left." },
	{ Id = "honey_jar", Name = "Wild Honey Jar", Rarity = "Uncommon", Value = 720, Weight = 300, SpawnArea = "Wilds", Shape = "Pot", Color = { 255, 190, 60 }, Material = "Glass", DisplaySize = "Small", Fx = "Fireflies", Lore = "The bees want it back. The bees are fast." },
	{ Id = "owl_totem", Name = "Owl Totem", Rarity = "Uncommon", Value = 1050, Weight = 500, SpawnArea = "Wilds", Shape = "Idol", Color = { 140, 100, 70 }, Material = "Wood", DisplaySize = "Medium", Fx = "Feathers", Lore = "It turns its head when you're not looking." },
	{ Id = "fairy_lantern", Name = "Fairy Lantern", Rarity = "Rare", Value = 4200, Weight = 650, SpawnArea = "Wilds", Shape = "Lantern", Color = { 255, 160, 230 }, Material = "Glass", DisplaySize = "Medium", Fx = "Fireflies", Lore = "A fairy lives inside. She pays no rent." },
	{ Id = "treant_heart", Name = "Heartwood of the Old Treant", Rarity = "Epic", Value = 16500, Weight = 1800, SpawnArea = "Wilds", Shape = "Gem", Color = { 110, 200, 80 }, Material = "Wood", DisplaySize = "Medium", Fx = "Leaves", Lore = "The oldest tree in the Wilds grew around it for a thousand years." },
	{ Id = "golden_goose", Name = "Golden Goose", Rarity = "Mythic", Value = 520000, Weight = 5500, SpawnArea = "Wilds", Shape = "Idol", Color = { 255, 205, 60 }, Material = "Metal", DisplaySize = "Large", Fx = "Coins", Lore = "Lays one golden egg a year. Today might be the day." },
	-- COAST
	{ Id = "sea_glass", Name = "Sea Glass Shards", Rarity = "Common", Value = 160, Weight = 100, SpawnArea = "Coast", Shape = "Gem", Color = { 120, 210, 200 }, Material = "Glass", DisplaySize = "Small", Fx = "Bubbles", Lore = "The ocean polished them for a hundred years." },
	{ Id = "mermaid_comb", Name = "Mermaid's Comb", Rarity = "Uncommon", Value = 1180, Weight = 320, SpawnArea = "Coast", Shape = "Tablet", Color = { 255, 190, 210 }, Material = "Marble", DisplaySize = "Small", Fx = "Bubbles", Lore = "Still has a strand of sea-green hair in it." },
	{ Id = "coral_tiara", Name = "Coral Tiara", Rarity = "Uncommon", Value = 1750, Weight = 300, SpawnArea = "Coast", Shape = "Crown", Color = { 255, 120, 110 }, Material = "Marble", DisplaySize = "Small", Fx = "Bubbles", Lore = "Grown, not made. The reef misses it." },
	{ Id = "cursed_doubloons", Name = "Cursed Doubloons", Rarity = "Rare", Value = 5600, Weight = 900, SpawnArea = "Coast", Shape = "Disc", Color = { 255, 200, 60 }, Material = "Metal", DisplaySize = "Medium", Fx = "Souls", Lore = "Spend one and it comes back. With friends." },
	{ Id = "leviathan_scale", Name = "Leviathan Scale", Rarity = "Epic", Value = 36000, Weight = 2300, SpawnArea = "Coast", Shape = "Disc", Color = { 40, 150, 170 }, Material = "Glass", DisplaySize = "Large", Fx = "Water", Lore = "One scale. Imagine the rest of it." },
	{ Id = "kraken_eye", Name = "Eye of the Kraken", Rarity = "Mythic", Value = 750000, Weight = 6500, SpawnArea = "Coast", Shape = "Orb", Color = { 255, 170, 40 }, Material = "Glass", DisplaySize = "Large", Fx = "Water", Lore = "It blinks. You should run." },
	-- MARSH
	{ Id = "bog_bottle", Name = "Bottled Bog Gas", Rarity = "Common", Value = 140, Weight = 100, SpawnArea = "Marsh", Shape = "Lantern", Color = { 150, 200, 80 }, Material = "Glass", DisplaySize = "Small", Fx = "Bubbles", Lore = "Do NOT open near a torch." },
	{ Id = "lily_lantern", Name = "Lily Pad Lantern", Rarity = "Common", Value = 370, Weight = 200, SpawnArea = "Marsh", Shape = "Lantern", Color = { 120, 200, 120 }, Material = "Glass", DisplaySize = "Small", Fx = "Fireflies", Lore = "Floats on the pools at night, glowing softly." },
	{ Id = "firefly_crown", Name = "Firefly Crown", Rarity = "Uncommon", Value = 860, Weight = 310, SpawnArea = "Marsh", Shape = "Crown", Color = { 220, 255, 120 }, Material = "Grass", DisplaySize = "Small", Fx = "Fireflies", Lore = "A thousand fireflies holding hands." },
	{ Id = "hex_doll", Name = "Hex Doll", Rarity = "Uncommon", Value = 1320, Weight = 340, SpawnArea = "Marsh", Shape = "Idol", Color = { 160, 110, 170 }, Material = "Fabric", DisplaySize = "Small", Fx = "Spores", Lore = "Poke it and someone, somewhere, says ouch." },
	{ Id = "mushroom_king_cap", Name = "Mushroom King's Cap", Rarity = "Rare", Value = 5100, Weight = 1300, SpawnArea = "Marsh", Shape = "Egg", Color = { 230, 70, 80 }, Material = "SmoothPlastic", DisplaySize = "Medium", Fx = "Spores", Lore = "Red with white spots. Bows to no one." },
	{ Id = "frog_prince_crown", Name = "Frog Prince's Crown", Rarity = "Rare", Value = 6100, Weight = 600, SpawnArea = "Marsh", Shape = "Crown", Color = { 255, 210, 90 }, Material = "Metal", DisplaySize = "Small", Fx = "Magic", Lore = "Kiss the frog? Keep the crown." },
	{ Id = "witch_broom", Name = "Swamp Witch's Broom", Rarity = "Epic", Value = 21000, Weight = 1300, SpawnArea = "Marsh", Shape = "Trident", Color = { 140, 90, 60 }, Material = "Wood", DisplaySize = "Medium", Fx = "Magic", Lore = "Still twitching to fly away." },
	{ Id = "unicorn_horn", Name = "Unicorn Horn", Rarity = "Divine", Value = 1400000, Weight = 3200, SpawnArea = "Marsh", Shape = "Horn", Color = { 255, 225, 250 }, Material = "Marble", DisplaySize = "Large", Fx = "Rainbow", Lore = "The marsh unicorn is real. This proves it." },
	-- RUINS
	{ Id = "sand_hourglass", Name = "Sand Hourglass", Rarity = "Common", Value = 290, Weight = 300, SpawnArea = "Ruins", Shape = "Goblet", Color = { 230, 200, 140 }, Material = "Glass", DisplaySize = "Small", Fx = "Sand", Lore = "The sand falls up when nobody watches." },
	{ Id = "cobra_idol", Name = "Cobra Idol", Rarity = "Uncommon", Value = 1450, Weight = 600, SpawnArea = "Ruins", Shape = "Idol", Color = { 60, 140, 80 }, Material = "Slate", DisplaySize = "Medium", Fx = "Souls", Lore = "Its eyes follow you. So does its tongue." },
	{ Id = "sun_mirror", Name = "Sun Mirror", Rarity = "Uncommon", Value = 1850, Weight = 500, SpawnArea = "Ruins", Shape = "Disc", Color = { 255, 220, 120 }, Material = "Metal", DisplaySize = "Medium", Fx = "Sparkle", Lore = "Priests signalled the sun with it. The sun signalled back." },
	{ Id = "pharaoh_mask", Name = "Pharaoh's Death Mask", Rarity = "Rare", Value = 8600, Weight = 1500, SpawnArea = "Ruins", Shape = "Tablet", Color = { 255, 195, 60 }, Material = "Metal", DisplaySize = "Medium", Fx = "Sand", Lore = "Gold, lapis, and a very bad mood." },
	{ Id = "judgement_scales", Name = "Scales of Judgement", Rarity = "Rare", Value = 6800, Weight = 1200, SpawnArea = "Ruins", Shape = "Goblet", Color = { 230, 190, 90 }, Material = "Metal", DisplaySize = "Medium", Fx = "Souls", Lore = "Weighs your heart against a feather. Yours is heavier." },
	{ Id = "sphinx_head", Name = "Sphinx Head", Rarity = "Epic", Value = 38000, Weight = 3000, SpawnArea = "Ruins", Shape = "Idol", Color = { 220, 180, 120 }, Material = "Sandstone", DisplaySize = "Large", Fx = "Sand", Lore = "Asks a riddle. Nobody has ever answered." },
	-- FROSTPEAK
	{ Id = "snow_globe", Name = "Snow Globe", Rarity = "Common", Value = 240, Weight = 250, SpawnArea = "Frost", Shape = "Orb", Color = { 200, 230, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Snow", Lore = "A tiny Frostpeak. It's snowing in there." },
	{ Id = "silver_skates", Name = "Silver Skates", Rarity = "Common", Value = 420, Weight = 300, SpawnArea = "Frost", Shape = "Tablet", Color = { 210, 220, 235 }, Material = "Metal", DisplaySize = "Small", Fx = "Snow", Lore = "Fastest pair on the frozen lake." },
	{ Id = "penguin_statue", Name = "Penguin Statue", Rarity = "Uncommon", Value = 950, Weight = 500, SpawnArea = "Frost", Shape = "Idol", Color = { 40, 45, 60 }, Material = "Marble", DisplaySize = "Medium", Fx = "Snow", Lore = "Carved by a very lonely yeti." },
	{ Id = "frost_lantern", Name = "Frost Lantern", Rarity = "Uncommon", Value = 1620, Weight = 400, SpawnArea = "Frost", Shape = "Lantern", Color = { 150, 220, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Frost", Lore = "Burns with a cold blue flame." },
	{ Id = "icicle_scepter", Name = "Icicle Scepter", Rarity = "Rare", Value = 7300, Weight = 1000, SpawnArea = "Frost", Shape = "Trident", Color = { 170, 230, 255 }, Material = "Glass", DisplaySize = "Medium", Fx = "Frost", Lore = "Never melts. Never breaks. Never warm." },
	{ Id = "snow_owl_egg", Name = "Snow Owl Egg", Rarity = "Rare", Value = 5900, Weight = 800, SpawnArea = "Frost", Shape = "Egg", Color = { 235, 245, 255 }, Material = "Marble", DisplaySize = "Medium", Fx = "Feathers", Lore = "Something inside is hooting." },
	{ Id = "blizzard_orb", Name = "Blizzard Orb", Rarity = "Epic", Value = 26000, Weight = 1800, SpawnArea = "Frost", Shape = "Orb", Color = { 180, 220, 255 }, Material = "Glass", DisplaySize = "Medium", Fx = "Snow", Lore = "A whole blizzard, trapped. It wants out." },
	-- THE FALLS
	{ Id = "parrot_totem", Name = "Parrot Totem", Rarity = "Uncommon", Value = 1380, Weight = 500, SpawnArea = "Falls", Shape = "Idol", Color = { 230, 60, 50 }, Material = "Wood", DisplaySize = "Medium", Fx = "Feathers", Lore = "Repeats everything you say. Loudly." },
	{ Id = "waterfall_pearl", Name = "Waterfall Pearl", Rarity = "Rare", Value = 6300, Weight = 700, SpawnArea = "Falls", Shape = "Orb", Color = { 170, 230, 255 }, Material = "Glass", DisplaySize = "Medium", Fx = "Water", Lore = "Formed under the falls, one drop at a time." },
	{ Id = "thunder_drum", Name = "Thunder Drum", Rarity = "Rare", Value = 7800, Weight = 1600, SpawnArea = "Falls", Shape = "Pot", Color = { 150, 90, 50 }, Material = "Wood", DisplaySize = "Medium", Fx = "Lightning", Lore = "One beat and the sky rumbles back." },
	{ Id = "rainbow_prism", Name = "Rainbow Prism", Rarity = "Epic", Value = 29000, Weight = 1200, SpawnArea = "Falls", Shape = "Gem", Color = { 255, 255, 255 }, Material = "Glass", DisplaySize = "Medium", Fx = "Rainbow", Lore = "Splits the waterfall's mist into every colour." },
	{ Id = "tide_idol", Name = "Idol of Tides", Rarity = "Epic", Value = 34000, Weight = 2400, SpawnArea = "Falls", Shape = "Idol", Color = { 40, 120, 180 }, Material = "Slate", DisplaySize = "Large", Fx = "Water", Lore = "The river rises when it's angry." },
	{ Id = "thunderbird_egg", Name = "Thunderbird Egg", Rarity = "Legendary", Value = 175000, Weight = 3600, SpawnArea = "Falls", Shape = "Egg", Color = { 90, 120, 200 }, Material = "Slate", DisplaySize = "Large", Fx = "Lightning", Lore = "Crackles with lightning. It's about to hatch." },
	-- EMBERFALL
	{ Id = "magma_marble", Name = "Magma Marble", Rarity = "Uncommon", Value = 1880, Weight = 600, SpawnArea = "Ember", Shape = "Orb", Color = { 255, 90, 30 }, Material = "Glass", DisplaySize = "Small", Fx = "Embers", Lore = "Lava, rolled into a ball. Don't hold it long." },
	{ Id = "fire_opal", Name = "Fire Opal", Rarity = "Rare", Value = 9200, Weight = 700, SpawnArea = "Ember", Shape = "Gem", Color = { 255, 120, 70 }, Material = "Glass", DisplaySize = "Small", Fx = "Embers", Lore = "Flames dance inside it forever." },
	{ Id = "dragon_scale_shield", Name = "Dragonscale Shield", Rarity = "Rare", Value = 8300, Weight = 1900, SpawnArea = "Ember", Shape = "Disc", Color = { 150, 40, 30 }, Material = "Metal", DisplaySize = "Large", Fx = "Embers", Lore = "Took a dragon's breath. Didn't even get warm." },
	{ Id = "inferno_chalice", Name = "Inferno Chalice", Rarity = "Epic", Value = 44000, Weight = 2200, SpawnArea = "Ember", Shape = "Goblet", Color = { 255, 110, 30 }, Material = "Metal", DisplaySize = "Medium", Fx = "Flames", Lore = "Pour anything in. Fire comes out." },
	{ Id = "phoenix_lyre", Name = "Phoenix Lyre", Rarity = "Epic", Value = 41000, Weight = 1600, SpawnArea = "Ember", Shape = "Tablet", Color = { 255, 170, 60 }, Material = "Metal", DisplaySize = "Medium", Fx = "Flames", Lore = "Plays one song: the one that calls the phoenix." },
	{ Id = "ifrit_lamp", Name = "Ifrit's Lamp", Rarity = "Legendary", Value = 220000, Weight = 3400, SpawnArea = "Ember", Shape = "Lantern", Color = { 255, 180, 70 }, Material = "Metal", DisplaySize = "Medium", Fx = "Magic", Lore = "Rub it. Go on. What's the worst that could happen?" },
	-- RIMEHEART
	{ Id = "frost_feather", Name = "Frost Feather", Rarity = "Uncommon", Value = 1920, Weight = 300, SpawnArea = "Rime", Shape = "Feather", Color = { 200, 240, 255 }, Material = "Glass", DisplaySize = "Small", Fx = "Snow", Lore = "Dropped by a bird made of snow." },
	{ Id = "narwhal_horn", Name = "Narwhal Horn", Rarity = "Rare", Value = 9700, Weight = 1600, SpawnArea = "Rime", Shape = "Horn", Color = { 235, 245, 255 }, Material = "Marble", DisplaySize = "Large", Fx = "Frost", Lore = "The unicorn of the frozen sea." },
	{ Id = "ice_dragon_egg", Name = "Ice Dragon Egg", Rarity = "Epic", Value = 49500, Weight = 2600, SpawnArea = "Rime", Shape = "Egg", Color = { 140, 210, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Frost", Lore = "Colder than the glacier. It's moving." },
	{ Id = "glacier_bell", Name = "Bell of the Glacier", Rarity = "Epic", Value = 45500, Weight = 2500, SpawnArea = "Rime", Shape = "Pot", Color = { 170, 220, 245 }, Material = "Glass", DisplaySize = "Large", Fx = "Notes", Lore = "Rings once for every avalanche." },
	{ Id = "frozen_treasure_chest", Name = "Frozen Treasure Chest", Rarity = "Epic", Value = 40500, Weight = 2800, SpawnArea = "Rime", Shape = "Chest", Color = { 190, 230, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Coins", Lore = "Somebody's loot, frozen mid-heist." },
	{ Id = "frost_titan_heart", Name = "Heart of the Frost Titan", Rarity = "Legendary", Value = 238000, Weight = 4400, SpawnArea = "Rime", Shape = "Gem", Color = { 120, 200, 255 }, Material = "Glass", DisplaySize = "Large", Fx = "Frost", Lore = "The Titan is still looking for it." },
	{ Id = "aurora_lantern", Name = "Aurora Lantern", Rarity = "Legendary", Value = 205000, Weight = 3000, SpawnArea = "Rime", Shape = "Lantern", Color = { 120, 255, 200 }, Material = "Neon", DisplaySize = "Medium", Fx = "Aurora", Lore = "Holds a piece of the northern lights." },
	-- STARFALL ISLES
	{ Id = "meteorite", Name = "Meteorite Chunk", Rarity = "Uncommon", Value = 1990, Weight = 700, SpawnArea = "Star", Shape = "Gem", Color = { 80, 70, 90 }, Material = "Basalt", DisplaySize = "Small", Fx = "Stars", Lore = "Still hot from its trip through the sky." },
	{ Id = "star_chart", Name = "Star Chart", Rarity = "Rare", Value = 9950, Weight = 800, SpawnArea = "Star", Shape = "Tablet", Color = { 40, 40, 90 }, Material = "Fabric", DisplaySize = "Medium", Fx = "Stars", Lore = "Maps a sky nobody has seen yet." },
	{ Id = "moon_rabbit", Name = "Moon Rabbit Idol", Rarity = "Rare", Value = 9750, Weight = 1000, SpawnArea = "Star", Shape = "Idol", Color = { 240, 240, 255 }, Material = "Marble", DisplaySize = "Medium", Fx = "Stars", Lore = "Fell off the moon. Still pounding rice." },
	{ Id = "tiny_planet", Name = "Tiny Planet", Rarity = "Epic", Value = 48500, Weight = 2300, SpawnArea = "Star", Shape = "Orb", Color = { 90, 160, 255 }, Material = "SmoothPlastic", DisplaySize = "Medium", Fx = "Stars", Lore = "Population: probably someone." },
	{ Id = "constellation_tiara", Name = "Constellation Tiara", Rarity = "Epic", Value = 47000, Weight = 1800, SpawnArea = "Star", Shape = "Crown", Color = { 200, 210, 255 }, Material = "Metal", DisplaySize = "Medium", Fx = "Stars", Lore = "Every jewel is a real star, shrunk." },
	{ Id = "void_lantern", Name = "Void Lantern", Rarity = "Epic", Value = 49800, Weight = 2100, SpawnArea = "Star", Shape = "Lantern", Color = { 90, 40, 160 }, Material = "Neon", DisplaySize = "Medium", Fx = "Void", Lore = "The light inside is darker than the dark outside." },
	{ Id = "supernova_core", Name = "Supernova Core", Rarity = "Legendary", Value = 248000, Weight = 4000, SpawnArea = "Star", Shape = "Orb", Color = { 255, 220, 150 }, Material = "Neon", DisplaySize = "Large", Fx = "Stars", Lore = "A star's last breath, kept in a ball." },
	{ Id = "galaxy_egg", Name = "Galaxy Egg", Rarity = "Legendary", Value = 232000, Weight = 3700, SpawnArea = "Star", Shape = "Egg", Color = { 120, 80, 200 }, Material = "Glass", DisplaySize = "Large", Fx = "Void", Lore = "A whole galaxy is about to hatch." },
	{ Id = "pocket_black_hole", Name = "Pocket Black Hole", Rarity = "Secret", Value = 3500000, Weight = 7000, SpawnArea = "Star", Shape = "Orb", Color = { 15, 10, 25 }, Material = "SmoothPlastic", DisplaySize = "Large", Fx = "Void", Lore = "Handle with care. Actually, don't handle it." },

	-- EVENT TREASURES: never spawn on their own - only when an admin drops them (Admin panel).
	-- Their own collection set, for the players who were there.
	{ Id = "heist_bag", Name = "Golden Heist Bag", Rarity = "Mythic", Value = 800000, Weight = 5000, SpawnArea = "Event", AdminOnly = true, Shape = "Pouch", Color = { 255, 205, 60 }, Material = "Metal", DisplaySize = "Large", Fx = "Coins", Lore = "Only appears when the heist masters say so." },
	{ Id = "cosmic_cat", Name = "Cosmic Cat", Rarity = "Divine", Value = 1750000, Weight = 3500, SpawnArea = "Event", AdminOnly = true, Shape = "Idol", Color = { 40, 30, 70 }, Material = "SmoothPlastic", DisplaySize = "Large", Fx = "Stars", Lore = "It fell from space and landed on its feet." },
	{ Id = "crown_of_heists", Name = "Crown of a Thousand Heists", Rarity = "Secret", Value = 4000000, Weight = 4500, SpawnArea = "Event", AdminOnly = true, Shape = "Crown", Color = { 255, 215, 80 }, Material = "Metal", DisplaySize = "Large", Fx = "Rainbow", Lore = "Worn by whoever steals it last." },
	{ Id = "dev_duck", Name = "The Golden Rubber Duck", Rarity = "OG", Value = 6000000, Weight = 3000, SpawnArea = "Event", AdminOnly = true, Shape = "Idol", Color = { 255, 220, 60 }, Material = "Metal", DisplaySize = "Large", Fx = "Rainbow", Lore = "Squeaks. Worth six million. Don't ask." },
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
