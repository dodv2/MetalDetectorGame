--[[
	SettingsController
	⚙ Settings: sound, beep volume, vibration, reduced motion, screen-edge signal glow, larger UI.
	Settings are saved with your data.
]]

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Settings = {}

local controllers
local window
local rows = {}

local TOGGLES = {
	{ Key = "Sound", Title = "🔊 Sound effects", Description = "Beeps, digging and rewards. Every sound also has a visual cue." },
	{ Key = "EdgeGlow", Title = "🟩 Screen-edge signal glow", Description = "The screen edges glow when a treasure is close (signal 3+)." },
	{ Key = "Haptics", Title = "📳 Controller vibration", Description = "Gamepad rumbles with strong signals." },
	{ Key = "ReducedMotion", Title = "🌀 Reduced motion", Description = "Turns off camera shake, spinning and detector sway." },
	{ Key = "LargeText", Title = "🔠 Larger interface", Description = "Makes all menus and text 15% bigger." },
}

local VOLUMES = { { 0.25, "Low" }, { 0.6, "Medium" }, { 1, "High" } }

function Settings:Render()
	local data = controllers.State.Data
	if not data then
		return
	end
	for key, row in rows do
		if key == "BeepVolume" then
			local label = "Medium"
			for _, option in VOLUMES do
				if math.abs(option[1] - (data.Settings.BeepVolume or 0.6)) < 0.01 then
					label = option[2]
				end
			end
			row.Text = "Volume: " .. label
		else
			local on = data.Settings[key] == true
			row.Text = if on then "ON" else "OFF"
			UIKit.SetButtonColor(row, if on then Theme.Colors.Green else Theme.Colors.Neutral)
		end
	end
	UIKit.TextBoost = if data.Settings.LargeText then 1.15 else 1
	UIKit.RefreshScale()
end

function Settings:Init(all)
	controllers = all
	window = UIKit.Window("Settings", "⚙ Settings", Vector2.new(640, 500))
	local list = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = window.Content }, { UIKit.List(nil, 8) })
	local function addRow(order: number, title: string, description: string, onClick: () -> ())
		local row = UIKit.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, Size = UDim2.new(1, 0, 0, 62), LayoutOrder = order, Parent = list }, { UIKit.Corner(12) })
		UIKit.Text({ Text = title, Font = Theme.Fonts.Bold, TextSize = 17, Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -180, 0, 22), Parent = row })
		UIKit.Text({ Text = description, TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(14, 30), Size = UDim2.new(1, -180, 0, 28), Parent = row })
		return UIKit.Button("", Theme.Colors.Neutral, onClick, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(140, 40), TextSize = 16, Parent = row })
	end
	for order, toggle in TOGGLES do
		rows[toggle.Key] = addRow(order * 2, toggle.Title, toggle.Description, function()
			local data = controllers.State.Data
			if data then
				controllers.State:Call("UpdateSettings", toggle.Key, not data.Settings[toggle.Key])
			end
		end)
	end
	rows.BeepVolume = addRow(3, "🔉 Detector beep volume", "How loud the detector beeps are.", function()
		local data = controllers.State.Data
		if not data then
			return
		end
		local current = data.Settings.BeepVolume or 0.6
		local nextIndex = 1
		for index, option in VOLUMES do
			if math.abs(option[1] - current) < 0.01 then
				nextIndex = index % #VOLUMES + 1
			end
		end
		controllers.State:Call("UpdateSettings", "BeepVolume", VOLUMES[nextIndex][1])
		controllers.Sound:Play("Beep", 1.2)
	end)
	window.Opened:Connect(function()
		self:Render()
	end)
end

function Settings:Start()
	controllers.State:OnChange(function()
		self:Render()
	end)
end

return Settings
