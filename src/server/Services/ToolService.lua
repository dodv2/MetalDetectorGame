--[[
	ToolService
	Gives each player two Tools: the Metal Detector and their Shovel. They are rebuilt whenever
	the player changes detector, coil, skin or shovel. (The custom hotbar equips them: keys 1 / 2.)

	Treasures can be held too: selecting a treasure on the hotbar asks the server (EquipItem
	"Treasure") to put that exact backpack item in the player's hand as a Tool. The tool carries the
	item's real saved Value and Luck as attributes, and disappears as soon as the item leaves the
	backpack (sold, displayed...).
	Update 17: the treasure is posed per shape (TreasureModels.BuildHeld) and welded to a hidden
	Handle at the grip point, so it sits naturally in the palm and follows the hand (R6 + R15).
	Only ever one treasure tool exists: holding another destroys the old one first.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DetectorModels = require(Shared.DetectorModels)
local ShovelModels = require(Shared.ShovelModels)
local TreasureModels = require(Shared.TreasureModels)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local GameMath = require(Shared.GameMath)
local Format = require(Shared.Format)

local ToolService = {}

local services
local TOOL_NAME = "Metal Detector"

function ToolService:GiveTools(player: Player)
	local data = services.DataService:Get(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not data or not backpack then
		return
	end
	local character = player.Character
	local held = character and character:FindFirstChildOfClass("Tool")
	local heldKind = if held and held:GetAttribute("IsShovel") then "Shovel" elseif held and held:GetAttribute("IsDetector") then "Detector" else nil

	for _, container in { backpack, character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and (child:GetAttribute("IsDetector") or child:GetAttribute("IsShovel")) then
					child:Destroy()
				end
			end
		end
	end

	local eq = data.Equipment
	local detector = DetectorModels.BuildTool(eq.Detector, eq.Skin)
	detector.Parent = backpack
	local shovel = ShovelModels.BuildTool(eq.Shovel)
	shovel.Parent = backpack

	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and heldKind then
		humanoid:EquipTool(if heldKind == "Shovel" then shovel else detector)
	end
end

---------------------------------------------------------------------------
-- Held treasures
---------------------------------------------------------------------------
local function treasureTools(player: Player): { Tool }
	local list = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, child in container:GetChildren() do
				if child:IsA("Tool") and child:GetAttribute("IsTreasure") then
					table.insert(list, child)
				end
			end
		end
	end
	return list
end

-- The held treasure: the model is posed for a hand (TreasureModels.BuildHeld - its own size,
-- grip point and angle per shape), welded to a small invisible Handle at the grip, so it follows
-- the hand through walking, running and every animation on R6 and R15 rigs. A small name tag
-- floats over it for OTHER players (the holder gets the full card above the hotbar instead).
local function buildTreasureTool(player: Player, item): Tool?
	local def = Treasures.ById[item.TreasureId]
	if not def then
		return nil
	end
	local model, heldSize = TreasureModels.BuildHeld(def.Id)
	local tool = Instance.new("Tool")
	tool.Name = def.Name
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = def.Name
	tool.Grip = CFrame.new()
	tool:SetAttribute("IsTreasure", true)
	tool:SetAttribute("ItemId", item.Id)
	tool:SetAttribute("TreasureId", def.Id)
	tool:SetAttribute("Value", item.Value)
	tool:SetAttribute("Luck", GameMath.ItemDisplayLuck(item))
	tool:SetAttribute("Rarity", def.Rarity)

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.2, 0.2, 0.2)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.CanTouch = false
	handle.Massless = true
	handle.CFrame = CFrame.new()
	handle.Parent = tool
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") then
			part.Anchored = false
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
		end
	end
	model.PrimaryPart = nil
	model.Name = "Treasure"
	model.Parent = tool

	-- rarer finds give off a soft glow in the hand
	local tier = Rarities.Tier(def.Rarity)
	if tier >= 5 then
		local light = Instance.new("PointLight")
		light.Color = Rarities.Info[def.Rarity].Color
		light.Brightness = 0.6 + (tier - 5) * 0.3
		light.Range = 6
		light.Shadows = false
		light.Parent = handle
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "HeldTag"
	tag.Adornee = handle
	tag.Size = UDim2.fromOffset(170, 38)
	tag.StudsOffsetWorldSpace = Vector3.new(0, heldSize.Y + 0.9, 0)
	tag.MaxDistance = 45
	tag.LightInfluence = 0
	tag.PlayerToHideFrom = player
	tag.Parent = handle
	local color = Rarities.Info[def.Rarity].Color
	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.new(1, 0, 0, 20)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.TextSize = 17
	nameLabel.TextColor3 = color
	nameLabel.TextStrokeTransparency = 0.35
	nameLabel.Text = def.Name
	nameLabel.Parent = tag
	local infoLabel = Instance.new("TextLabel")
	infoLabel.BackgroundTransparency = 1
	infoLabel.Position = UDim2.fromOffset(0, 20)
	infoLabel.Size = UDim2.new(1, 0, 0, 16)
	infoLabel.Font = Enum.Font.GothamBold
	infoLabel.TextSize = 13
	infoLabel.TextColor3 = Color3.new(1, 1, 1)
	infoLabel.TextStrokeTransparency = 0.4
	infoLabel.Text = Rarities.Label(def.Rarity) .. "  ·  " .. Format.Cash(item.Value)
	infoLabel.Parent = tag
	return tool
end

-- Put one backpack treasure in the player's hand ("" = put it away)
function ToolService:HoldTreasure(player: Player, itemId: string)
	local data = services.DataService:Get(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not data or not humanoid or humanoid.Health <= 0 then
		return { Ok = false }
	end
	if itemId == "" then
		for _, tool in treasureTools(player) do
			tool:Destroy()
		end
		return { Ok = true }
	end
	local _, item = services.InventoryService:FindItem(data, itemId)
	if not item then
		return { Ok = false, Error = "That treasure isn't in your backpack" }
	end
	-- never two treasure models at once: keep the right one, drop any other
	local keep: Tool? = nil
	for _, tool in treasureTools(player) do
		if keep == nil and tool:GetAttribute("ItemId") == itemId then
			keep = tool
		else
			tool:Destroy()
		end
	end
	if keep then
		if keep.Parent ~= character then
			humanoid:EquipTool(keep)
		end
		return { Ok = true }
	end
	local tool = buildTreasureTool(player, item)
	if not tool then
		return { Ok = false }
	end
	tool.Parent = player:FindFirstChildOfClass("Backpack")
	humanoid:EquipTool(tool)
	return { Ok = true }
end

-- Drop held-treasure tools whose item has left the backpack (sold, displayed, ...)
function ToolService:ValidateTreasure(player: Player, data)
	for _, tool in treasureTools(player) do
		local itemId = tool:GetAttribute("ItemId")
		if type(itemId) ~= "string" or not services.InventoryService:FindItem(data, itemId) then
			tool:Destroy()
		end
	end
end

-- Kept for older callers
function ToolService:GiveDetector(player: Player)
	self:GiveTools(player)
end

local function onCharacter(player: Player)
	services.DataService:WaitFor(player)
	if not player.Parent then
		return
	end
	player:WaitForChild("Backpack", 10)
	ToolService:GiveTools(player)
end

function ToolService:Init(allServices)
	services = allServices
end

function ToolService:Start()
	local function setup(player: Player)
		player.CharacterAdded:Connect(function()
			onCharacter(player)
		end)
		if player.Character then
			task.spawn(onCharacter, player)
		end
	end
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
end

return ToolService
