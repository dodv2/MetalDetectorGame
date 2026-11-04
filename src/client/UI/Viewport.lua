--[[
	Viewport
	3D treasure icons for the UI (a ViewportFrame showing the treasure model).
]]

local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local TreasureModels = require(Shared.TreasureModels)

local Viewport = {}

local spinning: { [ViewportFrame]: Model } = {}

export type Options = { Silhouette: boolean?, Spin: boolean?, Tilt: number? }

function Viewport.Create(treasureId: string, options: Options?): ViewportFrame
	local opts = options or {}
	local frame = Instance.new("ViewportFrame")
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.LightColor = Color3.fromRGB(255, 250, 240)
	frame.LightDirection = Vector3.new(-0.4, -1, 0.6)
	frame.Ambient = Color3.fromRGB(150, 155, 170)

	local model = TreasureModels.Build(treasureId, { Silhouette = opts.Silhouette, NoLights = true })
	model.Parent = frame

	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = frame
	frame.CurrentCamera = camera

	local boxCFrame, size = model:GetBoundingBox()
	local radius = math.max(size.Magnitude / 2, 0.5)
	local distance = radius / math.tan(math.rad(15)) * 1.05
	local center = boxCFrame.Position
	local tilt = opts.Tilt or 0.3
	camera.CFrame = CFrame.lookAt(center + Vector3.new(0, radius * tilt, -distance), center)

	if opts.Spin then
		spinning[frame] = model
		frame.Destroying:Connect(function()
			spinning[frame] = nil
		end)
	end
	return frame
end

RunService.RenderStepped:Connect(function(dt)
	for frame, model in spinning do
		if frame.Parent and frame.Visible then
			model:PivotTo(model:GetPivot() * CFrame.Angles(0, dt * 1.2, 0))
		end
	end
end)

return Viewport
