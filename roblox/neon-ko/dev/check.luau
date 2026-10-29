-- Lune-Skript: kompiliert alle Luau-Dateien (Syntaxprüfung) und zeigt die Struktur der gebauten Modelle.
-- Aufruf aus roblox/neon-ko:  lune run dev/check.luau
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")
local process = require("@lune/process")

local failures = 0
local files = 0

local function walk(dir: string)
	for _, name in fs.readDir(dir) do
		local path = dir .. "/" .. name
		if fs.isDir(path) then
			walk(path)
		elseif string.match(name, "%.luau$") then
			files += 1
			local ok, err = pcall(luau.compile, fs.readFile(path))
			if not ok then
				failures += 1
				print("SYNTAXFEHLER", path, err)
			end
		end
	end
end

for _, dir in { "src", "studio-tools", "tests" } do
	if fs.isDir(dir) then
		walk(dir)
	end
end
print(("Kompiliert: %d Dateien, Fehler: %d"):format(files, failures))

local function dump(instance, depth: number)
	print(string.rep("  ", depth) .. instance.Name .. " (" .. instance.ClassName .. ")")
	for _, child in instance:GetChildren() do
		dump(child, depth + 1)
	end
end

if fs.isDir("build") then
	for _, name in fs.readDir("build") do
		if string.match(name, "%.rbxm$") then
			print("== build/" .. name)
			for _, root in roblox.deserializeModel(fs.readFile("build/" .. name)) do
				dump(root, 1)
			end
		end
	end
end

if failures > 0 then
	process.exit(1)
end
