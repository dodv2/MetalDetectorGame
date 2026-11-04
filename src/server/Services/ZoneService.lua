--[[
	ZoneService
	Knows where each zone is, which zone every player is standing in, unlocking zones,
	and teleporting. Also keeps players out of zones they haven't unlocked, and answers
	"where is this player?" questions for other services (at base? at a shopkeeper?).

	World setup (Workspace > Map > Zones > <ZoneId>):
	  Region         invisible box covering the whole zone (used to detect who is inside)
	  DigArea        the sand where treasures are buried
	  TravelPoint    where travel teleports you
	  Gate           (optional) the barrier at the zone's entrance - opened client-side once unlocked
	  UnlockStation  (optional) the stand beside the gate where the beach is bought (level + cash)
	Workspace > Map > Town: invisible box over the base (plaza, shops, shop street, shop plots)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)
local Treasures = require(Shared.Config.Treasures)
local Format = require(Shared.Format)
local Signal = require(Shared.Signal)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local ZoneService = {}
ZoneService.PlayerZoneChanged = Signal.new()

local services
local zoneParts: { [string]: { Region: BasePart, DigArea: BasePart, TravelPoint: BasePart?, Gate: BasePart?, Station: BasePart? } } = {}
local playerZone: { [Player]: string? } = {}
local lastWarn: { [Player]: number } = {}
local hubPoint: BasePart? = nil
local townBox: BasePart? = nil
local UNLOCK_RADIUS = 30 -- studs from a beach's unlock station

local function inside(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

function ZoneService:GetZoneParts(zoneId: string)
	return zoneParts[zoneId]
end

function ZoneService:GetZoneAt(position: Vector3): string?
	for zoneId, parts in zoneParts do
		if inside(parts.Region, position) then
			return zoneId
		end
	end
	return nil
end

function ZoneService:GetPlayerZone(player: Player): string?
	return playerZone[player]
end

local function rootOf(player: Player): BasePart?
	local character = player.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- "On the Pier" (Update 17; was "at base") = inside the town (plaza, NPC shops, shop street, shop plots), not on a beach
function ZoneService:IsAtBase(player: Player): boolean
	local root = rootOf(player)
	if not root then
		return false
	end
	local position = (root :: BasePart).Position
	if self:GetZoneAt(position) then
		return false
	end
	return townBox == nil or inside(townBox :: BasePart, position)
end

-- Standing near one of the base shopkeepers ("EquipmentShop" / "SellShop")
function ZoneService:IsNearShopkeeper(player: Player, shopId: string, radius: number?): boolean
	local map = Workspace:FindFirstChild("Map")
	local hub = map and map:FindFirstChild("Hub")
	local shops = hub and hub:FindFirstChild("Shops")
	local shop = shops and shops:FindFirstChild(shopId)
	local npc = shop and shop:FindFirstChild("NPC")
	local npcRoot = npc and npc:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not npcRoot then
		return true -- no physical shop in this place: don't block anything
	end
	local root = rootOf(player)
	return root ~= nil and ((root :: BasePart).Position - (npcRoot :: BasePart).Position).Magnitude <= (radius or 40)
end

-- Where a beach is bought: its unlock station (or its gate). Nil = no barrier (e.g. Secret Island).
function ZoneService:GetUnlockPoint(zoneId: string): Vector3?
	local parts = zoneParts[zoneId]
	if not parts then
		return nil
	end
	local station = parts.Station
	if station then
		return station.Position
	end
	return if parts.Gate then (parts.Gate :: BasePart).Position else nil
end

function ZoneService:IsUnlocked(player: Player, zoneId: string): boolean
	local data = services.DataService:Get(player)
	return data ~= nil and data.Zones[zoneId] == true
end

-- Returns ok, reason
function ZoneService:CanUnlock(data, zoneId: string): (boolean, string?)
	local zone = Zones.Info[zoneId]
	if not zone then
		return false, "Unknown zone"
	end
	if data.Zones[zoneId] then
		return false, "Already unlocked"
	end
	if data.Level < zone.Level then
		return false, "Requires level " .. zone.Level
	end
	if zone.RequiresDiscovery and not data.Index[zone.RequiresDiscovery] then
		local def = Treasures.ById[zone.RequiresDiscovery]
		return false, "Find the " .. (if def then def.Name else "secret map") .. " first"
	end
	if data.Cash < zone.Price then
		return false, "Need " .. Format.Cash(zone.Price)
	end
	return true, nil
end

function ZoneService:Unlock(player: Player, zoneId: string)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Not loaded" }
	end
	local ok, reason = self:CanUnlock(data, zoneId)
	if not ok then
		return { Ok = false, Error = reason }
	end
	-- beaches with a barrier are bought AT that barrier's unlock station
	local point = self:GetUnlockPoint(zoneId)
	local root = rootOf(player)
	if point and (not root or ((root :: BasePart).Position - point).Magnitude > UNLOCK_RADIUS) then
		return { Ok = false, Error = "Walk to the unlock station at the " .. Zones.Info[zoneId].Name .. " barrier to unlock it." }
	end
	local zone = Zones.Info[zoneId]
	if not services.InventoryService:SpendCash(player, zone.Price) then
		return { Ok = false, Error = "Need " .. Format.Cash(zone.Price) }
	end
	data.Zones[zoneId] = true
	services.StateService:Notify(player, "🔓 " .. zone.Name .. " unlocked! The barrier is open - walk on through.", "Success")
	services.AchievementService:Check(player)
	services.DataService:MarkDirty(player)
	return { Ok = true }
end

function ZoneService:TeleportTo(player: Player, target: CFrame)
	local character = player.Character
	if character and character.PrimaryPart then
		character:PivotTo(target + Vector3.new(0, 4, 0))
	end
end

function ZoneService:GetHubCFrame(): CFrame
	return if hubPoint then hubPoint.CFrame else CFrame.new(0, 5, 140)
end

-- Every teleport (Return to Base, Treasure Shop, Travel menu) goes through here: the server picks
-- the destination and refuses mid-dig. There is NO cooldown (the remote is only rate-limited
-- against spam). Only the character moves - inventory, cash, equipment and progress are untouched.
function ZoneService:TravelTo(player: Player, destination: string)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return { Ok = false, Error = "You can't teleport right now" }
	end
	if services.TreasureService:IsDigging(player) then
		return { Ok = false, Error = "⛏ Finish (or cancel) your dig before teleporting." }
	end
	return self:Teleport(player, destination)
end

function ZoneService:Teleport(player: Player, destination: string)
	if destination == "Hub" or destination == "Base" or destination == "Pier" then -- (old names still accepted)
		-- a little spread so a group returning together doesn't stack up
		local spread = Vector3.new(math.random(-40, 40) / 10, 0, math.random(-30, 30) / 10)
		self:TeleportTo(player, self:GetHubCFrame() + spread)
		return { Ok = true }
	elseif destination == "MyShop" then
		local entrance = services.PersonalShopService:GetEntrance(player)
		if not entrance then
			return { Ok = false, Error = "You don't have a shop plot yet" }
		end
		self:TeleportTo(player, entrance)
		return { Ok = true }
	end
	local parts = zoneParts[destination]
	if not parts then
		return { Ok = false, Error = "Unknown destination" }
	end
	if not self:IsUnlocked(player, destination) then
		return { Ok = false, Error = "Unlock " .. Zones.Info[destination].Name .. " first" }
	end
	local point = parts.TravelPoint or parts.DigArea
	self:TeleportTo(player, point.CFrame)
	return { Ok = true }
end

function ZoneService:Init(allServices)
	services = allServices
end

function ZoneService:Start()
	local map = Workspace:WaitForChild("Map")
	local zonesFolder = map:WaitForChild("Zones")
	for _, zoneId in Zones.Order do
		local folder = zonesFolder:WaitForChild(zoneId, 10)
		if folder then
			local region = folder:FindFirstChild("Region") :: BasePart?
			local digArea = folder:FindFirstChild("DigArea") :: BasePart?
			if region and digArea then
				zoneParts[zoneId] = {
					Region = region,
					DigArea = digArea,
					TravelPoint = folder:FindFirstChild("TravelPoint") :: BasePart?,
					Gate = folder:FindFirstChild("Gate") :: BasePart?,
					Station = nil,
				}
				local station = folder:FindFirstChild("UnlockStation")
				if station and station:IsA("Model") then
					zoneParts[zoneId].Station = station.PrimaryPart or station:FindFirstChildWhichIsA("BasePart")
				end
			else
				warn("[ZoneService] Zone " .. zoneId .. " is missing Region or DigArea")
			end
		else
			warn("[ZoneService] Missing zone folder Map.Zones." .. zoneId)
		end
	end
	local hub = map:FindFirstChild("Hub")
	hubPoint = hub and hub:FindFirstChild("HubPoint") :: BasePart?
	townBox = map:FindFirstChild("Town") :: BasePart?

	RemoteGuard.Handle("UnlockZone", 0.5, function(player, zoneId)
		if not RemoteGuard.IsString(zoneId) then
			return { Ok = false, Error = "Bad zone" }
		end
		return self:Unlock(player, zoneId)
	end)

	RemoteGuard.Handle("TravelTo", 0.4, function(player, destination)
		if not RemoteGuard.IsString(destination) then
			return { Ok = false, Error = "Bad destination" }
		end
		return self:TravelTo(player, destination)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playerZone[player] = nil
		lastWarn[player] = nil
	end)

	-- Track zones + keep players out of locked zones (server-side backup for the client gates)
	while true do
		task.wait(0.4)
		for _, player in Players:GetPlayers() do
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local data = services.DataService:Get(player)
			if root and data then
				local zoneId = self:GetZoneAt(root.Position)
				if zoneId and not data.Zones[zoneId] then
					local zone = Zones.Info[zoneId]
					self:TeleportTo(player, self:GetHubCFrame())
					if not lastWarn[player] or os.clock() - lastWarn[player] > 4 then
						lastWarn[player] = os.clock()
						services.StateService:Notify(player, "🔒 " .. zone.Name .. " is locked (Level " .. zone.Level .. ", " .. Format.Cash(zone.Price) .. "). Unlock it at the station beside its barrier.", "Warning")
					end
					zoneId = nil
				end
				if playerZone[player] ~= zoneId then
					playerZone[player] = zoneId
					ZoneService.PlayerZoneChanged:Fire(player, zoneId)
					services.StateService:Schedule(player)
				end
			end
		end
	end
end

return ZoneService
