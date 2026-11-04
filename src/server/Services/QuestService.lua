--[[
	QuestService
	Daily quests (3 per day, reset at midnight UTC). Progress is pushed in by other services:
	  services.QuestService:Progress(player, "Find", 1)
	  services.QuestService:Progress(player, "FindTier", 1, { Tier = 4 })
	  services.QuestService:Progress(player, "FindInZone", 1, { Zone = "RockyShore" })
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Quests = require(Shared.Config.Quests)
local Zones = require(Shared.Config.Zones)
local GameMath = require(Shared.GameMath)
local Format = require(Shared.Format)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local QuestService = {}

local services

local function today(): number
	return os.time() // 86400
end

local function weightedPick(rng: Random, list)
	local total = 0
	for _, entry in list do
		total += entry.Weight
	end
	local roll = rng:NextNumber() * total
	for index, entry in list do
		roll -= entry.Weight
		if roll <= 0 then
			return index, entry
		end
	end
	return #list, list[#list]
end

function QuestService:Generate(player: Player, data)
	local day = today()
	local rng = Random.new(player.UserId * 31 + day * 7919)
	local valueMult = GameMath.BestZoneMult(data)
	local unlockedZones = {}
	for _, zoneId in Zones.Order do
		if data.Zones[zoneId] then
			table.insert(unlockedZones, zoneId)
		end
	end

	local available = {}
	for _, template in Quests.Templates do
		if data.Level >= (template.MinLevel or 1) then
			table.insert(available, template)
		end
	end

	local list = {}
	for _ = 1, Quests.DailyCount do
		if #available == 0 then
			break
		end
		local index, template = weightedPick(rng, available)
		table.remove(available, index)
		local target = template.Target(data.Level, valueMult)
		local quest = {
			Id = template.Id,
			Type = template.Type,
			Target = target,
			Progress = 0,
			Claimed = false,
			Reward = Quests.Reward(data.Level, valueMult),
		}
		local shownTarget = if template.IsCash then Format.Cash(target) else Format.Commas(target)
		if template.Type == "FindTier" then
			quest.MinTier = template.MinTier
		end
		if template.NeedsZone then
			-- Favour the player's best zone, sometimes an easier one
			local zoneId = unlockedZones[#unlockedZones]
			if #unlockedZones > 1 and rng:NextNumber() < 0.35 then
				zoneId = unlockedZones[rng:NextInteger(1, #unlockedZones - 1)]
			end
			quest.Zone = zoneId
			quest.Text = string.format(template.Text, shownTarget, Zones.Info[zoneId].Name)
		else
			quest.Text = string.format(template.Text, shownTarget)
		end
		table.insert(list, quest)
	end
	data.Quests = { Day = day, List = list }
end

function QuestService:EnsureToday(player: Player)
	local data = services.DataService:Get(player)
	if data and data.Quests.Day ~= today() then
		self:Generate(player, data)
		services.DataService:MarkDirty(player)
	end
end

function QuestService:Progress(player: Player, questType: string, amount: number, context: { [string]: any }?)
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	if data.Quests.Day ~= today() then
		self:Generate(player, data)
	end
	local changed = false
	for _, quest in data.Quests.List do
		if quest.Type == questType and not quest.Claimed and quest.Progress < quest.Target then
			local matches = true
			if questType == "FindTier" then
				matches = context ~= nil and (context.Tier or 0) >= (quest.MinTier or 1)
			elseif questType == "FindInZone" then
				matches = context ~= nil and context.Zone == quest.Zone
			end
			if matches then
				quest.Progress = math.min(quest.Target, quest.Progress + amount)
				changed = true
				if quest.Progress >= quest.Target then
					services.StateService:Notify(player, "📜 Quest complete: " .. quest.Text .. " - claim your reward!", "Success")
				end
			end
		end
	end
	if changed then
		services.DataService:MarkDirty(player)
	end
end

function QuestService:Claim(player: Player, index: number)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Not loaded" }
	end
	self:EnsureToday(player)
	local quest = data.Quests.List[index]
	if not quest then
		return { Ok = false, Error = "Quest not found" }
	end
	if quest.Claimed then
		return { Ok = false, Error = "Already claimed" }
	end
	if quest.Progress < quest.Target then
		return { Ok = false, Error = "Not finished yet" }
	end
	quest.Claimed = true
	services.InventoryService:AddCash(player, quest.Reward.Cash, true)
	services.LevelService:AddXP(player, quest.Reward.XP)
	services.StateService:Notify(player, "Quest reward: " .. Format.Cash(quest.Reward.Cash) .. " + " .. Format.Commas(quest.Reward.XP) .. " XP", "Success")
	services.AchievementService:Check(player)
	services.DataService:MarkDirty(player)
	return { Ok = true }
end

function QuestService:Init(allServices)
	services = allServices
end

function QuestService:Start()
	services.DataService.ProfileLoaded:Connect(function(player)
		self:EnsureToday(player)
	end)
	for _, player in services.DataService:GetLoadedPlayers() do
		self:EnsureToday(player)
	end

	RemoteGuard.Handle("ClaimQuest", 0.3, function(player, index)
		if not RemoteGuard.IsInteger(index, 1, 10) then
			return { Ok = false, Error = "Bad quest" }
		end
		return self:Claim(player, index)
	end)

	-- Roll over at midnight UTC for players who stay online
	while true do
		task.wait(60)
		for _, player in services.DataService:GetLoadedPlayers() do
			self:EnsureToday(player)
		end
	end
end

return QuestService
