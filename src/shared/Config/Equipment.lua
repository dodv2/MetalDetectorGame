--[[
	Equipment
	Everything sold in the Equipment Shop, plus shop upgrades/themes (bought inside your own
	Treasure Shop) and Trinkets (earned only, never sold).

	Detectors   Range (studs), Accuracy (0-1, lower = noisier distance/direction readings),
	            Depth (1-3, how deep it can sense), Luck (+0.05 = +5 Luck), RarityHint (shows rarity before digging).
	            Every detector has its own INTEGRATED COIL (Coil = name, CoilSize = radius of the 3D coil):
	            buying a better detector upgrades the coil, range, signal and depth together.
	Shovels     PASSIVE gear (never held by hand): Power, Speed, DecayMult, BonusChance, Luck
	Boosts      temporary Luck. Buying again adds time (max 2 hours total).
	ShopLevels  personal shop upgrades (display slots + new decor). Bought in order, in your own shop.
	Skins       cosmetic detector paint jobs
	Themes      cosmetic personal-shop decoration themes (bought in your own shop)
	Trinkets    earned from achievements; permanent Luck bonus
	The backpack always holds GameConfig.BackpackCapacity (10) treasures - it can't be upgraded.
]]

local function index(list)
	local byId = {}
	for i, def in list do
		def.Order = i
		byId[def.Id] = def
	end
	return byId
end

local Equipment = {}

Equipment.Detectors = {
	{ Id = "RustyBeeper", Name = "Rusty Beeper", Price = 0, Level = 1, Range = 20, Accuracy = 0.55, Depth = 1, Luck = 0, RarityHint = false,
		Coil = "Stock Coil", CoilSize = 0.9, Description = "Grandpa's old detector and its stock coil. It beeps... eventually." },
	{ Id = "BeachBuddy", Name = "Beach Buddy", Price = 250, Level = 3, Range = 27, Accuracy = 0.66, Depth = 1, Luck = 0.05, RarityHint = false,
		Coil = "Wide Scan Coil", CoilSize = 1.05, Description = "A friendly starter detector with a wider coil and a clearer signal." },
	{ Id = "SandScanner", Name = "Sand Scanner 2000", Price = 1200, Level = 6, Range = 36, Accuracy = 0.78, Depth = 2, Luck = 0.1, RarityHint = false,
		Coil = "Wide Scan Coil", CoilSize = 1.15, Description = "Senses medium-depth treasures that older detectors miss." },
	{ Id = "TideSeeker", Name = "Tide Seeker", Price = 7500, Level = 10, Range = 50, Accuracy = 0.87, Depth = 2, Luck = 0.21, RarityHint = true,
		Coil = "Double-D Coil", CoilSize = 1.15, Description = "Double-D coil cuts through wet sand. Shows the rarity of strong signals." },
	{ Id = "DeepPulse", Name = "Deep Pulse X", Price = 60000, Level = 15, Range = 65, Accuracy = 0.93, Depth = 2, Luck = 0.33, RarityHint = true,
		Coil = "Double-D Coil", CoilSize = 1.2, Description = "Pulse electronics with a long reach." },
	{ Id = "AbyssHunter", Name = "Abyss Hunter 500", Price = 400000, Level = 21, Range = 90, Accuracy = 0.97, Depth = 3, Luck = 0.51, RarityHint = true,
		Coil = "Pulse Induction Coil", CoilSize = 1.25, Description = "Pulse-induction coil reaches deep treasures, where the rarest finds hide." },
	{ Id = "RelicOracle", Name = "Relic Oracle", Price = 2500000, Level = 28, Range = 125, Accuracy = 0.99, Depth = 3, Luck = 0.77, RarityHint = true,
		Coil = "Pulse Induction Coil", CoilSize = 1.3, Description = "Ancient-tech detector that hums near relics." },
	{ Id = "MythicResonator", Name = "Mythic Resonator", Price = 15000000, Level = 36, Range = 160, Accuracy = 1, Depth = 3, Luck = 1.02, RarityHint = true,
		Coil = "Quantum Coil", CoilSize = 1.35, Description = "Its glowing quantum coil resonates with treasure from across the beach." },
}

-- Shovels are passive equipment: owning a better one makes every dig easier, you never hold it
-- yourself (it appears in your hands only while you dig). Their tier (1-7, list order) is compared
-- with each treasure's hidden recommended tier (GameMath.DigProfile):
--   Power     = progress per click        (higher = fewer clicks)
--   Speed     = max clicks per second that count (anti auto-click cap, also swing speed)
--   DecayMult = how hard the sand pulls back (it never stops; lower = more forgiving)
-- Every shovel can dig every treasure - an under-levelled one just makes it a fight.
-- Look = colours/materials for the 3D shovel.
--
-- PRICES (Update 16): cheap, close steps early; noticeably bigger gaps mid-game; steep late game.
-- Rough guide = digs needed at the beach you're on when it unlocks (no Luck):
--   early 4-15 digs, mid 20-90, late 100-350.
Equipment.Shovels = {
	{ Id = "StarterShovel", Name = "Starter Shovel", Price = 0, Level = 1, Power = 1, Speed = 6,
		DecayMult = 1, BonusChance = 0, Luck = 0,
		Look = { Shaft = Color3.fromRGB(240, 200, 60), Blade = Color3.fromRGB(220, 70, 60), ShaftMaterial = "SmoothPlastic", BladeMaterial = "SmoothPlastic" },
		Description = "A bright plastic beach spade. Every journey starts somewhere!" },
	{ Id = "WoodenShovel", Name = "Wooden Shovel", Price = 150, Level = 2, Power = 1.4, Speed = 7,
		DecayMult = 0.95, BonusChance = 0, Luck = 0,
		Look = { Shaft = Color3.fromRGB(150, 105, 65), Blade = Color3.fromRGB(175, 130, 85), ShaftMaterial = "Wood", BladeMaterial = "WoodPlanks" },
		Description = "Sturdier and faster through soft sand." },
	{ Id = "IronShovel", Name = "Iron Shovel", Price = 600, Level = 4, Power = 2, Speed = 8,
		DecayMult = 0.85, BonusChance = 0.02, Luck = 0,
		Look = { Shaft = Color3.fromRGB(120, 85, 55), Blade = Color3.fromRGB(120, 124, 130), ShaftMaterial = "Wood", BladeMaterial = "CorrodedMetal" },
		Description = "Bites into packed sand much faster." },
	{ Id = "SteelShovel", Name = "Steel Shovel", Price = 4000, Level = 8, Power = 2.8, Speed = 9,
		DecayMult = 0.75, BonusChance = 0.04, Luck = 0.02,
		Look = { Shaft = Color3.fromRGB(40, 44, 52), Blade = Color3.fromRGB(205, 210, 220), ShaftMaterial = "Metal", BladeMaterial = "Metal" },
		Description = "Polished steel that keeps its grip. Sometimes sifts bonus coins." },
	{ Id = "GoldShovel", Name = "Gold Shovel", Price = 45000, Level = 15, Power = 3.8, Speed = 10,
		DecayMult = 0.65, BonusChance = 0.08, Luck = 0.03,
		Look = { Shaft = Color3.fromRGB(60, 40, 30), Blade = Color3.fromRGB(255, 200, 60), ShaftMaterial = "Wood", BladeMaterial = "Metal", Glow = true },
		Description = "Solid gold. Stubborn treasure gives way quickly." },
	{ Id = "DiamondShovel", Name = "Diamond Shovel", Price = 650000, Level = 24, Power = 5, Speed = 11,
		DecayMult = 0.55, BonusChance = 0.12, Luck = 0.06,
		Look = { Shaft = Color3.fromRGB(230, 240, 255), Blade = Color3.fromRGB(120, 230, 255), ShaftMaterial = "Metal", BladeMaterial = "Glass", Glow = true, Sparkle = true },
		Description = "Crystal-hard. Even ancient relics come up fast." },
	{ Id = "MythicalShovel", Name = "Mythical Shovel", Price = 6000000, Level = 33, Power = 6.5, Speed = 12,
		DecayMult = 0.45, BonusChance = 0.15, Luck = 0.1,
		Look = { Shaft = Color3.fromRGB(30, 20, 50), Blade = Color3.fromRGB(190, 90, 255), ShaftMaterial = "Metal", BladeMaterial = "Neon", Glow = true, Sparkle = true },
		Description = "Forged from starlight. Nothing stays buried for long." },
}

Equipment.Boosts = {
	{ Id = "LuckyCharm", Name = "Lucky Charm", Price = 750, Level = 2, Luck = 0.5, Duration = 600,
		Description = "+50 Luck for 10 minutes." },
	{ Id = "FourLeafClover", Name = "Four-Leaf Clover", Price = 15000, Level = 10, Luck = 1, Duration = 900,
		Description = "+100 Luck for 15 minutes." },
	{ Id = "PiratesBlessing", Name = "Pirate's Blessing", Price = 250000, Level = 20, Luck = 2, Duration = 600,
		Description = "+200 Luck for 10 minutes." },
}

-- Personal shop upgrades: more display slots AND new decor that appears in your shop.
Equipment.ShopLevels = {
	{ Id = "Stall", Name = "Beach Stall", Price = 0, Level = 1, Slots = 6,
		Unlocks = "6 display slots: pedestals and wall shelves" },
	{ Id = "Shack", Name = "Seaside Shack", Price = 2000, Level = 4, Slots = 10,
		Unlocks = "+4 slots (glass cases) · striped awning and flower planters" },
	{ Id = "Boutique", Name = "Curio Boutique", Price = 12000, Level = 8, Slots = 16,
		Unlocks = "+6 slots · brass lanterns and marble entrance columns" },
	{ Id = "Gallery", Name = "Treasure Gallery", Price = 150000, Level = 14, Slots = 24,
		Unlocks = "+8 slots · hanging pendant lamps and a velvet runner" },
	{ Id = "Museum", Name = "Maritime Museum", Price = 1000000, Level = 20, Slots = 34,
		Unlocks = "+10 slots (wall plaques) · banners and a glass skylight dome" },
	{ Id = "Palace", Name = "Treasure Palace", Price = 7500000, Level = 28, Slots = 48,
		Unlocks = "+14 slots · golden statues, red carpet and a crystal chandelier" },
}

Equipment.Skins = {
	{ Id = "Default", Name = "Factory Grey", Price = 0, Level = 1,
		Body = Color3.fromRGB(70, 74, 82), Coil = Color3.fromRGB(40, 42, 48), Accent = Color3.fromRGB(255, 200, 60), Material = "SmoothPlastic" },
	{ Id = "OceanBlue", Name = "Ocean Blue", Price = 1000, Level = 3,
		Body = Color3.fromRGB(30, 120, 200), Coil = Color3.fromRGB(20, 60, 110), Accent = Color3.fromRGB(120, 230, 255), Material = "SmoothPlastic" },
	{ Id = "Sunset", Name = "Sunset Glow", Price = 10000, Level = 8,
		Body = Color3.fromRGB(255, 120, 60), Coil = Color3.fromRGB(150, 40, 90), Accent = Color3.fromRGB(255, 220, 120), Material = "SmoothPlastic" },
	{ Id = "GoldPlated", Name = "Gold Plated", Price = 120000, Level = 15,
		Body = Color3.fromRGB(255, 200, 50), Coil = Color3.fromRGB(60, 50, 30), Accent = Color3.fromRGB(255, 255, 255), Material = "Metal" },
	{ Id = "Neon", Name = "Neon Rave", Price = 900000, Level = 22,
		Body = Color3.fromRGB(25, 25, 35), Coil = Color3.fromRGB(255, 40, 200), Accent = Color3.fromRGB(40, 255, 220), Material = "SmoothPlastic", Sparkle = true },
	{ Id = "Galaxy", Name = "Galaxy", Price = 6000000, Level = 30,
		Body = Color3.fromRGB(70, 40, 160), Coil = Color3.fromRGB(20, 10, 60), Accent = Color3.fromRGB(200, 160, 255), Material = "ForceField", Sparkle = true },
}

Equipment.Themes = {
	{ Id = "BeachHut", Name = "Beach Hut", Price = 0, Level = 1,
		Floor = Color3.fromRGB(196, 150, 100), FloorMaterial = "WoodPlanks", Wall = Color3.fromRGB(240, 226, 196), WallMaterial = "Wood",
		Trim = Color3.fromRGB(70, 170, 200), Furniture = Color3.fromRGB(160, 110, 70), FurnitureMaterial = "Wood" },
	{ Id = "CoralReef", Name = "Coral Reef", Price = 5000, Level = 6,
		Floor = Color3.fromRGB(120, 210, 210), FloorMaterial = "SmoothPlastic", Wall = Color3.fromRGB(255, 170, 160), WallMaterial = "SmoothPlastic",
		Trim = Color3.fromRGB(255, 120, 110), Furniture = Color3.fromRGB(250, 235, 220), FurnitureMaterial = "SmoothPlastic" },
	{ Id = "PirateDen", Name = "Pirate Den", Price = 50000, Level = 12,
		Floor = Color3.fromRGB(90, 60, 40), FloorMaterial = "WoodPlanks", Wall = Color3.fromRGB(60, 45, 35), WallMaterial = "WoodPlanks",
		Trim = Color3.fromRGB(200, 160, 60), Furniture = Color3.fromRGB(110, 70, 40), FurnitureMaterial = "Wood" },
	{ Id = "RoyalGallery", Name = "Royal Gallery", Price = 600000, Level = 20,
		Floor = Color3.fromRGB(235, 235, 240), FloorMaterial = "Marble", Wall = Color3.fromRGB(120, 30, 50), WallMaterial = "Fabric",
		Trim = Color3.fromRGB(255, 205, 70), Furniture = Color3.fromRGB(245, 240, 230), FurnitureMaterial = "Marble" },
	{ Id = "NeonLagoon", Name = "Neon Lagoon", Price = 4000000, Level = 26,
		Floor = Color3.fromRGB(20, 20, 35), FloorMaterial = "SmoothPlastic", Wall = Color3.fromRGB(30, 25, 60), WallMaterial = "SmoothPlastic",
		Trim = Color3.fromRGB(40, 255, 220), Furniture = Color3.fromRGB(255, 60, 200), FurnitureMaterial = "Neon" },
}

Equipment.Trinkets = {
	{ Id = "LuckyDoubloon", Name = "Lucky Doubloon", Luck = 0.05, Description = "Earned by finding 100 treasures." },
	{ Id = "CaptainsSpyglass", Name = "Captain's Spyglass", Luck = 0.08, Description = "Earned by unlocking Tropical Island." },
	{ Id = "MermaidScale", Name = "Mermaid Scale", Luck = 0.12, Description = "Earned by finding your first Mythical treasure." },
	{ Id = "KrakenTooth", Name = "Kraken Tooth", Luck = 0.15, Description = "Earned by reaching level 25." },
	{ Id = "CuratorsMonocle", Name = "Curator's Monocle", Luck = 0.15, Description = "Earned by filling 24 display slots." },
	{ Id = "PirateKingsRing", Name = "Pirate King's Ring", Luck = 0.25, Description = "Earned by discovering 75% of the Treasure Index." },
	{ Id = "StarfallCharm", Name = "Starfall Charm", Luck = 0.3, Description = "Earned by finding your first Secret treasure." },
}

-- Lookup tables: Equipment.ById.Detector["TideSeeker"], etc.
-- (Kept separate from the lists so `for _, def in Equipment.Detectors` only loops over items.)
Equipment.ById = {
	Detector = index(Equipment.Detectors),
	Shovel = index(Equipment.Shovels),
	Boost = index(Equipment.Boosts),
	ShopLevel = index(Equipment.ShopLevels),
	Skin = index(Equipment.Skins),
	Theme = index(Equipment.Themes),
	Trinket = index(Equipment.Trinkets),
}

-- Categories the player buys once and can then equip.
Equipment.Ownable = {
	Detector = Equipment.Detectors,
	Shovel = Equipment.Shovels,
	Skin = Equipment.Skins,
	Theme = Equipment.Themes,
}

function Equipment.Get(category: string, id: string)
	local map = Equipment.ById[category]
	return map and map[id]
end

return Equipment
