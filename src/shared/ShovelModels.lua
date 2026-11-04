--[[
	ShovelModels
	Builds the shovel Tool that appears in the player's hands while they dig (shovels are passive
	gear - nobody equips them by hand). A real long-handled spade: D-grip with a Y-split and a
	crossbar, ferrule, tapered shaft (with grain on wooden ones), a riveted socket, a dished blade
	with a rounded point, rolled foot tread, centre ridge and a bright worn edge. Every shovel in
	Config > Equipment has its own Look (shaft/blade colours and materials, optional glow/sparkles).
]]

local Equipment = require(script.Parent.Config.Equipment)

local ShovelModels = {}

local function material(name: string?): Enum.Material
	if name then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[name]
		end)
		if ok and value then
			return value
		end
	end
	return Enum.Material.SmoothPlastic
end

local function newPart(props: { [string]: any }): BasePart
	local part = Instance.new("Part")
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- CFrame whose X axis runs from a to b (Roblox cylinders run along X)
local function alongX(a: Vector3, b: Vector3): CFrame
	return CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0)
end

function ShovelModels.BuildTool(shovelId: string): Tool
	local def = Equipment.ById.Shovel[shovelId] or Equipment.Shovels[1]
	local look = def.Look or {}
	local tier = def.Order or 1
	local shaftColor = look.Shaft or Color3.fromRGB(120, 85, 55)
	local shaftMaterial = material(look.ShaftMaterial)
	local bladeColor = look.Blade or Color3.fromRGB(150, 150, 155)
	local bladeMaterial = material(look.BladeMaterial)
	local glass = look.BladeMaterial == "Glass"
	local plastic = tier == 1
	local fitting = if plastic then bladeColor:Lerp(Color3.new(1, 1, 1), 0.2) else Color3.fromRGB(150, 152, 158)
	local fittingMaterial = if plastic then Enum.Material.SmoothPlastic else Enum.Material.Metal

	local tool = Instance.new("Tool")
	tool.Name = "Shovel"
	tool.ToolTip = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new()
	tool:SetAttribute("IsShovel", true)
	tool:SetAttribute("ShovelId", def.Id)

	-- the hand holds the shaft here (the Handle), the D-grip sits above/behind it
	local handle = newPart({
		Name = "Handle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 0.26, 0.26),
		Color = shaftColor,
		Material = shaftMaterial,
		CFrame = CFrame.new(),
	})
	handle.Parent = tool

	local parts = {}
	local function add(part: BasePart)
		part.Parent = tool
		table.insert(parts, part)
		return part
	end
	local function rod(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, mat: Enum.Material, extra: { [string]: any }?)
		local props: { [string]: any } = {
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(math.max((b - a).Magnitude, 0.02), diameter, diameter),
			CFrame = alongX(a, b),
			Color = color,
			Material = mat,
		}
		if extra then
			for key, value in extra do
				props[key] = value
			end
		end
		return add(newPart(props))
	end

	-- Shaft: from the D-grip above/behind the hand down to the blade in front of the feet
	local top = Vector3.new(0, 0.9, 0.9)
	local bottom = Vector3.new(0, -2.9, -2.3)
	local direction = (bottom - top).Unit
	local up = -direction
	local side = Vector3.new(1, 0, 0)
	-- slightly tapered: thicker near the blade, where it takes the load
	rod("ShaftUpper", top, top:Lerp(bottom, 0.5), 0.19, shaftColor, shaftMaterial)
	rod("ShaftLower", top:Lerp(bottom, 0.5), bottom, 0.215, shaftColor, shaftMaterial)
	if look.ShaftMaterial == "Wood" then
		-- a darker grain line down the wood
		rod("Grain", top + side * 0.09, bottom + side * 0.1, 0.03, shaftColor:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Wood, { CastShadow = false })
	end

	-- D-grip: the shaft splits into a Y and a crossbar closes the "D"
	local split = top + up * 0.12
	local left = top + up * 0.62 - side * 0.27
	local right = top + up * 0.62 + side * 0.27
	rod("Ferrule", top - up * 0.08, top + up * 0.12, 0.25, fitting, fittingMaterial)
	rod("GripArm", split, left, 0.12, shaftColor, shaftMaterial)
	rod("GripArm", split, right, 0.12, shaftColor, shaftMaterial)
	rod("GripBar", left - side * 0.05, right + side * 0.05, 0.19, if plastic then bladeColor else Color3.fromRGB(40, 32, 26), if plastic then Enum.Material.SmoothPlastic else Enum.Material.Fabric)
	for _, point in { left, right } do
		add(newPart({ Name = "GripCap", Shape = Enum.PartType.Ball, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(point), Color = fitting, Material = fittingMaterial }))
	end

	-- Blade frame: local +Y runs down the shaft towards the cutting tip, X across the blade
	local bladeWidth = 1.05 + tier * 0.05
	local bladeCenter = bottom + direction * 0.7
	local bladeCFrame = CFrame.lookAt(bladeCenter, bladeCenter + direction) * CFrame.Angles(math.rad(-90), 0, 0)
	local bladeProps = {
		Color = bladeColor,
		Material = bladeMaterial,
		Reflectance = if look.BladeMaterial == "Metal" then 0.12 else 0,
		Transparency = if glass then 0.2 else 0,
	}
	local function bladePart(props: { [string]: any })
		for key, value in bladeProps do
			if props[key] == nil then
				props[key] = value
			end
		end
		return add(newPart(props))
	end
	-- socket ("frog") that wraps the shaft end, with two rivets
	rod("Socket", bottom - direction * 0.3, bottom + direction * 0.35, 0.27, fitting, fittingMaterial)
	for _, offset in { -0.12, 0.12 } do
		local rivet = bottom + direction * offset
		add(newPart({ Name = "Rivet", Shape = Enum.PartType.Ball, Size = Vector3.new(0.09, 0.09, 0.09), CFrame = CFrame.new(rivet + side * 0.13), Color = Color3.fromRGB(200, 200, 205), Material = Enum.Material.Metal }))
	end
	-- main plate
	local blade = bladePart({ Name = "Blade", Size = Vector3.new(bladeWidth, 1.0, 0.1), CFrame = bladeCFrame * CFrame.new(0, -0.1, 0) })
	-- the rounded point of a real spade: a diamond tucked under the plate
	local point = bladeWidth * 0.71
	bladePart({ Name = "BladePoint", Size = Vector3.new(point, point, 0.1), CFrame = bladeCFrame * CFrame.new(0, 0.38, 0) * CFrame.Angles(0, 0, math.rad(45)) })
	-- curved sides: the blade's edges roll up a little (it's dished, not flat)
	for _, s in { -1, 1 } do
		bladePart({ Name = "BladeEdge", Size = Vector3.new(0.1, 0.95, 0.14), CFrame = bladeCFrame * CFrame.new(s * (bladeWidth / 2 - 0.02), -0.12, 0.05) * CFrame.Angles(0, s * math.rad(-25), 0) })
	end
	-- rolled top edge = the step you push with your foot
	bladePart({ Name = "Tread", Shape = Enum.PartType.Cylinder, Size = Vector3.new(bladeWidth + 0.04, 0.17, 0.17), CFrame = bladeCFrame * CFrame.new(0, -0.6, 0.02) })
	-- centre ridge running down from the socket
	bladePart({ Name = "Ridge", Size = Vector3.new(0.14, 0.75, 0.14), CFrame = bladeCFrame * CFrame.new(0, -0.15, 0.07) })
	if not plastic and not glass then
		-- a bright, worn cutting edge
		bladePart({ Name = "Edge", Size = Vector3.new(point * 0.98, 0.06, 0.11), CFrame = bladeCFrame * CFrame.new(0, 0.38, 0) * CFrame.Angles(0, 0, math.rad(45)) * CFrame.new(0, -point / 2 + 0.02, 0),
			Color = bladeColor:Lerp(Color3.new(1, 1, 1), 0.35), Reflectance = 0.2 })
	end
	if tier >= 6 then
		for _, s in { -1, 1 } do
			add(newPart({
				Name = "Fin",
				Size = Vector3.new(0.12, 0.9, 0.35),
				CFrame = bladeCFrame * CFrame.new(s * (bladeWidth / 2 + 0.05), -0.15, 0.1),
				Color = bladeColor,
				Material = Enum.Material.Neon,
				CastShadow = false,
			}))
		end
	end

	if look.Glow then
		local light = Instance.new("PointLight")
		light.Color = bladeColor
		light.Brightness = 1.2
		light.Range = 7
		light.Parent = blade
	end
	if look.Sparkle then
		local sparkle = Instance.new("ParticleEmitter")
		sparkle.Name = "Sparkles"
		sparkle.Color = ColorSequence.new(bladeColor)
		sparkle.LightEmission = 1
		sparkle.Rate = 6
		sparkle.Lifetime = NumberRange.new(0.4, 0.9)
		sparkle.Speed = NumberRange.new(0.5, 1.5)
		sparkle.SpreadAngle = Vector2.new(180, 180)
		sparkle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0) })
		sparkle.Parent = blade
	end

	for _, part in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = handle
	end
	return tool
end

return ShovelModels
