-- Creates the remotes and provides a throttled notification helper.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local folder = Instance.new("Folder")
folder.Name = "Remotes"
folder.Parent = ReplicatedStorage

local function make(class, name)
	local remote = Instance.new(class)
	remote.Name = name
	remote.Parent = folder
	Remotes[name] = remote
end

make("RemoteFunction", "Buy")
make("RemoteFunction", "Teleport")
make("RemoteEvent", "Pop")
make("RemoteEvent", "Notify")
make("RemoteEvent", "OpenTab")
make("RemoteEvent", "Hatch")

local notifyEvent = Remotes.Notify

local lastNotice = {} -- [player] = { [key] = os.clock() }

function Remotes.Notify(player, text, kind, throttleKey)
	if throttleKey then
		lastNotice[player] = lastNotice[player] or {}
		local last = lastNotice[player][throttleKey]
		if last and os.clock() - last < 4 then
			return
		end
		lastNotice[player][throttleKey] = os.clock()
	end
	notifyEvent:FireClient(player, text, kind or "info")
end

function Remotes.Forget(player)
	lastNotice[player] = nil
end

return Remotes
