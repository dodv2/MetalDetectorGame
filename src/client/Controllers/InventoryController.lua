--[[
	InventoryController
	🎒 Backpack window (10 slots): inspect and organise (filter / sort), ⭐ favourite and 🔒 lock
	every treasure you're carrying. Each shows its selling price and the +Luck it gives on display.

	  ⚡ Quick Sell   ONLY AT BASE: pick which rarities to sell (saved), see the count + total,
	                  confirm. Locked and favourite treasures are never included (server checks too).
	  Sell mode       opened by the Sell Shop NPC: tap treasures to select them, see the total,
	                  confirm. The server only sells while you're at the Sell Shop.
	Displaying happens in your own shop (📒 Manage Shop desk), never from here or the dig site.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Viewport = require(script.Parent.Parent.UI.Viewport)

local Inventory = {}

local controllers
local window
local ui = {} :: any
local selectedId: string? = nil
local filterIndex = 0 -- 0 = all, -1 = favourites, 1..7 = rarity tier
local sortIndex = 1
local SORTS = { "Rarity", "Value", "Luck", "Newest" }
local sellMode = false
local sellPick: { [string]: boolean } = {}

local function getDef(item)
	return Treasures.ById[item.TreasureId]
end

local function protected(item): boolean
	return item.Locked == true or item.Favorite == true
end

local function filterName(): string
	if filterIndex == 0 then
		return "All"
	elseif filterIndex == -1 then
		return "⭐ Favourites"
	end
	return Rarities.Order[filterIndex]
end

local function sortedItems(data)
	local items = {}
	for _, item in data.Inventory do
		local def = getDef(item)
		local pass = filterIndex == 0
			or (filterIndex == -1 and item.Favorite == true)
			or (filterIndex > 0 and def ~= nil and Rarities.Tier(def.Rarity) == filterIndex)
		if def and pass then
			table.insert(items, item)
		end
	end
	local mode = SORTS[sortIndex]
	table.sort(items, function(a, b)
		-- favourites always float to the top
		if (a.Favorite == true) ~= (b.Favorite == true) then
			return a.Favorite == true
		end
		local da, db = getDef(a), getDef(b)
		if mode == "Value" then
			return a.Value > b.Value
		elseif mode == "Luck" then
			return GameMath.ItemDisplayLuck(a) > GameMath.ItemDisplayLuck(b)
		elseif mode == "Newest" then
			return (tonumber(a.Id) or 0) > (tonumber(b.Id) or 0)
		end
		local ta, tb = Rarities.Tier(da.Rarity), Rarities.Tier(db.Rarity)
		if ta ~= tb then
			return ta > tb
		end
		return a.Value > b.Value
	end)
	return items
end

---------------------------------------------------------------------------
-- Selling helpers
---------------------------------------------------------------------------
local function celebrateSale(count: number, cash: number)
	controllers.Sound:Play("Reward", 1.3)
	controllers.Sound:Chime(3)
	controllers.HUD:BumpCash()
	controllers.Effects:Confetti(Theme.Colors.Gold, 24)
	controllers.Notify:Celebrate("💰", "SOLD!", string.format("%s  ·  +%s", Format.Plural(count, "treasure"), Format.Cash(cash)), Theme.Colors.Gold, 2.2)
end

local function quickSellRarities(): { [string]: boolean }
	local data = controllers.State.Data
	local saved = data and data.Settings and data.Settings.QuickSell
	local result = {}
	for tier, rarity in Rarities.Order do
		if type(saved) == "table" and saved[rarity] ~= nil then
			result[rarity] = saved[rarity] == true
		else
			result[rarity] = tier <= 4
		end
	end
	return result
end

-- count + total of what Quick Sell would sell (the server recounts when you confirm)
local function quickSellPreview(rarities: { [string]: boolean })
	local data = controllers.State.Data
	local count, total, kept = 0, 0, 0
	for _, item in data.Inventory do
		local def = getDef(item)
		if def and rarities[def.Rarity] then
			if protected(item) then
				kept += 1
			else
				count += 1
				total += item.Value
			end
		end
	end
	return count, total, kept
end

function Inventory:OpenQuickSell()
	local data = controllers.State.Data
	if not data then
		return
	end
	if not controllers.World:IsAtBase() then
		controllers.Notify:Toast("⚡ Quick Sell works on the Pier. Tap ⚓ Pier to head back first.", "Warning", 4)
		controllers.Sound:Play("Error")
		return
	end
	if not window.IsOpen then
		window:Open()
	end
	local rarities = quickSellRarities()

	local blocker = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = UIKit.Overlay,
	})
	UIKit.Overlay.DisplayOrder = 20
	local dialog = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(460, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 51,
		Parent = blocker,
	}, { UIKit.Corner(16), UIKit.Stroke(Theme.Colors.Gold, 3, 0.3), UIKit.Padding(16), UIKit.List(nil, 10, Enum.HorizontalAlignment.Center) })
	UIKit.AddScale(dialog)
	local function close()
		blocker:Destroy()
		UIKit.Overlay.DisplayOrder = -1
	end

	UIKit.Text({ Text = "⚡ Quick Sell", Font = Theme.Fonts.Title, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, LayoutOrder = 1, Parent = dialog })
	UIKit.Text({ Text = "Choose which rarities to sell. 🔒 Locked and ⭐ favourite treasures are always kept.", TextSize = 14, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, LayoutOrder = 2, Parent = dialog })

	local chips = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 52, LayoutOrder = 3, Parent = dialog }, {
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(136, 34), CellPadding = UDim2.fromOffset(6, 6), HorizontalAlignment = Enum.HorizontalAlignment.Center, SortOrder = Enum.SortOrder.LayoutOrder }),
	})
	local summary = UIKit.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = 17, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, LayoutOrder = 4, Parent = dialog })
	local sellButton: TextButton

	local chipButtons = {}
	local function refresh()
		for rarity, chip in chipButtons do
			local on = rarities[rarity]
			UIKit.SetButtonColor(chip, if on then UIKit.RarityColor(rarity):Lerp(Color3.new(0, 0, 0), 0.25) else Theme.Colors.Disabled)
			chip.Text = (if on then "✔ " else "✕ ") .. Rarities.Label(rarity)
		end
		local count, total, kept = quickSellPreview(rarities)
		summary.Text = if count > 0
			then string.format("Sell <b>%s</b> for <font color='#ffc43c'><b>%s</b></font>%s", Format.Plural(count, "treasure"), Format.Cash(total), if kept > 0 then string.format("\n<font size='13' color='#b0c8da'>(%d protected item%s kept)</font>", kept, if kept == 1 then "" else "s") else "")
			else "Nothing to sell with these filters"
		if sellButton then
			UIKit.SetButtonEnabled(sellButton, count > 0, Theme.Colors.Gold)
			sellButton.Text = if count > 0 then "💰 Sell " .. count .. " for " .. Format.Cash(total) else "Nothing to sell"
		end
	end
	for tier, rarity in Rarities.Order do
		local chip = UIKit.Button("", Theme.Colors.Disabled, function()
			rarities[rarity] = not rarities[rarity]
			refresh()
		end, { TextSize = 13, LayoutOrder = tier, ZIndex = 53, Parent = chips })
		chipButtons[rarity] = chip
	end

	sellButton = UIKit.Button("💰 Sell", Theme.Colors.Gold, function()
		local snapshot = table.clone(rarities)
		close()
		task.spawn(function()
			controllers.State:Call("UpdateSettings", "QuickSell", snapshot)
		end)
		local result = controllers.State:Call("SellBulk", { Rarities = snapshot })
		if result.Ok then
			celebrateSale(result.Count, result.Cash)
		end
	end, { Size = UDim2.new(1, 0, 0, 44), TextSize = 18, LayoutOrder = 5, ZIndex = 52, Parent = dialog })
	UIKit.Button("Cancel", Theme.Colors.Neutral, function()
		close()
		task.spawn(function()
			controllers.State:Call("UpdateSettings", "QuickSell", rarities)
		end)
	end, { Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 6, ZIndex = 52, Parent = dialog })
	refresh()
end

-- Sell mode (Sell Shop): tap treasures to pick them
function Inventory:OpenSellMode()
	sellMode = true
	table.clear(sellPick)
	selectedId = nil
	if window.IsOpen then
		self:Refresh()
	else
		window:Open()
	end
end

function Inventory:ConfirmSellPicked()
	local data = controllers.State.Data
	local ids, total = {}, 0
	for _, item in data.Inventory do
		if sellPick[item.Id] and not protected(item) then
			table.insert(ids, item.Id)
			total += item.Value
		end
	end
	if #ids == 0 then
		return
	end
	UIKit.Confirm("💰 Sell treasures", string.format("Sell <b>%s</b> for <b>%s</b>?", Format.Plural(#ids, "treasure"), Format.Cash(total)), {
		{
			Text = "💰 Sell for " .. Format.Cash(total),
			Color = Theme.Colors.Gold,
			Callback = function()
				local result = controllers.State:Call("SellBulk", { Ids = ids })
				if result.Ok then
					table.clear(sellPick)
					celebrateSale(result.Count, result.Cash)
				end
			end,
		},
	})
end

---------------------------------------------------------------------------
-- Window
---------------------------------------------------------------------------
function Inventory:BuildWindow()
	window = UIKit.Window("Inventory", "🎒 Backpack", Vector2.new(840, 540))
	local content = window.Content

	local toolbar = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 38), Parent = content }, {
		UIKit.List(Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center),
	})
	ui.Capacity = UIKit.Text({ Text = "0/10", Font = Theme.Fonts.Title, TextSize = 20, Size = UDim2.fromOffset(96, 38), LayoutOrder = 1, Parent = toolbar })
	ui.Filter = UIKit.Button("Show: All", Theme.Colors.Neutral, function()
		filterIndex += 1
		if filterIndex > #Rarities.Order then
			filterIndex = -1
		end
		self:Refresh()
	end, { Size = UDim2.fromOffset(160, 36), TextSize = 15, LayoutOrder = 2, Parent = toolbar })
	ui.Sort = UIKit.Button("Sort: Rarity", Theme.Colors.Neutral, function()
		sortIndex = sortIndex % #SORTS + 1
		self:Refresh()
	end, { Size = UDim2.fromOffset(130, 36), TextSize = 15, LayoutOrder = 3, Parent = toolbar })
	ui.QuickSell = UIKit.Button("⚡ Quick Sell", Theme.Colors.Gold, function()
		self:OpenQuickSell()
	end, { Size = UDim2.fromOffset(130, 36), TextSize = 15, LayoutOrder = 4, Parent = toolbar })
	ui.Where = UIKit.Text({ Text = "", TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.fromOffset(250, 36), LayoutOrder = 5, Parent = toolbar })

	ui.Grid = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, -290, 1, -46), Parent = content })
	UIKit.Grid(Vector2.new(104, 132), 8).Parent = ui.Grid
	UIKit.Padding(4).Parent = ui.Grid
	ui.Empty = UIKit.Text({ Text = "Your backpack is empty.\nHold your 📡 detector on a beach and dig up some treasure!", TextSize = 17, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Position = UDim2.fromOffset(0, 120), Size = UDim2.new(1, -290, 0, 60), Visible = false, Parent = content })

	ui.Detail = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 46),
		Size = UDim2.new(0, 276, 1, -46),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = content,
	}, { UIKit.Corner(14), UIKit.Padding(12), UIKit.List(nil, 6, Enum.HorizontalAlignment.Center) })

	window.Closed:Connect(function()
		sellMode = false
		table.clear(sellPick)
	end)
end

local function clearDetail()
	for _, child in ui.Detail:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

function Inventory:ShowSellPanel(data)
	clearDetail()
	local detail = ui.Detail
	local count, total = 0, 0
	for _, item in data.Inventory do
		if sellPick[item.Id] and not protected(item) then
			count += 1
			total += item.Value
		end
	end
	UIKit.Text({ Text = "💰 Sell Shop", Font = Theme.Fonts.Title, TextSize = 22, Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = detail })
	UIKit.Text({ Text = "Tap treasures on the left to select them.\n🔒 locked and ⭐ favourites can't be selected.", TextSize = 13, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = detail })
	local totalLabel = UIKit.Text({ Text = string.format("<b>%d</b> selected\n<font size='26' color='#ffc43c'>%s</font>", count, Format.Cash(total)), Font = Theme.Fonts.Title, TextSize = 18, Size = UDim2.new(1, 0, 0, 64), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = detail })
	UIKit.TextStroke(0.5).Parent = totalLabel
	local sell = UIKit.Button(if count > 0 then "💰 Sell selected" else "Select treasures", Theme.Colors.Gold, function()
		self:ConfirmSellPicked()
	end, { Size = UDim2.new(1, 0, 0, 44), TextSize = 17, LayoutOrder = 4, Parent = detail })
	UIKit.SetButtonEnabled(sell, count > 0, Theme.Colors.Gold)
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 36), LayoutOrder = 5, Parent = detail }, { UIKit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	UIKit.Button("Select all", Theme.Colors.Teal, function()
		for _, item in sortedItems(data) do
			if not protected(item) then
				sellPick[item.Id] = true
			end
		end
		self:Refresh()
	end, { Size = UDim2.fromOffset(122, 34), TextSize = 14, Parent = row })
	UIKit.Button("Clear", Theme.Colors.Neutral, function()
		table.clear(sellPick)
		self:Refresh()
	end, { Size = UDim2.fromOffset(122, 34), TextSize = 14, Parent = row })
	UIKit.Button("⚡ Quick Sell…", Theme.Colors.Gold, function()
		self:OpenQuickSell()
	end, { Size = UDim2.new(1, 0, 0, 36), TextSize = 15, LayoutOrder = 6, Parent = detail })
	UIKit.Button("Done", Theme.Colors.Neutral, function()
		sellMode = false
		table.clear(sellPick)
		self:Refresh()
	end, { Size = UDim2.new(1, 0, 0, 34), TextSize = 14, LayoutOrder = 7, Parent = detail })
end

function Inventory:ShowDetail(item)
	clearDetail()
	local detail = ui.Detail
	if not item then
		UIKit.Text({ Text = "Select a treasure to see its details.\n\n💰 Sell at the Sell Shop on the Pier.\n🏪 Display it in your own shop (Manage Shop desk) for permanent Luck.\n⭐ Favourite or 🔒 lock treasures to protect them from Quick Sell.", TextSize = 15, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.new(1, 0, 0, 200), Parent = detail })
		return
	end
	local def = getDef(item)
	local holder = UIKit.new("Frame", { Size = UDim2.fromOffset(160, 120), BackgroundColor3 = Theme.Colors.Panel, LayoutOrder = 1, Parent = detail }, {
		UIKit.Corner(14),
		UIKit.Gradient(UIKit.RarityColor(def.Rarity):Lerp(Color3.new(0, 0, 0), 0.55), Theme.Colors.PanelDark),
	})
	Viewport.Create(def.Id, { Spin = true }).Parent = holder
	UIKit.Text({ Text = (if item.Favorite then "⭐ " else "") .. def.Name, Font = Theme.Fonts.Title, TextSize = 22, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = detail })
	UIKit.RarityLabel(def.Rarity, { Text = Rarities.Label(def.Rarity) .. "  " .. UIKit.TierPips(def.Rarity), TextSize = 15, Size = UDim2.new(1, 0, 0, 18), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, Parent = detail })
	local zone = Zones.Info[item.Zone]
	UIKit.Text({
		Text = string.format("💰 <b>%s</b>   •   %s (x%.2f)\n🍀 <b>%s</b> on display\n📍 %s", Format.Cash(item.Value), GameMath.QualityName(item.Quality), item.Quality, Format.Luck(GameMath.ItemDisplayLuck(item)), if zone then zone.Name else "?"),
		TextSize = 14,
		Size = UDim2.new(1, 0, 0, 56),
		TextXAlignment = Enum.TextXAlignment.Center,
		LayoutOrder = 4,
		Parent = detail,
	})
	UIKit.Text({ Text = "<i>" .. def.Lore .. "</i>", TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 5, Parent = detail })
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 40), LayoutOrder = 6, Parent = detail }, { UIKit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	UIKit.Button(if item.Favorite then "★ Favourite" else "☆ Favourite", if item.Favorite then Theme.Colors.Gold else Theme.Colors.Neutral, function()
		controllers.State:Call("ToggleLock", item.Id, "Favorite")
	end, { Size = UDim2.fromOffset(130, 38), TextSize = 15, Parent = row })
	UIKit.Button(if item.Locked then "🔓" else "🔒", Theme.Colors.Neutral, function()
		controllers.State:Call("ToggleLock", item.Id)
	end, { Size = UDim2.fromOffset(44, 38), TextSize = 18, Parent = row })
	local notes = {}
	if item.Favorite then
		table.insert(notes, "⭐ Favourite")
	end
	if item.Locked then
		table.insert(notes, "🔒 Locked")
	end
	UIKit.Text({ Text = if #notes > 0 then table.concat(notes, " · ") .. ": Quick Sell skips it" else "", TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 7, Parent = detail })
	UIKit.Text({ Text = "💰 Sell at the Sell Shop  ·  🏪 Display at your shop's Manage Shop desk", TextSize = 12, TextColor3 = Theme.Colors.Gold, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 8, Parent = detail })
end

function Inventory:Refresh()
	local data = controllers.State.Data
	if not data or not window.IsOpen then
		return
	end
	window.Title.Text = if sellMode then "💰 Sell Shop  ·  🎒 Backpack" else "🎒 Backpack"
	ui.Capacity.Text = string.format("%d / %d", #data.Inventory, data.Capacity)
	ui.Capacity.TextColor3 = if #data.Inventory >= data.Capacity then Theme.Colors.Coral else Theme.Colors.Text
	ui.Filter.Text = "Show: " .. filterName()
	ui.Sort.Text = "Sort: " .. SORTS[sortIndex]
	local atBase = controllers.World:IsAtBase()
	UIKit.SetButtonEnabled(ui.QuickSell, atBase, Theme.Colors.Gold)
	ui.Where.Text = if atBase then "" else "⚡ Quick Sell works on the Pier"

	for _, child in ui.Grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local items = sortedItems(data)
	ui.Empty.Visible = #data.Inventory == 0
	local selectedItem = nil
	for order, item in items do
		local def = getDef(item)
		local color = UIKit.RarityColor(def.Rarity)
		local picked = sellMode and sellPick[item.Id] == true
		local highlighted = picked or (not sellMode and item.Id == selectedId)
		local cell = UIKit.new("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = if picked then Color3.fromRGB(90, 76, 30) else Theme.Colors.PanelLight,
			BackgroundTransparency = if sellMode and protected(item) then 0.5 else 0,
			LayoutOrder = order,
			Parent = ui.Grid,
			OnActivated = function()
				if sellMode then
					if protected(item) then
						controllers.Notify:Toast((if item.Favorite then "⭐ Favourite" else "🔒 Locked") .. " treasures can't be sold here. Un-protect it first.", "Info", 2.5)
						return
					end
					sellPick[item.Id] = if sellPick[item.Id] then nil else true
				else
					selectedId = item.Id
				end
				self:Refresh()
			end,
		}, { UIKit.Corner(12), UIKit.Stroke(if picked then Theme.Colors.Gold else color, if highlighted then 4 else 2, if highlighted then 0 else 0.35) })
		local icon = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 74), Parent = cell })
		Viewport.Create(def.Id).Parent = icon
		UIKit.Text({ Text = def.Name, Font = Theme.Fonts.Bold, TextSize = 11, Position = UDim2.fromOffset(4, 74), Size = UDim2.new(1, -8, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.AtEnd, Parent = cell })
		UIKit.RarityLabel(def.Rarity, { TextSize = 11, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 13), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
		UIKit.Text({ Text = string.format("<font color='#ffc43c'>%s</font>  <font color='#7ee08a'>%s</font>", Format.Cash(item.Value), Format.LuckNumber(GameMath.ItemDisplayLuck(item))), Font = Theme.Fonts.Bold, TextSize = 12, Position = UDim2.fromOffset(0, 114), Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Parent = cell })
		local badges = (if item.Favorite then "⭐" else "") .. (if item.Locked then "🔒" else "")
		if badges ~= "" then
			UIKit.Text({ Text = badges, TextSize = 14, Position = UDim2.fromOffset(4, 2), Size = UDim2.fromOffset(40, 18), Parent = cell })
		end
		if picked then
			UIKit.new("TextLabel", { Text = "✔", Font = Theme.Fonts.Title, TextSize = 18, TextColor3 = Color3.fromRGB(40, 30, 0), BackgroundColor3 = Theme.Colors.Gold, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -4, 0, 4), Size = UDim2.fromOffset(24, 24), ZIndex = 3, Parent = cell }, { UIKit.Round() })
		end
		if item.Id == selectedId then
			selectedItem = item
		end
	end
	if not selectedItem then
		selectedId = nil
	end
	if sellMode then
		self:ShowSellPanel(data)
	else
		self:ShowDetail(selectedItem)
	end
end

-- Open the backpack with one item selected (used by the hotbar)
function Inventory:OpenWith(itemId: string?)
	sellMode = false
	selectedId = itemId
	filterIndex = 0
	if window.IsOpen then
		self:Refresh()
	else
		window:Open()
	end
end

function Inventory:Init(all)
	controllers = all
	self:BuildWindow()
	window.Opened:Connect(function()
		self:Refresh()
	end)
end

function Inventory:Start()
	controllers.State.Changed:Connect(function()
		self:Refresh()
	end)
end

return Inventory
