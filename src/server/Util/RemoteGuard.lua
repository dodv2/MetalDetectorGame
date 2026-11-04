--[[
	RemoteGuard
	Safe wrapper for RemoteFunctions:
	  * per-player cooldown (stops spamming)
	  * pcall so a bug never breaks the client
	  * every handler returns { Ok = true, ... } or { Ok = false, Error = "message" }
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local RemoteGuard = {}

local lastCall: { [Player]: { [string]: number } } = {}

function RemoteGuard.Allow(player: Player, key: string, cooldown: number): boolean
	local now = os.clock()
	local calls = lastCall[player]
	if not calls then
		calls = {}
		lastCall[player] = calls
	end
	local last = calls[key]
	if last and now - last < cooldown then
		return false
	end
	calls[key] = now
	return true
end

function RemoteGuard.Handle(name: string, cooldown: number, handler: (Player, ...any) -> any)
	local remote = Net.Function(name)
	remote.OnServerInvoke = function(player: Player, ...)
		if not RemoteGuard.Allow(player, name, cooldown) then
			return { Ok = false, Error = "Slow down a little!", RateLimited = true }
		end
		local ok, result = pcall(handler, player, ...)
		if not ok then
			warn(("[Remote %s] error for %s: %s"):format(name, player.Name, tostring(result)))
			return { Ok = false, Error = "Something went wrong. Try again." }
		end
		return result
	end
end

-- Type helpers for validating client input
function RemoteGuard.IsString(value: any, maxLength: number?): boolean
	return type(value) == "string" and #value > 0 and #value <= (maxLength or 64)
end

function RemoteGuard.IsInteger(value: any, min: number?, max: number?): boolean
	return type(value) == "number" and value == value and value % 1 == 0
		and value >= (min or -math.huge) and value <= (max or math.huge)
end

Players.PlayerRemoving:Connect(function(player)
	lastCall[player] = nil
end)

return RemoteGuard
