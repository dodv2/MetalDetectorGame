--[[
	SharkModels
	Builds the smooth, rounded shark (ellipsoid body made from sphere meshes, wedge fins).
	Every part has a "Group" attribute so the client can animate it:
	  Body  - head, torso, fins          (moves with the shark)
	  Tail  - tail stalk + tail fin      (swings left/right around the tail joint)
	  Jaw   - lower jaw + teeth          (opens for the lunge)
	Local space: the shark faces -Z (like every Roblox model); ~14 studs long.
]]

local SharkModels = {}

local SKIN = Color3.fromRGB(92, 112, 132)
local SKIN_DARK = Color3.fromRGB(70, 88, 106)
local BELLY = Color3.fromRGB(236, 236, 230)
local MOUTH = Color3.fromRGB(205, 120, 120)

SharkModels.TailPivot = CFrame.new(0, 0, 3.9)
SharkModels.JawPivot = CFrame.new(0, -0.6, -2.9)

local function newPart(model: Model, name: string, group: string, size: Vector3, cf: CFrame, color: Color3, className: string?): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Massless = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Size = size
	part.CFrame = cf
	part.Color = color
	part:SetAttribute("Group", group)
	part.Parent = model
	return part
end

-- smooth ellipsoid (a block part wearing a sphere mesh)
local function ellipsoid(model: Model, name: string, group: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	local part = newPart(model, name, group, size, cf, color)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	return part
end

local function wedge(model: Model, name: string, group: string, size: Vector3, cf: CFrame, color: Color3): BasePart
	return newPart(model, name, group, size, cf, color, "WedgePart")
end

-- Water level and the depth a shark cruises at (only the dorsal fin breaks the surface)
SharkModels.WaterY = -0.5
SharkModels.SwimY = SharkModels.WaterY - 1.9

-- The patrol path, computed from the shared server clock so the server and every client agree
-- on where each shark is without streaming positions: a lazy figure-eight offshore of each beach,
-- or a loop around Secret Island. `attrs` reads a shark's Configuration attributes.
function SharkModels.PatrolPosition(config: Instance, t: number): Vector3
	local phase = config:GetAttribute("Phase") or 0
	if config:GetAttribute("Kind") == "Island" then
		local a = t * 0.13 + phase
		local rx = (config:GetAttribute("HalfX") or 95) + 14
		local rz = (config:GetAttribute("HalfZ") or 75) + 14
		return Vector3.new(config:GetAttribute("CX") + math.cos(a) * rx, SharkModels.SwimY, config:GetAttribute("CZ") + math.sin(a) * rz)
	end
	local a = t * 0.11 + phase
	local half = (config:GetAttribute("Width") or 150) * (config:GetAttribute("Reach") or 0.42)
	return Vector3.new(config:GetAttribute("CX") + math.sin(a) * half, SharkModels.SwimY, (config:GetAttribute("CZ") or -78) + math.sin(a * 2) * 13)
end

function SharkModels.Build(): Model
	local model = Instance.new("Model")
	model.Name = "Shark"

	-- body: layered ellipsoids give a smooth torpedo shape with a white underside
	local root = ellipsoid(model, "Body", "Body", Vector3.new(2.7, 2.5, 8.6), CFrame.new(0, 0, 0), SKIN)
	model.PrimaryPart = root
	ellipsoid(model, "Back", "Body", Vector3.new(2.2, 1.2, 7.4), CFrame.new(0, 0.75, 0.3), SKIN_DARK)
	ellipsoid(model, "Belly", "Body", Vector3.new(2.35, 1.7, 7.6), CFrame.new(0, -0.55, -0.3), BELLY)
	ellipsoid(model, "Snout", "Body", Vector3.new(2.0, 1.55, 3.4), CFrame.new(0, 0.05, -4.0), SKIN)
	ellipsoid(model, "SnoutUnder", "Body", Vector3.new(1.7, 0.9, 2.8), CFrame.new(0, -0.45, -3.8), BELLY)

	-- eyes + gills
	for _, side in { -1, 1 } do
		local eye = newPart(model, "Eye", "Body", Vector3.new(0.34, 0.34, 0.34), CFrame.new(side * 0.82, 0.32, -4.1), Color3.fromRGB(12, 14, 18))
		;(eye :: Part).Shape = Enum.PartType.Ball
		eye.Material = Enum.Material.Glass
		for i = 0, 2 do
			newPart(model, "Gill", "Body", Vector3.new(0.06, 0.8 - i * 0.08, 0.08), CFrame.new(side * 1.25, -0.05, -2.5 + i * 0.32) * CFrame.Angles(0, 0, side * 0.12), Color3.fromRGB(58, 72, 86))
		end
	end

	-- fins
	wedge(model, "DorsalFin", "Body", Vector3.new(0.24, 2.5, 2.6), CFrame.new(0, 2.15, 0.35), SKIN)
	for _, side in { -1, 1 } do
		wedge(model, "PectoralFin", "Body", Vector3.new(0.18, 0.8, 2.3), CFrame.new(side * 1.75, -0.75, -1.1) * CFrame.Angles(0, 0, side * 1.15) * CFrame.Angles(0, math.rad(180), 0), SKIN)
	end
	wedge(model, "PelvicFin", "Body", Vector3.new(0.14, 0.6, 1.1), CFrame.new(0, -1.15, 2.6) * CFrame.Angles(math.rad(180), 0, 0), SKIN)

	-- jaw (opens on the lunge)
	ellipsoid(model, "Jaw", "Jaw", Vector3.new(1.45, 0.5, 2.0), CFrame.new(0, -0.82, -3.45), MOUTH)
	for i = -2, 2 do
		local tooth = wedge(model, "Tooth", "Jaw", Vector3.new(0.12, 0.22, 0.12), CFrame.new(i * 0.22, -0.55, -4.2 + math.abs(i) * 0.18), Color3.fromRGB(250, 250, 245))
		tooth.Material = Enum.Material.SmoothPlastic
	end

	-- tail: stalk + crescent fin (swings around TailPivot)
	ellipsoid(model, "TailStalk", "Tail", Vector3.new(1.15, 1.2, 3.6), CFrame.new(0, 0.1, 5.4), SKIN)
	wedge(model, "TailUpper", "Tail", Vector3.new(0.22, 2.9, 1.9), CFrame.new(0, 1.35, 7.3) * CFrame.Angles(math.rad(-28), 0, 0), SKIN_DARK)
	wedge(model, "TailLower", "Tail", Vector3.new(0.22, 1.7, 1.4), CFrame.new(0, -0.75, 7.1) * CFrame.Angles(math.rad(200), 0, 0), SKIN_DARK)

	return model
end

return SharkModels
