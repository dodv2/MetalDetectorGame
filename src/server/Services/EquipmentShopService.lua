--[[
	EquipmentShopService
	Buying and equipping detectors (each with its own built-in coil), shovels, skins and Luck boosts.
	All prices, level requirements and ownership are checked here on the server.
	Purchases only work at the physical Equipment Shop (you must be near its shopkeeper).
	Shop upgrades and shop themes are bought inside your own Treasure Shop (PersonalShopService).
	The backpack is a fixed 10 slots, so there's nothing to buy for it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local GameConfig = require(Shared.Config.GameConfig)
local Format = require(Shared.Format)
local Net = require(Shared.Net)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local EquipmentShopService = {}

local services
local purchaseRemote: RemoteEvent

local function fail(message: string)
	return { Ok = false, Error = message }
end

local SHOP_RADIUS = 40

-- true when the player stands at the Equipment Shop (the NPC's position never leaves the server copy)
local function atShop(player: Player): boolean
	return services.ZoneService:IsNearShopkeeper(player, "EquipmentShop", SHOP_RADIUS)
end

function EquipmentShopService:Equip(player: Player, category: string, id: string)
	local data = services.DataService:Get(player)
	if not data then
		return fail("Not loaded")
	end
	if not Equipment.Ownable[category] or not Equipment.Get(category, id) then
		return fail("Unknown item")
	end
	if not (data.Owned[category] and data.Owned[category][id]) then
		return fail("You don't own that yet")
	end
	if category == "Theme" then
		data.Shop.Theme = id
		services.PersonalShopService:ApplyTheme(player)
	else
		data.Equipment[category] = id
	end
	if category == "Detector" or category == "Skin" or category == "Shovel" then
		services.ToolService:GiveTools(player)
	end
	services.DataService:MarkDirty(player)
	return { Ok = true }
end

function EquipmentShopService:Buy(player: Player, category: string, id: string)
	local data = services.DataService:Get(player)
	if not data then
		return fail("Not loaded")
	end
	if category == "Theme" then
		return fail("🏪 Shop themes are bought in your own Treasure Shop (Manage Shop desk).")
	end
	if not Equipment.Ownable[category] then
		return fail("Unknown category")
	end
	local def = Equipment.Get(category, id)
	if not def then
		return fail("Unknown item")
	end
	data.Owned[category] = data.Owned[category] or {}
	if data.Owned[category][id] then
		return fail("You already own " .. def.Name)
	end
	if data.Level < def.Level then
		return fail("Requires level " .. def.Level)
	end
	if not services.InventoryService:SpendCash(player, def.Price) then
		return fail("You need " .. Format.Cash(def.Price - data.Cash) .. " more")
	end
	data.Owned[category][id] = true
	-- the client celebrates the purchase (NotifyController)
	purchaseRemote:FireClient(player, { Category = category, Id = id, Name = def.Name })
	self:Equip(player, category, id)
	return { Ok = true }
end

-- Adds time to a boost (stacking up to MaxBoostSeconds) and upgrades buried treasure rolls
function EquipmentShopService:GrantBoost(player: Player, boostId: string, duration: number, quiet: boolean?)
	local data = services.DataService:Get(player)
	local def = Equipment.ById.Boost[boostId]
	if not data or not def then
		return
	end
	local now = os.time()
	local current = math.max(now, data.Boosts[boostId] or 0)
	data.Boosts[boostId] = math.min(current + duration, now + GameConfig.MaxBoostSeconds)
	data.Stats.BoostsUsed += 1
	services.TreasureService:UpgradeRolls(player)
	if not quiet then
		services.StateService:Notify(player, "🍀 " .. def.Name .. " active: " .. Format.Luck(def.Luck) .. " for " .. Format.Time(data.Boosts[boostId] - now), "Success")
	end
	services.AchievementService:Check(player)
	services.DataService:MarkDirty(player)
end

function EquipmentShopService:BuyBoost(player: Player, boostId: string)
	local data = services.DataService:Get(player)
	local def = Equipment.ById.Boost[boostId]
	if not data or not def then
		return fail("Unknown boost")
	end
	if data.Level < def.Level then
		return fail("Requires level " .. def.Level)
	end
	local now = os.time()
	if (data.Boosts[boostId] or 0) - now > GameConfig.MaxBoostSeconds - 60 then
		return fail("That boost is already stacked to the maximum")
	end
	if not services.InventoryService:SpendCash(player, def.Price) then
		return fail("You need " .. Format.Cash(def.Price - data.Cash) .. " more")
	end
	self:GrantBoost(player, boostId, def.Duration)
	return { Ok = true }
end

function EquipmentShopService:Init(allServices)
	services = allServices
	purchaseRemote = Net.Event("Purchased")
end

function EquipmentShopService:Start()
	RemoteGuard.Handle("BuyItem", 0.3, function(player, category, id)
		if not RemoteGuard.IsString(category, 20) or not RemoteGuard.IsString(id, 40) then
			return fail("Bad request")
		end
		if not atShop(player) then
			return fail("🛒 Visit the Equipment Shop on the Pier to buy equipment.")
		end
		return self:Buy(player, category, id)
	end)

	-- EquipItem(category, id). category "Treasure" = hold one of YOUR backpack treasures in your
	-- hand (id = item id, "" = put it away); everything else equips owned gear.
	RemoteGuard.Handle("EquipItem", 0.2, function(player, category, id)
		if category == "Treasure" and type(id) == "string" and #id <= 16 then
			return services.ToolService:HoldTreasure(player, id)
		end
		if not RemoteGuard.IsString(category, 20) or not RemoteGuard.IsString(id, 40) then
			return fail("Bad request")
		end
		return self:Equip(player, category, id)
	end)

	RemoteGuard.Handle("BuyBoost", 0.5, function(player, boostId)
		if not RemoteGuard.IsString(boostId, 40) then
			return fail("Bad request")
		end
		if not atShop(player) then
			return fail("🛒 Visit the Equipment Shop on the Pier to buy boosts.")
		end
		return self:BuyBoost(player, boostId)
	end)
end

return EquipmentShopService
