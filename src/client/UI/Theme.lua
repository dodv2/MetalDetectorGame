--[[
	Theme
	Colours and fonts for the whole UI. Change these to restyle every screen.
]]

local Theme = {}

Theme.Colors = {
	Panel = Color3.fromRGB(20, 36, 56),
	PanelLight = Color3.fromRGB(32, 54, 80),
	PanelDark = Color3.fromRGB(12, 24, 40),
	Stroke = Color3.fromRGB(120, 200, 230),
	Text = Color3.fromRGB(255, 255, 255),
	SubText = Color3.fromRGB(176, 200, 218),
	Muted = Color3.fromRGB(110, 132, 150),

	Sand = Color3.fromRGB(255, 214, 140),
	Gold = Color3.fromRGB(255, 196, 60),
	Teal = Color3.fromRGB(34, 178, 196),
	Ocean = Color3.fromRGB(30, 120, 200),
	Coral = Color3.fromRGB(236, 96, 88),
	Green = Color3.fromRGB(72, 196, 108),
	Orange = Color3.fromRGB(255, 150, 60),
	Purple = Color3.fromRGB(150, 110, 255),
	Neutral = Color3.fromRGB(62, 86, 112),
	Disabled = Color3.fromRGB(70, 78, 90),
	Luck = Color3.fromRGB(110, 230, 120),
	XP = Color3.fromRGB(120, 180, 255),
}

Theme.Fonts = {
	Title = Enum.Font.FredokaOne,
	Body = Enum.Font.GothamMedium,
	Bold = Enum.Font.GothamBold,
	Number = Enum.Font.FredokaOne,
}

-- Toast colours per notification kind
Theme.NotifyColors = {
	Info = Color3.fromRGB(40, 70, 100),
	Success = Color3.fromRGB(38, 130, 72),
	Warning = Color3.fromRGB(190, 110, 30),
	Error = Color3.fromRGB(170, 52, 52),
	Event = Color3.fromRGB(96, 70, 190),
	Rare = Color3.fromRGB(180, 130, 20),
}

Theme.DesignSize = Vector2.new(1280, 720)

return Theme
