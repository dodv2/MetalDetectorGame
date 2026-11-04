-- Place Best Items + dig balance sanity checks (run: lune run tests/shop_test.luau)
local H = require("./harness")
local base = "src/shared"
local Treasures = H.require(base .. "/Config/Treasures")
local Rarities = H.require(base .. "/Config/Rarities")
local Equipment = H.require(base .. "/Config/Equipment")
local GameMath = H.require(base .. "/GameMath")

local fails = 0
local function check(cond, msg) if not cond then fails += 1; print("FAIL: " .. msg) end end

local function firstOf(rarity)
	for _, def in Treasures.List do
		if def.Rarity == rarity and def.Zone ~= "Event" then return def end
	end
end
local nextId = 0
local function item(rarity, value)
	nextId += 1
	return { Id = tostring(nextId), TreasureId = firstOf(rarity).Id, Value = value, Quality = 1, Zone = "StartingBeach" }
end

-- 3 slots: 1 empty, 2 filled with a Common and a Rare; backpack has Epic, Legendary, Common(high value)
local commonShown, rareShown = item("Common", 5), item("Rare", 80)
local displays = { ["1"] = commonShown, ["3"] = rareShown }
local epic, legendary, bigCommon = item("Epic", 300), item("Legendary", 1200), item("Common", 50)
local inventory = { epic, legendary, bigCommon }
local plan = GameMath.PlanBestDisplays(inventory, displays, 3)

-- best 3 overall: Legendary, Epic, Rare -> add 2, return the shown Common, keep the Rare
check(#plan.Add == 2, "expected 2 adds, got " .. #plan.Add)
check(#plan.Return == 1 and plan.Return[1].Item == commonShown, "expected shown Common returned")
local addedItems = {}
for _, add in plan.Add do addedItems[add.Item] = add end
check(addedItems[legendary] ~= nil and addedItems[epic] ~= nil, "Legendary + Epic should be added")
check(addedItems[bigCommon] == nil, "Common should not be added")
-- empty slot 2 filled first, slot 1 (weak Common) replaced
local slots = {}
for _, add in plan.Add do slots[add.Slot] = add end
check(slots[2] ~= nil and slots[2].Replaces == nil, "empty slot 2 filled first")
check(slots[1] ~= nil and slots[1].Replaces == commonShown, "slot 1 swaps out the Common")
check(slots[3] == nil, "slot 3 (Rare) untouched")
check(plan.LuckAfter > plan.LuckBefore, "luck should go up")

-- conservation: simulate the move and make sure nothing is lost or duplicated
local after, bag = table.clone(displays), table.clone(inventory)
for _, add in plan.Add do
	local idx = table.find(bag, add.Item); check(idx ~= nil, "added item must be in bag")
	table.remove(bag, idx)
	local prev = after[tostring(add.Slot)]
	if prev then table.insert(bag, prev) end
	after[tostring(add.Slot)] = add.Item
end
local seen, total = {}, 0
for _, it in after do check(not seen[it], "dup in shop"); seen[it] = true; total += 1 end
for _, it in bag do check(not seen[it], "dup across bag/shop"); seen[it] = true; total += 1 end
check(total == 5, "5 items before and after, got " .. total)
check(#bag <= #inventory, "backpack never grows")

-- nothing better -> no adds
local plan2 = GameMath.PlanBestDisplays({ item("Common", 1) }, { ["1"] = item("Epic", 300) }, 1)
check(#plan2.Add == 0, "no change when shop already best")
-- tie on rarity -> higher value wins
local lowRare, highRare = item("Rare", 70), item("Rare", 95)
local plan3 = GameMath.PlanBestDisplays({ highRare }, { ["1"] = lowRare }, 1)
check(#plan3.Add == 1 and plan3.Add[1].Item == highRare and plan3.Return[1].Item == lowRare, "same rarity: higher value replaces")

-- Update 16 digging balance (a tug of war): EVERY shovel can dig EVERY treasure on EVERY beach,
-- better shovels are never slower, higher beaches ask for more clicks, and an under-levelled
-- shovel both gains less per click and gets pulled back sooner and harder.
local Zones = H.require(base .. "/Config/Zones")
local GameConfig = H.require(base .. "/Config/GameConfig")
local starter = Equipment.Shovels[1]
-- Update 17: no grace period, the sand pulls back all the time; failing to keep up loses the treasure.
for _, zoneId in Zones.Order do
	for _, rarity in Rarities.Order do
		for depth = 1, 3 do
			local last = math.huge
			local lastPull = math.huge
			for _, shovel in Equipment.Shovels do
				local clicks = GameMath.ClicksNeeded(zoneId, rarity, depth, shovel)
				local profile = GameMath.DigProfile(zoneId, rarity, depth, shovel)
				local tag = zoneId .. " " .. rarity .. " d" .. depth .. " " .. shovel.Id
				check(clicks <= GameConfig.Dig.MaxClicks, "counted clicks capped: " .. tag)
				check(clicks <= last, "better shovel never slower: " .. tag)
				check(clicks >= 1, "at least one click")
				-- clicking at the shovel's top speed ALWAYS beats the pull (never mathematically impossible)
				check(GameMath.DigClicksAt(profile, 1 / profile.MinInterval) ~= nil, "always winnable at full speed: " .. tag)
				-- with the recommended (or a better) shovel, a relaxed 3 clicks a second is enough
				if profile.Gap <= 0 then
					check(GameMath.DigClicksAt(profile, 3) ~= nil, "right shovel: 3 clicks/s wins: " .. tag)
				end
				-- pull-back measured in clicks per second: better shovels are more forgiving
				local pull = profile.DecayRate / profile.Gain
				check(pull <= lastPull + 1e-6, "better shovel never pulls back harder: " .. tag)
				check(profile.Foothold >= 0.1 - 1e-9 and profile.Foothold <= 0.3 + 1e-9, "foothold 10-30%: " .. tag)
				last, lastPull = clicks, pull
			end
		end
	end
end
check(GameMath.ClicksNeeded("StartingBeach", "Common", 1, starter) == 8, "starter + common on the first beach = 8 counted clicks")
check(GameMath.DigClicksAt(GameMath.DigProfile("StartingBeach", "Common", 1, starter), 5) <= 12, "starter + common at 5 clicks/s stays quick")
check(GameMath.DigClicksAt(GameMath.DigProfile("SecretIsland", "Secret", 3, starter), 6) ~= nil, "starter + deep secret on the last beach is still possible")
check(GameMath.ClicksNeeded("StartingBeach", "Secret", 1, starter) >= 3 * GameMath.ClicksNeeded("StartingBeach", "Rare", 1, starter), "secret clearly harder than rare")
-- every beach has its own recommended shovel, and higher beaches are harder with it
local lastBeach = 0
for index, zoneId in Zones.Order do
	local own = Equipment.Shovels[math.min(index, #Equipment.Shovels)]
	check(GameMath.RecommendedShovelTier(zoneId, "Common", 1) == math.min(index, #Equipment.Shovels), "beach " .. zoneId .. " recommends shovel tier " .. index)
	local clicks = GameMath.ClicksNeeded(zoneId, "Common", 1, own)
	check(clicks >= lastBeach, "higher beach is never easier with its own shovel: " .. zoneId)
	lastBeach = clicks
	-- one tier under on THIS beach is clearly harder than its own shovel (every beach, not just one)
	if index > 1 then
		local under = GameMath.DigProfile(zoneId, "Common", 1, Equipment.Shovels[index - 1])
		local right = GameMath.DigProfile(zoneId, "Common", 1, own)
		check(under.DecayRate / under.Gain > right.DecayRate / right.Gain, "under-tiered pulls harder on " .. zoneId)
		check(under.Gain < right.Gain, "under-tiered gains less on " .. zoneId)
	end
end
check(lastBeach > GameMath.ClicksNeeded("StartingBeach", "Common", 1, starter), "the last beach really is harder")
-- under-levelled vs right shovel on the same treasure
local under = GameMath.DigProfile("ShipwreckCoast", "Epic", 1, starter)
local right = GameMath.DigProfile("ShipwreckCoast", "Epic", 1, Equipment.Shovels[6])
check(under.Gap > 0 and right.Gap <= 0, "gap sign")
check(under.DecayRate / under.Gain > 2 * right.DecayRate / right.Gain, "under-levelled: much stronger pull-back")
check(1 / under.Gain > 3 / right.Gain, "under-levelled: many more clicks")
check(GameMath.DigClicksAt(under, 3) == nil, "under-levelled: slow clicking can't win")
-- no grace: the pull starts at once, and grows while nobody clicks
check(GameMath.DigDecay(right, 0, 0.1) > 0, "pull starts immediately (no grace)")
local firstSecond = GameMath.DigDecay(right, 0, 1)
local secondSecond = GameMath.DigDecay(right, 1, 2)
check(firstSecond > 0 and secondSecond > firstSecond, "pull grows while idle")
-- Update 16 prices: gentle early steps, bigger mid gaps, steep late game
local function ratios(list)
	local out = {}
	for i = 3, #list do
		table.insert(out, list[i].Price / list[i - 1].Price)
	end
	return out
end
for _, list in { Equipment.Detectors, Equipment.Shovels, Equipment.ShopLevels } do
	for i = 2, #list do
		check(list[i].Price > list[i - 1].Price, list[i].Id .. " costs more than the one before")
	end
	local r = ratios(list)
	check(r[#r] >= r[1], "late-game steps are at least as steep as early ones")
	check(list[#list].Price >= 6000000, list[#list].Id .. " is a real late-game goal")
	check(list[2].Price <= 2000, list[2].Id .. " is an affordable first upgrade")
end
check(GameMath.DigProfile("StartingBeach", "Common", 1, starter).Strike == nil, "no numeric strike shown any more")
for _, shovel in Equipment.Shovels do
	check(shovel.MaxTier == nil, shovel.Id .. " must not gate rarities")
end
-- section 14: fixed backpack, coils built into detectors, shop upgrades carry unlock text
check(Equipment.Backpacks == nil and GameMath.Capacity({ Equipment = { Backpack = 5 } }) == 10, "backpack fixed at 10")
check(Equipment.Coils == nil and Equipment.ById.Coil == nil, "no separate coils")
for index, detector in Equipment.Detectors do
	check(type(detector.Coil) == "string" and type(detector.CoilSize) == "number", detector.Id .. " has a built-in coil")
	if index > 1 then
		local previous = Equipment.Detectors[index - 1]
		check(detector.Range > previous.Range and detector.Accuracy >= previous.Accuracy and detector.Luck > previous.Luck, detector.Id .. " improves on the last")
	end
end
for _, level in Equipment.ShopLevels do
	check(type(level.Unlocks) == "string", level.Id .. " lists its unlocks")
end
-- level-up availability: only things in (from, to], never already-owned or already-unlocked
local data = { Owned = { Shovel = { StarterShovel = true } }, Zones = { StartingBeach = true }, Shop = { Level = 1 } }
local function texts(list)
	local out = {}
	for _, entry in list do
		out[entry.Text] = true
	end
	return out
end
local at4 = texts(GameMath.NewlyAvailable(3, 4, data))
check(at4["Iron Shovel Available in Equipment Shop"], "Iron Shovel announced at level 4")
check(at4["Rocky Shore Available to Unlock"], "Rocky Shore announced at level 4")
check(at4["New Shop Upgrade Available: Seaside Shack"], "shop upgrade announced at level 4")
check(not at4["Wooden Shovel Available in Equipment Shop"], "level-2 shovel not re-announced at 4")
local multi = texts(GameMath.NewlyAvailable(1, 4, data))
check(multi["Wooden Shovel Available in Equipment Shop"] and multi["Iron Shovel Available in Equipment Shop"], "multi-level jump lists every new unlock")
data.Owned.Shovel.IronShovel = true
data.Zones.RockyShore = true
local owned = texts(GameMath.NewlyAvailable(3, 4, data))
check(not owned["Iron Shovel Available in Equipment Shop"] and not owned["Rocky Shore Available to Unlock"], "owned / unlocked things are not announced")

print(if fails == 0 then "shop_test: all passed" else ("shop_test: " .. fails .. " failures"))
