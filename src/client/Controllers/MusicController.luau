-- Cinematic background music (config: Shared/Config/Music). One rule decides what you hear:
-- the highest layer that is active plays, everything under it fades out and pauses (and picks
-- up exactly where it left off when it's on top again).
--
--   1. CARRY THEME   - while you carry a treasure (never interrupted by anything below)
--   2. TRAINING      - while you lift at the bench (Music.Training): lifting is a choice you
--                      just made, so it wins over the night cues
--   3. PHASE CUE     - the final minute before night (Music.FinalMinute) and the night itself
--                      (Music.Night): recognition music - you learn to feel night coming
--   4. PLAYLIST      - shuffled, looping, crossfading. Every session opens with
--                      Music.FirstTrack (Für Elise); the rest is shuffled after it.
--
-- When a carry ends, a short sting says how it went: SuccessSting when you extracted it,
-- FailSting when you dropped it, got knocked, had it stolen or lost it at nightfall.
-- Muting (HUD 🔊 button) is saved per player (data.Settings.Music).
-- Tracks with empty ids are ignored. A track that fails to load (moderation-rejected, deleted,
-- no permission) is skipped instead of silencing the game, and a warning names it (F9).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Music = require(Shared.Config.Music)
local Treasures = require(Shared.Config.Treasures)
local GameConfig = require(Shared.Config.GameConfig)
local DayNight = require(Shared.Logic.DayNight)
local Net = require(Shared.Net)

local ClientState = require(script.Parent.Parent.ClientState)

local MusicController = {}

local player = Players.LocalPlayer
local group: SoundGroup
local playlist: { Sound } = {}
local failed: { [Sound]: boolean } = {}
local LOAD_TIMEOUT = 12 -- seconds a track may take to start before it is skipped
local order: { number } = {}
local position = 0
local firstLap = true -- the session's first lap opens with Music.FirstTrack
local current: Sound? = nil -- the playlist track
local carrySound: Sound? = nil
local phaseSound: Sound? = nil -- final minute / night cue
local trainingSound: Sound? = nil
local phase = "Day" -- "Day" | "FinalMinute" | "Night"
local muted = false
local holding = false -- carrying anything (even with no carry theme configured)
local lastExtracted = -math.huge -- os.clock() of the last "Extracted" feedback
local STING_WAIT = 0.6 -- the Extracted event can land just after the carry attribute clears

local function valid(track): boolean
	return type(track) == "table" and type(track.Id) == "string" and track.Id ~= ""
end

-- `volume`: the level this track fades up to (per-track mix under the master volume).
local function makeSound(track, looped: boolean, volume: number?): Sound
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. tostring(track.Name or "Track")
	sound.SoundId = track.Id
	sound.Looped = looped
	sound.Volume = 0
	sound.SoundGroup = group
	sound:SetAttribute("TargetVolume", volume or track.Volume or 1)
	if track.FadeSeconds then
		sound:SetAttribute("FadeSeconds", track.FadeSeconds)
	end
	if track.StartAt and track.StartAt > 0 then
		-- Skip the intro, also on every loop.
		sound.PlaybackRegionsEnabled = true
		sound.PlaybackRegion = NumberRange.new(track.StartAt, 100000)
		sound.LoopRegion = NumberRange.new(track.StartAt, 100000)
	end
	sound.Parent = SoundService
	return sound
end

local function targetOf(sound: Sound): number
	return tonumber(sound:GetAttribute("TargetVolume")) or 1
end

-- How long a change to the mix takes: the layer on top can ask for a slower fade (the night
-- melts in and out instead of cutting).
local function fadeTime(): number
	local top = carrySound or trainingSound or phaseSound
	return (top and tonumber(top:GetAttribute("FadeSeconds"))) or Music.CrossfadeSeconds
end

local function fade(sound: Sound, volume: number, andThen: (() -> ())?)
	local tween = TweenService:Create(sound, TweenInfo.new(fadeTime()), { Volume = volume })
	if andThen then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				andThen()
			end
		end)
	end
	tween:Play()
end

-- The layer that should be heard right now (nil = the playlist).
local function topLayer(): Sound?
	return carrySound or trainingSound or phaseSound
end

-- Bring `sound` up (resuming where it paused) or take it down (pausing once silent).
local function bringUp(sound: Sound)
	if not sound.IsPlaying then
		if sound.TimePosition > 0 then
			sound:Resume()
		else
			sound:Play()
		end
	end
	fade(sound, targetOf(sound))
end

local function takeDown(sound: Sound)
	if sound.IsPlaying then
		fade(sound, 0, function()
			if topLayer() ~= sound and not (sound == current and topLayer() == nil) then
				sound:Pause()
			end
		end)
	end
end

local playNext

-- Applies the priority rule to every layer.
local function mix()
	local top = topLayer()
	for _, sound in { carrySound, trainingSound, phaseSound } do
		if sound and sound ~= top then
			takeDown(sound)
		end
	end
	if top then
		bringUp(top)
		if current then
			takeDown(current)
		end
	elseif current then
		bringUp(current)
	else
		playNext()
	end
end

local function shuffle()
	order = {}
	for i = 1, #playlist do
		table.insert(order, i)
	end
	if Music.Shuffle then
		for i = #order, 2, -1 do
			local j = math.random(1, i)
			order[i], order[j] = order[j], order[i]
		end
	end
	-- The very first lap of a session starts with Für Elise.
	if firstLap and Music.FirstTrack then
		firstLap = false
		for i, index in order do
			if playlist[index].Name == "Music_" .. Music.FirstTrack then
				table.remove(order, i)
				table.insert(order, 1, index)
				break
			end
		end
	end
	position = 0
end

local function markFailed(sound: Sound, why: string)
	if not failed[sound] then
		failed[sound] = true
		warn(("[Music] skipping %s (%s): %s"):format(sound.Name, sound.SoundId, why))
	end
end

playNext = function()
	if #playlist == 0 or topLayer() then
		return
	end
	-- Find the next track that hasn't failed (at most one full lap).
	local sound: Sound? = nil
	for _ = 1, #playlist do
		position += 1
		if position > #order then
			shuffle()
			position = 1
		end
		local candidate = playlist[order[position]]
		if not failed[candidate] then
			sound = candidate
			break
		end
	end
	if not sound then
		return -- every track failed to load
	end
	local previous = current
	current = sound
	local chosen = sound :: Sound
	-- Watchdog: a track that never starts (failed asset) is skipped.
	task.delay(LOAD_TIMEOUT, function()
		if current == chosen and not topLayer() and (not chosen.IsLoaded or chosen.TimeLength <= 0) then
			markFailed(chosen, "did not load in time")
			playNext()
		end
	end)
	if previous and previous ~= sound then
		fade(previous, 0, function()
			previous:Stop()
		end)
	end
	chosen.TimePosition = 0
	chosen:Play()
	fade(chosen, targetOf(chosen))
end

-- A layer's sound stops for good: fade it out and destroy it.
local function retire(sound: Sound?)
	if sound then
		fade(sound, 0, function()
			sound:Destroy()
		end)
	end
end

-- CARRY -------------------------------------------------------------------------------------

local function startCarry()
	local id = player:GetAttribute("CarryingId")
	local def = if type(id) == "string" then Treasures.Get(id) else nil
	local track = def and Music.CarryByRarity[def.Rarity]
	if not valid(track) then
		track = Music.CarryTheme
	end
	if not valid(track) then
		return -- no carry theme configured: keep the music going
	end
	retire(carrySound)
	carrySound = makeSound(track, true)
	mix()
end

local function stopCarry()
	if carrySound then
		retire(carrySound)
		carrySound = nil
		mix()
	end
end

local function playSting(track)
	if not valid(track) then
		return
	end
	local sound = makeSound(track, false)
	sound.Volume = track.Volume or 1
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
end

-- Called when the carry ends: extracted -> success, anything else -> fail.
local function carryEnded()
	task.delay(STING_WAIT, function()
		if holding then
			return -- picked something up again in the meantime
		end
		if os.clock() - lastExtracted <= STING_WAIT + 1 then
			playSting(Music.SuccessSting)
		else
			playSting(Music.FailSting)
		end
	end)
end

-- DAY / FINAL MINUTE / NIGHT ----------------------------------------------------------------

local function phaseAt(serverTime: number): string
	local state = DayNight.State(serverTime)
	if state.IsNight then
		return "Night"
	elseif state.SecondsLeft <= (Music.FinalMinuteSeconds or 60) then
		return "FinalMinute"
	end
	return "Day"
end

local function setPhase(newPhase: string)
	if newPhase == phase then
		return
	end
	local wasCue = phaseSound ~= nil
	phase = newPhase
	retire(phaseSound)
	phaseSound = nil
	local track = if newPhase == "Night" then Music.Night elseif newPhase == "FinalMinute" then Music.FinalMinute else nil
	if valid(track) then
		local sound = makeSound(track, true)
		-- Enter the cue where the phase actually is (joining mid-phase starts mid-track).
		local state = DayNight.State(workspace:GetServerTimeNow())
		local length = if newPhase == "Night" then GameConfig.DayNight.NightSeconds else (Music.FinalMinuteSeconds or 60)
		sound.TimePosition = math.max(0, length - state.SecondsLeft) + (track.StartAt or 0)
		phaseSound = sound
	elseif newPhase == "Day" and wasCue and current then
		-- Dawn after the night: a fresh playlist track rather than resuming the old one.
		current:Stop()
		current = nil
	end
	mix()
end

-- TRAINING ----------------------------------------------------------------------------------

local function setTraining(active: boolean)
	if active and not trainingSound and valid(Music.Training) then
		trainingSound = makeSound(Music.Training, true)
		mix()
	elseif not active and trainingSound then
		retire(trainingSound)
		trainingSound = nil
		mix()
	end
end

-- MUTE --------------------------------------------------------------------------------------

local function applyMute()
	group.Volume = if muted then 0 else Music.Volume
	player:SetAttribute("MusicMuted", muted)
end

function MusicController.IsMuted(): boolean
	return muted
end

function MusicController.ToggleMute()
	muted = not muted
	applyMute()
	Net.Get("SetSetting"):FireServer("Music", not muted)
end

function MusicController.Init()
	group = Instance.new("SoundGroup")
	group.Name = "Music"
	group.Parent = SoundService
	applyMute()

	for _, track in Music.Playlist do
		if valid(track) then
			local sound = makeSound(track, false, Music.PlaylistVolume * (track.Volume or 1))
			sound.Ended:Connect(function()
				if current == sound then
					playNext()
				end
			end)
			table.insert(playlist, sound)
		end
	end
	shuffle()
	-- Preload everything: rejected / missing assets are flagged before their turn comes.
	task.spawn(function()
		local all: { Instance } = {}
		for _, sound in playlist do
			table.insert(all, sound)
		end
		ContentProvider:PreloadAsync(all, function(contentId, status)
			if status == Enum.AssetFetchStatus.Failure then
				for _, sound in playlist do
					if sound.SoundId == contentId then
						markFailed(sound, "asset failed to load")
						if current == sound and not topLayer() then
							playNext()
						end
					end
				end
			end
		end)
	end)

	-- Saved preference arrives with the first data sync.
	local function syncSetting(data)
		local settings = data and data.Settings
		if settings and type(settings.Music) == "boolean" and muted == settings.Music then
			muted = not settings.Music
			applyMute()
		end
	end
	ClientState.DataChanged:Connect(syncSetting)
	syncSetting(ClientState.Data)

	player:GetAttributeChangedSignal("CarryingId"):Connect(function()
		local id = player:GetAttribute("CarryingId")
		if type(id) == "string" and id ~= "" then
			holding = true
			startCarry()
		else
			stopCarry()
			if holding then
				holding = false
				carryEnded()
			end
		end
	end)
	Net.Get("Feedback").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and payload.Type == "Extracted" then
			lastExtracted = os.clock()
		end
	end)
	Net.Get("TrainingState").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" then
			setTraining(payload.Active == true)
		end
	end)

	playNext()
	task.spawn(function()
		while true do
			setPhase(phaseAt(workspace:GetServerTimeNow()))
			task.wait(0.5)
		end
	end)
end

return MusicController
