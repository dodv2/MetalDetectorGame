--[[
	Net
	Finds RemoteEvents / RemoteFunctions inside ReplicatedStorage.Remotes.
	Every remote used by the game is listed in ReplicatedStorage > Remotes in the Explorer.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = {}

local folder = ReplicatedStorage:WaitForChild("Remotes")

function Net.Event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
