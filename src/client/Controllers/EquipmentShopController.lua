--[[
	EquipmentShopController
	🛒 Equipment Shop window (opened by talking to Marina at the base): detectors (each with its own
	built-in coil - a new detector upgrades the coil too), shovels, Luck boosts and detector skins.
	Shows stats, level requirements and price for everything.
	(Shop upgrades + themes live in your own shop's management screen; the backpack is a fixed 10.)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Equipment = require(Shared.Config.Equipment)
local GameConfig = require(Shared.Config.GameConfig)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local EquipmentShop = {}

local controllers
local window
local list: ScrollingFrame
local tabs
local TABS = { "Detectors", "Shovels", "Boosts", "Skins" }

local function meters(studs: number): string
	return Format.Meters(studs)
end

local function detectorStats(def): string
	return string.format("⭕ Built-in %s   📡 Range %s   🎯 Accuracy %d%%   ⛏ Depth %s   🍀 %s%s",
		def.Coil or "coil", meters(def.Range), math.floor(def.Accuracy * 100), GameConfig.DepthNames[def.Depth], Format.Luck(def.Luck),
		if def.RarityHint then "   🔮 Rarity hint" else "")
end

-- ●●●○○○○ rating against the best item in the list (no raw numbers for digging strength)
local function pips(value: number, best: number): string
	local filled = math.clamp(math.floor(value / best * 7 + 0.5), 1, 7)
	return string.rep("■", filled) .. string.rep("□", 7 - filled)
end

-- Shovels dig EVERY treasure; better ones are simply stronger and faster (resistance stays hidden)
local function shovelStats(def): string
	local best = Equipment.Shovels[#Equipment.Shovels]
	local extras = {}
	if def.BonusChance > 0 then
		table.insert(extras, "💰 " .. math.floor(def.BonusChance * 100 + 0.5) .. "% bonus coins")
	end
	if def.Luck > 0 then
		table.insert(extras, "🍀 " .. Format.Luck(def.Luck))
	end
	return string.format("⛏ Strength %s   ⚡ Speed %s   🧤 Grip %s%s",
		pips(def.Power, best.Power), pips(def.Speed, best.Speed), pips(1 - def.DecayMult + 0.1, 1 - best.DecayMult + 0.1),
		if #extras > 0 then "\n" .. table.concat(extras, "   ") else "")
end

function EquipmentShop:Row(order: number, icon: string, iconColor: Color3?, title: string, subtitle: string, stats: string?, buttonText: string, buttonColor: Color3, enabled: boolean, onClick: () -> ())
	local row = UIKit.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 92),
		LayoutOrder = order,
		Parent = list,
	}, { UIKit.Corner(14), UIKit.Stroke(Theme.Colors.Stroke, 1.5, 0.75) })
	local badge = UIKit.new("TextLabel", {
		Text = icon,
		TextSize = 34,
		Font = Theme.Fonts.Title,
		BackgroundColor3 = iconColor or Theme.Colors.PanelDark,
		Position = UDim2.fromOffset(10, 10),
		Size = UDim2.fromOffset(72, 72),
		TextColor3 = Color3.new(1, 1, 1),
		Parent = row,
	}, { UIKit.Corner(14) })
	UIKit.TextStroke(0.4).Parent = badge
	UIKit.Text({ Text = title, Font = Theme.Fonts.Title, TextSize = 21, Position = UDim2.fromOffset(94, 6), Size = UDim2.new(1, -260, 0, 26), Parent = row })
	UIKit.Text({ Text = subtitle, TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(94, 32), Size = UDim2.new(1, -260, 0, 18), TextTruncate = Enum.TextTruncate.AtEnd, Parent = row })
	if stats then
		UIKit.Text({ Text = stats, Font = Theme.Fonts.Bold, TextSize = 12, Position = UDim2.fromOffset(94, 54), Size = UDim2.new(1, -260, 0, 32), Parent = row })
	end
	local button = UIKit.Button(buttonText, buttonColor, onClick, {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -12, 0.5, 0),
		Size = UDim2.fromOffset(150, 48),
		TextSize = 16,
		Parent = row,
	})
	if not enabled then
		UIKit.SetButtonEnabled(button, false)
	end
	return row
end

-- Buy / Equip / Equipped / locked button for ownable items
function EquipmentShop:OwnableRow(order: number, category: string, def, icon: string, iconColor: Color3?, stats: string?)
	local data = controllers.State.Data
	local owned = data.Owned[category] and data.Owned[category][def.Id]
	local equipped = if category == "Theme" then data.Shop.Theme == def.Id else data.Equipment[category] == def.Id
	local text, color, enabled, action
	if equipped then
		text, color, enabled = "✔ Equipped", Theme.Colors.Green, false
	elseif owned then
		text, color, enabled = "Equip", Theme.Colors.Teal, true
		action = function()
			controllers.State:Call("EquipItem", category, def.Id)
		end
	elseif data.Level < def.Level then
		text, color, enabled = "🔒 Level " .. def.Level, Theme.Colors.Disabled, false
	else
		local affordable = data.Cash >= def.Price
		text, color, enabled = "Buy " .. Format.Cash(def.Price), if affordable then Theme.Colors.Gold else Theme.Colors.Disabled, affordable
		action = function()
			controllers.State:Call("BuyItem", category, def.Id)
		end
	end
	local subtitle = (def.Description or "") .. (if def.Level > 1 then "   •   Level " .. def.Level else "")
	self:Row(order, icon, iconColor, def.Name, subtitle, stats, text, color, enabled, action or function() end)
end

function EquipmentShop:Render(tab: string)
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local data = controllers.State.Data
	if not data then
		return
	end
	local now = controllers.State:Now()

	if tab == "Detectors" then
		for index, def in Equipment.Detectors do
			self:OwnableRow(index, "Detector", def, "📡", nil, detectorStats(def))
		end
	elseif tab == "Shovels" then
		for index, def in Equipment.Shovels do
			self:OwnableRow(index, "Shovel", def, "⛏", nil, shovelStats(def))
		end
	elseif tab == "Skins" then
		for index, def in Equipment.Skins do
			self:OwnableRow(index, "Skin", def, "🎨", def.Body, "Cosmetic detector paint" .. (if def.Sparkle then " with sparkles" else ""))
		end
	elseif tab == "Boosts" then
		for index, def in Equipment.Boosts do
			local expiry = data.Boosts[def.Id] or 0
			local active = expiry > now
			local subtitle = def.Description .. (if active then "   •   ⏱ " .. Format.Time(expiry - now) .. " left" else "")
			local text, color, enabled
			if data.Level < def.Level then
				text, color, enabled = "🔒 Level " .. def.Level, Theme.Colors.Disabled, false
			else
				enabled = data.Cash >= def.Price
				text, color = (if active then "Add time " else "Buy ") .. Format.Cash(def.Price), if enabled then Theme.Colors.Gold else Theme.Colors.Disabled
			end
			self:Row(index, "🍀", Theme.Colors.Green, def.Name, subtitle, "Boosts stack in time (max 2h). Only your strongest active boost applies.", text, color, enabled, function()
				controllers.State:Call("BuyBoost", def.Id)
			end)
		end
	end
end

function EquipmentShop:Init(all)
	controllers = all
	window = UIKit.Window("EquipmentShop", "🛒 Equipment Shop", Vector2.new(860, 540))
	tabs = UIKit.Tabs(window.Content, TABS, function(tab)
		self:Render(tab)
	end)
	list = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = window.Content })
	UIKit.List(nil, 8).Parent = list
	window.Opened:Connect(function(tab)
		tabs.Select(if type(tab) == "string" then tab else tabs.Selected)
	end)
end

function EquipmentShop:Start()
	controllers.State.Changed:Connect(function()
		if window.IsOpen then
			self:Render(tabs.Selected)
		end
	end)
end

return EquipmentShop
