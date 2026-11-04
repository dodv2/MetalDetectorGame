--[[
	Zones
	Exploration areas, in unlock order. Each zone's world parts live in
	Workspace > Map > Zones > <ZoneId> (DigArea, Region, TravelPoint, Gate).

	Level        player level needed to unlock
	Price        one-time cash cost to unlock (paid at the gate / Travel menu)
	ValueMult    multiplies the value of event treasures found here (zone treasures already have their own values)
	XPMult       multiplies XP from finds
	Weights      base rarity weights before Luck is applied (higher = more common)
	RequiresDiscovery  optional treasure id the player must have found at least once
	Ground       colour of this beach's sand (dig site, sand spray) - matches its terrain material
	Mood         how the beach looks while you're on it (WorldController tweens to it):
	             Clock = time of day, Haze/Density + AirColor/AirDecay = atmosphere, Tint/Saturation =
	             colour grading, Water = sea colour. Night events still override the clock.
]]

local Zones = {}

Zones.Order = {
	"StartingBeach",
	"RockyShore",
	"TropicalIsland",
	"AbandonedPier",
	"ShipwreckCoast",
	"AncientRuins",
	"SecretIsland",
}

Zones.Info = {
	StartingBeach = {
		Index = 1,
		Name = "Starting Beach",
		Description = "Calm sands where every treasure hunter begins. Bottle caps, coins and the odd lost ring.",
		Level = 1,
		Price = 0,
		ValueMult = 1,
		XPMult = 1,
		Color = Color3.fromRGB(246, 215, 150),
		Ground = Color3.fromRGB(236, 214, 164),
		Mood = { Clock = 14.2, Density = 0.28, Haze = 1.2, AirColor = Color3.fromRGB(199, 224, 242), AirDecay = Color3.fromRGB(140, 178, 217), Tint = Color3.fromRGB(255, 255, 255), Saturation = 0.12, Water = Color3.fromRGB(28, 156, 176) },
		Weights = { Common = 620, Uncommon = 270, Rare = 85, Epic = 20, Legendary = 4, Mythical = 0.45, Secret = 0.05 },
	},
	RockyShore = {
		Index = 2,
		Name = "Rocky Shore",
		Description = "Tide pools and boulders hide relics washed in by storms.",
		Level = 4,
		Price = 750,
		ValueMult = 3,
		XPMult = 1.5,
		Color = Color3.fromRGB(176, 170, 156),
		Ground = Color3.fromRGB(184, 178, 164),
		Mood = { Clock = 13.4, Density = 0.36, Haze = 2.2, AirColor = Color3.fromRGB(205, 214, 224), AirDecay = Color3.fromRGB(120, 136, 152), Tint = Color3.fromRGB(236, 244, 255), Saturation = -0.02, Water = Color3.fromRGB(40, 118, 138) },
		Weights = { Common = 580, Uncommon = 280, Rare = 105, Epic = 28, Legendary = 6, Mythical = 0.7, Secret = 0.07 },
	},
	TropicalIsland = {
		Index = 3,
		Name = "Tropical Island",
		Description = "White sand and palm trees. Island charms and pearls are common here.",
		Level = 8,
		Price = 6000,
		ValueMult = 9,
		XPMult = 2.2,
		Color = Color3.fromRGB(255, 240, 205),
		Ground = Color3.fromRGB(232, 222, 196),
		Mood = { Clock = 13.0, Density = 0.24, Haze = 0.8, AirColor = Color3.fromRGB(190, 232, 246), AirDecay = Color3.fromRGB(120, 192, 232), Tint = Color3.fromRGB(255, 251, 240), Saturation = 0.25, Water = Color3.fromRGB(18, 196, 200) },
		Weights = { Common = 540, Uncommon = 290, Rare = 125, Epic = 36, Legendary = 8, Mythical = 1.0, Secret = 0.1 },
	},
	AbandonedPier = {
		Index = 4,
		Name = "Abandoned Pier",
		Description = "A rotting pier where fishermen and sailors lost a century of keepsakes.",
		Level = 13,
		Price = 35000,
		ValueMult = 25,
		XPMult = 3.2,
		Color = Color3.fromRGB(196, 170, 128),
		Ground = Color3.fromRGB(204, 172, 126),
		Mood = { Clock = 17.2, Density = 0.32, Haze = 1.8, AirColor = Color3.fromRGB(255, 214, 170), AirDecay = Color3.fromRGB(220, 140, 92), Tint = Color3.fromRGB(255, 236, 214), Saturation = 0.08, Water = Color3.fromRGB(40, 108, 128) },
		Weights = { Common = 500, Uncommon = 300, Rare = 140, Epic = 45, Legendary = 11, Mythical = 1.4, Secret = 0.14 },
	},
	ShipwreckCoast = {
		Index = 5,
		Name = "Shipwreck Coast",
		Description = "A pirate galleon broke apart on these rocks. Its cargo is still out there.",
		Level = 19,
		Price = 250000,
		ValueMult = 70,
		XPMult = 4.6,
		Color = Color3.fromRGB(150, 128, 104),
		Ground = Color3.fromRGB(84, 78, 72),
		Mood = { Clock = 15.0, Density = 0.42, Haze = 2.6, AirColor = Color3.fromRGB(172, 182, 192), AirDecay = Color3.fromRGB(92, 102, 112), Tint = Color3.fromRGB(226, 233, 242), Saturation = -0.12, Water = Color3.fromRGB(30, 82, 96) },
		Weights = { Common = 470, Uncommon = 300, Rare = 155, Epic = 55, Legendary = 15, Mythical = 2.0, Secret = 0.2 },
	},
	AncientRuins = {
		Index = 6,
		Name = "Ancient Ruins",
		Description = "The sunken temple of the Tide Kings. Find the Ancient Sea Chart to reach the secret island.",
		Level = 26,
		Price = 1500000,
		ValueMult = 200,
		XPMult = 6.5,
		Color = Color3.fromRGB(214, 196, 150),
		Ground = Color3.fromRGB(226, 206, 160),
		Mood = { Clock = 16.4, Density = 0.3, Haze = 1.6, AirColor = Color3.fromRGB(255, 226, 180), AirDecay = Color3.fromRGB(220, 170, 110), Tint = Color3.fromRGB(255, 243, 222), Saturation = 0.1, Water = Color3.fromRGB(30, 140, 150) },
		Weights = { Common = 440, Uncommon = 300, Rare = 170, Epic = 65, Legendary = 19, Mythical = 2.8, Secret = 0.28 },
	},
	SecretIsland = {
		Index = 7,
		Name = "Secret Treasure Island",
		Description = "Marked only on the Ancient Sea Chart. The richest sands in the ocean.",
		Level = 34,
		Price = 7500000,
		ValueMult = 600,
		XPMult = 9,
		Color = Color3.fromRGB(255, 214, 92),
		RequiresDiscovery = "AncientSeaChart",
		Ground = Color3.fromRGB(250, 222, 135),
		Mood = { Clock = 17.8, Density = 0.3, Haze = 1.4, AirColor = Color3.fromRGB(255, 192, 222), AirDecay = Color3.fromRGB(200, 122, 200), Tint = Color3.fromRGB(255, 236, 250), Saturation = 0.2, Water = Color3.fromRGB(60, 150, 205) },
		Weights = { Common = 400, Uncommon = 300, Rare = 185, Epic = 80, Legendary = 26, Mythical = 4.0, Secret = 0.4 },
	},
}

function Zones.Get(id: string)
	return Zones.Info[id]
end

return Zones
