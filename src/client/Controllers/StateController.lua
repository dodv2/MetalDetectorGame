--[[
	StateController
	Holds the latest copy of this player's state (sent by the server) and helps call remotes.

	State.Data                -> latest snapshot (nil until loaded)
	State:OnChange(fn)        -> fn(data) now and on every update
	State:Call("SellItem", id) -> server result; shows the error as a toast automatically
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Signal = require(Shared.Signal)

local State = {}
State.Data = nil :: any
State.Changed = Signal.new()

local controllers

function State:Set(view)
	self.Data = view
	self.Changed:Fire(view)
end

function State:OnChange(fn: (any) -> ())
	if self.Data then
		task.spawn(fn, self.Data)
	end
	return self.Changed:Connect(fn)
end

function State:Call(remoteName: string, ...: any): any
	local remote = Net.Function(remoteName)
	local ok, result = pcall(remote.InvokeServer, remote, ...)
	if not ok then
		result = { Ok = false, Error = "Couldn't reach the server. Try again." }
	end
	if type(result) ~= "table" then
		result = { Ok = false }
	end
	if result.Ok == false and result.Error and not result.RateLimited then
		controllers.Notify:Toast(result.Error, "Error")
		controllers.Sound:Play("Error")
	end
	return result
end

-- Unix time synced with the server (for boost / event countdowns)
function State:Now(): number
	return Workspace:GetServerTimeNow()
end

function State:Init(all)
	controllers = all
	Net.Event("StateUpdate").OnClientEvent:Connect(function(view)
		self:Set(view)
	end)
end

function State:Start()
	for _ = 1, 30 do
		local ok, result = pcall(function()
			return Net.Function("GetState"):InvokeServer()
		end)
		if ok and type(result) == "table" and result.Ok then
			self:Set(result.State)
			return
		end
		task.wait(1)
	end
end

return State
