--[[
	LuckService
	Calculates each player's total (additive) Luck (see Shared > GameMath.ComputeLuck) and
	refreshes the UI when boosts expire or events start/end.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameMath = require(Shared.GameMath)

local LuckService = {}

local services
local lastTotal: { [Player]: number } = {}

function LuckService:GetLuck(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return { Total = 1, Points = 0, Permanent = 0, Parts = {}, ShopLuck = 0, BoostBonus = 0, BoostEnds = 0, EventBonus = 0 }
	end
	return GameMath.ComputeLuck(data, os.time(), services.EventService:GetLuckBonus(), services.DevService:GetLuckBonus(player))
end

function LuckService:GetTotal(player: Player): number
	return self:GetLuck(player).Total
end

function LuckService:Init(allServices)
	services = allServices
end

function LuckService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastTotal[player] = nil
	end)
	while true do
		task.wait(2)
		for _, player in services.DataService:GetLoadedPlayers() do
			local total = self:GetTotal(player)
			if lastTotal[player] and math.abs(lastTotal[player] - total) > 1e-6 then
				services.StateService:Schedule(player)
			end
			lastTotal[player] = total
		end
	end
end

return LuckService
