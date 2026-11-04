--[[
	AmbienceController (Update 17)
	Makes the coast feel alive - all client-side, cosmetic and cheap. Nothing here affects
	gameplay, and everything important stays visual elsewhere.

	  * Seagulls circle over whichever beach you're on; now and then one glides down and lands on
	    a railing post or the sand, folds its wings, and takes off again if you walk up to it.
	  * Boats pass slowly far out at sea; moored boats, floats and buoys bob ("Bob" attribute).
	  * Flags and sails flutter ("Flag"), kelp and palm fronds sway in the wind ("Sway", palms).
	  * Foam laps up the shore of every beach; spray bursts off the surf rocks ("Spray").
	  * Sand drifts past your feet on the beaches, and you (and others nearby) leave footprints.
	  * Little crabs scuttle about and dash away when you come close; swimmers float in the safe
	    shallows of the family beaches.
	  * "Look closer" prompts on curiosities ("Curio" attribute) show a short story.
	Level of detail: only things near the camera animate, and at a reduced rate further away.
	Reduced Motion (Settings) turns the movement off.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Zones = require(Shared.Config.Zones)

local Ambience = {}

local player = Players.LocalPlayer
local controllers
local folder: Folder
local rng = Random.new()
local WATER_Y = -0.5

local function reduced(): boolean
	local data = controllers and controllers.State.Data
	return (data and data.Settings and data.Settings.ReducedMotion) == true
end

local function cameraPosition(): Vector3
	local camera = Workspace.CurrentCamera
	return if camera then camera.CFrame.Position else Vector3.zero
end

local function newPart(props: { [string]: any }): BasePart
	local part = Instance.new(props.ClassName or "Part") :: BasePart
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		if key ~= "ClassName" and key ~= "Sphere" then
			(part :: any)[key] = value
		end
	end
	if props.Sphere then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	return part
end

-- Which beach (and its middle) the camera is over, if any
local function beachNear(position: Vector3): (string?, Vector3?)
	local map = Workspace:FindFirstChild("Map")
	local zones = map and map:FindFirstChild("Zones")
	if not zones then
		return nil, nil
	end
	local best, bestDist, bestCenter = nil, math.huge, nil
	for _, zone in zones:GetChildren() do
		local area = zone:FindFirstChild("DigArea") :: BasePart?
		if area then
			local d = (Vector3.new(area.Position.X, 0, area.Position.Z) - Vector3.new(position.X, 0, position.Z)).Magnitude
			if d < bestDist then
				best, bestDist, bestCenter = zone.Name, d, area.Position
			end
		end
	end
	if bestDist > 220 then
		return nil, nil
	end
	return best, bestCenter
end

---------------------------------------------------------------------------
-- Seagulls
---------------------------------------------------------------------------
type Gull = { Model: Model, Body: BasePart, WingL: BasePart, WingR: BasePart, Parts: { { Part: BasePart, Rel: CFrame } },
	Center: Vector3, Radius: number, Height: number, Speed: number, Angle: number,
	State: string, Perch: Vector3?, From: Vector3?, T: number, Until: number, Position: Vector3, Heading: Vector3 }
local gulls: { Gull } = {}
local perches: { Vector3 } = {}

local function buildGull(): Gull
	local model = Instance.new("Model")
	model.Name = "Seagull"
	local white, grey, dark = Color3.fromRGB(245, 245, 242), Color3.fromRGB(160, 168, 176), Color3.fromRGB(40, 40, 45)
	local body = newPart({ Size = Vector3.new(0.7, 0.6, 1.6), Color = white, Material = Enum.Material.SmoothPlastic, Sphere = true })
	local head = newPart({ Size = Vector3.new(0.5, 0.5, 0.55), Color = white, Material = Enum.Material.SmoothPlastic, Sphere = true })
	local beak = newPart({ Size = Vector3.new(0.12, 0.12, 0.4), Color = Color3.fromRGB(240, 190, 60), Material = Enum.Material.SmoothPlastic })
	local tail = newPart({ ClassName = "WedgePart", Size = Vector3.new(0.5, 0.12, 0.5), Color = grey, Material = Enum.Material.SmoothPlastic })
	local wingL = newPart({ Size = Vector3.new(1.8, 0.08, 0.7), Color = grey, Material = Enum.Material.SmoothPlastic })
	local wingR = newPart({ Size = Vector3.new(1.8, 0.08, 0.7), Color = grey, Material = Enum.Material.SmoothPlastic })
	local tipL = newPart({ Size = Vector3.new(0.5, 0.09, 0.5), Color = dark, Material = Enum.Material.SmoothPlastic })
	local tipR = newPart({ Size = Vector3.new(0.5, 0.09, 0.5), Color = dark, Material = Enum.Material.SmoothPlastic })
	local rel = {
		{ Part = body, Rel = CFrame.new() },
		{ Part = head, Rel = CFrame.new(0, 0.25, -0.85) },
		{ Part = beak, Rel = CFrame.new(0, 0.2, -1.2) },
		{ Part = tail, Rel = CFrame.new(0, 0.05, 0.95) * CFrame.Angles(0, math.pi, 0) },
	}
	for _, p in { body, head, beak, tail, wingL, wingR, tipL, tipR } do
		p.Parent = model
	end
	local gull: Gull = {
		Model = model, Body = body, WingL = wingL, WingR = wingR, Parts = rel,
		Center = Vector3.zero, Radius = 30, Height = 30, Speed = 0.25, Angle = rng:NextNumber() * math.pi * 2,
		State = "Fly", Perch = nil, From = nil, T = 0, Until = 0, Position = Vector3.new(0, 40, 0), Heading = Vector3.new(0, 0, -1),
	}
	;(gull :: any).TipL = tipL
	;(gull :: any).TipR = tipR
	model.Parent = folder
	return gull
end

local function placeGull(gull: Gull, flap: number, folded: boolean)
	local cf = CFrame.lookAt(gull.Position, gull.Position + gull.Heading)
	for _, entry in gull.Parts do
		entry.Part.CFrame = cf * entry.Rel
	end
	local any = gull :: any
	if folded then
		gull.WingL.CFrame = cf * CFrame.new(-0.32, 0.1, 0.15) * CFrame.Angles(0, 0, math.rad(80)) * CFrame.new(0, 0, 0)
		gull.WingR.CFrame = cf * CFrame.new(0.32, 0.1, 0.15) * CFrame.Angles(0, 0, math.rad(-80))
		gull.WingL.Size = Vector3.new(0.6, 0.08, 0.9)
		gull.WingR.Size = Vector3.new(0.6, 0.08, 0.9)
		any.TipL.CFrame = cf * CFrame.new(-0.3, 0.05, 0.75)
		any.TipR.CFrame = cf * CFrame.new(0.3, 0.05, 0.75)
	else
		gull.WingL.Size = Vector3.new(1.8, 0.08, 0.7)
		gull.WingR.Size = Vector3.new(1.8, 0.08, 0.7)
		local a = flap
		gull.WingL.CFrame = cf * CFrame.new(-0.3, 0.15, 0) * CFrame.Angles(0, 0, a) * CFrame.new(-0.9, 0, 0)
		gull.WingR.CFrame = cf * CFrame.new(0.3, 0.15, 0) * CFrame.Angles(0, 0, -a) * CFrame.new(0.9, 0, 0)
		any.TipL.CFrame = gull.WingL.CFrame * CFrame.new(-1.05, 0, 0.05)
		any.TipR.CFrame = gull.WingR.CFrame * CFrame.new(1.05, 0, 0.05)
	end
end

local function collectPerches()
	table.clear(perches)
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, part in map:GetDescendants() do
		if part:IsA("BasePart") and (string.find(part.Name, "Post%d") or part.Name == "Cap") and part.Size.Y > 2 and part.Size.Y < 8 and #perches < 400 then
			table.insert(perches, part.Position + Vector3.new(0, part.Size.Y / 2 + 0.35, 0))
		end
	end
end

local function updateGulls(dt: number, now: number)
	local camPos = cameraPosition()
	local _, beachCenter = beachNear(camPos)
	local center = beachCenter or Vector3.new(camPos.X, 0, camPos.Z - 40)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for index, gull in gulls do
		-- each gull loosely follows the camera's beach
		gull.Center = gull.Center:Lerp(center + Vector3.new(math.sin(index * 2.1) * 40, 0, math.cos(index * 1.7) * 30 - 30), math.min(1, dt * 0.2))
		local far = (gull.Position - camPos).Magnitude
		if gull.State == "Fly" then
			gull.Angle += dt * gull.Speed
			local target = gull.Center + Vector3.new(math.cos(gull.Angle) * gull.Radius, gull.Height + math.sin(now * 0.5 + index) * 3, math.sin(gull.Angle) * gull.Radius * 0.7)
			local move = target - gull.Position
			if move.Magnitude > 60 then
				gull.Position = target -- way off (camera teleported): pop over
			else
				gull.Position += move * math.min(1, dt * 1.5)
			end
			if move.Magnitude > 0.05 then
				gull.Heading = gull.Heading:Lerp(move.Unit, math.min(1, dt * 3)).Unit
			end
			-- now and then: land somewhere near
			if now > gull.Until and #perches > 0 and rng:NextNumber() < dt * 0.04 then
				local best = nil
				for _ = 1, 12 do
					local candidate = perches[rng:NextInteger(1, #perches)]
					if (candidate - gull.Position).Magnitude < 120 then
						best = candidate
						break
					end
				end
				if not best and beachCenter then
					best = Vector3.new(beachCenter.X + rng:NextNumber(-60, 60), 0.35, rng:NextNumber(-12, 40))
				end
				if best then
					gull.State = "Land"
					gull.From = gull.Position
					gull.Perch = best
					gull.T = 0
				end
			end
			if far < 300 then
				placeGull(gull, math.sin(now * 9 + index) * 0.55, false)
			end
		elseif gull.State == "Land" then
			gull.T += dt / 3.2
			local t = math.min(1, gull.T)
			local from, to = gull.From :: Vector3, gull.Perch :: Vector3
			local position = from:Lerp(to, 1 - (1 - t) ^ 2) + Vector3.new(0, math.sin(t * math.pi) * 4, 0)
			local step = position - gull.Position
			gull.Position = position
			if step.Magnitude > 0.01 then
				gull.Heading = Vector3.new(step.X, 0, step.Z).Unit
			end
			placeGull(gull, math.sin(now * 5) * 0.3 * (1 - t) + 0.2, false)
			if t >= 1 then
				gull.State = "Perched"
				gull.Until = now + rng:NextNumber(8, 18)
			end
		elseif gull.State == "Perched" then
			local spooked = root ~= nil and ((root :: BasePart).Position - gull.Position).Magnitude < 9
			if now > gull.Until or spooked then
				gull.State = "Fly"
				gull.Until = now + rng:NextNumber(15, 35)
			end
			if far < 200 and math.floor(now * 2 + index) % 7 == 0 then
				-- look around
				gull.Heading = (CFrame.Angles(0, math.sin(now + index) * 0.6, 0) * gull.Heading).Unit
			end
			placeGull(gull, 0, true)
		end
	end
end

---------------------------------------------------------------------------
-- Distant boats
---------------------------------------------------------------------------
type Boat = { Model: Model, Parts: { { Part: BasePart, Rel: CFrame } }, X: number, Z: number, Speed: number, Phase: number }
local boats: { Boat } = {}

local function buildBoat(kind: number): Boat
	local model = Instance.new("Model")
	model.Name = "DistantBoat"
	local parts = {}
	local function add(props, rel: CFrame)
		local p = newPart(props)
		p.Parent = model
		table.insert(parts, { Part = p, Rel = rel })
	end
	local hull = if kind == 1 then Color3.fromRGB(180, 60, 50) elseif kind == 2 then Color3.fromRGB(240, 238, 230) else Color3.fromRGB(50, 80, 120)
	add({ Size = Vector3.new(14, 4, 5), Color = hull, Material = Enum.Material.WoodPlanks, Sphere = true }, CFrame.new(0, 0.3, 0))
	add({ Size = Vector3.new(12, 0.4, 4.2), Color = Color3.fromRGB(160, 120, 80), Material = Enum.Material.WoodPlanks }, CFrame.new(0, 1.6, 0))
	if kind == 2 then
		add({ Size = Vector3.new(0.4, 16, 0.4), Color = Color3.fromRGB(220, 210, 190), Material = Enum.Material.Wood }, CFrame.new(-1, 9.5, 0))
		add({ ClassName = "WedgePart", Size = Vector3.new(0.1, 13, 8), Color = Color3.fromRGB(245, 240, 228), Material = Enum.Material.Fabric }, CFrame.new(-1, 9, 4) * CFrame.Angles(0, 0, 0))
	else
		add({ Size = Vector3.new(4.5, 3.2, 3.6), Color = Color3.fromRGB(235, 232, 220), Material = Enum.Material.Wood }, CFrame.new(2.5, 3.4, 0))
		add({ Size = Vector3.new(0.3, 7, 0.3), Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Metal }, CFrame.new(-2, 5, 0))
		add({ Size = Vector3.new(0.12, 0.12, 9), Color = Color3.fromRGB(60, 60, 64), Material = Enum.Material.Metal }, CFrame.new(-4.5, 6, 0) * CFrame.Angles(0, math.rad(90), math.rad(-30)))
	end
	model.Parent = folder
	return { Model = model, Parts = parts, X = rng:NextNumber(-100, 950), Z = rng:NextNumber(-430, -320), Speed = rng:NextNumber(2.5, 5) * (if rng:NextNumber() < 0.5 then 1 else -1), Phase = rng:NextNumber() * 10 }
end

local function updateBoats(dt: number, now: number)
	for _, boat in boats do
		boat.X += boat.Speed * dt
		if boat.X > 1000 then
			boat.X = -150
		elseif boat.X < -150 then
			boat.X = 1000
		end
		local bob = math.sin(now * 0.9 + boat.Phase) * 0.35
		local roll = math.sin(now * 0.7 + boat.Phase) * 0.05
		local facing = if boat.Speed > 0 then -math.pi / 2 else math.pi / 2
		local cf = CFrame.new(boat.X, WATER_Y + bob, boat.Z) * CFrame.Angles(0, facing + math.pi / 2, roll)
		for _, entry in boat.Parts do
			entry.Part.CFrame = cf * entry.Rel
		end
	end
end

---------------------------------------------------------------------------
-- Flags, bobbing things, swaying plants
---------------------------------------------------------------------------
type Animated = { Instance: Instance, Base: CFrame, Kind: string, Phase: number, Pivot: CFrame? }
local animated: { Animated } = {}
local palmCrowns: { { Parts: { { Part: BasePart, Base: CFrame } }, Top: Vector3, Phase: number } } = {}

local function collectAnimated()
	table.clear(animated)
	table.clear(palmCrowns)
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, inst in map:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Flag") then
			-- flutter around the pole edge (the flag's +Z side)
			table.insert(animated, { Instance = inst, Base = inst.CFrame, Kind = "Flag", Phase = rng:NextNumber() * 10, Pivot = CFrame.new(0, 0, inst.Size.Z / 2) })
		elseif inst:IsA("BasePart") and inst:GetAttribute("Sway") then
			table.insert(animated, { Instance = inst, Base = inst.CFrame, Kind = "Sway", Phase = rng:NextNumber() * 10, Pivot = CFrame.new(0, -inst.Size.Y / 2, 0) })
		elseif inst:GetAttribute("Bob") then
			if inst:IsA("Model") then
				table.insert(animated, { Instance = inst, Base = inst:GetPivot(), Kind = "Bob", Phase = rng:NextNumber() * 10 })
			elseif inst:IsA("BasePart") then
				table.insert(animated, { Instance = inst, Base = inst.CFrame, Kind = "Bob", Phase = rng:NextNumber() * 10 })
			end
		elseif inst:IsA("Model") and string.find(inst.Name, "Palm") and inst:FindFirstChild("Crown") then
			local crown = inst:FindFirstChild("Crown") :: BasePart
			local parts = {}
			for _, child in inst:GetChildren() do
				if child:IsA("BasePart") and (string.find(child.Name, "^Leaf") or string.find(child.Name, "^Rib") or child.Name == "Crown" or string.find(child.Name, "^Coconut")) then
					table.insert(parts, { Part = child, Base = child.CFrame })
				end
			end
			table.insert(palmCrowns, { Parts = parts, Top = crown.Position, Phase = rng:NextNumber() * 10 })
		end
	end
end

local frame = 0
local function updateAnimated(now: number)
	frame += 1
	local camPos = cameraPosition()
	local gust = 1 + math.sin(now * 0.31) * 0.35
	for i, entry in animated do
		local inst = entry.Instance
		local part = inst :: BasePart
		local base = entry.Base
		local distance = (base.Position - camPos).Magnitude
		if distance > 260 or (distance > 120 and (frame + i) % 3 ~= 0) then
			continue
		end
		if entry.Kind == "Flag" then
			local pivot = entry.Pivot :: CFrame
			local a = (math.sin(now * 4.2 + entry.Phase) * 0.22 + math.sin(now * 7.1 + entry.Phase) * 0.08) * gust
			part.CFrame = base * pivot * CFrame.Angles(0, a, 0) * pivot:Inverse()
		elseif entry.Kind == "Sway" then
			local pivot = entry.Pivot :: CFrame
			local a = math.sin(now * 0.8 + entry.Phase) * 0.12
			part.CFrame = base * pivot * CFrame.Angles(a, 0, a * 0.6) * pivot:Inverse()
		else
			local offset = CFrame.new(0, math.sin(now * 1.1 + entry.Phase) * 0.18, 0) * CFrame.Angles(math.sin(now * 0.8 + entry.Phase) * 0.03, 0, math.sin(now * 0.9 + entry.Phase) * 0.05)
			if inst:IsA("Model") then
				inst:PivotTo(base * offset)
			else
				part.CFrame = base * offset
			end
		end
	end
	for i, palm in palmCrowns do
		local distance = (palm.Top - camPos).Magnitude
		if distance > 140 or (distance > 70 and (frame + i) % 2 ~= 0) then
			continue
		end
		local a = math.sin(now * 0.9 + palm.Phase) * 0.035 * gust
		local b = math.sin(now * 0.6 + palm.Phase * 1.3) * 0.025 * gust
		local pivot = CFrame.new(palm.Top)
		local rot = pivot * CFrame.Angles(a, 0, b) * pivot:Inverse()
		for _, entry in palm.Parts do
			entry.Part.CFrame = rot * entry.Base
		end
	end
end

---------------------------------------------------------------------------
-- Shore foam + surf spray
---------------------------------------------------------------------------
local foam: { { Part: BasePart, X: number, Phase: number, Z: number } } = {}
local function buildFoam()
	local map = Workspace:FindFirstChild("Map")
	local zones = map and map:FindFirstChild("Zones")
	if not zones then
		return
	end
	for _, zone in zones:GetChildren() do
		local slope = zone:FindFirstChild("ShoreSlope") :: BasePart?
		if slope then
			for layer = 1, 2 do
				local strip = newPart({
					Name = "Foam",
					Size = Vector3.new(slope.Size.X + 18, 0.12, 2.2),
					Color = Color3.fromRGB(246, 250, 252),
					Material = Enum.Material.SmoothPlastic,
					Transparency = 0.5,
				})
				strip.Parent = folder
				table.insert(foam, { Part = strip, X = slope.Position.X, Phase = layer * 2.4 + slope.Position.X * 0.01, Z = slope.Position.Z + slope.Size.Z / 2 - 2.4 })
			end
		end
	end
end

local function updateFoam(now: number)
	local camPos = cameraPosition()
	for _, entry in foam do
		local near = math.abs(entry.X - camPos.X) < 220 and camPos.Z < 140
		entry.Part.Transparency = if near then entry.Part.Transparency else 1
		if near then
			local wave = (math.sin(now * 0.7 + entry.Phase) + 1) / 2 -- 0..1: washes up, then back
			entry.Part.CFrame = CFrame.new(entry.X, WATER_Y + 0.03 + wave * 0.05, entry.Z - 2 + wave * 3.2)
			entry.Part.Transparency = 0.35 + (1 - wave) * 0.5
			entry.Part.Size = Vector3.new(entry.Part.Size.X, 0.12, 1.4 + wave * 1.6)
		end
	end
end

local sprayEmitters: { { Emitter: ParticleEmitter, Position: Vector3, Next: number } } = {}
local function buildSpray()
	local map = Workspace:FindFirstChild("Map")
	if not map then
		return
	end
	for _, inst in map:GetDescendants() do
		if inst:IsA("BasePart") and inst:GetAttribute("Spray") then
			local holder = newPart({ Size = Vector3.new(1, 1, 1), Transparency = 1, Position = Vector3.new(inst.Position.X, WATER_Y + 1, inst.Position.Z - inst.Size.Z * 0.3) })
			holder.Parent = folder
			local emitter = Instance.new("ParticleEmitter")
			emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
			emitter.Color = ColorSequence.new(Color3.fromRGB(240, 250, 255))
			emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
			emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3) })
			emitter.Speed = NumberRange.new(8, 14)
			emitter.SpreadAngle = Vector2.new(30, 30)
			emitter.Acceleration = Vector3.new(0, -14, 0)
			emitter.Lifetime = NumberRange.new(0.6, 1.1)
			emitter.Rate = 0
			emitter.Parent = holder
			table.insert(sprayEmitters, { Emitter = emitter, Position = holder.Position, Next = rng:NextNumber(0, 4) })
		end
	end
end

local function updateSpray(now: number)
	if reduced() then
		return
	end
	local camPos = cameraPosition()
	for _, entry in sprayEmitters do
		if now > entry.Next then
			entry.Next = now + rng:NextNumber(2.5, 6)
			if (entry.Position - camPos).Magnitude < 180 then
				entry.Emitter:Emit(rng:NextInteger(14, 26))
			end
		end
	end
end

---------------------------------------------------------------------------
-- Drifting sand + footprints
---------------------------------------------------------------------------
local SANDY = {
	[Enum.Material.Sand] = true, [Enum.Material.Salt] = true, [Enum.Material.Snow] = true,
	[Enum.Material.Sandstone] = true, [Enum.Material.Mud] = true, [Enum.Material.Ground] = true,
}
local drift: ParticleEmitter
local driftHolder: BasePart
local prints: { { Part: BasePart, Born: number } } = {}
local lastStep: { [Player]: { Position: Vector3, Left: boolean } } = {}
local MAX_PRINTS = 70

local function buildDrift()
	driftHolder = newPart({ Size = Vector3.new(30, 0.2, 30), Transparency = 1 })
	driftHolder.Parent = folder
	drift = Instance.new("ParticleEmitter")
	drift.Texture = "rbxasset://textures/particles/smoke_main.dds"
	drift.Color = ColorSequence.new(Color3.fromRGB(230, 206, 160))
	drift.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, 0.75), NumberSequenceKeypoint.new(1, 1) })
	drift.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1.6) })
	drift.Speed = NumberRange.new(4, 7)
	drift.EmissionDirection = Enum.NormalId.Top
	drift.SpreadAngle = Vector2.new(10, 10)
	drift.Acceleration = Vector3.new(6, -1, 3)
	drift.Lifetime = NumberRange.new(1.5, 2.5)
	drift.Rate = 0
	drift.Parent = driftHolder
end

local function stamp(position: Vector3, heading: Vector3, left: boolean, color: Color3)
	local side = heading:Cross(Vector3.yAxis).Unit * (if left then -0.35 else 0.35)
	local print = newPart({
		Name = "Footprint",
		Size = Vector3.new(0.55, 0.05, 0.95),
		Color = color,
		Material = Enum.Material.Sand,
		Transparency = 0.45,
		Sphere = true,
	})
	print.CFrame = CFrame.lookAt(position + side, position + side + heading)
	print.Parent = folder
	table.insert(prints, { Part = print, Born = os.clock() })
	if #prints > MAX_PRINTS then
		local oldest = table.remove(prints, 1)
		if oldest then
			oldest.Part:Destroy()
		end
	end
end

local function updateFeet(dt: number)
	local camPos = cameraPosition()
	local zoneId = beachNear(camPos)
	local myRoot = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	-- drifting sand follows you on the beaches
	if myRoot and zoneId and not reduced() then
		driftHolder.Position = Vector3.new(myRoot.Position.X - 10, 0.4, myRoot.Position.Z - 6)
		drift.Rate = 5
		local zone = Zones.Info[zoneId]
		drift.Color = ColorSequence.new(if zone and zone.Ground then zone.Ground else Color3.fromRGB(230, 206, 160))
	else
		drift.Rate = 0
	end
	-- footprints for everyone walking on sand near the camera
	for _, other in Players:GetPlayers() do
		local character = other.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not root or not humanoid or (root.Position - camPos).Magnitude > 120 then
			continue
		end
		if not SANDY[humanoid.FloorMaterial] or humanoid.MoveDirection.Magnitude < 0.1 then
			continue
		end
		local state = lastStep[other]
		local feet = root.Position - Vector3.new(0, humanoid.HipHeight + root.Size.Y / 2 - 0.02, 0)
		if not state then
			lastStep[other] = { Position = feet, Left = false }
		elseif (feet - state.Position).Magnitude > 2.2 then
			local heading = Vector3.new(humanoid.MoveDirection.X, 0, humanoid.MoveDirection.Z).Unit
			local zone = Zones.Info[zoneId or ""]
			local ground = if zone and zone.Ground then zone.Ground else Color3.fromRGB(226, 200, 146)
			stamp(feet, heading, state.Left, ground:Lerp(Color3.new(0, 0, 0), 0.22))
			state.Position = feet
			state.Left = not state.Left
		end
	end
	-- old prints fade into the sand
	local now = os.clock()
	for i = #prints, 1, -1 do
		local entry = prints[i]
		local age = now - entry.Born
		if age > 14 then
			entry.Part:Destroy()
			table.remove(prints, i)
		elseif age > 8 then
			entry.Part.Transparency = 0.45 + (age - 8) / 6 * 0.55
		end
	end
end

---------------------------------------------------------------------------
-- Crabs + swimmers
---------------------------------------------------------------------------
type Critter = { Model: Model, Parts: { { Part: BasePart, Rel: CFrame } }, Position: Vector3, Target: Vector3, Speed: number, Kind: string, Phase: number, Home: Vector3 }
local critters: { Critter } = {}

local function buildCrab(home: Vector3): Critter
	local model = Instance.new("Model")
	model.Name = "Crab"
	local shell = Color3.fromRGB(220, 90, 50)
	local parts = {}
	local function add(props, rel: CFrame)
		local p = newPart(props)
		p.Parent = model
		table.insert(parts, { Part = p, Rel = rel })
	end
	add({ Size = Vector3.new(1.0, 0.4, 0.8), Color = shell, Material = Enum.Material.SmoothPlastic, Sphere = true }, CFrame.new(0, 0.25, 0))
	for _, x in { -0.6, 0.6 } do
		add({ Size = Vector3.new(0.35, 0.25, 0.3), Color = shell, Material = Enum.Material.SmoothPlastic, Sphere = true }, CFrame.new(x, 0.3, -0.5))
		add({ Size = Vector3.new(0.08, 0.2, 0.08), Color = Color3.fromRGB(30, 30, 30), Material = Enum.Material.SmoothPlastic }, CFrame.new(x * 0.3, 0.5, -0.3))
		for k = 0, 2 do
			add({ Size = Vector3.new(0.5, 0.06, 0.06), Color = shell, Material = Enum.Material.SmoothPlastic }, CFrame.new(x * 0.9, 0.12, -0.2 + k * 0.25) * CFrame.Angles(0, 0, x > 0 and -0.4 or 0.4))
		end
	end
	model.Parent = folder
	return { Model = model, Parts = parts, Position = home, Target = home, Speed = 5, Kind = "Crab", Phase = rng:NextNumber() * 10, Home = home }
end

local function buildSwimmer(home: Vector3): Critter
	local model = Instance.new("Model")
	model.Name = "Swimmer"
	local parts = {}
	local function add(props, rel: CFrame)
		local p = newPart(props)
		p.Parent = model
		table.insert(parts, { Part = p, Rel = rel })
	end
	local skin = ({ Color3.fromRGB(240, 200, 165), Color3.fromRGB(200, 150, 110), Color3.fromRGB(140, 95, 65) })[rng:NextInteger(1, 3)]
	add({ Size = Vector3.new(0.9, 0.9, 0.9), Color = skin, Material = Enum.Material.SmoothPlastic, Sphere = true }, CFrame.new(0, 0.55, 0))
	add({ Size = Vector3.new(0.95, 0.4, 0.95), Color = ({ Color3.fromRGB(230, 60, 60), Color3.fromRGB(40, 90, 200), Color3.fromRGB(250, 220, 60) })[rng:NextInteger(1, 3)], Material = Enum.Material.Fabric, Sphere = true }, CFrame.new(0, 0.85, 0.05)) -- swim cap
	add({ Size = Vector3.new(0.5, 3.2, 3.2), Color = Color3.fromRGB(250, 120, 160), Material = Enum.Material.SmoothPlastic, Shape = Enum.PartType.Cylinder }, CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90))) -- float ring
	for _, x in { -1.1, 1.1 } do
		add({ Size = Vector3.new(1.2, 0.3, 0.35), Color = skin, Material = Enum.Material.SmoothPlastic, Sphere = true }, CFrame.new(x, 0.2, 0))
	end
	model.Parent = folder
	return { Model = model, Parts = parts, Position = home, Target = home, Speed = 1.2, Kind = "Swimmer", Phase = rng:NextNumber() * 10, Home = home }
end

local function updateCritters(dt: number, now: number)
	local camPos = cameraPosition()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for _, critter in critters do
		if (critter.Home - camPos).Magnitude > 200 then
			continue
		end
		if critter.Kind == "Crab" then
			local threat = root ~= nil and ((root :: BasePart).Position - critter.Position).Magnitude < 8
			if threat then
				local away = (critter.Position - (root :: BasePart).Position) * Vector3.new(1, 0, 1)
				critter.Target = critter.Position + (if away.Magnitude > 0.1 then away.Unit else Vector3.new(1, 0, 0)) * 10
				critter.Speed = 11
			elseif (critter.Target - critter.Position).Magnitude < 0.5 and rng:NextNumber() < dt * 0.5 then
				critter.Target = critter.Home + Vector3.new(rng:NextNumber(-10, 10), 0, rng:NextNumber(-6, 6))
				critter.Speed = 4
			end
		elseif (critter.Target - critter.Position).Magnitude < 0.5 then
			critter.Target = critter.Home + Vector3.new(rng:NextNumber(-8, 8), 0, rng:NextNumber(-3, 3))
		end
		local step = (critter.Target - critter.Position) * Vector3.new(1, 0, 1)
		local move = if step.Magnitude > critter.Speed * dt then step.Unit * critter.Speed * dt else step
		critter.Position += move
		local cf
		if critter.Kind == "Crab" then
			-- crabs walk sideways
			local side = if move.Magnitude > 1e-3 then move.Unit else Vector3.new(1, 0, 0)
			local facing = side:Cross(Vector3.yAxis)
			local wobble = if move.Magnitude > 1e-3 then math.sin(now * 30) * 0.05 else 0
			cf = CFrame.lookAt(critter.Position, critter.Position + facing) * CFrame.new(0, wobble, 0)
		else
			local bob = math.sin(now * 1.3 + critter.Phase) * 0.25
			cf = CFrame.new(critter.Position.X, WATER_Y - 0.25 + bob, critter.Position.Z) * CFrame.Angles(0, now * 0.1 + critter.Phase, 0)
		end
		for _, entry in critter.Parts do
			entry.Part.CFrame = cf * entry.Rel
		end
	end
end

---------------------------------------------------------------------------
function Ambience:Init(all)
	controllers = all
end

function Ambience:Start()
	folder = Instance.new("Folder")
	folder.Name = "Ambience"
	folder.Parent = Workspace
	local map = Workspace:WaitForChild("Map", 60)
	if not map then
		return
	end
	task.wait(2) -- let the map and terrain settle

	-- curiosities: "Look closer"
	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local text = prompt:GetAttribute("Curio")
		if type(text) == "string" then
			controllers.Notify:Toast("🔍 " .. prompt.ObjectText .. " - " .. text, "Info", 6)
			local anchor = prompt.Parent
			if anchor and anchor:IsA("BasePart") then
				controllers.Effects:Sparkles(anchor.Position, Color3.fromRGB(255, 236, 170), 10, 3)
			end
		end
	end)

	collectPerches()
	collectAnimated()
	buildFoam()
	buildSpray()
	buildDrift()
	for _ = 1, 9 do
		table.insert(gulls, buildGull())
	end
	for kind = 1, 3 do
		table.insert(boats, buildBoat(kind))
	end
	table.insert(boats, buildBoat(2))
	-- crabs on every beach, swimmers in the safe shallows of the family beaches
	local zones = map:FindFirstChild("Zones")
	for _, zone in if zones then zones:GetChildren() else {} do
		local area = zone:FindFirstChild("DigArea") :: BasePart?
		if area then
			for k = 1, 2 do
				table.insert(critters, buildCrab(Vector3.new(area.Position.X + rng:NextNumber(-50, 50), 0.05, rng:NextNumber(-8, 20) + (if zone.Name == "SecretIsland" then area.Position.Z - 30 else 0) + k)))
			end
			if zone.Name == "StartingBeach" or zone.Name == "TropicalIsland" then
				for _ = 1, 3 do
					table.insert(critters, buildSwimmer(Vector3.new(area.Position.X + rng:NextNumber(-45, 45), WATER_Y, rng:NextNumber(-33, -24))))
				end
			end
		end
	end

	local last = os.clock()
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		local dt = math.min(now - last, 0.1)
		last = now
		if reduced() then
			drift.Rate = 0
			return
		end
		updateGulls(dt, now)
		updateBoats(dt, now)
		updateAnimated(now)
		updateFoam(now)
		updateSpray(now)
		updateFeet(dt)
		updateCritters(dt, now)
	end)
	Players.PlayerRemoving:Connect(function(other)
		lastStep[other] = nil
	end)
end

return Ambience
