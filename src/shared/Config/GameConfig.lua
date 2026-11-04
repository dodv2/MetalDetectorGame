--[[
	GameConfig
	General tuning numbers. Change these to rebalance the whole game.
]]

return {
	-- 1 Roblox stud = 0.28 metres (Roblox's official conversion)
	StudsToMeters = 0.28,

	-- Digging / detection
	DigRadius = 6, -- studs (flat distance) you must be within to dig a treasure
	SpawnsPerZone = 10, -- buried treasures each player has per zone at once
	RespawnDelay = 3, -- seconds before a dug-up treasure is replaced
	MinSpawnSpacing = 12, -- studs between buried treasures
	ScanInterval = 0.2, -- seconds between detector scans (server)
	DepthWeights = { 60, 30, 10 }, -- chance weights for depth 1 / 2 / 3 treasures
	DepthLuck = { 1, 1.3, 1.7 }, -- deeper treasures roll with extra luck
	DepthNames = { "Shallow", "Medium", "Deep" },

	-- Excavation: a tug of war between you and the sand (see GameMath.DigProfile).
	-- Every number here is HIDDEN from players - the bar never shows them.
	Dig = {
		-- How much digging a treasure needs: resistance = beach x rarity x depth
		ClickGain = 0.125, -- progress per click: Common, shallow, Starting Beach treasure with the right shovel = 8 clicks
		ZoneResistance = { 1, 1.5, 2.2, 3.1, 4.4, 6.2, 9 }, -- by beach order: higher beaches pack the sand harder
		RarityResistance = { 1, 1.35, 1.8, 2.4, 3.2, 4.2, 5.5 }, -- Common ... Secret
		DepthResistance = { 1, 1.2, 1.45 }, -- shallow / medium / deep
		MaxClicks = 140, -- never more counted clicks than this before the pull, whatever the shovel

		-- Recommended shovel tier (1 = Starter ... 7 = Mythical) for each treasure
		ZoneShovelTier = { 1, 2, 3, 4, 5, 6, 7 }, -- the shovel each beach is balanced for
		RarityTierBonus = { 0, 0, 1, 1, 2, 2, 2 }, -- rarer treasure asks for a better shovel
		DepthTierBonus = { 0, 0, 1 }, -- and so does deep treasure
		MaxRecommendedTier = 8,
		UnderTierPenalty = 0.25, -- each tier under: progress per click / (1 + 0.25 x tiers under)
		OverTierBonus = 0.1, -- each tier over: progress per click x (1 + 0.1 x tiers over) ...
		OverTierMax = 1.5, -- ... up to x1.5

		-- The pull-back (Update 17): NO grace period. The sand pulls progress back all the time,
		-- even between fast clicks; clicks have to outpace it. Measured in clicks' worth per second:
		DecayClicks = 1.1, -- with the recommended shovel the sand takes back ~1 click every second ...
		DecayPerTierUnder = 0.5, -- ... +50% per tier under the recommendation ...
		DecayPerTierOver = 0.2, -- ... -20% per tier over (never below 40%) ...
		DecayMinMult = 0.4,
		DecayShovelWeight = 0.3, -- ... scaled by the shovel's own DecayMult (0.7 + 0.3 x DecayMult) ...
		DecayMaxShare = 0.5, -- ... and never more than half the shovel's top click speed,
		DecayMaxClicks = 3, -- (and never above 3 a second) so every dig can still be won by clicking fast
		IdleBoost = 1, -- stop clicking and the pull grows up to 2x ...
		IdleRamp = 1.2, -- ... over 1.2 seconds
		-- Permanent failure: once the hole is properly started (the "foothold"), letting the bar
		-- fall back to empty loses the treasure for good. Foothold = 1.5 clicks' worth, 10-30% of the bar.
		FootholdClicks = 1.5,
		FootholdMin = 0.1,
		FootholdMax = 0.3,

		MaxDistance = 10, -- studs: walking further than this from the hole cancels digging
		IdleCancel = 12, -- seconds without a click before the dig is abandoned (the pull keeps going)
		XPEveryClicks = 3, -- +1 XP for every 3 counted clicks
		SpawnLifetime = 300, -- untouched buried treasures move after 5 minutes
	},

	-- Economy
	StartingCash = 50,
	BackpackCapacity = 10, -- fixed: the backpack can't be upgraded. Sell or display at base to make room.
	SifterBonusShare = 0.25, -- bonus cash share when a shovel's bonus chance triggers
	MaxBoostSeconds = 7200, -- boosts can be stacked up to 2 hours

	-- Luck
	MinCommonChance = 0.08, -- Common treasures never drop below 8%
	ZoneDisplayLuckBonus = 0.12, -- each later zone adds +12% to the luck its treasures give on display

	-- Data
	DataStoreName = "BeachDetectingData_v1",
	AutosaveInterval = 120,
	LeaderboardPrefix = "BeachLB_v1_",
	LeaderboardUpdateInterval = 120,
	LeaderboardRefreshInterval = 90,

	-- Social
	AnnounceMinTier = 5, -- Legendary and above are announced to the whole server
}
