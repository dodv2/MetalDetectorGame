--[[
	Achievements
	One-time goals. The server checks them whenever stats change.

	Stat keys (see AchievementService.GetStat):
	  Found, Digs, Level, CashEarned, BoostsUsed, Displayed, ShopValue, IndexCount, IndexPercent,
	  TierCount:<1-7>       treasures found of that rarity tier OR HIGHER
	  ZoneFinds:<ZoneId>    treasures found in a zone (exploration challenges)
	  ZoneUnlocked:<ZoneId> 1 once the zone is unlocked
	Reward = { Cash = n, XP = n, Trinket = "TrinketId" }
	Format = "Cash" | "Percent" (how the goal is shown in the UI)
]]

local Achievements = {}

Achievements.Categories = { "Discovery", "Exploration", "Collection", "Shop", "Wealth", "Progress" }

Achievements.List = {
	-- Discovery
	{ Id = "Found10", Category = "Discovery", Name = "Beginner's Luck", Description = "Find 10 treasures", Stat = "Found", Goal = 10, Reward = { Cash = 150 } },
	{ Id = "Found100", Category = "Discovery", Name = "Seasoned Detectorist", Description = "Find 100 treasures", Stat = "Found", Goal = 100, Reward = { Cash = 1500, Trinket = "LuckyDoubloon" } },
	{ Id = "Found500", Category = "Discovery", Name = "Sand Veteran", Description = "Find 500 treasures", Stat = "Found", Goal = 500, Reward = { Cash = 25000 } },
	{ Id = "Found2500", Category = "Discovery", Name = "Beachcomber Legend", Description = "Find 2,500 treasures", Stat = "Found", Goal = 2500, Reward = { Cash = 300000 } },
	{ Id = "Found10000", Category = "Discovery", Name = "One With the Sand", Description = "Find 10,000 treasures", Stat = "Found", Goal = 10000, Reward = { Cash = 3000000 } },
	{ Id = "FirstRare", Category = "Discovery", Name = "Ooh, Shiny!", Description = "Find your first Rare treasure", Stat = "TierCount:3", Goal = 1, Reward = { Cash = 200 } },
	{ Id = "FirstEpic", Category = "Discovery", Name = "Epic Find", Description = "Find your first Epic treasure", Stat = "TierCount:4", Goal = 1, Reward = { Cash = 750 } },
	{ Id = "FirstLegendary", Category = "Discovery", Name = "Legend of the Sands", Description = "Find your first Legendary treasure", Stat = "TierCount:5", Goal = 1, Reward = { Cash = 4000, XP = 500 } },
	{ Id = "FirstMythical", Category = "Discovery", Name = "Myth Made Real", Description = "Find your first Mythical treasure", Stat = "TierCount:6", Goal = 1, Reward = { XP = 2000, Trinket = "MermaidScale" } },
	{ Id = "FirstSecret", Category = "Discovery", Name = "Keeper of Secrets", Description = "Find your first Secret treasure", Stat = "TierCount:7", Goal = 1, Reward = { XP = 5000, Trinket = "StarfallCharm" } },
	{ Id = "Legendary10", Category = "Discovery", Name = "Legend Collector", Description = "Find 10 Legendary-or-better treasures", Stat = "TierCount:5", Goal = 10, Reward = { Cash = 100000 } },
	{ Id = "Digs1000", Category = "Discovery", Name = "Elbow Grease", Description = "Swing your shovel 1,000 times", Stat = "Digs", Goal = 1000, Reward = { Cash = 5000 } },
	{ Id = "Digs10000", Category = "Discovery", Name = "Human Excavator", Description = "Swing your shovel 10,000 times", Stat = "Digs", Goal = 10000, Reward = { Cash = 250000 } },

	-- Exploration (unlock zones + exploration challenges)
	{ Id = "UnlockRocky", Category = "Exploration", Name = "Into the Rocks", Description = "Unlock Rocky Shore", Stat = "ZoneUnlocked:RockyShore", Goal = 1, Reward = { XP = 200 } },
	{ Id = "UnlockTropical", Category = "Exploration", Name = "Island Hopper", Description = "Unlock Tropical Island", Stat = "ZoneUnlocked:TropicalIsland", Goal = 1, Reward = { XP = 600, Trinket = "CaptainsSpyglass" } },
	{ Id = "UnlockPier", Category = "Exploration", Name = "Pier Pressure", Description = "Unlock the Abandoned Pier", Stat = "ZoneUnlocked:AbandonedPier", Goal = 1, Reward = { XP = 1500 } },
	{ Id = "UnlockShipwreck", Category = "Exploration", Name = "Wreck Diver", Description = "Unlock Shipwreck Coast", Stat = "ZoneUnlocked:ShipwreckCoast", Goal = 1, Reward = { XP = 3500 } },
	{ Id = "UnlockRuins", Category = "Exploration", Name = "Temple Raider", Description = "Unlock the Ancient Ruins", Stat = "ZoneUnlocked:AncientRuins", Goal = 1, Reward = { XP = 7000 } },
	{ Id = "UnlockSecret", Category = "Exploration", Name = "X Marks the Spot", Description = "Reach Secret Treasure Island", Stat = "ZoneUnlocked:SecretIsland", Goal = 1, Reward = { XP = 15000 } },
	{ Id = "ExploreBeach", Category = "Exploration", Name = "Beach Bum", Description = "Find 25 treasures at Starting Beach", Stat = "ZoneFinds:StartingBeach", Goal = 25, Reward = { Cash = 300 } },
	{ Id = "ExploreRocky", Category = "Exploration", Name = "Rock Hopper", Description = "Find 25 treasures at Rocky Shore", Stat = "ZoneFinds:RockyShore", Goal = 25, Reward = { Cash = 2000 } },
	{ Id = "ExploreTropical", Category = "Exploration", Name = "Island Life", Description = "Find 25 treasures on Tropical Island", Stat = "ZoneFinds:TropicalIsland", Goal = 25, Reward = { Cash = 12000 } },
	{ Id = "ExplorePier", Category = "Exploration", Name = "Under the Boardwalk", Description = "Find 25 treasures at the Abandoned Pier", Stat = "ZoneFinds:AbandonedPier", Goal = 25, Reward = { Cash = 50000 } },
	{ Id = "ExploreShipwreck", Category = "Exploration", Name = "Salvage Rights", Description = "Find 25 treasures at Shipwreck Coast", Stat = "ZoneFinds:ShipwreckCoast", Goal = 25, Reward = { Cash = 175000 } },
	{ Id = "ExploreRuins", Category = "Exploration", Name = "Relic Hunter", Description = "Find 25 treasures in the Ancient Ruins", Stat = "ZoneFinds:AncientRuins", Goal = 25, Reward = { Cash = 600000 } },
	{ Id = "ExploreSecret", Category = "Exploration", Name = "Island Royalty", Description = "Find 25 treasures on Secret Treasure Island", Stat = "ZoneFinds:SecretIsland", Goal = 25, Reward = { Cash = 2500000 } },

	-- Collection (Treasure Index)
	{ Id = "Index10", Category = "Collection", Name = "Collector", Description = "Discover 10 different treasures", Stat = "IndexCount", Goal = 10, Reward = { Cash = 400 } },
	{ Id = "Index30", Category = "Collection", Name = "Archivist", Description = "Discover 30 different treasures", Stat = "IndexCount", Goal = 30, Reward = { Cash = 20000 } },
	{ Id = "Index60", Category = "Collection", Name = "Historian", Description = "Discover 60 different treasures", Stat = "IndexCount", Goal = 60, Reward = { Cash = 400000 } },
	{ Id = "Index75", Category = "Collection", Name = "Master Archivist", Description = "Discover 75% of the Treasure Index", Stat = "IndexPercent", Goal = 0.75, Format = "Percent", Reward = { Trinket = "PirateKingsRing" } },
	{ Id = "IndexAll", Category = "Collection", Name = "Completionist", Description = "Discover every treasure in the game", Stat = "IndexPercent", Goal = 1, Format = "Percent", Reward = { Cash = 10000000 } },

	-- Shop
	{ Id = "Display1", Category = "Shop", Name = "Grand Opening", Description = "Display your first treasure", Stat = "Displayed", Goal = 1, Reward = { Cash = 100 } },
	{ Id = "Display10", Category = "Shop", Name = "Curator", Description = "Display 10 treasures at once", Stat = "Displayed", Goal = 10, Reward = { Cash = 6000 } },
	{ Id = "Display24", Category = "Shop", Name = "Gallery Owner", Description = "Display 24 treasures at once", Stat = "Displayed", Goal = 24, Reward = { Trinket = "CuratorsMonocle" } },
	{ Id = "Display48", Category = "Shop", Name = "Museum of Wonders", Description = "Fill all 48 display slots", Stat = "Displayed", Goal = 48, Reward = { Cash = 1500000 } },
	{ Id = "ShopValue10K", Category = "Shop", Name = "Valuable Collection", Description = "Reach a shop collection value of $10K", Stat = "ShopValue", Goal = 10000, Format = "Cash", Reward = { Cash = 2500 } },
	{ Id = "ShopValue1M", Category = "Shop", Name = "Priceless Collection", Description = "Reach a shop collection value of $1M", Stat = "ShopValue", Goal = 1000000, Format = "Cash", Reward = { Cash = 150000 } },

	-- Wealth
	{ Id = "Earned1K", Category = "Wealth", Name = "Pocket Money", Description = "Earn $1,000 in total", Stat = "CashEarned", Goal = 1000, Format = "Cash", Reward = { XP = 100 } },
	{ Id = "Earned10K", Category = "Wealth", Name = "Small Fortune", Description = "Earn $10,000 in total", Stat = "CashEarned", Goal = 10000, Format = "Cash", Reward = { XP = 500 } },
	{ Id = "Earned100K", Category = "Wealth", Name = "Big Spender", Description = "Earn $100,000 in total", Stat = "CashEarned", Goal = 100000, Format = "Cash", Reward = { XP = 2000 } },
	{ Id = "Earned1M", Category = "Wealth", Name = "Millionaire", Description = "Earn $1,000,000 in total", Stat = "CashEarned", Goal = 1000000, Format = "Cash", Reward = { XP = 6000 } },
	{ Id = "Earned10M", Category = "Wealth", Name = "Tycoon", Description = "Earn $10,000,000 in total", Stat = "CashEarned", Goal = 10000000, Format = "Cash", Reward = { XP = 20000 } },
	{ Id = "Earned100M", Category = "Wealth", Name = "Sea Baron", Description = "Earn $100,000,000 in total", Stat = "CashEarned", Goal = 100000000, Format = "Cash", Reward = { XP = 60000 } },

	-- Progress
	{ Id = "FirstBoost", Category = "Progress", Name = "Feeling Lucky", Description = "Use a Luck boost", Stat = "BoostsUsed", Goal = 1, Reward = { Cash = 300 } },
	{ Id = "Level10", Category = "Progress", Name = "Rising Star", Description = "Reach level 10", Stat = "Level", Goal = 10, Reward = { Cash = 5000 } },
	{ Id = "Level25", Category = "Progress", Name = "Expert Hunter", Description = "Reach level 25", Stat = "Level", Goal = 25, Reward = { Trinket = "KrakenTooth" } },
	{ Id = "Level50", Category = "Progress", Name = "Treasure Master", Description = "Reach level 50", Stat = "Level", Goal = 50, Reward = { Cash = 5000000 } },
}

Achievements.ById = {}
for _, def in Achievements.List do
	Achievements.ById[def.Id] = def
end

return Achievements
