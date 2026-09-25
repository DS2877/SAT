-- Background music. Ids are "rbxassetid://<id>" audio assets owned by the experience's owner;
-- empty ids are skipped (silence).
--
--   Playlist:   rolls in the background (shuffled, loops forever), crossfading between tracks.
--   CarryTheme: starts from the top the moment you pick up a treasure and loops while you carry
--               it; drop / extract / lose it and the playlist fades back in where it left off.
--   CarryByRarity (optional): a different carry theme for specific rarities, e.g. Legendary.
--   SuccessSting / FailSting: short one-shots when a carry ends - extracted vs dropped / lost.
--
-- The success / fail stings are our own uploads (approved); the pipeline in tools/music can
-- upload more and reports each asset's moderation status. See music/CREDITS.md.

local Music = {}

Music.Volume = 0.35 -- master music volume (players can mute in the HUD)
Music.PlaylistVolume = 0.5 -- background tracks play at half volume (clearly under the carry theme)
Music.CrossfadeSeconds = 1.5
Music.Shuffle = true
-- Every session opens with this track; after it, the rest of the playlist is shuffled.
Music.FirstTrack = "Fur Elise"

-- Mischievous classical. These are Roblox's own licensed library recordings (APM Music, uploaded
-- by the verified "APMOfficial" account): free to use in every experience, never moderated away.
-- (Our own public-domain uploads of the same pieces were REJECTED by Roblox moderation, which is
-- why the game was silent - see music/CREDITS.md.)
Music.Playlist = {
	{ Name = "Morning Mood", Id = "rbxassetid://1846088038" }, -- Grieg
	{ Name = "Anitra's Dance", Id = "rbxassetid://1843564354" }, -- Grieg
	{ Name = "Dance of the Sugar Plum Fairy", Id = "rbxassetid://1848047667" }, -- Tchaikovsky
	{ Name = "Russian Dance (Trepak)", Id = "rbxassetid://1848059091" }, -- Tchaikovsky
	{ Name = "Flight of the Bumblebee", Id = "rbxassetid://1836282767" }, -- Rimsky-Korsakov
	{ Name = "Rondo alla Turca", Id = "rbxassetid://1843535552" }, -- Mozart (piano)
	{ Name = "Fur Elise", Id = "rbxassetid://1836283178" }, -- Beethoven (piano)
	{ Name = "The Entertainer", Id = "rbxassetid://1846442728" }, -- Joplin (piano)
	{ Name = "Maple Leaf Rag", Id = "rbxassetid://1846443027" }, -- Joplin (piano)
	{ Name = "Hungarian Dance No. 5", Id = "rbxassetid://1842150470" }, -- Brahms
}

-- Grieg's "In the Hall of the Mountain King" (APM library recording). Our own upload of it,
-- rbxassetid://97301792132141 (Musopen, approved), is the fallback if you ever want to switch.
-- Volume 1.5 = 50% louder than a full-volume track (3x the background playlist);
-- StartAt skips the quiet intro (loops too).
Music.CarryTheme = { Name = "In the Hall of the Mountain King", Id = "rbxassetid://1843564372", Volume = 1.5, StartAt = 15 }

Music.SuccessSting = { Name = "Extraction Fanfare", Id = "rbxassetid://116829871483507", Volume = 0.9 }
Music.FailSting = { Name = "Lost It", Id = "rbxassetid://97318551187594", Volume = 0.9 }

-- RECOGNITION CUES: the day/night cycle has its own music, so players learn to feel it coming.
--   FinalMinute: the last minute before night (the Wilds seal, unbanked loot is lost).
--   Night: the ~30 s night, when new loot is spawning.
-- Priority: carry theme > night > final minute > playlist - a cue never interrupts a carry;
-- if you're carrying when the final minute starts, it picks up once you bank or drop it.
-- Empty ids are skipped (the playlist just keeps playing).
--   Both are APM library recordings (Roblox-licensed, verified APMOfficial account).
--   * Final minute: Bach's Toccata and Fugue in D minor - the most recognisable "oh no" organ
--     in music, as a trailer mix that builds for the whole minute.
--   * Night: Night on Bald Mountain (Mussorgsky: a witches' night) in APM's official 30-second
--     edit - exactly the length of the night. Alternatives found by the library search:
--     60 s edit 9042353909, trailer mix 9043770732, 15 s edit 104173705769074.
Music.FinalMinute = { Name = "Toccata and Fugue in D (Trailer Mix)", Id = "rbxassetid://9043771726", Volume = 1.1 }
Music.Night = { Name = "Night on Bald Mountain (30 Sec)", Id = "rbxassetid://9042354001", Volume = 1.2 }
Music.FinalMinuteSeconds = 60

-- TRAINING: hype gym music while you lift at the bench (under the phase cues and the carry
-- theme). Roblox Creator Store tracks from the DistroKid catalog / APM are licensed for use in
-- any experience. Alternatives from the search: APM "Luxe Life" (boom bap) 73069288137237,
-- "Boom Bap Funkshake" 94154386895952, "Hallo Effect (gym type beat)" 121346459467899.
Music.Training = { Name = "Trap Phonk Power Training Beat", Id = "rbxassetid://126438335141122", Volume = 0.9 }

Music.CarryByRarity = {
	-- Legendary = { Name = "Legendary Heist", Id = "rbxassetid://0000000000" },
}

return Music
