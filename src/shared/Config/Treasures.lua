--[[
	Treasures
	Every treasure in the game. To add one, copy a line and change the fields:

	Id          unique key (no spaces) - saved in player data, never rename it once live
	Name        display name
	Rarity      Common / Uncommon / Rare / Epic / Legendary / Mythical / Secret
	Zone        zone id it can be dug up in ("Event" = event-only)
	Value       base sell value (multiplied by the item's quality roll, 0.8x - 1.6x)
	Shape       model builder in Shared > TreasureModels (Coin, Ring, Gem, Chest, Crown, ...)
	Color/Accent  main and secondary colours of the model
	Material    optional model material (Metal, Glass, Neon, CorrodedMetal, Slate)
	Glow        optional, adds a light to the model
	Scale       optional model size multiplier
	MinLevel    optional, only appears for players at or above this level
	Event       for event treasures: event id from Config > Events
	ScalesWithZone  event treasures: value is multiplied by the zone's ValueMult
	Lore        flavour text shown on the discovery card and in the Index

	(Generated from tools/gen_treasures.py - values follow Rarity BaseValue x zone multiplier.)
]]

local Treasures = {}

Treasures.List = {

	-- StartingBeach ----------------------------------------
	{ Id = "BottleCap", Name = "Bottle Cap", Rarity = "Common", Zone = "StartingBeach", Value = 6, Shape = "Coin", Color = Color3.fromRGB(200, 60, 60), Accent = Color3.fromRGB(230, 230, 230), Material = "Metal", Scale = 0.7, Lore = "Someone's soda went flat in 1987." },
	{ Id = "OldPenny", Name = "Old Penny", Rarity = "Common", Zone = "StartingBeach", Value = 8, Shape = "Coin", Color = Color3.fromRGB(184, 115, 51), Accent = Color3.fromRGB(150, 90, 40), Material = "Metal", Scale = 0.8, Lore = "Heads up! Well... it's face-down in the sand." },
	{ Id = "SpiralSeashell", Name = "Spiral Seashell", Rarity = "Common", Zone = "StartingBeach", Value = 9, Shape = "Shell", Color = Color3.fromRGB(250, 220, 200), Accent = Color3.fromRGB(240, 160, 150), Lore = "Hold it to your ear and you can hear the ocean. Probably." },
	{ Id = "SodaCan", Name = "Crushed Soda Can", Rarity = "Common", Zone = "StartingBeach", Value = 6, Shape = "Can", Color = Color3.fromRGB(60, 140, 220), Accent = Color3.fromRGB(220, 220, 220), Material = "Metal", Lore = "Not treasure, but the beach is cleaner now." },
	{ Id = "LostCarKey", Name = "Lost Car Key", Rarity = "Uncommon", Zone = "StartingBeach", Value = 25, Shape = "Key", Color = Color3.fromRGB(200, 200, 210), Accent = Color3.fromRGB(40, 40, 40), Material = "Metal", Lore = "Somewhere, a very sunburnt tourist is still looking." },
	{ Id = "SilverDime", Name = "Silver Dime", Rarity = "Uncommon", Zone = "StartingBeach", Value = 28, Shape = "Coin", Color = Color3.fromRGB(215, 215, 225), Accent = Color3.fromRGB(180, 180, 190), Material = "Metal", Scale = 0.8, Lore = "Older than your grandparents and still shiny." },
	{ Id = "SeaGlassBottle", Name = "Sea Glass Bottle", Rarity = "Uncommon", Zone = "StartingBeach", Value = 25, Shape = "Bottle", Color = Color3.fromRGB(90, 190, 140), Accent = Color3.fromRGB(140, 100, 60), Material = "Glass", Lore = "Tumbled smooth by a thousand tides." },
	{ Id = "WeddingRing", Name = "Lost Wedding Ring", Rarity = "Rare", Zone = "StartingBeach", Value = 80, Shape = "Ring", Color = Color3.fromRGB(255, 205, 70), Accent = Color3.fromRGB(240, 250, 255), MinLevel = 2, Lore = "Engraved: 'Forever, M.' Someone will be very happy." },
	{ Id = "VintageWristwatch", Name = "Vintage Wristwatch", Rarity = "Rare", Zone = "StartingBeach", Value = 88, Shape = "Watch", Color = Color3.fromRGB(220, 190, 120), Accent = Color3.fromRGB(60, 40, 30), Lore = "Still ticking. Waterproof, as advertised." },
	{ Id = "BrassCompass", Name = "Brass Compass", Rarity = "Epic", Zone = "StartingBeach", Value = 300, Shape = "Compass", Color = Color3.fromRGB(205, 160, 70), Accent = Color3.fromRGB(200, 40, 40), Lore = "Its needle points to treasure, not north." },
	{ Id = "GoldenBracelet", Name = "Golden Bracelet", Rarity = "Epic", Zone = "StartingBeach", Value = 340, Shape = "Ring", Color = Color3.fromRGB(255, 200, 60), Accent = Color3.fromRGB(255, 240, 180), Scale = 1.2, MinLevel = 3, Lore = "Heavy, warm, and definitely real gold." },
	{ Id = "PirateDoubloon", Name = "Pirate Doubloon", Rarity = "Legendary", Zone = "StartingBeach", Value = 1200, Shape = "Coin", Color = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(200, 150, 20), Material = "Metal", Glow = true, Lore = "Spanish gold, 1715. The first sign the legends are true." },
	{ Id = "MermaidsPearl", Name = "Mermaid's Pearl", Rarity = "Mythical", Zone = "StartingBeach", Value = 6000, Shape = "Orb", Color = Color3.fromRGB(250, 245, 255), Accent = Color3.fromRGB(200, 220, 255), Glow = true, Lore = "It shimmers like moonlight on water." },
	{ Id = "SunkenStarFragment", Name = "Sunken Star Fragment", Rarity = "Secret", Zone = "StartingBeach", Value = 40000, Shape = "Gem", Color = Color3.fromRGB(255, 240, 120), Accent = Color3.fromRGB(255, 255, 255), Material = "Neon", Glow = true, Lore = "A piece of a falling star that cooled in the sea." },
	{ Id = "RubberDuck", Name = "Runaway Rubber Duck", Rarity = "Common", Zone = "StartingBeach", Value = 7, Shape = "RubberDuck", Color = Color3.fromRGB(255, 215, 40), Accent = Color3.fromRGB(255, 140, 30), Lore = "Squeaks once, mournfully, when you pick it up." },
	{ Id = "LostSunglasses", Name = "Lost Sunglasses", Rarity = "Common", Zone = "StartingBeach", Value = 8, Shape = "Spectacles", Color = Color3.fromRGB(30, 30, 35), Accent = Color3.fromRGB(40, 40, 50), Material = "SmoothPlastic", Lore = "Very cool. Very sandy." },
	{ Id = "PlainSandDollar", Name = "Sand Dollar", Rarity = "Common", Zone = "StartingBeach", Value = 8, Shape = "SandDollar", Color = Color3.fromRGB(240, 232, 210), Accent = Color3.fromRGB(215, 200, 170), Lore = "Nature's coin. Shops won't take it." },
	{ Id = "ToyRaceCar", Name = "Toy Race Car", Rarity = "Common", Zone = "StartingBeach", Value = 9, Shape = "ToyCar", Color = Color3.fromRGB(220, 40, 40), Accent = Color3.fromRGB(255, 255, 255), Lore = "Number 7, still waiting for the chequered flag." },
	{ Id = "FriendshipBracelet", Name = "Friendship Bracelet", Rarity = "Uncommon", Zone = "StartingBeach", Value = 25, Shape = "Bracelet", Color = Color3.fromRGB(255, 120, 170), Accent = Color3.fromRGB(120, 220, 255), Material = "Fabric", Lore = "Woven on holiday. 'BFF' in tiny beads." },
	{ Id = "PinkStarfish", Name = "Pink Starfish", Rarity = "Uncommon", Zone = "StartingBeach", Value = 25, Shape = "Starfish", Color = Color3.fromRGB(255, 140, 170), Accent = Color3.fromRGB(255, 220, 230), Lore = "Dried in the sun into a perfect five-point star." },
	{ Id = "TinSoldier", Name = "Tin Soldier", Rarity = "Uncommon", Zone = "StartingBeach", Value = 28, Shape = "ToySoldier", Color = Color3.fromRGB(200, 40, 40), Accent = Color3.fromRGB(255, 210, 60), Lore = "Stood guard over a sandcastle until the tide came." },
	{ Id = "DigitalWatch", Name = "Kid's Digital Watch", Rarity = "Uncommon", Zone = "StartingBeach", Value = 22, Shape = "Watch", Color = Color3.fromRGB(80, 200, 120), Accent = Color3.fromRGB(30, 30, 30), Material = "SmoothPlastic", Lore = "Still beeping every hour, on the hour." },
	{ Id = "SilverLocket", Name = "Silver Locket", Rarity = "Rare", Zone = "StartingBeach", Value = 80, Shape = "Locket", Color = Color3.fromRGB(215, 215, 225), Accent = Color3.fromRGB(120, 160, 220), MinLevel = 2, Lore = "Inside: a tiny photo of a very happy dog." },
	{ Id = "PearlNecklace", Name = "Pearl Necklace", Rarity = "Rare", Zone = "StartingBeach", Value = 88, Shape = "Necklace", Color = Color3.fromRGB(245, 240, 235), Accent = Color3.fromRGB(250, 250, 255), Lore = "Snapped at a beach party; every pearl found." },
	{ Id = "ShipInABottle", Name = "Ship in a Bottle", Rarity = "Epic", Zone = "StartingBeach", Value = 330, Shape = "Bottle", Color = Color3.fromRGB(170, 220, 200), Accent = Color3.fromRGB(140, 90, 50), Material = "Glass", Lore = "How did they get it in there? How did it get here?" },
	{ Id = "TennisBracelet", Name = "Diamond Tennis Bracelet", Rarity = "Epic", Zone = "StartingBeach", Value = 300, Shape = "Bracelet", Color = Color3.fromRGB(235, 235, 245), Accent = Color3.fromRGB(240, 250, 255), MinLevel = 3, Lore = "A line of diamonds, lost mid-serve." },
	{ Id = "CaptainsSpyglass", Name = "Old Captain's Spyglass", Rarity = "Legendary", Zone = "StartingBeach", Value = 1200, Shape = "Spyglass", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(120, 80, 40), Glow = true, Lore = "Through it, the horizon looks closer - and richer." },
	{ Id = "MermaidsLocket", Name = "Mermaid's Locket", Rarity = "Mythical", Zone = "StartingBeach", Value = 6000, Shape = "Locket", Color = Color3.fromRGB(120, 230, 220), Accent = Color3.fromRGB(255, 240, 250), Material = "Glass", Glow = true, Lore = "Holds a single scale that never dries." },

	-- RockyShore ----------------------------------------
	{ Id = "CrabShell", Name = "Crab Shell", Rarity = "Common", Zone = "RockyShore", Value = 24, Shape = "Shell", Color = Color3.fromRGB(230, 110, 60), Accent = Color3.fromRGB(250, 200, 170), Lore = "The crab moved out. No forwarding address." },
	{ Id = "LeadSinker", Name = "Lead Sinker", Rarity = "Common", Zone = "RockyShore", Value = 22, Shape = "Orb", Color = Color3.fromRGB(120, 120, 130), Accent = Color3.fromRGB(90, 90, 100), Material = "Metal", Scale = 0.6, Lore = "A fisherman's weight, lost to the rocks." },
	{ Id = "RustedBolt", Name = "Rusted Bolt", Rarity = "Common", Zone = "RockyShore", Value = 22, Shape = "Bar", Color = Color3.fromRGB(140, 80, 50), Accent = Color3.fromRGB(110, 60, 40), Material = "CorrodedMetal", Scale = 0.7, Lore = "From a lighthouse that no longer stands." },
	{ Id = "CopperBracelet", Name = "Copper Bracelet", Rarity = "Uncommon", Zone = "RockyShore", Value = 75, Shape = "Ring", Color = Color3.fromRGB(190, 110, 60), Accent = Color3.fromRGB(60, 170, 140), Lore = "Green patina means it's been here a long time." },
	{ Id = "AntiqueButton", Name = "Antique Button", Rarity = "Uncommon", Zone = "RockyShore", Value = 68, Shape = "Coin", Color = Color3.fromRGB(200, 170, 90), Accent = Color3.fromRGB(120, 90, 40), Scale = 0.7, Lore = "From a sea captain's coat." },
	{ Id = "PocketKnife", Name = "Old Pocket Knife", Rarity = "Uncommon", Zone = "RockyShore", Value = 82, Shape = "Sword", Color = Color3.fromRGB(190, 190, 200), Accent = Color3.fromRGB(110, 60, 40), Scale = 0.6, MinLevel = 5, Lore = "Rusty blade, handsome bone handle." },
	{ Id = "SilverPocketWatch", Name = "Silver Pocket Watch", Rarity = "Rare", Zone = "RockyShore", Value = 240, Shape = "Watch", Color = Color3.fromRGB(215, 215, 225), Accent = Color3.fromRGB(30, 30, 40), Lore = "Stopped at 4:12, the moment it hit the water." },
	{ Id = "TidepoolOpal", Name = "Tidepool Opal", Rarity = "Rare", Zone = "RockyShore", Value = 260, Shape = "Gem", Color = Color3.fromRGB(120, 220, 230), Accent = Color3.fromRGB(255, 200, 240), Material = "Glass", Lore = "Flashes every colour of the shallows." },
	{ Id = "KeepersBell", Name = "Lighthouse Keeper's Bell", Rarity = "Epic", Zone = "RockyShore", Value = 900, Shape = "Bell", Color = Color3.fromRGB(200, 150, 60), Accent = Color3.fromRGB(90, 60, 30), Lore = "Rang through the fog for forty years." },
	{ Id = "GeodeHeart", Name = "Geode Heart", Rarity = "Epic", Zone = "RockyShore", Value = 990, Shape = "Gem", Color = Color3.fromRGB(150, 80, 220), Accent = Color3.fromRGB(230, 200, 255), MinLevel = 6, Lore = "Crack it open and it sparkles like a galaxy." },
	{ Id = "SmugglersLockbox", Name = "Smuggler's Lockbox", Rarity = "Legendary", Zone = "RockyShore", Value = 3600, Shape = "Chest", Color = Color3.fromRGB(80, 70, 70), Accent = Color3.fromRGB(200, 170, 80), Glow = true, Lore = "Still locked. Whatever's inside, it rattles." },
	{ Id = "SirensConch", Name = "Siren's Conch", Rarity = "Mythical", Zone = "RockyShore", Value = 18000, Shape = "Shell", Color = Color3.fromRGB(255, 200, 230), Accent = Color3.fromRGB(255, 120, 180), Glow = true, Scale = 1.2, Lore = "Blow it and the waves fall silent." },
	{ Id = "KrakenEye", Name = "Fossilized Kraken Eye", Rarity = "Secret", Zone = "RockyShore", Value = 120000, Shape = "Orb", Color = Color3.fromRGB(255, 170, 40), Accent = Color3.fromRGB(60, 20, 0), Material = "Glass", Glow = true, Lore = "It's watching. It has always been watching." },
	{ Id = "Periwinkle", Name = "Periwinkle Shell", Rarity = "Common", Zone = "RockyShore", Value = 22, Shape = "Shell", Color = Color3.fromRGB(110, 100, 90), Accent = Color3.fromRGB(170, 150, 120), Scale = 0.6, Lore = "Tiny, stubborn, and very good at hiding." },
	{ Id = "GlassFloat", Name = "Glass Fishing Float", Rarity = "Common", Zone = "RockyShore", Value = 24, Shape = "Orb", Color = Color3.fromRGB(90, 170, 120), Accent = Color3.fromRGB(200, 230, 210), Material = "Glass", Lore = "Drifted here from a fishing village far away." },
	{ Id = "GullBone", Name = "Gull Bone", Rarity = "Common", Zone = "RockyShore", Value = 22, Shape = "Bone", Color = Color3.fromRGB(235, 230, 215), Accent = Color3.fromRGB(200, 190, 170), Lore = "The seagull isn't missing it any more." },
	{ Id = "AmmoniteFossil", Name = "Ammonite Fossil", Rarity = "Uncommon", Zone = "RockyShore", Value = 75, Shape = "Ammonite", Color = Color3.fromRGB(170, 150, 120), Accent = Color3.fromRGB(120, 100, 80), Lore = "Spiralled shut 150 million years ago." },
	{ Id = "TrilobiteFossil", Name = "Trilobite Fossil", Rarity = "Uncommon", Zone = "RockyShore", Value = 82, Shape = "Trilobite", Color = Color3.fromRGB(120, 115, 110), Accent = Color3.fromRGB(60, 55, 50), Lore = "An ocean bug older than the dinosaurs." },
	{ Id = "KeeperSpectacles", Name = "Keeper's Spectacles", Rarity = "Uncommon", Zone = "RockyShore", Value = 75, Shape = "Spectacles", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(200, 220, 240), Lore = "For reading the logbook by lamplight." },
	{ Id = "LighthouseLantern", Name = "Storm Lantern", Rarity = "Rare", Zone = "RockyShore", Value = 240, Shape = "Lantern", Color = Color3.fromRGB(60, 60, 65), Accent = Color3.fromRGB(255, 190, 80), MinLevel = 5, Lore = "Kept the keeper's way lit on the cliff path." },
	{ Id = "GarnetLocket", Name = "Garnet Locket", Rarity = "Rare", Zone = "RockyShore", Value = 240, Shape = "Locket", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(160, 20, 40), Lore = "Its hinge still clicks shut with a secret." },
	{ Id = "FossilSeahorse", Name = "Fossilised Seahorse", Rarity = "Epic", Zone = "RockyShore", Value = 900, Shape = "Seahorse", Color = Color3.fromRGB(190, 170, 140), Accent = Color3.fromRGB(130, 110, 90), Material = "Limestone", Lore = "Curled up in stone, as if asleep." },
	{ Id = "KeepersSpyglass", Name = "Keeper's Spyglass", Rarity = "Epic", Zone = "RockyShore", Value = 990, Shape = "Spyglass", Color = Color3.fromRGB(170, 170, 180), Accent = Color3.fromRGB(60, 60, 70), Material = "Metal", Lore = "Watched for ships in every storm." },
	{ Id = "StormHourglass", Name = "Storm Hourglass", Rarity = "Legendary", Zone = "RockyShore", Value = 3600, Shape = "Hourglass", Color = Color3.fromRGB(225, 205, 150), Accent = Color3.fromRGB(60, 50, 45), Glow = true, Lore = "Its sand only falls when a storm is coming." },
	{ Id = "MegalodonTooth", Name = "Megalodon Tooth", Rarity = "Mythical", Zone = "RockyShore", Value = 18000, Shape = "Tooth", Color = Color3.fromRGB(70, 70, 75), Accent = Color3.fromRGB(200, 190, 170), Material = "Slate", Glow = true, Scale = 1.4, Lore = "From a shark the size of a bus." },

	-- TropicalIsland ----------------------------------------
	{ Id = "CoconutCup", Name = "Coconut Cup", Rarity = "Common", Zone = "TropicalIsland", Value = 72, Shape = "Goblet", Color = Color3.fromRGB(120, 80, 45), Accent = Color3.fromRGB(230, 220, 200), Lore = "Perfect for juice. Less perfect after the sand." },
	{ Id = "SharkTooth", Name = "Shark Tooth", Rarity = "Common", Zone = "TropicalIsland", Value = 72, Shape = "Tooth", Color = Color3.fromRGB(245, 245, 235), Accent = Color3.fromRGB(200, 200, 190), Lore = "Sharks lose thousands. This one was big." },
	{ Id = "PaintedShell", Name = "Painted Shell", Rarity = "Common", Zone = "TropicalIsland", Value = 72, Shape = "Shell", Color = Color3.fromRGB(255, 150, 190), Accent = Color3.fromRGB(120, 220, 255), Lore = "Painted by a child, kept by the sea." },
	{ Id = "JadeTurtle", Name = "Jade Turtle Charm", Rarity = "Uncommon", Zone = "TropicalIsland", Value = 220, Shape = "Statue", Color = Color3.fromRGB(80, 190, 120), Accent = Color3.fromRGB(40, 120, 80), Scale = 0.7, Lore = "Islanders say it brings safe voyages." },
	{ Id = "PukaNecklace", Name = "Puka Shell Necklace", Rarity = "Uncommon", Zone = "TropicalIsland", Value = 200, Shape = "Ring", Color = Color3.fromRGB(245, 240, 225), Accent = Color3.fromRGB(180, 140, 90), Lore = "Very surf. Very 1998." },
	{ Id = "TikiBottle", Name = "Tiki Bottle", Rarity = "Uncommon", Zone = "TropicalIsland", Value = 250, Shape = "Bottle", Color = Color3.fromRGB(170, 110, 60), Accent = Color3.fromRGB(60, 180, 120), Lore = "Carved face, empty belly." },
	{ Id = "GoldNugget", Name = "Gold Nugget", Rarity = "Rare", Zone = "TropicalIsland", Value = 720, Shape = "Gem", Color = Color3.fromRGB(255, 200, 50), Accent = Color3.fromRGB(200, 150, 30), Material = "Metal", Scale = 0.8, Lore = "Washed down from the island's volcano streams." },
	{ Id = "TikiIdol", Name = "Carved Tiki Idol", Rarity = "Rare", Zone = "TropicalIsland", Value = 790, Shape = "Statue", Color = Color3.fromRGB(140, 90, 50), Accent = Color3.fromRGB(240, 200, 80), MinLevel = 9, Lore = "Grinning at you. Is that... a wink?" },
	{ Id = "BlackPearl", Name = "Black Pearl", Rarity = "Epic", Zone = "TropicalIsland", Value = 2700, Shape = "Orb", Color = Color3.fromRGB(40, 40, 55), Accent = Color3.fromRGB(140, 120, 200), Scale = 0.8, Lore = "Rarer than gold. Darker than the deep." },
	{ Id = "EmeraldParrot", Name = "Emerald Parrot Pin", Rarity = "Epic", Zone = "TropicalIsland", Value = 3000, Shape = "Gem", Color = Color3.fromRGB(40, 200, 90), Accent = Color3.fromRGB(255, 80, 60), Material = "Glass", Lore = "A brooch fit for a pirate captain's lapel." },
	{ Id = "ObsidianDagger", Name = "Volcano Glass Dagger", Rarity = "Legendary", Zone = "TropicalIsland", Value = 11000, Shape = "Sword", Color = Color3.fromRGB(30, 25, 40), Accent = Color3.fromRGB(255, 90, 30), Material = "Glass", Glow = true, Lore = "Forged in lava, sharpened by the sea." },
	{ Id = "TikiKingMask", Name = "Tiki King's Mask", Rarity = "Mythical", Zone = "TropicalIsland", Value = 54000, Shape = "Mask", Color = Color3.fromRGB(160, 100, 50), Accent = Color3.fromRGB(255, 210, 60), Glow = true, Lore = "Worn by the first king of the island." },
	{ Id = "HeartOfTheIsland", Name = "Heart of the Island", Rarity = "Secret", Zone = "TropicalIsland", Value = 360000, Shape = "Gem", Color = Color3.fromRGB(255, 50, 80), Accent = Color3.fromRGB(255, 180, 200), Material = "Neon", Glow = true, Scale = 1.2, Lore = "The island's heartbeat, warm to the touch." },
	{ Id = "OrangeSeaStar", Name = "Orange Sea Star", Rarity = "Common", Zone = "TropicalIsland", Value = 72, Shape = "Starfish", Color = Color3.fromRGB(255, 140, 50), Accent = Color3.fromRGB(255, 220, 150), Lore = "Bright as a sunset, rough as sandpaper." },
	{ Id = "CoralBracelet", Name = "Coral Bead Bracelet", Rarity = "Common", Zone = "TropicalIsland", Value = 72, Shape = "Bracelet", Color = Color3.fromRGB(255, 120, 100), Accent = Color3.fromRGB(255, 220, 200), Material = "SmoothPlastic", Lore = "Made by island kids, sold for a smile." },
	{ Id = "PinkSandDollar", Name = "Pink Sand Dollar", Rarity = "Common", Zone = "TropicalIsland", Value = 72, Shape = "SandDollar", Color = Color3.fromRGB(255, 200, 210), Accent = Color3.fromRGB(255, 160, 180), Lore = "Pink sand made it pink. Probably." },
	{ Id = "SharkJawNecklace", Name = "Shark Tooth Necklace", Rarity = "Uncommon", Zone = "TropicalIsland", Value = 220, Shape = "Necklace", Color = Color3.fromRGB(240, 235, 220), Accent = Color3.fromRGB(245, 245, 235), Material = "Limestone", Lore = "Each tooth is a tall tale." },
	{ Id = "BambooDice", Name = "Bamboo Dice", Rarity = "Uncommon", Zone = "TropicalIsland", Value = 220, Shape = "Dice", Color = Color3.fromRGB(210, 180, 110), Accent = Color3.fromRGB(70, 40, 20), Material = "Wood", Lore = "Rolled for the last coconut." },
	{ Id = "CaptainDuck", Name = "Captain Rubber Duck", Rarity = "Uncommon", Zone = "TropicalIsland", Value = 250, Shape = "RubberDuck", Color = Color3.fromRGB(255, 220, 60), Accent = Color3.fromRGB(255, 120, 30), Lore = "Wears a tiny captain's hat. Respect it." },
	{ Id = "DiverGoggles", Name = "Pearl Diver's Goggles", Rarity = "Rare", Zone = "TropicalIsland", Value = 720, Shape = "Spectacles", Color = Color3.fromRGB(40, 60, 80), Accent = Color3.fromRGB(120, 220, 255), Lore = "Seen a hundred pearl beds." },
	{ Id = "CoralSeahorse", Name = "Coral Seahorse", Rarity = "Rare", Zone = "TropicalIsland", Value = 790, Shape = "Seahorse", Color = Color3.fromRGB(255, 130, 90), Accent = Color3.fromRGB(255, 220, 180), Lore = "Coral grew over it in the shape of a seahorse." },
	{ Id = "VolcanoMeteorite", Name = "Volcanic Meteorite", Rarity = "Epic", Zone = "TropicalIsland", Value = 2700, Shape = "Meteorite", Color = Color3.fromRGB(40, 30, 30), Accent = Color3.fromRGB(255, 90, 30), Lore = "Fell into the volcano and came back out." },
	{ Id = "IslandAmphora", Name = "Island Amphora", Rarity = "Epic", Zone = "TropicalIsland", Value = 3000, Shape = "Amphora", Color = Color3.fromRGB(200, 120, 70), Accent = Color3.fromRGB(40, 40, 40), MinLevel = 10, Lore = "Traded across the sea for spices and silk." },
	{ Id = "SunstoneBracelet", Name = "Sunstone Bracelet", Rarity = "Legendary", Zone = "TropicalIsland", Value = 11000, Shape = "Bracelet", Color = Color3.fromRGB(255, 170, 60), Accent = Color3.fromRGB(255, 240, 120), Glow = true, Lore = "Warm to the touch, even at midnight." },
	{ Id = "VolcanoRune", Name = "Volcano Rune Stone", Rarity = "Mythical", Zone = "TropicalIsland", Value = 54000, Shape = "RuneStone", Color = Color3.fromRGB(60, 45, 45), Accent = Color3.fromRGB(255, 100, 30), Material = "Basalt", Glow = true, Lore = "The rune glows brighter when the volcano rumbles." },

	-- AbandonedPier ----------------------------------------
	{ Id = "RustyHook", Name = "Rusty Hook", Rarity = "Common", Zone = "AbandonedPier", Value = 200, Shape = "Anchor", Color = Color3.fromRGB(150, 90, 60), Accent = Color3.fromRGB(110, 70, 50), Material = "CorrodedMetal", Scale = 0.6, Lore = "The one that got away took the line with it." },
	{ Id = "LanternGlass", Name = "Old Lantern Glass", Rarity = "Common", Zone = "AbandonedPier", Value = 200, Shape = "Bottle", Color = Color3.fromRGB(220, 230, 200), Accent = Color3.fromRGB(90, 90, 80), Material = "Glass", Lore = "Once lit the end of the pier." },
	{ Id = "ShipNail", Name = "Hand-Forged Ship Nail", Rarity = "Common", Zone = "AbandonedPier", Value = 180, Shape = "Bar", Color = Color3.fromRGB(90, 90, 95), Accent = Color3.fromRGB(70, 70, 75), Material = "Metal", Scale = 0.6, Lore = "Square-headed and centuries old." },
	{ Id = "PortholeRing", Name = "Brass Porthole Ring", Rarity = "Uncommon", Zone = "AbandonedPier", Value = 620, Shape = "Ring", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(120, 200, 230), Scale = 1.2, Lore = "Look through it and imagine the open sea." },
	{ Id = "DockBadge", Name = "Dock Master's Badge", Rarity = "Uncommon", Zone = "AbandonedPier", Value = 620, Shape = "Coin", Color = Color3.fromRGB(210, 210, 220), Accent = Color3.fromRGB(40, 70, 140), Lore = "Authority over every rope and crate." },
	{ Id = "MessageBottle", Name = "Message in a Bottle", Rarity = "Uncommon", Zone = "AbandonedPier", Value = 690, Shape = "Bottle", Color = Color3.fromRGB(120, 200, 170), Accent = Color3.fromRGB(240, 225, 180), Material = "Glass", Lore = "'If found: I was right about the treasure.'" },
	{ Id = "DivingWatch", Name = "Antique Diving Watch", Rarity = "Rare", Zone = "AbandonedPier", Value = 2000, Shape = "Watch", Color = Color3.fromRGB(60, 90, 140), Accent = Color3.fromRGB(230, 230, 240), Lore = "Rated to 300 metres. Dropped from 3." },
	{ Id = "GoldTooth", Name = "Fisherman's Gold Tooth", Rarity = "Rare", Zone = "AbandonedPier", Value = 2000, Shape = "Tooth", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(230, 180, 40), Material = "Metal", Scale = 0.7, MinLevel = 14, Lore = "He smiled a lot. Then he didn't." },
	{ Id = "ShipsBell", Name = "Ship's Bell", Rarity = "Epic", Zone = "AbandonedPier", Value = 7500, Shape = "Bell", Color = Color3.fromRGB(190, 140, 60), Accent = Color3.fromRGB(60, 40, 30), Lore = "Engraved with the ship's name: 'Persistence'." },
	{ Id = "Sextant", Name = "Navigator's Sextant", Rarity = "Epic", Zone = "AbandonedPier", Value = 8200, Shape = "Compass", Color = Color3.fromRGB(200, 170, 90), Accent = Color3.fromRGB(40, 60, 90), Lore = "Finds your place by the stars." },
	{ Id = "GhostKey", Name = "Ghost Captain's Key", Rarity = "Legendary", Zone = "AbandonedPier", Value = 30000, Shape = "Key", Color = Color3.fromRGB(120, 255, 220), Accent = Color3.fromRGB(40, 120, 110), Material = "Glass", Glow = true, Scale = 1.3, Lore = "Cold as the deep and faintly glowing." },
	{ Id = "LighthouseLens", Name = "Lighthouse Lens", Rarity = "Mythical", Zone = "AbandonedPier", Value = 150000, Shape = "Gem", Color = Color3.fromRGB(220, 250, 255), Accent = Color3.fromRGB(255, 240, 150), Material = "Glass", Glow = true, Scale = 1.3, Lore = "It still gathers light that isn't there." },
	{ Id = "DrownedCrown", Name = "The Drowned Crown", Rarity = "Secret", Zone = "AbandonedPier", Value = 1000000, Shape = "Crown", Color = Color3.fromRGB(60, 200, 190), Accent = Color3.fromRGB(255, 255, 255), Glow = true, Lore = "Worn by a king who ruled beneath the waves." },
	{ Id = "BentSpectacles", Name = "Bent Spectacles", Rarity = "Common", Zone = "AbandonedPier", Value = 200, Shape = "Spectacles", Color = Color3.fromRGB(150, 150, 155), Accent = Color3.fromRGB(200, 210, 215), Material = "CorrodedMetal", Lore = "Somebody sat on them. Then dropped them." },
	{ Id = "PierToken", Name = "Pier Arcade Token", Rarity = "Common", Zone = "AbandonedPier", Value = 200, Shape = "Coin", Color = Color3.fromRGB(200, 170, 80), Accent = Color3.fromRGB(120, 80, 40), Scale = 0.7, Lore = "Good for one go on the claw machine. In 1962." },
	{ Id = "RustyToyCar", Name = "Rusty Toy Car", Rarity = "Common", Zone = "AbandonedPier", Value = 200, Shape = "ToyCar", Color = Color3.fromRGB(120, 70, 50), Accent = Color3.fromRGB(180, 160, 140), Material = "CorrodedMetal", Lore = "Lost its paint. Kept its pride." },
	{ Id = "ShipsLantern", Name = "Ship's Lantern", Rarity = "Uncommon", Zone = "AbandonedPier", Value = 620, Shape = "Lantern", Color = Color3.fromRGB(60, 90, 70), Accent = Color3.fromRGB(255, 200, 90), Lore = "Swung from the bow on foggy nights." },
	{ Id = "SailorsMedal", Name = "Sailor's Medal", Rarity = "Uncommon", Zone = "AbandonedPier", Value = 620, Shape = "Medal", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(30, 60, 140), Lore = "For 25 years of keeping the pier afloat." },
	{ Id = "FishermansPipe", Name = "Fisherman's Pipe", Rarity = "Uncommon", Zone = "AbandonedPier", Value = 690, Shape = "Pipe", Color = Color3.fromRGB(120, 80, 50), Accent = Color3.fromRGB(200, 170, 90), Lore = "Still smells of cherry tobacco and sea air." },
	{ Id = "PocketHourglass", Name = "Pocket Hourglass", Rarity = "Rare", Zone = "AbandonedPier", Value = 2000, Shape = "Hourglass", Color = Color3.fromRGB(220, 200, 150), Accent = Color3.fromRGB(110, 70, 40), MinLevel = 14, Lore = "Timed the tides for the harbour master." },
	{ Id = "PortholeWindow", Name = "Porthole Window", Rarity = "Rare", Zone = "AbandonedPier", Value = 2200, Shape = "Porthole", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(120, 200, 230), Lore = "Look through it and the pier is busy again." },
	{ Id = "CaptainsLocket", Name = "Captain's Locket", Rarity = "Epic", Zone = "AbandonedPier", Value = 7500, Shape = "Locket", Color = Color3.fromRGB(255, 205, 70), Accent = Color3.fromRGB(30, 60, 140), Lore = "A portrait of a ship, not a sweetheart." },
	{ Id = "HarbourSpyglass", Name = "Harbour Master's Spyglass", Rarity = "Epic", Zone = "AbandonedPier", Value = 8200, Shape = "Spyglass", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(40, 40, 45), Lore = "Every ship that docked, it saw first." },
	{ Id = "PierShipWheel", Name = "Pier Ferry's Wheel", Rarity = "Legendary", Zone = "AbandonedPier", Value = 30000, Shape = "ShipWheel", Color = Color3.fromRGB(140, 95, 55), Accent = Color3.fromRGB(255, 205, 70), Glow = true, Lore = "Steered the last ferry before the pier closed." },
	{ Id = "PhantomLantern", Name = "Phantom Lantern", Rarity = "Mythical", Zone = "AbandonedPier", Value = 150000, Shape = "Lantern", Color = Color3.fromRGB(60, 80, 90), Accent = Color3.fromRGB(120, 255, 220), Material = "Glass", Glow = true, Lore = "Lights itself when nobody is looking." },

	-- ShipwreckCoast ----------------------------------------
	{ Id = "ShipRivet", Name = "Ship Rivet", Rarity = "Common", Zone = "ShipwreckCoast", Value = 560, Shape = "Coin", Color = Color3.fromRGB(90, 85, 80), Accent = Color3.fromRGB(60, 55, 50), Material = "CorrodedMetal", Scale = 0.6, Lore = "Held the hull together. Mostly." },
	{ Id = "CannonballShard", Name = "Cannonball Shard", Rarity = "Common", Zone = "ShipwreckCoast", Value = 560, Shape = "Orb", Color = Color3.fromRGB(40, 40, 45), Accent = Color3.fromRGB(90, 90, 95), Material = "Metal", Scale = 0.8, Lore = "Fired in anger, found in peace." },
	{ Id = "CutlassHilt", Name = "Broken Cutlass Hilt", Rarity = "Common", Zone = "ShipwreckCoast", Value = 500, Shape = "Sword", Color = Color3.fromRGB(150, 140, 120), Accent = Color3.fromRGB(100, 70, 40), Scale = 0.7, Lore = "The blade went one way, the pirate another." },
	{ Id = "SpanishReal", Name = "Spanish Silver Real", Rarity = "Uncommon", Zone = "ShipwreckCoast", Value = 1800, Shape = "Coin", Color = Color3.fromRGB(220, 220, 230), Accent = Color3.fromRGB(170, 170, 180), Material = "Metal", Lore = "Pieces of eight! Well, one piece." },
	{ Id = "GrogBottle", Name = "Grog Bottle", Rarity = "Uncommon", Zone = "ShipwreckCoast", Value = 1800, Shape = "Bottle", Color = Color3.fromRGB(110, 70, 30), Accent = Color3.fromRGB(230, 220, 200), Material = "Glass", Lore = "Smells faintly of bad decisions." },
	{ Id = "BrassSpyglass", Name = "Brass Spyglass", Rarity = "Uncommon", Zone = "ShipwreckCoast", Value = 1900, Shape = "Can", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(60, 40, 30), Material = "Metal", Lore = "Land ho! (It's foggy.)" },
	{ Id = "GoldIngot", Name = "Gold Ingot", Rarity = "Rare", Zone = "ShipwreckCoast", Value = 5600, Shape = "Bar", Color = Color3.fromRGB(255, 200, 50), Accent = Color3.fromRGB(220, 170, 30), Material = "Metal", Lore = "Stamped with a royal seal." },
	{ Id = "AdmiralsMedal", Name = "Admiral's Medal", Rarity = "Rare", Zone = "ShipwreckCoast", Value = 6200, Shape = "Coin", Color = Color3.fromRGB(255, 205, 70), Accent = Color3.fromRGB(180, 30, 40), Material = "Metal", MinLevel = 20, Lore = "For valour at sea. Lost at sea." },
	{ Id = "JeweledGoblet", Name = "Jeweled Goblet", Rarity = "Epic", Zone = "ShipwreckCoast", Value = 21000, Shape = "Goblet", Color = Color3.fromRGB(255, 200, 60), Accent = Color3.fromRGB(200, 30, 60), Material = "Metal", Lore = "Pirates drank from it. Kings before them." },
	{ Id = "PirateCompass", Name = "Pirate Captain's Compass", Rarity = "Epic", Zone = "ShipwreckCoast", Value = 23000, Shape = "Compass", Color = Color3.fromRGB(255, 205, 70), Accent = Color3.fromRGB(30, 30, 30), Lore = "Points to whatever you want most." },
	{ Id = "RoyalChest", Name = "Royal Treasure Chest", Rarity = "Legendary", Zone = "ShipwreckCoast", Value = 84000, Shape = "Chest", Color = Color3.fromRGB(140, 90, 40), Accent = Color3.fromRGB(255, 210, 60), Glow = true, Scale = 1.1, Lore = "Overflowing with the king's own gold." },
	{ Id = "KrakensTrident", Name = "Kraken's Trident", Rarity = "Mythical", Zone = "ShipwreckCoast", Value = 420000, Shape = "Trident", Color = Color3.fromRGB(60, 140, 140), Accent = Color3.fromRGB(200, 255, 240), Glow = true, Lore = "Taken from a sea monster. It wants it back." },
	{ Id = "GhostAnchor", Name = "Ghost Ship Anchor", Rarity = "Secret", Zone = "ShipwreckCoast", Value = 2800000, Shape = "Anchor", Color = Color3.fromRGB(150, 255, 230), Accent = Color3.fromRGB(255, 255, 255), Material = "Glass", Glow = true, Scale = 1.2, Lore = "From a ship that sails only on foggy nights." },
	{ Id = "MusketBall", Name = "Musket Ball", Rarity = "Common", Zone = "ShipwreckCoast", Value = 560, Shape = "Orb", Color = Color3.fromRGB(80, 80, 85), Accent = Color3.fromRGB(60, 60, 65), Material = "Metal", Scale = 0.5, Lore = "Fired from a pirate's pistol. Missed." },
	{ Id = "BarnacleBottle", Name = "Barnacled Bottle", Rarity = "Common", Zone = "ShipwreckCoast", Value = 560, Shape = "Bottle", Color = Color3.fromRGB(80, 110, 70), Accent = Color3.fromRGB(200, 190, 170), Material = "Glass", Lore = "The barnacles have claimed it as their home." },
	{ Id = "BoneDice", Name = "Bone Dice", Rarity = "Common", Zone = "ShipwreckCoast", Value = 560, Shape = "Dice", Color = Color3.fromRGB(235, 225, 200), Accent = Color3.fromRGB(30, 30, 30), Material = "Limestone", Lore = "Loaded. Of course they're loaded." },
	{ Id = "PiratePipe", Name = "Pirate's Clay Pipe", Rarity = "Uncommon", Zone = "ShipwreckCoast", Value = 1800, Shape = "Pipe", Color = Color3.fromRGB(230, 220, 200), Accent = Color3.fromRGB(120, 80, 50), Material = "Limestone", Lore = "Puffed on the poop deck at dawn." },
	{ Id = "RumJug", Name = "Clay Rum Jug", Rarity = "Uncommon", Zone = "ShipwreckCoast", Value = 1900, Shape = "Amphora", Color = Color3.fromRGB(150, 100, 60), Accent = Color3.fromRGB(60, 40, 30), Lore = "Empty. Suspiciously empty." },
	{ Id = "BrassPorthole", Name = "Brass Porthole", Rarity = "Uncommon", Zone = "ShipwreckCoast", Value = 1800, Shape = "Porthole", Color = Color3.fromRGB(200, 160, 70), Accent = Color3.fromRGB(60, 140, 170), Lore = "Pried from the captain's cabin wall." },
	{ Id = "NavigatorsHourglass", Name = "Navigator's Hourglass", Rarity = "Rare", Zone = "ShipwreckCoast", Value = 5600, Shape = "Hourglass", Color = Color3.fromRGB(230, 210, 160), Accent = Color3.fromRGB(80, 50, 30), Lore = "Measured the ship's speed, knot by knot." },
	{ Id = "EmeraldNecklace", Name = "Emerald Necklace", Rarity = "Rare", Zone = "ShipwreckCoast", Value = 6200, Shape = "Necklace", Color = Color3.fromRGB(255, 205, 70), Accent = Color3.fromRGB(30, 200, 90), MinLevel = 20, Lore = "Looted twice, lost once, found by you." },
	{ Id = "CaptainsWheel", Name = "Captain's Ship Wheel", Rarity = "Epic", Zone = "ShipwreckCoast", Value = 21000, Shape = "ShipWheel", Color = Color3.fromRGB(110, 70, 40), Accent = Color3.fromRGB(255, 205, 70), Lore = "Held fast through the storm that sank her." },
	{ Id = "PirateGoldLocket", Name = "Pirate's Gold Locket", Rarity = "Epic", Zone = "ShipwreckCoast", Value = 23000, Shape = "Locket", Color = Color3.fromRGB(255, 200, 50), Accent = Color3.fromRGB(200, 30, 40), Lore = "A lock of hair and a map scrap inside." },
	{ Id = "AdmiralsSpyglass", Name = "Admiral's Spyglass", Rarity = "Legendary", Zone = "ShipwreckCoast", Value = 84000, Shape = "Spyglass", Color = Color3.fromRGB(255, 205, 70), Accent = Color3.fromRGB(20, 40, 90), Glow = true, Lore = "Spotted the treasure fleet before anyone else." },
	{ Id = "AbyssalLantern", Name = "Abyssal Lantern", Rarity = "Mythical", Zone = "ShipwreckCoast", Value = 420000, Shape = "Lantern", Color = Color3.fromRGB(30, 40, 60), Accent = Color3.fromRGB(80, 160, 255), Material = "Metal", Glow = true, Lore = "Lit by something living deep below." },

	-- AncientRuins ----------------------------------------
	{ Id = "PotteryShard", Name = "Pottery Shard", Rarity = "Common", Zone = "AncientRuins", Value = 1600, Shape = "Tooth", Color = Color3.fromRGB(190, 110, 70), Accent = Color3.fromRGB(90, 50, 30), Scale = 1.2, Lore = "Painted with waves and tiny fish." },
	{ Id = "ClayBead", Name = "Clay Bead", Rarity = "Common", Zone = "AncientRuins", Value = 1600, Shape = "Orb", Color = Color3.fromRGB(200, 130, 80), Accent = Color3.fromRGB(240, 200, 150), Scale = 0.6, Lore = "Strung on a necklace three thousand years ago." },
	{ Id = "TabletPiece", Name = "Stone Tablet Piece", Rarity = "Common", Zone = "AncientRuins", Value = 1600, Shape = "Bar", Color = Color3.fromRGB(160, 160, 150), Accent = Color3.fromRGB(110, 110, 100), Material = "Slate", Lore = "Carved in a language no one speaks." },
	{ Id = "BronzeCoin", Name = "Bronze Temple Coin", Rarity = "Uncommon", Zone = "AncientRuins", Value = 5000, Shape = "Coin", Color = Color3.fromRGB(200, 130, 60), Accent = Color3.fromRGB(120, 80, 40), Material = "Metal", Lore = "Offered to the sea for good fortune." },
	{ Id = "ObsidianArrowhead", Name = "Obsidian Arrowhead", Rarity = "Uncommon", Zone = "AncientRuins", Value = 5000, Shape = "Tooth", Color = Color3.fromRGB(30, 30, 40), Accent = Color3.fromRGB(90, 80, 110), Material = "Glass", Lore = "Razor sharp after all these years." },
	{ Id = "ScarabAmulet", Name = "Scarab Amulet", Rarity = "Uncommon", Zone = "AncientRuins", Value = 5500, Shape = "Gem", Color = Color3.fromRGB(40, 110, 220), Accent = Color3.fromRGB(255, 200, 60), Lore = "A beetle of lapis and gold." },
	{ Id = "GoldenIdol", Name = "Golden Idol", Rarity = "Rare", Zone = "AncientRuins", Value = 16000, Shape = "Statue", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(40, 200, 140), Material = "Metal", Lore = "Don't swap it for a bag of sand." },
	{ Id = "AncientSeaChart", Name = "Ancient Sea Chart", Rarity = "Rare", Zone = "AncientRuins", Value = 16000, Shape = "Scroll", Color = Color3.fromRGB(230, 210, 160), Accent = Color3.fromRGB(160, 40, 40), Lore = "Marks an island no living sailor has seen. Finding it reveals the way to Secret Treasure Island." },
	{ Id = "SunDisk", Name = "Sun Disk", Rarity = "Epic", Zone = "AncientRuins", Value = 60000, Shape = "Coin", Color = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(255, 120, 30), Glow = true, Scale = 1.4, Lore = "Once caught the first light of every solstice." },
	{ Id = "CeremonialGoblet", Name = "Ceremonial Goblet", Rarity = "Epic", Zone = "AncientRuins", Value = 66000, Shape = "Goblet", Color = Color3.fromRGB(230, 230, 240), Accent = Color3.fromRGB(60, 140, 255), Material = "Metal", Lore = "Silver and lapis, for the Tide Kings' feasts." },
	{ Id = "TideKingsCrown", Name = "Crown of the Tide Kings", Rarity = "Legendary", Zone = "AncientRuins", Value = 240000, Shape = "Crown", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(40, 170, 255), Glow = true, Lore = "Seven kings wore it. Seven kings vanished." },
	{ Id = "SeaPharaohMask", Name = "Sea Pharaoh's Mask", Rarity = "Mythical", Zone = "AncientRuins", Value = 1200000, Shape = "Mask", Color = Color3.fromRGB(255, 200, 50), Accent = Color3.fromRGB(30, 80, 200), Glow = true, Lore = "Gold, lapis and a gaze that follows you." },
	{ Id = "AtlanteanCore", Name = "Atlantean Core", Rarity = "Secret", Zone = "AncientRuins", Value = 8000000, Shape = "Orb", Color = Color3.fromRGB(60, 255, 255), Accent = Color3.fromRGB(255, 255, 255), Material = "Neon", Glow = true, Lore = "Power source of a lost civilisation." },
	{ Id = "BoneFragment", Name = "Bone Fragment", Rarity = "Common", Zone = "AncientRuins", Value = 1600, Shape = "Bone", Color = Color3.fromRGB(220, 210, 185), Accent = Color3.fromRGB(180, 170, 150), Scale = 0.8, Lore = "From an offering left on the temple steps." },
	{ Id = "ClayDice", Name = "Clay Dice", Rarity = "Common", Zone = "AncientRuins", Value = 1600, Shape = "Dice", Color = Color3.fromRGB(200, 130, 80), Accent = Color3.fromRGB(60, 30, 20), Material = "Sandstone", Lore = "The temple priests played for incense." },
	{ Id = "FossilShell", Name = "Fossil Shell", Rarity = "Common", Zone = "AncientRuins", Value = 1600, Shape = "Ammonite", Color = Color3.fromRGB(200, 180, 140), Accent = Color3.fromRGB(150, 130, 100), Scale = 0.7, Lore = "The ruins were built on an ancient sea floor." },
	{ Id = "BronzeBracelet", Name = "Bronze Arm Ring", Rarity = "Uncommon", Zone = "AncientRuins", Value = 5000, Shape = "Bracelet", Color = Color3.fromRGB(200, 130, 60), Accent = Color3.fromRGB(60, 160, 140), Lore = "Worn by temple guards above the elbow." },
	{ Id = "ClayAmphora", Name = "Clay Amphora", Rarity = "Uncommon", Zone = "AncientRuins", Value = 5000, Shape = "Amphora", Color = Color3.fromRGB(200, 120, 70), Accent = Color3.fromRGB(40, 30, 30), Lore = "Painted with dolphins leaping over waves." },
	{ Id = "TrilobiteImprint", Name = "Trilobite Imprint", Rarity = "Uncommon", Zone = "AncientRuins", Value = 5500, Shape = "Trilobite", Color = Color3.fromRGB(170, 160, 140), Accent = Color3.fromRGB(110, 100, 90), Lore = "Pressed into the temple's foundation stone." },
	{ Id = "TempleRune", Name = "Temple Rune Stone", Rarity = "Rare", Zone = "AncientRuins", Value = 16000, Shape = "RuneStone", Color = Color3.fromRGB(150, 145, 135), Accent = Color3.fromRGB(60, 200, 255), MinLevel = 26, Lore = "Carved with the word for 'tide'." },
	{ Id = "LapisNecklace", Name = "Lapis Necklace", Rarity = "Rare", Zone = "AncientRuins", Value = 18000, Shape = "Necklace", Color = Color3.fromRGB(255, 200, 50), Accent = Color3.fromRGB(30, 70, 200), Lore = "Blue as the deep, gold as the sun." },
	{ Id = "GoldenHourglass", Name = "Golden Hourglass", Rarity = "Epic", Zone = "AncientRuins", Value = 60000, Shape = "Hourglass", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(255, 205, 60), Material = "Metal", Lore = "Its sand has been falling for a thousand years." },
	{ Id = "TempleSeahorse", Name = "Temple Seahorse Idol", Rarity = "Epic", Zone = "AncientRuins", Value = 66000, Shape = "Seahorse", Color = Color3.fromRGB(255, 200, 50), Accent = Color3.fromRGB(40, 170, 255), Material = "Metal", Lore = "Guardian of the sea-gate." },
	{ Id = "StarfallMeteorite", Name = "Starfall Meteorite", Rarity = "Legendary", Zone = "AncientRuins", Value = 240000, Shape = "Meteorite", Color = Color3.fromRGB(60, 50, 70), Accent = Color3.fromRGB(170, 120, 255), Glow = true, Lore = "The temple was built where it landed." },
	{ Id = "OraclesAmphora", Name = "Oracle's Amphora", Rarity = "Mythical", Zone = "AncientRuins", Value = 1200000, Shape = "Amphora", Color = Color3.fromRGB(240, 230, 210), Accent = Color3.fromRGB(60, 200, 255), Material = "Marble", Glow = true, Lore = "Whisper a question into it. Listen." },

	-- SecretIsland ----------------------------------------
	{ Id = "GildedShell", Name = "Gilded Shell", Rarity = "Common", Zone = "SecretIsland", Value = 4800, Shape = "Shell", Color = Color3.fromRGB(255, 210, 80), Accent = Color3.fromRGB(255, 240, 200), Material = "Metal", Lore = "Even the shells here are made of gold." },
	{ Id = "RubyChip", Name = "Ruby Chip", Rarity = "Common", Zone = "SecretIsland", Value = 4800, Shape = "Gem", Color = Color3.fromRGB(220, 30, 50), Accent = Color3.fromRGB(255, 150, 160), Material = "Glass", Scale = 0.6, Lore = "A fragment of something much bigger." },
	{ Id = "AncientDoubloon", Name = "Ancient Doubloon", Rarity = "Common", Zone = "SecretIsland", Value = 4800, Shape = "Coin", Color = Color3.fromRGB(255, 200, 40), Accent = Color3.fromRGB(200, 150, 20), Material = "Metal", Lore = "Gold so old it predates kings." },
	{ Id = "SapphireRing", Name = "Sapphire Ring", Rarity = "Uncommon", Zone = "SecretIsland", Value = 15000, Shape = "Ring", Color = Color3.fromRGB(220, 220, 235), Accent = Color3.fromRGB(40, 80, 230), Lore = "A deep-blue stone on a platinum band." },
	{ Id = "PirateEarring", Name = "Pirate King's Earring", Rarity = "Uncommon", Zone = "SecretIsland", Value = 15000, Shape = "Ring", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(220, 30, 50), Scale = 0.7, Lore = "Arr. It's heavier than it looks." },
	{ Id = "SilverStack", Name = "Stack of Silver Coins", Rarity = "Uncommon", Zone = "SecretIsland", Value = 16000, Shape = "CoinStack", Color = Color3.fromRGB(220, 220, 230), Accent = Color3.fromRGB(180, 180, 190), Material = "Metal", Lore = "Someone was saving up." },
	{ Id = "DiamondPendant", Name = "Diamond Pendant", Rarity = "Rare", Zone = "SecretIsland", Value = 48000, Shape = "Gem", Color = Color3.fromRGB(240, 250, 255), Accent = Color3.fromRGB(200, 220, 255), Material = "Glass", Lore = "Flawless, cold and impossibly bright." },
	{ Id = "CursedSkull", Name = "Cursed Skull", Rarity = "Rare", Zone = "SecretIsland", Value = 53000, Shape = "Skull", Color = Color3.fromRGB(230, 225, 200), Accent = Color3.fromRGB(60, 255, 120), Lore = "Its eyes glow green when the moon is full." },
	{ Id = "LegendsMap", Name = "Map of Legends", Rarity = "Epic", Zone = "SecretIsland", Value = 180000, Shape = "Scroll", Color = Color3.fromRGB(240, 220, 170), Accent = Color3.fromRGB(40, 40, 40), Lore = "Every X on it has already been dug... except one." },
	{ Id = "GoldenSkull", Name = "Golden Skull", Rarity = "Epic", Zone = "SecretIsland", Value = 200000, Shape = "Skull", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(255, 80, 60), Material = "Metal", Lore = "A pirate king's last joke." },
	{ Id = "DavyJonesLocker", Name = "Davy Jones' Locker", Rarity = "Legendary", Zone = "SecretIsland", Value = 720000, Shape = "Chest", Color = Color3.fromRGB(30, 70, 80), Accent = Color3.fromRGB(90, 255, 220), Glow = true, Scale = 1.1, Lore = "Every sailor's fear. Now yours to keep." },
	{ Id = "PoseidonsTrident", Name = "Poseidon's Trident", Rarity = "Mythical", Zone = "SecretIsland", Value = 3600000, Shape = "Trident", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(90, 220, 255), Glow = true, Lore = "Strike the sand and the sea parts." },
	{ Id = "EyeOfTheOcean", Name = "Eye of the Ocean", Rarity = "Secret", Zone = "SecretIsland", Value = 24000000, Shape = "Gem", Color = Color3.fromRGB(40, 120, 255), Accent = Color3.fromRGB(180, 240, 255), Material = "Neon", Glow = true, Scale = 1.4, Lore = "The single greatest treasure of the sea." },
	{ Id = "GoldenDice", Name = "Golden Dice", Rarity = "Common", Zone = "SecretIsland", Value = 4800, Shape = "Dice", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(40, 30, 10), Material = "Metal", Lore = "Always rolls a six. Always." },
	{ Id = "PearlStarfish", Name = "Pearl Starfish", Rarity = "Common", Zone = "SecretIsland", Value = 4800, Shape = "Starfish", Color = Color3.fromRGB(250, 245, 255), Accent = Color3.fromRGB(220, 200, 255), Material = "Glass", Lore = "Mother-of-pearl, shimmering in five colours." },
	{ Id = "GoldSandDollar", Name = "Gold Sand Dollar", Rarity = "Common", Zone = "SecretIsland", Value = 4800, Shape = "SandDollar", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(220, 170, 40), Material = "Metal", Lore = "Finally, a sand dollar shops accept." },
	{ Id = "RubyBracelet", Name = "Ruby Bracelet", Rarity = "Uncommon", Zone = "SecretIsland", Value = 15000, Shape = "Bracelet", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(220, 20, 50), Lore = "Seven rubies, one for each sea." },
	{ Id = "GoldenDuck", Name = "Golden Rubber Duck", Rarity = "Uncommon", Zone = "SecretIsland", Value = 15000, Shape = "RubberDuck", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(255, 150, 40), Material = "Metal", Lore = "Doesn't float. Doesn't care." },
	{ Id = "EmeraldLocket", Name = "Emerald Locket", Rarity = "Uncommon", Zone = "SecretIsland", Value = 15000, Shape = "Locket", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(30, 200, 90), Lore = "Holds a pressed island flower." },
	{ Id = "OpalNecklace", Name = "Opal Necklace", Rarity = "Rare", Zone = "SecretIsland", Value = 53000, Shape = "Necklace", Color = Color3.fromRGB(230, 230, 240), Accent = Color3.fromRGB(160, 230, 255), Lore = "Every opal shows a different sky." },
	{ Id = "CrystalHourglass", Name = "Crystal Hourglass", Rarity = "Rare", Zone = "SecretIsland", Value = 48000, Shape = "Hourglass", Color = Color3.fromRGB(220, 240, 255), Accent = Color3.fromRGB(160, 200, 255), Material = "Glass", Lore = "The sand inside is ground diamond." },
	{ Id = "GoldenShipWheel", Name = "Golden Ship Wheel", Rarity = "Epic", Zone = "SecretIsland", Value = 180000, Shape = "ShipWheel", Color = Color3.fromRGB(255, 205, 60), Accent = Color3.fromRGB(255, 240, 180), Material = "Metal", Lore = "From the flagship of the pirate king." },
	{ Id = "DiamondSpectacles", Name = "Diamond Spectacles", Rarity = "Epic", Zone = "SecretIsland", Value = 200000, Shape = "Spectacles", Color = Color3.fromRGB(240, 240, 250), Accent = Color3.fromRGB(220, 240, 255), MinLevel = 34, Lore = "See every treasure for miles. Or so they say." },
	{ Id = "DeepMeteor", Name = "Meteor of the Deep", Rarity = "Legendary", Zone = "SecretIsland", Value = 720000, Shape = "Meteorite", Color = Color3.fromRGB(20, 30, 60), Accent = Color3.fromRGB(80, 220, 255), Glow = true, Lore = "Fell into the ocean and grew brighter." },
	{ Id = "TidecallerRune", Name = "Tidecaller Rune", Rarity = "Mythical", Zone = "SecretIsland", Value = 3600000, Shape = "RuneStone", Color = Color3.fromRGB(40, 60, 90), Accent = Color3.fromRGB(90, 255, 230), Material = "Slate", Glow = true, Lore = "Touch it and the waves bow." },
	{ Id = "ClockworkHeart", Name = "Clockwork Heart", Rarity = "Secret", Zone = "SecretIsland", Value = 24000000, Shape = "Locket", Color = Color3.fromRGB(230, 200, 120), Accent = Color3.fromRGB(255, 80, 60), Material = "Metal", Glow = true, Scale = 1.3, Lore = "Still ticking, deep under the sand. Whose was it?" },

	-- Event: Moonlit Night (can appear in any zone while the event runs) ---------
	{ Id = "MoonlitLocket", Name = "Moonlit Locket", Rarity = "Uncommon", Zone = "Event", Value = 32, Shape = "Locket", Color = Color3.fromRGB(220, 225, 240), Accent = Color3.fromRGB(150, 170, 255), Glow = true, Event = "MoonlitNight", ScalesWithZone = true, Lore = "Opens only under the full moon." },
	{ Id = "Moonstone", Name = "Moonstone", Rarity = "Rare", Zone = "Event", Value = 100, Shape = "Gem", Color = Color3.fromRGB(200, 220, 255), Accent = Color3.fromRGB(255, 255, 255), Glow = true, Event = "MoonlitNight", ScalesWithZone = true, Lore = "Glows softly only under a moonlit sky." },
	{ Id = "LunarPearl", Name = "Lunar Pearl", Rarity = "Epic", Zone = "Event", Value = 390, Shape = "Orb", Color = Color3.fromRGB(230, 230, 255), Accent = Color3.fromRGB(150, 170, 255), Glow = true, Event = "MoonlitNight", ScalesWithZone = true, Lore = "A pearl that formed in moonlight." },
	{ Id = "StarfallShard", Name = "Starfall Shard", Rarity = "Legendary", Zone = "Event", Value = 1600, Shape = "Gem", Color = Color3.fromRGB(180, 140, 255), Accent = Color3.fromRGB(255, 255, 255), Material = "Neon", Glow = true, Scale = 1.2, Event = "MoonlitNight", ScalesWithZone = true, Lore = "Fell from the sky on a moonlit night." },
	{ Id = "CrescentCrown", Name = "Crescent Crown", Rarity = "Mythical", Zone = "Event", Value = 7800, Shape = "Crown", Color = Color3.fromRGB(220, 225, 240), Accent = Color3.fromRGB(150, 180, 255), Glow = true, Event = "MoonlitNight", ScalesWithZone = true, Lore = "Crowned by the moon itself." },
}

Treasures.ById = {}
Treasures.ByZone = {}
Treasures.ByEvent = {}

for order, def in Treasures.List do
	def.Order = order
	assert(Treasures.ById[def.Id] == nil, "Duplicate treasure id: " .. def.Id)
	Treasures.ById[def.Id] = def
	if def.Event then
		Treasures.ByEvent[def.Event] = Treasures.ByEvent[def.Event] or {}
		table.insert(Treasures.ByEvent[def.Event], def)
	else
		Treasures.ByZone[def.Zone] = Treasures.ByZone[def.Zone] or {}
		table.insert(Treasures.ByZone[def.Zone], def)
	end
end

Treasures.Count = #Treasures.List

function Treasures.Get(id: string)
	return Treasures.ById[id]
end

-- Treasures of one rarity a player can find in a zone at their level.
function Treasures.GetPool(zoneId: string, rarity: string, level: number)
	local pool = {}
	for _, def in Treasures.ByZone[zoneId] or {} do
		if def.Rarity == rarity and (def.MinLevel == nil or level >= def.MinLevel) then
			table.insert(pool, def)
		end
	end
	return pool
end

function Treasures.GetEventPool(eventId: string)
	return Treasures.ByEvent[eventId] or {}
end

return Treasures
