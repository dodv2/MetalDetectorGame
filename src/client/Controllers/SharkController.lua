--[[
	SharkController
	Draws and animates the sharks on this client (the server moves hunting sharks and bites).

	* Patrol: every client computes the same smooth path from the server clock (SharkModels), so
	  all players see each shark in the same place. Only the dorsal fin breaks the surface.
	* Chase / Return (Update 17): the server simulates the shark and publishes PX / PZ / Heading;
	  the model glides there smoothly. On "BiteAt" it lunges out of the water, jaw open.
	* If YOU are the target: red pulsing screen edges + a "SHARK!" warning ribbon (visual, so it
	  works with sound off) and a heartbeat beep. A bite (SharkBite) splashes, shakes the camera
	  and flashes the screen red; the health bar in the HUD shows the damage.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SharkModels = require(Shared.SharkModels)
local Net = require(Shared.Net)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local SharkUI = {}

local player = Players.LocalPlayer
local controllers
local ui = {} :: any
local SWIM_Y = SharkModels.SwimY -- keeps just the dorsal fin above the surface

type SharkState = {
	Config: Configuration,
	Model: Model,
	Parts: { { Part: BasePart, Rel: CFrame, Group: string } },
	Position: Vector3,
	Heading: Vector3,
	Blend: number,
	Spray: ParticleEmitter,
}

local sharks: { SharkState } = {}
local lastBeat = 0

local function patrolPosition(config: Configuration, t: number): Vector3
	return SharkModels.PatrolPosition(config, t)
end

local function register(config: Instance)
	if not config:IsA("Configuration") then
		return
	end
	local model = SharkModels.Build()
	model.Name = config.Name
	local root = model.PrimaryPart :: BasePart
	local base = root.CFrame
	local parts = {}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			table.insert(parts, { Part = part, Rel = base:ToObjectSpace(part.CFrame), Group = tostring(part:GetAttribute("Group") or "Body") })
		end
	end
	-- water spray at the fin while chasing
	local spray = Instance.new("ParticleEmitter")
	spray.Texture = "rbxasset://textures/particles/smoke_main.dds"
	spray.Color = ColorSequence.new(Color3.fromRGB(230, 248, 255))
	spray.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	spray.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 1.8) })
	spray.Speed = NumberRange.new(3, 6)
	spray.SpreadAngle = Vector2.new(40, 40)
	spray.Lifetime = NumberRange.new(0.4, 0.7)
	spray.Rate = 0
	spray.EmissionDirection = Enum.NormalId.Top
	local fin = model:FindFirstChild("DorsalFin")
	spray.Parent = if fin then fin else root
	-- place it on its patrol path straight away: the model is built at the world origin (which is
	-- on Starting Beach), and sharks far from the camera aren't animated, so they must never stay there
	local start = patrolPosition(config :: Configuration, Workspace:GetServerTimeNow())
	local ahead = patrolPosition(config :: Configuration, Workspace:GetServerTimeNow() + 0.5) - start
	local heading = if Vector3.new(ahead.X, 0, ahead.Z).Magnitude > 1e-3 then Vector3.new(ahead.X, 0, ahead.Z).Unit else Vector3.new(1, 0, 0)
	local body = CFrame.lookAt(start, start + heading)
	for _, entry in parts do
		entry.Part.CFrame = body * entry.Rel
	end
	model.Parent = Workspace
	table.insert(sharks, {
		Config = config :: Configuration,
		Model = model,
		Parts = parts,
		Position = start,
		Heading = heading,
		Blend = 0,
		Spray = spray,
	})
end

local function targetRoot(userId: number): BasePart?
	if userId == 0 then
		return nil
	end
	local target = Players:GetPlayerByUserId(userId)
	local character = target and target.Character
	return character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

function SharkUI:Animate(dt: number)
	local serverNow = Workspace:GetServerTimeNow()
	local camera = Workspace.CurrentCamera
	local reduced = controllers.Effects:Reduced()
	local hunted = false
	for _, shark in sharks do
		local config = shark.Config
		local targetId = config:GetAttribute("TargetUserId") or 0
		local root = targetRoot(targetId)
		local biteAt = config:GetAttribute("BiteAt") or 0
		local sinceBite = serverNow - biteAt
		if targetId == player.UserId then
			hunted = true
		end

		local mode = config:GetAttribute("Mode") or "Patrol"
		local desired: Vector3
		local speed: number
		local px, pz = config:GetAttribute("PX"), config:GetAttribute("PZ")
		if mode ~= "Patrol" and type(px) == "number" and type(pz) == "number" then
			-- the server is steering it: glide to its latest published position (10x a second)
			desired = Vector3.new(px, SWIM_Y, pz)
			speed = math.max(34, (desired - shark.Position).Magnitude * 8)
			shark.Blend = 1
		else
			desired = patrolPosition(config, serverNow)
			-- glide back onto the patrol path after a chase
			speed = if shark.Blend > 0 then 22 else 999
			if (desired - shark.Position).Magnitude < 2 then
				shark.Blend = 0
			end
		end

		local step = desired - shark.Position
		local move = if step.Magnitude > speed * dt then step.Unit * speed * dt else step
		local newPosition = shark.Position + move
		local heading = config:GetAttribute("Heading")
		if mode ~= "Patrol" and type(heading) == "number" and step.Magnitude < 3 then
			shark.Heading = shark.Heading:Lerp(Vector3.new(math.sin(heading), 0, math.cos(heading)), math.min(1, dt * 6)).Unit
		elseif move.Magnitude > 1e-3 then
			local flatMove = Vector3.new(move.X, 0, move.Z)
			if flatMove.Magnitude > 1e-3 then
				shark.Heading = shark.Heading:Lerp(flatMove.Unit, math.min(1, dt * 4)).Unit
			end
		end
		shark.Position = newPosition

		-- skip animating sharks nobody can see
		if camera and (camera.CFrame.Position - newPosition).Magnitude > 420 then
			continue
		end

		-- lunge on the bite
		local lift = 0
		local jaw = 0
		if sinceBite >= 0 and sinceBite < 0.9 then
			local k = math.sin(math.clamp(sinceBite / 0.9, 0, 1) * math.pi)
			lift = k * 3.2
			jaw = k * 0.6
		end
		local chasing = root ~= nil and mode == "Chase"
		local t = os.clock()
		local swing = if reduced then 0 else math.sin(t * (if chasing then 11 else 5) + (config:GetAttribute("Phase") or 0)) * (if chasing then 0.42 else 0.3)
		local sway = -swing * 0.25
		local body = CFrame.lookAt(newPosition + Vector3.new(0, lift, 0), newPosition + Vector3.new(0, lift, 0) + shark.Heading)
			* CFrame.Angles(lift > 0 and -0.35 or 0, sway, 0)
		local tailJoint = SharkModels.TailPivot
		local jawJoint = SharkModels.JawPivot
		for _, entry in shark.Parts do
			if entry.Group == "Tail" then
				entry.Part.CFrame = body * tailJoint * CFrame.Angles(0, swing, 0) * tailJoint:Inverse() * entry.Rel
			elseif entry.Group == "Jaw" then
				entry.Part.CFrame = body * jawJoint * CFrame.Angles(jaw, 0, 0) * jawJoint:Inverse() * entry.Rel
			else
				entry.Part.CFrame = body * entry.Rel
			end
		end
		shark.Spray.Rate = if chasing and not reduced then 30 else 0
	end

	-- warning for the hunted player (visual first, sound optional)
	ui.Warning.Visible = hunted
	local beat = if reduced then 0.5 else (math.sin(os.clock() * 9) * 0.5 + 0.5)
	for _, edge in ui.Edges do
		edge.BackgroundTransparency = if hunted then 1 - (0.25 + beat * 0.3) else 1
	end
	if hunted and os.clock() - lastBeat > 0.45 then
		lastBeat = os.clock()
		controllers.Sound:Play("Beep", 0.45, 0.8)
	end
end

function SharkUI:Init(all)
	controllers = all
	ui.Warning = UIKit.new("TextLabel", {
		Name = "SharkWarning",
		Text = "🦈 SHARK!  Swim back to the beach or the Pier!",
		Font = Theme.Fonts.Title,
		TextSize = 26,
		TextColor3 = Color3.new(1, 1, 1),
		BackgroundColor3 = Color3.fromRGB(200, 40, 50),
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 60),
		Size = UDim2.fromOffset(0, 44),
		AutomaticSize = Enum.AutomaticSize.X,
		Visible = false,
		ZIndex = 40,
		Parent = UIKit.Screen,
	}, { UIKit.Corner(14), UIKit.Padding(0, 18), UIKit.Stroke(Color3.new(1, 1, 1), 2, 0.3) })
	UIKit.TextStroke(0.3).Parent = ui.Warning
	UIKit.AddScale(ui.Warning)
	ui.Edges = {}
	for _, spec in {
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.new(1, 0, 0, 110), Rotation = 90 },
		{ Position = UDim2.new(0, 0, 1, -110), Size = UDim2.new(1, 0, 0, 110), Rotation = -90 },
		{ Position = UDim2.fromScale(0, 0), Size = UDim2.new(0, 110, 1, 0), Rotation = 0 },
		{ Position = UDim2.new(1, -110, 0, 0), Size = UDim2.new(0, 110, 1, 0), Rotation = 180 },
	} do
		table.insert(ui.Edges, UIKit.new("Frame", {
			Position = spec.Position,
			Size = spec.Size,
			BackgroundColor3 = Color3.fromRGB(220, 30, 40),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Parent = UIKit.Overlay,
		}, { UIKit.new("UIGradient", { Rotation = spec.Rotation, Transparency = NumberSequence.new(0, 1) }) }))
	end
end

-- A bite: splash at the swimmer, a jolt and a red flash (the HUD health bar shows the damage)
function SharkUI:Bitten(payload)
	local position = if type(payload) == "table" and typeof(payload.Position) == "Vector3" then payload.Position else nil
	if position then
		controllers.Effects:SandBurst(Vector3.new(position.X, SharkModels.WaterY, position.Z), 22, Color3.fromRGB(225, 245, 255))
		controllers.Effects:Shockwave(Vector3.new(position.X, SharkModels.WaterY + 0.1, position.Z), Color3.fromRGB(235, 250, 255), 9)
	end
	controllers.Effects:Shake(0.45, 0.3)
	controllers.Effects:Flash(Color3.fromRGB(220, 40, 40), 0.45)
	controllers.Sound:Play("Error", 0.6)
end

function SharkUI:Start()
	Net.Event("SharkBite").OnClientEvent:Connect(function(payload)
		self:Bitten(payload)
	end)
	local folder = Workspace:WaitForChild("Sharks", 60)
	if not folder then
		return
	end
	for _, config in folder:GetChildren() do
		register(config)
	end
	folder.ChildAdded:Connect(register)
	RunService.PreRender:Connect(function(dt)
		self:Animate(math.min(dt, 0.1))
	end)
end

return SharkUI
