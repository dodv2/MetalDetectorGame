--[[
	DataService
	Loads, saves and session-locks every player's data with DataStoreService.

	* Data is loaded with UpdateAsync and a session lock, so two servers can never overwrite each other.
	* Autosaves every GameConfig.AutosaveInterval seconds, on leave, and on server shutdown.
	* In Studio without "Enable Studio Access to API Services", the game still runs - progress just won't save.

	Other services use:
	  DataService:Get(player)          -> data table (or nil if not loaded yet)
	  DataService:MarkDirty(player)    -> sends fresh state to that player's UI
	  DataService.ProfileLoaded        -> Signal(player, data)
	  DataService.ProfileReleasing     -> Signal(player, data)  (just before final save)
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Signal = require(Shared.Signal)
local GameConfig = require(Shared.Config.GameConfig)
local Zones = require(Shared.Config.Zones)
local Equipment = require(Shared.Config.Equipment)

local DataService = {}
DataService.ProfileLoaded = Signal.new()
DataService.ProfileReleasing = Signal.new()
DataService.StoreAvailable = true

local DATA_VERSION = 3
local LOCK_TIMEOUT = 600 -- seconds before another server's lock is considered dead

type Profile = {
	Data: any,
	Key: string,
	Loaded: boolean,
	Saving: boolean,
	CanSave: boolean,
	Sandbox: boolean?, -- developer test session: the lock is kept/released, the data never written
}

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local services

---------------------------------------------------------------------------
-- Default data (new players). New fields added here are automatically
-- filled in for existing players when they next join (see reconcile).
---------------------------------------------------------------------------
local function defaultData()
	return {
		Version = DATA_VERSION,
		Cash = GameConfig.StartingCash,
		XP = 0,
		Level = 1,
		Inventory = {}, -- array of items
		NextItemId = 1,
		Equipment = {
			Detector = "RustyBeeper", -- every detector has its own built-in coil
			Shovel = "StarterShovel",
			Skin = "Default",
		},
		Owned = {
			Detector = { RustyBeeper = true },
			Shovel = { StarterShovel = true },
			Skin = { Default = true },
			Theme = { BeachHut = true },
		},
		Trinkets = {},
		Zones = { [Zones.Order[1]] = true },
		Shop = {
			Level = 1, -- index into Equipment.ShopLevels
			Theme = "BeachHut",
			Name = "",
			Displays = {}, -- ["slotIndex"] = item
		},
		Boosts = {}, -- [boostId] = unix expiry time
		Index = {}, -- [treasureId] = times found
		Stats = {
			Found = 0,
			Digs = 0,
			CashEarned = 0,
			Sold = 0,
			BoostsUsed = 0,
			BestValue = 0,
			Lost = 0, -- treasures lost in the sand (Update 17)
			Rarity = {}, -- [rarityName] = count
			ZoneFinds = {}, -- [zoneId] = count
		},
		Achievements = {}, -- [achievementId] = true
		Quests = { Day = 0, List = {} },
		Settings = {
			Sound = true,
			BeepVolume = 0.6,
			Haptics = true,
			ReducedMotion = false,
			EdgeGlow = true,
			LargeText = false,
			DetectorMinimized = false,
			-- which rarities the backpack's Quick Sell includes (Legendary+ kept by default)
			QuickSell = { Common = true, Uncommon = true, Rare = true, Epic = true, Legendary = false, Mythical = false, Secret = false },
		},
		FirstJoin = os.time(),
		LastJoin = os.time(),
	}
end

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in value do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- Adds any missing fields from the template (never removes player data)
local function reconcile(target, template)
	for key, value in template do
		if target[key] == nil then
			target[key] = deepCopy(value)
		elseif type(value) == "table" and type(target[key]) == "table" and next(value) ~= nil and #value == 0 then
			reconcile(target[key], value)
		end
	end
end

-- Upgrades older saves to the current layout:
--   v2  shovel overhaul
--   v3  coils are built into detectors and the backpack is fixed at 10 (old coil/backpack
--       purchases are simply dropped; treasures are NEVER removed, even above 10)
local function migrate(data)
	local starter = Equipment.Shovels[1].Id
	data.Owned.Shovel = data.Owned.Shovel or {}
	data.Owned.Shovel[starter] = true
	if not Equipment.ById.Shovel[data.Equipment.Shovel] then
		data.Equipment.Shovel = starter
	end
	data.Equipment.Coil = nil
	data.Equipment.Backpack = nil
	data.Owned.Coil = nil
	data.Version = DATA_VERSION
end

local function isStudioAccessError(message: string): boolean
	return string.find(message, "StudioAccessToApisNotAllowed") ~= nil
		or string.find(message, "Studio") ~= nil and string.find(message, "API") ~= nil
		or string.find(message, "403") ~= nil
end

---------------------------------------------------------------------------
-- Loading (with session lock)
---------------------------------------------------------------------------
local function loadAsync(key: string): (boolean, any)
	if not store or not DataService.StoreAvailable then
		return true, nil
	end
	for attempt = 1, 5 do
		local status = "ok"
		local loaded = nil
		local ok, err = pcall(function()
			(store :: DataStore):UpdateAsync(key, function(old)
				old = old or {}
				local lock = old.Lock
				if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < LOCK_TIMEOUT and attempt < 5 then
					status = "locked"
					return nil -- don't write; try again shortly
				end
				old.Lock = { JobId = game.JobId, Time = os.time() }
				loaded = old.Data
				return old
			end)
		end)
		if ok and status == "ok" then
			return true, loaded
		end
		if not ok then
			warn("[DataService] Load failed (" .. attempt .. "): " .. tostring(err))
			if RunService:IsStudio() and isStudioAccessError(tostring(err)) then
				DataService.StoreAvailable = false
				warn("[DataService] Studio API access is off - progress will NOT save. Turn on 'Enable Studio Access to API Services' in Game Settings > Security.")
				return true, nil
			end
		end
		task.wait(if status == "locked" then 4 else 2)
	end
	return false, nil
end

---------------------------------------------------------------------------
-- Saving
---------------------------------------------------------------------------
local function saveAsync(player: Player, release: boolean)
	local profile = profiles[player]
	if not profile or not profile.Loaded or not profile.CanSave or not store or not DataService.StoreAvailable then
		return
	end
	while profile.Saving do
		task.wait(0.1)
	end
	profile.Saving = true
	local data = profile.Data
	local sandbox = profile.Sandbox == true
	if not sandbox then
		data.LastSave = os.time()
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(profile.Key, function(old)
			old = old or {}
			local lock = old.Lock
			if lock and lock.JobId ~= game.JobId and os.time() - (lock.Time or 0) < LOCK_TIMEOUT then
				-- Another server took over this player (they joined elsewhere). Don't overwrite.
				return nil
			end
			if not sandbox then
				old.Data = data
			end
			if release then
				old.Lock = nil
			else
				old.Lock = { JobId = game.JobId, Time = os.time() }
			end
			return old
		end)
	end)
	profile.Saving = false
	if not ok then
		warn("[DataService] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------------------
-- Player lifecycle
---------------------------------------------------------------------------
local function onPlayerAdded(player: Player)
	local key = "Player_" .. player.UserId
	local profile: Profile = { Data = nil, Key = key, Loaded = false, Saving = false, CanSave = true }
	profiles[player] = profile

	local ok, stored = loadAsync(key)
	if not ok then
		player:Kick("Couldn't load your save data. Please rejoin in a moment - your progress is safe.")
		profiles[player] = nil
		return
	end

	local data = if type(stored) == "table" then stored else defaultData()
	reconcile(data, defaultData())
	migrate(data)
	data.LastJoin = os.time()
	profile.Data = data
	profile.Loaded = true

	if player.Parent == nil then
		-- Left while loading: release the lock right away
		saveAsync(player, true)
		profiles[player] = nil
		return
	end

	player:SetAttribute("DataLoaded", true)
	DataService.ProfileLoaded:Fire(player, data)
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.Loaded then
		DataService.ProfileReleasing:Fire(player, profile.Data)
		task.wait() -- let listeners finish their synchronous cleanup
		saveAsync(player, true)
	end
	profiles[player] = nil
end

---------------------------------------------------------------------------
-- Public API
---------------------------------------------------------------------------
function DataService:Get(player: Player)
	local profile = profiles[player]
	return if profile and profile.Loaded then profile.Data else nil
end

function DataService:IsLoaded(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Loaded
end

-- Yields until the player's data is loaded (or they leave)
function DataService:WaitFor(player: Player)
	while player.Parent and not self:IsLoaded(player) do
		task.wait(0.1)
	end
	return self:Get(player)
end

function DataService:GetLoadedPlayers(): { Player }
	local list = {}
	for player, profile in profiles do
		if profile.Loaded and player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

function DataService:MarkDirty(player: Player)
	services.StateService:Schedule(player)
end

-- Developer sandbox (DevService): while on, nothing about this player is written to the
-- DataStore, so test edits can never leak into real progression.
function DataService:SetSandbox(player: Player, on: boolean)
	local profile = profiles[player]
	if profile then
		profile.Sandbox = on
	end
end

function DataService:IsSandboxed(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile.Sandbox == true
end

function DataService:SaveNow(player: Player)
	saveAsync(player, false)
end

function DataService:Init(allServices)
	services = allServices
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(GameConfig.DataStoreName)
	end)
	if ok then
		store = result
	else
		DataService.StoreAvailable = false
		warn("[DataService] DataStores unavailable: " .. tostring(result))
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end

	-- Autosave loop
	task.spawn(function()
		while true do
			task.wait(GameConfig.AutosaveInterval)
			for player, profile in profiles do
				if profile.Loaded and player.Parent then
					task.spawn(saveAsync, player, false)
					task.wait(1)
				end
			end
		end
	end)

	game:BindToClose(function()
		local pending = 0
		for player, profile in profiles do
			if profile.Loaded then
				pending += 1
				task.spawn(function()
					saveAsync(player, true)
					pending -= 1
				end)
			end
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
end

return DataService
