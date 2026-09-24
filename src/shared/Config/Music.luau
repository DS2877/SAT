-- Background music. Upload the audio to Roblox (Creator Hub -> Development Items -> Audio, from
-- the account/group that owns the experience) and paste each asset id as "rbxassetid://<id>".
-- Empty ids are skipped, so the game runs silently until tracks are added.
--
--   Playlist:   rolls in the background (shuffled, loops forever), crossfading between tracks.
--   CarryTheme: starts from the top the moment you pick up a treasure and loops while you carry
--               it; drop / extract / lose it and the playlist fades back in where it left off.
--   CarryByRarity (optional): a different carry theme for specific rarities, e.g. Legendary.
--   SuccessSting / FailSting: short one-shots when a carry ends - extracted vs dropped / lost.
--
-- Tracks are public-domain recordings found and uploaded by the music pipeline
-- (music/tracks.json, tools/music/pipeline.py, .github/workflows/music.yml); see music/CREDITS.md.

local Music = {}

Music.Volume = 0.35 -- master music volume (players can mute in the HUD)
Music.CrossfadeSeconds = 1.5
Music.Shuffle = true

Music.Playlist = {
	-- { Name = "Island Morning", Id = "rbxassetid://0000000000" },
}

Music.CarryTheme = { Name = "The Getaway", Id = "" }

Music.SuccessSting = { Name = "Extraction Fanfare", Id = "", Volume = 1 }
Music.FailSting = { Name = "Lost It", Id = "", Volume = 1 }

Music.CarryByRarity = {
	-- Legendary = { Name = "Legendary Heist", Id = "rbxassetid://0000000000" },
}

return Music
