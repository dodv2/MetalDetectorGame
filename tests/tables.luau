local H = require("./harness")
local E = H.require("src/shared/Config/Equipment")
local Z = H.require("src/shared/Config/Zones")
local R = H.require("src/shared/Config/Rarities")
local G = H.require("src/shared/GameMath")
local F = H.require("src/shared/Format")
local GC = H.require("src/shared/Config/GameConfig")
print("| Detector | Level | Price | Range | Accuracy | Depth | Luck | Rarity hint |")
for _, d in E.Detectors do
	print(string.format("| %s | %d | %s | %s | %d%% | %s | %s | %s |", d.Name, d.Level, d.Price == 0 and "Free" or F.Cash(d.Price), F.Meters(d.Range), d.Accuracy*100, GC.DepthNames[d.Depth], F.Percent(d.Luck), d.RarityHint and "Yes" or "No"))
end
print("\n| Zone | Level | Unlock | Legendary (no luck) | Mythical | Secret | XP |")
for _, id in Z.Order do
	local z = Z.Info[id]; local c = G.GetChances(id, 1, 1)
	print(string.format("| %s | %d | %s | %.2f%% | %.3f%% | %.4f%% | x%s |", z.Name, z.Level, z.Price == 0 and "Free" or F.Cash(z.Price), c.Legendary*100, c.Mythical*100, c.Secret*100, tostring(z.XPMult)))
end
print("\n| Rarity | Luck power | Display luck | XP |")
for _, n in R.Order do local r = R.Info[n]; print(string.format("| %s %s | %s | %s | %d |", r.Glyph, n, tostring(r.LuckPower), F.Percent(r.DisplayLuck), r.XP)) end
print("\n| Shop | Level | Price | Slots |")
for _, s in E.ShopLevels do print(string.format("| %s | %d | %s | %d |", s.Name, s.Level, s.Price==0 and "Free" or F.Cash(s.Price), s.Slots)) end
print("\nCoils:") for _, s in E.Coils do print(s.Name, s.Level, F.Cash(s.Price)) end
print("\nShovels:") for _, s in E.Shovels do print(s.Name, s.Level, F.Cash(s.Price), s.Power) end
print("\nBackpacks:") for _, s in E.Backpacks do print(s.Name, s.Level, F.Cash(s.Price), s.Capacity) end
