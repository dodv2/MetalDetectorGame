--[[
	Quests
	Daily quests: every player gets 3 random quests per day (UTC). They reset at midnight UTC.

	Type        what progresses it (sent by the server when things happen):
	            Find, FindTier, Dig, SellValue, Display, FindInZone, EarnXP, Discover
	Target      function(level, valueMult) -> number needed
	Weight      how often it's picked
]]

local Progression = require(script.Parent.Progression)

local Quests = {}

Quests.DailyCount = 3

Quests.Templates = {
	{ Id = "FindAny", Type = "Find", Weight = 3, Text = "Dig up %s treasures",
		Target = function(level) return 10 + math.floor(level * 0.5) end },
	{ Id = "FindRare", Type = "FindTier", MinTier = 3, Weight = 2, Text = "Find %s Rare-or-better treasures",
		Target = function(level) return 2 + level // 12 end },
	{ Id = "FindEpic", Type = "FindTier", MinTier = 4, Weight = 1, MinLevel = 8, Text = "Find %s Epic-or-better treasures",
		Target = function(level) return 1 + level // 30 end },
	{ Id = "Strikes", Type = "Dig", Weight = 2, Text = "Swing your shovel %s times",
		Target = function(level) return 40 + level * 2 end },
	{ Id = "SellCash", Type = "SellValue", IsCash = true, Weight = 2, Text = "Sell treasures worth %s",
		Target = function(level, mult) return math.floor((200 + level * 30) * mult) end },
	{ Id = "Display", Type = "Display", Weight = 1, Text = "Put %s treasures on display in your shop",
		Target = function() return 3 end },
	{ Id = "ZoneFinds", Type = "FindInZone", NeedsZone = true, Weight = 2, Text = "Find %s treasures in %s",
		Target = function(level) return 8 + level // 6 end },
	{ Id = "EarnXP", Type = "EarnXP", Weight = 1, Text = "Earn %s XP",
		Target = function(level) return math.floor(Progression.XPForLevel(level) * 0.5) end },
	{ Id = "Discover", Type = "Discover", MinLevel = 3, Weight = 1, Text = "Discover %s new treasure type",
		Target = function() return 1 end },
}

Quests.ById = {}
for _, template in Quests.Templates do
	Quests.ById[template.Id] = template
end

-- Reward for completing one daily quest
function Quests.Reward(level: number, valueMult: number)
	return {
		Cash = math.floor((120 + level * 35) * valueMult),
		XP = math.floor(Progression.XPForLevel(level) * 0.3),
	}
end

return Quests
