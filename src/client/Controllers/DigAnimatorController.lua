--[[
	DigAnimatorController
	A physical, grounded digging animation for EVERY player's character - built in code, so no
	animation assets need uploading. Inspired by a real person digging with a long shovel:

	  ready   knees bent, body leaning in, both hands on the shaft, blade resting on the sand
	  windup  straighten up a little and lift the shovel
	  strike  drive the blade down into the sand (lean right in, knees bend, sand bursts)
	  pry     lever the handle back to loosen the sand
	  toss    twist the upper body and flick the scoop of sand to the side (clumps fly)

	Three variations (overhead chop, side scoop, double jab) keep it from looking repetitive.
	Torso, arms, legs and head move together, and the shovel stays in the right hand (the tool is
	welded to it), so the blade follows the swing.

	How it's driven:
	  * your own character: DigController calls SetActive (dig started/ended) and Swing (each click)
	    straight away, so it reacts instantly
	  * everyone else: the server sets attributes on their character while they dig
	      DigHole (Vector3)  where they're digging      DigSwings (number) +1 per counted swing
	      DigSpeed (number)  their shovel's swing speed
	The swing cycle runs at its own steady tempo (faster shovels swing faster). Clicking keeps the
	cycle going; stop clicking and the character settles back into the ready pose.

	Sand that settles: every strike sprays a few grains around the rim and every toss flings
	clumps to the side. They fly on a simple ballistic path, land on whatever is below (raycast),
	flatten into little piles, rest for a few seconds and then sink away. At most 48 are alive at
	once (the oldest is recycled) and nothing is created far from the camera or with Reduced Motion.

	Works with R15 and R6 avatars, and with both joint systems: classic Motor6Ds and Roblox's
	newer AnimationConstraint joints (Avatar Joint Upgrade). It adjusts each joint's Transform
	after the default Animate script has posed the character, blending smoothly in and out.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Zones = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config.Zones)

local DigAnimator = {}

local controllers
local player = Players.LocalPlayer
local DEG = math.rad

type Pose = { [string]: number }
type Joint = { Motor: any, Rot: CFrame } -- Motor6D or AnimationConstraint (both have .Transform)
type Rig = {
	Character: Model,
	Humanoid: Humanoid,
	R15: boolean,
	Joints: { [string]: Joint },
	Weight: number,
	Active: boolean,
	Hole: Vector3?,
	Speed: number,
	Playing: boolean,
	Pending: boolean,
	Phase: number,
	Variant: number,
	Fired: { [string]: boolean },
	SeenSwings: number,
}

local rigs: { [Model]: Rig } = {}

---------------------------------------------------------------------------
-- Poses (degrees; drop in studs). Sign convention (R15 terms):
--   lean   + = upper body tips forward          twist  + = turn left, - = turn right
--   neck   + = look down                        drop   + = sink the hips
--   rArm / lArm  + = raise the arm forward      rIn / lIn  + = bring the arm across the body
--   rElbow / lElbow  + = bend                    hip + = thigh forward   knee + = bend
---------------------------------------------------------------------------
local READY: Pose = { lean = 18, twist = 0, drop = 0.15, neck = 12, rArm = 98, rIn = 12, rElbow = 10, lArm = 80, lIn = 28, lElbow = 25, hip = 14, knee = 28 }

local function pose(overrides: Pose): Pose
	local p = table.clone(READY)
	for key, value in overrides do
		p[key] = value
	end
	return p
end

local WINDUP = pose({ lean = 6, twist = 6, drop = 0.05, neck = -4, rArm = 150, rIn = 8, rElbow = 20, lArm = 130, lIn = 24, lElbow = 30, hip = 6, knee = 12 })
local STRIKE = pose({ lean = 34, drop = 0.35, neck = 18, rArm = 96, rElbow = 5, lArm = 84, lIn = 30, lElbow = 12, hip = 24, knee = 44 })
local PRY = pose({ lean = 24, twist = -6, drop = 0.25, neck = 14, rArm = 118, rIn = 14, rElbow = 18, lArm = 92, lIn = 26, lElbow = 30, hip = 18, knee = 34 })
local TOSS_RIGHT = pose({ lean = 14, twist = -38, drop = 0.12, neck = 6, rArm = 132, rIn = 4, rElbow = 26, lArm = 108, lIn = 20, lElbow = 34, hip = 10, knee = 20 })
local TOSS_LEFT = pose({ lean = 14, twist = 34, drop = 0.12, neck = 6, rArm = 130, rIn = 26, rElbow = 22, lArm = 112, lIn = 8, lElbow = 30, hip = 10, knee = 20 })
local LOW_WINDUP = pose({ lean = 12, twist = 10, drop = 0.1, neck = 4, rArm = 128, rIn = 10, rElbow = 18, lArm = 110, lIn = 26, lElbow = 26, hip = 10, knee = 18 })
local SCOOP = pose({ lean = 28, twist = 12, drop = 0.3, neck = 16, rArm = 108, rIn = 18, rElbow = 14, lArm = 96, lIn = 22, lElbow = 22, hip = 22, knee = 40 })
local JAB_UP = pose({ lean = 16, drop = 0.12, neck = 10, rArm = 118, rElbow = 16, lArm = 100, lElbow = 26, hip = 12, knee = 24 })

-- keyframes: { t (0-1 of the cycle), pose, ease ("in" = accelerate into the hit) }; events at t
local VARIANTS = {
	{ -- overhead chop: lift, drive down, pry, toss to the right
		Keys = { { 0, READY }, { 0.26, WINDUP }, { 0.4, STRIKE, "in" }, { 0.58, PRY }, { 0.78, TOSS_RIGHT }, { 1, READY } },
		Hits = { 0.4 },
		Toss = { At = 0.74, Side = -1 },
	},
	{ -- side scoop: low lift, dig in, scoop across and toss to the left
		Keys = { { 0, READY }, { 0.24, LOW_WINDUP }, { 0.38, STRIKE, "in" }, { 0.6, SCOOP }, { 0.8, TOSS_LEFT }, { 1, READY } },
		Hits = { 0.38 },
		Toss = { At = 0.76, Side = 1 },
	},
	{ -- double jab: two quick stabs to break the sand, then a short pry
		Keys = { { 0, READY }, { 0.16, JAB_UP }, { 0.28, STRIKE, "in" }, { 0.44, JAB_UP }, { 0.58, STRIKE, "in" }, { 0.8, PRY }, { 1, READY } },
		Hits = { 0.28, 0.58 },
		Toss = nil,
	},
}

local function ease(t: number, mode: string?): number
	if mode == "in" then
		return t * t * t -- slow start, fast finish: the blade "drops" into the sand
	end
	return t * t * (3 - 2 * t) -- smoothstep
end

local function samplePose(variant, phase: number): Pose
	local keys = variant.Keys
	for index = 1, #keys - 1 do
		local a, b = keys[index] :: any, keys[index + 1] :: any
		if phase <= b[1] then
			local t = ease(math.clamp((phase - a[1]) / math.max(1e-3, b[1] - a[1]), 0, 1), b[3])
			local result = {}
			for key, value in a[2] do
				result[key] = value + (b[2][key] - value) * t
			end
			return result
		end
	end
	return (keys[#keys] :: any)[2]
end

---------------------------------------------------------------------------
-- Rig setup
---------------------------------------------------------------------------
local function findMotor(character: Model, partName: string, motorName: string): Joint?
	local part = character:FindFirstChild(partName)
	local motor = part and part:FindFirstChild(motorName)
	if motor and motor:IsA("Motor6D") then
		return { Motor = motor, Rot = motor.C0.Rotation }
	elseif motor and motor:IsA("AnimationConstraint") then
		-- new joints: Attachment1 = Attachment0 * Transform, so Attachment0 plays the role of C0
		local attachment = motor.Attachment0
		return { Motor = motor, Rot = if attachment then attachment.CFrame.Rotation else CFrame.identity }
	end
	return nil
end

local function buildRig(character: Model): Rig?
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end
	local r15 = humanoid.RigType == Enum.HumanoidRigType.R15
	local joints: { [string]: Joint } = {}
	local function add(key: string, joint: Joint?)
		if joint then
			joints[key] = joint
		end
	end
	if r15 then
		add("Root", findMotor(character, "LowerTorso", "Root"))
		add("Waist", findMotor(character, "UpperTorso", "Waist"))
		add("Neck", findMotor(character, "Head", "Neck"))
		add("RShoulder", findMotor(character, "RightUpperArm", "RightShoulder"))
		add("RElbow", findMotor(character, "RightLowerArm", "RightElbow"))
		add("LShoulder", findMotor(character, "LeftUpperArm", "LeftShoulder"))
		add("LElbow", findMotor(character, "LeftLowerArm", "LeftElbow"))
		add("RHip", findMotor(character, "RightUpperLeg", "RightHip"))
		add("RKnee", findMotor(character, "RightLowerLeg", "RightKnee"))
		add("LHip", findMotor(character, "LeftUpperLeg", "LeftHip"))
		add("LKnee", findMotor(character, "LeftLowerLeg", "LeftKnee"))
	else
		add("Root", findMotor(character, "HumanoidRootPart", "RootJoint"))
		add("Neck", findMotor(character, "Torso", "Neck"))
		add("RShoulder", findMotor(character, "Torso", "Right Shoulder"))
		add("LShoulder", findMotor(character, "Torso", "Left Shoulder"))
		add("RHip", findMotor(character, "Torso", "Right Hip"))
		add("LHip", findMotor(character, "Torso", "Left Hip"))
	end
	if not joints.RShoulder then
		return nil
	end
	return {
		Character = character,
		Humanoid = humanoid,
		R15 = r15,
		Joints = joints,
		Weight = 0,
		Active = false,
		Hole = nil,
		Speed = 6,
		Playing = false,
		Pending = false,
		Phase = 0,
		Variant = 1,
		Fired = {},
		SeenSwings = 0,
	}
end

local function getRig(character: Model): Rig?
	local rig = rigs[character]
	if rig and rig.Humanoid.Parent == character then
		return rig
	end
	local built = buildRig(character)
	if built then
		rigs[character] = built
		character.Destroying:Connect(function()
			rigs[character] = nil
		end)
	end
	return built
end

---------------------------------------------------------------------------
-- Applying a pose
---------------------------------------------------------------------------
-- rotation/offset are expressed in the joint's Part0 space (character axes); the joint's own C0
-- rotation is undone so the same pose works for R15 and R6
local function setJoint(rig: Rig, name: string, rotation: CFrame, offset: Vector3?, weight: number)
	local joint = rig.Joints[name]
	if not joint or weight <= 0.001 then
		return
	end
	local inverse = joint.Rot:Inverse()
	local target = CFrame.new(inverse * (offset or Vector3.zero)) * (inverse * rotation * joint.Rot)
	joint.Motor.Transform = joint.Motor.Transform:Lerp(target, math.clamp(weight, 0, 1))
end

local function applyPose(rig: Rig, p: Pose, weight: number)
	local moving = rig.Humanoid.MoveDirection.Magnitude > 0.1
	local legWeight = if moving then 0 else weight
	local lean, twist = p.lean, p.twist
	if rig.R15 then
		setJoint(rig, "Root", CFrame.Angles(0, DEG(twist * 0.3), 0), Vector3.new(0, -p.drop * legWeight, 0), weight)
		setJoint(rig, "Waist", CFrame.Angles(DEG(-lean), DEG(twist * 0.7), 0), nil, weight)
		setJoint(rig, "Neck", CFrame.Angles(DEG(-p.neck), 0, 0), nil, weight)
		setJoint(rig, "RShoulder", CFrame.Angles(DEG(p.rArm), 0, DEG(-p.rIn)), nil, weight)
		setJoint(rig, "RElbow", CFrame.Angles(DEG(p.rElbow), 0, 0), nil, weight)
		setJoint(rig, "LShoulder", CFrame.Angles(DEG(p.lArm), 0, DEG(p.lIn)), nil, weight)
		setJoint(rig, "LElbow", CFrame.Angles(DEG(p.lElbow), 0, 0), nil, weight)
		setJoint(rig, "RHip", CFrame.Angles(DEG(p.hip), DEG(-twist * 0.3), 0), nil, legWeight)
		setJoint(rig, "LHip", CFrame.Angles(DEG(p.hip * 0.8), DEG(-twist * 0.3), 0), nil, legWeight)
		setJoint(rig, "RKnee", CFrame.Angles(DEG(-p.knee), 0, 0), nil, legWeight)
		setJoint(rig, "LKnee", CFrame.Angles(DEG(-p.knee * 0.8), 0, 0), nil, legWeight)
	else
		-- R6: the whole torso leans on the root joint; the hips counter-rotate so the legs stay planted
		setJoint(rig, "Root", CFrame.Angles(DEG(-lean), DEG(twist), 0), Vector3.new(0, -p.drop * legWeight, 0), weight)
		setJoint(rig, "Neck", CFrame.Angles(DEG(-p.neck), 0, 0), nil, weight)
		setJoint(rig, "RShoulder", CFrame.Angles(DEG(p.rArm + p.rElbow * 0.5), 0, DEG(-p.rIn)), nil, weight)
		setJoint(rig, "LShoulder", CFrame.Angles(DEG(p.lArm + p.lElbow * 0.5), 0, DEG(p.lIn)), nil, weight)
		setJoint(rig, "RHip", CFrame.Angles(DEG(p.hip + lean), DEG(-twist), 0), nil, weight)
		setJoint(rig, "LHip", CFrame.Angles(DEG(p.hip * 0.8 + lean), DEG(-twist), 0), nil, weight)
	end
end

---------------------------------------------------------------------------
-- Effects at the hole
---------------------------------------------------------------------------
local SAND = Color3.fromRGB(226, 196, 140)

local function nearCamera(position: Vector3, range: number): boolean
	local camera = Workspace.CurrentCamera
	return camera ~= nil and (camera.CFrame.Position - position).Magnitude < range
end

-- clumps of sand flung off the blade (local physics only: cheap, nothing replicates)
---------------------------------------------------------------------------
-- Settling sand: little clumps that fly, land, flatten, rest and sink away
---------------------------------------------------------------------------
type Bit = { Part: BasePart, Velocity: Vector3, Size: number, Landed: number? }
local MAX_BITS = 48
local GRAVITY = Vector3.new(0, -48, 0)
local REST_TIME = 3.5
local SINK_TIME = 1.2
local bits: { Bit } = {}
local bitsFolder: Folder
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = false

local function spawnBit(position: Vector3, velocity: Vector3, size: number, color: Color3)
	local bit: Bit
	if #bits >= MAX_BITS then
		bit = table.remove(bits, 1) :: Bit -- recycle the oldest
	else
		local part = Instance.new("Part")
		part.Name = "SandBit"
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Material = Enum.Material.Sand
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
		part.Parent = bitsFolder
		bit = { Part = part, Velocity = Vector3.zero, Size = size }
	end
	bit.Velocity = velocity
	bit.Size = size
	bit.Landed = nil
	bit.Part.Size = Vector3.new(size, size, size)
	bit.Part.Color = color
	bit.Part.Transparency = 0
	bit.Part.CFrame = CFrame.new(position)
	table.insert(bits, bit)
end

local function updateBits(dt: number)
	if #bits == 0 then
		return
	end
	local exclude: { Instance } = { bitsFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local effects = Workspace:FindFirstChild("DigEffects")
	if effects then
		table.insert(exclude, effects)
	end
	rayParams.FilterDescendantsInstances = exclude
	local now = os.clock()
	local index = 1
	while index <= #bits do
		local bit = bits[index]
		local part = bit.Part
		if bit.Landed then
			local age = now - bit.Landed
			if age > REST_TIME then
				-- sink into the beach and fade
				local t = math.min(1, (age - REST_TIME) / SINK_TIME)
				part.Transparency = t
				part.CFrame = part.CFrame - Vector3.new(0, dt * 0.25, 0)
				if t >= 1 then
					part:Destroy()
					table.remove(bits, index)
					continue
				end
			end
		else
			local from = part.Position
			bit.Velocity += GRAVITY * dt
			local step = bit.Velocity * dt
			local hit = Workspace:Raycast(from, step, rayParams)
			if hit then
				-- land and flatten into a little pile that matches the slope
				local flat = bit.Size * 1.5
				part.Size = Vector3.new(flat, bit.Size * 0.45, flat * 0.9)
				part.CFrame = CFrame.lookAt(hit.Position, hit.Position + hit.Normal) * CFrame.Angles(math.rad(-90), 0, 0)
					+ hit.Normal * (bit.Size * 0.12)
				bit.Landed = now
			elseif from.Y < -60 then
				part:Destroy()
				table.remove(bits, index)
				continue
			else
				part.CFrame = CFrame.new(from + step)
			end
		end
		index += 1
	end
end

-- this beach's sand colour (black volcanic sand throws up black clumps, white sand white ones)
local function groundColors(): (Color3, Color3)
	local data = controllers.State.Data
	local zone = data and data.CurrentZone and Zones.Info[data.CurrentZone]
	local ground = if zone and zone.Ground then zone.Ground else SAND
	return ground, ground:Lerp(Color3.new(0, 0, 0), 0.3)
end

-- a fan of sand thrown out of the hole (used for tosses, strikes and the final eruption)
local function spray(origin: Vector3, direction: Vector3?, count: number, speed: number, spread: number)
	if controllers.Effects:Reduced() then
		return
	end
	local dry, wet = groundColors()
	for i = 1, count do
		local angle = math.random() * math.pi * 2
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		if direction then
			out = (direction + out * spread).Unit
		end
		local velocity = out * (speed * (0.6 + math.random() * 0.6)) + Vector3.new(0, speed * (0.9 + math.random() * 0.5), 0)
		local size = 0.18 + math.random() * 0.3
		spawnBit(origin + Vector3.new(0, 0.3, 0), velocity, size, if i % 3 == 0 then wet else dry:Lerp(wet, math.random() * 0.4))
	end
end

local function tossClumps(rig: Rig, side: number)
	local hole = rig.Hole
	local root = rig.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hole or not root or not nearCamera(hole, 140) or controllers.Effects:Reduced() then
		return
	end
	local right = (root :: BasePart).CFrame.RightVector
	local forward = (root :: BasePart).CFrame.LookVector
	-- the scoop leaves the blade and lands to the side, where it piles up and settles
	spray(hole + Vector3.new(0, 1.1, 0) + forward * 0.4, right * -side, 7, 9, 0.35)
	controllers.Effects:SandBurst(hole + (right * -side * 3), 6)
end

local function hitSand(rig: Rig)
	local hole = rig.Hole
	if not hole or not nearCamera(hole, 140) then
		return
	end
	controllers.Effects:SandBurst(hole, 10)
	spray(hole, nil, 4, 5, 1) -- grains scatter around the rim and settle there
	if rig.Character == player.Character then
		controllers.Effects:Shake(0.12, 0.06)
	end
end

-- The final eruption when a treasure comes out: a ring of sand that lands and settles
function DigAnimator:Erupt(position: Vector3)
	if not nearCamera(position, 160) then
		return
	end
	spray(position, nil, 16, 10, 1)
end

-- The hole caves in (a treasure lost in the sand): the rim slumps inwards and a puff rises
function DigAnimator:Collapse(position: Vector3)
	if not nearCamera(position, 160) or controllers.Effects:Reduced() then
		return
	end
	local dry, wet = groundColors()
	for i = 1, 18 do
		local angle = (i / 18) * math.pi * 2 + math.random() * 0.3
		local out = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local from = position + out * (2.2 + math.random() * 1.2) + Vector3.new(0, 0.6 + math.random() * 0.6, 0)
		local velocity = -out * (3 + math.random() * 3) + Vector3.new(0, 1.5 + math.random() * 2, 0)
		spawnBit(from, velocity, 0.25 + math.random() * 0.3, dry:Lerp(wet, math.random() * 0.6))
	end
	spray(position, nil, 6, 4, 1)
end

---------------------------------------------------------------------------
-- Swing control
---------------------------------------------------------------------------
local function cycleLength(rig: Rig): number
	return math.clamp(1.0 - rig.Speed * 0.045, 0.48, 0.78)
end

local function startCycle(rig: Rig)
	rig.Playing = true
	rig.Pending = false
	rig.Phase = 0
	table.clear(rig.Fired)
	-- next variation (never the same twice in a row)
	local nextVariant = math.random(1, #VARIANTS - 1)
	if nextVariant >= rig.Variant then
		nextVariant += 1
	end
	rig.Variant = nextVariant
end

-- Start (or keep going) the dig animation for this character
function DigAnimator:SetActive(character: Model?, hole: Vector3?, speed: number?)
	if not character then
		return
	end
	local rig = getRig(character)
	if not rig then
		return
	end
	rig.Active = hole ~= nil
	rig.Hole = hole
	rig.Speed = speed or rig.Speed
	if not rig.Active then
		rig.Pending = false
	end
end

-- One shovel swing was made
function DigAnimator:Swing(character: Model?)
	local rig = character and getRig(character)
	if not rig or not rig.Active then
		return
	end
	if rig.Playing then
		rig.Pending = true -- carry straight on into the next swing
	else
		startCycle(rig)
	end
end

local function step(dt: number)
	for character, rig in rigs do
		if not character.Parent then
			rigs[character] = nil
			continue
		end
		local target = if rig.Active then 1 else 0
		rig.Weight += (target - rig.Weight) * math.min(1, dt * (if rig.Active then 9 else 6))
		if rig.Weight < 0.01 and not rig.Active then
			rig.Weight = 0
			rig.Playing = false
			continue
		end
		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if root and character ~= player.Character and not nearCamera((root :: BasePart).Position, 160) then
			continue
		end

		local current = READY
		if rig.Playing then
			rig.Phase += dt / cycleLength(rig)
			local variant = VARIANTS[rig.Variant]
			for _, hitAt in variant.Hits do
				local key = "Hit" .. hitAt
				if rig.Phase >= hitAt and not rig.Fired[key] then
					rig.Fired[key] = true
					hitSand(rig)
				end
			end
			if variant.Toss and rig.Phase >= variant.Toss.At and not rig.Fired.Toss then
				rig.Fired.Toss = true
				tossClumps(rig, variant.Toss.Side)
			end
			if rig.Phase >= 1 then
				if rig.Pending and rig.Active then
					startCycle(rig)
				else
					rig.Playing = false
				end
				current = READY
			else
				current = samplePose(variant, rig.Phase)
			end
		end
		applyPose(rig, current, rig.Weight)
	end
end

---------------------------------------------------------------------------
-- Other players: follow the server's attributes on their characters
---------------------------------------------------------------------------
local function watchCharacter(character: Model)
	if character == player.Character then
		return -- your own character is driven directly by DigController
	end
	local function refresh()
		local hole = character:GetAttribute("DigHole")
		DigAnimator:SetActive(character, if typeof(hole) == "Vector3" then hole else nil, character:GetAttribute("DigSpeed"))
	end
	character:GetAttributeChangedSignal("DigHole"):Connect(refresh)
	character:GetAttributeChangedSignal("DigSwings"):Connect(function()
		local swings = character:GetAttribute("DigSwings")
		local rig = rigs[character]
		if type(swings) == "number" and swings > 0 and rig and rig.Active then
			DigAnimator:Swing(character)
		end
	end)
	refresh()
end

local function watchPlayer(other: Player)
	if other.Character then
		task.spawn(watchCharacter, other.Character)
	end
	other.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid", 10)
		watchCharacter(character)
	end)
end

function DigAnimator:Init(all)
	controllers = all
end

function DigAnimator:Start()
	for _, other in Players:GetPlayers() do
		if other ~= player then
			watchPlayer(other)
		end
	end
	Players.PlayerAdded:Connect(watchPlayer)
	-- after the Animator has posed everyone this frame
	bitsFolder = Instance.new("Folder")
	bitsFolder.Name = "SettlingSand"
	bitsFolder.Parent = Workspace
	RunService.Heartbeat:Connect(updateBits)

	-- PreSimulation runs after the Animator writes joints, so our Transform blend stacks on top (vault: Procedural Animation)
	RunService.PreSimulation:Connect(function(dt)
		step(math.min(dt, 0.1))
	end)
end

return DigAnimator
