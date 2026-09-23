-- Verifies the Rojo-built place has the expected script tree. Run after `rojo build`:
--   lune run tests/place build/game.rbxl
local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")

local path = process.args[1] or "build/game.rbxl"
local game = roblox.deserializePlace(fs.readFile(path))

local failures = 0
local function expect(instancePath: { string }, className: string)
	local current = game
	for _, name in instancePath do
		current = current and current:FindFirstChild(name)
	end
	local label = table.concat(instancePath, ".")
	if not current then
		failures += 1
		print("MISSING " .. label)
	elseif current.ClassName ~= className then
		failures += 1
		print(("WRONG CLASS %s: %s (expected %s)"):format(label, current.ClassName, className))
	end
end

expect({ "ServerScriptService", "Server", "Main" }, "Script")
expect({ "ServerScriptService", "Server", "WorldBuilder" }, "ModuleScript")
expect({ "ServerScriptService", "Server", "Services", "TreasureService" }, "ModuleScript")
expect({ "StarterPlayer", "StarterPlayerScripts", "Client", "Main" }, "LocalScript")
expect({ "StarterPlayer", "StarterPlayerScripts", "Client", "Controllers", "HUD" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Net" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Config", "GameConfig" }, "ModuleScript")
expect({ "ReplicatedStorage", "Shared", "Logic", "Carry" }, "ModuleScript")

local modules = 0
for _, d in game:GetDescendants() do
	if d:IsA("LuaSourceContainer") then
		modules += 1
	end
end
print(("%d scripts in place, %d problems"):format(modules, failures))
if failures > 0 then
	error("place structure check failed")
end
