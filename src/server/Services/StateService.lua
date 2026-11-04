--[[
	StateService
	Sends each player a snapshot of their own data (plus calculated values like Luck)
	whenever something changes. The client UI only ever *reads* this - all changes go
	through server RemoteFunctions.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameMath = require(Shared.GameMath)
local Rarities = require(Shared.Config.Rarities)
local Progression = require(Shared.Config.Progression)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local StateService = {}

local services
local pending: { [Player]: boolean } = {}
local stateRemote: RemoteEvent
local notifyRemote: RemoteEvent

function StateService:BuildView(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return nil
	end
	services.ToolService:ValidateTreasure(player, data)
	return {
		Cash = data.Cash,
		XP = data.XP,
		Level = data.Level,
		XPNeeded = Progression.XPForLevel(data.Level),
		Inventory = data.Inventory,
		Capacity = GameMath.Capacity(data),
		Equipment = data.Equipment,
		Owned = data.Owned,
		Trinkets = data.Trinkets,
		Zones = data.Zones,
		Shop = {
			Level = data.Shop.Level,
			Theme = data.Shop.Theme,
			Name = data.Shop.Name,
			Displays = data.Shop.Displays,
			Slots = GameMath.ShopSlots(data),
			Plot = services.PersonalShopService:GetPlotIndex(player),
		},
		Boosts = data.Boosts,
		Luck = services.LuckService:GetLuck(player),
		Index = data.Index,
		Stats = data.Stats,
		Achievements = data.Achievements,
		Quests = data.Quests,
		Settings = data.Settings,
		CurrentZone = services.ZoneService:GetPlayerZone(player),
		ServerTime = os.time(),
		Saving = services.DataService.StoreAvailable,
	}
end

function StateService:Push(player: Player)
	local view = self:BuildView(player)
	if view then
		stateRemote:FireClient(player, view)
	end
end

-- Toast message on the player's screen. Kind: "Info" | "Success" | "Warning" | "Error" | "Event" | "Rare"
function StateService:Notify(player: Player, text: string, kind: string?)
	notifyRemote:FireClient(player, { Text = text, Kind = kind or "Info" })
end

function StateService:NotifyAll(text: string, kind: string?)
	notifyRemote:FireAllClients({ Text = text, Kind = kind or "Info" })
end

-- Batch many changes in the same moment into one update
function StateService:Schedule(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.1, function()
		pending[player] = nil
		if player.Parent then
			self:Push(player)
		end
	end)
end

function StateService:Init(allServices)
	services = allServices
	stateRemote = Net.Event("StateUpdate")
	notifyRemote = Net.Event("Notify")
end

function StateService:Start()
	RemoteGuard.Handle("GetState", 0.5, function(player)
		local data = services.DataService:WaitFor(player)
		if not data then
			return { Ok = false, Error = "Not loaded" }
		end
		return { Ok = true, State = self:BuildView(player) }
	end)

	RemoteGuard.Handle("UpdateSettings", 0.2, function(player, key, value)
		local data = services.DataService:Get(player)
		if not data or type(key) ~= "string" then
			return { Ok = false }
		end
		local current = data.Settings[key]
		if current == nil or type(current) ~= type(value) then
			return { Ok = false, Error = "Unknown setting" }
		end
		if key == "QuickSell" then
			-- rebuild from known rarities only (never store a client table as-is)
			local clean = {}
			for _, rarity in Rarities.Order do
				clean[rarity] = value[rarity] == true
			end
			data.Settings.QuickSell = clean
			self:Schedule(player)
			return { Ok = true }
		elseif type(value) == "table" then
			return { Ok = false, Error = "Unknown setting" }
		end
		if type(value) == "number" then
			value = math.clamp(value, 0, 1)
		end
		data.Settings[key] = value
		self:Schedule(player)
		return { Ok = true }
	end)

	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return StateService
