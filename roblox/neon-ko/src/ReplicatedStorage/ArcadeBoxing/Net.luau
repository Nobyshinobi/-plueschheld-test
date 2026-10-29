-- Remote-Namen und Zugriff. Der Server legt die Remotes an; Clients warten darauf.
-- RemoteEvents transportieren nur Anfragen (Client→Server) und Rückmeldungen (Server→Client).

local RunService = game:GetService("RunService")

local Net = {}

Net.FolderName = "Remotes"
Net.Request = "Request" -- Client → Server: (kind: string, a: any?, b: any?)
Net.Event = "Event" -- Server → Client: (kind: string, payload: table)

-- Erlaubte Anfragearten und Aktionen (Server prüft jede Anfrage gegen diese Listen).
Net.RequestKinds = {
	SelectOpponent = true,
	CancelSelect = true,
	Action = true,
	SkipIntro = true,
	Leave = true,
	LeaveQueue = true,
}

Net.Actions = {
	Light = true,
	Heavy = true,
	Special = true,
	Dodge = true,
	BlockStart = true,
	BlockEnd = true,
}

local function folder(): Instance
	return script.Parent
end

function Net.serverSetup(): (RemoteEvent, RemoteEvent)
	assert(RunService:IsServer(), "Net.serverSetup nur auf dem Server")
	local root = folder()
	local remotes = root:FindFirstChild(Net.FolderName)
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = Net.FolderName
		remotes.Parent = root
	end
	local function ensure(name: string): RemoteEvent
		local existing = remotes:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local remote = Instance.new("RemoteEvent")
		remote.Name = name
		remote.Parent = remotes
		return remote
	end
	return ensure(Net.Request), ensure(Net.Event)
end

-- Liefert nil, wenn der Server-Teil nicht installiert ist (Client beendet sich dann still mit Warnung).
function Net.clientGet(timeout: number?): (RemoteEvent?, RemoteEvent?)
	local remotes = folder():WaitForChild(Net.FolderName, timeout or 30)
	if not remotes then
		return nil, nil
	end
	local request = remotes:WaitForChild(Net.Request, 10)
	local event = remotes:WaitForChild(Net.Event, 10)
	if request and event and request:IsA("RemoteEvent") and event:IsA("RemoteEvent") then
		return request, event
	end
	return nil, nil
end

return Net
