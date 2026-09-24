-- Cinematic background music (config: Shared/Config/Music).
--   * The playlist rolls in the background (shuffled, looping), crossfading between tracks.
--   * Pick up a treasure -> the playlist pauses (fading out) and the carry theme starts from the
--     top; drop / extract / lose it -> the carry theme fades out and the playlist fades back in
--     exactly where it paused.
--   * When the carry ends, a short sting says how it went: SuccessSting when you extracted it,
--     FailSting when you dropped it, got knocked, had it stolen or lost it at nightfall.
--   * Muting (HUD 🔊 button) is saved per player (data.Settings.Music).
-- Tracks with empty ids are ignored. A track that fails to load (moderation-rejected, deleted,
-- no permission) is skipped instead of silencing the playlist forever, and a warning names it
-- in the developer console (F9).

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage.Shared
local Music = require(Shared.Config.Music)
local Treasures = require(Shared.Config.Treasures)
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
local current: Sound? = nil
local carrySound: Sound? = nil
local carrying = false
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
	if track.StartAt then
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

local function fade(sound: Sound, volume: number, andThen: (() -> ())?)
	local tween = TweenService:Create(sound, TweenInfo.new(Music.CrossfadeSeconds), { Volume = volume })
	if andThen then
		tween.Completed:Once(function(state)
			if state == Enum.PlaybackState.Completed then
				andThen()
			end
		end)
	end
	tween:Play()
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
	position = 0
end

local playNext

local function markFailed(sound: Sound, why: string)
	if not failed[sound] then
		failed[sound] = true
		warn(("[Music] skipping %s (%s): %s"):format(sound.Name, sound.SoundId, why))
	end
end

playNext = function()
	if #playlist == 0 or carrying then
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
		if current == chosen and not carrying and (not chosen.IsLoaded or chosen.TimeLength <= 0) then
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

local function startCarry()
	local id = player:GetAttribute("CarryingId")
	local def = if type(id) == "string" then Treasures.Get(id) else nil
	local track = def and Music.CarryByRarity[def.Rarity]
	if not valid(track) then
		track = Music.CarryTheme
	end
	if not valid(track) then
		return -- no carry theme configured: keep the playlist going
	end
	carrying = true
	if current and current.IsPlaying then
		local paused = current
		fade(paused, 0, function()
			if carrying then
				paused:Pause() -- keeps TimePosition for the resume
			end
		end)
	end
	if carrySound then
		carrySound:Destroy()
	end
	local sound = makeSound(track, true)
	carrySound = sound
	sound:Play()
	fade(sound, targetOf(sound))
end

local function stopCarry()
	if not carrying then
		return
	end
	carrying = false
	local sound = carrySound
	carrySound = nil
	if sound then
		fade(sound, 0, function()
			sound:Destroy()
		end)
	end
	if current then
		if not current.IsPlaying then
			current:Resume()
		end
		fade(current, targetOf(current))
	else
		playNext()
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
			sound.Ended:Connect(playNext)
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
						if current == sound and not carrying then
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

	playNext()
end

return MusicController
