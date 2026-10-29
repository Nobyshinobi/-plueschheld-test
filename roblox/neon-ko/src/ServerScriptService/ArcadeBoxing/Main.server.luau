-- NEON K.O. – Server-Start. Legt Remotes an und startet den MatchService.
-- Deaktivieren/Rückbau: dieses Skript deaktivieren (Enabled = false) oder den Ordner
-- ServerScriptService.ArcadeBoxing entfernen – andere Parksysteme sind nicht betroffen.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("ArcadeBoxing")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local MatchService = require(script.Parent:WaitForChild("MatchService"))

local request, event = Net.serverSetup()
MatchService.init(request, event)

game:BindToClose(function()
	MatchService.shutdown()
end)

print(("[NEON K.O.] Server bereit (Version %s)"):format(Config.Version))
