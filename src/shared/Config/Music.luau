-- Background music. Ids are "rbxassetid://<id>" audio assets owned by the experience's owner;
-- empty ids are skipped (silence).
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

-- Mischievous classical: orchestral Grieg / Tchaikovsky / Saint-Saens and solo piano.
Music.Playlist = {
	{ Name = "Morning Mood", Id = "rbxassetid://78668272498081" }, -- Edvard Grieg
	{ Name = "Anitra's Dance", Id = "rbxassetid://105535399370641" }, -- Edvard Grieg
	{ Name = "Sugar Plum Fairy and Russian Dance", Id = "rbxassetid://95147405203508" }, -- Pyotr Tchaikovsky
	{ Name = "Danse Macabre", Id = "rbxassetid://111142441082336" }, -- Camille Saint-Saens
	{ Name = "Flight of the Bumblebee", Id = "rbxassetid://106049612353448" }, -- Nikolai Rimsky-Korsakov
	{ Name = "Rondo alla Turca", Id = "rbxassetid://109763529271338" }, -- Wolfgang Amadeus Mozart
	{ Name = "Fur Elise", Id = "rbxassetid://90914907253072" }, -- Ludwig van Beethoven
	{ Name = "Minute Waltz", Id = "rbxassetid://127639660640379" }, -- Frederic Chopin
	{ Name = "The Entertainer", Id = "rbxassetid://102817718772248" }, -- Scott Joplin
}

Music.CarryTheme = { Name = "In the Hall of the Mountain King", Id = "rbxassetid://97301792132141" } -- Grieg, Musopen

Music.SuccessSting = { Name = "Extraction Fanfare", Id = "rbxassetid://116829871483507", Volume = 0.9 }
Music.FailSting = { Name = "Lost It", Id = "rbxassetid://97318551187594", Volume = 0.9 }

Music.CarryByRarity = {
	-- Legendary = { Name = "Legendary Heist", Id = "rbxassetid://0000000000" },
}

return Music
