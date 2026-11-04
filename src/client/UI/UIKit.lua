--[[
	UIKit
	Small helpers for building the UI in code.

	UIKit.new("TextLabel", { Text = "Hi", Size = ... }, { children... })
	  * keys starting with "On" connect events:  OnActivated = function() end
	UIKit.Button("Buy", Theme.Colors.Gold, function() end)
	UIKit.Window("Inventory", "🎒 Backpack", Vector2.new(760, 500)) -> window object with :Open/:Close/:Toggle
]]

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Theme = require(script.Parent.Theme)
local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Signal = require(Shared.Signal)
local Rarities = require(Shared.Config.Rarities)

local UIKit = {}
UIKit.Theme = Theme
UIKit.Colors = Theme.Colors
UIKit.Fonts = Theme.Fonts
UIKit.ClickSound = nil :: (() -> ())?
UIKit.WindowOpened = Signal.new()

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- Root ScreenGui + responsive scaling
---------------------------------------------------------------------------
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BeachUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screenGui.IgnoreGuiInset = false
screenGui.Parent = player:WaitForChild("PlayerGui")
UIKit.Screen = screenGui

local overlayGui = Instance.new("ScreenGui")
overlayGui.Name = "BeachOverlay"
overlayGui.ResetOnSpawn = false
overlayGui.IgnoreGuiInset = true
overlayGui.DisplayOrder = -1
overlayGui.Parent = player:WaitForChild("PlayerGui")
UIKit.Overlay = overlayGui

local scales: { UIScale } = {}
UIKit.ScaleValue = 1
UIKit.TextBoost = 1

local function computeScale(): number
	local camera = Workspace.CurrentCamera
	local viewport = if camera then camera.ViewportSize else Theme.DesignSize
	local scale = math.min(viewport.X / Theme.DesignSize.X, viewport.Y / Theme.DesignSize.Y)
	return math.clamp(scale, 0.55, 1.35) * UIKit.TextBoost
end

local scaleCaps: { [UIScale]: number } = {}

function UIKit.RefreshScale()
	UIKit.ScaleValue = computeScale()
	for _, uiScale in scales do
		uiScale.Scale = math.min(UIKit.ScaleValue, scaleCaps[uiScale] or math.huge)
	end
end

-- Adds a UIScale so the frame scales with screen size (design size is 1280x720).
-- maxScale keeps compact HUD pieces from growing too big on large monitors.
function UIKit.AddScale(frame: GuiObject, maxScale: number?)
	local uiScale = Instance.new("UIScale")
	if maxScale then
		scaleCaps[uiScale] = maxScale
	end
	uiScale.Scale = math.min(UIKit.ScaleValue, maxScale or math.huge)
	uiScale.Parent = frame
	table.insert(scales, uiScale)
	return uiScale
end

local function watchCamera()
	local camera = Workspace.CurrentCamera
	if camera then
		camera:GetPropertyChangedSignal("ViewportSize"):Connect(UIKit.RefreshScale)
	end
	UIKit.RefreshScale()
end
Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
watchCamera()

function UIKit.IsTouch(): boolean
	return UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
end

---------------------------------------------------------------------------
-- Instance builder
---------------------------------------------------------------------------
function UIKit.new(className: string, props: { [any]: any }?, children: { Instance }?): any
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif type(key) == "string" and string.sub(key, 1, 2) == "On" and type(value) == "function" then
				(instance :: any)[string.sub(key, 3)]:Connect(value)
			else
				(instance :: any)[key] = value
			end
		end
	end
	if children then
		for _, child in children do
			child.Parent = instance
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

function UIKit.Corner(radius: number?): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(0, radius or 12) })
end

function UIKit.Round(): UICorner
	return UIKit.new("UICorner", { CornerRadius = UDim.new(1, 0) })
end

function UIKit.Stroke(color: Color3?, thickness: number?, transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = color or Theme.Colors.Stroke,
		Thickness = thickness or 2,
		Transparency = transparency or 0.6,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
	})
end

function UIKit.TextStroke(transparency: number?): UIStroke
	return UIKit.new("UIStroke", {
		Color = Color3.new(0, 0, 0),
		Thickness = 1.5,
		Transparency = transparency or 0.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
	})
end

function UIKit.Padding(all: number, horizontal: number?): UIPadding
	local h = horizontal or all
	return UIKit.new("UIPadding", {
		PaddingTop = UDim.new(0, all),
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, h),
		PaddingRight = UDim.new(0, h),
	})
end

function UIKit.List(direction: Enum.FillDirection?, padding: number?, horizontalAlign: Enum.HorizontalAlignment?, verticalAlign: Enum.VerticalAlignment?): UIListLayout
	return UIKit.new("UIListLayout", {
		FillDirection = direction or Enum.FillDirection.Vertical,
		Padding = UDim.new(0, padding or 6),
		SortOrder = Enum.SortOrder.LayoutOrder,
		HorizontalAlignment = horizontalAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = verticalAlign or Enum.VerticalAlignment.Top,
	})
end

function UIKit.Grid(cell: Vector2, padding: number?): UIGridLayout
	return UIKit.new("UIGridLayout", {
		CellSize = UDim2.fromOffset(cell.X, cell.Y),
		CellPadding = UDim2.fromOffset(padding or 8, padding or 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
	})
end

function UIKit.Gradient(top: Color3, bottom: Color3, rotation: number?): UIGradient
	return UIKit.new("UIGradient", {
		Color = ColorSequence.new(top, bottom),
		Rotation = rotation or 90,
	})
end

function UIKit.Text(props: { [any]: any }): TextLabel
	local defaults = {
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Body,
		TextColor3 = Theme.Colors.Text,
		TextSize = 16,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		RichText = true,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UIKit.new("TextLabel", defaults)
end

function UIKit.Tween(instance: Instance, time: number, goals: { [string]: any }, style: Enum.EasingStyle?, direction: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(instance, TweenInfo.new(time, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), goals)
	tween:Play()
	return tween
end

function UIKit.ScrollFrame(props: { [any]: any }): ScrollingFrame
	local defaults = {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Theme.Colors.Stroke,
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Selectable = false,
	}
	for key, value in props do
		defaults[key] = value
	end
	return UIKit.new("ScrollingFrame", defaults)
end

---------------------------------------------------------------------------
-- Buttons
---------------------------------------------------------------------------
local function lighten(color: Color3, amount: number): Color3
	return color:Lerp(Color3.new(1, 1, 1), amount)
end

-- Text colour that stays readable on the given background
function UIKit.ContrastText(background: Color3): Color3
	local luminance = 0.299 * background.R + 0.587 * background.G + 0.114 * background.B
	return if luminance > 0.62 then Color3.fromRGB(30, 30, 36) else Color3.new(1, 1, 1)
end

export type Button = TextButton & {}

function UIKit.Button(text: string, color: Color3?, onClick: (() -> ())?, props: { [any]: any }?): TextButton
	local base = color or Theme.Colors.Teal
	local button = UIKit.new("TextButton", {
		Text = text,
		Font = Theme.Fonts.Title,
		TextSize = 18,
		TextColor3 = UIKit.ContrastText(base),
		BackgroundColor3 = base,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(120, 40),
		TextWrapped = true,
	}, {
		UIKit.Corner(10),
		UIKit.Stroke(Color3.new(0, 0, 0), 2, 0.75),
		UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(205, 205, 205)),
	})
	button:SetAttribute("BaseColor", base)
	if props then
		for key, value in props do
			(button :: any)[key] = value
		end
	end
	button.MouseEnter:Connect(function()
		if button.Active then
			UIKit.Tween(button, 0.12, { BackgroundColor3 = lighten(button:GetAttribute("BaseColor") :: Color3, 0.15) })
		end
	end)
	button.MouseLeave:Connect(function()
		UIKit.Tween(button, 0.12, { BackgroundColor3 = button:GetAttribute("BaseColor") :: Color3 })
	end)
	button.Activated:Connect(function()
		if not button.Active then
			return
		end
		if UIKit.ClickSound then
			UIKit.ClickSound()
		end
		if onClick then
			onClick()
		end
	end)
	return button
end

-- Changes a button's colour (keeps hover working)
function UIKit.SetButtonColor(button: TextButton, color: Color3)
	button:SetAttribute("BaseColor", color)
	button.BackgroundColor3 = color
	button.TextColor3 = UIKit.ContrastText(color)
end

function UIKit.SetButtonEnabled(button: TextButton, enabled: boolean, color: Color3?)
	button.Active = enabled
	button.AutoButtonColor = false
	UIKit.SetButtonColor(button, if enabled then (color or button:GetAttribute("BaseColor") :: Color3) else Theme.Colors.Disabled)
end

---------------------------------------------------------------------------
-- Progress bar
---------------------------------------------------------------------------
export type Bar = { Frame: Frame, Fill: Frame, Label: TextLabel, Set: (self: Bar, fraction: number, text: string?) -> () }

function UIKit.Bar(props: { [any]: any }, fillColor: Color3?): Bar
	local frame = UIKit.new("Frame", {
		BackgroundColor3 = Theme.Colors.PanelDark,
		Size = UDim2.new(1, 0, 0, 16),
		ClipsDescendants = true,
	}, { UIKit.Round(), UIKit.Stroke(Color3.new(0, 0, 0), 1.5, 0.6) })
	for key, value in props do
		(frame :: any)[key] = value
	end
	local fill = UIKit.new("Frame", {
		Name = "Fill",
		BackgroundColor3 = fillColor or Theme.Colors.Green,
		Size = UDim2.fromScale(0, 1),
		Parent = frame,
	}, { UIKit.Round(), UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(190, 190, 190)) })
	local label = UIKit.Text({
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		ZIndex = 3,
		Text = "",
		Parent = frame,
	})
	UIKit.TextStroke(0.4).Parent = label
	local bar = { Frame = frame, Fill = fill, Label = label }
	function bar.Set(self: any, fraction: number, text: string?)
		local clamped = math.clamp(fraction, 0, 1)
		UIKit.Tween(self.Fill, 0.25, { Size = UDim2.fromScale(clamped, 1) })
		if text then
			self.Label.Text = text
		end
	end
	return bar :: any
end

---------------------------------------------------------------------------
-- Rarity helpers (never colour-only: always glyph + name)
---------------------------------------------------------------------------
function UIKit.RarityColor(rarity: string): Color3
	local info = Rarities.Info[rarity]
	if not info then
		return Theme.Colors.Text
	end
	return if info.Rainbow then Color3.fromRGB(255, 236, 150) else info.Color
end

function UIKit.RarityLabel(rarity: string, props: { [any]: any }?): TextLabel
	local label = UIKit.Text({
		Text = Rarities.Label(rarity),
		Font = Theme.Fonts.Bold,
		TextColor3 = UIKit.RarityColor(rarity),
		TextSize = 14,
	})
	UIKit.TextStroke(0.55).Parent = label
	local info = Rarities.Info[rarity]
	if info and info.Rainbow then
		local gradient = UIKit.new("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
				ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 110)),
				ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 255, 160)),
				ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 190, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
			}),
			Parent = label,
		})
		label.TextColor3 = Color3.new(1, 1, 1)
		task.spawn(function()
			while label.Parent do
				gradient.Offset = Vector2.new(math.sin(os.clock() * 1.5) * 0.4, 0)
				task.wait(0.05)
			end
		end)
	end
	if props then
		for key, value in props do
			(label :: any)[key] = value
		end
	end
	return label
end

-- "■■■□□□□" tier pips
function UIKit.TierPips(rarity: string): string
	local tier = Rarities.Tier(rarity)
	return string.rep("■", tier) .. string.rep("□", #Rarities.Order - tier)
end

---------------------------------------------------------------------------
-- Windows (only one open at a time; Esc / gamepad B closes)
---------------------------------------------------------------------------
export type Window = {
	Name: string,
	Frame: Frame,
	Content: Frame,
	Title: TextLabel,
	IsOpen: boolean,
	Opened: any,
	Closed: any,
	Open: (self: Window, ...any) -> (),
	Close: (self: Window) -> (),
	Toggle: (self: Window, ...any) -> (),
}

local windows: { [string]: Window } = {}
UIKit.CurrentWindow = nil :: Window?

-- On small screens Roblox's chat box (top-left) can sit on top of a window's tabs and swallow
-- clicks. While a window overlaps that corner we tuck the chat away, and bring it back on close.
local CHAT_CORNER = Vector2.new(420, 300)
local chatTuckedAway = false
local function tuckChat(hide: boolean)
	if hide == chatTuckedAway then
		return
	end
	-- works for both the legacy chat and TextChatService
	local ok, enabled = pcall(StarterGui.GetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat)
	if not ok then
		return
	end
	if hide then
		if not enabled then
			return -- chat was already hidden by something else; leave it alone
		end
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, false)
		chatTuckedAway = true
	else
		pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Chat, true)
		chatTuckedAway = false
	end
end

function UIKit.Window(name: string, title: string, size: Vector2): Window
	local frame = UIKit.new("Frame", {
		Name = name .. "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, 40, 0.54, 0),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 10,
		Parent = screenGui,
	}, {
		UIKit.Corner(18),
		UIKit.Stroke(Theme.Colors.Stroke, 3, 0.45),
		UIKit.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(200, 210, 225)),
	})
	UIKit.AddScale(frame)

	local header = UIKit.new("Frame", {
		Name = "Header",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundColor3 = Theme.Colors.Teal,
		ZIndex = 11,
		Parent = frame,
	}, { UIKit.Corner(18), UIKit.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(170, 200, 210)) })
	-- square off the header's bottom corners
	UIKit.new("Frame", {
		Size = UDim2.new(1, 0, 0, 18),
		Position = UDim2.new(0, 0, 1, -18),
		BackgroundColor3 = Theme.Colors.Teal,
		BorderSizePixel = 0,
		ZIndex = 11,
		Parent = header,
	}, { UIKit.Gradient(Color3.fromRGB(205, 225, 232), Color3.fromRGB(170, 200, 210)) })

	local titleLabel = UIKit.Text({
		Name = "Title",
		Text = title,
		Font = Theme.Fonts.Title,
		TextSize = 26,
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -90, 1, 0),
		ZIndex = 12,
		Parent = header,
	})
	UIKit.TextStroke(0.3).Parent = titleLabel

	local window = {
		Name = name,
		Frame = frame,
		Title = titleLabel,
		IsOpen = false,
		Opened = Signal.new(),
		Closed = Signal.new(),
	} :: any

	local closeButton = UIKit.Button("✕", Theme.Colors.Coral, function()
		window:Close()
	end, {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -48, 0, 6),
		TextSize = 22,
		ZIndex = 13,
		Parent = header,
	})
	closeButton:SetAttribute("Accessible", "Close window")

	window.Content = UIKit.new("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(16, 62),
		Size = UDim2.new(1, -32, 1, -76),
		ZIndex = 10,
		Parent = frame,
	})

	function window.Open(self: any, ...)
		if UIKit.CurrentWindow and UIKit.CurrentWindow ~= self then
			UIKit.CurrentWindow:Close()
		end
		UIKit.CurrentWindow = self
		self.IsOpen = true
		self.Frame.Visible = true
		-- nudged right/down so Roblox's chat box (top-left) covers as little as possible
		self.Frame.Position = UDim2.new(0.5, 40, 0.58, 0)
		UIKit.Tween(self.Frame, 0.18, { Position = UDim2.new(0.5, 40, 0.54, 0) }, Enum.EasingStyle.Back)
		task.delay(0.22, function()
			if self.IsOpen and UIKit.CurrentWindow == self then
				local corner = self.Frame.AbsolutePosition
				tuckChat(corner.X < CHAT_CORNER.X and corner.Y < CHAT_CORNER.Y)
			end
		end)
		self.Opened:Fire(...)
		UIKit.WindowOpened:Fire(self)
		if GuiService.SelectedObject == nil and UserInputService.GamepadEnabled then
			GuiService.SelectedObject = closeButton
		end
	end

	function window.Close(self: any)
		if not self.IsOpen then
			return
		end
		self.IsOpen = false
		self.Frame.Visible = false
		if UIKit.CurrentWindow == self then
			UIKit.CurrentWindow = nil
			tuckChat(false)
		end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.Frame) then
			GuiService.SelectedObject = nil
		end
		self.Closed:Fire()
	end

	function window.Toggle(self: any, ...)
		if self.IsOpen then
			self:Close()
		else
			self:Open(...)
		end
	end

	windows[name] = window
	return window
end

function UIKit.GetWindow(name: string): Window?
	return windows[name]
end

UserInputService.InputBegan:Connect(function(input, processed)
	if input.KeyCode == Enum.KeyCode.Escape or input.KeyCode == Enum.KeyCode.ButtonB then
		if UIKit.CurrentWindow and (not processed or input.KeyCode == Enum.KeyCode.ButtonB) then
			UIKit.CurrentWindow:Close()
		end
	end
end)

---------------------------------------------------------------------------
-- Tabs
---------------------------------------------------------------------------
function UIKit.Tabs(parent: GuiObject, names: { string }, onSelect: (string) -> (), height: number?)
	local bar = UIKit.new("Frame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 34),
		ZIndex = 11,
		Parent = parent,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 6) })
	local buttons = {}
	local tabs = { Selected = names[1], Buttons = buttons }
	local function select(name: string)
		tabs.Selected = name
		for tabName, button in buttons do
			UIKit.SetButtonColor(button, if tabName == name then Theme.Colors.Gold else Theme.Colors.Neutral)
		end
		onSelect(name)
	end
	for index, name in names do
		local button = UIKit.Button(name, Theme.Colors.Neutral, function()
			select(name)
		end, {
			LayoutOrder = index,
			Size = UDim2.new(0, 0, 1, 0),
			AutomaticSize = Enum.AutomaticSize.X,
			TextSize = 15,
			ZIndex = 12,
			Parent = bar,
		})
		UIKit.Padding(0, 12).Parent = button
		buttons[name] = button
	end
	tabs.Select = select
	tabs.Frame = bar
	return tabs
end

---------------------------------------------------------------------------
-- Confirmation dialog
---------------------------------------------------------------------------
function UIKit.Confirm(title: string, message: string, options: { { Text: string, Color: Color3?, Callback: (() -> ())? } })
	local blocker = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.45,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 50,
		Parent = overlayGui,
	})
	overlayGui.DisplayOrder = 20
	local dialog = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(420, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 51,
		Parent = blocker,
	}, { UIKit.Corner(16), UIKit.Stroke(Theme.Colors.Gold, 3, 0.3), UIKit.Padding(18), UIKit.List(nil, 10, Enum.HorizontalAlignment.Center) })
	UIKit.AddScale(dialog)
	UIKit.Text({ Text = title, Font = Theme.Fonts.Title, TextSize = 24, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, LayoutOrder = 1, Parent = dialog })
	UIKit.Text({ Text = message, TextSize = 16, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextColor3 = Theme.Colors.SubText, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52, LayoutOrder = 2, Parent = dialog })
	local function close()
		blocker:Destroy()
		overlayGui.DisplayOrder = -1
	end
	for index, option in options do
		UIKit.Button(option.Text, option.Color or Theme.Colors.Teal, function()
			close()
			if option.Callback then
				option.Callback()
			end
		end, { Size = UDim2.new(1, 0, 0, 42), LayoutOrder = 10 + index, ZIndex = 52, Parent = dialog })
	end
	UIKit.Button("Cancel", Theme.Colors.Neutral, close, { Size = UDim2.new(1, 0, 0, 38), LayoutOrder = 99, ZIndex = 52, Parent = dialog })
	return close
end

return UIKit
