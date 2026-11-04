--[[
	MyShopController
	🏪 My Treasure Shop window - your shop's management screen. It opens from the 📒 "Manage Shop"
	desk inside your shop (or the "Manage display" prompt on a displayed treasure).

	  Displays tab   every display slot and what's in it; place treasures from your backpack
	                 (each shows name, rarity, selling price and +Luck), remove or move them,
	                 Place Best Items, rename the shop.
	  Upgrades tab   shop upgrades (level, cost, what each unlocks: more slots + new decor) and
	                 decoration themes. Everything is saved permanently.

	The server only accepts these actions while you stand in your own shop.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Equipment = require(Shared.Config.Equipment)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Viewport = require(script.Parent.Parent.UI.Viewport)

local MyShop = {}

local controllers
local window
local tabs
local ui = {} :: any
local selectedSlot = 1
local moveFrom: number? = nil
local slotInfo: { [number]: { Type: string, ShopLevel: number } } = {}

local SLOT_ICONS = { Shelf = "🪵", Case = "🔲", Pedestal = "🏛", Wall = "🖼" }

local function loadSlotInfo()
	local map = Workspace:WaitForChild("Map", 30)
	local plots = map and map:WaitForChild("ShopPlots", 30)
	local plot = plots and plots:FindFirstChild("Plot1")
	local slots = plot and plot:FindFirstChild("Slots")
	if not slots then
		return
	end
	for _, slot in slots:GetChildren() do
		local index = slot:GetAttribute("SlotIndex")
		if index then
			slotInfo[index] = { Type = slot:GetAttribute("SlotType") or "Pedestal", ShopLevel = slot:GetAttribute("ShopLevel") or 1 }
		end
	end
end

local function clearChildren(frame: Instance, keepLayouts: boolean?)
	for _, child in frame:GetChildren() do
		if not (keepLayouts and (child:IsA("UIListLayout") or child:IsA("UIGridLayout") or child:IsA("UIPadding") or child:IsA("UICorner"))) then
			child:Destroy()
		end
	end
end

function MyShop:BuildWindow()
	window = UIKit.Window("MyShop", "🏪 My Treasure Shop", Vector2.new(900, 580))
	local content = window.Content

	tabs = UIKit.Tabs(content, { "🏺 Displays", "🏗 Upgrades" }, function(tab)
		ui.Displays.Visible = tab == "🏺 Displays"
		ui.Upgrades.Visible = tab == "🏗 Upgrades"
		self:Refresh()
	end)

	-- Displays page -------------------------------------------------------
	local page = UIKit.new("Frame", { Name = "DisplaysPage", BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42), Parent = content })
	ui.Displays = page
	local header = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 58), Parent = page })
	ui.Name = UIKit.Text({ Text = "", Font = Theme.Fonts.Title, TextSize = 22, Size = UDim2.new(1, -350, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })
	ui.NameBox = UIKit.new("TextBox", {
		Visible = false,
		Size = UDim2.new(0.42, 0, 0, 30),
		BackgroundColor3 = Theme.Colors.PanelDark,
		TextColor3 = Theme.Colors.Text,
		PlaceholderText = "Shop name (max 30)",
		Font = Theme.Fonts.Bold,
		TextSize = 16,
		ClearTextOnFocus = false,
		Text = "",
		Parent = header,
	}, { UIKit.Corner(8), UIKit.Padding(0, 8) })
	ui.NameBox.FocusLost:Connect(function(enterPressed)
		ui.NameBox.Visible = false
		ui.Name.Visible = true
		if enterPressed then
			controllers.State:Call("SetShopName", string.sub(ui.NameBox.Text, 1, 30))
		end
	end)
	ui.Stats = UIKit.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Theme.Colors.Luck, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, -350, 0, 20), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, Parent = header })

	local buttons = UIKit.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(340, 40), Parent = header }, {
		UIKit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right),
	})
	UIKit.Button("✏ Rename", Theme.Colors.Neutral, function()
		ui.Name.Visible = false
		ui.NameBox.Visible = true
		ui.NameBox.Text = (controllers.State.Data and controllers.State.Data.Shop.Name) or ""
		ui.NameBox:CaptureFocus()
	end, { Size = UDim2.fromOffset(120, 36), TextSize = 14, LayoutOrder = 1, Parent = buttons })
	UIKit.Button("✨ Place Best Items", Theme.Colors.Green, function()
		self:PlaceBest()
	end, { Size = UDim2.fromOffset(190, 36), TextSize = 14, LayoutOrder = 2, Parent = buttons })

	ui.Grid = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, -290, 1, -62), Parent = page })
	UIKit.Grid(Vector2.new(70, 84), 6).Parent = ui.Grid
	UIKit.Padding(4).Parent = ui.Grid

	ui.Side = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 62),
		Size = UDim2.new(0, 280, 1, -62),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = page,
	}, { UIKit.Corner(14), UIKit.Padding(10) })

	-- Upgrades page -------------------------------------------------------
	local upgrades = UIKit.ScrollFrame({ Name = "UpgradesPage", Position = UDim2.fromOffset(0, 42), Size = UDim2.new(1, 0, 1, -42), Visible = false, Parent = content })
	UIKit.List(nil, 8).Parent = upgrades
	UIKit.Padding(4).Parent = upgrades
	ui.Upgrades = upgrades
end

---------------------------------------------------------------------------
-- Place Best Items: the server builds the plan, we show it, the player confirms
---------------------------------------------------------------------------
local function itemLine(entry): string
	local color = UIKit.RarityColor(entry.Rarity):ToHex()
	return string.format("<font color='#%s'>%s %s</font> (%s · %s)", color, Rarities.Info[entry.Rarity] and Rarities.Info[entry.Rarity].Glyph or "", entry.Name, Format.Cash(entry.Value), Format.Luck(entry.Luck))
end

function MyShop:ShowPlacePreview(preview)
	local lines = {}
	local shown = 0
	for _, add in preview.Add do
		shown += 1
		if shown <= 8 then
			if add.Replaces then
				table.insert(lines, string.format("🔁 Slot %d: %s  ⟵ replaces %s", add.Slot, itemLine(add), itemLine(add.Replaces)))
			else
				table.insert(lines, string.format("➕ Slot %d: %s", add.Slot, itemLine(add)))
			end
		end
	end
	if shown > 8 then
		table.insert(lines, string.format("<i>…and %d more</i>", shown - 8))
	end
	local returned = #preview.Return
	local message = table.concat(lines, "\n")
		.. string.format("\n\n🎒 Back to your backpack: <b>%d</b> treasure%s", returned, if returned == 1 then "" else "s")
		.. string.format("\n🍀 Shop Luck: <b>%s</b> → <b>%s</b>", Format.Luck(preview.LuckBefore), Format.Luck(preview.LuckAfter))
	UIKit.Confirm("✨ Place Best Items", "<font size='14'>" .. message .. "</font>", {
		{
			Text = string.format("Place %d treasure%s", #preview.Add, if #preview.Add == 1 then "" else "s"),
			Color = Theme.Colors.Green,
			Callback = function()
				local result = controllers.State:Call("AutoFillShop", "Confirm", preview.Signature)
				if result.Ok then
					controllers.Sound:Chime(4)
					controllers.Notify:Celebrate("🏪", "SHOP UPDATED!", string.format("%d placed · %d returned to backpack\n🍀 Shop Luck %s → %s",
						result.Count, result.Returned, Format.Luck(result.LuckBefore), Format.Luck(result.LuckAfter)), Theme.Colors.Green, 3)
				elseif result.Changed and result.Preview then
					self:ShowPlacePreview(result.Preview)
				end
			end,
		},
	})
end

function MyShop:PlaceBest()
	local result = controllers.State:Call("AutoFillShop", "Preview")
	if result.Ok and result.Preview then
		self:ShowPlacePreview(result.Preview)
	end
end

---------------------------------------------------------------------------
-- Displays tab
---------------------------------------------------------------------------
-- one backpack treasure: name, rarity, selling price and the Luck it gives on display
local function pickerRow(parent: Instance, order: number, candidate, onClick: () -> ())
	local def = Treasures.ById[candidate.TreasureId]
	if not def then
		return
	end
	local row = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = Theme.Colors.PanelLight,
		Size = UDim2.new(1, -8, 0, 54),
		LayoutOrder = order,
		Parent = parent,
		OnActivated = onClick,
	}, { UIKit.Corner(8), UIKit.Stroke(UIKit.RarityColor(def.Rarity), 1.5, 0.4) })
	local icon = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(2, 3), Size = UDim2.fromOffset(48, 48), Parent = row })
	Viewport.Create(def.Id).Parent = icon
	UIKit.Text({ Text = (if candidate.Favorite then "⭐ " else "") .. def.Name, Font = Theme.Fonts.Bold, TextSize = 13, Position = UDim2.fromOffset(54, 3), Size = UDim2.new(1, -60, 0, 17), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = row })
	UIKit.RarityLabel(def.Rarity, { TextSize = 11, Position = UDim2.fromOffset(54, 19), Size = UDim2.new(1, -60, 0, 14), Parent = row })
	UIKit.Text({
		Text = string.format("<font color='#ffc43c'><b>%s</b></font>   <font color='#7ee08a'><b>%s</b></font>", Format.Cash(candidate.Value), Format.Luck(GameMath.ItemDisplayLuck(candidate))),
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		Position = UDim2.fromOffset(54, 34),
		Size = UDim2.new(1, -60, 0, 16),
		TextWrapped = false,
		Parent = row,
	})
end

function MyShop:RenderSide(data)
	local side = ui.Side
	clearChildren(side, true)
	local key = tostring(selectedSlot)
	local item = data.Shop.Displays[key]
	local info = slotInfo[selectedSlot] or { Type = "Pedestal", ShopLevel = 1 }
	local unlocked = selectedSlot <= data.Shop.Slots

	local container = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = side }, { UIKit.List(nil, 6, Enum.HorizontalAlignment.Center) })
	UIKit.Text({ Text = string.format("%s Slot %d  ·  %s", SLOT_ICONS[info.Type] or "", selectedSlot, info.Type), Font = Theme.Fonts.Title, TextSize = 19, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = container })

	if not unlocked then
		local level = Equipment.ShopLevels[info.ShopLevel]
		UIKit.Text({ Text = "🔒 Locked\nUpgrade your shop to " .. (if level then level.Name else "a bigger shop") .. " (🏗 Upgrades tab) to use this slot.", TextSize = 15, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 80), LayoutOrder = 2, Parent = container })
		return
	end

	if moveFrom then
		UIKit.Text({ Text = "Moving the treasure from slot " .. moveFrom .. ".\nClick the slot to move it to.", TextSize = 14, TextColor3 = Theme.Colors.Gold, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 2, Parent = container })
		UIKit.Button("Cancel move", Theme.Colors.Neutral, function()
			moveFrom = nil
			self:Refresh()
		end, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 3, Parent = container })
		return
	end

	if item then
		local def = Treasures.ById[item.TreasureId]
		local holder = UIKit.new("Frame", { Size = UDim2.fromOffset(150, 110), BackgroundColor3 = Theme.Colors.Panel, LayoutOrder = 2, Parent = container }, { UIKit.Corner(12) })
		Viewport.Create(item.TreasureId, { Spin = true }).Parent = holder
		UIKit.Text({ Text = def and def.Name or "?", Font = Theme.Fonts.Title, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, Parent = container })
		if def then
			UIKit.RarityLabel(def.Rarity, { TextSize = 14, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = container })
		end
		UIKit.Text({ Text = string.format("<font color='#ffc43c'><b>%s</b></font>   •   <font color='#7ee08a'><b>%s</b></font>", Format.Cash(item.Value), Format.Luck(GameMath.ItemDisplayLuck(item))), TextSize = 15, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 5, Parent = container })
		UIKit.Button("↩ Back to backpack", Theme.Colors.Coral, function()
			controllers.State:Call("RemoveDisplay", selectedSlot)
		end, { Size = UDim2.new(1, 0, 0, 34), TextSize = 15, LayoutOrder = 6, Parent = container })
		UIKit.Button("↔ Move to another slot", Theme.Colors.Teal, function()
			moveFrom = selectedSlot
			self:Refresh()
		end, { Size = UDim2.new(1, 0, 0, 34), TextSize = 15, LayoutOrder = 7, Parent = container })
		UIKit.Text({ Text = "Tip: pick a backpack treasure below to swap it in.", TextSize = 11, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 14), LayoutOrder = 8, Parent = container })
	else
		UIKit.Text({ Text = "Empty — choose a treasure to display:", TextSize = 14, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 2, Parent = container })
	end

	-- Backpack picker (best Luck first): name, rarity, selling price and +Luck side by side
	local picker = UIKit.ScrollFrame({ Size = UDim2.new(1, 0, 0, if item then 118 else 340), LayoutOrder = 20, Parent = container })
	UIKit.List(nil, 4).Parent = picker
	local candidates = table.clone(data.Inventory)
	table.sort(candidates, function(a, b)
		return GameMath.ItemDisplayLuck(a) > GameMath.ItemDisplayLuck(b)
	end)
	if #candidates == 0 then
		UIKit.Text({ Text = "Your backpack is empty.", TextSize = 13, TextColor3 = Theme.Colors.Muted, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, Parent = picker })
	end
	for order, candidate in candidates do
		pickerRow(picker, order, candidate, function()
			local result = controllers.State:Call("DisplayItem", candidate.Id, selectedSlot)
			if result.Ok then
				controllers.Sound:Play("Reward", 1.2, 0.6)
			end
		end)
	end
end

function MyShop:RenderDisplays(data)
	local shop = data.Shop
	ui.Name.Text = if shop.Name ~= "" then shop.Name else "My Treasure Shop"
	local count = GameMath.CountDisplays(shop.Displays)
	local level = Equipment.ShopLevels[shop.Level]
	ui.Stats.Text = string.format("🍀 Shop %s   💎 Value %s   🏺 %d / %d displayed   🏗 %s",
		Format.Luck(GameMath.ShopLuck(shop.Displays)), Format.Cash(GameMath.ShopValue(shop.Displays)), count, shop.Slots, if level then level.Name else "")

	clearChildren(ui.Grid, true)
	for index = 1, 48 do
		local info = slotInfo[index] or { Type = "Pedestal", ShopLevel = 1 }
		local unlocked = index <= shop.Slots
		local item = shop.Displays[tostring(index)]
		local def = item and Treasures.ById[item.TreasureId]
		local strokeColor = if index == selectedSlot then Theme.Colors.Gold elseif def then UIKit.RarityColor(def.Rarity) else Theme.Colors.Stroke
		local cell = UIKit.new("TextButton", {
			Text = "",
			AutoButtonColor = unlocked,
			BackgroundColor3 = if unlocked then Theme.Colors.PanelLight else Theme.Colors.PanelDark,
			LayoutOrder = index,
			Parent = ui.Grid,
			OnActivated = function()
				if moveFrom and unlocked and index ~= moveFrom then
					local from = moveFrom
					moveFrom = nil
					selectedSlot = index
					controllers.State:Call("MoveDisplay", from, index)
				else
					selectedSlot = index
				end
				self:Refresh()
			end,
		}, { UIKit.Corner(10), UIKit.Stroke(strokeColor, if index == selectedSlot then 3 else 1.5, if index == selectedSlot then 0 else 0.5) })
		UIKit.Text({ Text = tostring(index), Font = Theme.Fonts.Bold, TextSize = 10, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(20, 12), Parent = cell })
		UIKit.Text({ Text = SLOT_ICONS[info.Type] or "", TextSize = 11, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 1), Size = UDim2.fromOffset(16, 14), TextXAlignment = Enum.TextXAlignment.Right, Parent = cell })
		if not unlocked then
			UIKit.Text({ Text = "🔒", TextSize = 22, Size = UDim2.new(1, 0, 0, 40), Position = UDim2.fromOffset(0, 14), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
			local needed = Equipment.ShopLevels[info.ShopLevel]
			UIKit.Text({ Text = if needed then needed.Name else "", TextSize = 9, TextColor3 = Theme.Colors.Muted, Position = UDim2.new(0, 2, 1, -24), Size = UDim2.new(1, -4, 0, 22), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
		elseif item and def then
			local icon = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(6, 12), Size = UDim2.new(1, -12, 0, 48), Parent = cell })
			Viewport.Create(def.Id).Parent = icon
			UIKit.Text({ Text = Format.Luck(GameMath.ItemDisplayLuck(item)), Font = Theme.Fonts.Bold, TextSize = 9, TextColor3 = Theme.Colors.Luck, Position = UDim2.new(0, 0, 1, -18), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = cell })
		else
			UIKit.Text({ Text = "Empty", TextSize = 11, TextColor3 = Theme.Colors.Muted, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
		end
	end
	self:RenderSide(data)
end

---------------------------------------------------------------------------
-- Upgrades tab: shop levels + themes
---------------------------------------------------------------------------
local function card(parent: Instance, order: number, height: number): Frame
	return UIKit.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, Size = UDim2.new(1, -8, 0, height), LayoutOrder = order, Parent = parent }, { UIKit.Corner(12) })
end

local function sectionTitle(parent: Instance, order: number, text: string, sub: string)
	local frame = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 42), LayoutOrder = order, Parent = parent })
	UIKit.Text({ Text = text, Font = Theme.Fonts.Title, TextSize = 20, Size = UDim2.new(1, 0, 0, 24), Parent = frame })
	UIKit.Text({ Text = sub, TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 16), Parent = frame })
end

function MyShop:RenderUpgrades(data)
	local page = ui.Upgrades
	clearChildren(page, true)
	local current = data.Shop.Level or 1
	local currentDef = Equipment.ShopLevels[current]
	sectionTitle(page, 1, "🏗 Shop upgrades", string.format("Your shop: %s  ·  %d display slots. Each upgrade adds slots and new decor, and is saved forever.",
		if currentDef then currentDef.Name else "?", data.Shop.Slots))
	for index, def in Equipment.ShopLevels do
		local row = card(page, 1 + index, 74)
		local owned = index <= current
		UIKit.Stroke(if index == current then Theme.Colors.Gold else Theme.Colors.Stroke, 2, if index == current then 0.1 else 0.7).Parent = row
		UIKit.new("Frame", { BackgroundColor3 = if owned then Theme.Colors.Green else Theme.Colors.PanelDark, Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(52, 52), Parent = row }, { UIKit.Corner(12) })
		UIKit.Text({ Text = tostring(index), Font = Theme.Fonts.Title, TextSize = 28, Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(52, 52), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		UIKit.Text({ Text = string.format("%s  <font size='13' color='#9fb4c8'>·  %d slots  ·  Level %d</font>", def.Name, def.Slots, def.Level), Font = Theme.Fonts.Title, TextSize = 18, Position = UDim2.fromOffset(74, 8), Size = UDim2.new(1, -270, 0, 24), TextWrapped = false, Parent = row })
		UIKit.Text({ Text = def.Unlocks or "", TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(74, 34), Size = UDim2.new(1, -270, 0, 34), Parent = row })

		local text, color, enabled = "", Theme.Colors.Disabled, false
		if owned then
			text, color = if index == current then "✔ Current" else "✔ Owned", Theme.Colors.Green
		elseif index == current + 1 then
			if data.Level < def.Level then
				text = "🔒 Level " .. def.Level
			else
				enabled = data.Cash >= def.Price
				text, color = "Upgrade  " .. Format.Cash(def.Price), if enabled then Theme.Colors.Gold else Theme.Colors.Disabled
			end
		else
			text = "Upgrade previous first"
		end
		local button = UIKit.Button(text, color, function()
			local result = controllers.State:Call("ExpandShop")
			if result.Ok then
				controllers.Sound:Chime(4)
				controllers.Notify:Celebrate("🏗", "SHOP UPGRADED!", def.Name .. "  ·  " .. def.Slots .. " display slots\n" .. (def.Unlocks or ""), Theme.Colors.Gold, 3)
			end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(180, 46), TextSize = 15, Parent = row })
		if not enabled and not owned then
			UIKit.SetButtonEnabled(button, false)
		end
		if owned then
			UIKit.SetButtonEnabled(button, false, Theme.Colors.Green)
		end
	end

	local base = #Equipment.ShopLevels + 10
	sectionTitle(page, base, "🎨 Decoration themes", "Floor, walls, trim and display furniture colours. Buy once, switch any time.")
	for index, def in Equipment.Themes do
		local row = card(page, base + index, 62)
		local owned = data.Owned.Theme ~= nil and data.Owned.Theme[def.Id] == true
		local applied = data.Shop.Theme == def.Id
		UIKit.Stroke(if applied then Theme.Colors.Gold else Theme.Colors.Stroke, 2, if applied then 0.1 else 0.7).Parent = row
		local swatches = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(10, 11), Size = UDim2.fromOffset(84, 40), Parent = row }, { UIKit.List(Enum.FillDirection.Horizontal, 4) })
		for order, colour in { def.Floor, def.Wall, def.Trim, def.Furniture } do
			UIKit.new("Frame", { BackgroundColor3 = colour, Size = UDim2.fromOffset(18, 40), LayoutOrder = order, Parent = swatches }, { UIKit.Corner(6), UIKit.Stroke(Color3.new(0, 0, 0), 1, 0.6) })
		end
		UIKit.Text({ Text = def.Name .. (if def.Level > 1 then string.format("  <font size='13' color='#9fb4c8'>·  Level %d</font>", def.Level) else ""), Font = Theme.Fonts.Title, TextSize = 18, Position = UDim2.fromOffset(106, 0), Size = UDim2.new(1, -310, 1, 0), TextWrapped = false, Parent = row })
		local text, color, enabled, action = "", Theme.Colors.Disabled, false, "Equip"
		if applied then
			text, color = "✔ Applied", Theme.Colors.Green
		elseif owned then
			text, color, enabled = "Apply", Theme.Colors.Teal, true
		elseif data.Level < def.Level then
			text = "🔒 Level " .. def.Level
		else
			enabled = data.Cash >= def.Price
			text, color, action = "Buy  " .. Format.Cash(def.Price), if enabled then Theme.Colors.Gold else Theme.Colors.Disabled, "Buy"
		end
		local button = UIKit.Button(text, color, function()
			local result = controllers.State:Call("ShopTheme", action, def.Id)
			if result.Ok and action == "Buy" then
				controllers.Sound:Chime(3)
			end
		end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(180, 42), TextSize = 15, Parent = row })
		if not enabled then
			UIKit.SetButtonEnabled(button, false, if applied then Theme.Colors.Green else nil)
		end
	end
end

---------------------------------------------------------------------------
function MyShop:Refresh()
	local data = controllers.State.Data
	if not data or not window.IsOpen then
		return
	end
	if next(slotInfo) == nil then
		loadSlotInfo()
	end
	if ui.Upgrades.Visible then
		self:RenderUpgrades(data)
	else
		self:RenderDisplays(data)
	end
end

function MyShop:Open(tab: string?)
	moveFrom = nil
	if not window.IsOpen then
		window:Open()
	end
	tabs.Select(tab or tabs.Selected)
end

-- Open with a slot pre-selected (used by the in-world "Manage display" prompts)
function MyShop:OpenSlot(index: number)
	selectedSlot = index
	self:Open("🏺 Displays")
end

function MyShop:Init(all)
	controllers = all
	self:BuildWindow()
	window.Opened:Connect(function()
		self:Refresh()
	end)
end

function MyShop:Start()
	task.spawn(loadSlotInfo)
	controllers.State.Changed:Connect(function()
		self:Refresh()
	end)
end

return MyShop
