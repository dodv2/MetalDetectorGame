--[[
	PersonalShopService
	Every player gets a shop plot (Workspace > Map > ShopPlots > PlotN) while they're in the server.
	Displayed treasures are saved in data.Shop.Displays["<slot>"] and rebuilt when they join.

	Each plot contains:
	  Slots    invisible anchor parts Slot01..Slot48 (attributes SlotIndex, SlotType, ShopLevel) holding the
	           display furniture (pedestal / glass case / shelf / wall plaque). Furniture is ONLY visible
	           while a treasure stands on it - empty and locked slots are completely invisible.
	  Upgrades decor with a ShopLevel attribute; it appears once the owner's shop reaches that level
	  Desk     the "Manage Shop" desk inside the door (the owner's prompt is added by the client)
	  Sign     shows the shop name, Shop Luck and collection value
	  Entrance where the 🏪 Shop button teleports you
	  Parts with a ThemeRole attribute (Floor/Wall/Trim/Furniture) are recoloured by the shop theme.

	Managing a shop (displaying, removing, moving, Place Best Items, upgrades, themes) only works
	while you stand in YOUR OWN shop - checked here on the server. Visitors simply walk in.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local GameMath = require(Shared.GameMath)
local Format = require(Shared.Format)
local TreasureModels = require(Shared.TreasureModels)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local PersonalShopService = {}

local services
local plots: { Model } = {}
local plotOwner: { [Model]: Player } = {}
local playerPlot: { [Player]: Model } = {}

local MAX_SLOTS = 48
local DISPLAY_SIZE = { Shelf = 1.7, Case = 1.9, Pedestal = 2.6, Wall = 2.2 }

local function fail(message: string)
	return { Ok = false, Error = message }
end

local function notHere()
	return fail("🏪 Manage your displays and upgrades inside your own Treasure Shop (use the 🏪 Shop button).")
end

local function getSlot(plot: Model, index: number): BasePart?
	local slots = plot:FindFirstChild("Slots")
	return slots and slots:FindFirstChild(string.format("Slot%02d", index)) :: BasePart?
end

local function getDisplaysFolder(plot: Model): Folder
	local folder = plot:FindFirstChild("Displays") :: Folder?
	if not folder then
		local created = Instance.new("Folder")
		created.Name = "Displays"
		created.Parent = plot
		return created
	end
	return folder :: Folder
end

-- Show / hide a piece of shop furniture or decor completely (no "ghost" shelves)
local function setVisible(root: Instance, visible: boolean)
	local function apply(object: Instance)
		if object:IsA("BasePart") then
			local base = object:GetAttribute("BaseTransparency")
			if base == nil then
				base = object.Transparency
				object:SetAttribute("BaseTransparency", base)
			end
			object.Transparency = if visible then base else 1
			object.CanCollide = visible and object:GetAttribute("BaseCollide") ~= false
		elseif object:IsA("Light") or object:IsA("SurfaceGui") or object:IsA("BillboardGui") or object:IsA("ParticleEmitter") then
			(object :: any).Enabled = visible
		elseif object:IsA("Decal") then
			object.Transparency = if visible then 0 else 1
		end
	end
	apply(root)
	for _, child in root:GetDescendants() do
		apply(child)
	end
end

---------------------------------------------------------------------------
-- Rendering
---------------------------------------------------------------------------
function PersonalShopService:RenderSlot(plot: Model, index: number, item)
	local folder = getDisplaysFolder(plot)
	local existing = folder:FindFirstChild("Display" .. index)
	if existing then
		existing:Destroy()
	end
	local slot = getSlot(plot, index)
	if slot then
		setVisible(slot, item ~= nil) -- the shelf/pedestal appears with its treasure
	end
	if not item then
		return
	end
	local def = Treasures.ById[item.TreasureId]
	if not slot or not def then
		return
	end

	local model = TreasureModels.Build(item.TreasureId)
	model.Name = "Display" .. index
	local slotType = slot:GetAttribute("SlotType") or "Pedestal"
	local size = model:GetExtentsSize()
	local target = DISPLAY_SIZE[slotType] or 2
	local largest = math.max(size.X, size.Y, size.Z, 0.1)
	model:ScaleTo(model:GetScale() * (target / largest))
	size = model:GetExtentsSize()

	-- Model is built around its origin; its "front" faces the slot's -Z (into the room)
	local pivot
	if slotType == "Wall" then
		pivot = slot.CFrame * CFrame.new(0, 0, -(slot.Size.Z / 2 + size.Z / 2 + 0.25))
	else
		pivot = slot.CFrame * CFrame.new(0, slot.Size.Y / 2 + size.Y / 2 + 0.15, 0)
	end
	model:PivotTo(pivot)

	local luck = GameMath.ItemDisplayLuck(item)
	model:SetAttribute("TreasureId", item.TreasureId)
	model:SetAttribute("Quality", item.Quality)
	model:SetAttribute("Value", item.Value)
	model:SetAttribute("Luck", luck)
	model:SetAttribute("SlotIndex", index)
	model:SetAttribute("SlotType", slotType)
	model:SetAttribute("Spin", slotType ~= "Wall")

	local rarity = Rarities.Info[def.Rarity]
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(180, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, size.Y / 2 + 1, 0)
	billboard.MaxDistance = 22
	billboard.LightInfluence = 0
	billboard.Parent = model.PrimaryPart

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.45, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.Text = def.Name
	nameLabel.Parent = billboard

	local infoLabel = Instance.new("TextLabel")
	infoLabel.Position = UDim2.new(0, 0, 0.5, 0)
	infoLabel.Size = UDim2.new(1, 0, 0.4, 0)
	infoLabel.BackgroundTransparency = 1
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextScaled = true
	infoLabel.TextColor3 = if rarity.Rainbow then Color3.fromRGB(255, 240, 160) else rarity.Color
	infoLabel.TextStrokeTransparency = 0.4
	infoLabel.Text = Rarities.Label(def.Rarity) .. "  •  🍀 " .. Format.Luck(luck)
	infoLabel.Parent = billboard

	model.Parent = folder
end

-- Furniture shows only under a displayed treasure; decor shows once the shop level is reached
function PersonalShopService:RefreshSlots(plot: Model)
	local owner = plotOwner[plot]
	local data = owner and services.DataService:Get(owner)
	local unlocked = if data then GameMath.ShopSlots(data) else 0
	for index = 1, MAX_SLOTS do
		local slot = getSlot(plot, index)
		if slot then
			local occupied = data ~= nil and data.Shop.Displays[tostring(index)] ~= nil
			setVisible(slot, occupied and index <= unlocked)
		end
	end
	local level = if data then data.Shop.Level or 1 else 1
	local upgrades = plot:FindFirstChild("Upgrades")
	if upgrades then
		for _, child in upgrades:GetChildren() do
			local hideAt = child:GetAttribute("HideAtLevel")
			setVisible(child, (child:GetAttribute("ShopLevel") or 1) <= level and (hideAt == nil or level < hideAt))
		end
	end
end

function PersonalShopService:UpdateSign(plot: Model)
	local sign = plot:FindFirstChild("Sign") :: BasePart?
	if not sign then
		return
	end
	local gui = sign:FindFirstChild("SignGui") :: SurfaceGui?
	if not gui then
		local surface = Instance.new("SurfaceGui")
		surface.Name = "SignGui"
		surface.Face = Enum.NormalId.Front
		surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		surface.PixelsPerStud = 40
		surface.LightInfluence = 0
		surface.Parent = sign

		local title = Instance.new("TextLabel")
		title.Name = "Title"
		title.BackgroundTransparency = 1
		title.Size = UDim2.new(1, -40, 0.55, 0)
		title.Position = UDim2.new(0, 20, 0.05, 0)
		title.Font = Enum.Font.FredokaOne
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 244, 214)
		title.TextStrokeTransparency = 0.5
		title.Parent = surface

		local info = Instance.new("TextLabel")
		info.Name = "Info"
		info.BackgroundTransparency = 1
		info.Size = UDim2.new(1, -40, 0.32, 0)
		info.Position = UDim2.new(0, 20, 0.62, 0)
		info.Font = Enum.Font.GothamBold
		info.TextScaled = true
		info.TextColor3 = Color3.fromRGB(255, 220, 120)
		info.Parent = surface
		gui = surface
	end
	local surface = gui :: SurfaceGui
	local title = surface:FindFirstChild("Title") :: TextLabel
	local info = surface:FindFirstChild("Info") :: TextLabel
	local owner = plotOwner[plot]
	local data = owner and services.DataService:Get(owner)
	if owner and data then
		title.Text = if data.Shop.Name ~= "" then data.Shop.Name else (owner.DisplayName .. "'s Treasure Shop")
		info.Text = string.format("🍀 Shop %s   💎 %s   🏺 %d/%d",
			Format.Luck(GameMath.ShopLuck(data.Shop.Displays)),
			Format.Cash(GameMath.ShopValue(data.Shop.Displays)),
			GameMath.CountDisplays(data.Shop.Displays),
			GameMath.ShopSlots(data))
	else
		title.Text = "Empty Shop Plot"
		info.Text = "Claimed automatically when a treasure hunter joins"
	end
end

function PersonalShopService:ApplyTheme(player: Player)
	local plot = playerPlot[player]
	local data = services.DataService:Get(player)
	if not plot then
		return
	end
	local theme = Equipment.ById.Theme[data and data.Shop.Theme or "BeachHut"] or Equipment.Themes[1]
	for _, part in plot:GetDescendants() do
		if part:IsA("BasePart") then
			local role = part:GetAttribute("ThemeRole")
			if role == "Floor" then
				part.Color = theme.Floor
				part.Material = (Enum.Material :: any)[theme.FloorMaterial]
			elseif role == "Wall" then
				part.Color = theme.Wall
				part.Material = (Enum.Material :: any)[theme.WallMaterial]
			elseif role == "Trim" then
				part.Color = theme.Trim
			elseif role == "Furniture" then
				part.Color = theme.Furniture
				part.Material = (Enum.Material :: any)[theme.FurnitureMaterial]
			end
		end
	end
end

function PersonalShopService:RenderAll(player: Player)
	local plot = playerPlot[player]
	local data = services.DataService:Get(player)
	if not plot or not data then
		return
	end
	getDisplaysFolder(plot):ClearAllChildren()
	for key, item in data.Shop.Displays do
		local index = tonumber(key)
		if index then
			self:RenderSlot(plot, index, item)
		end
	end
	self:RefreshSlots(plot)
	self:ApplyTheme(player)
	self:UpdateSign(plot)
end

---------------------------------------------------------------------------
-- Plot ownership
---------------------------------------------------------------------------
function PersonalShopService:AssignPlot(player: Player)
	for _, plot in plots do
		if not plotOwner[plot] then
			plotOwner[plot] = player
			playerPlot[player] = plot
			plot:SetAttribute("OwnerUserId", player.UserId)
			plot:SetAttribute("OwnerName", player.DisplayName)
			self:RenderAll(player)
			return plot
		end
	end
	services.StateService:Notify(player, "All shop plots are taken in this server - your displays are saved and will appear next time.", "Warning")
	return nil
end

function PersonalShopService:ReleasePlot(player: Player)
	local plot = playerPlot[player]
	if not plot then
		return
	end
	playerPlot[player] = nil
	plotOwner[plot] = nil
	plot:SetAttribute("OwnerUserId", 0)
	plot:SetAttribute("OwnerName", "")
	getDisplaysFolder(plot):ClearAllChildren()
	for _, part in plot:GetDescendants() do
		if part:IsA("BasePart") and part:GetAttribute("ThemeRole") then
			local role = part:GetAttribute("ThemeRole")
			local theme = Equipment.Themes[1]
			if role == "Floor" then
				part.Color = theme.Floor
			elseif role == "Wall" then
				part.Color = theme.Wall
			elseif role == "Trim" then
				part.Color = theme.Trim
			elseif role == "Furniture" then
				part.Color = theme.Furniture
			end
		end
	end
	self:RefreshSlots(plot)
	self:UpdateSign(plot)
end

function PersonalShopService:GetPlotIndex(player: Player): number?
	local plot = playerPlot[player]
	return if plot then plot:GetAttribute("PlotIndex") else nil
end

function PersonalShopService:GetEntrance(player: Player): CFrame?
	local plot = playerPlot[player]
	local entrance = plot and plot:FindFirstChild("Entrance") :: BasePart?
	return if entrance then entrance.CFrame else nil
end

-- true while the player stands inside (or right outside the door of) their own shop plot
function PersonalShopService:IsAtOwnShop(player: Player): boolean
	local plot = playerPlot[player]
	local floor = plot and plot:FindFirstChild("Floor") :: BasePart?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not floor or not root then
		return false
	end
	local relative = (floor :: BasePart).CFrame:PointToObjectSpace((root :: BasePart).Position)
	local half = (floor :: BasePart).Size / 2
	return math.abs(relative.X) <= half.X + 6 and relative.Z >= -half.Z - 14 and relative.Z <= half.Z + 4 and math.abs(relative.Y) <= 30
end

function PersonalShopService:HasFreeSlot(player: Player): boolean
	local data = services.DataService:Get(player)
	return data ~= nil and playerPlot[player] ~= nil and GameMath.CountDisplays(data.Shop.Displays) < GameMath.ShopSlots(data)
end

local function firstFreeSlot(data): number?
	for index = 1, GameMath.ShopSlots(data) do
		if data.Shop.Displays[tostring(index)] == nil then
			return index
		end
	end
	return nil
end

local function afterDisplayChange(player: Player)
	local plot = playerPlot[player]
	if plot then
		PersonalShopService:UpdateSign(plot)
	end
	services.AchievementService:Check(player)
	services.DataService:MarkDirty(player)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
function PersonalShopService:Display(player: Player, itemId: string, slotIndex: number?)
	local data = services.DataService:Get(player)
	local plot = playerPlot[player]
	if not data or not plot then
		return fail("You don't have a shop plot in this server")
	end
	local slots = GameMath.ShopSlots(data)
	local index = slotIndex or firstFreeSlot(data)
	if not index then
		return fail("Your shop is full! Expand it or remove a display.")
	end
	if index < 1 or index > slots then
		return fail("That slot is locked - expand your shop to use it")
	end
	local _, item = services.InventoryService:FindItem(data, itemId)
	if not item then
		return fail("Item not found")
	end
	local key = tostring(index)
	local previous = data.Shop.Displays[key]
	services.InventoryService:RemoveItem(player, itemId)
	if previous then
		table.insert(data.Inventory, previous) -- swap: old display goes back to the backpack
	end
	data.Shop.Displays[key] = item
	self:RenderSlot(plot, index, item)
	services.QuestService:Progress(player, "Display", 1)
	afterDisplayChange(player)
	return { Ok = true, Slot = index }
end

function PersonalShopService:RemoveDisplay(player: Player, slotIndex: number)
	local data = services.DataService:Get(player)
	local plot = playerPlot[player]
	if not data or not plot then
		return fail("No shop plot")
	end
	local key = tostring(slotIndex)
	local item = data.Shop.Displays[key]
	if not item then
		return fail("That slot is empty")
	end
	if services.InventoryService:IsFull(data) then
		return fail("Your backpack is full")
	end
	data.Shop.Displays[key] = nil
	table.insert(data.Inventory, item)
	self:RenderSlot(plot, slotIndex, nil)
	afterDisplayChange(player)
	return { Ok = true }
end

function PersonalShopService:MoveDisplay(player: Player, fromIndex: number, toIndex: number)
	local data = services.DataService:Get(player)
	local plot = playerPlot[player]
	if not data or not plot then
		return fail("No shop plot")
	end
	local slots = GameMath.ShopSlots(data)
	if fromIndex > slots or toIndex > slots then
		return fail("That slot is locked")
	end
	local displays = data.Shop.Displays
	local a, b = displays[tostring(fromIndex)], displays[tostring(toIndex)]
	if not a then
		return fail("Nothing to move")
	end
	displays[tostring(fromIndex)], displays[tostring(toIndex)] = b, a
	self:RenderSlot(plot, fromIndex, b)
	self:RenderSlot(plot, toIndex, a)
	afterDisplayChange(player)
	return { Ok = true }
end

-- Place Best Items. mode "Preview" returns what would change; "Confirm" applies it, but only if
-- the plan still matches the preview the player saw (signature) - otherwise a fresh preview is sent.
local function describe(item, slot: number?)
	local def = Treasures.ById[item.TreasureId]
	return {
		Id = item.Id,
		TreasureId = item.TreasureId,
		Name = if def then def.Name else "?",
		Rarity = if def then def.Rarity else "Common",
		Value = item.Value,
		Luck = GameMath.ItemDisplayLuck(item),
		Slot = slot,
	}
end

local function previewOf(plan)
	local view = { Add = {}, Return = {}, LuckBefore = plan.LuckBefore, LuckAfter = plan.LuckAfter, Signature = plan.Signature }
	for _, add in plan.Add do
		local entry = describe(add.Item, add.Slot)
		entry.Replaces = if add.Replaces then describe(add.Replaces, add.Slot) else nil
		table.insert(view.Add, entry)
	end
	for _, ret in plan.Return do
		table.insert(view.Return, describe(ret.Item, ret.Slot))
	end
	return view
end

function PersonalShopService:AutoFill(player: Player, mode: string?, signature: string?)
	local data = services.DataService:Get(player)
	local plot = playerPlot[player]
	if not data or not plot then
		return fail("No shop plot")
	end
	local slots = GameMath.ShopSlots(data)
	local plan = GameMath.PlanBestDisplays(data.Inventory, data.Shop.Displays, slots)
	if #plan.Add == 0 then
		return fail(if #data.Inventory == 0 then "Your backpack is empty" else "Your shop already shows your best treasures! 🏆")
	end
	if mode ~= "Confirm" then
		return { Ok = true, Preview = previewOf(plan) }
	end
	if signature ~= plan.Signature then
		return { Ok = false, Changed = true, Error = "Your items changed - check the updated preview.", Preview = previewOf(plan) }
	end

	-- validate everything first, then move (no half-finished transfers)
	for _, add in plan.Add do
		if not services.InventoryService:FindItem(data, add.Item.Id) then
			return fail("Item not found")
		end
		if add.Replaces and data.Shop.Displays[tostring(add.Slot)] ~= add.Replaces then
			return fail("Your shop changed - try again")
		end
	end
	for _, add in plan.Add do
		services.InventoryService:RemoveItem(player, add.Item.Id)
		local key = tostring(add.Slot)
		local previous = data.Shop.Displays[key]
		if previous then
			table.insert(data.Inventory, previous) -- replaced display goes safely back to the backpack
		end
		data.Shop.Displays[key] = add.Item
		self:RenderSlot(plot, add.Slot, add.Item)
	end
	services.QuestService:Progress(player, "Display", #plan.Add)
	afterDisplayChange(player)
	return { Ok = true, Count = #plan.Add, Returned = #plan.Return, LuckBefore = plan.LuckBefore, LuckAfter = plan.LuckAfter }
end

function PersonalShopService:Expand(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return fail("Not loaded")
	end
	local nextLevel = data.Shop.Level + 1
	local def = Equipment.ShopLevels[nextLevel]
	if not def then
		return fail("Your shop is already fully expanded!")
	end
	if data.Level < def.Level then
		return fail("Requires level " .. def.Level)
	end
	if not services.InventoryService:SpendCash(player, def.Price) then
		return fail("You need " .. Format.Cash(def.Price - data.Cash) .. " more")
	end
	data.Shop.Level = nextLevel
	local plot = playerPlot[player]
	if plot then
		self:RefreshSlots(plot)
		self:UpdateSign(plot)
	end
	services.StateService:Notify(player, "🏪 Upgraded to " .. def.Name .. "! " .. def.Slots .. " display slots · " .. (def.Unlocks or ""), "Success")
	services.DataService:MarkDirty(player)
	return { Ok = true }
end

-- Shop themes are bought and applied here, in your own shop
function PersonalShopService:Theme(player: Player, action: string, themeId: string)
	local data = services.DataService:Get(player)
	local def = Equipment.ById.Theme[themeId]
	if not data or not def then
		return fail("Unknown theme")
	end
	data.Owned.Theme = data.Owned.Theme or {}
	if action == "Buy" then
		if data.Owned.Theme[themeId] then
			return fail("You already own " .. def.Name)
		end
		if data.Level < def.Level then
			return fail("Requires level " .. def.Level)
		end
		if not services.InventoryService:SpendCash(player, def.Price) then
			return fail("You need " .. Format.Cash(def.Price - data.Cash) .. " more")
		end
		data.Owned.Theme[themeId] = true
		services.StateService:Notify(player, "🎨 " .. def.Name .. " theme bought and applied to your shop!", "Success")
	elseif not data.Owned.Theme[themeId] then
		return fail("You don't own that theme yet")
	end
	data.Shop.Theme = themeId
	self:ApplyTheme(player)
	services.DataService:MarkDirty(player)
	return { Ok = true }
end

function PersonalShopService:SetName(player: Player, text: string)
	local data = services.DataService:Get(player)
	if not data then
		return fail("Not loaded")
	end
	text = string.sub((string.gsub(text, "[%c]", "")), 1, 30)
	if text == "" then
		data.Shop.Name = ""
	else
		local ok, filtered = pcall(function()
			local result = TextService:FilterStringAsync(text, player.UserId, Enum.TextFilterContext.PublicChat)
			return result:GetNonChatStringForBroadcastAsync()
		end)
		if not ok then
			return fail("Couldn't check that name right now. Try again.")
		end
		data.Shop.Name = filtered
	end
	local plot = playerPlot[player]
	if plot then
		self:UpdateSign(plot)
	end
	services.DataService:MarkDirty(player)
	return { Ok = true, Name = data.Shop.Name }
end

---------------------------------------------------------------------------
function PersonalShopService:Init(allServices)
	services = allServices
end

function PersonalShopService:Start()
	local map = Workspace:WaitForChild("Map")
	local plotsFolder = map:WaitForChild("ShopPlots")
	for _, child in plotsFolder:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotIndex") then
			table.insert(plots, child)
		end
	end
	table.sort(plots, function(a, b)
		return (a:GetAttribute("PlotIndex") :: number) < (b:GetAttribute("PlotIndex") :: number)
	end)
	for _, plot in plots do
		plot:SetAttribute("OwnerUserId", 0)
		for _, part in plot:GetDescendants() do
			if part:IsA("BasePart") then
				part:SetAttribute("BaseTransparency", part.Transparency)
				part:SetAttribute("BaseCollide", part.CanCollide)
			end
		end
		self:RefreshSlots(plot)
		self:UpdateSign(plot)
	end

	services.DataService.ProfileLoaded:Connect(function(player)
		self:AssignPlot(player)
		services.DataService:MarkDirty(player)
	end)
	for _, player in services.DataService:GetLoadedPlayers() do
		if not playerPlot[player] then
			self:AssignPlot(player)
		end
	end
	services.DataService.ProfileReleasing:Connect(function(player)
		self:ReleasePlot(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		self:ReleasePlot(player)
	end)

	local function slotArg(value)
		return RemoteGuard.IsInteger(value, 1, MAX_SLOTS)
	end

	RemoteGuard.Handle("DisplayItem", 0.15, function(player, itemId, slotIndex)
		if not self:IsAtOwnShop(player) then
			return notHere()
		end
		if not RemoteGuard.IsString(itemId, 16) or (slotIndex ~= nil and not slotArg(slotIndex)) then
			return fail("Bad request")
		end
		return self:Display(player, itemId, slotIndex)
	end)
	RemoteGuard.Handle("RemoveDisplay", 0.15, function(player, slotIndex)
		if not self:IsAtOwnShop(player) then
			return notHere()
		end
		if not slotArg(slotIndex) then
			return fail("Bad slot")
		end
		return self:RemoveDisplay(player, slotIndex)
	end)
	RemoteGuard.Handle("MoveDisplay", 0.15, function(player, fromIndex, toIndex)
		if not self:IsAtOwnShop(player) then
			return notHere()
		end
		if not slotArg(fromIndex) or not slotArg(toIndex) or fromIndex == toIndex then
			return fail("Bad slot")
		end
		return self:MoveDisplay(player, fromIndex, toIndex)
	end)
	RemoteGuard.Handle("AutoFillShop", 0.5, function(player, mode, signature)
		if not self:IsAtOwnShop(player) then
			return notHere()
		end
		if mode ~= nil and mode ~= "Preview" and mode ~= "Confirm" then
			return fail("Bad request")
		end
		if signature ~= nil and not RemoteGuard.IsString(signature, 4000) then
			return fail("Bad request")
		end
		return self:AutoFill(player, mode, signature)
	end)
	RemoteGuard.Handle("ExpandShop", 0.5, function(player)
		if not self:IsAtOwnShop(player) then
			return notHere()
		end
		return self:Expand(player)
	end)
	RemoteGuard.Handle("SetShopName", 3, function(player, text)
		if type(text) ~= "string" or #text > 60 then
			return fail("Bad name")
		end
		return self:SetName(player, text)
	end)
	RemoteGuard.Handle("ShopTheme", 0.4, function(player, action, themeId)
		if (action ~= "Buy" and action ~= "Equip") or not RemoteGuard.IsString(themeId, 40) then
			return fail("Bad request")
		end
		if not self:IsAtOwnShop(player) then
			return notHere()
		end
		return self:Theme(player, action, themeId)
	end)
end

return PersonalShopService
