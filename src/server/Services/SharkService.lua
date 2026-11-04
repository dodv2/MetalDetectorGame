--[[
	SharkService (Update 17: real attacks)
	Sharks patrol the open sea, hunt swimmers and bite.

	* One shark cruises offshore of every beach, one circles Secret Treasure Island. While they
	  patrol, the server and every client compute the same time-based path (SharkModels), so
	  nothing is streamed. When a shark hunts, the SERVER moves it (and publishes its position as
	  attributes 10x a second); clients just glide the model there.
	* Only SWIMMERS in open water are hunted: past the shallows off the beaches, or out around
	  Secret Island. Players on the sand, wading in the shallows or on the Pier (its deck and
	  jetty are above the water) are never targets, and sharks can't swim into the shallows -
	  their water is clamped to the ocean bounds.
	* A shark picks the nearest swimmer in its water (one target per shark, one shark per
	  swimmer), races to them and bites when it's close: a lunge, damage, then it circles for the
	  next bite. Bites need a clear line through the water (no biting through terrain, the jetty
	  or rocks). Per-player bite cooldown is shared by all sharks, so bites never stack.
	* A swimmer who reaches the shallows (or the sharks' water bounds stop the shark) is
	  released after a few seconds and the shark swims back to its patrol path.
	* At 0 HP it's a normal Roblox death: the character respawns on the Pier (the only
	  SpawnLocation). Backpack, cash and progress live in the save, so nothing is lost, and an
	  active dig is stopped safely by TreasureService.

	Shark state (Workspace > Sharks > <Configuration> attributes):
	  Kind ("Coast"/"Island"), CX, CZ, Width, Reach, HalfX, HalfZ, Phase       patrol path
	  Mode ("Patrol"/"Chase"/"Return"), PX, PZ, Heading                       live position
	  TargetUserId, BiteAt (server time of the last bite, drives the lunge)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local SharkModels = require(Shared.SharkModels)
local Net = require(Shared.Net)

local SharkService = {}

local services
local folder: Folder
local biteRemote: RemoteEvent

type Shark = {
	Config: Configuration,
	Position: Vector3,
	Heading: Vector3,
	Mode: string, -- "Patrol" | "Chase" | "Return"
	Target: Player?,
	ChaseStart: number,
	LastClose: number, -- last time it was within reach of its target (or still closing in)
	LastDistance: number,
	NextBite: number,
	LastPublish: number,
}

local sharks: { Shark } = {}
local lastBite: { [Player]: number } = {} -- shared by ALL sharks: bites never stack
local released: { [Player]: number } = {} -- short breather after escaping

local SHORE_SAFE_Z = -38 -- swimmers north of this line (the shallows) are never hunted
local SHARK_MIN_Z = -45 -- coast sharks never come closer to shore than this
local SEA_FAR_Z = -440 -- open-sea limit (the invisible south wall)
local ISLAND_MARGIN = 26 -- studs of shallow water around Secret Island that are still safe
local ISLAND_KEEP_OUT = 1.08 -- island sharks stay outside this much of the safe ellipse
local CHASE_SPEED = 30 -- players swim at 22
local RETURN_SPEED = 18
local BITE_RANGE = 6.5
local BITE_DAMAGE = 18
local PLAYER_BITE_COOLDOWN = 1.7
local SHARK_BITE_RECOVER = 1.1
local GIVE_UP_AFTER = 4 -- seconds without getting closer (or within reach) before giving up
local MAX_CHASE = 30
local RELEASE_BREATHER = 2.5
local TICK = 0.1

local function serverNow(): number
	return Workspace:GetServerTimeNow()
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

local function makeShark(id: string, attrs: { [string]: any }): Shark
	local config = Instance.new("Configuration")
	config.Name = id
	for key, value in attrs do
		config:SetAttribute(key, value)
	end
	config:SetAttribute("Mode", "Patrol")
	config:SetAttribute("TargetUserId", 0)
	config:SetAttribute("BiteAt", 0)
	config.Parent = folder
	local start = SharkModels.PatrolPosition(config, serverNow())
	local shark: Shark = {
		Config = config,
		Position = start,
		Heading = Vector3.new(1, 0, 0),
		Mode = "Patrol",
		Target = nil,
		ChaseStart = 0,
		LastClose = 0,
		LastDistance = math.huge,
		NextBite = 0,
		LastPublish = 0,
	}
	table.insert(sharks, shark)
	return shark
end

-- Is this position in this shark's hunting water? (and how deep into it, for picking the nearest)
local function inWater(shark: Shark, position: Vector3): boolean
	local config = shark.Config
	if config:GetAttribute("Kind") == "Island" then
		local rx = config:GetAttribute("HalfX") + ISLAND_MARGIN
		local rz = config:GetAttribute("HalfZ") + ISLAND_MARGIN
		local nx, nz = (position.X - config:GetAttribute("CX")) / rx, (position.Z - config:GetAttribute("CZ")) / rz
		local d = math.sqrt(nx * nx + nz * nz)
		return d > 1 and d < 3
	end
	return position.Z < SHORE_SAFE_Z and position.Z > SEA_FAR_Z
end

-- Keep a shark inside its ocean bounds (never in the shallows, never up on an island)
local function clampToSea(shark: Shark, position: Vector3): Vector3
	local config = shark.Config
	if config:GetAttribute("Kind") == "Island" then
		local cx, cz = config:GetAttribute("CX"), config:GetAttribute("CZ")
		local rx = (config:GetAttribute("HalfX") + ISLAND_MARGIN) * ISLAND_KEEP_OUT
		local rz = (config:GetAttribute("HalfZ") + ISLAND_MARGIN) * ISLAND_KEEP_OUT
		local nx, nz = (position.X - cx) / rx, (position.Z - cz) / rz
		local d = math.sqrt(nx * nx + nz * nz)
		if d < 1 and d > 1e-3 then
			return Vector3.new(cx + nx / d * rx, SharkModels.SwimY, cz + nz / d * rz)
		end
		return Vector3.new(position.X, SharkModels.SwimY, position.Z)
	end
	return Vector3.new(math.clamp(position.X, -150, 1000), SharkModels.SwimY, math.clamp(position.Z, SEA_FAR_Z + 10, SHARK_MIN_Z))
end

local function isSwimmer(player: Player): (BasePart?, Humanoid?)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return nil, nil
	end
	-- on the Pier, on a boat, on the sand: not swimming. Only bodies actually in the sea count.
	local swimming = humanoid:GetState() == Enum.HumanoidStateType.Swimming
		or (root.Position.Y < SharkModels.WaterY - 1.2 and humanoid.FloorMaterial == Enum.Material.Air)
	if not swimming then
		return nil, nil
	end
	return root, humanoid
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

-- A clear line through the water from the shark's mouth to the swimmer (no biting through the
-- seabed, rocks, the jetty's pilings...)
local function clearLine(from: Vector3, to: Vector3, character: Model): boolean
	local exclude: { Instance } = { character, folder }
	local effects = Workspace:FindFirstChild("DigEffects")
	if effects then
		table.insert(exclude, effects)
	end
	rayParams.FilterDescendantsInstances = exclude
	local start = Vector3.new(from.X, math.max(from.Y, SharkModels.WaterY - 1), from.Z)
	local result = Workspace:Raycast(start, to - start, rayParams)
	return result == nil
end

function SharkService:Release(shark: Shark)
	local target = shark.Target
	if target then
		released[target] = os.clock() + RELEASE_BREATHER
	end
	shark.Target = nil
	shark.Mode = "Return"
	shark.Config:SetAttribute("TargetUserId", 0)
	shark.Config:SetAttribute("Mode", "Return")
end

function SharkService:Bite(shark: Shark, player: Player, humanoid: Humanoid, root: BasePart)
	local now = os.clock()
	lastBite[player] = now
	shark.NextBite = now + SHARK_BITE_RECOVER
	shark.Config:SetAttribute("BiteAt", serverNow())
	humanoid:TakeDamage(BITE_DAMAGE)
	biteRemote:FireClient(player, { Position = root.Position, Shark = shark.Config.Name })
	if humanoid.Health <= 0 then
		services.StateService:Notify(player, "🦈 A shark got you! You'll wash up on the Pier - your treasures and progress are safe.", "Error")
		self:Release(shark)
	end
end

-- Assign hunters: each swimmer in open water gets the nearest free shark whose water they're in
function SharkService:AssignTargets()
	local clock = os.clock()
	local hunted: { [Player]: boolean } = {}
	for _, shark in sharks do
		if shark.Target then
			hunted[shark.Target] = true
		end
	end
	for _, player in Players:GetPlayers() do
		if hunted[player] or clock < (released[player] or 0) then
			continue
		end
		local root = isSwimmer(player)
		if not root then
			continue
		end
		local best: Shark? = nil
		local bestDist = math.huge
		for _, shark in sharks do
			if shark.Target == nil and inWater(shark, root.Position) then
				local distance = (flat(shark.Position) - flat(root.Position)).Magnitude
				if distance < bestDist then
					best, bestDist = shark, distance
				end
			end
		end
		if best and bestDist < 260 then
			local shark = best :: Shark
			shark.Target = player
			shark.Mode = "Chase"
			shark.ChaseStart = clock
			shark.LastClose = clock
			shark.LastDistance = bestDist
			shark.Config:SetAttribute("TargetUserId", player.UserId)
			shark.Config:SetAttribute("Mode", "Chase")
			services.StateService:Notify(player, "🦈 SHARK! Swim back to the beach or the Pier!", "Error")
		end
	end
end

function SharkService:Step(shark: Shark, dt: number)
	local clock = os.clock()
	local config = shark.Config
	local goal: Vector3
	local speed: number

	if shark.Mode == "Chase" then
		local target = shark.Target
		local root, humanoid = nil, nil
		if target and target.Parent then
			root, humanoid = isSwimmer(target)
		end
		if not root or not humanoid or not inWater(shark, root.Position) or clock - shark.ChaseStart > MAX_CHASE then
			-- out of the water, back in the shallows, dead or gone: let them go
			self:Release(shark)
			return self:Step(shark, dt)
		end
		local distance = (flat(shark.Position) - flat(root.Position)).Magnitude
		if distance < shark.LastDistance - 0.5 or distance <= BITE_RANGE then
			shark.LastClose = clock
		end
		shark.LastDistance = distance
		if clock - shark.LastClose > GIVE_UP_AFTER then
			self:Release(shark) -- it can't reach them (shallows, bounds, blocked): back to patrol
			return self:Step(shark, dt)
		end
		-- close in; once alongside, circle for the next bite
		local swimmer = Vector3.new(root.Position.X, SharkModels.SwimY, root.Position.Z)
		if distance < 4.5 then
			local a = serverNow() * 2.4
			goal = swimmer + Vector3.new(math.cos(a), 0, math.sin(a)) * 5
		else
			goal = swimmer
		end
		speed = CHASE_SPEED
		if distance <= BITE_RANGE and math.abs(root.Position.Y - SharkModels.SwimY) < 7
			and clock >= shark.NextBite and clock - (lastBite[target :: Player] or 0) >= PLAYER_BITE_COOLDOWN
			and clearLine(shark.Position + shark.Heading * 4, root.Position, (target :: Player).Character :: Model) then
			self:Bite(shark, target :: Player, humanoid :: Humanoid, root :: BasePart)
		end
	elseif shark.Mode == "Return" then
		goal = SharkModels.PatrolPosition(config, serverNow())
		speed = RETURN_SPEED
		if (flat(goal) - flat(shark.Position)).Magnitude < 3 then
			shark.Mode = "Patrol"
			config:SetAttribute("Mode", "Patrol")
		end
	else
		shark.Position = SharkModels.PatrolPosition(config, serverNow())
		return
	end

	local step = flat(goal - shark.Position)
	local move = if step.Magnitude > speed * dt then step.Unit * speed * dt else step
	if move.Magnitude > 1e-3 then
		shark.Heading = shark.Heading:Lerp(move.Unit, math.min(1, dt * 6))
		if shark.Heading.Magnitude < 1e-3 then
			shark.Heading = move.Unit
		else
			shark.Heading = shark.Heading.Unit
		end
	end
	shark.Position = clampToSea(shark, shark.Position + move)
	-- publish the live position (clients glide the model to it)
	if clock - shark.LastPublish >= TICK - 0.01 then
		shark.LastPublish = clock
		config:SetAttribute("PX", math.floor(shark.Position.X * 10 + 0.5) / 10)
		config:SetAttribute("PZ", math.floor(shark.Position.Z * 10 + 0.5) / 10)
		config:SetAttribute("Heading", math.floor(math.atan2(shark.Heading.X, shark.Heading.Z) * 100 + 0.5) / 100)
	end
end

function SharkService:Tick(dt: number)
	self:AssignTargets()
	for _, shark in sharks do
		self:Step(shark, dt)
	end
end

-- Nobody can be the target of a shark that's gone (left, died...)
local function forget(player: Player)
	for _, shark in sharks do
		if shark.Target == player then
			SharkService:Release(shark)
		end
	end
	lastBite[player] = nil
	released[player] = nil
end

function SharkService:Init(allServices)
	services = allServices
	biteRemote = Net.Event("SharkBite")
end

function SharkService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Sharks"
	folder.Parent = Workspace

	local map = Workspace:WaitForChild("Map")
	local zones = map:WaitForChild("Zones")
	local phase = 0
	for _, zoneFolder in zones:GetChildren() do
		local digArea = zoneFolder:FindFirstChild("DigArea") :: BasePart?
		if digArea then
			phase += 1.7
			if zoneFolder.Name == "SecretIsland" then
				makeShark("Shark_" .. zoneFolder.Name, {
					Kind = "Island",
					CX = digArea.Position.X,
					CZ = digArea.Position.Z,
					HalfX = digArea.Size.X / 2 + 20,
					HalfZ = digArea.Size.Z / 2 + 20,
					Phase = phase,
				})
			else
				makeShark("Shark_" .. zoneFolder.Name, {
					Kind = "Coast",
					CX = digArea.Position.X,
					CZ = -80,
					Width = digArea.Size.X,
					-- Starting Beach's shark keeps clear of the Pier's jetty on the west side
					Reach = if zoneFolder.Name == "StartingBeach" then 0.34 else 0.42,
					Phase = phase,
				})
			end
		end
	end

	Players.PlayerRemoving:Connect(forget)
	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			forget(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		player.CharacterAdded:Connect(function()
			forget(player)
		end)
	end

	local last = os.clock()
	while true do
		task.wait(TICK)
		local now = os.clock()
		local ok, err = pcall(self.Tick, self, math.min(now - last, 0.3))
		last = now
		if not ok then
			warn("[SharkService] " .. tostring(err))
		end
	end
end

return SharkService
