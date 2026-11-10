--[[
	EffectsController
	Reusable, performance-friendly visual effects (all local to this player):
	  Effects:SandBurst(position, amount?, color?)   sand kicked up by a shovel
	  Effects:Sparkles(position, color, amount?)     glittery burst
	  Effects:Shockwave(position, color, size?)      expanding ground ring
	  Effects:Beam(position, color, height?, rainbow?) light pillar
	  Effects:Flash(color, strength?)                full-screen flash (Legendary+)
	  Effects:Shake(strength, duration)              camera shake
	  Effects:Pop(guiObject, scale?)                 bouncy UI "pop"
	  Effects:Rays(parent, color)                    spinning sunburst behind a UI card
	  Effects:Confetti(color?, amount?)              UI confetti rain (rainbow if no colour)
	Everything respects the Reduced Motion setting.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent.Parent.UI.UIKit)

local Effects = {}

local player = Players.LocalPlayer
local controllers
local folder: Folder
local flashFrame: Frame
local shakeUntil = 0
local shakeStrength = 0

local RAINBOW = {
	Color3.fromRGB(255, 110, 110),
	Color3.fromRGB(255, 200, 90),
	Color3.fromRGB(255, 250, 120),
	Color3.fromRGB(110, 255, 160),
	Color3.fromRGB(110, 190, 255),
	Color3.fromRGB(200, 120, 255),
}
Effects.Rainbow = RAINBOW

function Effects:Reduced(): boolean
	local data = controllers and controllers.State.Data
	return data ~= nil and data.Settings.ReducedMotion == true
end

local function anchorPart(position: Vector3): Part
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.Position = position
	part.Parent = folder
	return part
end

local function cleanup(instance: Instance, after: number)
	task.delay(after, function()
		if instance.Parent then
			instance:Destroy()
		end
	end)
end

function Effects:SandBurst(position: Vector3, amount: number?, color: Color3?)
	local holder = anchorPart(position + Vector3.new(0, 0.3, 0))
	local base = color or Color3.fromRGB(232, 204, 146)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(base, base:Lerp(Color3.fromRGB(150, 120, 80), 0.4))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.15) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter.Speed = NumberRange.new(9, 16)
	emitter.SpreadAngle = Vector2.new(38, 38)
	emitter.Acceleration = Vector3.new(0, -42, 0)
	emitter.Lifetime = NumberRange.new(0.45, 0.85)
	emitter.Rotation = NumberRange.new(0, 360)
	emitter.Rate = 0
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = holder
	emitter:Emit(amount or 14)

	-- a few chunky grains that tumble out
	local grains = Instance.new("ParticleEmitter")
	grains.Color = ColorSequence.new(base:Lerp(Color3.new(0, 0, 0), 0.15))
	grains.Size = NumberSequence.new(0.18)
	grains.Speed = NumberRange.new(10, 18)
	grains.SpreadAngle = Vector2.new(50, 50)
	grains.Acceleration = Vector3.new(0, -60, 0)
	grains.Lifetime = NumberRange.new(0.5, 0.8)
	grains.Rate = 0
	grains.EmissionDirection = Enum.NormalId.Top
	grains.Parent = holder
	grains:Emit(math.floor((amount or 14) * 0.6))
	cleanup(holder, 2)
end

function Effects:Sparkles(position: Vector3, color: Color3, amount: number?, speed: number?)
	local holder = anchorPart(position)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color, Color3.new(1, 1, 1))
	emitter.LightEmission = 1
	emitter.LightInfluence = 0
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(4, speed or 12)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Lifetime = NumberRange.new(0.6, 1.3)
	emitter.Drag = 2
	emitter.Rate = 0
	emitter.Parent = holder
	emitter:Emit(amount or 20)
	cleanup(holder, 2.5)
end

function Effects:Shockwave(position: Vector3, color: Color3, size: number?)
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.25
	ring.Size = Vector3.new(0.15, 1, 1)
	ring.CFrame = CFrame.new(position + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	local final = size or 16
	TweenService:Create(ring, TweenInfo.new(0.7, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, final, final),
		Transparency = 1,
	}):Play()
	cleanup(ring, 0.8)
end

function Effects:Beam(position: Vector3, color: Color3, height: number?, rainbow: boolean?, duration: number?)
	local h = height or 30
	local beam = Instance.new("Part")
	beam.Shape = Enum.PartType.Cylinder
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.35
	beam.Size = Vector3.new(h, 0.3, 0.3)
	beam.CFrame = CFrame.new(position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = folder
	TweenService:Create(beam, TweenInfo.new(0.35, Enum.EasingStyle.Back), { Size = Vector3.new(h, 2.2, 2.2) }):Play()
	local life = duration or 2.6
	if rainbow then
		task.spawn(function()
			local t0 = os.clock()
			while beam.Parent and os.clock() - t0 < life do
				local index = math.floor((os.clock() - t0) * 8) % #RAINBOW + 1
				beam.Color = RAINBOW[index]
				task.wait(0.06)
			end
		end)
	end
	task.delay(life, function()
		TweenService:Create(beam, TweenInfo.new(0.6), { Transparency = 1, Size = Vector3.new(h, 0.1, 0.1) }):Play()
	end)
	cleanup(beam, life + 0.7)
end

function Effects:Flash(color: Color3, strength: number?)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = if self:Reduced() then 0.88 else 1 - (strength or 0.55)
	UIKit.Tween(flashFrame, 0.9, { BackgroundTransparency = 1 })
end

function Effects:Shake(strength: number, duration: number)
	if self:Reduced() then
		return
	end
	shakeStrength = math.max(shakeStrength, strength)
	shakeUntil = math.max(shakeUntil, os.clock() + duration)
	if shakeStrength > 0 and not self._shaking then
		self._shaking = true
		task.spawn(function()
			while os.clock() < shakeUntil do
				local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
				if humanoid then
					local s = shakeStrength * math.clamp((shakeUntil - os.clock()) / 0.3, 0.2, 1)
					humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * s, (math.random() - 0.5) * s, 0)
				end
				task.wait(0.025)
			end
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				humanoid.CameraOffset = Vector3.zero
			end
			shakeStrength = 0
			self._shaking = false
		end)
	end
end

-- Bouncy scale pop on any GuiObject (adds a UIScale the first time)
function Effects:Pop(object: GuiObject, scale: number?)
	-- reuse a UIKit slab's "Pop" scale: an object only honours one UIScale
	local uiScale = (object:FindFirstChild("Pop") or object:FindFirstChild("PopScale")) :: UIScale?
	if not uiScale then
		local created = Instance.new("UIScale")
		created.Name = "PopScale"
		created.Parent = object
		uiScale = created
	end
	local s = uiScale :: UIScale
	if self:Reduced() then
		s.Scale = 1
		return
	end
	s.Scale = scale or 1.25
	TweenService:Create(s, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

-- Sunburst behind a card; returns the frame (destroy it with the card)
function Effects:Rays(parent: GuiObject, color: Color3, size: number?): Frame
	local holder = UIKit.new("Frame", {
		Name = "Rays",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size or 420, size or 420),
		BackgroundTransparency = 1,
		ZIndex = 0,
		Parent = parent,
	})
	for i = 0, 5 do
		UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 34, 1, 0),
			Rotation = i * 30,
			BackgroundColor3 = color,
			BackgroundTransparency = 0.55,
			BorderSizePixel = 0,
			ZIndex = 0,
			Parent = holder,
		}, {
			UIKit.new("UIGradient", {
				Rotation = 90,
				Transparency = NumberSequence.new({
					NumberSequenceKeypoint.new(0, 1),
					NumberSequenceKeypoint.new(0.5, 0.2),
					NumberSequenceKeypoint.new(1, 1),
				}),
			}),
		})
	end
	if not self:Reduced() then
		task.spawn(function()
			while holder.Parent do
				holder.Rotation = (holder.Rotation + 0.6) % 360
				task.wait(1 / 30)
			end
		end)
	end
	return holder
end

function Effects:Confetti(color: Color3?, amount: number?)
	if self:Reduced() then
		return
	end
	local camera = Workspace.CurrentCamera
	local width = if camera then camera.ViewportSize.X else 1280
	for _ = 1, amount or 40 do
		local piece = UIKit.new("Frame", {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0, math.random(0, math.floor(width)), 0, -20),
			Size = UDim2.fromOffset(math.random(6, 11), math.random(10, 16)),
			Rotation = math.random(0, 360),
			BackgroundColor3 = color or RAINBOW[math.random(1, #RAINBOW)],
			BorderSizePixel = 0,
			Parent = UIKit.Overlay,
		})
		local fall = math.random(18, 30) / 10
		UIKit.Tween(piece, fall, {
			Position = UDim2.new(0, piece.Position.X.Offset + math.random(-120, 120), 1, 40),
			Rotation = piece.Rotation + math.random(-540, 540),
		}, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		cleanup(piece, fall + 0.1)
	end
end

-- A floating "+1" style label in the world (BillboardGui), e.g. "+12%" on each dig click
function Effects:FloatText(position: Vector3, text: string, color: Color3?)
	local holder = anchorPart(position)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(120, 34)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.StudsOffset = Vector3.new(0, 0, 0)
	gui.Parent = holder
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.35
	label.Parent = gui
	TweenService:Create(gui, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { StudsOffset = Vector3.new(math.random(-10, 10) / 10, 2.4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.7), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	cleanup(holder, 0.75)
end

function Effects:Init(all)
	controllers = all
	folder = Instance.new("Folder")
	folder.Name = "LocalEffects"
	folder.Parent = Workspace
	flashFrame = UIKit.new("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 50,
		Parent = UIKit.Overlay,
	})
end

return Effects
