-- Cinematic background music (config: Shared/Config/Music).
--   * The playlist rolls in the background (shuffled, looping), crossfading between tracks.
--   * Pick up a treasure -> the playlist pauses (fading out) and the carry theme starts from the
--     top; drop / extract / lose it -> the carry theme fades out and the playlist fades back in
--     exactly where it paused.
--   * Muting (HUD 🔊 button) is saved per player (data.Settings.Music).
-- Tracks with empty ids are ignored, so nothing plays until real asset ids are configured.

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
local order: { number } = {}
local position = 0
local current: Sound? = nil
local carrySound: Sound? = nil
local carrying = false
local muted = false

local function valid(track): boolean
	return type(track) == "table" and type(track.Id) == "string" and track.Id ~= ""
end

local function makeSound(track, looped: boolean): Sound
	local sound = Instance.new("Sound")
	sound.Name = "Music_" .. tostring(track.Name or "Track")
	sound.SoundId = track.Id
	sound.Looped = looped
	sound.Volume = 0
	sound.SoundGroup = group
	sound.Parent = SoundService
	return sound
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

local function playNext()
	if #playlist == 0 or carrying then
		return
	end
	position += 1
	if position > #order then
		shuffle()
		position = 1
	end
	local previous = current
	current = playlist[order[position]]
	local sound = current :: Sound
	if previous and previous ~= sound then
		fade(previous, 0, function()
			previous:Stop()
		end)
	end
	sound.TimePosition = 0
	sound:Play()
	fade(sound, 1)
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
	fade(sound, 1)
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
		fade(current, 1)
	else
		playNext()
	end
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
			local sound = makeSound(track, false)
			sound.Ended:Connect(playNext)
			table.insert(playlist, sound)
		end
	end
	shuffle()

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
			startCarry()
		else
			stopCarry()
		end
	end)

	playNext()
end

return MusicController
