--[[
	HotbarController
	The compact inventory taskbar at the bottom of the screen (replaces Roblox's default backpack bar):

	  [1 📡 Detector] | [2..9] newest treasures (icon, xN, rarity border, NEW) | [🎒 7/10]

	  * 1 (or L1 on a gamepad, or tapping) takes the detector out / puts it away
	  * the shovel is PASSIVE equipment: it has no slot and is never held by hand - it appears in
	    your hands only while you dig (DigController equips it, then gives the detector back)
	  * 2-9 (or tap) select a treasure slot -> you HOLD that treasure and a card shows its name,
	    price and Luck (selling and displaying happen at base); select it again to put it away
	  * treasures you just dug up fly into their slot and the capacity counter bumps
	  * the backpack button turns red when full (10/10) and a ribbon offers a trip back to base
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Equipment = require(Shared.Config.Equipment)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Viewport = require(script.Parent.Parent.UI.Viewport)
local GameMath = require(Shared.GameMath)

local Hotbar = {}

local player = Players.LocalPlayer
local controllers
local ui = {} :: any
local slotFrames: { [number]: any } = {}
local groups: { any } = {}
local seenItems: { [string]: boolean } = {}
local newTreasures: { [string]: boolean } = {}
local selectedGroup: string? = nil
local equipPending = 0 -- os.clock() of the last "hold this treasure" request (tools swap meanwhile)
local firstState = true
local SLOT = 58
local TREASURE_SLOTS = if UIKit.IsTouch() then 5 else 8

---------------------------------------------------------------------------
-- Tools
---------------------------------------------------------------------------
local function findTool(attribute: string): Tool?
	for _, container in { player.Character, player:FindFirstChildOfClass("Backpack") } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute(attribute) then
					return child
				end
			end
		end
	end
	return nil
end

function Hotbar:Held(): string?
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	if tool and tool:GetAttribute("IsDetector") then
		return "Detector"
	elseif tool and tool:GetAttribute("IsShovel") then
		return "Shovel"
	elseif tool and tool:GetAttribute("IsTreasure") then
		return "Treasure"
	end
	return nil
end

local function bestOf(group)
	local best = group.Items[1]
	for _, item in group.Items do
		if item.Value > best.Value then
			best = item
		end
	end
	return best
end

local function heldTreasureTool(): Tool?
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return if tool and tool:GetAttribute("IsTreasure") then tool else nil
end

-- Equip "Detector" / "Shovel"; equipping the held one again puts it away.
-- ("Shovel" is only used by DigController while a dig is running - players never pick it.)
function Hotbar:Equip(kind: string, forceOn: boolean?)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if self:Held() == kind then
		if not forceOn then
			humanoid:UnequipTools()
		end
		return
	end
	local tool = findTool(if kind == "Detector" then "IsDetector" else "IsShovel")
	if tool then
		humanoid:EquipTool(tool)
	end
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function makeSlot(parent: Instance, order: number, keyText: string?): any
	local button = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.12,
		Size = UDim2.fromOffset(SLOT, SLOT),
		LayoutOrder = order,
		Parent = parent,
	}, { UIKit.Corner(12), UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 200, 215)) })
	local stroke = UIKit.Stroke(Theme.Colors.Stroke, 2, 0.6)
	stroke.Parent = button
	local icon = UIKit.new("Frame", { Name = "Icon", BackgroundTransparency = 1, Position = UDim2.fromOffset(4, 3), Size = UDim2.new(1, -8, 1, -8), Parent = button })
	local emoji = UIKit.Text({ Text = "", TextSize = 28, Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = icon })
	local key = UIKit.Text({
		Text = keyText or "",
		Font = Theme.Fonts.Bold,
		TextSize = 11,
		TextColor3 = Theme.Colors.SubText,
		Position = UDim2.fromOffset(5, 2),
		Size = UDim2.fromOffset(14, 12),
		Visible = not UIKit.IsTouch() and keyText ~= nil,
		ZIndex = 3,
		Parent = button,
	})
	local count = UIKit.Text({
		Text = "",
		Font = Theme.Fonts.Number,
		TextSize = 15,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -4, 1, -1),
		Size = UDim2.fromOffset(40, 16),
		TextXAlignment = Enum.TextXAlignment.Right,
		ZIndex = 3,
		Parent = button,
	})
	UIKit.TextStroke(0.3).Parent = count
	local badge = UIKit.new("TextLabel", {
		Text = "NEW",
		Font = Theme.Fonts.Title,
		TextSize = 10,
		TextColor3 = Color3.fromRGB(40, 30, 0),
		BackgroundColor3 = Theme.Colors.Gold,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 4, 0, -6),
		Size = UDim2.fromOffset(30, 14),
		Visible = false,
		ZIndex = 4,
		Parent = button,
	}, { UIKit.Corner(6) })
	local label = UIKit.Text({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 10,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, 0, 0, 12),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 3,
		Parent = button,
	})
	UIKit.TextStroke(0.4).Parent = label
	return { Button = button, Stroke = stroke, Icon = icon, Emoji = emoji, Key = key, Count = count, Badge = badge, Label = label, TreasureId = nil }
end

function Hotbar:BuildUI()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)

	local bar = UIKit.new("Frame", {
		Name = "Hotbar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -8),
		Size = UDim2.fromOffset(0, SLOT + 14),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.35,
		Parent = UIKit.Screen,
	}, {
		UIKit.Corner(18),
		UIKit.Stroke(Theme.Colors.Stroke, 1.5, 0.75),
	})
	UIKit.AddScale(bar)
	ui.Bar = bar
	-- the slot row has its own list layout, so the card / ribbon parented to the bar keep their positions
	local row = UIKit.new("Frame", {
		Name = "Slots",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(0, SLOT + 14),
		AutomaticSize = Enum.AutomaticSize.X,
		Parent = bar,
	}, {
		UIKit.Padding(7, 8),
		UIKit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})

	-- tool slots
	ui.Detector = makeSlot(row, 1, "1")
	ui.Detector.Emoji.Text = "📡"
	ui.Detector.Label.Text = "Detector"
	ui.Detector.Button.Activated:Connect(function()
		self:Equip("Detector", false)
	end)
	UIKit.new("Frame", { BackgroundColor3 = Theme.Colors.Stroke, BackgroundTransparency = 0.6, BorderSizePixel = 0, Size = UDim2.fromOffset(2, SLOT - 12), LayoutOrder = 3, Parent = row })

	for index = 1, TREASURE_SLOTS do
		local slot = makeSlot(row, 3 + index, tostring(index + 1))
		slot.Button.Activated:Connect(function()
			self:SelectSlot(index)
		end)
		slotFrames[index] = slot
	end

	-- backpack / capacity button
	local pack = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Teal,
		Size = UDim2.fromOffset(78, SLOT),
		LayoutOrder = 100,
		Parent = row,
		OnActivated = function()
			if UIKit.ClickSound then
				UIKit.ClickSound()
			end
			local window = UIKit.GetWindow("Inventory")
			if window then
				window:Toggle()
			end
		end,
	}, { UIKit.Corner(12), UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(185, 195, 210)), UIKit.Stroke(Color3.new(0, 0, 0), 1.5, 0.7) })
	ui.Pack = pack
	UIKit.Text({ Text = "🎒", TextSize = 22, Position = UDim2.fromOffset(0, 2), Size = UDim2.new(1, 0, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, Parent = pack })
	ui.PackCount = UIKit.Text({ Text = "0/10", Font = Theme.Fonts.Number, TextSize = 15, Position = UDim2.fromOffset(0, 27), Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, Parent = pack })
	UIKit.TextStroke(0.4).Parent = ui.PackCount
	ui.PackFill = UIKit.Bar({ Position = UDim2.new(0, 8, 1, -11), Size = UDim2.new(1, -16, 0, 6), Parent = pack }, Theme.Colors.Gold)

	-- "Backpack full" ribbon above the bar: one tap takes you home to sell / display
	ui.Full = UIKit.new("TextButton", {
		Text = "🎒 Backpack full (10/10)!  ⚓ Tap to return to the Pier",
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.Coral,
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -6),
		Size = UDim2.fromOffset(360, 24),
		Visible = false,
		Parent = bar,
		OnActivated = function()
			if controllers.World:IsAtBase() then
				-- already home: open the backpack (Quick Sell works here)
				controllers.Inventory:OpenWith(nil)
			else
				controllers.HUD:Teleport("Pier")
			end
		end,
	}, { UIKit.Corner(10), UIKit.Stroke(Color3.new(1, 1, 1), 1.5, 0.5) })

	-- Selected treasure card
	ui.Card = UIKit.new("Frame", {
		Name = "SlotCard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 0, -12),
		Size = UDim2.fromOffset(250, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 20,
		Parent = bar,
	}, { UIKit.Corner(14), UIKit.Padding(10), UIKit.List(nil, 5, Enum.HorizontalAlignment.Center) })
	ui.CardStroke = UIKit.Stroke(Theme.Colors.Stroke, 2.5, 0.1)
	ui.CardStroke.Parent = ui.Card
end

local function groupItems(data)
	local byId: { [string]: any } = {}
	local list = {}
	for _, item in data.Inventory do
		local def = Treasures.ById[item.TreasureId]
		if def then
			local group = byId[def.Id]
			if not group then
				group = { TreasureId = def.Id, Def = def, Items = {}, Newest = 0, Value = 0 }
				byId[def.Id] = group
				table.insert(list, group)
			end
			table.insert(group.Items, item)
			group.Newest = math.max(group.Newest, tonumber(item.Id) or 0)
			group.Value += item.Value
		end
	end
	-- newest first, so what you just dug is always in the first slot
	table.sort(list, function(a, b)
		return a.Newest > b.Newest
	end)
	return list
end

function Hotbar:Refresh(data)
	-- spot new items (everything already in the bag on join counts as seen)
	for _, item in data.Inventory do
		if not seenItems[item.Id] then
			seenItems[item.Id] = true
			if not firstState then
				newTreasures[item.TreasureId] = true
			end
		end
	end
	firstState = false

	groups = groupItems(data)
	for index, slot in slotFrames do
		local group = groups[index]
		if not group or slot.TreasureId ~= group.TreasureId then
			for _, child in slot.Icon:GetChildren() do
				if child:IsA("ViewportFrame") then
					child:Destroy()
				end
			end
		end
		if group then
			local color = UIKit.RarityColor(group.Def.Rarity)
			if slot.TreasureId ~= group.TreasureId or not slot.Icon:FindFirstChildOfClass("ViewportFrame") then
				Viewport.Create(group.TreasureId, { Tilt = 0.5 }).Parent = slot.Icon
			end
			slot.TreasureId = group.TreasureId
			slot.Count.Text = if #group.Items > 1 then "x" .. #group.Items else ""
			slot.Label.Text = ""
			slot.Stroke.Color = color
			slot.Stroke.Thickness = if selectedGroup == group.TreasureId then 4 else 2.5
			slot.Stroke.Transparency = 0
			slot.Badge.Visible = newTreasures[group.TreasureId] == true
			slot.Button.BackgroundColor3 = color:Lerp(Theme.Colors.PanelDark, 0.72)
		else
			slot.TreasureId = nil
			slot.Count.Text = ""
			slot.Label.Text = ""
			slot.Stroke.Color = Theme.Colors.Stroke
			slot.Stroke.Thickness = 1.5
			slot.Stroke.Transparency = 0.75
			slot.Badge.Visible = false
			slot.Button.BackgroundColor3 = Theme.Colors.Panel
		end
	end

	local used, capacity = #data.Inventory, data.Capacity
	ui.PackCount.Text = used .. "/" .. capacity
	ui.PackFill:Set(used / math.max(capacity, 1))
	local full = used >= capacity
	UIKit.SetButtonColor(ui.Pack, if full then Theme.Colors.Coral elseif used >= capacity * 0.8 then Theme.Colors.Orange else Theme.Colors.Teal)
	ui.Full.Visible = full and not ui.Card.Visible
	ui.FullCount = string.format("%d/%d", used, capacity)
	self:UpdateFullRibbon()
	if full and not ui.WasFull and ui.KnownCount ~= nil and used > ui.KnownCount then
		-- just filled up: say what to do (once)
		controllers.Notify:Toast("🎒 Your backpack is full! Return to the Pier to sell treasures or display them in your shop.", "Warning", 5)
		controllers.Sound:Play("Error")
	end
	ui.WasFull = full
	ui.KnownCount = used

	-- shovel slot shows the tier you own
	local detector = Equipment.ById.Detector[data.Equipment.Detector]
	ui.Detector.Label.Text = "Detector"
	if detector then
		ui.Detector.Button:SetAttribute("Tip", detector.Name)
	end

	if selectedGroup then
		local still = false
		for _, group in groups do
			if group.TreasureId == selectedGroup then
				still = true
				local tool = heldTreasureTool()
				local heldItem = nil
				for _, item in group.Items do
					if tool and item.Id == tool:GetAttribute("ItemId") then
						heldItem = item
					end
				end
				self:ShowCard(group, heldItem or bestOf(group))
			end
		end
		if not still then
			self:CloseCard()
		end
	end
end

function Hotbar:RefreshTools()
	local held = self:Held()
	for kind, slot in { Detector = ui.Detector } do
		local on = held == kind
		slot.Stroke.Color = if on then Theme.Colors.Gold else Theme.Colors.Stroke
		slot.Stroke.Thickness = if on then 3.5 else 2
		slot.Stroke.Transparency = if on then 0 else 0.5
		slot.Button.BackgroundColor3 = if on then Color3.fromRGB(70, 96, 60) else Theme.Colors.Panel
	end
end

function Hotbar:CloseCard(keepHeld: boolean?)
	selectedGroup = nil
	if not keepHeld then
		equipPending = 0
	end
	ui.Card.Visible = false
	ui.Full.Visible = ui.WasFull == true
	for _, slot in slotFrames do
		if slot.TreasureId then
			slot.Stroke.Thickness = 2.5
		end
	end
	if not keepHeld and heldTreasureTool() then
		task.spawn(function()
			controllers.State:Call("EquipItem", "Treasure", "")
		end)
	end
end

-- Held-treasure info card (sits right above the hotbar, connected to the selected slot).
-- Shows the item's real saved price and Luck (from the held tool once the server hands it over).
function Hotbar:ShowCard(group, item)
	local card = ui.Card
	for _, child in card:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local def = group.Def
	local tool = heldTreasureTool()
	local value = if tool and tool:GetAttribute("ItemId") == item.Id then tool:GetAttribute("Value") else item.Value
	local luck = if tool and tool:GetAttribute("ItemId") == item.Id then tool:GetAttribute("Luck") else GameMath.ItemDisplayLuck(item)
	ui.CardStroke.Color = UIKit.RarityColor(def.Rarity)
	local name = UIKit.Text({ Text = def.Name, Font = Theme.Fonts.Title, TextSize = 20, Size = UDim2.new(1, 0, 0, 24), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 1, Parent = card })
	UIKit.TextStroke(0.4).Parent = name
	UIKit.RarityLabel(def.Rarity, { TextSize = 13, Size = UDim2.new(1, 0, 0, 16), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = card })
	local stats = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 3, Parent = card }, {
		UIKit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	local price = UIKit.new("TextLabel", { Text = Format.Cash(value), Font = Theme.Fonts.Number, TextSize = 18, TextColor3 = Color3.fromRGB(60, 40, 0), BackgroundColor3 = Theme.Colors.Gold, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 1, Parent = stats }, { UIKit.Corner(8), UIKit.Padding(0, 10) })
	local luckChip = UIKit.new("TextLabel", { Text = Format.Luck(luck), Font = Theme.Fonts.Number, TextSize = 18, TextColor3 = Color3.fromRGB(10, 50, 20), BackgroundColor3 = Theme.Colors.Luck, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = stats }, { UIKit.Corner(8), UIKit.Padding(0, 10) })
	price.TextWrapped = false
	luckChip.TextWrapped = false
	UIKit.Text({ Text = (if #group.Items > 1 then "x" .. #group.Items .. " in backpack  ·  " else "") .. "Luck applies when displayed", TextSize = 11, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 4, Parent = card })
	UIKit.Text({ Text = "💰 Sell at the Sell Shop  ·  🏪 Display at your shop desk", TextSize = 11, TextColor3 = Theme.Colors.Gold, Size = UDim2.new(1, 0, 0, 14), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 5, Parent = card })
	local row = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 32), LayoutOrder = 6, Parent = card }, { UIKit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center) })
	UIKit.Button("🎒 Open backpack", Theme.Colors.Teal, function()
		self:CloseCard()
		controllers.Inventory:OpenWith(item.Id)
	end, { Size = UDim2.fromOffset(150, 30), TextSize = 14, Parent = row })
	card.Visible = true
	ui.Full.Visible = false
end

-- Selecting a treasure slot puts that treasure in your hand (and shows its price + Luck);
-- selecting it again puts it away.
function Hotbar:SelectSlot(index: number)
	local slot = slotFrames[index]
	local group = groups[index]
	if not slot or not group then
		return
	end
	newTreasures[group.TreasureId] = nil
	slot.Badge.Visible = false
	if selectedGroup == group.TreasureId then
		self:CloseCard()
		return
	end
	self:CloseCard(true)
	selectedGroup = group.TreasureId
	slot.Stroke.Thickness = 4
	local item = bestOf(group)
	self:ShowCard(group, item)
	controllers.Effects:Pop(slot.Button, 1.12)
	-- the server swaps the old tool for the new one: the card must survive that moment
	local requested = os.clock()
	equipPending = requested
	task.spawn(function()
		local result = controllers.State:Call("EquipItem", "Treasure", item.Id)
		if equipPending ~= requested then
			return -- a newer request took over
		end
		if not result or not result.Ok then
			equipPending = 0
			if selectedGroup == group.TreasureId then
				self:CloseCard(true)
			end
			return
		end
		-- give the tool a moment to replicate, then make sure the card matches what's in hand
		task.wait(0.8)
		if equipPending == requested then
			equipPending = 0
			if selectedGroup and not heldTreasureTool() then
				self:CloseCard(true)
			end
		end
	end)
end

-- The "Backpack full" ribbon says what to do from where you stand: go home, or sell / display at base
function Hotbar:UpdateFullRibbon()
	if not ui.Full or not ui.Full.Visible then
		return
	end
	local count = ui.FullCount or "10/10"
	ui.Full.Text = if controllers.World:IsAtBase()
		then string.format("🎒 Backpack full (%s)!  💰 Sell or 🏪 display them · tap to open", count)
		else string.format("🎒 Backpack full (%s)!  ⚓ Tap to return to the Pier", count)
end

-- Screen position (pixels, top-left origin of the BeachUI ScreenGui) of the slot for a treasure
function Hotbar:SlotPosition(treasureId: string?): Vector2
	for _, slot in slotFrames do
		if slot.TreasureId == treasureId then
			return slot.Button.AbsolutePosition + slot.Button.AbsoluteSize / 2
		end
	end
	local first = slotFrames[1]
	if first then
		return first.Button.AbsolutePosition + first.Button.AbsoluteSize / 2
	end
	return ui.Pack.AbsolutePosition + ui.Pack.AbsoluteSize / 2
end

-- Item collection animation: an icon flies from `from` (screen pixels) into its hotbar slot
function Hotbar:FlyIn(treasureId: string, from: Vector2?)
	local def = Treasures.ById[treasureId]
	if not def then
		return
	end
	local camera = Workspace.CurrentCamera
	local start = from or (if camera then camera.ViewportSize / 2 else Vector2.new(640, 360))
	local size = 64
	local flyer = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(start.X, start.Y),
		Size = UDim2.fromOffset(size, size),
		BackgroundColor3 = UIKit.RarityColor(def.Rarity):Lerp(Theme.Colors.PanelDark, 0.5),
		ZIndex = 60,
		Parent = UIKit.Screen,
	}, { UIKit.Corner(14), UIKit.Stroke(UIKit.RarityColor(def.Rarity), 3, 0) })
	Viewport.Create(def.Id).Parent = flyer
	local reduced = controllers.Effects:Reduced()
	task.defer(function()
		local target = self:SlotPosition(treasureId)
		local duration = if reduced then 0.2 else 0.55
		UIKit.Tween(flyer, duration, { Position = UDim2.fromOffset(target.X, target.Y), Size = UDim2.fromOffset(SLOT * UIKit.ScaleValue, SLOT * UIKit.ScaleValue) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		task.wait(duration)
		flyer:Destroy()
		for _, slot in slotFrames do
			if slot.TreasureId == treasureId then
				controllers.Effects:Pop(slot.Button, 1.3)
			end
		end
		controllers.Effects:Pop(ui.Pack, 1.2)
		controllers.Sound:Play("Click", 1.5, 0.7)
	end)
end

function Hotbar:Init(all)
	controllers = all
	self:BuildUI()
end

function Hotbar:Start()
	controllers.State:OnChange(function(data)
		self:Refresh(data)
	end)
	-- keep the full-backpack ribbon's advice in step with where the player is
	task.spawn(function()
		while true do
			task.wait(0.5)
			self:UpdateFullRibbon()
		end
	end)

	-- Number keys (Roblox's default backpack is hidden, so we handle them)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed or UserInputService:GetFocusedTextBox() then
			return
		end
		local key = input.KeyCode
		local slotKeys = { Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five, Enum.KeyCode.Six, Enum.KeyCode.Seven, Enum.KeyCode.Eight, Enum.KeyCode.Nine }
		local slotIndex = table.find(slotKeys, key)
		if key == Enum.KeyCode.One then
			self:Equip("Detector", false)
		elseif slotIndex and slotIndex <= TREASURE_SLOTS then
			self:SelectSlot(slotIndex)
		elseif key == Enum.KeyCode.ButtonL1 then
			self:Equip("Detector", true)
		end
	end)
	ContextActionService:BindActionAtPriority("BeachCloseSlotCard", function(_, state)
		if state == Enum.UserInputState.Begin and selectedGroup then
			self:CloseCard()
			return Enum.ContextActionResult.Sink
		end
		return Enum.ContextActionResult.Pass
	end, false, 3000, Enum.KeyCode.Escape)

	local function watch(character: Model)
		character.ChildAdded:Connect(function(child)
			self:RefreshTools()
			if child:IsA("Tool") and child:GetAttribute("IsTreasure") then
				-- the card always follows what's really in your hand
				local treasureId = child:GetAttribute("TreasureId")
				if type(treasureId) == "string" and selectedGroup ~= treasureId then
					selectedGroup = treasureId
				end
				local data = controllers.State.Data
				if data then
					self:Refresh(data) -- re-draw the card with the tool's real values
				end
			end
		end)
		character.ChildRemoved:Connect(function(child)
			self:RefreshTools()
			if child:IsA("Tool") and child:GetAttribute("IsTreasure") then
				task.defer(function()
					-- (ignored while a swap to another treasure is on its way)
					if not heldTreasureTool() and selectedGroup and os.clock() - equipPending > 1.5 then
						self:CloseCard(true) -- you put it away (or switched to the detector/shovel)
					end
				end)
			end
		end)
		self:RefreshTools()
	end
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)

	-- opening the backpack clears "NEW" badges
	local window = UIKit.GetWindow("Inventory")
	if window then
		window.Opened:Connect(function()
			table.clear(newTreasures)
			local data = controllers.State.Data
			if data then
				self:Refresh(data)
			end
		end)
	end
end

-- Keep Rarities referenced for type-checking of rarity names used above
Hotbar.Rarities = Rarities

return Hotbar
