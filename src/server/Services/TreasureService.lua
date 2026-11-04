--[[
	TreasureService
	The heart of the game: buried treasures, the detector signal, and digging.

	* Each player has their OWN buried treasures in each zone (no fighting over spots).
	  Their positions never leave the server - the client only receives signal strength,
	  a (noisy) distance and a (noisy) direction, so exploiters can't see where treasure is.
	* The treasure (and its rarity) is rolled when it's buried, using the player's Luck.
	  Boosts/events re-roll un-dug treasures but only ever upgrade them.
	* Digging (a tug of war with the sand): at a 5/5 signal the client shows "[E] Begin Excavation".
	  Dig("Start") opens a dig session and puts the (passive) shovel in the player's hands.
	  Any shovel can dig any treasure. The beach, rarity and depth set a hidden resistance and a
	  hidden recommended shovel tier (GameMath.DigProfile); an under-levelled shovel gains less
	  per click and the sand pulls back harder. Update 17: there is NO grace period - the server
	  integrates the pull continuously (10x a second and at every click), so clicks must outpace it.
	* Permanent failure (Update 17): once the hole has a foothold, letting the bar fall back to
	  empty loses the treasure for good - removed from the player's buried list, the hole caves in
	  and a NEW treasure is buried elsewhere later. Nothing is awarded: the dig's XP, quest and stat
	  progress are held on the hole and only paid out when the treasure comes up. Walking away,
	  dying, teleporting or leaving doesn't stop the pull either (the hole keeps "cooling"), so no
	  reset, rejoin or remote trick can bring a failed treasure back.
	* The hole is a visible dig site (DigEffects > DigSite): a dark pit that widens and a ring of
	  displaced sand that piles up as the excavation progresses. Past ~30% the digger's client is
	  told what's down there so it can show the treasure slowly surfacing.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local GameMath = require(Shared.GameMath)
local GameConfig = require(Shared.Config.GameConfig)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Progression = require(Shared.Config.Progression)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

local TreasureService = {}

type Spawn = {
	Id: number,
	Zone: string,
	Position: Vector3,
	Depth: number,
	TreasureId: string,
	Rarity: string,
	Progress: number,
	Seed: number,
	Hole: Model?,
	Created: number,
	Digger: Player?,
	Owner: Player?,
	Armed: boolean?, -- past the foothold: falling back to empty now loses it
	Swings: number?, -- counted clicks so far (their XP/quest/stats are paid on success only)
	Frozen: boolean?, -- almost dug out but the backpack was full: no pull until dug again
}

-- An abandoned hole that is still sliding back (nobody digging it)
type Cooling = { Spawn: Spawn, State: ZoneState, Profile: any, Idle: number, LastHole: number }

type Session = {
	Spawn: Spawn,
	State: ZoneState,
	Profile: any,
	LastClick: number,
	LastAccepted: number,
	LastSent: number,
	LastHole: number,
	Clicks: number,
	Speed: number,
	LastIdle: number, -- seconds since the last click at the previous tick (decay is integrated)
	Peeked: boolean, -- has the client been told which treasure is surfacing?
}

local PEEK_AT = 0.3 -- progress at which the treasure starts to show in the hole

type ZoneState = { List: { Spawn }, NextFill: number, Initialized: boolean }

local services
local rng = Random.new()
local spawns: { [Player]: { [string]: ZoneState } } = {}
local lastSignalLevel: { [Player]: number } = {}
local sessions: { [Player]: Session } = {}
local cooling: { [Spawn]: Cooling } = {}
local nextSpawnId = 0
local effectsFolder: Folder

local signalRemote: RemoteEvent
local foundRemote: RemoteEvent
local announceRemote: RemoteEvent
local progressRemote: RemoteEvent

local function flatDistance(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function getZoneState(player: Player, zoneId: string): ZoneState
	local byZone = spawns[player]
	if not byZone then
		byZone = {}
		spawns[player] = byZone
	end
	local state = byZone[zoneId]
	if not state then
		state = { List = {}, NextFill = 0, Initialized = false }
		byZone[zoneId] = state
	end
	return state
end

local function pickDepth(maxDepth: number): number
	local total = 0
	for depth = 1, maxDepth do
		total += GameConfig.DepthWeights[depth]
	end
	local roll = rng:NextNumber() * total
	for depth = 1, maxDepth do
		roll -= GameConfig.DepthWeights[depth]
		if roll <= 0 then
			return depth
		end
	end
	return 1
end

---------------------------------------------------------------------------
-- Rolling treasures
---------------------------------------------------------------------------
function TreasureService:RollTreasure(player: Player, zoneId: string, depth: number): (string, string)
	local data = services.DataService:Get(player)
	local luck = services.LuckService:GetTotal(player)

	-- Event-only treasures (e.g. Moonlit Night)
	local event = services.EventService:GetActive()
	if event and event.TreasureChance and rng:NextNumber() < event.TreasureChance then
		local rolledTier = Rarities.Tier(GameMath.RollRarity(zoneId, luck, depth, rng))
		local best = nil
		for _, def in Treasures.GetEventPool(event.Id) do
			local tier = Rarities.Tier(def.Rarity)
			if tier <= rolledTier and (best == nil or tier > Rarities.Tier(best.Rarity)) then
				best = def
			end
		end
		if best then
			return best.Id, best.Rarity
		end
	end

	local rarity = GameMath.RollRarity(zoneId, luck, depth, rng)
	for tier = Rarities.Tier(rarity), 1, -1 do
		local pool = Treasures.GetPool(zoneId, Rarities.FromTier(tier), data.Level)
		if #pool > 0 then
			local def = pool[rng:NextInteger(1, #pool)]
			return def.Id, def.Rarity
		end
	end
	local fallback = Treasures.ByZone[zoneId][1]
	return fallback.Id, fallback.Rarity
end

-- Re-roll un-dug treasures with the player's current Luck, keeping whichever is rarer.
-- Called when a boost starts or an event begins, so the boost is felt immediately.
function TreasureService:UpgradeRolls(player: Player)
	local byZone = spawns[player]
	if not byZone or not services.DataService:Get(player) then
		return
	end
	for zoneId, state in byZone do
		for _, spawn in state.List do
			if spawn.Progress <= 0 and spawn.Digger == nil then
				local treasureId, rarity = self:RollTreasure(player, zoneId, spawn.Depth)
				if Rarities.Tier(rarity) > Rarities.Tier(spawn.Rarity) then
					spawn.TreasureId = treasureId
					spawn.Rarity = rarity
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- Burying treasures
---------------------------------------------------------------------------
function TreasureService:FindSpawnPoint(zoneId: string, existing: { Spawn }): Vector3?
	local parts = services.ZoneService:GetZoneParts(zoneId)
	if not parts then
		return nil
	end
	local area = parts.DigArea
	local size = area.Size
	local inset = 6

	local exclude: { Instance } = { effectsFolder }
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(exclude, other.Character)
		end
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = exclude
	params.IgnoreWater = true
	local materialName = area:GetAttribute("TerrainMaterial")
	local digMaterial = Enum.Material.Sand
	if type(materialName) == "string" then
		local ok, value = pcall(function()
			return (Enum.Material :: any)[materialName]
		end)
		if ok and value then
			digMaterial = value
		end
	end

	for _ = 1, 20 do
		local localX = rng:NextNumber(-size.X / 2 + inset, size.X / 2 - inset)
		local localZ = rng:NextNumber(-size.Z / 2 + inset, size.Z / 2 - inset)
		local top = (area.CFrame * CFrame.new(localX, size.Y / 2, localZ)).Position
		local result = Workspace:Raycast(top + Vector3.new(0, 60, 0), Vector3.new(0, -70, 0), params)
		-- The dig area becomes Terrain at runtime (EnvironmentService) in that beach's own ground
		-- material (golden sand, grey shingle, white powder, black volcanic sand...); the part is the fallback
		local onSand = result ~= nil and (result.Instance == area
			or (result.Instance == Workspace.Terrain and result.Material == digMaterial and result.Position.Y > top.Y - 2))
		if result and onSand then
			local clear = true
			for _, other in existing do
				if flatDistance(other.Position, result.Position) < GameConfig.MinSpawnSpacing then
					clear = false
					break
				end
			end
			if clear then
				return result.Position
			end
		end
	end
	return nil
end

function TreasureService:EnsureSpawns(player: Player, zoneId: string): ZoneState
	local state = getZoneState(player, zoneId)
	local data = services.DataService:Get(player)
	local target = math.floor(GameConfig.SpawnsPerZone * services.EventService:GetSpawnMult())

	-- Untouched treasure moves somewhere new after a while, so a too-tough find never blocks a slot forever
	local now = os.clock()
	for index = #state.List, 1, -1 do
		local spawn = state.List[index]
		if spawn.Progress <= 0 and spawn.Digger == nil and now - spawn.Created > GameConfig.Dig.SpawnLifetime then
			if spawn.Hole then
				spawn.Hole:Destroy()
			end
			table.remove(state.List, index)
		end
	end
	if #state.List >= target or os.clock() < state.NextFill then
		return state
	end
	local stats = GameMath.DetectorStats(data)
	local batch = if state.Initialized then 1 else target - #state.List
	for _ = 1, batch do
		local position = self:FindSpawnPoint(zoneId, state.List)
		if not position then
			break
		end
		local depth = pickDepth(stats.Depth)
		local treasureId, rarity = self:RollTreasure(player, zoneId, depth)
		nextSpawnId += 1
		table.insert(state.List, {
			Id = nextSpawnId,
			Zone = zoneId,
			Position = position,
			Depth = depth,
			TreasureId = treasureId,
			Rarity = rarity,
			Progress = 0,
			Seed = rng:NextNumber() * 1000,
			Hole = nil,
			Created = os.clock(),
			Digger = nil,
			Owner = player,
			Swings = 0,
		})
	end
	state.Initialized = true
	state.NextFill = os.clock() + 0.5
	return state
end

---------------------------------------------------------------------------
-- Detector signal (sent ~5 times a second while the detector is held)
---------------------------------------------------------------------------
function TreasureService:Scan(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local tool = character and character:FindFirstChildOfClass("Tool")
	local holdingDetector = tool ~= nil and tool:GetAttribute("IsDetector") == true
	-- Holding the shovel only tells you whether you're standing on a dig spot (no radar)
	local holdingShovel = tool ~= nil and tool:GetAttribute("IsShovel") == true

	if not root or not (holdingDetector or holdingShovel) then
		if lastSignalLevel[player] ~= -1 then
			lastSignalLevel[player] = -1
			signalRemote:FireClient(player, { Active = false })
		end
		return
	end

	local zoneId = services.ZoneService:GetPlayerZone(player)
	if not zoneId or not data.Zones[zoneId] then
		lastSignalLevel[player] = 0
		signalRemote:FireClient(player, { Active = true, Level = 0 })
		return
	end

	local state = self:EnsureSpawns(player, zoneId)
	local stats = GameMath.DetectorStats(data)
	local rootPos = (root :: BasePart).Position

	local best: Spawn? = nil
	local bestDist = math.huge
	for _, spawn in state.List do
		if spawn.Depth <= stats.Depth then
			local distance = flatDistance(rootPos, spawn.Position)
			if distance <= stats.Range and distance < bestDist then
				best, bestDist = spawn, distance
			end
		end
	end

	if not best then
		lastSignalLevel[player] = 0
		signalRemote:FireClient(player, { Active = true, Level = 0, Zone = zoneId, Range = stats.Range })
		return
	end
	local target = best :: Spawn

	if holdingShovel then
		local onSpot = bestDist <= GameConfig.DigRadius
		lastSignalLevel[player] = if onSpot then 5 else 0
		signalRemote:FireClient(player, {
			Active = true,
			ShovelOnly = true,
			Level = if onSpot then 5 else 0,
			DigSpot = if onSpot then target.Position else nil,
			Digging = sessions[player] ~= nil,
			Zone = zoneId,
		})
		return
	end

	local level
	if bestDist <= GameConfig.DigRadius then
		level = 5
	else
		local fraction = bestDist / stats.Range
		level = if fraction < 0.25 then 4 elseif fraction < 0.5 then 3 elseif fraction < 0.75 then 2 else 1
	end

	-- Cheaper detectors give wobblier readings (smooth noise so it doesn't jitter)
	local err = 1 - stats.Accuracy
	local t = os.clock()
	local shownDistance = bestDist
	local angleNoise = 0
	if level < 5 then
		shownDistance = math.clamp(bestDist * (1 + err * 0.8 * math.clamp(math.noise(target.Seed, t * 0.7) * 2, -1, 1)), GameConfig.DigRadius, stats.Range)
		angleNoise = err * 1.6 * math.clamp(math.noise(target.Seed + 37.3, t * 0.5) * 2, -1, 1)
	end
	local offset = target.Position - rootPos
	local angle = math.atan2(offset.X, offset.Z) + angleNoise

	-- Within digging range: the exact spot is no secret any more (you're standing on it)
	local digSpot = if level == 5 then target.Position else nil

	lastSignalLevel[player] = level
	signalRemote:FireClient(player, {
		Active = true,
		Level = level,
		DigSpot = digSpot,
		Digging = sessions[player] ~= nil,
		Studs = shownDistance,
		DirX = math.sin(angle),
		DirZ = math.cos(angle),
		Depth = target.Depth,
		Hint = if stats.RarityHint and level >= 3 then target.Rarity else nil,
		Progress = target.Progress,
		Zone = zoneId,
		Range = stats.Range,
	})
end

---------------------------------------------------------------------------
-- Digging
---------------------------------------------------------------------------
local BLACK = Color3.new(0, 0, 0)
local DEFAULT_GROUND = Color3.fromRGB(226, 200, 146)
local MOUND_COUNT = 7

local function sitePart(name: string, parent: Instance, color: Color3, ellipsoid: boolean): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Material = Enum.Material.Sand
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if ellipsoid then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	else
		part.Shape = Enum.PartType.Cylinder
	end
	part.Parent = parent
	return part
end

-- The dig site grows with progress: the pit widens and darkens towards the middle (it reads as
-- depth), and a ring of displaced sand rises around it, with the biggest heap where the
-- shovel tosses the sand.
function TreasureService:UpdateHole(spawn: Spawn)
	local site = spawn.Hole
	if not site then
		-- tinted to the beach's own sand (golden, grey shingle, white powder, black volcanic...)
		local zone = Zones.Info[spawn.Zone]
		local ground = (zone and zone.Ground) or DEFAULT_GROUND
		local model = Instance.new("Model")
		model.Name = "DigSite"
		model:SetAttribute("Ground", ground)
		local pit = sitePart("Pit", model, ground:Lerp(BLACK, 0.3), false)
		sitePart("PitDeep", model, ground:Lerp(BLACK, 0.55), false)
		model.PrimaryPart = pit
		for i = 1, MOUND_COUNT do
			sitePart("Mound" .. i, model, ground:Lerp(Color3.new(1, 1, 1), 0.04), true)
		end
		sitePart("Heap", model, ground, true)
		model.Parent = effectsFolder
		spawn.Hole = model
		site = model
	end
	local model = site :: Model
	local p = math.clamp(spawn.Progress, 0, 1)
	model:SetAttribute("Progress", p)
	local base = spawn.Position
	local flat = CFrame.Angles(0, 0, math.rad(90))
	local pitDiameter = 1.8 + 3.0 * p
	local pit = model:FindFirstChild("Pit") :: BasePart
	pit.Size = Vector3.new(0.12, pitDiameter, pitDiameter)
	pit.CFrame = CFrame.new(base + Vector3.new(0, 0.05, 0)) * flat
	local deep = model:FindFirstChild("PitDeep") :: BasePart
	local deepDiameter = 0.6 + 2.4 * p
	deep.Size = Vector3.new(0.12, deepDiameter, deepDiameter)
	deep.CFrame = CFrame.new(base + Vector3.new(0, 0.08, 0)) * flat
	local ground = model:GetAttribute("Ground")
	if typeof(ground) == "Color3" then
		deep.Color = ground:Lerp(BLACK, 0.35 + 0.3 * p) -- darker as it gets deeper
	end
	-- displaced sand ring (seeded so it doesn't jump around between updates)
	local seed = Random.new(spawn.Seed)
	local rim = pitDiameter / 2 + 0.35
	for i = 1, MOUND_COUNT do
		local mound = model:FindFirstChild("Mound" .. i) :: BasePart
		local angle = (i / MOUND_COUNT) * math.pi * 2 + seed:NextNumber(-0.25, 0.25)
		local bulk = 0.6 + seed:NextNumber() * 0.5
		local height = (0.15 + 0.75 * p) * bulk
		mound.Size = Vector3.new((1.1 + 1.5 * p) * bulk, height, (0.8 + 1.0 * p) * bulk)
		mound.CFrame = CFrame.new(base + Vector3.new(math.cos(angle) * rim, height * 0.18, math.sin(angle) * rim))
			* CFrame.Angles(0, -angle + math.pi / 2, 0)
	end
	local heap = model:FindFirstChild("Heap") :: BasePart
	local heapAngle = seed:NextNumber() * math.pi * 2
	local heapHeight = 0.2 + 1.3 * p
	heap.Size = Vector3.new(1.2 + 2.2 * p, heapHeight, 1.1 + 1.8 * p)
	heap.CFrame = CFrame.new(base + Vector3.new(math.cos(heapAngle) * (rim + 0.9), heapHeight * 0.2, math.sin(heapAngle) * (rim + 0.9)))
end

function TreasureService:PlayBeam(position: Vector3, color: Color3)
	local beam = Instance.new("Part")
	beam.Name = "DiscoveryBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.Material = Enum.Material.Neon
	beam.Color = color
	beam.Transparency = 0.35
	beam.Size = Vector3.new(60, 1.6, 1.6)
	beam.CFrame = CFrame.new(position + Vector3.new(0, 30, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = effectsFolder
	local tween = TweenService:Create(beam, TweenInfo.new(3.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		Transparency = 1,
		Size = Vector3.new(60, 0.2, 0.2),
	})
	tween:Play()
	tween.Completed:Once(function()
		beam:Destroy()
	end)
end

function TreasureService:CompleteFind(player: Player, state: ZoneState, spawn: Spawn)
	local data = services.DataService:Get(player)
	local index = table.find(state.List, spawn)
	if index then
		table.remove(state.List, index)
	end
	state.NextFill = os.clock() + GameConfig.RespawnDelay
	local hole = spawn.Hole
	if hole then
		task.delay(12, function()
			hole:Destroy()
		end)
	end

	local def = Treasures.ById[spawn.TreasureId]
	local zone = Zones.Info[spawn.Zone]
	local rarityInfo = Rarities.Info[def.Rarity]
	local luck = services.LuckService:GetTotal(player)

	local quality = GameMath.RollQuality(rng, luck)
	local baseValue = def.Value * (if def.ScalesWithZone then zone.ValueMult else 1)
	local value = math.max(1, math.floor(baseValue * quality + 0.5))
	local item = services.InventoryService:CreateItem(player, def.Id, quality, value, spawn.Zone)
	services.InventoryService:AddItem(player, item)

	local isNew = (data.Index[def.Id] or 0) == 0
	data.Index[def.Id] = (data.Index[def.Id] or 0) + 1
	local stats = data.Stats
	stats.Found += 1
	stats.Rarity[def.Rarity] = (stats.Rarity[def.Rarity] or 0) + 1
	stats.ZoneFinds[spawn.Zone] = (stats.ZoneFinds[spawn.Zone] or 0) + 1
	stats.BestValue = math.max(stats.BestValue, value)

	local xp = math.floor(rarityInfo.XP * zone.XPMult + (if isNew then Progression.NewDiscoveryXP * zone.XPMult else 0))
	-- the dig's own work is only paid out now that the treasure is up (a lost treasure pays nothing)
	local swings = spawn.Swings or 0
	spawn.Swings = 0
	xp += math.floor(swings / GameConfig.Dig.XPEveryClicks) * Progression.StrikeXP
	stats.Digs += swings
	if swings > 0 then
		services.QuestService:Progress(player, "Dig", swings)
	end

	-- Shovel bonus: extra coins sifted from the sand
	local bonusCash = 0
	local detectorStats = GameMath.DetectorStats(data)
	if detectorStats.BonusChance > 0 and rng:NextNumber() < detectorStats.BonusChance then
		bonusCash = math.max(1, math.floor(value * GameConfig.SifterBonusShare))
		services.InventoryService:AddCash(player, bonusCash, true)
	end

	services.QuestService:Progress(player, "Find", 1)
	services.QuestService:Progress(player, "FindTier", 1, { Tier = rarityInfo.Tier })
	services.QuestService:Progress(player, "FindInZone", 1, { Zone = spawn.Zone })
	if isNew then
		services.QuestService:Progress(player, "Discover", 1)
	end

	foundRemote:FireClient(player, {
		Item = item,
		Position = spawn.Position,
		IsNew = isNew,
		XP = xp,
		BonusCash = bonusCash,
		Luck = luck,
	})
	services.LevelService:AddXP(player, xp)

	if rarityInfo.Tier >= GameConfig.AnnounceMinTier then
		announceRemote:FireAllClients({
			Player = player.DisplayName,
			UserId = player.UserId,
			TreasureId = def.Id,
			Zone = spawn.Zone,
		})
	end
	if rarityInfo.Tier >= 4 then
		self:PlayBeam(spawn.Position, rarityInfo.Color)
	end

	if isNew then
		for _, zoneId in Zones.Order do
			if Zones.Info[zoneId].RequiresDiscovery == def.Id then
				services.StateService:Notify(player, "🗺 The " .. def.Name .. " reveals the way to " .. Zones.Info[zoneId].Name .. "! Unlock it from the Travel menu.", "Rare")
			end
		end
	end

	services.AchievementService:Check(player)
	services.DataService:MarkDirty(player)
end

local function sendProgress(player: Player, payload)
	progressRemote:FireClient(player, payload)
end

function TreasureService:FindDiggable(player: Player, data, rootPos: Vector3): (Spawn?, ZoneState?)
	local zoneId = services.ZoneService:GetPlayerZone(player)
	if not zoneId or not data.Zones[zoneId] then
		return nil, nil
	end
	local state = getZoneState(player, zoneId)
	local stats = GameMath.DetectorStats(data)
	local best: Spawn? = nil
	local bestDist = math.huge
	for _, spawn in state.List do
		if spawn.Depth <= stats.Depth then
			local distance = flatDistance(rootPos, spawn.Position)
			if distance <= GameConfig.DigRadius + 0.75 and math.abs(rootPos.Y - spawn.Position.Y) < 12 and distance < bestDist then
				best, bestDist = spawn, distance
			end
		end
	end
	return best, state
end

function TreasureService:StartDig(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Still loading..." }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return { Ok = false, Error = "You can't dig right now" }
	end
	local existing = sessions[player]
	if existing then
		return self:SessionInfo(existing)
	end
	if services.InventoryService:IsFull(data) then
		return { Ok = false, Error = "🎒 Backpack full (10/10)! Return to the Pier to sell treasures or display them in your shop.", Full = true }
	end

	local spawn, state = self:FindDiggable(player, data, (root :: BasePart).Position)
	if not spawn or not state then
		return { Ok = false, Error = "Nothing here - follow the signal until it reads 5/5." }
	end
	local target = spawn :: Spawn
	if target.Digger and target.Digger ~= player then
		return { Ok = false, Error = "Someone is already digging here." }
	end

	-- every shovel can dig every treasure; the beach, rarity and depth only change how hard
	-- it fights back (all hidden)
	local shovel = GameMath.GetShovel(data)
	local profile = GameMath.DigProfile(target.Zone, target.Rarity, target.Depth, shovel, services.EventService:GetDigSpeedMult())

	-- coming back to a hole that's still sliding back: the pull carries on from where it is
	local now = os.clock()
	local idle = 0
	local cool = cooling[target]
	if cool then
		cooling[target] = nil
		idle = cool.Idle
	end
	target.Frozen = nil
	target.Digger = player
	sessions[player] = {
		Spawn = target,
		State = state :: ZoneState,
		Profile = profile,
		LastClick = now - idle,
		LastAccepted = 0,
		LastSent = 0,
		LastHole = 0,
		Clicks = 0,
		Speed = shovel.Speed,
		LastIdle = idle,
		Peeked = false,
	}
	self:UpdateHole(target)
	self:EquipShovel(player)
	-- other players' clients animate this character digging (DigAnimator)
	character:SetAttribute("DigHole", target.Position)
	character:SetAttribute("DigSpeed", shovel.Speed)
	character:SetAttribute("DigSwings", 0)
	return self:SessionInfo(sessions[player])
end

-- What the digger's client needs to animate the bar between server messages: the click gain and
-- the pull. No resistance, no recommended tier, no words for how hard it is - the bar says it all.
function TreasureService:SessionInfo(session: Session)
	local spawn = session.Spawn
	local profile = session.Profile
	local player = spawn.Digger
	local data = player and services.DataService:Get(player)
	local stats = data and GameMath.DetectorStats(data)
	if spawn.Progress >= PEEK_AT then
		session.Peeked = true
	end
	return {
		Ok = true,
		Progress = spawn.Progress,
		Position = spawn.Position,
		Gain = profile.Gain,
		DecayRate = profile.DecayRate,
		IdleBoost = profile.IdleBoost,
		IdleRamp = profile.IdleRamp,
		Idle = os.clock() - session.LastClick,
		AtStake = spawn.Armed == true,
		MinInterval = profile.MinInterval,
		Speed = session.Speed,
		Hint = if stats and stats.RarityHint then spawn.Rarity else nil,
		Peek = if session.Peeked then spawn.TreasureId else nil,
	}
end

-- The shovel is passive gear: the server puts it in your hands for the dig (and the client
-- hands the detector back afterwards). Players never have to pick it themselves.
function TreasureService:EquipShovel(player: Player): boolean
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid then
		return false
	end
	local held = character:FindFirstChildOfClass("Tool")
	if held and held:GetAttribute("IsShovel") then
		return true
	end
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, tool in backpack:GetChildren() do
			if tool:IsA("Tool") and tool:GetAttribute("IsShovel") then
				humanoid:EquipTool(tool)
				return true
			end
		end
	end
	return false
end

function TreasureService:IsDigging(player: Player): boolean
	return sessions[player] ~= nil
end

local function clearDigAttributes(player: Player)
	local character = player.Character
	if character then
		character:SetAttribute("DigHole", nil)
		character:SetAttribute("DigSwings", nil)
		character:SetAttribute("DigSpeed", nil)
	end
end

-- The hole caves in: the pit closes up and the displaced sand slumps back in and sinks.
-- (Everyone nearby sees it - the parts are server-side.)
function TreasureService:CollapseHole(spawn: Spawn)
	local site = spawn.Hole
	spawn.Hole = nil
	if not site then
		return
	end
	local model = site :: Model
	model.Name = "CollapsingSite"
	local base = spawn.Position
	local info = TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, part in model:GetChildren() do
		if part:IsA("BasePart") then
			local offset = part.Position - base
			local target = part.CFrame - Vector3.new(offset.X * 0.7, 0, offset.Z * 0.7) - Vector3.new(0, part.Size.Y * 0.6 + 0.1, 0)
			TweenService:Create(part, info, {
				CFrame = target,
				Size = Vector3.new(part.Size.X * 0.6, part.Size.Y * 0.35, part.Size.Z * 0.6),
			}):Play()
			TweenService:Create(part, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9), {
				Transparency = 1,
			}):Play()
		end
	end
	task.delay(2.8, function()
		model:Destroy()
	end)
end

-- Permanent failure: the bar fell back to empty after the foothold. The treasure is gone for
-- good - out of the player's buried list (the detector can never find it again), nothing paid,
-- and a brand-new treasure is buried somewhere else after the usual delay.
function TreasureService:LoseTreasure(state: ZoneState, spawn: Spawn, profile)
	local player = spawn.Owner
	cooling[spawn] = nil
	local index = table.find(state.List, spawn)
	if index then
		table.remove(state.List, index)
	end
	state.NextFill = os.clock() + GameConfig.RespawnDelay
	spawn.Progress = 0
	spawn.Digger = nil
	self:CollapseHole(spawn)
	if player and sessions[player] and sessions[player].Spawn == spawn then
		sessions[player] = nil
		clearDigAttributes(player)
	end
	if player and player.Parent then
		local data = services.DataService:Get(player)
		if data then
			data.Stats.Lost = (data.Stats.Lost or 0) + 1
			services.DataService:MarkDirty(player)
		end
		sendProgress(player, {
			Ended = true,
			Lost = true,
			Progress = 0,
			Position = spawn.Position,
			-- a gentle nudge (no numbers): only when the shovel really was too weak for it
			Tip = if profile and profile.Gap and profile.Gap >= 2 then "Stronger shovels hold the sand back better." else nil,
		})
	end
end

-- Ends a dig without finding anything. The hole does NOT keep its progress safe: the sand keeps
-- pulling back while nobody digs, and once it reaches the bottom a started hole is lost.
function TreasureService:StopDig(player: Player, reason: string?)
	local session = sessions[player]
	if not session then
		return
	end
	sessions[player] = nil
	clearDigAttributes(player)
	local spawn = session.Spawn
	spawn.Digger = nil
	if spawn.Progress > 0 and table.find(session.State.List, spawn) and not spawn.Frozen then
		cooling[spawn] = {
			Spawn = spawn,
			State = session.State,
			Profile = session.Profile,
			Idle = os.clock() - session.LastClick,
			LastHole = 0,
		}
	end
	self:UpdateHole(spawn)
	sendProgress(player, { Ended = true, Progress = spawn.Progress, Reason = reason, AtStake = spawn.Armed == true and not spawn.Frozen })
end

-- Applies the pull for the time since the last settle. Returns true if the treasure was lost.
local function settle(session: Session, now: number): boolean
	local spawn = session.Spawn
	local idle = now - session.LastClick
	local pulled = GameMath.DigDecay(session.Profile, session.LastIdle, idle)
	session.LastIdle = idle
	if pulled > 0 and spawn.Progress > 0 then
		spawn.Progress = math.max(0, spawn.Progress - pulled)
		if spawn.Progress <= 0 and spawn.Armed then
			return true
		end
	end
	return false
end

function TreasureService:Click(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	local now = os.clock()
	-- Faster than the shovel allows: ignored (stops auto-clickers and remote spam)
	if now - session.LastAccepted < session.Profile.MinInterval * 0.8 then
		return
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return
	end
	local spawn = session.Spawn
	-- the treasure must still be buried (and still yours to dig) - never handed out twice
	if spawn.Digger ~= player or not table.find(session.State.List, spawn) then
		sessions[player] = nil
		clearDigAttributes(player)
		sendProgress(player, { Ended = true, Progress = 0, Reason = "This treasure is gone." })
		return
	end
	if flatDistance((root :: BasePart).Position, spawn.Position) > GameConfig.Dig.MaxDistance then
		self:StopDig(player, "You moved too far from the hole.")
		return
	end
	-- the shovel is passive: if it isn't in your hands (yet), the server puts it there
	self:EquipShovel(player)
	local data = services.DataService:Get(player)
	if not data then
		return
	end

	-- settle the pull since the last tick (it never stops), then push forward
	if settle(session, now) then
		self:LoseTreasure(session.State, spawn, session.Profile)
		return
	end
	session.LastAccepted = now
	session.LastClick = now
	session.LastIdle = 0
	session.Clicks += 1
	spawn.Swings = (spawn.Swings or 0) + 1
	if character then
		character:SetAttribute("DigSwings", session.Clicks)
	end
	spawn.Progress = math.min(1, spawn.Progress + session.Profile.Gain)
	local newlyArmed = false
	if not spawn.Armed and spawn.Progress >= session.Profile.Foothold then
		spawn.Armed = true
		newlyArmed = true
	end
	self:UpdateHole(spawn)

	if spawn.Progress >= 0.999 and services.InventoryService:IsFull(data) then
		-- never lose a treasure to a full backpack: it stays (almost dug out) and the pull pauses
		spawn.Progress = 0.95
		spawn.Frozen = true
		self:StopDig(player, "🎒 Backpack full! Head back to the Pier to make room - this treasure stays buried here.")
		return
	end
	if spawn.Progress >= 0.999 then
		sessions[player] = nil
		spawn.Digger = nil
		clearDigAttributes(player)
		sendProgress(player, { Progress = 1, Done = true })
		self:CompleteFind(player, session.State, spawn)
	else
		session.LastSent = now
		local peek = nil
		if not session.Peeked and spawn.Progress >= PEEK_AT then
			session.Peeked = true
			peek = spawn.TreasureId
		end
		sendProgress(player, { Progress = spawn.Progress, Peek = peek, AtStake = if newlyArmed then true else nil })
	end
end

-- The pull, distance and idle checks for every active dig, and the pull on abandoned holes
-- (10 times a second). Decay is continuous: no grace, no timer-based lump subtraction.
function TreasureService:TickDigs(dt: number)
	local now = os.clock()
	for player, session in sessions do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local spawn = session.Spawn
		if not player.Parent or not root or not humanoid or humanoid.Health <= 0 then
			self:StopDig(player, "Digging stopped.")
		elseif flatDistance((root :: BasePart).Position, spawn.Position) > GameConfig.Dig.MaxDistance then
			self:StopDig(player, "You moved too far from the hole.")
		elseif settle(session, now) then
			self:LoseTreasure(session.State, spawn, session.Profile)
		elseif now - session.LastClick > GameConfig.Dig.IdleCancel then
			self:StopDig(player, "You stopped digging.")
		elseif spawn.Progress > 0 then
			if now - session.LastHole > 0.3 then
				session.LastHole = now
				self:UpdateHole(spawn)
			end
			if now - session.LastSent > 0.15 then
				session.LastSent = now
				sendProgress(player, { Progress = spawn.Progress, Decaying = true })
			end
		end
	end

	-- abandoned holes keep sliding back (at the full "not clicking" strength)
	for spawn, cool in cooling do
		if spawn.Digger or not table.find(cool.State.List, spawn) then
			cooling[spawn] = nil
			continue
		end
		local before = cool.Idle
		cool.Idle += dt
		spawn.Progress = math.max(0, spawn.Progress - GameMath.DigDecay(cool.Profile, before, cool.Idle))
		if spawn.Progress <= 0 then
			if spawn.Armed then
				self:LoseTreasure(cool.State, spawn, cool.Profile)
			else
				-- never properly started: the sand simply fills the scrape back in
				cooling[spawn] = nil
				if spawn.Hole then
					spawn.Hole:Destroy()
					spawn.Hole = nil
				end
			end
		elseif now - cool.LastHole > 0.4 then
			cool.LastHole = now
			self:UpdateHole(spawn)
		end
	end
end

-- Studio testing: turn every buried treasure in the player's current zone into a given rarity
function TreasureService:DebugReroll(player: Player, rarity: string)
	local zoneId = services.ZoneService:GetPlayerZone(player)
	local data = services.DataService:Get(player)
	if not zoneId or not data or not Rarities.Info[rarity] then
		return false
	end
	local pool = Treasures.GetPool(zoneId, rarity, 100)
	if #pool == 0 then
		return false
	end
	for _, spawn in getZoneState(player, zoneId).List do
		local def = pool[rng:NextInteger(1, #pool)]
		spawn.TreasureId = def.Id
		spawn.Rarity = def.Rarity
	end
	return true
end

-- Studio testing: position of the closest treasure the player's detector can find
function TreasureService:DebugNearest(player: Player): Vector3?
	local zoneId = services.ZoneService:GetPlayerZone(player)
	local data = services.DataService:Get(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not zoneId or not data or not root then
		return nil
	end
	local depth = GameMath.DetectorStats(data).Depth
	local best, bestDist = nil, math.huge
	for _, spawn in self:EnsureSpawns(player, zoneId).List do
		local distance = flatDistance((root :: BasePart).Position, spawn.Position)
		if spawn.Depth <= depth and distance < bestDist then
			best, bestDist = spawn.Position, distance
		end
	end
	return best
end

---------------------------------------------------------------------------
function TreasureService:Init(allServices)
	services = allServices
	signalRemote = Net.Event("DetectorSignal")
	foundRemote = Net.Event("TreasureFound")
	announceRemote = Net.Event("Announcement")
	progressRemote = Net.Event("DigProgress")

	effectsFolder = Instance.new("Folder")
	effectsFolder.Name = "DigEffects"
	effectsFolder.Parent = Workspace
end

function TreasureService:Start()
	-- Dig("Start") opens a dig session, Dig("Stop") abandons it
	RemoteGuard.Handle("Dig", 0.25, function(player, action)
		if action == "Stop" then
			self:StopDig(player, "Stopped digging.")
			return { Ok = true }
		end
		return self:StartDig(player)
	end)

	-- Each shovel click (fire-and-forget; the server ignores clicks faster than the shovel's speed)
	Net.Event("DigClick").OnServerEvent:Connect(function(player)
		self:Click(player)
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(0.1)
			local now = os.clock()
			local ok, err = pcall(self.TickDigs, self, now - last)
			last = now
			if not ok then
				warn("[TreasureService] dig tick error: " .. tostring(err))
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		local byZone = spawns[player]
		if byZone then
			for _, state in byZone do
				for _, spawn in state.List do
					cooling[spawn] = nil -- leaving never saves a started hole: it goes with you
					if spawn.Hole then
						spawn.Hole:Destroy()
					end
				end
			end
		end
		spawns[player] = nil
		lastSignalLevel[player] = nil
		sessions[player] = nil
	end)

	while true do
		task.wait(GameConfig.ScanInterval)
		for _, player in services.DataService:GetLoadedPlayers() do
			local ok, err = pcall(self.Scan, self, player)
			if not ok then
				warn("[TreasureService] scan error: " .. tostring(err))
			end
		end
	end
end

return TreasureService
