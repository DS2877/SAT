-- Syntax check: compiles every Luau source file under src/. Run with: lune run tests/compile
local fs = require("@lune/fs")
local luau = require("@lune/luau")

local failures = 0
local count = 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif name:match("%.luau$") then
			count += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failures += 1
				print("FAIL " .. path .. "\n  " .. tostring(err))
			end
		end
	end
end

walk("src")
print(("%d files compiled, %d failed"):format(count, failures))
if failures > 0 then
	error("compile failed")
end
