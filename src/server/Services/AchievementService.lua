--[[
	AchievementService
	Checks achievements (Config > Achievements) whenever stats change and hands out rewards.
	Calls are batched: :Check(player) can be called as often as you like.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Achievements = require(Shared.Config.Achievements)
local Equipment = require(Shared.Config.Equipment)
local GameMath = require(Shared.GameMath)
local Format = require(Shared.Format)

local AchievementService = {}

local services
local pending: { [Player]: boolean } = {}

function AchievementService.GetStat(data, stat: string): number
	return GameMath.AchievementStat(data, stat)
end

function AchievementService:RunCheck(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	for _, def in Achievements.List do
		if not data.Achievements[def.Id] and AchievementService.GetStat(data, def.Stat) >= def.Goal then
			data.Achievements[def.Id] = true
			local rewardText = {}
			local reward = def.Reward or {}
			if reward.Cash then
				services.InventoryService:AddCash(player, reward.Cash, false)
				table.insert(rewardText, Format.Cash(reward.Cash))
			end
			if reward.Trinket then
				data.Trinkets[reward.Trinket] = true
				local trinket = Equipment.ById.Trinket[reward.Trinket]
				table.insert(rewardText, "Trinket: " .. (if trinket then trinket.Name .. " (" .. Format.Luck(trinket.Luck) .. ")" else reward.Trinket))
			end
			services.StateService:Notify(player, "🏆 Achievement: " .. def.Name .. (if #rewardText > 0 then "  (" .. table.concat(rewardText, ", ") .. ")" else ""), "Rare")
			if reward.XP then
				services.LevelService:AddXP(player, reward.XP) -- may re-trigger Check; that's fine (batched)
			end
		end
	end
	services.DataService:MarkDirty(player)
end

function AchievementService:Check(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.25, function()
		pending[player] = nil
		if player.Parent then
			self:RunCheck(player)
		end
	end)
end

function AchievementService:Init(allServices)
	services = allServices
end

function AchievementService:Start()
	services.DataService.ProfileLoaded:Connect(function(player)
		self:Check(player)
	end)
end

return AchievementService
