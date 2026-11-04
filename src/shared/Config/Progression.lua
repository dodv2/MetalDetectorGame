--[[
	Progression
	XP curve and level-up rewards.
]]

local Progression = {}

Progression.MaxLevel = 100
Progression.LuckPerLevel = 0.01 -- every level above 1 gives +1 Luck
Progression.NewDiscoveryXP = 50 -- bonus XP the first time you find a treasure type
Progression.StrikeXP = 1 -- XP per shovel strike

-- XP needed to go from `level` to `level + 1`
function Progression.XPForLevel(level: number): number
	return math.floor(45 * level ^ 1.5 + 30)
end

-- Cash given when reaching `level`
function Progression.LevelUpCash(level: number): number
	return math.floor(40 * level ^ 1.35)
end

-- Every 5 levels: a free Lucky Charm. Every 10: a Four-Leaf Clover instead.
function Progression.LevelUpBoost(level: number): (string?, number?)
	if level % 10 == 0 then
		return "FourLeafClover", 300
	elseif level % 5 == 0 then
		return "LuckyCharm", 300
	end
	return nil, nil
end

return Progression
