-- Treasure lying in the world (or dropped) slowly spins and bobs, so it catches the eye and the
-- rarity flair (orbiting gems, coins, rings) actually orbits. Rarer = livelier. Local and
-- purely visual: only anchored treasure is moved, and only near the camera.
-- Also: the camera starts further out on your first spawn - there's a lot to see.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Rarities = require(ReplicatedStorage.Shared.Config.Rarities)

local TreasureMotion = {}

local player = Players.LocalPlayer
local ANIMATE_DISTANCE = 220
local START_ZOOM = 26 -- studs: the camera distance you start the game with

type Motion = { Base: CFrame, Phase: number, Spin: number, Bob: number }
local moving: { [Model]: Motion } = {}

local function track(model: Instance)
	if not model:IsA("Model") then
		return
	end
	local function refresh()
		local handle = model.PrimaryPart
		local state = model:GetAttribute("State")
		if handle and handle.Anchored and (state == "World" or state == "Dropped") then
			local rank = Rarities.Rank(tostring(model:GetAttribute("Rarity")))
			moving[model] = {
				Base = handle.CFrame,
				Phase = math.random() * math.pi * 2,
				Spin = 0.5 + rank * 0.09,
				Bob = 0.25 + rank * 0.07,
			}
		else
			moving[model] = nil
		end
	end
	model:GetAttributeChangedSignal("State"):Connect(function()
		moving[model] = nil
		task.defer(refresh) -- let the server's new position land first
	end)
	refresh()
end

local function startZoomedOut()
	local function apply()
		local minimum = player.CameraMinZoomDistance
		player.CameraMinZoomDistance = math.min(START_ZOOM, player.CameraMaxZoomDistance)
		task.delay(0.5, function()
			player.CameraMinZoomDistance = minimum -- free to zoom in again
		end)
	end
	if player.Character then
		task.defer(apply)
	else
		local connection
		connection = player.CharacterAdded:Connect(function()
			connection:Disconnect()
			task.wait(0.2)
			apply()
		end)
	end
end

function TreasureMotion.Init()
	startZoomedOut()
	task.spawn(function()
		local folder = workspace:WaitForChild("Treasures")
		for _, model in folder:GetChildren() do
			track(model)
		end
		folder.ChildAdded:Connect(function(model)
			task.defer(track, model)
		end)
		folder.ChildRemoved:Connect(function(model)
			moving[model :: Model] = nil
		end)
	end)
	RunService.RenderStepped:Connect(function()
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local t = os.clock()
		for model, motion in moving do
			local handle = model.PrimaryPart
			if not handle or not handle.Anchored then
				moving[model] = nil
				continue
			end
			if (motion.Base.Position - eye).Magnitude < ANIMATE_DISTANCE then
				local lift = (math.sin(t * 1.8 + motion.Phase) + 1) * 0.5 * motion.Bob
				handle.CFrame = motion.Base * CFrame.new(0, lift, 0) * CFrame.Angles(0, t * motion.Spin + motion.Phase, 0)
			end
		end
	end)
end

return TreasureMotion
