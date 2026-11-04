--[[
	LevelService
	XP and levels (the only level system in the game). Level-ups give cash and, every 5 levels,
	a free Luck boost.

	One "LevelUp" message is sent per XP gain, even when it crosses several levels at once:
	  { From, Level, Cash, Boosts = { { Id, Duration } }, Unlocks = { { Kind, Text } } }
	Unlocks lists only what became AVAILABLE between From and Level (equipment, beaches, shop
	upgrades, themes, new treasures). Nothing is bought or equipped for the player. The client
	shows the compact level-up notice first, then the unlock lines (NotifyController).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Progression = require(Shared.Config.Progression)
local GameMath = require(Shared.GameMath)

local LevelService = {}

local services
local levelUpRemote: RemoteEvent

function LevelService:AddXP(player: Player, amount: number)
	local data = services.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	amount = math.floor(amount + 0.5)
	data.XP += amount
	services.QuestService:Progress(player, "EarnXP", amount)

	local fromLevel = data.Level
	local totalCash = 0
	local boosts = {}
	while data.Level < Progression.MaxLevel and data.XP >= Progression.XPForLevel(data.Level) do
		data.XP -= Progression.XPForLevel(data.Level)
		data.Level += 1

		local cash = Progression.LevelUpCash(data.Level)
		totalCash += cash
		services.InventoryService:AddCash(player, cash, false)
		local boostId, duration = Progression.LevelUpBoost(data.Level)
		if boostId and duration then
			services.EquipmentShopService:GrantBoost(player, boostId, duration, true) -- shown in the level-up notice
			table.insert(boosts, { Id = boostId, Duration = duration })
		end
	end
	local leveled = data.Level > fromLevel
	if leveled then
		levelUpRemote:FireClient(player, {
			From = fromLevel,
			Level = data.Level,
			Cash = totalCash,
			Boosts = boosts,
			Unlocks = GameMath.NewlyAvailable(fromLevel, data.Level, data),
		})
	end
	if data.Level >= Progression.MaxLevel then
		data.XP = math.min(data.XP, Progression.XPForLevel(data.Level))
	end

	if leveled then
		services.LeaderboardService:UpdateLeaderstats(player)
		services.AchievementService:Check(player)
	end
	services.DataService:MarkDirty(player)
end

-- Developer tools: jump straight to a level (no cash/boost rewards). XP restarts at 0 for that
-- level; beaches, shop items and the progression UI follow automatically from the new level.
function LevelService:SetLevel(player: Player, level: number)
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local fromLevel = data.Level
	data.Level = math.clamp(math.floor(level), 1, Progression.MaxLevel)
	data.XP = 0
	if data.Level > fromLevel then
		levelUpRemote:FireClient(player, {
			From = fromLevel,
			Level = data.Level,
			Cash = 0,
			Boosts = {},
			Unlocks = GameMath.NewlyAvailable(fromLevel, data.Level, data),
		})
	end
	services.LeaderboardService:UpdateLeaderstats(player)
	services.AchievementService:Check(player)
	services.DataService:MarkDirty(player)
end

function LevelService:Init(allServices)
	services = allServices
	levelUpRemote = Net.Event("LevelUp")
end

return LevelService
