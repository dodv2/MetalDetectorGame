local H = require("./harness")
local base = "src/shared"
local Rarities = H.require(base .. "/Config/Rarities")
local Zones = H.require(base .. "/Config/Zones")
local Treasures = H.require(base .. "/Config/Treasures")
local Equipment = H.require(base .. "/Config/Equipment")
local Achievements = H.require(base .. "/Config/Achievements")
local Quests = H.require(base .. "/Config/Quests")
local Events = H.require(base .. "/Config/Events")
local GameMath = H.require(base .. "/GameMath")
local Format = H.require(base .. "/Format")

local fails = 0
local function check(cond, msg) if not cond then fails += 1; print("FAIL: " .. msg) end end

-- every zone has at least one treasure for every rarity (at max level)
for _, zoneId in Zones.Order do
	for _, r in Rarities.Order do
		check(#Treasures.GetPool(zoneId, r, 100) > 0, zoneId .. " missing " .. r)
	end
	-- at level 1, Common must exist
	check(#Treasures.GetPool(zoneId, "Common", 1) > 0, zoneId .. " no level-1 commons")
end
-- shapes valid
local fs = require("@lune/fs")
local TM_shapes = {}
for name in string.gmatch(fs.readFile("src/shared/TreasureModels.lua"), "function Builders%.([%w_]+)") do
	TM_shapes[name] = 1
end
for _, def in Treasures.List do
	check(TM_shapes[def.Shape] ~= nil, "bad shape " .. def.Shape)
	check(Rarities.Info[def.Rarity] ~= nil, "bad rarity " .. def.Id)
	check(def.Zone == "Event" or Zones.Info[def.Zone] ~= nil, "bad zone " .. def.Id)
	if def.Event then check(Events.ById[def.Event] ~= nil, "bad event " .. def.Id) end
end
check(Treasures.ById[Zones.Info.SecretIsland.RequiresDiscovery] ~= nil, "secret island requirement missing")
-- achievements reference valid trinkets / zones
for _, a in Achievements.List do
	if a.Reward.Trinket then check(Equipment.ById.Trinket[a.Reward.Trinket] ~= nil, "bad trinket " .. a.Id) end
	local kind, arg = string.match(a.Stat, "^(%w+):(%w+)$")
	if kind == "ZoneFinds" or kind == "ZoneUnlocked" then check(Zones.Info[arg] ~= nil, "bad zone in " .. a.Id) end
end
-- every trinket is obtainable
for _, t in Equipment.Trinkets do
	local found = false
	for _, a in Achievements.List do if a.Reward.Trinket == t.Id then found = true end end
	check(found, "trinket not obtainable " .. t.Id)
end

-- chances sum to 1 and luck increases rare odds without removing commons
for _, zoneId in Zones.Order do
	for _, luck in { 1, 2, 10, 100, 10000 } do
		local c = GameMath.GetChances(zoneId, luck, 3)
		local s = 0
		for _, p in c do s += p end
		check(math.abs(s - 1) < 1e-6, "chances don't sum to 1")
		check(c.Common >= 0.08 - 1e-9, "common below floor")
	end
	local a, b = GameMath.GetChances(zoneId, 1, 1), GameMath.GetChances(zoneId, 5, 1)
	check(b.Legendary > a.Legendary and b.Secret > a.Secret, "luck doesn't help")
end

-- print a balance table
print("\nZone rarity odds at luck 1 / luck 3 (depth 1):")
for _, zoneId in Zones.Order do
	local c1, c3 = GameMath.GetChances(zoneId, 1, 1), GameMath.GetChances(zoneId, 3, 1)
	local ev = 0
	for _, r in Rarities.Order do
		local pool = Treasures.GetPool(zoneId, r, 100)
		local avg = 0
		for _, d in pool do avg += d.Value end
		avg /= #pool
		ev += c1[r] * avg
	end
	print(string.format("%-15s Leg %.2f%%->%.2f%%  Myth %.3f%%->%.3f%%  Sec %.4f%%->%.4f%%  avg value %s", zoneId,
		c1.Legendary*100, c3.Legendary*100, c1.Mythical*100, c3.Mythical*100, c1.Secret*100, c3.Secret*100, Format.Cash(ev * 1.12)))
end

local fakeData = { Level = 10, Equipment = { Detector = "TideSeeker", Shovel = "SandSifter" },
	Trinkets = { LuckyDoubloon = true }, Shop = { Level = 2, Displays = { ["1"] = { TreasureId = "PirateDoubloon", Quality = 1.2, Value = 1400, Zone = "StartingBeach" } } },
	Boosts = { LuckyCharm = os.time() + 100 }, Zones = { StartingBeach = true, RockyShore = true } }
local luck = GameMath.ComputeLuck(fakeData, os.time(), 2)
print("\nSample luck:", Format.Luck(luck.Points), "roll x" .. luck.Total, "boost", luck.BoostBonus)
for _, p in luck.Parts do print("  ", p.Name, Format.Percent(p.Value)) end
print("Detector stats:", GameMath.DetectorStats(fakeData).Range, GameMath.DetectorStats(fakeData).Depth)
local unlockTexts = {}
for _, entry in GameMath.NewlyAvailable(9, 10, fakeData) do
	table.insert(unlockTexts, entry.Text)
end
print("Available at 10:", table.concat(unlockTexts, "; "))
print("Format:", Format.Number(1234), Format.Number(999), Format.Number(100000), Format.Number(1500000), Format.Commas(1234567), Format.Percent(0.125), Format.Time(3725), Format.Meters(20))
print(fails == 0 and "\nALL CONFIG CHECKS PASSED" or ("\n" .. fails .. " FAILURES"))
