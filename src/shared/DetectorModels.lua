--[[
	DetectorModels
	Builds the metal detector Tool the player holds - a believable, real-world shape:

	  armrest cuff + strap -> rubber pistol grip (with trigger) -> control housing with an angled
	  display, buttons, a knob and a speaker grille -> three-section telescoping shaft with cam-lock
	  collars and a coiled cable spiralling down it -> yoke + bolt -> the search coil.

	The look depends on:
	  detector tier   housing size, display, antenna (4+), power bands (6+), resonator orb (8)
	  built-in coil   its type sets the construction (Stock / Wide Scan = concentric rings,
	                  Double-D = two D windings, Pulse Induction = thick mono ring, Quantum = glowing
	                  ring with an orbit) and CoilSize sets its radius
	  skin            colours / material / sparkles

	The coil has a part named "CoilGlow" with a PointLight "SignalLight" - the client pulses it with
	the signal (DetectorController). Every part is Massless and non-colliding.
]]

local Equipment = require(script.Parent.Config.Equipment)

local DetectorModels = {}

local DEG = math.rad
local RUBBER = Color3.fromRGB(28, 28, 32)
local DARK = Color3.fromRGB(44, 46, 52)
local STEEL = Color3.fromRGB(176, 180, 188)

local function materialFromName(name: string?): Enum.Material
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

local function newPart(className: string?, props: { [string]: any }): BasePart
	local part = Instance.new(className or "Part") :: BasePart
	part.Anchored = false
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Massless = true
	part.CastShadow = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		(part :: any)[key] = value
	end
	return part
end

-- CFrame whose X axis runs from a to b (Roblox cylinders run along X)
local function alongX(a: Vector3, b: Vector3): CFrame
	return CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, DEG(90), 0)
end

function DetectorModels.BuildTool(detectorId: string, skinId: string): Tool
	local detector = Equipment.ById.Detector[detectorId] or Equipment.Detectors[1]
	local skin = Equipment.ById.Skin[skinId] or Equipment.Skins[1]
	local tier = detector.Order or 1
	local skinMaterial = materialFromName(skin.Material)
	local coilType = detector.Coil or "Stock Coil"

	local tool = Instance.new("Tool")
	tool.Name = "Metal Detector"
	tool.ToolTip = detector.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, 0, 0)
	tool:SetAttribute("IsDetector", true)
	tool:SetAttribute("DetectorId", detector.Id)

	-- Handle = the rubber grip. With the default grip, the handle's -Z points where the arm points.
	local handle = newPart(nil, {
		Name = "Handle",
		Size = Vector3.new(0.3, 0.34, 0.72),
		Color = RUBBER,
		Material = Enum.Material.Fabric,
		CFrame = CFrame.new(),
	})
	handle.Parent = tool

	local parts: { BasePart } = {}
	local function add(className: string?, props: { [string]: any }): BasePart
		local part = newPart(className, props)
		part.Parent = tool
		table.insert(parts, part)
		return part
	end
	local function cylinder(name: string, a: Vector3, b: Vector3, diameter: number, color: Color3, material: Enum.Material, extra: { [string]: any }?)
		local props: { [string]: any } = {
			Name = name,
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(math.max((b - a).Magnitude, 0.02), diameter, diameter),
			CFrame = alongX(a, b),
			Color = color,
			Material = material,
		}
		if extra then
			for key, value in extra do
				props[key] = value
			end
		end
		return add(nil, props)
	end
	local function ball(name: string, position: Vector3, diameter: number, color: Color3, material: Enum.Material, extra: { [string]: any }?)
		local props: { [string]: any } = { Name = name, Shape = Enum.PartType.Ball, Size = Vector3.new(diameter, diameter, diameter), CFrame = CFrame.new(position), Color = color, Material = material }
		if extra then
			for key, value in extra do
				props[key] = value
			end
		end
		return add(nil, props)
	end

	local body = skin.Body
	local bodyMaterial = if skin.Id == "Default" and tier <= 2 then Enum.Material.SmoothPlastic else skinMaterial
	local metal = if tier >= 3 then Enum.Material.Metal else Enum.Material.SmoothPlastic

	---------------------------------------------------------------- grip, trigger, armrest
	-- finger ridges on the front of the grip
	for i = 0, 2 do
		cylinder("GripRidge", Vector3.new(-0.16, -0.12, -0.22 + i * 0.18), Vector3.new(0.16, -0.12, -0.22 + i * 0.18), 0.1, RUBBER, Enum.Material.Fabric)
	end
	add(nil, { Name = "Trigger", Size = Vector3.new(0.08, 0.18, 0.1), CFrame = CFrame.new(0, -0.24, -0.26) * CFrame.Angles(DEG(20), 0, 0), Color = skin.Accent, Material = Enum.Material.SmoothPlastic })
	-- the upper stem runs back over the forearm to the armrest
	cylinder("UpperStem", Vector3.new(0, 0.2, 1.25), Vector3.new(0, 0.2, -0.35), 0.2, body, bodyMaterial)
	cylinder("StemJoinFront", Vector3.new(0, 0.2, -0.3), Vector3.new(0, 0.05, -0.55), 0.18, body, bodyMaterial)
	cylinder("StemJoinBack", Vector3.new(0, 0.2, 0.3), Vector3.new(0, 0.12, 0.1), 0.18, body, bodyMaterial)
	-- armrest: a curved cradle (base + two raised sides) with a strap across it
	add(nil, { Name = "ArmrestBase", Size = Vector3.new(0.5, 0.08, 0.75), CFrame = CFrame.new(0, 0.33, 1.05), Color = body, Material = bodyMaterial })
	for _, side in { -1, 1 } do
		add(nil, { Name = "ArmrestSide", Size = Vector3.new(0.06, 0.26, 0.7), CFrame = CFrame.new(side * 0.26, 0.43, 1.05) * CFrame.Angles(0, 0, DEG(side * -12)), Color = body, Material = bodyMaterial })
	end
	add(nil, { Name = "ArmrestPad", Size = Vector3.new(0.42, 0.04, 0.66), CFrame = CFrame.new(0, 0.38, 1.05), Color = RUBBER, Material = Enum.Material.Fabric })
	add(nil, { Name = "Strap", Size = Vector3.new(0.6, 0.05, 0.16), CFrame = CFrame.new(0, 0.6, 1.0), Color = Color3.fromRGB(30, 30, 34), Material = Enum.Material.Fabric })
	add(nil, { Name = "StrapBuckle", Size = Vector3.new(0.12, 0.06, 0.18), CFrame = CFrame.new(0.2, 0.62, 1.0), Color = STEEL, Material = Enum.Material.Metal })

	---------------------------------------------------------------- control housing
	local big = tier >= 5
	local boxSize = if big then Vector3.new(0.62, 0.4, 0.95) else Vector3.new(0.54, 0.34, 0.8)
	local boxCF = CFrame.new(0, 0.42, -0.72)
	add(nil, { Name = "ControlBox", Size = boxSize, CFrame = boxCF, Color = body, Material = bodyMaterial })
	-- rounded side edges
	for _, side in { -1, 1 } do
		cylinder("BoxEdge", (boxCF * CFrame.new(side * boxSize.X / 2, 0, boxSize.Z / 2)).Position, (boxCF * CFrame.new(side * boxSize.X / 2, 0, -boxSize.Z / 2)).Position,
			boxSize.Y, body, bodyMaterial)
	end
	add(nil, { Name = "BoxBottom", Size = Vector3.new(boxSize.X * 0.9, 0.08, boxSize.Z * 0.9), CFrame = boxCF * CFrame.new(0, -boxSize.Y / 2 - 0.03, 0), Color = DARK, Material = Enum.Material.SmoothPlastic })
	-- angled display panel facing the player (tilted back toward the grip)
	local faceCF = boxCF * CFrame.new(0, boxSize.Y / 2 + 0.02, 0.02) * CFrame.Angles(DEG(-14), 0, 0)
	add(nil, { Name = "FacePlate", Size = Vector3.new(boxSize.X * 0.92, 0.05, boxSize.Z * 0.92), CFrame = faceCF, Color = DARK, Material = Enum.Material.SmoothPlastic })
	add(nil, { Name = "ScreenBezel", Size = Vector3.new(boxSize.X * 0.76, 0.025, boxSize.Z * 0.5), CFrame = faceCF * CFrame.new(0, 0.03, -boxSize.Z * 0.17), Color = Color3.fromRGB(16, 16, 20), Material = Enum.Material.SmoothPlastic })
	add(nil, {
		Name = "Screen",
		Size = Vector3.new(boxSize.X * 0.68, 0.03, boxSize.Z * 0.42),
		CFrame = faceCF * CFrame.new(0, 0.045, -boxSize.Z * 0.17),
		Color = if tier >= 2 then skin.Accent else Color3.fromRGB(150, 170, 120),
		Material = if tier >= 2 then Enum.Material.Neon else Enum.Material.SmoothPlastic,
		Transparency = if tier >= 2 then 0.15 else 0,
		CastShadow = false,
	})
	-- a row of buttons (the first, in the accent colour, is power)
	local buttons = if tier >= 4 then 4 else 3
	for i = 1, buttons do
		local x = (i - (buttons + 1) / 2) * (boxSize.X * 0.2)
		cylinder("Button", (faceCF * CFrame.new(x, 0.02, boxSize.Z * 0.22)).Position, (faceCF * CFrame.new(x, 0.07, boxSize.Z * 0.22)).Position,
			0.09, if i == 1 then skin.Accent else Color3.fromRGB(70, 72, 80), Enum.Material.SmoothPlastic)
	end
	-- speaker grille on the front face
	add(nil, { Name = "Speaker", Size = Vector3.new(boxSize.X * 0.5, boxSize.Y * 0.5, 0.03), CFrame = boxCF * CFrame.new(0, -0.02, -boxSize.Z / 2 - 0.01), Color = Color3.fromRGB(20, 20, 24), Material = Enum.Material.DiamondPlate })
	-- tuning knob on the side
	cylinder("Knob", (boxCF * CFrame.new(boxSize.X / 2 + 0.01, 0.02, 0.1)).Position, (boxCF * CFrame.new(boxSize.X / 2 + 0.1, 0.02, 0.1)).Position, 0.16, DARK, Enum.Material.SmoothPlastic)
	add(nil, { Name = "KnobMark", Size = Vector3.new(0.02, 0.1, 0.02), CFrame = boxCF * CFrame.new(boxSize.X / 2 + 0.11, 0.06, 0.1), Color = skin.Accent, Material = Enum.Material.Neon, CastShadow = false })
	-- brand stripe
	add(nil, { Name = "Stripe", Size = Vector3.new(0.02, 0.06, boxSize.Z * 0.85), CFrame = boxCF * CFrame.new(-boxSize.X / 2 - 0.005, -0.08, 0), Color = skin.Accent, Material = Enum.Material.SmoothPlastic })

	---------------------------------------------------------------- telescoping shaft
	local shaftStart = Vector3.new(0, 0, -0.45)
	local coilPos = Vector3.new(0, -3.7, -3.6)
	local direction = (coilPos - shaftStart).Unit
	local length = (coilPos - shaftStart).Magnitude
	local function at(t: number): Vector3
		return shaftStart + direction * (length * t)
	end
	local rusty = skin.Id == "Default" and tier <= 2
	local upperColor = if skin.Id == "Default" then (if tier <= 2 then Color3.fromRGB(140, 96, 64) else STEEL) else body
	cylinder("ShaftUpper", at(0), at(0.42), 0.17, upperColor, if rusty then Enum.Material.CorrodedMetal else metal)
	cylinder("ShaftMiddle", at(0.38), at(0.74), 0.14, STEEL, Enum.Material.Metal)
	cylinder("ShaftLower", at(0.7), at(0.95), 0.12, Color3.fromRGB(38, 38, 42), Enum.Material.SmoothPlastic) -- composite lower rod
	for _, t in { 0.4, 0.72 } do
		cylinder("CamLock", at(t - 0.02), at(t + 0.03), 0.22, DARK, Enum.Material.SmoothPlastic)
		local leverBase = at(t) + Vector3.new(0.12, 0, 0)
		add(nil, { Name = "CamLever", Size = Vector3.new(0.05, 0.05, 0.22), CFrame = CFrame.lookAt(leverBase, leverBase + direction), Color = skin.Accent, Material = Enum.Material.SmoothPlastic })
	end
	-- the coil cable spirals down the shaft from the housing to the coil
	local cableColor = Color3.fromRGB(22, 22, 26)
	local side = direction:Cross(Vector3.new(0, 1, 0)).Unit
	local norm = side:Cross(direction).Unit
	local turns = 3.5
	local steps = 14
	local previous: Vector3? = nil
	for i = 0, steps do
		local t = 0.05 + 0.85 * i / steps
		local angle = t * turns * math.pi * 2
		local point = at(t) + (side * math.cos(angle) + norm * math.sin(angle)) * 0.13
		if previous then
			cylinder("Cable", previous, point, 0.045, cableColor, Enum.Material.SmoothPlastic, { CastShadow = false })
		end
		previous = point
	end

	---------------------------------------------------------------- yoke + coil
	local radius = detector.CoilSize or 1
	local coilCF = CFrame.new(coilPos) -- the coil lies flat over the sand
	-- yoke: two ears rising from the coil, a bolt through them and the lower rod's end
	for _, s in { -1, 1 } do
		add(nil, { Name = "YokeEar", Size = Vector3.new(0.05, 0.32, 0.26), CFrame = coilCF * CFrame.new(s * 0.1, 0.22, 0), Color = DARK, Material = Enum.Material.SmoothPlastic })
	end
	cylinder("YokeBolt", (coilCF * CFrame.new(-0.2, 0.3, 0)).Position, (coilCF * CFrame.new(0.2, 0.3, 0)).Position, 0.08, STEEL, Enum.Material.Metal)
	ball("WingNut", (coilCF * CFrame.new(0.24, 0.3, 0)).Position, 0.13, skin.Accent, Enum.Material.SmoothPlastic)
	cylinder("RodEnd", at(0.95), (coilCF * CFrame.new(0, 0.3, 0)).Position, 0.12, Color3.fromRGB(38, 38, 42), Enum.Material.SmoothPlastic)

	-- ring of short cylinders lying in the coil's plane (zScale stretches it into an ellipse)
	local function ring(name: string, r: number, thickness: number, height: number, color: Color3, material: Enum.Material, zScale: number?, extra: { [string]: any }?)
		local k = zScale or 1
		local n = 18
		for i = 0, n - 1 do
			local a0 = i / n * math.pi * 2
			local a1 = (i + 1) / n * math.pi * 2
			local p0 = (coilCF * CFrame.new(math.cos(a0) * r, height, math.sin(a0) * r * k)).Position
			local p1 = (coilCF * CFrame.new(math.cos(a1) * r, height, math.sin(a1) * r * k)).Position
			local step = p1 - p0
			cylinder(name, p0 - step * 0.06, p1 + step * 0.06, thickness, color, material, extra)
		end
	end
	local coilColor = skin.Coil
	local coilMaterial = if skinMaterial == Enum.Material.ForceField then Enum.Material.SmoothPlastic else skinMaterial
	local zScale = if coilType == "Double-D Coil" then 1.22 else 1
	-- skid plate: the flat underside that slides over the sand
	local plate = add(nil, {
		Name = "SkidPlate",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.06, radius * 2.05, radius * 2.05),
		CFrame = coilCF * CFrame.new(0, -0.08, 0) * CFrame.Angles(0, 0, DEG(90)),
		Color = Color3.fromRGB(30, 30, 34),
		Material = Enum.Material.SmoothPlastic,
	})
	if zScale ~= 1 then
		-- an oval plate for the Double-D (a cylinder can't be oval, so a sphere-mesh disc)
		(plate :: Part).Shape = Enum.PartType.Block
		plate.Size = Vector3.new(radius * 2.05, 0.06, radius * 2.05 * zScale)
		plate.CFrame = coilCF * CFrame.new(0, -0.08, 0)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = plate
	end
	ring("CoilRim", radius, 0.2, 0, coilColor, coilMaterial, zScale)
	if coilType == "Double-D Coil" then
		-- two D-shaped windings meeting at a centre spine
		add(nil, { Name = "DDSpine", Size = Vector3.new(0.12, 0.12, radius * 2 * zScale), CFrame = coilCF, Color = coilColor, Material = coilMaterial })
		ring("CoilWinding", radius * 0.62, 0.1, 0.02, coilColor:Lerp(skin.Accent, 0.25), coilMaterial, zScale)
	elseif coilType == "Pulse Induction Coil" then
		ring("CoilMono", radius * 0.78, 0.14, 0.03, DARK, Enum.Material.SmoothPlastic) -- heavy mono loop
	elseif coilType == "Quantum Coil" then
		ring("QuantumRing", radius * 0.7, 0.08, 0.05, skin.Accent, Enum.Material.Neon, nil, { CastShadow = false })
	else
		-- concentric stock / wide scan coil: inner ring + spokes
		ring("CoilInner", radius * 0.55, 0.11, 0.01, coilColor, coilMaterial)
		for i = 0, 3 do
			local a = i / 4 * math.pi * 2 + math.pi / 4
			add(nil, {
				Name = "Spoke",
				Size = Vector3.new(radius * 0.45, 0.07, 0.09),
				CFrame = coilCF * CFrame.Angles(0, -a, 0) * CFrame.new(radius * 0.77, 0, 0),
				Color = coilColor,
				Material = coilMaterial,
			})
		end
	end
	-- the glowing centre the client pulses with the signal
	local glow = add(nil, {
		Name = "CoilGlow",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.08, radius * 0.7, radius * 0.7),
		CFrame = coilCF * CFrame.new(0, 0.02, 0) * CFrame.Angles(0, 0, DEG(90)),
		Color = skin.Accent,
		Material = Enum.Material.Neon,
		Transparency = if tier <= 1 then 0.65 else 0.3,
		CastShadow = false,
	})
	local light = Instance.new("PointLight")
	light.Name = "SignalLight"
	light.Color = skin.Accent
	light.Brightness = 0
	light.Range = 10
	light.Parent = glow

	---------------------------------------------------------------- tier extras
	if tier >= 4 then
		local base = (boxCF * CFrame.new(boxSize.X * 0.3, boxSize.Y / 2, boxSize.Z * 0.35)).Position
		cylinder("Antenna", base, base + Vector3.new(0, 0.75, 0.1), 0.05, DARK, Enum.Material.Metal)
		ball("AntennaTip", base + Vector3.new(0, 0.78, 0.1), 0.14, skin.Accent, Enum.Material.Neon, { CastShadow = false })
	end
	if tier >= 6 then
		for _, t in { 0.55, 0.62 } do
			cylinder("PowerBand", at(t - 0.012), at(t + 0.012), 0.2, skin.Accent, Enum.Material.Neon, { CastShadow = false })
		end
	end
	if tier >= 8 then
		ball("ResonatorOrb", coilPos + Vector3.new(0, 0.95, 0), 0.42, skin.Accent, Enum.Material.Neon, { Transparency = 0.15, CastShadow = false })
		local orbCF = CFrame.new(coilPos + Vector3.new(0, 0.95, 0)) * CFrame.Angles(DEG(70), 0, DEG(20))
		for i = 0, 11 do
			local a0 = i / 12 * math.pi * 2
			local a1 = (i + 1) / 12 * math.pi * 2
			cylinder("Orbit", (orbCF * CFrame.new(math.cos(a0) * 0.4, math.sin(a0) * 0.4, 0)).Position, (orbCF * CFrame.new(math.cos(a1) * 0.4, math.sin(a1) * 0.4, 0)).Position,
				0.035, skin.Accent, Enum.Material.Neon, { CastShadow = false })
		end
	end

	if skin.Sparkle or tier >= 7 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Name = "Sparkles"
		sparkles.Color = ColorSequence.new(skin.Accent)
		sparkles.LightEmission = 1
		sparkles.Rate = 8
		sparkles.Lifetime = NumberRange.new(0.5, 1)
		sparkles.Speed = NumberRange.new(0.5, 1.5)
		sparkles.SpreadAngle = Vector2.new(180, 180)
		sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 0) })
		sparkles.Parent = glow
	end

	for _, part in parts do
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = part
		weld.Parent = handle
	end

	return tool
end

return DetectorModels
