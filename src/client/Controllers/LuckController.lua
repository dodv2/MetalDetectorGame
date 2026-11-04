--[[
	LuckController
	🧰 Equipment & Luck window (navigation menu, G): the gear you're using and what it does,
	your total Luck multiplier and where every bit of it comes from, how it changes the
	rarity odds in each zone, and which trinkets you own. Upgrades are bought at the
	physical 🛒 Equipment Shop at the base.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Zones = require(Shared.Config.Zones)
local Rarities = require(Shared.Config.Rarities)
local Equipment = require(Shared.Config.Equipment)
local Events = require(Shared.Config.Events)
local GameMath = require(Shared.GameMath)
local GameConfig = require(Shared.Config.GameConfig)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Luck = {}

local controllers
local window
local ui = {} :: any
local zoneIndex = 1

local function clear(frame: Instance)
	for _, child in frame:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

local function line(parent: Instance, order: number, left: string, right: string, color: Color3?, height: number?)
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, height or 22), LayoutOrder = order, Parent = parent })
	UIKit.Text({ Text = left, TextSize = 15, Size = UDim2.new(0.68, 0, 1, 0), Parent = row })
	UIKit.Text({ Text = right, Font = Theme.Fonts.Bold, TextSize = 15, TextColor3 = color or Theme.Colors.Luck, Position = UDim2.fromScale(0.68, 0), Size = UDim2.new(0.32, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
end

function Luck:Render()
	local data = controllers.State.Data
	if not data or not window.IsOpen then
		return
	end
	local luck = data.Luck
	ui.Total.Text = "🍀 " .. Format.Luck(luck.Points or 0)

	clear(ui.Breakdown)
	-- gear ------------------------------------------------------------------
	UIKit.Text({ Text = "🧰 Your equipment", Font = Theme.Fonts.Title, TextSize = 17, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = -20, Parent = ui.Breakdown })
	local detector = Equipment.ById.Detector[data.Equipment.Detector]
	local shovel = Equipment.ById.Shovel[data.Equipment.Shovel]
	local stats = GameMath.DetectorStats(data)
	local small = "<font size=\"12\" color=\"#9fb4c8\">%s</font>"
	line(ui.Breakdown, -19, "📡 " .. (if detector then detector.Name else "?") .. "\n" .. string.format(small, string.format("Range %s · accuracy %d%% · depth %s", Format.Meters(stats.Range), math.floor(stats.Accuracy * 100), GameConfig.DepthNames[stats.Depth] or tostring(stats.Depth))), "", Theme.Colors.Text, 38)
	line(ui.Breakdown, -18, "⭕ Built-in " .. (if detector and detector.Coil then detector.Coil else "coil") .. "\n" .. string.format(small, "comes with your detector - a new detector upgrades it"), "", Theme.Colors.Text, 38)
	if shovel then
		line(ui.Breakdown, -17, "⛏ " .. shovel.Name .. "\n" .. string.format(small, "every shovel digs everything - better ones dig faster"), "", Theme.Colors.Text, 38)
	end
	line(ui.Breakdown, -16, "🎒 Backpack\n" .. string.format(small, string.format("%d / %d treasures (fixed size - sell or display on the Pier)", #data.Inventory, data.Capacity)), "", Theme.Colors.Text, 38)
	UIKit.Text({ Text = "🛒 Upgrade at the Equipment Shop on the Pier (⚓ Return to Pier).", TextSize = 12, TextColor3 = Theme.Colors.Gold, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = -15, Parent = ui.Breakdown })
	UIKit.Text({ Text = "🍀 Luck", Font = Theme.Fonts.Title, TextSize = 17, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = -1, Parent = ui.Breakdown })

	local order = 0
	line(ui.Breakdown, 0, "<b>Luck sources</b>", "", Theme.Colors.Text)
	for _, part in luck.Parts do
		order += 1
		if part.Value > 0 then
			line(ui.Breakdown, order, part.Name, Format.LuckNumber(part.Value))
		end
	end
	order += 1
	line(ui.Breakdown, order, "<b>Permanent Luck</b>", Format.LuckNumber(luck.Permanent or 0), Theme.Colors.Text)
	local now = controllers.State:Now()
	order += 1
	if (luck.BoostBonus or 0) > 0 and luck.BoostEnds > now then
		local boost = Equipment.ById.Boost[luck.BoostId]
		line(ui.Breakdown, order, "⏱ " .. (if boost then boost.Name else "Boost") .. " (" .. Format.Time(luck.BoostEnds - now) .. ")", Format.LuckNumber(luck.BoostBonus), Theme.Colors.Gold)
	else
		line(ui.Breakdown, order, "⏱ No boost active (🛒 Equipment Shop > Boosts)", "+0", Theme.Colors.Muted)
	end
	order += 1
	local event = Events.ById[ReplicatedStorage:GetAttribute("EventId") or ""]
	if (luck.EventBonus or 0) > 0 and event then
		line(ui.Breakdown, order, event.Icon .. " " .. event.Name .. " event", Format.LuckNumber(luck.EventBonus), Theme.Colors.Gold)
	else
		line(ui.Breakdown, order, "🎉 No Luck event right now", "+0", Theme.Colors.Muted)
	end
	order += 1
	UIKit.Text({ Text = "Luck adds up: every source above is added together.\n+100 Luck doubles your base luck for rare finds (Commons never disappear).", TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 34), LayoutOrder = order, Parent = ui.Breakdown })

	-- Trinkets
	order += 1
	UIKit.Text({ Text = "🧿 Trinkets (earned from achievements)", Font = Theme.Fonts.Title, TextSize = 17, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = order, Parent = ui.Breakdown })
	for _, trinket in Equipment.Trinkets do
		order += 1
		local owned = data.Trinkets[trinket.Id] == true
		line(ui.Breakdown, order, (if owned then "✅ " else "🔒 ") .. trinket.Name .. "\n<font size=\"12\" color=\"#9fb4c8\">" .. trinket.Description .. "</font>", Format.LuckNumber(trinket.Luck), if owned then Theme.Colors.Luck else Theme.Colors.Muted, 38)
	end

	-- Odds table
	local zoneId = Zones.Order[zoneIndex]
	local zone = Zones.Info[zoneId]
	ui.ZoneButton.Text = "📍 " .. zone.Name .. " ▸"
	clear(ui.Odds)
	local header = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 0, Parent = ui.Odds })
	for column, title in { "Rarity", "No luck", "Your luck", "Deep dig" } do
		UIKit.Text({ Text = "<b>" .. title .. "</b>", TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromScale((column - 1) * 0.25, 0), Size = UDim2.fromScale(0.25, 1), TextXAlignment = if column == 1 then Enum.TextXAlignment.Left else Enum.TextXAlignment.Right, Parent = header })
	end
	local base = GameMath.GetChances(zoneId, 1, 1)
	local mine = GameMath.GetChances(zoneId, luck.Total, 1)
	local deep = GameMath.GetChances(zoneId, luck.Total, 3)
	local function pct(p: number): string
		if p >= 0.1 then
			return string.format("%.1f%%", p * 100)
		elseif p >= 0.001 then
			return string.format("%.2f%%", p * 100)
		end
		return string.format("%.3f%%", p * 100)
	end
	for index, rarity in Rarities.Order do
		local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = index, Parent = ui.Odds })
		UIKit.RarityLabel(rarity, { TextSize = 14, Size = UDim2.fromScale(0.25, 1), Parent = row })
		for column, value in { base[rarity], mine[rarity], deep[rarity] } do
			UIKit.Text({ Text = pct(value), Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = if column == 1 then Theme.Colors.SubText else Theme.Colors.Text, Position = UDim2.fromScale(column * 0.25, 0), Size = UDim2.fromScale(0.25, 1), TextXAlignment = Enum.TextXAlignment.Right, Parent = row })
		end
	end
	UIKit.Text({ Text = "Deep treasures (depth 3) roll with extra Luck — you need a detector that reaches them.", TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 30), LayoutOrder = 20, Parent = ui.Odds })
end

function Luck:Init(all)
	controllers = all
	window = UIKit.Window("Luck", "🧰 Equipment & Luck", Vector2.new(860, 540))
	ui.Total = UIKit.Text({ Text = "", Font = Theme.Fonts.Title, TextSize = 34, TextColor3 = Theme.Colors.Luck, Size = UDim2.new(0.5, 0, 0, 40), Parent = window.Content })
	UIKit.TextStroke(0.4).Parent = ui.Total
	ui.Breakdown = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(0.5, -12, 1, -46), Parent = window.Content })
	UIKit.List(nil, 4).Parent = ui.Breakdown
	UIKit.Padding(4, 8).Parent = ui.Breakdown

	local right = UIKit.new("Frame", { BackgroundColor3 = Theme.Colors.PanelDark, Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0), Parent = window.Content }, { UIKit.Corner(14), UIKit.Padding(10) })
	UIKit.Text({ Text = "🎲 Rarity odds per treasure", Font = Theme.Fonts.Title, TextSize = 19, Size = UDim2.new(1, 0, 0, 26), Parent = right })
	ui.ZoneButton = UIKit.Button("Zone", Theme.Colors.Neutral, function()
		zoneIndex = zoneIndex % #Zones.Order + 1
		self:Render()
	end, { Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 34), TextSize = 15, Parent = right })
	ui.Odds = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, 0, 1, -72), Parent = right }, { UIKit.List(nil, 4) })

	window.Opened:Connect(function()
		local data = controllers.State.Data
		if data and data.CurrentZone then
			zoneIndex = table.find(Zones.Order, data.CurrentZone) or zoneIndex
		end
		self:Render()
	end)
end

function Luck:Start()
	controllers.State.Changed:Connect(function()
		self:Render()
	end)
end

return Luck
