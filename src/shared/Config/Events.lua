--[[
	Events
	Server-wide limited-time events. One starts every Interval seconds and lasts Duration seconds.

	LuckBonus      Luck everyone gets during the event (additive: 1 = +100 Luck)
	SpawnMult      multiplies how many treasures are buried per zone
	DigSpeedMult   multiplies shovel progress per strike
	TreasureChance chance that a spawn becomes an event-only treasure (see Treasures with Event = <Id>)
	Night          clients switch to night lighting while it runs
]]

local Events = {}

Events.FirstDelay = 180 -- seconds after a server starts before the first event
Events.Interval = 720 -- seconds between event starts
Events.Duration = 240 -- seconds each event lasts

Events.List = {
	{ Id = "GoldenTide", Name = "Golden Tide", Icon = "🌅", Description = "Everyone gets +100 Luck!",
		LuckBonus = 1, SpawnMult = 1, DigSpeedMult = 1, Color = Color3.fromRGB(255, 196, 60) },
	{ Id = "TreasureRush", Name = "Treasure Rush", Icon = "⛏", Description = "Twice as many buried treasures and 50% faster digging!",
		LuckBonus = 0, SpawnMult = 2, DigSpeedMult = 1.5, Color = Color3.fromRGB(255, 120, 60) },
	{ Id = "MoonlitNight", Name = "Moonlit Night", Icon = "🌙", Description = "Limited Moon treasures can be dug up in every zone!",
		LuckBonus = 0.25, SpawnMult = 1, DigSpeedMult = 1, TreasureChance = 0.2, Night = true, Color = Color3.fromRGB(150, 170, 255) },
}

Events.ById = {}
for _, def in Events.List do
	Events.ById[def.Id] = def
end

return Events
