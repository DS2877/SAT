-- Audio hooks. Every gameplay moment routes through Sounds.Play(name) so audio can be
-- swapped in one place.

local SoundService = game:GetService("SoundService")

local Sounds = {}

-- ONE COHERENT, SOFT SET (all licensed in the Roblox Creator Store: Roblox's own UI pack,
-- ProSoundEffects, APM, and the Project 555 / CoreCraft Studio UI libraries - see
-- music/CREDITS.md). Mixed UNDER the music: everything plays through the "SFX" SoundGroup.
-- Rules: one sound per action (buttons whose action makes a sound are Silent - Kit.button),
-- natural pitch, a touch of random pitch on sounds that repeat (so they never feel robotic),
-- and a short per-sound guard so nothing stacks into noise.
local R = "rbxassetid://"
local LIBRARY = {
	-- UI
	Click = { Id = R .. "15675032796", Volume = 0.35, Vary = 0.04 }, -- Roblox_UI_Small_Click
	Swipe = { Id = R .. "15675037413", Volume = 0.3 }, -- Roblox_UI_Paper_Swipe (cards sliding in)
	Error = { Id = R .. "87519554692663", Volume = 0.3, Gap = 0.4 }, -- soft negative blip
	Notify = { Id = R .. "106553517979212", Volume = 0.35, Gap = 0.5, Moment = 1 }, -- banner chime
	-- Bat
	Swing = { Id = R .. "9120972444", Volume = 0.45, Speed = 1.05, Vary = 0.05 }, -- wood whoosh
	BatHit = { Id = R .. "9125380872", Volume = 0.45, Speed = 1.1, Vary = 0.04 }, -- bat whack
	Slap = { Id = R .. "9114771792", Volume = 0.5, Vary = 0.05 }, -- hand slap
	-- Body
	Hit = { Id = R .. "9113480915", Volume = 0.45, Vary = 0.05 }, -- body fall thud
	Knocked = { Id = R .. "9113525391", Volume = 0.5 }, -- body impact
	Shaken = { Id = R .. "15675062723", Volume = 0.35 }, -- Roblox_UI_Whistle_Low
	HeavyStep = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.25, Speed = 0.7, Vary = 0.06 },
	Heartbeat = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.35, Speed = 0.45 },
	-- Treasure + extraction
	Pickup = { Id = R .. "15675055424", Volume = 0.45 }, -- Roblox_UI_Cute_Pop
	Drop = { Id = R .. "9113480917", Volume = 0.4 }, -- soft thud
	RareDiscovery = { Id = R .. "95469323096995", Volume = 0.5, Gap = 0.5, Moment = 3 }, -- three soft bells
	ExtractStart = { Id = R .. "15675046931", Volume = 0.35 }, -- Roblox_UI_Sweep
	ExtractTick = { Id = R .. "15675032796", Volume = 0.12 },
	ExtractInterrupted = { Id = R .. "15675075163", Volume = 0.4 }, -- Roblox_UI_Delete
	ExtractSuccess = { Id = R .. "107978604605265", Volume = 0.45, Gap = 0.4, Moment = 2 }, -- double ding
	BigReward = { Id = R .. "134821092416328", Volume = 0.5, Gap = 0.6, Moment = 4 }, -- rewards tier-up
	-- Progress + world
	Ascend = { Id = R .. "1839901334", Volume = 0.55, Gap = 1, Moment = 5 }, -- APM "Space Chimes"
	Event = { Id = R .. "83059242168617", Volume = 0.45, Gap = 0.6, Moment = 2 }, -- bright plucks
	GuardianAlert = { Id = R .. "133470439269793", Volume = 0.4, Gap = 0.8, Moment = 3 }, -- brass stab
	Gadget = { Id = R .. "15675012262", Volume = 0.4, Vary = 0.04 }, -- Roblox_UI_Whoosh_04
	Splash = { Id = R .. "9125703162", Volume = 0.35, Vary = 0.06 },
	Boost = { Id = R .. "15674975792", Volume = 0.45, Speed = 0.95 }, -- Roblox_UI_Whoosh_03
	Launch = { Id = R .. "9119377942", Volume = 0.45 }, -- soft whoosh burst
	-- Gym
	TrainGood = { Id = R .. "15675032796", Volume = 0.25, Vary = 0.04 },
	TrainPerfect = { Id = R .. "15675059323", Volume = 0.35, Vary = 0.03 }, -- Roblox_UI_Bright_Click
	TrainMiss = { Id = R .. "15675075163", Volume = 0.25 },
	Rep = { Id = R .. "133196982070163", Volume = 0.18, Vary = 0.05 }, -- muffled tap
	MegaRep = { Id = R .. "83059242168617", Volume = 0.4 },
	GoldenRep = { Id = R .. "95469323096995", Volume = 0.45 },
	SetComplete = { Id = R .. "107978604605265", Volume = 0.4 },
	PumpMax = { Id = R .. "15675043410", Volume = 0.4 }, -- Roblox_UI_Tonal_Stinger
}

-- Master level for every sound effect: sits under the music (Config/Music).
local SFX_VOLUME = 0.75
local MIN_GAP = 0.06 -- the same sound can't restart faster than this (unless it sets Gap)

local group = Instance.new("SoundGroup")
group.Name = "SFX"
group.Volume = SFX_VOLUME
group.Parent = SoundService

local cache: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local rng = Random.new()

-- MOMENTS: chimes and stingers (Moment = priority). One moment, one cue: within
-- MOMENT_WINDOW a cue only plays if it outranks the one already playing (a big bank's
-- fanfare swallows the banner ding that arrives with it, never the other way round).
local MOMENT_WINDOW = 0.35
local lastMoment, lastMomentAt = 0, -math.huge

local function allowed(name: string, def): boolean
	local now = os.clock()
	if now - (lastPlayed[name] or -math.huge) < (def.Gap or MIN_GAP) then
		return false
	end
	if def.Moment then
		if now - lastMomentAt < MOMENT_WINDOW and def.Moment <= lastMoment then
			return false
		end
		lastMoment, lastMomentAt = def.Moment, now
	end
	lastPlayed[name] = now
	return true
end

local function pitch(def, speedScale: number?): number
	local vary = def.Vary or 0
	return (def.Speed or 1) * (speedScale or 1) * (1 + rng:NextNumber(-vary, vary))
end

-- speedScale shifts the pitch (e.g. rising pitch as the training pump builds).
function Sounds.Play(name: string, volumeScale: number?, speedScale: number?)
	local def = LIBRARY[name]
	if not def or not allowed(name, def) then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "SFX_" .. name
		sound.SoundId = def.Id
		sound.SoundGroup = group
		sound.Parent = SoundService
		cache[name] = sound
	end
	(sound :: Sound).Volume = def.Volume * (volumeScale or 1);
	(sound :: Sound).PlaybackSpeed = pitch(def, speedScale)
	SoundService:PlayLocalSound(sound :: Sound)
end

-- Positional sound at a world point (other players' swings, guardians).
function Sounds.PlayAt(name: string, position: Vector3)
	local def = LIBRARY[name]
	if not def then
		return
	end
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	local sound = Instance.new("Sound")
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = pitch(def)
	sound.SoundGroup = group
	sound.RollOffMinDistance = 10
	sound.RollOffMaxDistance = 120
	sound.Parent = attachment
	sound:Play()
	task.delay(4, function()
		attachment:Destroy()
	end)
end

-- Preload everything once, so the first tap / first bank never plays late or silent.
task.spawn(function()
	local ContentProvider = game:GetService("ContentProvider")
	local sounds = {}
	for name, def in LIBRARY do
		local sound = Instance.new("Sound")
		sound.Name = "SFX_" .. name
		sound.SoundId = def.Id
		sound.SoundGroup = group
		sound.Parent = SoundService
		cache[name] = sound
		table.insert(sounds, sound)
	end
	pcall(ContentProvider.PreloadAsync, ContentProvider, sounds)
end)

-- Every id in use (for preloading and the unit test).
function Sounds.Ids(): { string }
	local ids = {}
	for _, def in LIBRARY do
		table.insert(ids, def.Id)
	end
	return ids
end

return Sounds
