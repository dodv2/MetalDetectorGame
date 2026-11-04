--[[
	GameMath
	Shared formulas: Luck, rarity chances, quality rolls, detector stats, capacity.
	The SERVER uses these to make every real decision. The CLIENT uses the same code
	only to *display* numbers (e.g. the Luck panel's chance table).
]]

local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local Rarities = require(Config.Rarities)
local Zones = require(Config.Zones)
local Treasures = require(Config.Treasures)
local Equipment = require(Config.Equipment)
local Progression = require(Config.Progression)

local GameMath = {}

---------------------------------------------------------------------------
-- Shop / display luck
---------------------------------------------------------------------------

-- Luck one displayed item gives: rarity bonus x quality x zone bonus
function GameMath.ItemDisplayLuck(item): number
	if type(item) ~= "table" then
		return 0
	end
	local def = Treasures.ById[item.TreasureId]
	if not def then
		return 0
	end
	local rarity = Rarities.Info[def.Rarity]
	local zone = Zones.Info[item.Zone]
	local zoneIndex = if zone then zone.Index else 1
	return rarity.DisplayLuck * (item.Quality or 1) * (1 + GameConfig.ZoneDisplayLuckBonus * (zoneIndex - 1))
end

function GameMath.ShopLuck(displays): number
	local total = 0
	for _, item in displays or {} do
		total += GameMath.ItemDisplayLuck(item)
	end
	return total
end

function GameMath.ShopValue(displays): number
	local total = 0
	for _, item in displays or {} do
		total += item.Value or 0
	end
	return total
end

function GameMath.CountDisplays(displays): number
	local count = 0
	for _ in displays or {} do
		count += 1
	end
	return count
end

-- "Better" treasure for display: higher rarity first, then higher value (ties: older item first)
function GameMath.BetterForDisplay(a, b): boolean
	local da, db = Treasures.ById[a.TreasureId], Treasures.ById[b.TreasureId]
	local ta = if da then Rarities.Tier(da.Rarity) else 0
	local tb = if db then Rarities.Tier(db.Rarity) else 0
	if ta ~= tb then
		return ta > tb
	end
	if (a.Value or 0) ~= (b.Value or 0) then
		return (a.Value or 0) > (b.Value or 0)
	end
	return (tonumber(a.Id) or 0) < (tonumber(b.Id) or 0)
end

--[[
	Place Best Items plan. Looks at backpack + displayed treasures together, keeps the best
	`slots` of them on display, fills empty slots first and swaps out weaker displays.
	Returns {
		Add = { { Item, Slot, Replaces = item? } },  -- backpack -> display
		Return = { { Item, Slot } },                  -- display -> backpack (replaced)
		LuckBefore, LuckAfter, Signature
	}
	Nothing is created or destroyed: every item ends up in exactly one place.
]]
function GameMath.PlanBestDisplays(inventory, displays, slots: number)
	local pool = {}
	for key, item in displays do
		local slot = tonumber(key)
		if slot and slot <= slots then
			table.insert(pool, { Item = item, Slot = slot })
		end
	end
	for _, item in inventory do
		table.insert(pool, { Item = item, Slot = nil })
	end
	table.sort(pool, function(a, b)
		return GameMath.BetterForDisplay(a.Item, b.Item)
	end)

	local keep: { [any]: boolean } = {}
	for index = 1, math.min(slots, #pool) do
		keep[pool[index].Item] = true
	end

	-- displayed items that drop out, weakest first
	local outgoing = {}
	for key, item in displays do
		local slot = tonumber(key)
		if slot and slot <= slots and not keep[item] then
			table.insert(outgoing, { Item = item, Slot = slot })
		end
	end
	table.sort(outgoing, function(a, b)
		return GameMath.BetterForDisplay(b.Item, a.Item)
	end)

	-- free slots (lowest index first), then the slots being vacated
	local targets = {}
	for slot = 1, slots do
		if displays[tostring(slot)] == nil then
			table.insert(targets, { Slot = slot })
		end
	end
	for _, out in outgoing do
		table.insert(targets, { Slot = out.Slot, Replaces = out.Item })
	end

	local plan = { Add = {}, Return = {} }
	local after = table.clone(displays)
	local targetIndex = 1
	for index = 1, math.min(slots, #pool) do
		local entry = pool[index]
		if entry.Slot == nil then
			local target = targets[targetIndex]
			if not target then
				break
			end
			targetIndex += 1
			table.insert(plan.Add, { Item = entry.Item, Slot = target.Slot, Replaces = target.Replaces })
			if target.Replaces then
				table.insert(plan.Return, { Item = target.Replaces, Slot = target.Slot })
			end
			after[tostring(target.Slot)] = entry.Item
		end
	end

	local parts = {}
	for _, add in plan.Add do
		table.insert(parts, tostring(add.Item.Id) .. ">" .. add.Slot)
	end
	plan.Signature = table.concat(parts, ",")
	plan.LuckBefore = GameMath.ShopLuck(displays)
	plan.LuckAfter = GameMath.ShopLuck(after)
	return plan
end

---------------------------------------------------------------------------
-- Total luck
---------------------------------------------------------------------------

-- Strongest active boost: (luck bonus, boost id, expiry). Boost Luck is additive (0.5 = +50 Luck).
function GameMath.ActiveBoost(boosts, now: number): (number, string?, number)
	local best, bestId, bestEnds = 0, nil, 0
	for id, expiry in boosts or {} do
		local def = Equipment.ById.Boost[id]
		if def and expiry > now and def.Luck > best then
			best, bestId, bestEnds = def.Luck, id, expiry
		end
	end
	return best, bestId, bestEnds
end

--[[
	Luck is ADDITIVE. Every source adds Luck points (stored as fractions: 0.05 = +5 Luck):
	  level + detector + coil + shovel + trinkets + shop displays   (permanent)
	  + active boost + event                                       (temporary)
	The rarity roll uses Total = 1 + all of it (so +100 Luck doubles the base luck).
	Returns a breakdown table the UI can show line by line.
]]
function GameMath.ComputeLuck(data, now: number, eventBonus: number?, devBonus: number?)
	local eq = data.Equipment
	local detector = Equipment.ById.Detector[eq.Detector] or Equipment.Detectors[1]
	local shovel = Equipment.ById.Shovel[eq.Shovel] or Equipment.Shovels[1]

	local trinketLuck = 0
	for id, owned in data.Trinkets or {} do
		local trinket = Equipment.ById.Trinket[id]
		if owned and trinket then
			trinketLuck += trinket.Luck
		end
	end

	local shopLuck = GameMath.ShopLuck(data.Shop and data.Shop.Displays)
	local parts = {
		{ Name = "Level " .. data.Level, Value = (data.Level - 1) * Progression.LuckPerLevel },
		{ Name = detector.Name, Value = detector.Luck },
		{ Name = shovel.Name, Value = shovel.Luck },
		{ Name = "Trinkets", Value = trinketLuck },
		{ Name = "Shop displays", Value = shopLuck },
	}
	if devBonus and devBonus ~= 0 then
		-- developer test tools only (session-only, never saved)
		table.insert(parts, { Name = "🧪 Developer test bonus", Value = devBonus })
	end

	local permanent = 0
	for _, part in parts do
		permanent += part.Value
	end

	local boostBonus, boostId, boostEnds = GameMath.ActiveBoost(data.Boosts, now)
	local event = eventBonus or 0
	local all = permanent + boostBonus + event

	return {
		Total = 1 + all, -- multiplier used by the rarity roll
		Points = all, -- everything, shown as "+N Luck"
		Permanent = permanent,
		Parts = parts,
		ShopLuck = shopLuck,
		BoostBonus = boostBonus,
		BoostId = boostId,
		BoostEnds = boostEnds,
		EventBonus = event,
	}
end

---------------------------------------------------------------------------
-- Rarity rolls
---------------------------------------------------------------------------

--[[
	Each rarity's weight is multiplied by Luck ^ LuckPower.
	Common has LuckPower 0, so Luck never lowers its weight - it only makes rarer
	things relatively more likely. Common is also floored at MinCommonChance.
]]
function GameMath.GetChances(zoneId: string, luck: number, depth: number?)
	local zone = Zones.Info[zoneId] or Zones.Info.StartingBeach
	local depthLuck = GameConfig.DepthLuck[depth or 1] or 1
	local effective = math.max(1, (luck or 1) * depthLuck)

	local weights = {}
	local total = 0
	for _, name in Rarities.Order do
		local weight = (zone.Weights[name] or 0) * effective ^ Rarities.Info[name].LuckPower
		weights[name] = weight
		total += weight
	end

	local chances = {}
	for name, weight in weights do
		chances[name] = weight / total
	end

	local floor = GameConfig.MinCommonChance
	if chances.Common < floor then
		local scale = (1 - floor) / (1 - chances.Common)
		for name, chance in chances do
			if name ~= "Common" then
				chances[name] = chance * scale
			end
		end
		chances.Common = floor
	end
	return chances
end

function GameMath.RollRarity(zoneId: string, luck: number, depth: number?, rng: Random): string
	local chances = GameMath.GetChances(zoneId, luck, depth)
	local roll = rng:NextNumber()
	local running = 0
	for _, name in Rarities.Order do
		running += chances[name]
		if roll <= running then
			return name
		end
	end
	return "Common"
end

-- Quality 0.80 - 1.60. Luck gently pushes it upward.
function GameMath.RollQuality(rng: Random, luck: number?): number
	local skew = 2.2 / math.clamp((luck or 1) ^ 0.25, 1, 2)
	local quality = 0.8 + 0.8 * rng:NextNumber() ^ skew
	return math.floor(quality * 100 + 0.5) / 100
end

GameMath.QualityTiers = {
	{ Min = 1.45, Name = "Flawless" },
	{ Min = 1.25, Name = "Pristine" },
	{ Min = 1.0, Name = "Fine" },
	{ Min = 0, Name = "Worn" },
}

function GameMath.QualityName(quality: number?): string
	for _, tier in GameMath.QualityTiers do
		if (quality or 1) >= tier.Min then
			return tier.Name
		end
	end
	return "Worn"
end

---------------------------------------------------------------------------
-- Equipment stats
---------------------------------------------------------------------------

function GameMath.GetShovel(data)
	return Equipment.ById.Shovel[data.Equipment.Shovel] or Equipment.Shovels[1]
end

function GameMath.DetectorStats(data)
	local eq = data.Equipment
	local detector = Equipment.ById.Detector[eq.Detector] or Equipment.Detectors[1]
	local shovel = GameMath.GetShovel(data)
	-- the coil is built into the detector, so its stats are the detector's
	return {
		Range = detector.Range,
		Accuracy = math.min(1, detector.Accuracy),
		Depth = math.min(3, detector.Depth),
		RarityHint = detector.RarityHint,
		BonusChance = shovel.BonusChance,
	}
end

---------------------------------------------------------------------------
-- Resistance-based digging
---------------------------------------------------------------------------

-- Raw resistance of a buried treasure (rarity x depth)
--[[
	Digging difficulty (all hidden - the bar never shows numbers)

	  resistance   beach x rarity x depth: how much sand stands between you and the treasure
	  recommended  the shovel tier the treasure is balanced for (beach, +rarity, +depth)
	  gap          recommended - your shovel's tier (> 0 = under-levelled shovel)

	Every shovel can dig every treasure. The gap only changes how it FEELS:
	  * progress per click   = ClickGain x shovel Power / resistance, cut for each tier under
	  * the pull (Update 17) = NO grace period: the sand pulls the bar back continuously, even
	                           between fast clicks. About 1 click's worth per second with the right
	                           shovel, +50% per tier under, -20% per tier over, scaled by the shovel's
	                           DecayMult, growing up to 2x while you don't click at all.
	  * always winnable      = the pull is capped at half the shovel's top click speed, so clicking
	                           fast always outpaces it - however under-levelled the shovel.
	  * permanent failure    = once the hole has a foothold (10-30% of the bar), letting it fall back
	                           to empty loses the treasure for good (TreasureService).
]]
local function zoneIndex(zoneId: string?): number
	local zone = if zoneId then Zones.Info[zoneId] else nil
	return if zone then zone.Index else 1
end

function GameMath.RecommendedShovelTier(zoneId: string?, rarity: string, depth: number?): number
	local cfg = GameConfig.Dig
	local tier = (cfg.ZoneShovelTier[zoneIndex(zoneId)] or 1)
		+ (cfg.RarityTierBonus[Rarities.Tier(rarity)] or 0)
		+ (cfg.DepthTierBonus[depth or 1] or 0)
	return math.min(tier, cfg.MaxRecommendedTier)
end

function GameMath.DigResistance(zoneId: string?, rarity: string, depth: number?): number
	local cfg = GameConfig.Dig
	return (cfg.ZoneResistance[zoneIndex(zoneId)] or 1)
		* (cfg.RarityResistance[Rarities.Tier(rarity)] or 1)
		* (cfg.DepthResistance[depth or 1] or 1)
end

--[[
	Everything about digging one treasure with one shovel:
	  Gain        progress per counted click (1 = done)
	  DecayRate   progress the sand pulls back per second while you keep clicking (no grace)
	  IdleBoost   how much stronger the pull gets when you stop clicking (+100% = double) ...
	  IdleRamp    ... reached after this many seconds without a click
	  Foothold    progress at which the treasure is "at stake": falling back to 0 from here loses it
	  MinInterval fastest click that still counts (1 / shovel Speed)
	All hidden from players: the client only animates the bar with them.
]]
function GameMath.DigProfile(zoneId: string?, rarity: string, depth: number?, shovel, speedMult: number?)
	local cfg = GameConfig.Dig
	local recommended = GameMath.RecommendedShovelTier(zoneId, rarity, depth)
	local gap = recommended - (shovel.Order or 1)
	local resistance = GameMath.DigResistance(zoneId, rarity, depth)
	local fit = if gap > 0 then 1 / (1 + cfg.UnderTierPenalty * gap) else math.min(cfg.OverTierMax, 1 + cfg.OverTierBonus * -gap)
	local baseGain = math.max(cfg.ClickGain * shovel.Power / resistance * fit, 1 / cfg.MaxClicks)
	local gain = math.min(1, baseGain * (speedMult or 1)) -- events like Treasure Rush speed up digging, not the pull
	-- the pull, in clicks' worth per second
	local pull = if gap > 0 then 1 + cfg.DecayPerTierUnder * gap else math.max(cfg.DecayMinMult, 1 - cfg.DecayPerTierOver * -gap)
	local shovelGrip = (1 - cfg.DecayShovelWeight) + cfg.DecayShovelWeight * (shovel.DecayMult or 1)
	local clicksPerSecond = math.min(cfg.DecayClicks * pull * shovelGrip, cfg.DecayMaxShare * shovel.Speed, cfg.DecayMaxClicks)
	return {
		Tier = Rarities.Tier(rarity),
		Recommended = recommended, -- hidden: never shown to players
		Gap = gap,
		Resistance = resistance, -- hidden
		Gain = gain,
		DecayRate = math.min(1, baseGain) * clicksPerSecond, -- (a one-click dig has nothing to pull back)
		PullClicks = clicksPerSecond, -- hidden (tests / balancing)
		IdleBoost = cfg.IdleBoost,
		IdleRamp = cfg.IdleRamp,
		Foothold = math.clamp(cfg.FootholdClicks * gain, cfg.FootholdMin, cfg.FootholdMax),
		MinInterval = 1 / shovel.Speed,
	}
end

-- Progress the sand pulls back between two moments, measured in seconds since the last click.
-- The pull starts at once (no grace) and grows while nobody clicks.
-- (Used by the server for the real value and by the client to animate the bar between messages.)
function GameMath.DigDecay(profile, fromIdle: number, toIdle: number): number
	local ramp = math.max(profile.IdleRamp or 1, 0.01)
	local boost = profile.IdleBoost or 0
	local function pulled(idle: number): number
		local t = math.max(0, idle)
		local extra = if t <= ramp then t * t / (2 * ramp) else ramp / 2 + (t - ramp)
		return t + boost * extra
	end
	return math.max(0, profile.DecayRate * (pulled(toIdle) - pulled(fromIdle)))
end

-- Clicks it really takes with the pull, clicking steadily at clicksPerSecond (nil = never finishes).
-- Balancing / tests only.
function GameMath.DigClicksAt(profile, clicksPerSecond: number): number?
	local rate = math.min(clicksPerSecond, 1 / profile.MinInterval)
	local net = profile.Gain - GameMath.DigDecay(profile, 0, 1 / rate)
	if net <= 0 then
		return nil
	end
	return math.ceil(1 / net)
end

-- Counted clicks with no pull at all (the floor)
function GameMath.ClicksNeeded(zoneId: string?, rarity: string, depth: number?, shovel): number
	return math.ceil(1 / GameMath.DigProfile(zoneId, rarity, depth, shovel).Gain - 1e-9)
end

function GameMath.Capacity(_data): number
	return GameConfig.BackpackCapacity -- fixed size, never upgraded
end

function GameMath.ShopSlots(data): number
	local shopLevel = Equipment.ShopLevels[data.Shop.Level or 1] or Equipment.ShopLevels[1]
	return shopLevel.Slots
end

-- Value multiplier of the best zone a player has unlocked (used to scale quest rewards)
function GameMath.BestZoneMult(data): number
	local best = 1
	for _, zoneId in Zones.Order do
		if data.Zones[zoneId] then
			best = math.max(best, Zones.Info[zoneId].ValueMult)
		end
	end
	return best
end

-- Current value of an achievement stat (see Config > Achievements). Works on server data
-- and on the client's state view (same field names).
function GameMath.AchievementStat(data, stat: string): number
	local stats = data.Stats
	if stat == "Found" then
		return stats.Found
	elseif stat == "Digs" then
		return stats.Digs
	elseif stat == "Level" then
		return data.Level
	elseif stat == "CashEarned" then
		return stats.CashEarned
	elseif stat == "BoostsUsed" then
		return stats.BoostsUsed
	elseif stat == "Displayed" then
		return GameMath.CountDisplays(data.Shop.Displays)
	elseif stat == "ShopValue" then
		return GameMath.ShopValue(data.Shop.Displays)
	elseif stat == "IndexCount" or stat == "IndexPercent" then
		local count = GameMath.IndexCount(data.Index)
		return if stat == "IndexCount" then count else count / Treasures.Count
	end
	local kind, arg = string.match(stat, "^(%w+):(%w+)$")
	if kind == "TierCount" then
		local minTier = tonumber(arg) or 1
		local total = 0
		for rarity, count in stats.Rarity do
			if Rarities.Tier(rarity) >= minTier then
				total += count
			end
		end
		return total
	elseif kind == "ZoneFinds" then
		return stats.ZoneFinds[arg] or 0
	elseif kind == "ZoneUnlocked" then
		return if data.Zones[arg] then 1 else 0
	end
	return 0
end

function GameMath.IndexCount(index): number
	local count = 0
	for id in index or {} do
		if Treasures.ById[id] then
			count += 1
		end
	end
	return count
end

--[[
	What became AVAILABLE when a player went from level `fromLevel` to `toLevel` (exclusive / inclusive).
	Only things whose level requirement lies in that range are listed, so nothing that was already
	available is announced again, and nothing is bought or equipped. Each entry: { Kind, Text }.
]]
function GameMath.NewlyAvailable(fromLevel: number, toLevel: number, data): { { Kind: string, Text: string } }
	local list = {}
	local function inRange(level: number?): boolean
		return level ~= nil and level > fromLevel and level <= toLevel
	end
	local function owned(category: string, id: string): boolean
		return data ~= nil and data.Owned ~= nil and data.Owned[category] ~= nil and data.Owned[category][id] == true
	end
	for _, def in Equipment.Detectors do
		if inRange(def.Level) and def.Price > 0 and not owned("Detector", def.Id) then
			table.insert(list, { Kind = "Equipment", Text = def.Name .. " Available in Equipment Shop" })
		end
	end
	for _, def in Equipment.Shovels do
		if inRange(def.Level) and def.Price > 0 and not owned("Shovel", def.Id) then
			table.insert(list, { Kind = "Equipment", Text = def.Name .. " Available in Equipment Shop" })
		end
	end
	for _, def in Equipment.Boosts do
		if inRange(def.Level) then
			table.insert(list, { Kind = "Equipment", Text = def.Name .. " Boost Available in Equipment Shop" })
		end
	end
	for _, def in Equipment.Skins do
		if inRange(def.Level) and def.Price > 0 and not owned("Skin", def.Id) then
			table.insert(list, { Kind = "Cosmetic", Text = def.Name .. " Detector Skin Available in Equipment Shop" })
		end
	end
	for _, zoneId in Zones.Order do
		local zone = Zones.Info[zoneId]
		local unlocked = data ~= nil and data.Zones ~= nil and data.Zones[zoneId] == true
		if inRange(zone.Level) and not unlocked and not zone.RequiresDiscovery then
			table.insert(list, { Kind = "Beach", Text = zone.Name .. " Available to Unlock" })
		end
	end
	for index, def in Equipment.ShopLevels do
		local bought = data ~= nil and data.Shop ~= nil and (data.Shop.Level or 1) >= index
		if inRange(def.Level) and def.Price > 0 and not bought then
			table.insert(list, { Kind = "Shop", Text = "New Shop Upgrade Available: " .. def.Name })
		end
	end
	for _, def in Equipment.Themes do
		if inRange(def.Level) and def.Price > 0 and not owned("Theme", def.Id) then
			table.insert(list, { Kind = "Shop", Text = def.Name .. " Shop Theme Available" })
		end
	end
	for _, def in Treasures.List do
		if inRange(def.MinLevel) then
			table.insert(list, { Kind = "Feature", Text = def.Name .. " can now be found" })
		end
	end
	return list
end

return GameMath
