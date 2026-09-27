-- Little models of every gadget: on the shop shelves (WorldBuilder), on the Ascension Shop's
-- plinths, and in your HAND when you hold one (GadgetService). Each builder puts a few parts,
-- standing on `at` (about 1-1.5 studs tall), into folder/model `f`.

local Props = require(script.Parent.Props)

local part, cylinder = Props.part, Props.cylinder

local GadgetModels = {}

GadgetModels.Minis = {
	speed_soda = function(at: CFrame, f: Folder)
		cylinder((at * CFrame.new(0, 0.6, 0)).Position, 1.2, 0.7, { Name = "MiniSoda", Color = Color3.fromRGB(230, 60, 70), Material = Enum.Material.Metal, Parent = f })
		cylinder((at * CFrame.new(0, 1.28, 0)).Position, 0.16, 0.6, { Name = "MiniSodaCap", Color = Color3.fromRGB(210, 210, 220), Material = Enum.Material.Metal, Parent = f })
	end,
	balloon = function(at: CFrame, f: Folder)
		part({ Name = "MiniBalloon", Shape = Enum.PartType.Ball, Size = Vector3.new(1.1, 1.1, 1.1), CFrame = at * CFrame.new(0, 1.6, 0), Color = Color3.fromRGB(235, 50, 70), Material = Enum.Material.SmoothPlastic, Parent = f })
		part({ Name = "MiniString", Size = Vector3.new(0.05, 1, 0.05), CFrame = at * CFrame.new(0, 0.55, 0), Color = Color3.new(1, 1, 1), Parent = f })
	end,
	bubble_blaster = function(at: CFrame, f: Folder)
		part({ Name = "MiniBlaster", Size = Vector3.new(1.3, 0.5, 0.45), CFrame = at * CFrame.new(0, 0.7, 0), Color = Color3.fromRGB(70, 150, 255), Material = Enum.Material.SmoothPlastic, Parent = f })
		part({ Name = "MiniBlasterGrip", Size = Vector3.new(0.3, 0.6, 0.35), CFrame = at * CFrame.new(-0.3, 0.3, 0), Color = Color3.fromRGB(40, 40, 60), Parent = f })
		part({ Name = "MiniBubble", Shape = Enum.PartType.Ball, Size = Vector3.new(0.45, 0.45, 0.45), CFrame = at * CFrame.new(0.9, 1.1, 0), Color = Color3.fromRGB(170, 230, 255), Material = Enum.Material.Glass, Transparency = 0.4, Parent = f })
	end,
	grapple_hook = function(at: CFrame, f: Folder)
		part({ Name = "MiniGrappleShaft", Size = Vector3.new(0.18, 1.2, 0.18), CFrame = at * CFrame.new(0, 0.7, 0), Color = Color3.fromRGB(120, 120, 130), Material = Enum.Material.Metal, Parent = f })
		for _, sx in { -1, 1 } do
			part({ Name = "MiniGrappleClaw", Size = Vector3.new(0.14, 0.5, 0.14), CFrame = at * CFrame.new(sx * 0.2, 1.35, 0) * CFrame.Angles(0, 0, math.rad(sx * -35)), Color = Color3.fromRGB(200, 200, 210), Material = Enum.Material.Metal, Parent = f })
		end
	end,
	disguise = function(at: CFrame, f: Folder)
		part({ Name = "MiniBush", Shape = Enum.PartType.Ball, Size = Vector3.new(1.3, 1.1, 1.3), CFrame = at * CFrame.new(0, 0.6, 0), Color = Color3.fromRGB(70, 150, 60), Material = Enum.Material.Grass, Parent = f })
		part({ Name = "MiniBushEyes", Size = Vector3.new(0.5, 0.12, 0.05), CFrame = at * CFrame.new(0, 0.75, -0.62), Color = Color3.new(1, 1, 1), Material = Enum.Material.Neon, Parent = f })
	end,
	bee_box = function(at: CFrame, f: Folder)
		part({ Name = "MiniBeeBox", Size = Vector3.new(1, 0.9, 0.9), CFrame = at * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(240, 190, 40), Material = Enum.Material.WoodPlanks, Parent = f })
		for _, y in { 0.25, 0.65 } do
			part({ Name = "MiniBeeStripe", Size = Vector3.new(1.02, 0.12, 0.92), CFrame = at * CFrame.new(0, y, 0), Color = Color3.fromRGB(40, 30, 20), Parent = f })
		end
	end,
	boomerang = function(at: CFrame, f: Folder)
		for _, sx in { -1, 1 } do
			part({ Name = "MiniBoomerang", Size = Vector3.new(0.9, 0.12, 0.28), CFrame = at * CFrame.new(sx * 0.3, 0.8, 0) * CFrame.Angles(0, 0, math.rad(sx * 30)), Color = Color3.fromRGB(190, 110, 255), Material = Enum.Material.SmoothPlastic, Parent = f })
		end
	end,
	bear_trap = function(at: CFrame, f: Folder)
		part({ Name = "MiniTrapPlate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, 1.3, 1.3), CFrame = at * CFrame.new(0, 0.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(90, 88, 84), Material = Enum.Material.Metal, Parent = f })
		for _, sz in { -1, 1 } do
			part({ Name = "MiniTrapJaw", Size = Vector3.new(1.2, 0.1, 0.35), CFrame = at * CFrame.new(0, 0.3, sz * 0.4) * CFrame.Angles(math.rad(sz * 55), 0, 0), Color = Color3.fromRGB(180, 175, 170), Material = Enum.Material.Metal, Parent = f })
		end
	end,
	auto_cannon = function(at: CFrame, f: Folder)
		part({ Name = "MiniCannonBase", Size = Vector3.new(1.1, 0.35, 1.1), CFrame = at * CFrame.new(0, 0.2, 0), Color = Color3.fromRGB(110, 72, 42), Material = Enum.Material.WoodPlanks, Parent = f })
		part({ Name = "MiniCannonBarrel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.3, 0.55, 0.55), CFrame = at * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, math.rad(90), math.rad(20)), Color = Color3.fromRGB(45, 45, 52), Material = Enum.Material.Metal, Parent = f })
	end,
	freeze_ray = function(at: CFrame, f: Folder)
		part({ Name = "MiniRay", Size = Vector3.new(0.45, 0.45, 1.3), CFrame = at * CFrame.new(0, 0.8, 0), Color = Color3.fromRGB(200, 230, 255), Material = Enum.Material.Metal, Parent = f })
		part({ Name = "MiniRayTip", Shape = Enum.PartType.Ball, Size = Vector3.new(0.5, 0.5, 0.5), CFrame = at * CFrame.new(0, 0.8, -0.75), Color = Color3.fromRGB(120, 220, 255), Material = Enum.Material.Neon, Parent = f })
		part({ Name = "MiniRayGrip", Size = Vector3.new(0.25, 0.6, 0.3), CFrame = at * CFrame.new(0, 0.35, 0.3), Color = Color3.fromRGB(40, 50, 70), Parent = f })
	end,
	tornado = function(at: CFrame, f: Folder)
		for i = 0, 3 do
			local w = 0.4 + i * 0.3
			part({ Name = "MiniTwister", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, w, w), CFrame = at * CFrame.new(0, 0.25 + i * 0.4, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(190, 195, 205), Transparency = 0.2, Parent = f })
		end
	end,
	thunder_totem = function(at: CFrame, f: Folder)
		part({ Name = "MiniTotem", Size = Vector3.new(0.4, 1.3, 0.4), CFrame = at * CFrame.new(0, 0.65, 0), Color = Color3.fromRGB(70, 60, 90), Material = Enum.Material.Slate, Parent = f })
		part({ Name = "MiniTotemOrb", Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), CFrame = at * CFrame.new(0, 1.5, 0), Color = Color3.fromRGB(255, 240, 120), Material = Enum.Material.Neon, Parent = f })
	end,
	decoy_duck = function(at: CFrame, f: Folder)
		part({ Name = "MiniDuck", Shape = Enum.PartType.Ball, Size = Vector3.new(1, 0.8, 1.2), CFrame = at * CFrame.new(0, 0.45, 0), Color = Color3.fromRGB(255, 220, 60), Parent = f })
		part({ Name = "MiniDuckHead", Shape = Enum.PartType.Ball, Size = Vector3.new(0.55, 0.55, 0.55), CFrame = at * CFrame.new(0, 0.95, -0.35), Color = Color3.fromRGB(255, 220, 60), Parent = f })
		part({ Name = "MiniDuckBeak", Size = Vector3.new(0.3, 0.12, 0.3), CFrame = at * CFrame.new(0, 0.9, -0.68), Color = Color3.fromRGB(255, 140, 40), Parent = f })
	end,
}

-- Builds gadget `id` standing on `at` into `parent`. Returns false if there's no model.
function GadgetModels.Build(id: string, at: CFrame, parent: Instance): boolean
	local builder = GadgetModels.Minis[id]
	if not builder then
		return false
	end
	builder(at, parent :: any)
	return true
end

return GadgetModels
