--[[
	Rarities
	Tier order matters: higher Tier = rarer.

	LuckPower    how strongly Luck boosts this rarity's chance (Common = 0, never boosted)
	DisplayLuck  Luck bonus this rarity gives when displayed in your shop (0.01 = +1%)
	XP           XP for digging one up (multiplied by the zone's XPMult)
	BaseValue    reference sell value at the Starting Beach (used when designing treasures)
	Glyph        symbol shown next to the rarity name, so rarity is never colour-only
]]

local Rarities = {}

Rarities.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret" }

Rarities.Info = {
	Common = {
		Tier = 1,
		Color = Color3.fromRGB(190, 196, 204),
		Glyph = "●",
		LuckPower = 0,
		DisplayLuck = 0.005,
		XP = 12,
		BaseValue = 8,
	},
	Uncommon = {
		Tier = 2,
		Color = Color3.fromRGB(96, 214, 112),
		Glyph = "◆",
		LuckPower = 0.45,
		DisplayLuck = 0.012,
		XP = 20,
		BaseValue = 25,
	},
	Rare = {
		Tier = 3,
		Color = Color3.fromRGB(72, 156, 255),
		Glyph = "★",
		LuckPower = 0.75,
		DisplayLuck = 0.03,
		XP = 40,
		BaseValue = 80,
	},
	Epic = {
		Tier = 4,
		Color = Color3.fromRGB(178, 98, 255),
		Glyph = "✦",
		LuckPower = 1.0,
		DisplayLuck = 0.07,
		XP = 80,
		BaseValue = 300,
	},
	Legendary = {
		Tier = 5,
		Color = Color3.fromRGB(255, 186, 46),
		Glyph = "♛",
		LuckPower = 1.2,
		DisplayLuck = 0.16,
		XP = 175,
		BaseValue = 1200,
	},
	Mythical = {
		Tier = 6,
		Color = Color3.fromRGB(255, 78, 128),
		Glyph = "❖",
		LuckPower = 1.35,
		DisplayLuck = 0.35,
		XP = 450,
		BaseValue = 6000,
	},
	Secret = {
		Tier = 7,
		Color = Color3.fromRGB(255, 255, 255),
		Glyph = "✪",
		Rainbow = true, -- UI animates a rainbow gradient for Secrets
		LuckPower = 1.5,
		DisplayLuck = 0.75,
		XP = 1200,
		BaseValue = 40000,
	},
}

function Rarities.Get(name: string)
	return Rarities.Info[name]
end

function Rarities.Tier(name: string): number
	local info = Rarities.Info[name]
	return if info then info.Tier else 1
end

function Rarities.FromTier(tier: number): string
	return Rarities.Order[math.clamp(tier, 1, #Rarities.Order)]
end

-- "★ Rare" style label used everywhere in the UI
function Rarities.Label(name: string): string
	local info = Rarities.Info[name]
	return if info then info.Glyph .. " " .. name else name
end

return Rarities
