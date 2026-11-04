--[[
	DevController (Update 17)
	F1 / F2 / F3 developer test tools - the UI half. It holds NO permissions of its own:

	  * A key press only ASKS the server (DevCommand "Status"). The server checks the caller's
	    Roblox UserId against its own allowlist (DevService) and only then answers Ok.
	  * For everyone else the answer is "no": nothing is shown, no message appears, and the keys
	    stop asking for the rest of the session. The panel isn't even built.
	  * Every button sends a command that the server validates, clamps and applies to the
	    developer's own data only - the HUD updates from the normal state push.

	  F1  Developer panel: Cash, Level, XP, detector + shovel tiers, test Luck, sandbox switch
	  F2  Cash: preset amounts or a custom amount
	  F3  Level: level up (+1 / +5 / +10) or jump to any level, set XP
	  (press the same key again, Esc or ✕ to close)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Dev = {}

local controllers
local authorised: boolean? = nil -- nil = not asked yet, false = refused (never ask again)
local asking = false
local window = nil :: any
local tabs = nil :: any
local pages: { [string]: Frame } = {}
local labels = {} :: any
local status = nil :: any

local KEY_TAB = {
	[Enum.KeyCode.F1] = "Edit",
	[Enum.KeyCode.F2] = "Cash",
	[Enum.KeyCode.F3] = "Level",
}

-- Talks to the server. Errors only show once we know this player really is a developer.
local function call(command: string, value: any?): any
	local remote = Net.Function("DevCommand")
	local ok, result = pcall(remote.InvokeServer, remote, command, value)
	if not ok or type(result) ~= "table" then
		return { Ok = false }
	end
	if result.Ok == false and authorised and result.Error and not result.RateLimited then
		controllers.Notify:Toast("🧪 " .. result.Error, "Error", 2.5)
	end
	return result
end

local function refresh(result)
	if not result or not result.Ok or not labels.Cash then
		return
	end
	status = result
	labels.Cash.Text = "💰 Cash: " .. Format.Cash(result.Cash)
	labels.CashBig.Text = Format.Cash(result.Cash)
	labels.Level.Text = string.format("⭐ Level %d / %d   ·   XP %s / %s", result.Level, result.MaxLevel, Format.Commas(result.XP), Format.Commas(result.XPNeeded))
	labels.LevelBig.Text = string.format("Level %d   ·   %s / %s XP", result.Level, Format.Commas(result.XP), Format.Commas(result.XPNeeded))
	labels.Detector.Text = string.format("📡 Detector  %d/%d  %s", result.Detector, result.DetectorCount, result.DetectorName)
	labels.Shovel.Text = string.format("⛏ Shovel  %d/%d  %s", result.Shovel, result.ShovelCount, result.ShovelName)
	labels.Luck.Text = string.format("🍀 Test Luck +%s   (total +%s Luck)", Format.Commas(result.LuckPoints), Format.Commas(result.TotalLuckPoints))
	labels.Sandbox.Text = if result.Sandbox then "🧪 SANDBOX ON - nothing from this session is saved" else "💾 SANDBOX OFF - changes save to your real data!"
	labels.Sandbox.TextColor3 = if result.Sandbox then Theme.Colors.Luck else Theme.Colors.Coral
	UIKit.SetButtonColor(labels.SandboxButton, if result.Sandbox then Theme.Colors.Coral else Theme.Colors.Teal)
	labels.SandboxButton.Text = if result.Sandbox then "Turn sandbox off" else "Turn sandbox on"
	labels.Badge.Visible = result.Sandbox
end

local function run(command: string, value: any?)
	local result = call(command, value)
	if result.Ok then
		refresh(result)
		if result.Message then
			controllers.Notify:Toast("🧪 " .. result.Message, "Success", 1.8)
		end
		controllers.Sound:Play("Click")
	end
end

---------------------------------------------------------------------------
-- UI (built only after the server says yes)
---------------------------------------------------------------------------
local function row(parent: Instance, order: number, height: number?): Frame
	return UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 36),
		LayoutOrder = order,
		Parent = parent,
	}, { UIKit.List(Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left, Enum.VerticalAlignment.Center) })
end

local function heading(parent: Instance, order: number, text: string): TextLabel
	return UIKit.Text({
		Text = text,
		Font = Theme.Fonts.Bold,
		TextSize = 16,
		Size = UDim2.new(1, 0, 0, 22),
		LayoutOrder = order,
		Parent = parent,
	})
end

local function button(parent: Instance, text: string, color: Color3, width: number, onClick: () -> ())
	return UIKit.Button(text, color, onClick, { Size = UDim2.fromOffset(width, 32), TextSize = 15, Parent = parent })
end

local function input(parent: Instance, placeholder: string, width: number): TextBox
	return UIKit.new("TextBox", {
		Text = "",
		PlaceholderText = placeholder,
		ClearTextOnFocus = false,
		Font = Theme.Fonts.Number,
		TextSize = 16,
		TextColor3 = Theme.Colors.Text,
		PlaceholderColor3 = Theme.Colors.SubText,
		BackgroundColor3 = Theme.Colors.PanelDark,
		Size = UDim2.fromOffset(width, 32),
		Parent = parent,
	}, { UIKit.Corner(8), UIKit.Stroke(Theme.Colors.Stroke, 1.5, 0.4) })
end

-- "1.5m", "250k", "1,000" -> number (nil if it isn't one)
local function parseAmount(text: string): number?
	local clean = string.lower((string.gsub(text, "[%s,$]", "")))
	local number, suffix = string.match(clean, "^(%d+%.?%d*)([kmbt]?)$")
	local value = tonumber(number)
	if not value then
		return nil
	end
	local mult = ({ k = 1e3, m = 1e6, b = 1e9, t = 1e12 })[suffix] or 1
	return math.floor(value * mult)
end

local function page(name: string): Frame
	local frame = UIKit.ScrollFrame({
		Name = name,
		Position = UDim2.fromOffset(0, 42),
		Size = UDim2.new(1, 0, 1, -64),
		Visible = false,
		ZIndex = 11,
		Parent = window.Content,
	})
	UIKit.List(nil, 6).Parent = frame
	pages[name] = frame
	return frame
end

local function buildPanel()
	window = UIKit.Window("Dev", "🧪 Developer Tools", Vector2.new(600, 470))
	tabs = UIKit.Tabs(window.Content, { "Edit", "Cash", "Level" }, function(name)
		for pageName, frame in pages do
			frame.Visible = pageName == name
		end
	end)
	UIKit.Text({
		Text = "F1 panel  ·  F2 cash  ·  F3 level  ·  Esc closes   —   only works for authorised developer accounts",
		TextSize = 12,
		TextColor3 = Theme.Colors.SubText,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 18),
		Parent = window.Content,
	})

	-- Edit (F1): everything at once
	local edit = page("Edit")
	labels.Sandbox = heading(edit, 1, "")
	local sandboxRow = row(edit, 2)
	labels.SandboxButton = button(sandboxRow, "Turn sandbox off", Theme.Colors.Coral, 170, function()
		if status then
			run("Sandbox", not status.Sandbox)
		end
	end)
	UIKit.Text({ Text = "Sandbox keeps tests out of your real save and the leaderboards.", TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.fromOffset(380, 32), Parent = sandboxRow })

	labels.Cash = heading(edit, 3, "")
	local cashRow = row(edit, 4)
	local cashBox = input(cashRow, "e.g. 250k, 1.5m", 170)
	button(cashRow, "Set cash", Theme.Colors.Gold, 110, function()
		local amount = parseAmount(cashBox.Text)
		if amount then
			run("SetCash", amount)
		end
	end)

	labels.Level = heading(edit, 5, "")
	local levelRow = row(edit, 6)
	local levelBox = input(levelRow, "level", 80)
	button(levelRow, "Set level", Theme.Colors.Purple, 110, function()
		local level = tonumber(levelBox.Text)
		if level then
			run("SetLevel", math.floor(level))
		end
	end)
	local xpBox = input(levelRow, "XP", 90)
	button(levelRow, "Set XP", Theme.Colors.Purple, 90, function()
		local xp = parseAmount(xpBox.Text)
		if xp then
			run("SetXP", xp)
		end
	end)

	for order, kind in { [7] = "Detector", [9] = "Shovel" } do
		labels[kind] = heading(edit, order, "")
		local tierRow = row(edit, order + 1)
		button(tierRow, "◀ Lower tier", Theme.Colors.Neutral, 130, function()
			if status then
				run("Set" .. kind, math.max(1, status[kind] - 1))
			end
		end)
		button(tierRow, "Higher tier ▶", Theme.Colors.Teal, 130, function()
			if status then
				run("Set" .. kind, math.min(status[kind .. "Count"], status[kind] + 1))
			end
		end)
		button(tierRow, "Best", Theme.Colors.Gold, 70, function()
			if status then
				run("Set" .. kind, status[kind .. "Count"])
			end
		end)
	end

	labels.Luck = heading(edit, 11, "")
	local luckRow = row(edit, 12)
	for _, points in { 0, 100, 1000, 10000 } do
		button(luckRow, if points == 0 then "None" else "+" .. Format.Commas(points), Theme.Colors.Luck, 80, function()
			run("SetLuck", points)
		end)
	end
	local luckBox = input(luckRow, "custom", 90)
	button(luckRow, "Set", Theme.Colors.Luck, 50, function()
		local points = parseAmount(luckBox.Text)
		if points then
			run("SetLuck", points)
		end
	end)

	-- Cash (F2)
	local cash = page("Cash")
	labels.CashBig = UIKit.Text({ Text = "", Font = Theme.Fonts.Number, TextSize = 30, TextColor3 = Theme.Colors.Gold, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = cash })
	heading(cash, 2, "Add a preset amount")
	local presets = row(cash, 3, 40)
	for _, amount in { 1000, 100000, 10000000, 1000000000 } do
		button(presets, "+" .. Format.Cash(amount), Theme.Colors.Gold, 128, function()
			run("AddCash", amount)
		end)
	end
	heading(cash, 4, "…or any amount (250k, 1.5m, 2b)")
	local customRow = row(cash, 5, 40)
	local customBox = input(customRow, "amount", 200)
	button(customRow, "Add", Theme.Colors.Gold, 90, function()
		local amount = parseAmount(customBox.Text)
		if amount then
			run("AddCash", amount)
		end
	end)
	button(customRow, "Set exactly", Theme.Colors.Neutral, 120, function()
		local amount = parseAmount(customBox.Text)
		if amount then
			run("SetCash", amount)
		end
	end)

	-- Level (F3)
	local level = page("Level")
	labels.LevelBig = UIKit.Text({ Text = "", Font = Theme.Fonts.Number, TextSize = 26, TextColor3 = Theme.Colors.Purple, Size = UDim2.new(1, 0, 0, 40), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = level })
	heading(level, 2, "Level up")
	local ups = row(level, 3, 40)
	for _, count in { 1, 5, 10, 25 } do
		button(ups, "+" .. count .. (if count == 1 then " level" else " levels"), Theme.Colors.Purple, 128, function()
			run("LevelUp", count)
		end)
	end
	heading(level, 4, "Jump to a level (beaches and the shop follow automatically)")
	local setRow = row(level, 5, 40)
	local setBox = input(setRow, "level", 120)
	button(setRow, "Set level", Theme.Colors.Purple, 120, function()
		local value = tonumber(setBox.Text)
		if value then
			run("SetLevel", math.floor(value))
		end
	end)
	button(setRow, "Max", Theme.Colors.Gold, 80, function()
		if status then
			run("SetLevel", status.MaxLevel)
		end
	end)

	-- a small reminder in the corner while the sandbox is on
	labels.Badge = UIKit.new("TextLabel", {
		Text = "🧪 DEV SANDBOX",
		Font = Theme.Fonts.Title,
		TextSize = 13,
		TextColor3 = Color3.fromRGB(20, 50, 20),
		BackgroundColor3 = Theme.Colors.Luck,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -8, 1, -8),
		Size = UDim2.fromOffset(120, 22),
		Visible = false,
		ZIndex = 50,
		Parent = UIKit.Screen,
	}, { UIKit.Corner(8) })

	tabs.Select("Edit")
end

---------------------------------------------------------------------------
function Dev:Open(tabName: string)
	if authorised == false or asking then
		return
	end
	if window and window.IsOpen and tabs.Selected == tabName then
		window:Close() -- same key again closes it
		return
	end
	asking = true
	local result = call("Status")
	asking = false
	if not result.Ok then
		if authorised == nil then
			authorised = false -- not a developer: stay silent and stop asking
		end
		return
	end
	authorised = true
	if not window then
		buildPanel()
	end
	refresh(result)
	tabs.Select(tabName)
	if not window.IsOpen then
		window:Open()
	end
end

function Dev:Init(all)
	controllers = all
end

function Dev:Start()
	UserInputService.InputBegan:Connect(function(input, _processed)
		local tabName = KEY_TAB[input.KeyCode]
		if not tabName or UserInputService:GetFocusedTextBox() then
			return
		end
		task.spawn(function()
			self:Open(tabName)
		end)
	end)
	-- keep the numbers fresh while the panel is open
	controllers.State:OnChange(function()
		if window and window.IsOpen then
			task.spawn(function()
				refresh(call("Status"))
			end)
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function()
		if window and window.IsOpen then
			window:Close()
		end
	end)
end

return Dev
