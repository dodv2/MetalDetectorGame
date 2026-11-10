--[[
	DetectorController
	The compact detector panel pinned to the TOP-RIGHT corner of the screen (screen-space UI, never
	attached to the character or world; only shown while the 📡 detector is held):

	  ┌──────────────────┐
	  │ 📡 Rusty Beeper –│  header (the – button minimises it to a slim pill)
	  │     ( radar )    │  circular radar: sweep + needle rotate around the exact centre,
	  │                  │  pulses expand from the centre, blip lights up as the sweep passes it
	  │  4/5  STRONG     │  signal level in numbers AND words (never colour alone)
	  │  ▁▃▅▇█           │  five-level proximity gauge
	  │   ≈ 12.4 m       │  distance in metres
	  │ ↗ Ahead-right    │  direction + depth, rarity hint (better detectors)
	  │ [E] Start digging│  what to do next
	  └──────────────────┘

	Plus: beeps that speed up and rise in pitch, coil light, optional screen-edge glow and
	gamepad vibration. At 5/5 the radar switches to a "dig here" animation.
	Digging itself lives in DigController.
]]

local HapticService = game:GetService("HapticService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local GameConfig = require(Shared.Config.GameConfig)
local Equipment = require(Shared.Config.Equipment)
local Rarities = require(Shared.Config.Rarities)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Detector = {}

local player = Players.LocalPlayer
local controllers
local ui = {} :: any

local LEVEL_WORDS = { [0] = "No signal", "Faint", "Weak", "Moderate", "Strong", "DIG HERE" }
local LEVEL_COLORS = {
	[0] = Color3.fromRGB(90, 110, 130),
	Color3.fromRGB(110, 170, 210),
	Color3.fromRGB(90, 210, 200),
	Color3.fromRGB(255, 214, 90),
	Color3.fromRGB(255, 150, 60),
	Color3.fromRGB(90, 235, 110),
}
Detector.LevelColors = LEVEL_COLORS
local BEEP_INTERVAL = { 1.3, 0.9, 0.55, 0.32, 0.16 }
local ARROWS = { "↑", "↗", "→", "↘", "↓", "↙", "←", "↖" }
local DIRECTION_WORDS = { "Ahead", "Ahead-right", "Right", "Behind-right", "Behind", "Behind-left", "Left", "Ahead-left" }

local TOUCH = UIKit.IsTouch()
local PANEL_W = if TOUCH then 168 else 200
local RADAR = if TOUCH then 118 else 150

local signal = { Active = false, Level = 0 } :: any
local equippedTool: Tool? = nil
local lastBeep = 0
local sweepAngle = 0
local blipAngle: number? = nil
local blipLit = 0
local minimized = false
local directionText = ""

function Detector:Signal()
	return signal
end

function Detector:IsHeld(): boolean
	return equippedTool ~= nil
end

local function settings()
	local data = controllers.State.Data
	return if data then data.Settings else {}
end

---------------------------------------------------------------------------
-- UI
---------------------------------------------------------------------------
local function circle(props: { [string]: any }, stroke: Color3?, thickness: number?, transparency: number?): Frame
	local frame = UIKit.new("Frame", props, { UIKit.Round() })
	if stroke then
		UIKit.Stroke(stroke, thickness or 1, transparency or 0.5).Parent = frame
	end
	return frame
end

function Detector:BuildRadar(parent: Instance)
	-- Outer ring carries the border (a CanvasGroup would clip a stroke), inner CanvasGroup clips
	-- everything to a perfect circle.
	local ring = circle({
		Name = "RadarRing",
		Size = UDim2.fromOffset(RADAR, RADAR),
		BackgroundColor3 = Color3.fromRGB(6, 40, 46),
		LayoutOrder = 2,
		Parent = parent,
	})
	ui.RadarStroke = UIKit.Stroke(Theme.Colors.Teal, 3, 0.15)
	ui.RadarStroke.Parent = ring
	ui.RadarRing = ring

	local disc = UIKit.new("CanvasGroup", {
		Name = "Radar",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = Color3.fromRGB(8, 52, 58),
		Parent = ring,
	}, { UIKit.Round(), UIKit.Gradient(Color3.fromRGB(20, 92, 96), Color3.fromRGB(6, 34, 42), 90) })
	ui.Radar = disc

	-- range rings + crosshair (all centred with AnchorPoint 0.5, 0.5)
	for _, scale in { 0.33, 0.66 } do
		circle({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(scale, scale), BackgroundTransparency = 1, Parent = disc }, Theme.Colors.Teal, 1, 0.55)
	end
	UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, 0, 0, 1), BackgroundColor3 = Theme.Colors.Teal, BackgroundTransparency = 0.65, BorderSizePixel = 0, Parent = disc })
	UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(0, 1, 1, 0), BackgroundColor3 = Theme.Colors.Teal, BackgroundTransparency = 0.65, BorderSizePixel = 0, Parent = disc })

	-- Sweep: a full-size holder centred on the radar. GUI rotation always pivots around an
	-- element's own centre, so rotating this holder spins everything inside it around the
	-- exact radar centre (needle and trail stay aligned).
	local holder = UIKit.new("Frame", {
		Name = "SweepHolder",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = disc,
	})
	ui.SweepHolder = holder
	-- trail: the quarter behind the needle (needle points up and turns clockwise)
	ui.SweepTrail = UIKit.new("Frame", {
		Name = "Trail",
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.fromScale(0.5, 0.5),
		BackgroundColor3 = Color3.fromRGB(120, 255, 220),
		BorderSizePixel = 0,
		Parent = holder,
	}, { UIKit.new("UIGradient", { Rotation = 0, Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.7, 0.85), NumberSequenceKeypoint.new(1, 0.45) }) }) })
	ui.Needle = UIKit.new("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 2, 0.5, 0),
		BackgroundColor3 = Color3.fromRGB(170, 255, 230),
		BorderSizePixel = 0,
		Parent = holder,
	}, { UIKit.new("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0, 0.5) }) })

	ui.PulseHolder = UIKit.new("Frame", { Name = "Pulses", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = disc })

	circle({ Name = "Center", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(8, 8), BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 4, Parent = disc })

	ui.Blip = circle({
		Name = "Blip",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.25),
		Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = LEVEL_COLORS[3],
		Visible = false,
		ZIndex = 5,
		Parent = disc,
	}, Color3.new(1, 1, 1), 2, 0.1)

	-- 5/5: discovery-ready overlay
	ui.Ready = UIKit.new("Frame", {
		Name = "Ready",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = LEVEL_COLORS[5],
		BackgroundTransparency = 1,
		ZIndex = 6,
		Visible = false,
		Parent = disc,
	}, { UIKit.Round() })
	ui.ReadyRing = circle({ AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.4, 0.4), BackgroundTransparency = 1, ZIndex = 6, Parent = ui.Ready }, LEVEL_COLORS[5], 3, 0)
	ui.ReadyIcon = UIKit.Text({ Text = "⛏", TextSize = 34, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(50, 50), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 7, Parent = ui.Ready })

	UIKit.Text({ Text = "▲", TextSize = 10, Font = Theme.Fonts.Bold, TextColor3 = Theme.Colors.SubText, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 3), Size = UDim2.fromOffset(20, 10), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5, Parent = disc })
end

function Detector:BuildUI()
	local panel = UIKit.new("Frame", {
		Name = "DetectorPanel",
		-- pinned to the top-right corner of the screen (just under Roblox's top bar). Anchored at
		-- the TOP so the radar never moves when rows below it change.
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -10, 0, 10),
		Size = UDim2.fromOffset(PANEL_W, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		BackgroundTransparency = 0.08,
		Visible = false,
		Parent = UIKit.Screen,
	}, {
		UIKit.Corner(18),
		UIKit.Stroke(Theme.Colors.Stroke, 2, 0.55),
		UIKit.Gradient(Color3.fromRGB(255, 255, 255), Color3.fromRGB(175, 190, 210), 90),
		UIKit.Padding(10, 10),
		UIKit.List(nil, 6, Enum.HorizontalAlignment.Center),
	})
	ui.PanelScale = UIKit.AddScale(panel, 1)
	ui.Panel = panel
	ui.PanelHome = panel.Position

	-- header ---------------------------------------------------------------
	local header = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 22), LayoutOrder = 1, Parent = panel })
	ui.Title = UIKit.Text({ Text = "📡 Detector", Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, -28, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, Parent = header })
	ui.MinButton = UIKit.Button("–", Theme.Colors.Neutral, function()
		self:SetMinimized(not minimized, true)
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(24, 22), TextSize = 16, Parent = header })

	-- body -----------------------------------------------------------------
	local body = UIKit.new("Frame", { Name = "Body", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, Parent = panel }, {
		UIKit.List(nil, 6, Enum.HorizontalAlignment.Center),
	})
	ui.Body = body
	self:BuildRadar(body)

	local levelRow = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 26), LayoutOrder = 3, Parent = body }, {
		UIKit.List(Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Center),
	})
	ui.LevelNumber = UIKit.Text({ Text = "0/5", Font = Theme.Fonts.Number, TextSize = 24, Size = UDim2.fromOffset(0, 26), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 1, Parent = levelRow })
	UIKit.TextStroke(0.4).Parent = ui.LevelNumber
	ui.LevelWord = UIKit.new("TextLabel", {
		Text = "NO SIGNAL",
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(20, 30, 40),
		BackgroundColor3 = LEVEL_COLORS[0],
		Size = UDim2.fromOffset(0, 20),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = 2,
		Parent = levelRow,
	}, { UIKit.Corner(10), UIKit.Padding(0, 8) })

	-- five-level gauge
	local gauge = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 30), LayoutOrder = 4, Parent = body }, {
		UIKit.List(Enum.FillDirection.Horizontal, 5, Enum.HorizontalAlignment.Center, Enum.VerticalAlignment.Bottom),
	})
	ui.Bars = {}
	local barWidth = math.floor((PANEL_W - 28 - 20) / 5)
	for level = 1, 5 do
		local bar = UIKit.new("Frame", {
			Size = UDim2.fromOffset(barWidth, 8 + level * 4.4),
			BackgroundColor3 = Theme.Colors.PanelDark,
			LayoutOrder = level,
			Parent = gauge,
		}, { UIKit.Corner(4), UIKit.Stroke(Color3.new(1, 1, 1), 1, 0.75) })
		ui.Bars[level] = bar
	end

	ui.Distance = UIKit.Text({ Text = "—", Font = Theme.Fonts.Number, TextSize = if TOUCH then 24 else 30, Size = UDim2.new(1, 0, 0, if TOUCH then 26 else 32), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, LayoutOrder = 5, Parent = body })
	UIKit.TextStroke(0.45).Parent = ui.Distance
	ui.Direction = UIKit.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = Theme.Colors.SubText, Size = UDim2.new(1, 0, 0, 30), TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center, LayoutOrder = 6, Parent = body })
	ui.Hint = UIKit.new("TextLabel", {
		Text = "",
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 20),
		LayoutOrder = 7,
		Parent = body,
	}, { UIKit.Corner(8) })
	UIKit.TextStroke(0.5).Parent = ui.Hint

	ui.Action = UIKit.new("TextLabel", {
		Text = "",
		Font = Theme.Fonts.Bold,
		TextScaled = true, -- always fits the fixed-height row (no clipped words)
		TextWrapped = true,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Theme.Colors.PanelDark,
		Size = UDim2.new(1, 0, 0, 34),
		LayoutOrder = 8,
		Parent = body,
	}, { UIKit.Corner(10), UIKit.Padding(4, 6), UIKit.new("UITextSizeConstraint", { MaxTextSize = 13, MinTextSize = 8 }) })
	UIKit.TextStroke(0.5).Parent = ui.Action

	-- slim minimised readout (shown instead of the body)
	ui.Mini = UIKit.Text({ Text = "", Font = Theme.Fonts.Number, TextSize = 16, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, Visible = false, LayoutOrder = 3, Parent = panel })
	UIKit.TextStroke(0.45).Parent = ui.Mini


	-- screen-edge glow (visual proximity cue, can be turned off in Settings)
	ui.Edges = {}
	local edgeSpecs = {
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, 70), Rotation = 90 },
		{ Position = UDim2.new(0, 0, 1, -70), Size = UDim2.new(1, 0, 0, 70), Rotation = -90 },
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.new(0, 70, 1, 0), Rotation = 0 },
		{ Position = UDim2.new(1, -70, 0, 0), Size = UDim2.new(0, 70, 1, 0), Rotation = 180 },
	}
	for _, spec in edgeSpecs do
		local edge = UIKit.new("Frame", {
			Position = spec.Position,
			Size = spec.Size,
			BackgroundColor3 = LEVEL_COLORS[5],
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = UIKit.Overlay,
		}, { UIKit.new("UIGradient", { Rotation = spec.Rotation, Transparency = NumberSequence.new(0, 1) }) })
		table.insert(ui.Edges, edge)
	end
end

function Detector:SetMinimized(value: boolean, save: boolean?)
	minimized = value
	ui.Body.Visible = not value
	ui.Mini.Visible = value
	ui.MinButton.Text = if value then "+" else "–"
	if save then
		task.spawn(function()
			controllers.State:Call("UpdateSettings", "DetectorMinimized", value)
		end)
	end
end

local function spawnPulse(color: Color3, strong: boolean)
	local ring = circle({
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(0.08, 0.08),
		BackgroundTransparency = 1,
		Parent = ui.PulseHolder,
	})
	local stroke = UIKit.Stroke(color, if strong then 4 else 2.5, 0.05)
	stroke.Parent = ring
	UIKit.Tween(ring, 0.85, { Size = UDim2.fromScale(1.05, 1.05) }, Enum.EasingStyle.Sine)
	UIKit.Tween(stroke, 0.85, { Transparency = 1 }, Enum.EasingStyle.Sine)
	task.delay(0.9, function()
		ring:Destroy()
	end)
end

function Detector:UpdateReadout()
	local level = signal.Level or 0
	local color = LEVEL_COLORS[level]
	for index, bar in ui.Bars do
		local lit = index <= level
		bar.BackgroundColor3 = if lit then LEVEL_COLORS[index] else Theme.Colors.PanelDark
		bar.BackgroundTransparency = if lit then 0 else 0.2
	end
	ui.LevelNumber.Text = level .. "/5"
	ui.LevelNumber.TextColor3 = if level > 0 then color else Theme.Colors.SubText
	ui.LevelWord.Text = string.upper(LEVEL_WORDS[level])
	ui.LevelWord.BackgroundColor3 = color
	ui.LevelWord.TextColor3 = UIKit.ContrastText(color)
	ui.Blip.BackgroundColor3 = color
	ui.RadarStroke.Color = if level == 5 then LEVEL_COLORS[5] elseif level >= 3 then color else Theme.Colors.Teal

	local data = controllers.State.Data
	if data then
		local def = Equipment.ById.Detector[data.Equipment.Detector]
		local stats = GameMath.DetectorStats(data)
		ui.Title.Text = string.format("📡 %s · %s", if def then def.Name else "Detector", Format.Meters(stats.Range))
	end

	local action, actionColor = "", Theme.Colors.PanelDark
	if not signal.Zone then
		ui.Distance.Text = "—"
		ui.Direction.Text = "Walk onto a beach to start detecting"
		ui.Mini.Text = "📡 No dig zone"
	elseif level == 0 then
		ui.Distance.Text = "Scanning…"
		ui.Direction.Text = "Nothing in range — keep walking"
		ui.Mini.Text = "📡 Scanning…"
	else
		local distance = (if level == 5 then "" else "≈ ") .. Format.Meters(signal.Studs or 0)
		ui.Distance.Text = if level == 5 then "Right here!" else distance
		local depthName = GameConfig.DepthNames[signal.Depth or 1] or "?"
		ui.Direction.Text = directionText .. "  ·  " .. depthName
		ui.Mini.Text = string.format("📡 %d/5 · %s", level, if level == 5 then "DIG!" else distance)
	end
	ui.Mini.TextColor3 = if level > 0 then color else Theme.Colors.SubText

	-- the hint and action rows always keep their space, so nothing in the panel jumps around
	if signal.Hint and level >= 3 then
		ui.Hint.Text = "🔮 " .. Rarities.Label(signal.Hint)
		ui.Hint.BackgroundTransparency = 0
		ui.Hint.BackgroundColor3 = UIKit.RarityColor(signal.Hint):Lerp(Color3.new(0, 0, 0), 0.45)
	else
		ui.Hint.Text = ""
		ui.Hint.BackgroundTransparency = 1
	end

	if level == 5 then
		if signal.Digging then
			action, actionColor = "⛏ Digging… keep clicking!", Theme.Colors.Orange
		else
			action, actionColor = if TOUCH then "⛏ Tap “Begin Excavation”" else "⛏ Press [E] to dig here", Theme.Colors.Green
		end
	elseif level > 0 then
		action = "Follow the blip to 5/5"
	else
		action = "Sweep the sand for a signal"
	end
	ui.Action.Text = action
	ui.Action.BackgroundColor3 = actionColor
end

---------------------------------------------------------------------------
-- Per-frame visuals
---------------------------------------------------------------------------
local function angleBetween(fromDeg: number, toDeg: number, target: number): boolean
	-- true if `target` lies on the clockwise arc fromDeg -> toDeg (degrees, 0..360)
	local span = (toDeg - fromDeg) % 360
	local offset = (target - fromDeg) % 360
	return offset <= span
end

function Detector:RenderStep(dt: number)
	local held = equippedTool ~= nil
	local active = held and signal.Active
	ui.Panel.Visible = held

	local level = if active then (signal.Level or 0) else 0
	local currentSettings = settings()
	local reduced = currentSettings.ReducedMotion == true

	-- sweep: rotate the centred holder
	local previous = sweepAngle
	sweepAngle = (sweepAngle + dt * (110 + level * 45)) % 360
	ui.SweepHolder.Rotation = sweepAngle

	-- blip position relative to where the camera faces
	local camera = Workspace.CurrentCamera
	ui.Blip.Visible = level > 0 and level < 5
	if level > 0 and camera and signal.DirX then
		local look = camera.CFrame.LookVector * Vector3.new(1, 0, 1)
		local right = camera.CFrame.RightVector * Vector3.new(1, 0, 1)
		if look.Magnitude > 0.01 and right.Magnitude > 0.01 then
			look, right = look.Unit, right.Unit
			local dir = Vector3.new(signal.DirX, 0, signal.DirZ)
			local x, y = dir:Dot(right), dir:Dot(look)
			local fraction = math.clamp((signal.Studs or 0) / math.max(signal.Range or 1, 1), 0.12, 0.9)
			ui.Blip.Position = UDim2.fromScale(0.5 + x * fraction * 0.5, 0.5 - y * fraction * 0.5)
			local angle = math.deg(math.atan2(x, y)) % 360
			blipAngle = angle
			local sector = math.floor((angle + 22.5) / 45) % 8 + 1
			directionText = if level == 5 then "⬇ Right under you" else ARROWS[sector] .. " " .. DIRECTION_WORDS[sector]
		end
	else
		blipAngle = nil
	end
	-- the blip lights up when the needle passes over it, then fades (like a real radar)
	if blipAngle and angleBetween(previous, sweepAngle, blipAngle) then
		blipLit = 1
		if not reduced then
			ui.Blip.Size = UDim2.fromOffset(22, 22)
			UIKit.Tween(ui.Blip, 0.35, { Size = UDim2.fromOffset(14, 14) })
		end
	end
	blipLit = math.max(0.35, blipLit - dt * 0.9)
	ui.Blip.BackgroundTransparency = 1 - blipLit

	-- 5/5: discovery-ready animation
	local ready = level == 5
	ui.Ready.Visible = ready
	if ready then
		local t = os.clock()
		local beat = if reduced then 0.5 else (math.sin(t * 6) * 0.5 + 0.5)
		ui.Ready.BackgroundTransparency = 0.82 - beat * 0.12
		ui.ReadyRing.Size = UDim2.fromScale(0.35 + beat * 0.3, 0.35 + beat * 0.3)
		local readyStroke = ui.ReadyRing:FindFirstChildOfClass("UIStroke")
		if readyStroke then
			readyStroke.Transparency = beat * 0.7
		end
		ui.ReadyIcon.Rotation = if reduced then 0 else math.sin(t * 9) * 18
		ui.RadarStroke.Thickness = 3 + beat * 2
	else
		ui.RadarStroke.Thickness = 3
	end
	ui.SweepTrail.BackgroundColor3 = if level >= 3 then LEVEL_COLORS[level] else Color3.fromRGB(120, 255, 220)

	-- beeps / pulses / coil light / haptics
	local glow = equippedTool and equippedTool:FindFirstChild("CoilGlow")
	local light = glow and glow:FindFirstChild("SignalLight") :: PointLight?
	if level > 0 then
		local interval = BEEP_INTERVAL[level]
		if os.clock() - lastBeep >= interval then
			lastBeep = os.clock()
			controllers.Sound:Play("Beep", 0.75 + level * 0.15)
			if not minimized then
				spawnPulse(LEVEL_COLORS[level], level >= 4)
				if level >= 4 and not reduced then
					controllers.Effects:Pop(ui.LevelNumber, 1.15)
				end
			end
			if light then
				light.Brightness = 1 + level
			end
			if currentSettings.Haptics ~= false and level >= 3 and UserInputService.GamepadEnabled then
				pcall(function()
					HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0.15 * level)
				end)
				task.delay(0.07, function()
					pcall(function()
						HapticService:SetMotor(Enum.UserInputType.Gamepad1, Enum.VibrationMotor.Small, 0)
					end)
				end)
			end
		end
	end
	if light then
		light.Brightness = math.max(0, light.Brightness - dt * 8)
	end

	-- screen-edge glow from 4/5 (subtle; off with the setting)
	local edgeAlpha = 0
	if level >= 4 and currentSettings.EdgeGlow ~= false then
		local beat = if reduced then 0.5 else (math.sin(os.clock() * (6 + level * 3)) * 0.5 + 0.5)
		edgeAlpha = (level - 3) * 0.1 * (0.6 + 0.4 * beat)
	end
	for _, edge in ui.Edges do
		edge.BackgroundTransparency = 1 - edgeAlpha
		edge.BackgroundColor3 = LEVEL_COLORS[math.max(level, 1)]
	end

	-- sweep the detector left/right while walking (local only)
	if equippedTool then
		local swing = if reduced then 0 else math.sin(os.clock() * 2.2) * 0.22
		equippedTool.Grip = CFrame.Angles(0, swing, 0)
	end
end

---------------------------------------------------------------------------
function Detector:WatchCharacter(character: Model)
	equippedTool = nil
	local function check()
		local tool = character:FindFirstChildOfClass("Tool")
		local wasHeld = equippedTool ~= nil
		equippedTool = if tool and tool:GetAttribute("IsDetector") then tool else nil
		if equippedTool and not wasHeld then
			ui.Panel.Position = ui.PanelHome -- always exactly in its corner (no sliding)
		end
	end
	character.ChildAdded:Connect(check)
	character.ChildRemoved:Connect(check)
	check()
end

function Detector:Init(all)
	controllers = all
	self:BuildUI()
end

function Detector:Start()
	Net.Event("DetectorSignal").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or payload.ShovelOnly then
			return
		end
		signal = payload
		if signal.Active then
			self:UpdateReadout()
		end
	end)

	if player.Character then
		self:WatchCharacter(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		self:WatchCharacter(character)
	end)

	local appliedSetting = false
	controllers.State:OnChange(function(data)
		if not appliedSetting and data.Settings then
			appliedSetting = true
			self:SetMinimized(data.Settings.DetectorMinimized == true, false)
		end
		if signal.Active then
			self:UpdateReadout()
		end
	end)

	RunService.PreRender:Connect(function(dt)
		self:RenderStep(dt)
	end)
	-- refresh the text readout (direction words follow the camera)
	while true do
		task.wait(0.15)
		if equippedTool and signal.Active then
			self:UpdateReadout()
		end
	end
end

return Detector
