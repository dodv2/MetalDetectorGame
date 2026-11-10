--[[
	WorldController
	Client-side world touches:
	  * beach barriers: each locked beach has an UNLOCK STATION beside its barrier. Its prompt opens
	    an unlock card (required level + cost, what you're missing). Buying is checked by the
	    server; once unlocked, the barrier disappears for you.
	  * proximity prompts in town open menus (attribute OpenUI on the prompt)
	  * your own shop: a "Manage Shop" prompt on the desk inside the door, plus "Manage display"
	    on every treasure you've put out. Other shops' displays get "Inspect".
	  * displayed treasures slowly spin; Moonlit Night turns the sky to night
	  * IsAtBase / IsAtOwnShop: the same location rules the server uses (for button hints)
]]

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Zones = require(Shared.Config.Zones)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Events = require(Shared.Config.Events)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local World = {}

local player = Players.LocalPlayer
local controllers
local map: Instance
local gateLabels: { [string]: { TextLabel } } = {}
local slotPrompts: { ProximityPrompt } = {}
local promptedKey = ""
local deskPrompt: ProximityPrompt? = nil
local stationPrompts: { [string]: ProximityPrompt } = {}
local spinModels: { [Model]: boolean } = {}

---------------------------------------------------------------------------
-- Gates
---------------------------------------------------------------------------
local function setupGates()
	local zonesFolder = map:WaitForChild("Zones")
	for _, zoneId in Zones.Order do
		local folder = zonesFolder:FindFirstChild(zoneId)
		local gate = folder and folder:FindFirstChild("Gate") :: BasePart?
		if gate then
			gateLabels[zoneId] = {}
			for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
				local gui = Instance.new("SurfaceGui")
				gui.Face = face
				gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
				gui.PixelsPerStud = 12
				gui.LightInfluence = 0
				gui.Parent = gate
				local label = Instance.new("TextLabel")
				label.BackgroundTransparency = 1
				label.Size = UDim2.fromScale(1, 0.4)
				label.Position = UDim2.fromScale(0, 0.18)
				label.Font = Enum.Font.FredokaOne
				label.TextScaled = true
				label.TextColor3 = Color3.new(1, 1, 1)
				label.TextStrokeTransparency = 0.3
				label.Parent = gui
				table.insert(gateLabels[zoneId], label)
			end
		end
	end
end

local function refreshGates(data)
	local zonesFolder = map:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end
	for _, zoneId in Zones.Order do
		local folder = zonesFolder:FindFirstChild(zoneId)
		local gate = folder and folder:FindFirstChild("Gate") :: BasePart?
		if gate then
			local zone = Zones.Info[zoneId]
			local unlocked = data.Zones[zoneId] == true
			gate.CanCollide = not unlocked
			gate.Transparency = if unlocked then 1 else 0.35 -- the barrier is gone for you once bought
			gate.Color = Color3.fromRGB(220, 80, 70)
			for _, gui in gate:GetChildren() do
				if gui:IsA("SurfaceGui") then
					gui.Enabled = not unlocked
				end
			end
			local station = stationPrompts[zoneId]
			if station then
				station.Enabled = not unlocked
				station.ObjectText = string.format("Level %d  ·  %s", zone.Level, Format.Cash(zone.Price))
			end
			for _, extra in folder:GetChildren() do
				if extra.Name == "GateSea" and extra:IsA("BasePart") then
					extra.CanCollide = not unlocked
				end
			end
			local text
			if unlocked then
				text = "✅ " .. zone.Name
			else
				local needs = { "Level " .. zone.Level }
				if zone.Price > 0 then
					table.insert(needs, Format.Cash(zone.Price))
				end
				text = "🔒 " .. zone.Name .. "\n" .. table.concat(needs, " · ") .. "\nUnlock at the station beside this barrier"
			end
			for _, label in gateLabels[zoneId] or {} do
				label.Text = text
			end
		end
	end
end

-- Unlock stations: one prompt per locked beach, on the stand beside its barrier
local function setupStations()
	local zonesFolder = map:WaitForChild("Zones")
	for _, zoneId in Zones.Order do
		local folder = zonesFolder:FindFirstChild(zoneId)
		local station = folder and folder:FindFirstChild("UnlockStation")
		local anchor = station and station:FindFirstChild("PromptAnchor") :: BasePart?
		if anchor then
			local zone = Zones.Info[zoneId]
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Unlock " .. zone.Name
			prompt.ObjectText = string.format("Level %d  ·  %s", zone.Level, Format.Cash(zone.Price))
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 12
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("PromptKind", "Unlock")
			prompt:SetAttribute("UnlockZone", zoneId)
			prompt.Parent = anchor
			stationPrompts[zoneId] = prompt
		end
	end
end

-- The unlock card: what the beach needs, what you have, and the buy button (server re-checks)
function World:ShowUnlockCard(zoneId: string)
	local zone = Zones.Info[zoneId]
	local data = controllers.State.Data
	if not zone or not data then
		return
	end
	if data.Zones[zoneId] then
		controllers.Notify:Toast("✅ " .. zone.Name .. " is already unlocked - walk on through!", "Info", 3)
		return
	end
	local levelOk = data.Level >= zone.Level
	local cashOk = data.Cash >= zone.Price
	local good, bad = "#5fd37a", "#ff7a6b"
	local lines = {
		string.format("<b>Required Level:</b> %d   <font color='%s'>%s</font>", zone.Level, if levelOk then good else bad,
			if levelOk then "✅" else string.format("❌ you need %d more level%s", zone.Level - data.Level, if zone.Level - data.Level == 1 then "" else "s")),
		string.format("<b>Unlock Cost:</b> %s   <font color='%s'>%s</font>", Format.Cash(zone.Price), if cashOk then good else bad,
			if cashOk then "✅" else "❌ you need " .. Format.Cash(zone.Price - data.Cash) .. " more"),
		"",
		"<font size='13'>" .. zone.Description .. "</font>",
	}
	local options = {}
	if levelOk and cashOk then
		table.insert(options, {
			Text = "🔓 Unlock for " .. Format.Cash(zone.Price),
			Color = Theme.Colors.Gold,
			Callback = function()
				local result = controllers.State:Call("UnlockZone", zoneId)
				if result.Ok then
					controllers.Sound:Chime(4)
					controllers.Notify:Celebrate("🔓", "BEACH UNLOCKED!", zone.Name .. " is open - walk through the barrier!", Theme.Colors.Gold, 3)
				end
			end,
		})
	end
	UIKit.Confirm("🔓 Unlock " .. zone.Name, table.concat(lines, "\n"), options)
end

---------------------------------------------------------------------------
-- Shop prompts
---------------------------------------------------------------------------
local function clearSlotPrompts()
	for _, prompt in slotPrompts do
		prompt:Destroy()
	end
	slotPrompts = {}
end

-- Your shop: "Manage Shop" on the desk + "Manage display" on each treasure you've put out
-- (empty shelves are invisible, so they get no prompt)
local function refreshSlotPrompts(data)
	local plotIndex = data.Shop.Plot
	local keys = {}
	for key in data.Shop.Displays do
		table.insert(keys, key)
	end
	table.sort(keys)
	local signature = tostring(plotIndex) .. "|" .. data.Shop.Slots .. "|" .. table.concat(keys, ",")
	if signature == promptedKey then
		return
	end
	promptedKey = signature
	clearSlotPrompts()
	if not plotIndex then
		return
	end
	local plot = map:WaitForChild("ShopPlots"):FindFirstChild("Plot" .. plotIndex)
	local desk = plot and plot:FindFirstChild("Desk")
	local deskAnchor = desk and desk:FindFirstChild("PromptAnchor") :: BasePart?
	if deskAnchor and (not deskPrompt or deskPrompt.Parent ~= deskAnchor) then
		if deskPrompt then
			deskPrompt:Destroy()
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Manage Shop"
		prompt.ObjectText = "Displays · upgrades · themes"
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Style = Enum.ProximityPromptStyle.Custom
		prompt:SetAttribute("PromptKind", "Shop")
		prompt:SetAttribute("ShopDesk", true)
		prompt.Parent = deskAnchor
		deskPrompt = prompt
	end
	local slots = plot and plot:FindFirstChild("Slots")
	if not slots then
		return
	end
	for _, slot in slots:GetChildren() do
		local index = slot:GetAttribute("SlotIndex")
		if index and index <= data.Shop.Slots and slot:IsA("BasePart") and data.Shop.Displays[tostring(index)] ~= nil then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Manage display"
			prompt.ObjectText = "Slot " .. index .. " · " .. tostring(slot:GetAttribute("SlotType"))
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 7
			prompt.RequiresLineOfSight = false
			prompt.Style = Enum.ProximityPromptStyle.Custom
			prompt:SetAttribute("PromptKind", "Shop")
			prompt:SetAttribute("ShopSlot", index)
			prompt.Parent = slot
			table.insert(slotPrompts, prompt)
		end
	end
end

local function watchDisplays()
	local plots = map:WaitForChild("ShopPlots")
	local function onDisplay(model: Instance, plot: Instance)
		if not model:IsA("Model") then
			return
		end
		spinModels[model] = true
		model.Destroying:Connect(function()
			spinModels[model] = nil
		end)
		local root = model.PrimaryPart or model:FindFirstChild("Root")
		if root and plot:GetAttribute("OwnerUserId") ~= player.UserId then
			local def = Treasures.ById[model:GetAttribute("TreasureId") or ""]
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Inspect"
			prompt.ObjectText = if def then def.Name else "Treasure"
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 9
			prompt.RequiresLineOfSight = false
			prompt:SetAttribute("Inspect", true)
			prompt.Parent = root
		end
	end
	for _, plot in plots:GetChildren() do
		local displays = plot:WaitForChild("Displays", 10)
		if displays then
			for _, model in displays:GetChildren() do
				onDisplay(model, plot)
			end
			displays.ChildAdded:Connect(function(model)
				task.wait() -- let attributes replicate
				onDisplay(model, plot)
			end)
		end
	end
end

local function inspect(prompt: ProximityPrompt)
	local model = prompt.Parent and prompt.Parent.Parent
	if not model then
		return
	end
	local def = Treasures.ById[model:GetAttribute("TreasureId") or ""]
	if not def then
		return
	end
	local owner = model.Parent and model.Parent.Parent
	local ownerName = if owner then owner:GetAttribute("OwnerName") else nil
	controllers.Notify:Toast(string.format("%s  •  %s  •  💰 %s  •  🍀 %s%s\n%s",
		def.Name, Rarities.Label(def.Rarity), Format.Cash(model:GetAttribute("Value") or def.Value),
		Format.Luck(model:GetAttribute("Luck") or 0), if ownerName and ownerName ~= "" then "  •  owned by " .. ownerName else "", def.Lore), "Info", 6)
end

---------------------------------------------------------------------------
-- Other players' digging: their hole's "Progress" attribute rises with every swing,
-- so everyone nearby sees the sand fly
---------------------------------------------------------------------------
local function watchHoles()
	local effects = Workspace:WaitForChild("DigEffects", 30)
	if not effects then
		return
	end
	local function watch(hole: Instance)
		if not hole:IsA("BasePart") or hole.Name ~= "DigHole" then
			return
		end
		local last = hole:GetAttribute("Progress") or 0
		hole:GetAttributeChangedSignal("Progress"):Connect(function()
			local progress = hole:GetAttribute("Progress") or 0
			local grew = progress > last + 0.001
			last = progress
			if not grew or controllers.Dig:IsMyHole(hole.Position) then
				return
			end
			local camera = Workspace.CurrentCamera
			if camera and (camera.CFrame.Position - hole.Position).Magnitude < 120 then
				controllers.Effects:SandBurst(hole.Position, 8)
			end
		end)
	end
	for _, hole in effects:GetChildren() do
		watch(hole)
	end
	effects.ChildAdded:Connect(watch)
end

---------------------------------------------------------------------------
-- Beach moods + event lighting
-- Each beach has its own time of day, haze, colour grading and sea colour (Zones.Info[..].Mood):
-- breezy Starting Beach, misty Rocky Shore, bright turquoise Tropical Island, golden-hour Abandoned
-- Pier, stormy Shipwreck Coast, warm Ancient Ruins, sunset Secret Island. The base uses Starting
-- Beach's. A night event (Moonlit Night) still turns the sky to night wherever you are.
---------------------------------------------------------------------------
local dayClock = Lighting.ClockTime
local moodZone: string? = "?"
-- Update 17: the sun keeps moving. Each beach has its base time of day; the light drifts slowly
-- around it (about ±20 minutes of sun over ~9 real minutes) so shadows creep across the sand.
local targetClock = Lighting.ClockTime
local nightMode = false
local CLOUD_COVER = { RockyShore = 0.62, ShipwreckCoast = 0.78, AbandonedPier = 0.55, TropicalIsland = 0.32, SecretIsland = 0.5 }
local function refreshLighting()
	local event = Events.ById[ReplicatedStorage:GetAttribute("EventId") or ""]
	local night = event ~= nil and event.Night == true
	local data = controllers and controllers.State.Data
	local zone = (data and data.CurrentZone and Zones.Info[data.CurrentZone]) or Zones.Info.StartingBeach
	local mood = zone.Mood or {}
	local info = TweenInfo.new(3, Enum.EasingStyle.Sine)
	targetClock = if night then 0.3 else (mood.Clock or dayClock)
	nightMode = night
	local clouds = Workspace.Terrain:FindFirstChildOfClass("Clouds")
	if clouds then
		TweenService:Create(clouds, TweenInfo.new(6, Enum.EasingStyle.Sine), { Cover = CLOUD_COVER[data and data.CurrentZone or ""] or 0.42 }):Play()
	end
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere and mood.AirColor then
		TweenService:Create(atmosphere, info, { Color = mood.AirColor, Decay = mood.AirDecay, Density = mood.Density, Haze = mood.Haze }):Play()
	end
	local grade = Lighting:FindFirstChild("ColorCorrection")
	if grade and grade:IsA("ColorCorrectionEffect") and mood.Tint then
		TweenService:Create(grade, info, { TintColor = mood.Tint, Saturation = mood.Saturation }):Play()
	end
	if mood.Water then
		TweenService:Create(Workspace.Terrain, info, { WaterColor = mood.Water }):Play()
	end
end

---------------------------------------------------------------------------
-- Where am I? (same rules as the server - used to show hints, the server still decides)
---------------------------------------------------------------------------
local function insideBox(part: BasePart, position: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(position)
	local half = part.Size / 2
	return math.abs(relative.X) <= half.X and math.abs(relative.Y) <= half.Y and math.abs(relative.Z) <= half.Z
end

local function myPosition(): Vector3?
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then (root :: BasePart).Position else nil
end

function World:IsAtBase(): boolean
	local position = myPosition()
	if not position or not map then
		return false
	end
	local zonesFolder = map:FindFirstChild("Zones")
	for _, folder in if zonesFolder then zonesFolder:GetChildren() else {} do
		local region = folder:FindFirstChild("Region")
		if region and region:IsA("BasePart") and insideBox(region, position) then
			return false
		end
	end
	local town = map:FindFirstChild("Town")
	return town == nil or (town:IsA("BasePart") and insideBox(town, position))
end

function World:IsAtOwnShop(): boolean
	local data = controllers.State.Data
	local position = myPosition()
	if not data or not data.Shop.Plot or not position or not map then
		return false
	end
	local plots = map:FindFirstChild("ShopPlots")
	local plot = plots and plots:FindFirstChild("Plot" .. data.Shop.Plot)
	local floor = plot and plot:FindFirstChild("Floor") :: BasePart?
	if not floor then
		return false
	end
	local relative = (floor :: BasePart).CFrame:PointToObjectSpace(position)
	local half = (floor :: BasePart).Size / 2
	return math.abs(relative.X) <= half.X + 6 and relative.Z >= -half.Z - 14 and relative.Z <= half.Z + 4 and math.abs(relative.Y) <= 30
end

---------------------------------------------------------------------------
-- After a teleport, point the camera the way the character is facing
function World:AlignCamera()
	task.delay(0.2, function()
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
		local camera = Workspace.CurrentCamera
		if root and camera then
			local look = root.CFrame.LookVector
			local focus = root.Position + Vector3.new(0, 2, 0)
			camera.CFrame = CFrame.lookAt(focus - look * 16 + Vector3.new(0, 7, 0), focus)
		end
	end)
end

---------------------------------------------------------------------------
function World:Init(all)
	controllers = all
end

function World:Start()
	map = Workspace:WaitForChild("Map")
	setupGates()
	setupStations()

	ProximityPromptService.PromptTriggered:Connect(function(prompt, triggeringPlayer)
		if triggeringPlayer ~= player then
			return
		end
		local openUI = prompt:GetAttribute("OpenUI")
		if type(openUI) == "string" then
			local window = UIKit.GetWindow(openUI)
			if window then
				window:Open(prompt:GetAttribute("OpenTab"))
			end
			return
		end
		local slot = prompt:GetAttribute("ShopSlot")
		if type(slot) == "number" then
			controllers.MyShop:OpenSlot(slot)
			return
		end
		if prompt:GetAttribute("ShopDesk") then
			controllers.MyShop:Open()
			return
		end
		local unlockZone = prompt:GetAttribute("UnlockZone")
		if type(unlockZone) == "string" then
			self:ShowUnlockCard(unlockZone)
			return
		end
		if prompt:GetAttribute("Inspect") then
			inspect(prompt)
		end
	end)

	controllers.State:OnChange(function(data)
		refreshGates(data)
		refreshSlotPrompts(data)
	end)

	task.spawn(watchDisplays)
	task.spawn(watchHoles)
	ReplicatedStorage:GetAttributeChangedSignal("EventId"):Connect(refreshLighting)
	refreshLighting()
	Lighting.ClockTime = targetClock
	RunService.Heartbeat:Connect(function(dt)
		local drift = if nightMode then 0 else math.sin(os.clock() * (2 * math.pi / 540)) * 0.33
		local goal = targetClock + drift
		local current = Lighting.ClockTime
		local diff = goal - current
		if math.abs(diff) > 12 then
			diff -= 24 * math.sign(diff) -- (never spin the long way round the clock)
		end
		Lighting.ClockTime = current + diff * math.min(1, dt * 0.6)
	end)
	-- walking onto another beach eases the sky, haze and sea into that beach's mood
	controllers.State:OnChange(function(data)
		local zone = data.CurrentZone
		if zone ~= moodZone then
			moodZone = zone
			refreshLighting()
		end
	end)

	RunService.PreRender:Connect(function(dt)
		local data = controllers.State.Data
		if data and data.Settings.ReducedMotion then
			return
		end
		local camera = Workspace.CurrentCamera
		if not camera then
			return
		end
		local cameraPos = camera.CFrame.Position
		for model in spinModels do
			if model.Parent and model:GetAttribute("Spin") then
				local pivot = model:GetPivot()
				if (pivot.Position - cameraPos).Magnitude < 90 then
					model:PivotTo(pivot * CFrame.Angles(0, dt * 0.8, 0))
				end
			end
		end
	end)
end

return World
