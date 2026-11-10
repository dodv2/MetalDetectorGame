--[[
	DigController
	Tug-of-war excavation (the server owns progress; this file is feel + feedback).
	Resistance and the recommended shovel are HIDDEN, and so are numbers: you feel progress through
	the bar, the animation and the treasure slowly surfacing - never a percentage or a "+5".

	  1. At a 5/5 signal a marker appears on the sand with a custom "BEGIN EXCAVATION" prompt
	     (PromptController draws it; tap it on mobile, X on gamepad). Any shovel can dig any treasure.
	  2. E -> Dig("Start"). The shovel is passive gear: it appears in your hands for the dig (and the
	     detector comes back afterwards). Your character steps up to the hole, faces it and readies
	     the shovel (DigAnimatorController), and the Excavation Bar slides up above the hotbar.
	  3. Every LEFT CLICK (tap / R2) sends DigClick. Clicks faster than your shovel's speed are
	     queued, never lost. Each swing drives the shovel into the sand (sand bursts, clumps fly),
	     the bar's golden fill pushes on through the soil and the buried treasure glints brighter.
	  4. Update 17: NO grace period. The sand pulls the bar back all the time - even between fast
	     clicks - so your clicks have to outpace it. Click too slowly and the fill creeps backwards:
	     a striped red ghost shows what you just lost, the shovel chip flips to "◀" and the status
	     reads "◀ THE SAND IS PULLING BACK!" (an under-levelled shovel makes the pull much stronger).
	  5. Once the hole has a foothold the treasure is AT STAKE (a cave-in strip lights up at the
	     empty end of the bar). If the bar falls back to empty the treasure is lost for good:
	     "TREASURE LOST IN THE SAND", the hole caves in and nothing is awarded (server-side).
	  6. Full bar -> completion burst; the server puts the treasure straight into your backpack and
	     sends TreasureFound (RevealController).
	  Walking away or idling stops the dig, but the pull carries on - come back quickly or a started
	  hole is lost. A full backpack (10/10) can't start a dig - head back to the Pier to sell or display.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local GameMath = require(Shared.GameMath)
local TreasureModels = require(Shared.TreasureModels)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Dig = {}

local player = Players.LocalPlayer
local controllers
local ui = {} :: any
local TOUCH = UIKit.IsTouch()

-- dig spot reported by the server scan
local spot: Vector3? = nil
local spotSeen = 0

-- active session
local session = nil :: any
local shown = 0 -- progress shown on the dial (predicted / smoothed)
local serverProgress = 0
local decaying = false
local lastSend = 0
local pendingClick = false
local heldBefore: string? = nil
local lossMark = 0 -- the ghost of progress the sand just pulled back
local lossHold = 0
local trend = 0 -- smoothed speed of the bar (progress per second): < 0 = the sand is winning
local peekModel: Model? = nil -- the treasure itself, slowly surfacing (only you see it)
local peekHeight = 1
local connectedTools = setmetatable({}, { __mode = "k" })

local marker: Part
local prompt: ProximityPrompt
local markerRing: Part
local arrowGui: BillboardGui
local glint: Part? = nil

local SAND = Color3.fromRGB(240, 206, 140)
local GOLD = Color3.fromRGB(255, 196, 60)
local BRASS_DARK = Color3.fromRGB(150, 104, 44)

---------------------------------------------------------------------------
-- World marker + prompt
---------------------------------------------------------------------------
function Dig:BuildMarker()
	marker = Instance.new("Part")
	marker.Name = "DigMarker"
	marker.Anchored = true
	marker.CanCollide = false
	marker.CanQuery = false
	marker.CanTouch = false
	marker.Transparency = 1
	marker.Size = Vector3.new(1, 1, 1)
	marker.CFrame = CFrame.new(0, -500, 0)

	-- the prompt floats at chest height so it never hides behind the hotbar
	local promptAnchor = Instance.new("Attachment")
	promptAnchor.Name = "PromptAnchor"
	promptAnchor.Position = Vector3.new(0, 2.6, 0)
	promptAnchor.Parent = marker

	prompt = Instance.new("ProximityPrompt")
	prompt.Name = "DigPrompt"
	prompt.ActionText = "Begin Excavation"
	prompt.ObjectText = "Buried treasure detected"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = GameConfig.DigRadius + 3
	prompt.RequiresLineOfSight = false
	prompt.Exclusivity = Enum.ProximityPromptExclusivity.OneGlobally
	prompt.Style = Enum.ProximityPromptStyle.Custom -- drawn by PromptController
	prompt:SetAttribute("PromptKind", "Dig")
	prompt.Enabled = false
	prompt.Parent = promptAnchor
	prompt.Triggered:Connect(function()
		self:TryStart()
	end)

	markerRing = Instance.new("Part")
	markerRing.Name = "DigRing"
	markerRing.Shape = Enum.PartType.Cylinder
	markerRing.Anchored = true
	markerRing.CanCollide = false
	markerRing.CanQuery = false
	markerRing.CanTouch = false
	markerRing.Material = Enum.Material.Neon
	markerRing.Color = Color3.fromRGB(255, 214, 120)
	markerRing.Transparency = 1
	markerRing.Size = Vector3.new(0.1, 3, 3)
	markerRing.Parent = marker

	arrowGui = Instance.new("BillboardGui")
	arrowGui.Name = "Arrow"
	arrowGui.Size = UDim2.fromOffset(44, 44)
	arrowGui.StudsOffset = Vector3.new(0, 4.6, 0)
	arrowGui.AlwaysOnTop = true
	arrowGui.LightInfluence = 0
	arrowGui.Enabled = false
	arrowGui.Parent = marker
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Glyph"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.FredokaOne
	arrow.TextScaled = true
	arrow.Text = "▼"
	arrow.TextColor3 = Color3.fromRGB(255, 220, 130)
	arrow.TextStrokeTransparency = 0.25
	arrow.Parent = arrowGui

	marker.Parent = Workspace
end

local function setMarker(position: Vector3?)
	if position then
		marker.CFrame = CFrame.new(position + Vector3.new(0, 1.2, 0))
		markerRing.CFrame = CFrame.new(position + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	else
		marker.CFrame = CFrame.new(0, -500, 0)
		markerRing.CFrame = marker.CFrame
	end
end

function Dig:RefreshPrompt()
	local visible = spot ~= nil and session == nil
	prompt.Enabled = visible
	arrowGui.Enabled = visible
end

---------------------------------------------------------------------------
-- The Excavation Bar: a long brass-framed bar of layered soil above the hotbar.
-- Progress is FELT, never counted: the golden fill pushes through the soil layers, a little
-- shovel rides its leading edge, sand sprays off on every swing, and it bursts when done.
-- (No percentages, no numbers, no "+5", no resistance info.)
---------------------------------------------------------------------------
local BAR_WIDTH = 520
local TRACK_HEIGHT = 26

local function pill(props: { [string]: any }, children: { Instance }?): Frame
	local frame = UIKit.new("Frame", props, children)
	UIKit.Corner(TRACK_HEIGHT // 2).Parent = frame
	return frame
end

function Dig:BuildUI()
	local gauge = UIKit.new("Frame", {
		Name = "ExcavationBar",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -98),
		Size = UDim2.fromOffset(BAR_WIDTH, 66),
		BackgroundTransparency = 1,
		Visible = false,
		Parent = UIKit.Screen,
	})
	UIKit.AddScale(gauge)
	ui.Gauge = gauge
	ui.Home = gauge.Position

	-- the brass plate (this is what pops on completion)
	local plate = UIKit.new("Frame", {
		Name = "Plate",
		Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = GOLD,
		Parent = gauge,
	}, {
		UIKit.Corner(18),
		UIKit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 150)),
				ColorSequenceKeypoint.new(0.5, GOLD),
				ColorSequenceKeypoint.new(1, BRASS_DARK),
			}),
		}),
	})
	ui.Body = plate
	ui.PlateStroke = UIKit.Stroke(Color3.fromRGB(70, 44, 18), 2, 0.15)
	ui.PlateStroke.Parent = plate
	-- rivets
	for _, x in { 10, BAR_WIDTH - 10 } do
		for _, y in { 10, 56 } do
			UIKit.new("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(6, 6),
				BackgroundColor3 = Color3.fromRGB(255, 240, 190),
				ZIndex = 2,
				Parent = plate,
			}, { UIKit.Round(), UIKit.Stroke(BRASS_DARK, 1, 0.3) })
		end
	end

	-- title + status words
	ui.Title = UIKit.Text({
		Text = "EXCAVATING",
		Font = Theme.Fonts.Title,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(70, 42, 14),
		Position = UDim2.fromOffset(22, 3),
		Size = UDim2.fromOffset(200, 18),
		TextWrapped = false,
		ZIndex = 3,
		Parent = plate,
	})
	ui.Status = UIKit.Text({
		Text = "",
		Font = Theme.Fonts.Title,
		TextSize = 14,
		TextColor3 = Color3.fromRGB(70, 42, 14),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -46, 0, 3),
		Size = UDim2.fromOffset(220, 18),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextWrapped = false,
		ZIndex = 3,
		Parent = plate,
	})

	-- the soil track: three strata with pebbles
	local track = pill({
		Name = "Track",
		Position = UDim2.fromOffset(14, 24),
		Size = UDim2.new(1, -28, 0, TRACK_HEIGHT),
		BackgroundColor3 = Color3.fromRGB(92, 64, 38),
		ClipsDescendants = true,
		ZIndex = 3,
		Parent = plate,
	}, { UIKit.Stroke(Color3.fromRGB(60, 38, 16), 2, 0.1) })
	for index, layer in { { 0, 0.34, Color3.fromRGB(122, 88, 54) }, { 0.34, 0.36, Color3.fromRGB(176, 140, 92) }, { 0.7, 0.3, Color3.fromRGB(140, 98, 66) } } do
		UIKit.new("Frame", {
			Name = "Layer" .. index,
			Position = UDim2.fromScale(0, layer[1]),
			Size = UDim2.fromScale(1, layer[2]),
			BackgroundColor3 = layer[3],
			BorderSizePixel = 0,
			ZIndex = 3,
			Parent = track,
		})
	end
	local rng = Random.new(7)
	for _ = 1, 26 do
		local size = rng:NextInteger(3, 6)
		UIKit.new("Frame", {
			Position = UDim2.new(rng:NextNumber(0, 0.98), 0, rng:NextNumber(0.1, 0.85), 0),
			Size = UDim2.fromOffset(size, size - 1),
			BackgroundColor3 = Color3.fromRGB(80, 56, 34):Lerp(Color3.fromRGB(210, 180, 130), rng:NextNumber()),
			BackgroundTransparency = 0.2,
			ZIndex = 3,
			Parent = track,
		}, { UIKit.Round() })
	end
	-- depth notches (just marks - no numbers)
	for _, at in { 0.25, 0.5, 0.75 } do
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(at, 0.5),
			Size = UDim2.new(0, 2, 0.6, 0),
			BackgroundColor3 = Color3.fromRGB(50, 30, 12),
			BackgroundTransparency = 0.45,
			BorderSizePixel = 0,
			ZIndex = 4,
			Parent = track,
		})
	end

	-- the cave-in strip: once the treasure is at stake, the empty end of the bar glows red
	ui.Danger = UIKit.new("Frame", {
		Name = "CaveIn",
		Size = UDim2.new(0.07, 0, 1, 0),
		BackgroundColor3 = Color3.fromRGB(196, 40, 30),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = track,
	}, {
		UIKit.new("UIGradient", {
			Transparency = NumberSequence.new(0, 1),
		}),
	})

	-- the ghost of lost progress: striped red, it lingers where the fill was and then drains
	local loss = pill({
		Name = "Loss",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.fromRGB(214, 64, 52),
		BackgroundTransparency = 0.15,
		ClipsDescendants = true,
		Visible = false,
		ZIndex = 5,
		Parent = track,
	})
	for i = 0, 40 do
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, i * 14, 0.5, 0),
			Size = UDim2.fromOffset(5, TRACK_HEIGHT * 2),
			Rotation = 35,
			BackgroundColor3 = Color3.fromRGB(255, 220, 210),
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 5,
			Parent = loss,
		})
	end
	ui.Loss = loss

	-- the golden fill that pushes through the soil
	local fill = pill({
		Name = "Fill",
		Size = UDim2.fromScale(0, 1),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = track,
	})
	ui.FillGradient = UIKit.new("UIGradient", {
		Color = ColorSequence.new(SAND, GOLD),
		Parent = fill,
	})
	ui.Fill = fill
	-- a highlight that keeps sweeping along the fill
	local sheen = UIKit.new("Frame", {
		Name = "Sheen",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0, 0),
		Size = UDim2.new(0, 60, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.45,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = fill,
	}, {
		UIKit.new("UIGradient", {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.5, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}),
	})
	ui.Sheen = sheen
	-- a glossy top edge on the fill
	UIKit.new("Frame", {
		Position = UDim2.fromOffset(0, 3),
		Size = UDim2.new(1, 0, 0, 5),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.6,
		BorderSizePixel = 0,
		ZIndex = 6,
		Parent = fill,
	})

	-- the little shovel riding the leading edge
	local edgeHolder = UIKit.new("Frame", {
		Name = "EdgeHolder",
		Position = UDim2.fromOffset(14, 24),
		Size = UDim2.new(1, -28, 0, TRACK_HEIGHT),
		BackgroundTransparency = 1,
		ZIndex = 7,
		Parent = plate,
	})
	ui.Edge = UIKit.new("Frame", {
		Name = "Edge",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(34, 34),
		BackgroundColor3 = Color3.fromRGB(255, 244, 214),
		ZIndex = 8,
		Parent = edgeHolder,
	}, { UIKit.Round(), UIKit.Stroke(Color3.fromRGB(70, 44, 18), 2, 0.1) })
	ui.EdgeIcon = UIKit.Text({
		Text = "⛏",
		TextSize = 20,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 9,
		Parent = ui.Edge,
	})

	-- cancel (small round brass nub, top-right)
	ui.Cancel = UIKit.new("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = Color3.fromRGB(255, 226, 150),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -24, 0, 12),
		Size = UDim2.fromOffset(20, 20),
		ZIndex = 8,
		Parent = plate,
		OnActivated = function()
			self:Cancel()
		end,
	}, { UIKit.Round(), UIKit.Stroke(Color3.fromRGB(70, 44, 18), 1.5, 0.2) })
	for _, angle in { 45, -45 } do
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(11, 2.5),
			Rotation = angle,
			BackgroundColor3 = Color3.fromRGB(60, 36, 14),
			BorderSizePixel = 0,
			ZIndex = 9,
			Parent = ui.Cancel,
		}, { UIKit.Corner(2) })
	end

	-- layer for sand grains
	ui.Fx = UIKit.new("Frame", { Name = "Fx", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 10, Parent = gauge })
end

function Dig:SetFill(progress: number, color: Color3)
	local p = math.clamp(progress, 0, 1)
	ui.Fill.Size = UDim2.fromScale(p, 1)
	ui.Fill.Visible = p > 0.002
	ui.Edge.Position = UDim2.fromScale(p, 0.5)
	ui.FillGradient.Color = ColorSequence.new(color:Lerp(SAND, 0.35), color)
end

function Dig:ShowGauge()
	ui.Gauge.Visible = true
	ui.Gauge.Position = ui.Home + UDim2.fromOffset(0, 30)
	UIKit.Tween(ui.Gauge, 0.25, { Position = ui.Home }, Enum.EasingStyle.Back)
	controllers.Effects:Pop(ui.Body, 0.8)
end

function Dig:HideGauge(delay: number?)
	task.delay(delay or 0, function()
		if session then
			return
		end
		UIKit.Tween(ui.Gauge, 0.2, { Position = ui.Home + UDim2.fromOffset(0, 40) })
		task.wait(0.2)
		if not session then
			ui.Gauge.Visible = false
			ui.Gauge.Position = ui.Home
		end
	end)
end

-- sand grains sprayed from the bar's leading edge
function Dig:SandGrains(count: number, color: Color3?)
	if controllers.Effects:Reduced() then
		return
	end
	local origin = ui.Edge.AbsolutePosition + ui.Edge.AbsoluteSize / 2 - ui.Gauge.AbsolutePosition
	local scale = math.max(0.01, ui.Gauge.AbsoluteSize.X / BAR_WIDTH)
	origin /= scale
	for _ = 1, count do
		local size = math.random(4, 7)
		local grain = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromOffset(origin.X, origin.Y),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = (color or SAND):Lerp(Color3.fromRGB(150, 110, 60), math.random() * 0.4),
			ZIndex = 10,
			Parent = ui.Fx,
		}, { UIKit.Round() })
		local angle = math.rad(math.random(200, 340)) -- spray upwards
		local distance = math.random(30, 60)
		UIKit.Tween(grain, 0.45, {
			Position = UDim2.fromOffset(origin.X + math.cos(angle) * distance, origin.Y + math.sin(angle) * distance),
			BackgroundTransparency = 1,
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		task.delay(0.5, function()
			grain:Destroy()
		end)
	end
end

local function setStatus(text: string, color: Color3?)
	ui.Status.Text = text
	ui.Status.TextColor3 = color or Color3.fromRGB(70, 42, 14)
end

---------------------------------------------------------------------------
-- Session
---------------------------------------------------------------------------
local function holePosition(): Vector3
	if session and session.Position then
		return session.Position
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.Position - Vector3.new(0, 3, 0) else Vector3.zero
end

local function glintColor(): Color3
	if session and session.Hint then
		return UIKit.RarityColor(session.Hint)
	end
	return Color3.fromRGB(255, 220, 120)
end

-- The treasure slowly surfaces: a glinting lump that rises, grows and sparkles with progress
local function clearPeek()
	if peekModel then
		peekModel:Destroy()
		peekModel = nil
	end
end

-- Past ~30% the server says what's down there: the real treasure model starts poking out of the
-- sand and rises with the excavation (it sinks back if the sand pulls back).
function Dig:ShowPeek(treasureId: string)
	if peekModel or not session then
		return
	end
	local ok, model = pcall(TreasureModels.Build, treasureId, { NoLights = true, Plain = true })
	if not ok or not model then
		return
	end
	local size = model:GetExtentsSize()
	local scale = 1.5 / math.max(size.X, size.Y, size.Z, 0.1)
	model:ScaleTo(scale)
	peekHeight = model:GetExtentsSize().Y
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.CastShadow = true
		end
	end
	model.Name = "SurfacingTreasure"
	model.Parent = Workspace
	peekModel = model
	controllers.Effects:SandBurst(holePosition(), 12)
end

function Dig:UpdateGlint()
	if not session then
		if glint then
			glint:Destroy()
			glint = nil
		end
		clearPeek()
		return
	end
	if peekModel then
		-- from just under the surface at the first peek to half out of the sand at the end
		local p = math.clamp((shown - 0.25) / 0.75, 0, 1)
		local y = -peekHeight * 0.55 + p * peekHeight * 0.5
		peekModel:PivotTo(CFrame.new(holePosition() + Vector3.new(0, y, 0)) * CFrame.Angles(math.rad(-18), math.rad(30), math.rad(12)))
	end
	if not glint then
		local part = Instance.new("Part")
		part.Name = "TreasureGlint"
		part.Shape = Enum.PartType.Ball
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.Material = Enum.Material.Neon
		part.Size = Vector3.new(0.5, 0.5, 0.5)
		part.Color = glintColor()
		part.Transparency = 1
		part.Parent = Workspace
		local light = Instance.new("PointLight")
		light.Color = part.Color
		light.Brightness = 0
		light.Range = 8
		light.Parent = part
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		sparkle.Color = ColorSequence.new(part.Color)
		sparkle.LightEmission = 1
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Speed = NumberRange.new(1, 3)
		sparkle.SpreadAngle = Vector2.new(60, 60)
		sparkle.Lifetime = NumberRange.new(0.4, 0.8)
		sparkle.Rate = 0
		sparkle.Parent = part
		glint = part
	end
	local part = glint :: Part
	local p = shown
	local size = 0.5 + p * 0.7
	part.Size = Vector3.new(size, size, size)
	part.Position = holePosition() + Vector3.new(0, -0.9 + p * 1.25, 0)
	part.Transparency = math.clamp(1 - p * 1.6, 0, 1)
	local light = part:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = p * 2.4
	end
	local sparkle = part:FindFirstChildOfClass("ParticleEmitter")
	if sparkle then
		sparkle.Rate = if p > 0.4 then 4 + p * 16 else 0
	end
end

function Dig:TryStart()
	if session then
		return
	end
	local held = controllers.Hotbar:Held()
	if held ~= "Shovel" then
		heldBefore = held -- (if a previous dig left the shovel in hand, keep the older answer)
	end
	local result = controllers.State:Call("Dig", "Start")
	if not result.Ok then
		return
	end
	local idle = math.max(0, tonumber(result.Idle) or 0)
	session = {
		Position = result.Position,
		Gain = result.Gain or 0.1,
		DecayRate = result.DecayRate or 0.1,
		IdleBoost = result.IdleBoost or 1,
		IdleRamp = result.IdleRamp or 1.2,
		MinInterval = result.MinInterval or 0.15,
		Speed = result.Speed or 6,
		AtStake = result.AtStake == true,
		Hint = result.Hint,
		LastClick = os.clock() - idle,
		PrevIdle = idle,
		Clicks = 0,
	}
	serverProgress = result.Progress or 0
	shown = serverProgress
	lossMark = shown
	trend = 0
	decaying = false
	pendingClick = false
	self:RefreshPrompt()

	-- the passive shovel goes into your hands for the dig (the server does the same)
	controllers.Hotbar:Equip("Shovel", true)
	-- no words for how hard it is: the bar's movement tells you (resistance stays hidden)
	setStatus(if TOUCH then "TAP FAST TO DIG!" else "CLICK FAST TO DIG!")
	if result.Peek then
		self:ShowPeek(result.Peek)
	end
	ui.Title.Text = "EXCAVATING"
	self:SetFill(shown, SAND)
	self:ShowGauge()
	self:Approach(session.Position)
	controllers.DigAnimator:SetActive(player.Character, session.Position, session.Speed)
	controllers.Effects:SandBurst(session.Position, 10)
	controllers.Sound:Play("Dig", 0.8)
end

function Dig:Cancel()
	if not session then
		return
	end
	task.spawn(function()
		controllers.State:Call("Dig", "Stop")
	end)
end

function Dig:End(reason: string?, done: boolean, atStake: boolean?)
	local finished = session
	session = nil
	pendingClick = false
	decaying = false
	lossMark = 0
	ui.Loss.Visible = false
	ui.Danger.BackgroundTransparency = 1
	ui.EdgeIcon.Text = "⛏"
	if done then
		-- the reveal takes over from the surfacing treasure
		local model = peekModel
		peekModel = nil
		if model then
			task.delay(0.15, function()
				model:Destroy()
			end)
		end
	end
	controllers.DigAnimator:SetActive(player.Character, nil)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.AutoRotate = true
	end
	if done and finished then
		shown = 1
		self:SetFill(1, Color3.fromRGB(255, 244, 200))
		task.delay(0.12, function()
			if ui.Fill.Size.X.Scale >= 0.99 then
				self:SetFill(1, GOLD)
			end
		end)
		ui.Title.Text = "UNEARTHED!"
		setStatus("TREASURE FOUND!", Color3.fromRGB(70, 42, 14))
		ui.PlateStroke.Color = Color3.new(1, 1, 1)
		controllers.Effects:Pop(ui.Body, 1.15)
		self:SandGrains(18, GOLD)
		controllers.Effects:SandBurst(finished.Position, 34)
		controllers.DigAnimator:Erupt(finished.Position)
		controllers.Effects:Shockwave(finished.Position, glintColor(), 10)
		controllers.Effects:Shake(0.35, 0.18)
		self:HideGauge(0.85)
	else
		if reason and atStake then
			controllers.Notify:Toast("⚠ " .. reason .. " The sand is filling the hole back in - get back and dig, or the treasure is lost!", "Warning", 4)
		elseif reason then
			controllers.Notify:Toast("⛏ " .. reason, "Info", 3)
		end
		self:HideGauge(0.2)
	end
	self:UpdateGlint()
	self:RefreshPrompt()
	-- put the detector back in your hands so you can keep hunting. The shovel is passive gear, so
	-- it never stays in your hands after a dig (even if the dig was interrupted or restarted).
	local restore = heldBefore
	task.delay(if done then 1.4 else 0.3, function()
		if session then
			return
		end
		if restore ~= "Treasure" or controllers.Hotbar:Held() == "Shovel" then
			controllers.Hotbar:Equip("Detector", true)
		end
	end)
end

-- "TREASURE LOST IN THE SAND": the hole caves in, the half-surfaced treasure sinks away and a
-- sandy plaque shudders on screen before sliding down out of view (sand trickling off it).
function Dig:ShowLost(payload, sinking: Model?)
	local position = if typeof(payload.Position) == "Vector3" then payload.Position else nil
	if position then
		controllers.DigAnimator:Collapse(position)
		controllers.Effects:SandBurst(position, 28)
	end
	if sinking then
		task.spawn(function()
			local start = sinking:GetPivot()
			local t0 = os.clock()
			while sinking.Parent and os.clock() - t0 < 0.9 do
				local a = (os.clock() - t0) / 0.9
				sinking:PivotTo(start * CFrame.new(0, -a * a * (peekHeight + 1), 0) * CFrame.Angles(0, a * 0.8, 0))
				RunService.Heartbeat:Wait()
			end
			sinking:Destroy()
		end)
	end
	controllers.Effects:Shake(0.32, 0.4)
	controllers.Sound:Play("Dig", 0.35)

	if ui.LostCard then
		ui.LostCard:Destroy()
	end
	local card = UIKit.new("Frame", {
		Name = "TreasureLost",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.36),
		Size = UDim2.fromOffset(470, 104),
		BackgroundColor3 = Color3.fromRGB(214, 176, 118),
		ZIndex = 40,
		Parent = UIKit.Screen,
	}, {
		UIKit.Corner(16),
		UIKit.Stroke(Color3.fromRGB(84, 50, 22), 3, 0.05),
		UIKit.new("UIGradient", {
			Rotation = 90,
			Color = ColorSequence.new(Color3.fromRGB(240, 212, 160), Color3.fromRGB(176, 132, 82)),
		}),
	})
	UIKit.AddScale(card)
	ui.LostCard = card
	UIKit.Text({
		Text = "TREASURE LOST IN THE SAND",
		Font = Theme.Fonts.Title,
		TextSize = 30,
		TextColor3 = Color3.fromRGB(120, 26, 18),
		Position = UDim2.fromOffset(0, 14),
		Size = UDim2.new(1, 0, 0, 36),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 41,
		Parent = card,
	})
	UIKit.Text({
		Text = "The hole caved in and swallowed it - it's gone for good."
			.. (if type(payload.Tip) == "string" then "\n" .. payload.Tip else "\nKeep clicking faster than the sand pulls back."),
		Font = Theme.Fonts.Bold,
		TextSize = 15,
		TextColor3 = Color3.fromRGB(70, 40, 16),
		Position = UDim2.fromOffset(16, 52),
		Size = UDim2.new(1, -32, 0, 42),
		TextXAlignment = Enum.TextXAlignment.Center,
		ZIndex = 41,
		Parent = card,
	})
	-- shudder, then sink away with sand trickling off the bottom edge
	local reduced = controllers.Effects:Reduced()
	task.spawn(function()
		local home = card.Position
		if not reduced then
			for i = 1, 8 do
				card.Position = home + UDim2.fromOffset(math.random(-7, 7), math.random(-3, 3))
				card.Rotation = (if i % 2 == 0 then 1 else -1) * (2 - i * 0.2)
				task.wait(0.04)
			end
		end
		card.Position = home
		card.Rotation = 0
		if not reduced then
			for _ = 1, 22 do
				local grain = UIKit.new("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.new(math.random(), 0, 1, 0),
					Size = UDim2.fromOffset(math.random(3, 6), math.random(3, 6)),
					BackgroundColor3 = Color3.fromRGB(200, 160, 100):Lerp(Color3.fromRGB(120, 84, 44), math.random()),
					ZIndex = 42,
					Parent = card,
				}, { UIKit.Round() })
				local drop = math.random(30, 90)
				UIKit.Tween(grain, 0.9 + math.random() * 0.5, {
					Position = grain.Position + UDim2.fromOffset(math.random(-10, 10), drop),
					BackgroundTransparency = 1,
				}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			end
		end
		task.wait(2.6)
		if card.Parent then
			UIKit.Tween(card, 0.7, { Position = home + UDim2.fromOffset(0, 70), Size = UDim2.fromOffset(470, 0) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.wait(0.7)
			card:Destroy()
		end
	end)
end

-- One shovel swing (local feel) + the server message
function Dig:SendClick()
	if not session then
		return
	end
	lastSend = os.clock()
	session.LastClick = lastSend
	session.PrevIdle = 0
	session.Clicks += 1
	Net.Event("DigClick"):FireServer()

	-- predict progress so the bar reacts instantly (the server corrects it)
	shown = math.min(0.99, shown + session.Gain)
	decaying = false

	-- the swing itself (lean in, chop, pry, toss) - the animation drives the sand bursts
	controllers.DigAnimator:Swing(player.Character)
	controllers.Sound:Play("Dig", 0.55 + math.random() * 0.2 + shown * 0.25)
	controllers.Effects:Pop(ui.Edge, 1.35)
	self:SandGrains(5)
	if not controllers.Effects:Reduced() then
		ui.Edge.Rotation = -28
		UIKit.Tween(ui.Edge, 0.2, { Rotation = 0 }, Enum.EasingStyle.Back)
	end
end

-- Step up to the hole and face it, like the person in the photo: blade in front of your feet
local STAND_DISTANCE = 4.2 -- studs from the hole, so the long shovel's blade lands in it
function Dig:Approach(hole: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then
		return
	end
	local offset = ((root :: BasePart).Position - hole) * Vector3.new(1, 0, 1)
	local direction = if offset.Magnitude > 0.5 then offset.Unit else -(root :: BasePart).CFrame.LookVector * Vector3.new(1, 0, 1)
	if direction.Magnitude < 0.1 then
		direction = Vector3.new(0, 0, 1)
	end
	direction = direction.Unit
	local stand = hole + direction * STAND_DISTANCE
	local hum = humanoid :: Humanoid
	if math.abs(offset.Magnitude - STAND_DISTANCE) > 0.8 then
		hum:MoveTo(Vector3.new(stand.X, (root :: BasePart).Position.Y, stand.Z))
		local connection
		connection = hum.MoveToFinished:Connect(function()
			connection:Disconnect()
			if session then
				hum.AutoRotate = false
			end
		end)
		task.delay(1.2, function()
			if connection.Connected then
				connection:Disconnect()
			end
			if session then
				hum.AutoRotate = false
			end
		end)
	else
		hum.AutoRotate = false
	end
end

-- keep facing the hole while digging (only when you're not walking)
function Dig:FaceHole(dt: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not session or not root or not humanoid or (humanoid :: Humanoid).AutoRotate then
		return
	end
	if (humanoid :: Humanoid).MoveDirection.Magnitude > 0.1 then
		(humanoid :: Humanoid).AutoRotate = true -- walking off: let the character turn normally again
		return
	end
	local position = (root :: BasePart).Position
	local look = (session.Position - position) * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.3 then
		return
	end
	local goal = CFrame.lookAt(position, position + look.Unit)
	local body = root :: BasePart
	body.CFrame = body.CFrame:Lerp(goal, math.min(1, dt * 10))
end

function Dig:OnActivated()
	if not session then
		if spot then
			controllers.Notify:Toast(if TOUCH then "Tap “Begin Excavation” first" else "Press [E] to begin excavating here", "Info", 2)
		end
		return
	end
	if os.clock() - lastSend >= session.MinInterval then
		self:SendClick()
	else
		pendingClick = true -- swing as soon as your shovel allows
	end
end

function Dig:WatchTools(character: Model)
	local function hook(child: Instance)
		if child:IsA("Tool") and child:GetAttribute("IsShovel") and not connectedTools[child] then
			connectedTools[child] = true
			child.Activated:Connect(function()
				self:OnActivated()
			end)
		end
		-- switching to another tool mid-dig abandons the dig
		if child:IsA("Tool") and not child:GetAttribute("IsShovel") and session then
			self:Cancel()
		end
	end
	character.ChildAdded:Connect(hook)
	for _, child in character:GetChildren() do
		hook(child)
	end
end

---------------------------------------------------------------------------
-- Per frame
---------------------------------------------------------------------------
function Dig:RenderStep(dt: number)
	local now = os.clock()
	-- forget a dig spot we haven't heard about for a moment
	if spot and not session and now - spotSeen > 0.7 then
		spot = nil
		setMarker(nil)
		self:RefreshPrompt()
	end

	local reduced = controllers.Effects:Reduced()
	if spot and not session then
		local beat = if reduced then 0.5 else (math.sin(now * 5) * 0.5 + 0.5)
		markerRing.Transparency = 0.3 + beat * 0.4
		local d = 2.6 + beat * 1.2
		markerRing.Size = Vector3.new(0.08, d, d)
		arrowGui.StudsOffset = Vector3.new(0, 4.4 + (if reduced then 0 else math.abs(math.sin(now * 4)) * 0.6), 0)
	else
		markerRing.Transparency = 1
	end

	if not session then
		return
	end
	if pendingClick and now - lastSend >= session.MinInterval then
		pendingClick = false
		self:SendClick()
	end
	-- local preview of the pull, same maths as the server (its messages keep this honest).
	-- It never stops: there's no grace period, so the bar always creeps back between clicks.
	local before = shown
	local idle = now - session.LastClick
	local pulled = GameMath.DigDecay(session, session.PrevIdle, idle)
	session.PrevIdle = idle
	if pulled > 0 and shown > 0 then
		shown = math.max(0, shown - pulled)
	end
	-- is the sand winning? (the bar's smoothed speed over the last ~half second, clicks included)
	if dt > 0 then
		trend += ((shown - before) / dt - trend) * math.min(1, dt * 2.2)
	end
	decaying = shown > 0 and (trend < -session.Gain * 0.15 or idle > 0.45)

	-- the striped ghost holds what you just lost, then drains away once you dig again
	if shown < lossMark - 0.001 then
		if decaying then
			lossHold = now
		elseif now - lossHold > 0.5 then
			lossMark = math.max(shown, lossMark - dt * 0.8)
		end
	else
		lossMark = shown
	end
	ui.Loss.Size = UDim2.fromScale(math.clamp(lossMark, 0, 1), 1)
	ui.Loss.Visible = lossMark - shown > 0.004

	-- at stake: the empty end of the bar glows, brighter the closer the fill gets to it
	if session.AtStake then
		local danger = math.clamp(1 - shown / 0.3, 0, 1)
		local pulse = if reduced then 0.5 else (math.sin(now * 9) * 0.5 + 0.5)
		ui.Danger.BackgroundTransparency = 0.75 - danger * (0.35 + 0.3 * pulse)
	end

	local color
	if decaying then
		local pulse = if reduced then 0.5 else (math.sin(now * 12) * 0.5 + 0.5)
		color = Theme.Colors.Coral:Lerp(Theme.Colors.Orange, pulse)
		if session.AtStake and shown < 0.22 then
			setStatus("⚠ IT'S CAVING IN - DIG!", Color3.fromRGB(170, 30, 20))
		else
			setStatus("◀ THE SAND IS PULLING BACK!", Color3.fromRGB(170, 40, 30))
		end
		ui.PlateStroke.Color = Theme.Colors.Coral
		ui.EdgeIcon.Text = "◀"
		ui.Edge.BackgroundColor3 = Color3.fromRGB(255, 196, 180)
		if not reduced then
			ui.Edge.Rotation = math.sin(now * 30) * 10 -- the shovel chip shudders backwards
		end
	else
		color = SAND:Lerp(GOLD, shown)
		ui.PlateStroke.Color = Color3.fromRGB(70, 44, 18)
		ui.EdgeIcon.Text = "⛏"
		ui.Edge.BackgroundColor3 = Color3.fromRGB(255, 244, 214)
		if session.Clicks > 0 then
			setStatus(if shown > 0.75 then "ALMOST THERE!" elseif shown > 0.35 then "IT'S LOOSENING!" else "DIG, DIG, DIG!")
		end
	end
	self:SetFill(shown, color)
	-- the highlight keeps sweeping along the fill
	if not reduced then
		ui.Sheen.Position = UDim2.fromScale((now * 0.6) % 1.4 - 0.2, 0)
	end
	self:FaceHole(dt)

	-- warn before the server cancels for distance
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local offset = (root.Position - session.Position) * Vector3.new(1, 0, 1)
		if offset.Magnitude > GameConfig.Dig.MaxDistance * 0.7 then
			setStatus("⚠ TOO FAR FROM THE HOLE", Color3.fromRGB(170, 40, 30))
		end
	end
	self:UpdateGlint()
end

-- true if a hole at this position is the one you're digging right now
function Dig:IsDigging(): boolean
	return session ~= nil
end

function Dig:IsMyHole(position: Vector3): boolean
	return session ~= nil and ((session.Position - position) * Vector3.new(1, 0, 1)).Magnitude < 1
end

---------------------------------------------------------------------------
function Dig:Init(all)
	controllers = all
	self:BuildMarker()
	self:BuildUI()
end

function Dig:Start()
	Net.Event("DetectorSignal").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Active and payload.Level == 5 and typeof(payload.DigSpot) == "Vector3" then
			local changed = spot == nil or (spot :: Vector3 - payload.DigSpot).Magnitude > 0.1
			spot = payload.DigSpot
			spotSeen = os.clock()
			if changed then
				setMarker(spot)
				self:RefreshPrompt()
			end
		end
	end)

	Net.Event("DigProgress").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.Lost then
			-- permanent failure (decided by the server): the treasure is gone for good
			local sinking = peekModel
			peekModel = nil
			if session then
				self:End(nil, false)
			end
			self:ShowLost(payload, sinking)
			return
		end
		if payload.Ended then
			if session then
				self:End(payload.Reason, false, payload.AtStake == true)
			end
			return
		end
		if payload.Done then
			serverProgress = 1
			if session then
				self:End(nil, true)
			end
			return
		end
		if not session then
			return
		end
		serverProgress = payload.Progress or serverProgress
		if payload.AtStake and not session.AtStake then
			session.AtStake = true
			controllers.Effects:Pop(ui.Body, 1.06)
		end
		if type(payload.Peek) == "string" then
			self:ShowPeek(payload.Peek)
		end
		if payload.Decaying then
			-- the server's pull ticks: ease towards its value (not while the clicks are in flight)
			if os.clock() - lastSend > 0.3 then
				shown = shown + (serverProgress - shown) * 0.5
			end
		elseif os.clock() - lastSend > 0.35 or serverProgress > shown then
			shown = serverProgress
		end
	end)

	if player.Character then
		self:WatchTools(player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		if session then
			self:End(nil, false)
		end
		self:WatchTools(character)
	end)

	RunService.PreRender:Connect(function(dt)
		self:RenderStep(dt)
	end)
end

return Dig
