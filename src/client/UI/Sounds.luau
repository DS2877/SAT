-- Audio hooks. Every gameplay moment routes through Sounds.Play(name) so final audio can be
-- swapped in one place. Placeholder ids use sounds bundled with the Roblox client.

local SoundService = game:GetService("SoundService")

local Sounds = {}

local LIBRARY = {
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Speed = 1.1 },
	Pickup = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7, Speed = 0.8 },
	Drop = { Id = "rbxasset://sounds/action_falling.mp3", Volume = 0.6, Speed = 1.3 },
	Swing = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.5, Speed = 1.2 },
	Hit = { Id = "rbxasset://sounds/swordslash.wav", Volume = 0.7, Speed = 0.9 },
	Shaken = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 0.5 },
	Knocked = { Id = "rbxasset://sounds/uuhhh.mp3", Volume = 0.7, Speed = 1.1 },
	ExtractStart = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.0 },
	ExtractTick = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.25, Speed = 1.6 },
	ExtractInterrupted = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.8, Speed = 0.7 },
	ExtractSuccess = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Speed = 1.4 },
	BigReward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 0.6 },
	RareDiscovery = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 1.8 },
	Ascend = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 0.4 },
	Event = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 0.7 },
	GuardianAlert = { Id = "rbxasset://sounds/unsheath.wav", Volume = 0.7, Speed = 0.8 },
	TrainPerfect = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.6, Speed = 1.6 },
	TrainGood = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.6, Speed = 1 },
	Rep = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.35, Speed = 1.5 },
	MegaRep = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 0.9 },
	GoldenRep = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 1, Speed = 0.5 },
	SetComplete = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.9, Speed = 1.25 },
	PumpMax = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8, Speed = 0.7 },
	HeavyStep = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.5, Speed = 0.7 },
	Heartbeat = { Id = "rbxasset://sounds/action_jump_land.mp3", Volume = 0.7, Speed = 0.45 },
	TrainMiss = { Id = "rbxasset://sounds/action_get_up.mp3", Volume = 0.4, Speed = 1.5 },
	Gadget = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 0.6, Speed = 1.3 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5, Speed = 0.6 },
	Splash = { Id = "rbxasset://sounds/impact_water.mp3", Volume = 0.5, Speed = 1 },
	Boost = { Id = "rbxasset://sounds/swordlunge.wav", Volume = 0.8, Speed = 0.7 },
	Launch = { Id = "rbxasset://sounds/action_jump.mp3", Volume = 1, Speed = 0.55 },
}

local cache: { [string]: Sound } = {}

-- speedScale shifts the pitch (e.g. rising pitch as the training pump builds).
function Sounds.Play(name: string, volumeScale: number?, speedScale: number?)
	local def = LIBRARY[name]
	if not def then
		return
	end
	local sound = cache[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = "SFX_" .. name
		sound.SoundId = def.Id
		sound.Volume = def.Volume
		sound.PlaybackSpeed = def.Speed
		sound.Parent = SoundService
		cache[name] = sound
	end
	(sound :: Sound).Volume = def.Volume * (volumeScale or 1);
	(sound :: Sound).PlaybackSpeed = def.Speed * (speedScale or 1)
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
	sound.PlaybackSpeed = def.Speed
	sound.RollOffMaxDistance = 120
	sound.Parent = attachment
	sound:Play()
	task.delay(3, function()
		attachment:Destroy()
	end)
end

return Sounds
