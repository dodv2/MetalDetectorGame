--[[
	Main (Server)
	Starts every server service in order. Each service is a ModuleScript in ServerScriptService > Services
	with optional :Init(services) (set up, no yielding) and :Start() (connect events, start loops).
]]

local Services = {}

local ORDER = {
	"DataService",
	"StateService",
	"EventService",
	"ZoneService",
	"InventoryService",
	"LevelService",
	"LuckService",
	"ToolService",
	"TreasureService",
	"EquipmentShopService",
	"PersonalShopService",
	"QuestService",
	"AchievementService",
	"LeaderboardService",
	"EnvironmentService",
	"SharkService",
	"DevService",
}

local servicesFolder = script.Parent:WaitForChild("Services")

for _, name in ORDER do
	Services[name] = require(servicesFolder:WaitForChild(name))
end

for _, name in ORDER do
	local service = Services[name]
	if service.Init then
		service:Init(Services)
	end
end

for _, name in ORDER do
	local service = Services[name]
	if service.Start then
		task.spawn(function()
			service:Start()
		end)
	end
end

-- Studio-only testing helper (never created in live servers).
-- In Play mode, switch to the "Server" view and run in the command bar (Ctrl+Enter):
--   game.ServerStorage.BeachDev:Invoke("Give", 100000, 15)        -- +$100K and at least level 15
--   game.ServerStorage.BeachDev:Invoke("XP", 5000)                 -- +5000 XP (shows level-ups)
--   game.ServerStorage.BeachDev:Invoke("Rarity", "Legendary")      -- treasure buried in your zone becomes Legendary
--   game.ServerStorage.BeachDev:Invoke("Event", "MoonlitNight")  -- GoldenTide / TreasureRush / MoonlitNight
--   game.ServerStorage.BeachDev:Invoke("Items", 8)                 -- 8 random Starting Beach treasures in your backpack
--   game.ServerStorage.BeachDev:Invoke("Nearest")                  -- stand right on the closest buried treasure
--   game.ServerStorage.BeachDev:Invoke("Zones")                    -- unlock every beach (test moods, grounds, difficulty)
--   game.ServerStorage.BeachDev:Invoke("Shovel", "GoldShovel")     -- own + equip any shovel (test rarity gating)
if game:GetService("RunService"):IsStudio() then
	local devHook = Instance.new("BindableFunction")
	devHook.Name = "BeachDev"
	devHook.OnInvoke = function(command: string, a: any, b: any)
		if command == "Give" then
			for _, player in game:GetService("Players"):GetPlayers() do
				local data = Services.DataService:Get(player)
				if data then
					data.Cash += tonumber(a) or 0
					data.Level = math.max(data.Level, tonumber(b) or data.Level)
					Services.LeaderboardService:UpdateLeaderstats(player)
					Services.AchievementService:Check(player)
					Services.DataService:MarkDirty(player)
				end
			end
			return "Gave cash/level to all players"
		elseif command == "XP" then
			for _, player in game:GetService("Players"):GetPlayers() do
				Services.LevelService:AddXP(player, tonumber(a) or 1000)
			end
			return "Gave XP to all players"
		elseif command == "Rarity" then
			for _, player in game:GetService("Players"):GetPlayers() do
				Services.TreasureService:DebugReroll(player, a)
			end
			return "Buried treasure in your current zone is now " .. tostring(a)
		elseif command == "Event" then
			Services.EventService:StartEvent(a)
			return "Started event " .. tostring(a)
		elseif command == "Items" then
			local Treasures = require(game:GetService("ReplicatedStorage").Shared.Config.Treasures)
			local pool = {}
			for _, def in Treasures.List do
				if def.Zone == "StartingBeach" then
					table.insert(pool, def)
				end
			end
			for _, player in game:GetService("Players"):GetPlayers() do
				for _ = 1, math.clamp(tonumber(a) or 5, 1, 50) do
					local data = Services.DataService:Get(player)
					if data and not Services.InventoryService:IsFull(data) then
						local def = pool[math.random(1, #pool)]
						local quality = 0.8 + math.random() * 0.8
						local item = Services.InventoryService:CreateItem(player, def.Id, quality, math.floor(def.Value * quality), "StartingBeach")
						Services.InventoryService:AddItem(player, item)
					end
				end
			end
			return "Added treasures to every backpack"
		elseif command == "Shovel" then
			local Equipment = require(game:GetService("ReplicatedStorage").Shared.Config.Equipment)
			if not Equipment.ById.Shovel[a] then
				return "Unknown shovel id (e.g. GoldShovel, DiamondShovel, MythicalShovel)"
			end
			for _, player in game:GetService("Players"):GetPlayers() do
				local data = Services.DataService:Get(player)
				if data then
					data.Owned.Shovel[a] = true
					data.Equipment.Shovel = a
					Services.ToolService:GiveTools(player)
					Services.DataService:MarkDirty(player)
				end
			end
			return "Equipped " .. a
		elseif command == "Zones" then
			local Zones = require(game:GetService("ReplicatedStorage").Shared.Config.Zones)
			for _, player in game:GetService("Players"):GetPlayers() do
				local data = Services.DataService:Get(player)
				if data then
					for _, zoneId in Zones.Order do
						data.Zones[zoneId] = true
					end
					Services.DataService:MarkDirty(player)
				end
			end
			return "Unlocked every beach"
		elseif command == "Nearest" then
			for _, player in game:GetService("Players"):GetPlayers() do
				local position = Services.TreasureService:DebugNearest(player)
				if position and player.Character then
					player.Character:PivotTo(CFrame.new(position + Vector3.new(2, 4, 0)))
				end
			end
			return "Moved players onto the nearest buried treasure"
		end
		return "Unknown command"
	end
	devHook.Parent = game:GetService("ServerStorage")
end

print("[BeachDetecting] Server started with " .. #ORDER .. " services")
