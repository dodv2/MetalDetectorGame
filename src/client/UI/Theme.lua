--[[
	Theme
	Colours and fonts for the whole UI. Change these to restyle every screen.
	Palette follows the LihFolk "Ink and Candy" UI design system
	(vault: 21 LihFolk UI Design System). Key names are unchanged so every controller keeps working.
]]

local Theme = {}

local hex = Color3.fromHex

Theme.Colors = {
	-- canvas (dusk) and outlines (ink)
	Panel = hex("#2D2852"), -- dusk
	PanelLight = hex("#3B3566"), -- duskRaised
	PanelLightHi = hex("#4A437A"), -- duskRaisedHi (card gradient top)
	PanelDark = hex("#1F1B3D"), -- duskSunken: tracks, fields
	Stroke = hex("#160F2B"), -- ink: every outline and text stroke
	Ink = hex("#160F2B"),
	Text = hex("#FFFFFF"), -- textHi 13.7:1 on dusk
	SubText = hex("#D6D0F5"), -- textMid 9.2:1
	Muted = hex("#B0A9DD"), -- textLow 6.2:1

	-- role colours (button face bottoms)
	Sand = hex("#FFE27A"),
	Gold = hex("#FFD24A"), -- featured outlines
	Teal = hex("#18B5C6"), -- Lagoon
	Ocean = hex("#3D93F0"), -- info
	Coral = hex("#EE3D66"), -- danger / close
	Green = hex("#25C773"), -- go: the one primary action
	Orange = hex("#FF7B22"), -- Tangerine (shop)
	Purple = hex("#9257F2"), -- Orchid
	Neutral = hex("#6E66B3"), -- neutral / tabs
	Disabled = hex("#3A3466"), -- locked: darkest slab
	Luck = hex("#7BF5A6"),
	XP = hex("#7CC8FF"),
}

-- Slab lips (darker band under each button face), keyed by face colour hex
Theme.Lips = {
	[hex("#25C773"):ToHex()] = hex("#12804A"),
	[hex("#6E66B3"):ToHex()] = hex("#40397A"),
	[hex("#FFD24A"):ToHex()] = hex("#B06B00"),
	[hex("#FFE27A"):ToHex()] = hex("#B06B00"),
	[hex("#EE3D66"):ToHex()] = hex("#9A1838"),
	[hex("#3D93F0"):ToHex()] = hex("#1D58A8"),
	[hex("#3A3466"):ToHex()] = hex("#221D42"),
}

Theme.Fonts = {
	Title = Enum.Font.FredokaOne, -- display, titles, buttons, numbers
	Body = Enum.Font.BuilderSansBold,
	Bold = Enum.Font.BuilderSansExtraBold,
	Number = Enum.Font.FredokaOne,
}

-- Toast colours per notification kind (role colours)
Theme.NotifyColors = {
	Info = hex("#1D58A8"),
	Success = hex("#12804A"),
	Warning = hex("#B06B00"),
	Error = hex("#9A1838"),
	Event = hex("#5B33B0"),
	Rare = hex("#B06B00"),
}

Theme.DesignSize = Vector2.new(1280, 720)

return Theme
