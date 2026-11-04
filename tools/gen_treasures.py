# Generates src/shared/Config/Treasures.lua from a compact spec (values computed from rarity x zone).
import math
RB = {"C":("Common",8),"U":("Uncommon",25),"R":("Rare",80),"E":("Epic",300),"L":("Legendary",1200),"M":("Mythical",6000),"S":("Secret",40000)}
ZM = {"StartingBeach":1,"RockyShore":3,"TropicalIsland":9,"AbandonedPier":25,"ShipwreckCoast":70,"AncientRuins":200,"SecretIsland":600}

def nice(v):
    if v < 100: return int(round(v))
    mag = 10 ** (int(math.log10(v)) - 1)
    return int(round(v / mag) * mag)

# id, name, rarity, shape, color, accent, lore, opts
T = {
"StartingBeach": [
 ("BottleCap","Bottle Cap","C","Coin",(200,60,60),(230,230,230),"Someone's soda went flat in 1987.",dict(mul=0.8,mat="Metal",scale=0.7)),
 ("OldPenny","Old Penny","C","Coin",(184,115,51),(150,90,40),"Heads up! Well... it's face-down in the sand.",dict(mat="Metal",scale=0.8)),
 ("SpiralSeashell","Spiral Seashell","C","Shell",(250,220,200),(240,160,150),"Hold it to your ear and you can hear the ocean. Probably.",dict(mul=1.1)),
 ("SodaCan","Crushed Soda Can","C","Can",(60,140,220),(220,220,220),"Not treasure, but the beach is cleaner now.",dict(mul=0.7,mat="Metal")),
 ("LostCarKey","Lost Car Key","U","Key",(200,200,210),(40,40,40),"Somewhere, a very sunburnt tourist is still looking.",dict(mat="Metal")),
 ("SilverDime","Silver Dime","U","Coin",(215,215,225),(180,180,190),"Older than your grandparents and still shiny.",dict(mul=1.1,mat="Metal",scale=0.8)),
 ("SeaGlassBottle","Sea Glass Bottle","U","Bottle",(90,190,140),(140,100,60),"Tumbled smooth by a thousand tides.",dict(mat="Glass")),
 ("WeddingRing","Lost Wedding Ring","R","Ring",(255,205,70),(240,250,255),"Engraved: 'Forever, M.' Someone will be very happy.",dict(minLevel=2)),
 ("VintageWristwatch","Vintage Wristwatch","R","Watch",(220,190,120),(60,40,30),"Still ticking. Waterproof, as advertised.",dict(mul=1.1)),
 ("BrassCompass","Brass Compass","E","Compass",(205,160,70),(200,40,40),"Its needle points to treasure, not north.",{}),
 ("GoldenBracelet","Golden Bracelet","E","Ring",(255,200,60),(255,240,180),"Heavy, warm, and definitely real gold.",dict(mul=1.15,scale=1.2,minLevel=3)),
 ("PirateDoubloon","Pirate Doubloon","L","Coin",(255,200,40),(200,150,20),"Spanish gold, 1715. The first sign the legends are true.",dict(mat="Metal",glow=True)),
 ("MermaidsPearl","Mermaid's Pearl","M","Orb",(250,245,255),(200,220,255),"It shimmers like moonlight on water.",dict(glow=True)),
 ("SunkenStarFragment","Sunken Star Fragment","S","Gem",(255,240,120),(255,255,255),"A piece of a falling star that cooled in the sea.",dict(mat="Neon",glow=True)),
],
"RockyShore": [
 ("CrabShell","Crab Shell","C","Shell",(230,110,60),(250,200,170),"The crab moved out. No forwarding address.",{}),
 ("LeadSinker","Lead Sinker","C","Orb",(120,120,130),(90,90,100),"A fisherman's weight, lost to the rocks.",dict(mul=0.9,mat="Metal",scale=0.6)),
 ("RustedBolt","Rusted Bolt","C","Bar",(140,80,50),(110,60,40),"From a lighthouse that no longer stands.",dict(mul=0.9,mat="CorrodedMetal",scale=0.7)),
 ("CopperBracelet","Copper Bracelet","U","Ring",(190,110,60),(60,170,140),"Green patina means it's been here a long time.",{}),
 ("AntiqueButton","Antique Button","U","Coin",(200,170,90),(120,90,40),"From a sea captain's coat.",dict(mul=0.9,scale=0.7)),
 ("PocketKnife","Old Pocket Knife","U","Sword",(190,190,200),(110,60,40),"Rusty blade, handsome bone handle.",dict(mul=1.1,scale=0.6,minLevel=5)),
 ("SilverPocketWatch","Silver Pocket Watch","R","Watch",(215,215,225),(30,30,40),"Stopped at 4:12, the moment it hit the water.",{}),
 ("TidepoolOpal","Tidepool Opal","R","Gem",(120,220,230),(255,200,240),"Flashes every colour of the shallows.",dict(mul=1.1,mat="Glass")),
 ("KeepersBell","Lighthouse Keeper's Bell","E","Bell",(200,150,60),(90,60,30),"Rang through the fog for forty years.",{}),
 ("GeodeHeart","Geode Heart","E","Gem",(150,80,220),(230,200,255),"Crack it open and it sparkles like a galaxy.",dict(mul=1.1,minLevel=6)),
 ("SmugglersLockbox","Smuggler's Lockbox","L","Chest",(80,70,70),(200,170,80),"Still locked. Whatever's inside, it rattles.",dict(glow=True)),
 ("SirensConch","Siren's Conch","M","Shell",(255,200,230),(255,120,180),"Blow it and the waves fall silent.",dict(glow=True,scale=1.2)),
 ("KrakenEye","Fossilized Kraken Eye","S","Orb",(255,170,40),(60,20,0),"It's watching. It has always been watching.",dict(mat="Glass",glow=True)),
],
"TropicalIsland": [
 ("CoconutCup","Coconut Cup","C","Goblet",(120,80,45),(230,220,200),"Perfect for juice. Less perfect after the sand.",{}),
 ("SharkTooth","Shark Tooth","C","Tooth",(245,245,235),(200,200,190),"Sharks lose thousands. This one was big.",{}),
 ("PaintedShell","Painted Shell","C","Shell",(255,150,190),(120,220,255),"Painted by a child, kept by the sea.",{}),
 ("JadeTurtle","Jade Turtle Charm","U","Statue",(80,190,120),(40,120,80),"Islanders say it brings safe voyages.",dict(scale=0.7)),
 ("PukaNecklace","Puka Shell Necklace","U","Ring",(245,240,225),(180,140,90),"Very surf. Very 1998.",dict(mul=0.9)),
 ("TikiBottle","Tiki Bottle","U","Bottle",(170,110,60),(60,180,120),"Carved face, empty belly.",dict(mul=1.1)),
 ("GoldNugget","Gold Nugget","R","Gem",(255,200,50),(200,150,30),"Washed down from the island's volcano streams.",dict(mat="Metal",scale=0.8)),
 ("TikiIdol","Carved Tiki Idol","R","Statue",(140,90,50),(240,200,80),"Grinning at you. Is that... a wink?",dict(mul=1.1,minLevel=9)),
 ("BlackPearl","Black Pearl","E","Orb",(40,40,55),(140,120,200),"Rarer than gold. Darker than the deep.",dict(scale=0.8)),
 ("EmeraldParrot","Emerald Parrot Pin","E","Gem",(40,200,90),(255,80,60),"A brooch fit for a pirate captain's lapel.",dict(mul=1.1,mat="Glass")),
 ("ObsidianDagger","Volcano Glass Dagger","L","Sword",(30,25,40),(255,90,30),"Forged in lava, sharpened by the sea.",dict(mat="Glass",glow=True)),
 ("TikiKingMask","Tiki King's Mask","M","Mask",(160,100,50),(255,210,60),"Worn by the first king of the island.",dict(glow=True)),
 ("HeartOfTheIsland","Heart of the Island","S","Gem",(255,50,80),(255,180,200),"The island's heartbeat, warm to the touch.",dict(mat="Neon",glow=True,scale=1.2)),
],
"AbandonedPier": [
 ("RustyHook","Rusty Hook","C","Anchor",(150,90,60),(110,70,50),"The one that got away took the line with it.",dict(mat="CorrodedMetal",scale=0.6)),
 ("LanternGlass","Old Lantern Glass","C","Bottle",(220,230,200),(90,90,80),"Once lit the end of the pier.",dict(mat="Glass")),
 ("ShipNail","Hand-Forged Ship Nail","C","Bar",(90,90,95),(70,70,75),"Square-headed and centuries old.",dict(mul=0.9,mat="Metal",scale=0.6)),
 ("PortholeRing","Brass Porthole Ring","U","Ring",(200,160,70),(120,200,230),"Look through it and imagine the open sea.",dict(scale=1.2)),
 ("DockBadge","Dock Master's Badge","U","Coin",(210,210,220),(40,70,140),"Authority over every rope and crate.",{}),
 ("MessageBottle","Message in a Bottle","U","Bottle",(120,200,170),(240,225,180),"'If found: I was right about the treasure.'",dict(mul=1.1,mat="Glass")),
 ("DivingWatch","Antique Diving Watch","R","Watch",(60,90,140),(230,230,240),"Rated to 300 metres. Dropped from 3.",{}),
 ("GoldTooth","Fisherman's Gold Tooth","R","Tooth",(255,205,60),(230,180,40),"He smiled a lot. Then he didn't.",dict(mat="Metal",scale=0.7,minLevel=14)),
 ("ShipsBell","Ship's Bell","E","Bell",(190,140,60),(60,40,30),"Engraved with the ship's name: 'Persistence'.",{}),
 ("Sextant","Navigator's Sextant","E","Compass",(200,170,90),(40,60,90),"Finds your place by the stars.",dict(mul=1.1)),
 ("GhostKey","Ghost Captain's Key","L","Key",(120,255,220),(40,120,110),"Cold as the deep and faintly glowing.",dict(mat="Glass",glow=True,scale=1.3)),
 ("LighthouseLens","Lighthouse Lens","M","Gem",(220,250,255),(255,240,150),"It still gathers light that isn't there.",dict(mat="Glass",glow=True,scale=1.3)),
 ("DrownedCrown","The Drowned Crown","S","Crown",(60,200,190),(255,255,255),"Worn by a king who ruled beneath the waves.",dict(glow=True)),
],
"ShipwreckCoast": [
 ("ShipRivet","Ship Rivet","C","Coin",(90,85,80),(60,55,50),"Held the hull together. Mostly.",dict(mat="CorrodedMetal",scale=0.6)),
 ("CannonballShard","Cannonball Shard","C","Orb",(40,40,45),(90,90,95),"Fired in anger, found in peace.",dict(mat="Metal",scale=0.8)),
 ("CutlassHilt","Broken Cutlass Hilt","C","Sword",(150,140,120),(100,70,40),"The blade went one way, the pirate another.",dict(mul=0.9,scale=0.7)),
 ("SpanishReal","Spanish Silver Real","U","Coin",(220,220,230),(170,170,180),"Pieces of eight! Well, one piece.",dict(mat="Metal")),
 ("GrogBottle","Grog Bottle","U","Bottle",(110,70,30),(230,220,200),"Smells faintly of bad decisions.",dict(mat="Glass")),
 ("BrassSpyglass","Brass Spyglass","U","Can",(200,160,70),(60,40,30),"Land ho! (It's foggy.)",dict(mul=1.1,mat="Metal")),
 ("GoldIngot","Gold Ingot","R","Bar",(255,200,50),(220,170,30),"Stamped with a royal seal.",dict(mat="Metal")),
 ("AdmiralsMedal","Admiral's Medal","R","Coin",(255,205,70),(180,30,40),"For valour at sea. Lost at sea.",dict(mul=1.1,mat="Metal",minLevel=20)),
 ("JeweledGoblet","Jeweled Goblet","E","Goblet",(255,200,60),(200,30,60),"Pirates drank from it. Kings before them.",dict(mat="Metal")),
 ("PirateCompass","Pirate Captain's Compass","E","Compass",(255,205,70),(30,30,30),"Points to whatever you want most.",dict(mul=1.1)),
 ("RoyalChest","Royal Treasure Chest","L","Chest",(140,90,40),(255,210,60),"Overflowing with the king's own gold.",dict(glow=True,scale=1.1)),
 ("KrakensTrident","Kraken's Trident","M","Trident",(60,140,140),(200,255,240),"Taken from a sea monster. It wants it back.",dict(glow=True)),
 ("GhostAnchor","Ghost Ship Anchor","S","Anchor",(150,255,230),(255,255,255),"From a ship that sails only on foggy nights.",dict(mat="Glass",glow=True,scale=1.2)),
],
"AncientRuins": [
 ("PotteryShard","Pottery Shard","C","Tooth",(190,110,70),(90,50,30),"Painted with waves and tiny fish.",dict(scale=1.2)),
 ("ClayBead","Clay Bead","C","Orb",(200,130,80),(240,200,150),"Strung on a necklace three thousand years ago.",dict(scale=0.6)),
 ("TabletPiece","Stone Tablet Piece","C","Bar",(160,160,150),(110,110,100),"Carved in a language no one speaks.",dict(mat="Slate")),
 ("BronzeCoin","Bronze Temple Coin","U","Coin",(200,130,60),(120,80,40),"Offered to the sea for good fortune.",dict(mat="Metal")),
 ("ObsidianArrowhead","Obsidian Arrowhead","U","Tooth",(30,30,40),(90,80,110),"Razor sharp after all these years.",dict(mat="Glass")),
 ("ScarabAmulet","Scarab Amulet","U","Gem",(40,110,220),(255,200,60),"A beetle of lapis and gold.",dict(mul=1.1)),
 ("GoldenIdol","Golden Idol","R","Statue",(255,205,60),(40,200,140),"Don't swap it for a bag of sand.",dict(mat="Metal")),
 ("AncientSeaChart","Ancient Sea Chart","R","Scroll",(230,210,160),(160,40,40),"Marks an island no living sailor has seen. Finding it reveals the way to Secret Treasure Island.",{}),
 ("SunDisk","Sun Disk","E","Coin",(255,200,40),(255,120,30),"Once caught the first light of every solstice.",dict(glow=True,scale=1.4)),
 ("CeremonialGoblet","Ceremonial Goblet","E","Goblet",(230,230,240),(60,140,255),"Silver and lapis, for the Tide Kings' feasts.",dict(mul=1.1,mat="Metal")),
 ("TideKingsCrown","Crown of the Tide Kings","L","Crown",(255,205,60),(40,170,255),"Seven kings wore it. Seven kings vanished.",dict(glow=True)),
 ("SeaPharaohMask","Sea Pharaoh's Mask","M","Mask",(255,200,50),(30,80,200),"Gold, lapis and a gaze that follows you.",dict(glow=True)),
 ("AtlanteanCore","Atlantean Core","S","Orb",(60,255,255),(255,255,255),"Power source of a lost civilisation.",dict(mat="Neon",glow=True)),
],
"SecretIsland": [
 ("GildedShell","Gilded Shell","C","Shell",(255,210,80),(255,240,200),"Even the shells here are made of gold.",dict(mat="Metal")),
 ("RubyChip","Ruby Chip","C","Gem",(220,30,50),(255,150,160),"A fragment of something much bigger.",dict(mat="Glass",scale=0.6)),
 ("AncientDoubloon","Ancient Doubloon","C","Coin",(255,200,40),(200,150,20),"Gold so old it predates kings.",dict(mat="Metal")),
 ("SapphireRing","Sapphire Ring","U","Ring",(220,220,235),(40,80,230),"A deep-blue stone on a platinum band.",{}),
 ("PirateEarring","Pirate King's Earring","U","Ring",(255,205,60),(220,30,50),"Arr. It's heavier than it looks.",dict(scale=0.7)),
 ("SilverStack","Stack of Silver Coins","U","CoinStack",(220,220,230),(180,180,190),"Someone was saving up.",dict(mul=1.1,mat="Metal")),
 ("DiamondPendant","Diamond Pendant","R","Gem",(240,250,255),(200,220,255),"Flawless, cold and impossibly bright.",dict(mat="Glass")),
 ("CursedSkull","Cursed Skull","R","Skull",(230,225,200),(60,255,120),"Its eyes glow green when the moon is full.",dict(mul=1.1)),
 ("LegendsMap","Map of Legends","E","Scroll",(240,220,170),(40,40,40),"Every X on it has already been dug... except one.",{}),
 ("GoldenSkull","Golden Skull","E","Skull",(255,205,60),(255,80,60),"A pirate king's last joke.",dict(mul=1.1,mat="Metal")),
 ("DavyJonesLocker","Davy Jones' Locker","L","Chest",(30,70,80),(90,255,220),"Every sailor's fear. Now yours to keep.",dict(glow=True,scale=1.1)),
 ("PoseidonsTrident","Poseidon's Trident","M","Trident",(255,205,60),(90,220,255),"Strike the sand and the sea parts.",dict(glow=True)),
 ("EyeOfTheOcean","Eye of the Ocean","S","Gem",(40,120,255),(180,240,255),"The single greatest treasure of the sea.",dict(mat="Neon",glow=True,scale=1.4)),
],
}
EVENT = [
 ("Moonstone","Moonstone","R","Gem",(200,220,255),(255,255,255),"Glows softly only under a moonlit sky.",dict(glow=True)),
 ("LunarPearl","Lunar Pearl","E","Orb",(230,230,255),(150,170,255),"A pearl that formed in moonlight.",dict(glow=True)),
 ("StarfallShard","Starfall Shard","L","Gem",(180,140,255),(255,255,255),"Fell from the sky on a moonlit night.",dict(mat="Neon",glow=True,scale=1.2)),
 ("CrescentCrown","Crescent Crown","M","Crown",(220,225,240),(150,180,255),"Crowned by the moon itself.",dict(glow=True)),
]

def c3(rgb): return "Color3.fromRGB(%d, %d, %d)" % rgb
def lstr(s): return '"' + s.replace('\\','\\\\').replace('"','\\"') + '"'

out = []
out.append('''--[[
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

Treasures.List = {''')
def emit(zone, e, event=None):
    tid, name, r, shape, col, acc, lore, o = e
    rname, base = RB[r]
    if event:
        value = nice(base * 1.3)
    else:
        value = nice(base * ZM[zone] * o.get("mul", 1.0))
    fields = [f'Id = "{tid}"', f'Name = {lstr(name)}', f'Rarity = "{rname}"', f'Zone = "{zone}"', f'Value = {value}', f'Shape = "{shape}"', f'Color = {c3(col)}', f'Accent = {c3(acc)}']
    if o.get("mat"): fields.append(f'Material = "{o["mat"]}"')
    if o.get("glow"): fields.append('Glow = true')
    if o.get("scale"): fields.append(f'Scale = {o["scale"]}')
    if o.get("minLevel"): fields.append(f'MinLevel = {o["minLevel"]}')
    if event: fields += [f'Event = "{event}"', 'ScalesWithZone = true']
    fields.append(f'Lore = {lstr(lore)}')
    out.append("\t{ " + ", ".join(fields) + " },")

count = 0
for zone, items in T.items():
    out.append(f"\n\t-- {zone} " + "-" * 40)
    for e in items: emit(zone, e); count += 1
out.append("\n\t-- Event: Moonlit Night (can appear in any zone while the event runs) ---------")
for e in EVENT: emit("Event", e, event="MoonlitNight"); count += 1
out.append('''}

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
''')
open("src/shared/Config/Treasures.lua","w").write("\n".join(out))
print("treasures:", count)
