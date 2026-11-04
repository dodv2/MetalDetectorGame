--[[
	HUDController
	Always-on screen info: cash, level + XP bar, Luck, active boost, current zone,
	the event banner, and the navigation buttons (Menu, 🏠 Base, 🏪 Shop).
	Menus open only by clicking/tapping - there are no keyboard shortcuts for menus or teleports,
	so nothing opens by accident. Teleports have no cooldown (only blocked while digging).
]]

local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Zones = require(Shared.Config.Zones)
local Events = require(Shared.Config.Events)
local Equipment = require(Shared.Config.Equipment)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local HUD = {}

local controllers
local ui = {} :: any

-- One expandable navigation menu: window name, label, icon.
-- (The Equipment Shop and Sell Shop are physical NPC shops at the base, so they're not here.)
-- (Backpack lives on the hotbar's 🎒 button; your treasure shop has its own 🏪 teleport button
--  and is managed at the desk inside it.)
local MENU = {
	{ Window = "Index", Label = "Collection Index", Icon = "📖" },
	{ Window = "Luck", Label = "Equipment & Luck", Icon = "🧰" },
	{ Window = "Quests", Label = "Quests & Achievements", Icon = "📜" },
	{ Window = "Travel", Label = "Travel", Icon = "🧭" },
	{ Window = "Settings", Label = "Settings", Icon = "⚙" },
}

-- The stats bar sits INSIDE Roblox's top bar row (the free space between Roblox's own buttons),
-- flush with the top of the screen. ScreenInsets.TopbarSafeInsets gives exactly that area on every
-- device (desktop, phones with notches, consoles); the bar scales down to fit narrow screens.
local function makeTopbarGui(): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = "BeachTopBar"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5
	local ok = pcall(function()
		(gui :: any).ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
	end)
	if not ok then
		gui.IgnoreGuiInset = true
	end
	gui:SetAttribute("TopbarInsets", ok)
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	return gui
end

function HUD:BuildStats()
	local topbar = makeTopbarGui()
	ui.TopBar = topbar
	local usesInsets = topbar:GetAttribute("TopbarInsets") == true
	local panel = UIKit.new("Frame", {
		Name = "Stats",
		AnchorPoint = if usesInsets then Vector2.new(0.5, 0.5) else Vector2.new(0.5, 0),
		Position = if usesInsets then UDim2.fromScale(0.5, 0.5) else UDim2.new(0.5, 0, 0, 6),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.1,
		Parent = topbar,
	}, {
		UIKit.Corner(14),
		UIKit.Stroke(Theme.Colors.Stroke, 1.5, 0.6),
		UIKit.Padding(4, 14),
		UIKit.List(Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	ui.StatsPanel = panel
	-- fit the bar to the top bar's height and the free width between Roblox's buttons
	local fit = Instance.new("UIScale")
	fit.Parent = panel
	ui.StatsFit = fit
	local function refit()
		local area = topbar.AbsoluteSize
		local natural = panel.AbsoluteSize / math.max(fit.Scale, 0.01)
		if natural.X < 1 or area.X < 1 then
			return
		end
		local byHeight = if usesInsets then (area.Y - 8) / 44 else 1
		local byWidth = (area.X - 16) / natural.X
		fit.Scale = math.clamp(math.min(byHeight, byWidth, 1.15), 0.5, 1.15)
	end
	topbar:GetPropertyChangedSignal("AbsoluteSize"):Connect(refit)
	panel:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		task.defer(refit)
	end)
	task.defer(refit)

	ui.Cash = UIKit.Text({
		Text = "💰 $0",
		Font = Theme.Fonts.Number,
		TextSize = 26,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		LayoutOrder = 1,
		Parent = panel,
	})
	UIKit.TextStroke(0.4).Parent = ui.Cash

	local levelRow = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(250, 28), LayoutOrder = 2, Parent = panel })
	ui.Level = UIKit.new("TextLabel", {
		Text = "Lv 1",
		Font = Theme.Fonts.Number,
		TextSize = 18,
		TextColor3 = Color3.fromRGB(20, 30, 50),
		BackgroundColor3 = Theme.Colors.XP,
		Size = UDim2.fromOffset(60, 28),
		Parent = levelRow,
	}, { UIKit.Corner(8) })
	ui.XPBar = UIKit.Bar({ Position = UDim2.fromOffset(66, 4), Size = UDim2.new(1, -66, 0, 20), Parent = levelRow }, Theme.Colors.XP)

	ui.CashValue = Instance.new("NumberValue")
	ui.CashValue.Value = 0
	ui.CashValue.Changed:Connect(function(value)
		ui.Cash.Text = "💰 " .. Format.Cash(math.floor(value + 0.5))
	end)

	ui.LuckButton = UIKit.Button("🍀 +0 Luck", Theme.Colors.Green, function()
		self:OpenWindow("Luck")
	end, {
		Size = UDim2.fromOffset(150, 34),
		TextSize = 17,
		LayoutOrder = 4,
		Parent = panel,
	})

	-- Health (Update 17): sharks bite. A heart + bar that drains (with a pale "just lost" ghost)
	-- and flashes when you're hurt; the Roblox health bar is hidden so there's only one.
	local healthRow = UIKit.new("Frame", { Name = "Health", BackgroundTransparency = 1, Size = UDim2.fromOffset(128, 28), LayoutOrder = 3, Parent = panel })
	ui.Heart = UIKit.Text({ Text = "❤", TextSize = 20, TextColor3 = Theme.Colors.Coral, Size = UDim2.fromOffset(24, 28), TextXAlignment = Enum.TextXAlignment.Center, Parent = healthRow })
	ui.HealthBar = UIKit.Bar({ Position = UDim2.fromOffset(26, 5), Size = UDim2.new(1, -26, 0, 18), Parent = healthRow }, Theme.Colors.Coral)
	ui.HealthGhost = UIKit.new("Frame", {
		Name = "Ghost",
		BackgroundColor3 = Color3.fromRGB(255, 220, 200),
		BackgroundTransparency = 0.2,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = ui.HealthBar.Frame,
	}, { UIKit.Round() })
	ui.HealthBar.Fill.ZIndex = 2

	ui.Zone = UIKit.Text({
		Text = "📍 The Pier",
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = Theme.Colors.SubText,
		Size = UDim2.fromOffset(0, 34),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		LayoutOrder = 5,
		Parent = panel,
	})

	-- Second line under the bar: active boost + Studio save warning
	local sub = UIKit.new("Frame", {
		Name = "SubStats",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 4),
		Size = UDim2.fromOffset(640, 18),
		BackgroundTransparency = 1,
		Parent = UIKit.Screen,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 12, Enum.HorizontalAlignment.Center) })
	UIKit.AddScale(sub)
	ui.Boost = UIKit.Text({
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 14,
		TextColor3 = Theme.Colors.Luck,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Visible = false,
		Parent = sub,
	})
	UIKit.TextStroke(0.4).Parent = ui.Boost
	ui.Goal = UIKit.new("TextButton", {
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 13,
		TextColor3 = Color3.new(1, 1, 1),
		AutoButtonColor = false,
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.25,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		LayoutOrder = 2,
		Parent = sub,
		OnActivated = function()
			self:OpenWindow("Luck")
		end,
	}, { UIKit.Corner(9), UIKit.Padding(0, 10) })
	UIKit.TextStroke(0.5).Parent = ui.Goal
	ui.SaveWarning = UIKit.Text({
		Text = "⚠ Studio test: progress is not being saved",
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = Theme.Colors.Orange,
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		Visible = false,
		Parent = sub,
	})
	UIKit.TextStroke(0.4).Parent = ui.SaveWarning
end

function HUD:OpenWindow(name: string, ...)
	local window = UIKit.GetWindow(name)
	if window then
		window:Toggle(...)
	end
end

function HUD:BuildMenu()
	-- Bottom-left on desktop (chat lives top-left); top-left under the Roblox buttons on touch screens
	local touch = UIKit.IsTouch()
	local holder = UIKit.new("Frame", {
		Name = "Navigation",
		AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.fromOffset(12, 8) else UDim2.new(0, 12, 1, -12),
		Size = UDim2.fromOffset(250, 60),
		BackgroundTransparency = 1,
		Parent = UIKit.Screen,
	})
	UIKit.AddScale(holder)

	local row = UIKit.new("Frame", {
		AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.fromScale(0, 0) else UDim2.fromScale(0, 1),
		Size = UDim2.fromOffset(190, 58),
		BackgroundTransparency = 1,
		Parent = holder,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 8) })

	local function squareButton(icon: string, label: string, color: Color3, order: number, onClick: () -> ())
		local button = UIKit.Button("", color, onClick, { Size = UDim2.fromOffset(58, 58), LayoutOrder = order, Parent = row })
		button.BackgroundTransparency = 0.08
		local iconLabel = UIKit.Text({ Name = "Icon", Text = icon, TextSize = 26, Size = UDim2.new(1, 0, 0, 32), Position = UDim2.fromOffset(0, 4), TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		button:SetAttribute("Icon", iconLabel.Name)
		UIKit.Text({ Text = label, Font = Theme.Fonts.Bold, TextSize = 11, Size = UDim2.new(1, 0, 0, 14), Position = UDim2.new(0, 0, 1, -18), TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		return button
	end

	ui.MenuButton = squareButton("", "Menu", Theme.Colors.Panel, 1, function()
		self:SetMenuOpen(not ui.MenuOpen)
	end)
	-- hamburger icon drawn with frames (the ☰ glyph isn't in Roblox's fonts)
	ui.MenuBars = UIKit.new("Frame", { Name = "Bars", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 11), Size = UDim2.fromOffset(24, 18), BackgroundTransparency = 1, Parent = ui.MenuButton }, {
		UIKit.List(nil, 5, Enum.HorizontalAlignment.Center),
	})
	for index = 1, 3 do
		UIKit.new("Frame", { Size = UDim2.fromOffset(24, 3), BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, LayoutOrder = index, Parent = ui.MenuBars }, { UIKit.Corner(2) })
	end
	ui.MenuBadge = UIKit.new("TextLabel", { Text = "!", Font = Theme.Fonts.Title, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), BackgroundColor3 = Theme.Colors.Coral, Size = UDim2.fromOffset(20, 20), Position = UDim2.new(1, -14, 0, -6), Visible = false, ZIndex = 5, Parent = ui.MenuButton }, { UIKit.Round() })

	-- 🏠 Return to Base (server-checked; no cooldown, blocked only while digging)
	ui.HomeButton = squareButton("⚓", "Pier", Theme.Colors.Teal, 2, function()
		self:ReturnToBase()
	end)

	-- 🏪 Treasure Shop teleport (to YOUR shop plot; same rules as Return to Base)
	ui.ShopButton = squareButton("🏪", "Shop", Theme.Colors.Purple, 3, function()
		self:Teleport("MyShop")
	end)

	-- the expandable list
	local list = UIKit.new("Frame", {
		Name = "MenuList",
		AnchorPoint = if touch then Vector2.new(0, 0) else Vector2.new(0, 1),
		Position = if touch then UDim2.fromOffset(0, 66) else UDim2.new(0, 0, 1, -66),
		Size = UDim2.fromOffset(262, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.06,
		Visible = false,
		Parent = holder,
	}, {
		UIKit.Corner(16),
		UIKit.Stroke(Theme.Colors.Stroke, 2, 0.55),
		UIKit.Padding(8),
		UIKit.List(nil, 5),
	})
	ui.MenuList = list
	ui.MenuBadges = {}
	for index, entry in MENU do
		local button = UIKit.Button("", Theme.Colors.PanelLight, function()
			self:SetMenuOpen(false)
			self:OpenWindow(entry.Window)
		end, { Size = UDim2.new(1, 0, 0, 40), LayoutOrder = index, Parent = list })
		UIKit.Text({ Text = entry.Icon, TextSize = 20, Position = UDim2.fromOffset(8, 0), Size = UDim2.fromOffset(28, 40), TextXAlignment = Enum.TextXAlignment.Center, Parent = button })
		UIKit.Text({ Text = entry.Label, Font = Theme.Fonts.Bold, TextSize = 14, Position = UDim2.fromOffset(42, 0), Size = UDim2.new(1, -60, 1, 0), TextWrapped = false, Parent = button })
		local badge = UIKit.new("TextLabel", {
			Text = "!",
			Font = Theme.Fonts.Title,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Theme.Colors.Coral,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(20, 20),
			Visible = false,
			ZIndex = 5,
			Parent = button,
		}, { UIKit.Round() })
		ui.MenuBadges[entry.Window] = badge
	end

	-- any window opening collapses the menu
	UIKit.WindowOpened:Connect(function()
		self:SetMenuOpen(false)
	end)
end

function HUD:SetMenuOpen(open: boolean)
	ui.MenuOpen = open
	ui.MenuList.Visible = open
	local icon = ui.MenuButton:FindFirstChild("Icon") :: TextLabel?
	if icon then
		icon.Text = if open then "✕" else ""
	end
	ui.MenuBars.Visible = not open
	if open then
		controllers.Effects:Pop(ui.MenuList, 0.9)
	end
end

local teleporting = false

function HUD:ReturnToPier()
	self:Teleport("Pier")
end
HUD.ReturnToBase = HUD.ReturnToPier -- (older callers)

-- Server-authoritative teleport with a little sparkle-and-flash effect at both ends.
-- "Pier" = next to the Equipment + Sell shops, "MyShop" = your own treasure shop plot.
function HUD:Teleport(destination: string)
	if teleporting then
		return
	end
	local label = if destination == "MyShop" then "your treasure shop" else "the Pier"
	if controllers.Dig:IsDigging() then
		controllers.Notify:Toast("⛏ Finish (or cancel) your dig before teleporting to " .. label .. ".", "Warning", 3)
		controllers.Sound:Play("Error")
		return
	end
	teleporting = true
	local accent = if destination == "MyShop" then Theme.Colors.Purple else Theme.Colors.Teal
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		controllers.Effects:Sparkles(root.Position, accent, 30, 10)
		controllers.Effects:Shockwave(root.Position - Vector3.new(0, 2.8, 0), accent, 12)
	end
	controllers.Effects:Flash(accent:Lerp(Color3.new(1, 1, 1), 0.7), 0.6)
	controllers.Sound:Chime(2)
	task.wait(0.25)
	local result = controllers.State:Call("TravelTo", destination)
	teleporting = false
	if result.Ok then
		controllers.World:AlignCamera()
		task.delay(0.15, function()
			local newRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if newRoot then
				controllers.Effects:Sparkles(newRoot.Position, accent, 30, 10)
				controllers.Effects:Shockwave(newRoot.Position - Vector3.new(0, 2.8, 0), accent, 14)
			end
		end)
		if destination == "MyShop" then
			controllers.Notify:Toast("🏪 Welcome to your treasure shop! Use the 📒 Manage Shop desk inside to display treasures and buy upgrades.", "Info", 4)
		else
			controllers.Notify:Toast("⚓ Back on the Pier — 🛒 Equipment Shop on the left, 💰 Sell Shop on the right, your shop up the boardwalk.", "Info", 4)
		end
	end
end

function HUD:BuildEventBanner()
	ui.Event = UIKit.new("Frame", {
		Name = "EventBanner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 26),
		Size = UDim2.fromOffset(0, 22),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.Purple,
		Visible = false,
		Parent = UIKit.Screen,
	}, { UIKit.Corner(11), UIKit.Stroke(Color3.new(1, 1, 1), 1.5, 0.5), UIKit.Padding(2, 12), UIKit.List(Enum.FillDirection.Horizontal, 8, nil, Enum.VerticalAlignment.Center) })
	UIKit.AddScale(ui.Event)
	ui.EventTitle = UIKit.Text({ Text = "", Font = Theme.Fonts.Title, TextSize = 15, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 1, Parent = ui.Event })
	ui.EventText = UIKit.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = 12, Size = UDim2.fromOffset(0, 18), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 2, Parent = ui.Event })
	UIKit.TextStroke(0.5).Parent = ui.EventTitle
end

-- The cheapest upgrade you don't own yet (shovel / detector): always something to aim for
local function nextGoal(data): (string?, number?, number?, string?)
	local best, bestPrice, bestLevel, bestTab = nil, math.huge, nil, nil
	local function consider(def, tab: string)
		if def and def.Price < bestPrice then
			best, bestPrice, bestLevel, bestTab = def.Name, def.Price, def.Level, tab
		end
	end
	for _, def in Equipment.Shovels do
		if not (data.Owned.Shovel and data.Owned.Shovel[def.Id]) then
			consider(def, "Shovels")
			break
		end
	end
	for _, def in Equipment.Detectors do
		if not (data.Owned.Detector and data.Owned.Detector[def.Id]) then
			consider(def, "Detectors")
			break
		end
	end
	if not best then
		return nil
	end
	return best, bestPrice, bestLevel, bestTab
end

function HUD:BumpCash()
	controllers.Effects:Pop(ui.Cash, 1.25)
end

function HUD:BumpLevel()
	controllers.Effects:Pop(ui.Level, 1.5)
end

function HUD:Refresh(data)
	-- cash counts up/down smoothly and pops when it grows
	local previous = ui.CashValue.Value
	if data.Cash ~= previous then
		if data.Cash > previous and previous > 0 then
			self:BumpCash()
		end
		UIKit.Tween(ui.CashValue, 0.45, { Value = data.Cash })
	end

	local goalName, goalPrice, goalLevel, goalTab = nextGoal(data)
	ui.GoalTab = goalTab
	if goalName and goalPrice then
		local ready = data.Cash >= goalPrice and data.Level >= (goalLevel or 1)
		ui.Goal.Visible = true
		if ready then
			ui.Goal.Text = "✅ You can afford: " .. goalName .. "! Visit the 🛒 Equipment Shop"
			ui.Goal.BackgroundColor3 = Theme.Colors.Green
		elseif data.Level < (goalLevel or 1) then
			ui.Goal.Text = string.format("🎯 Next: %s · reach Lv %d", goalName, goalLevel or 1)
			ui.Goal.BackgroundColor3 = Theme.Colors.PanelDark
		else
			ui.Goal.Text = string.format("🎯 Next: %s · %s / %s", goalName, Format.Cash(data.Cash), Format.Cash(goalPrice))
			ui.Goal.BackgroundColor3 = Theme.Colors.PanelDark
		end
	else
		ui.Goal.Visible = false
	end
	if ui.CashValue.Value == 0 then
		ui.Cash.Text = "💰 " .. Format.Cash(data.Cash)
	end
	ui.Level.Text = "Lv " .. data.Level
	ui.XPBar:Set(data.XP / math.max(1, data.XPNeeded), Format.Commas(data.XP) .. " / " .. Format.Commas(data.XPNeeded) .. " XP")
	ui.LuckButton.Text = "🍀 " .. Format.Luck(data.Luck.Points or 0)
	local zone = data.CurrentZone and Zones.Info[data.CurrentZone]
	ui.Zone.Text = "📍 " .. (if zone then zone.Name else "The Pier")
	ui.SaveWarning.Visible = data.Saving == false

	-- badges
	local claimable = false
	for _, quest in data.Quests.List do
		if not quest.Claimed and quest.Progress >= quest.Target then
			claimable = true
		end
	end
	ui.MenuBadges.Quests.Visible = claimable
	ui.MenuBadge.Visible = claimable
end

function HUD:Tick()
	local data = controllers.State.Data
	if data then
		local now = controllers.State:Now()
		local luck = data.Luck
		if luck.BoostId and luck.BoostEnds > now then
			local boost = Equipment.ById.Boost[luck.BoostId]
			ui.Boost.Visible = true
			ui.Boost.Text = string.format("⏱ %s %s · %s left", if boost then boost.Name else "Boost", Format.Luck(luck.BoostBonus or 0), Format.Time(luck.BoostEnds - now))
		else
			ui.Boost.Visible = false
		end
	end

	local eventId = ReplicatedStorage:GetAttribute("EventId")
	local ends = ReplicatedStorage:GetAttribute("EventEnds") or 0
	local event = eventId and Events.ById[eventId]
	if event and ends > controllers.State:Now() then
		ui.Event.Visible = true
		ui.Event.BackgroundColor3 = event.Color
		ui.EventTitle.TextColor3 = UIKit.ContrastText(event.Color)
		ui.EventText.TextColor3 = UIKit.ContrastText(event.Color)
		ui.EventTitle.Text = event.Icon .. " " .. event.Name .. "  ⏱ " .. Format.Time(ends - controllers.State:Now())
		ui.EventText.Text = event.Description
	else
		ui.Event.Visible = false
	end
end

function HUD:Init(all)
	controllers = all
	self:BuildStats()
	self:BuildMenu()
	self:BuildEventBanner()
end

-- Follow the character's Humanoid: drain the bar, leave a ghost of what was lost, pulse the heart
function HUD:WatchHealth(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	local last = humanoid.Health
	local function update()
		local max = math.max(humanoid.MaxHealth, 1)
		local fraction = math.clamp(humanoid.Health / max, 0, 1)
		ui.HealthBar:Set(fraction, tostring(math.ceil(humanoid.Health)))
		ui.HealthBar.Fill.BackgroundColor3 = if fraction < 0.3 then Color3.fromRGB(230, 50, 50) else Theme.Colors.Coral
		if humanoid.Health < last - 0.5 then
			-- hurt: the ghost holds the old amount for a moment, then drains after the fill
			ui.HealthGhost.Size = UDim2.fromScale(math.clamp(last / max, 0, 1), 1)
			task.delay(0.45, function()
				UIKit.Tween(ui.HealthGhost, 0.5, { Size = UDim2.fromScale(math.clamp(humanoid.Health / max, 0, 1), 1) })
			end)
			controllers.Effects:Pop(ui.Heart, 1.5)
		else
			ui.HealthGhost.Size = UDim2.fromScale(fraction, 1)
		end
		last = humanoid.Health
	end
	humanoid.HealthChanged:Connect(update)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(update)
	update()
end

function HUD:Start()
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false)
	end)
	local localPlayer = Players.LocalPlayer
	local current = localPlayer.Character
	if current then
		task.spawn(function()
			self:WatchHealth(current)
		end)
	end
	localPlayer.CharacterAdded:Connect(function(character)
		self:WatchHealth(character)
	end)
	controllers.State:OnChange(function(data)
		self:Refresh(data)
	end)
	while true do
		self:Tick()
		task.wait(0.5)
	end
end

return HUD
