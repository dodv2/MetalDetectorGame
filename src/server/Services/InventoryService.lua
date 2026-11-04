--[[
	InventoryService
	The player's backpack of found treasures, plus cash.
	The backpack holds a fixed 10 treasures (GameConfig.BackpackCapacity).

	Where you can sell (checked here, on the server):
	  SellItem / SellBulk({Ids})        only at the 💰 Sell Shop (next to Captain Goldtooth)
	  SellBulk({Rarities}) = Quick Sell anywhere at base (town), never out on a beach
	Newly dug treasures go straight into the backpack - nothing can be sold from the dig site.

	Item format (saved in data.Inventory and data.Shop.Displays):
	  { Id = "17", TreasureId = "PirateDoubloon", Quality = 1.23, Value = 1476, Zone = "StartingBeach", Locked = false }
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local GameMath = require(Shared.GameMath)
local Format = require(Shared.Format)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local InventoryService = {}

local services

function InventoryService:CreateItem(player: Player, treasureId: string, quality: number, value: number, zoneId: string)
	local data = services.DataService:Get(player)
	local id = tostring(data.NextItemId)
	data.NextItemId += 1
	return {
		Id = id,
		TreasureId = treasureId,
		Quality = quality,
		Value = value,
		Zone = zoneId,
		Locked = false,
		Found = os.time(),
	}
end

function InventoryService:GetCapacity(data): number
	return GameMath.Capacity(data)
end

function InventoryService:IsFull(data): boolean
	return #data.Inventory >= GameMath.Capacity(data)
end

function InventoryService:FindItem(data, itemId: string)
	for index, item in data.Inventory do
		if item.Id == itemId then
			return index, item
		end
	end
	return nil, nil
end

function InventoryService:AddItem(player: Player, item)
	local data = services.DataService:Get(player)
	table.insert(data.Inventory, item)
	services.DataService:MarkDirty(player)
end

function InventoryService:RemoveItem(player: Player, itemId: string)
	local data = services.DataService:Get(player)
	local index, item = self:FindItem(data, itemId)
	if index then
		table.remove(data.Inventory, index)
	end
	return item
end

-- earned = true counts towards "total money earned" stats/achievements
function InventoryService:AddCash(player: Player, amount: number, earned: boolean)
	local data = services.DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	amount = math.floor(amount)
	data.Cash += amount
	if earned then
		data.Stats.CashEarned += amount
	end
	services.LeaderboardService:UpdateLeaderstats(player)
	services.DataService:MarkDirty(player)
end

function InventoryService:SpendCash(player: Player, amount: number): boolean
	local data = services.DataService:Get(player)
	if not data or data.Cash < amount then
		return false
	end
	data.Cash -= amount
	services.LeaderboardService:UpdateLeaderstats(player)
	services.DataService:MarkDirty(player)
	return true
end

function InventoryService:Sell(player: Player, itemId: string)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Not loaded" }
	end
	local _, item = self:FindItem(data, itemId)
	if not item then
		return { Ok = false, Error = "Item not found" }
	end
	self:RemoveItem(player, itemId)
	data.Stats.Sold += 1
	self:AddCash(player, item.Value, true)
	services.QuestService:Progress(player, "SellValue", item.Value)
	services.AchievementService:Check(player)
	return { Ok = true, Cash = item.Value }
end

-- Bulk sale. `filter` is one of:
--   { Rarities = { Common = true, ... } }  Quick Sell: every eligible item of the chosen rarities
--   { Ids = { "12", "15", ... } }          Sell Shop: exactly these items
-- Locked and favourite items are NEVER bulk-sold; displayed items live in the shop, not the
-- backpack, so they can't be sold here either. `preview = true` only counts.
function InventoryService:SellBulk(player: Player, filter, preview: boolean?)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Not loaded" }
	end
	local wanted: { [string]: boolean } = {}
	if filter.Ids then
		for _, id in filter.Ids do
			wanted[id] = true
		end
	end
	local total, count = 0, 0
	local keep = {}
	for _, item in data.Inventory do
		local def = Treasures.ById[item.TreasureId]
		local rarity = if def then def.Rarity else "Common"
		local chosen = if filter.Ids then wanted[item.Id] == true else filter.Rarities[rarity] == true
		if chosen and not item.Locked and not item.Favorite then
			total += item.Value
			count += 1
		else
			table.insert(keep, item)
		end
	end
	if preview then
		return { Ok = true, Cash = total, Count = count }
	end
	if count == 0 then
		return { Ok = false, Error = "Nothing to sell (🔒 locked and ⭐ favourite treasures are always kept)" }
	end
	data.Inventory = keep
	data.Stats.Sold += count
	self:AddCash(player, total, true)
	services.QuestService:Progress(player, "SellValue", total)
	services.AchievementService:Check(player)
	return { Ok = true, Cash = total, Count = count }
end

-- kind "Lock" (default) or "Favorite"
function InventoryService:ToggleLock(player: Player, itemId: string, kind: string?)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false }
	end
	local _, item = self:FindItem(data, itemId)
	if not item then
		return { Ok = false, Error = "Item not found" }
	end
	if kind == "Favorite" then
		item.Favorite = if item.Favorite then nil else true
	else
		item.Locked = not item.Locked
	end
	services.DataService:MarkDirty(player)
	return { Ok = true, Locked = item.Locked, Favorite = item.Favorite == true }
end

function InventoryService:Init(allServices)
	services = allServices
end

function InventoryService:Start()
	local SELL_RADIUS = 40
	local function atSellShop(player: Player): boolean
		return services.ZoneService:IsNearShopkeeper(player, "SellShop", SELL_RADIUS)
	end

	RemoteGuard.Handle("SellItem", 0.1, function(player, itemId)
		if not RemoteGuard.IsString(itemId, 16) then
			return { Ok = false, Error = "Bad item" }
		end
		if not atSellShop(player) then
			return { Ok = false, Error = "💰 Sell treasures at the Sell Shop on the Pier (talk to Captain Goldtooth)." }
		end
		return self:Sell(player, itemId)
	end)

	-- SellBulk(maxTier)                     legacy: everything up to a rarity tier
	-- SellBulk({ Rarities = {...} }, preview) Quick Sell
	-- SellBulk({ Ids = {...} }, preview)      Sell Shop selection
	-- Only plain strings / booleans are read from the client table (nothing else is trusted).
	RemoteGuard.Handle("SellBulk", 0.5, function(player, arg, preview)
		local filter
		if RemoteGuard.IsInteger(arg, 1, #Rarities.Order) then
			filter = { Rarities = {} }
			for tier = 1, arg do
				filter.Rarities[Rarities.Order[tier]] = true
			end
		elseif type(arg) == "table" and type(arg.Rarities) == "table" then
			filter = { Rarities = {} }
			for _, rarity in Rarities.Order do
				filter.Rarities[rarity] = arg.Rarities[rarity] == true
			end
		elseif type(arg) == "table" and type(arg.Ids) == "table" then
			filter = { Ids = {} }
			for index, id in arg.Ids do
				if index > 300 then
					break
				end
				if RemoteGuard.IsString(id, 16) then
					table.insert(filter.Ids, id)
				end
			end
		else
			return { Ok = false, Error = "Bad request" }
		end
		if filter.Ids and not atSellShop(player) then
			return { Ok = false, Error = "💰 Sell treasures at the Sell Shop on the Pier (talk to Captain Goldtooth)." }
		end
		if filter.Rarities and not services.ZoneService:IsAtBase(player) then
			return { Ok = false, Error = "⚡ Quick Sell works on the Pier. Use ⚓ Pier to head back first." }
		end
		return self:SellBulk(player, filter, preview == true)
	end)

	RemoteGuard.Handle("ToggleLock", 0.1, function(player, itemId, kind)
		if not RemoteGuard.IsString(itemId, 16) then
			return { Ok = false, Error = "Bad item" }
		end
		return self:ToggleLock(player, itemId, if kind == "Favorite" then "Favorite" else "Lock")
	end)
end

return InventoryService
