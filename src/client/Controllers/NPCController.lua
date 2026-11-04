--[[
	NPCController
	Brings the town's shopkeepers to life (all animation is local and cheap - the NPC parts are
	anchored and only animated when you're nearby):
	  * idle breathing + subtle arm sway
	  * the head follows you when you walk past; the whole body turns to face you while talking
	  * a friendly wave when you walk up to the counter
	  * talking to them (their ProximityPrompt) opens a dialogue box with a typewriter greeting
	    and buttons that open the right shop tab / sell / appraise

	NPC models: Workspace > Map > Hub > Shops > <Shop> > NPC  (attribute NPCId, see Config > NPCs)
	Each part has a "Rig" attribute: Root, Head, Torso, LeftArm, RightArm, Legs.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local NPCs = require(Shared.Config.NPCs)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local NPC = {}

local player = Players.LocalPlayer
local controllers
local ui = {} :: any

type Rig = {
	Id: string,
	Model: Model,
	Root: BasePart,
	Base: CFrame,
	Parts: { { Part: BasePart, Rel: CFrame, Rig: string } },
	Yaw: number,
	HeadYaw: number,
	WaveUntil: number,
	Talking: boolean,
	Seed: number,
}

local rigs: { Rig } = {}
local talkingTo: Rig? = nil
local typeToken = 0
-- a shop window opened from an NPC closes again when you walk away from that NPC
local shopWindow = nil :: any
local shopRig: Rig? = nil

-- pivots in the NPC root's local space (root sits 3 studs above the feet)
local NECK = CFrame.new(0, 1, 0)
local SHOULDER_L = CFrame.new(-1.5, 1, 0)
local SHOULDER_R = CFrame.new(1.5, 1, 0)

---------------------------------------------------------------------------
-- Rigs
---------------------------------------------------------------------------
local function register(model: Model)
	local id = model:GetAttribute("NPCId")
	if type(id) ~= "string" then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local base = (root :: BasePart).CFrame
	local rig: Rig = {
		Id = id,
		Model = model,
		Root = root :: BasePart,
		Base = base,
		Parts = {},
		Yaw = 0,
		HeadYaw = 0,
		WaveUntil = 0,
		Talking = false,
		Seed = math.random() * 10,
	}
	for _, part in model:GetDescendants() do
		if part:IsA("BasePart") and part ~= root then
			table.insert(rig.Parts, { Part = part, Rel = base:ToObjectSpace(part.CFrame), Rig = tostring(part:GetAttribute("Rig") or "Torso") })
		end
	end
	table.insert(rigs, rig)
end

local function yawTowards(rig: Rig, position: Vector3): number
	local relative = rig.Base:PointToObjectSpace(position)
	return math.atan2(-relative.X, -relative.Z)
end

function NPC:Animate(dt: number)
	local character = player.Character
	local myRoot = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	local reduced = controllers.Effects:Reduced()
	local now = os.clock()
	for _, rig in rigs do
		local distanceToCamera = (rig.Base.Position - camera.CFrame.Position).Magnitude
		if distanceToCamera > 110 or not rig.Model.Parent then
			continue
		end
		local targetYaw, targetHead = 0, 0
		local near = false
		if myRoot then
			local distance = (myRoot.Position - rig.Base.Position).Magnitude
			near = distance < 22
			local toPlayer = yawTowards(rig, myRoot.Position)
			if rig.Talking or distance < 11 then
				targetYaw = math.clamp(toPlayer, -1.1, 1.1) -- turn the body (stays behind the counter)
			end
			if near then
				targetHead = math.clamp(toPlayer - targetYaw, -0.9, 0.9)
			end
		end
		local blend = math.min(1, dt * 5)
		rig.Yaw += (targetYaw - rig.Yaw) * blend
		rig.HeadYaw += (targetHead - rig.HeadYaw) * blend

		local t = now + rig.Seed
		local breathe = if reduced then 0 else math.sin(t * 2) * 0.05
		local sway = if reduced then 0 else math.sin(t * 1.3) * 0.05
		local nod = if rig.Talking and not reduced then math.sin(t * 9) * 0.08 else 0
		local waving = now < rig.WaveUntil
		local rootCF = rig.Base * CFrame.Angles(0, rig.Yaw, 0)
		local up = CFrame.new(0, breathe, 0)

		for _, entry in rig.Parts do
			local rel = entry.Rel
			local cf
			if entry.Rig == "Head" then
				cf = rootCF * up * NECK * CFrame.Angles(nod, rig.HeadYaw, 0) * NECK:Inverse() * rel
			elseif entry.Rig == "RightArm" then
				local angle = if waving then math.rad(150 + math.sin(t * 12) * 18) else sway
				local axis = if waving then CFrame.Angles(0, 0, angle) else CFrame.Angles(angle, 0, 0)
				cf = rootCF * up * SHOULDER_R * axis * SHOULDER_R:Inverse() * rel
			elseif entry.Rig == "LeftArm" then
				cf = rootCF * up * SHOULDER_L * CFrame.Angles(-sway, 0, 0) * SHOULDER_L:Inverse() * rel
			elseif entry.Rig == "Legs" then
				cf = rootCF * rel
			else
				cf = rootCF * up * rel
			end
			entry.Part.CFrame = cf
		end
		rig.Root.CFrame = rootCF
		if not near then
			rig.Talking = false
		end
	end
end

local function findRig(id: string): Rig?
	for _, rig in rigs do
		if rig.Id == id then
			return rig
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- Dialogue
---------------------------------------------------------------------------
function NPC:BuildUI()
	local panel = UIKit.new("Frame", {
		Name = "NPCDialogue",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -98),
		Size = UDim2.fromOffset(560, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 25,
		Parent = UIKit.Screen,
	}, {
		UIKit.Corner(18),
		UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 195, 215)),
		UIKit.Padding(12, 14),
	})
	ui.Stroke = UIKit.Stroke(Theme.Colors.Gold, 3, 0.1)
	ui.Stroke.Parent = panel
	UIKit.AddScale(panel)
	ui.Panel = panel
	ui.Home = panel.Position

	ui.Portrait = UIKit.new("TextLabel", {
		Text = "",
		TextSize = 40,
		Font = Theme.Fonts.Title,
		BackgroundColor3 = Theme.Colors.Gold,
		Size = UDim2.fromOffset(72, 72),
		ZIndex = 26,
		Parent = panel,
	}, { UIKit.Round(), UIKit.Stroke(Color3.new(1, 1, 1), 3, 0.2) })

	local right = UIKit.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(86, 0),
		Size = UDim2.new(1, -86, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 26,
		Parent = panel,
	}, { UIKit.List(nil, 4) })
	local nameRow = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 24), LayoutOrder = 1, ZIndex = 26, Parent = right })
	ui.Name = UIKit.Text({ Text = "", Font = Theme.Fonts.Title, TextSize = 22, Size = UDim2.new(1, -30, 1, 0), TextWrapped = false, RichText = true, ZIndex = 26, Parent = nameRow })
	UIKit.TextStroke(0.4).Parent = ui.Name
	UIKit.Button("✕", Theme.Colors.Neutral, function()
		self:Close()
	end, { AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 0), Size = UDim2.fromOffset(26, 24), TextSize = 14, ZIndex = 27, Parent = nameRow })
	ui.Line = UIKit.Text({ Text = "", TextSize = 16, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 2, ZIndex = 26, Parent = right })
	ui.Actions = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 3, ZIndex = 26, Parent = right }, {
		UIKit.new("UIGridLayout", { CellSize = UDim2.fromOffset(150, 36), CellPadding = UDim2.fromOffset(6, 6), SortOrder = Enum.SortOrder.LayoutOrder }),
	})
end

local function typewrite(label: TextLabel, text: string)
	typeToken += 1
	local token = typeToken
	label.Text = text
	label.MaxVisibleGraphemes = 0
	if controllers.Effects:Reduced() then
		label.MaxVisibleGraphemes = -1
		return
	end
	task.spawn(function()
		local total = utf8.len(text) or #text
		for count = 1, total do
			if token ~= typeToken then
				return
			end
			label.MaxVisibleGraphemes = count
			if count % 3 == 0 then
				task.wait(0.02)
			end
		end
		label.MaxVisibleGraphemes = -1
	end)
end

function NPC:DoAction(action)
	if action.Window then
		local rig = talkingTo
		self:Close()
		local window = UIKit.GetWindow(action.Window)
		if window then
			window:Open(action.Tab)
			shopWindow = window
			shopRig = rig
		end
	elseif action.Do == "SellMode" then
		local rig = talkingTo
		self:Close()
		controllers.Inventory:OpenSellMode()
		shopWindow = UIKit.GetWindow("Inventory")
		shopRig = rig
	elseif action.Do == "QuickSell" then
		self:Close()
		controllers.Inventory:OpenQuickSell()
	elseif action.Do == "Appraise" then
		local data = controllers.State.Data
		local total, best, bestDef = 0, nil, nil
		for _, item in data.Inventory do
			total += item.Value
			if not best or item.Value > best.Value then
				best, bestDef = item, Treasures.ById[item.TreasureId]
			end
		end
		if not best or not bestDef then
			typewrite(ui.Line, "An empty backpack! Come back when the sand's been kind to ye.")
		else
			typewrite(ui.Line, string.format("Yer whole backpack's worth about %s. Finest piece: a %s %s worth %s. Keep the shiny ones for yer shop!",
				Format.Cash(total), Rarities.Label(bestDef.Rarity), bestDef.Name, Format.Cash(best.Value)))
		end
	end
end

function NPC:Open(id: string)
	local info = NPCs.ById[id]
	if not info then
		return
	end
	local rig = findRig(id)
	if talkingTo and talkingTo ~= rig then
		talkingTo.Talking = false
	end
	talkingTo = rig
	if rig then
		rig.Talking = true
		rig.WaveUntil = os.clock() + 1.2
		local prompt = rig.Root:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = false -- the dialogue box replaces the prompt while you talk
		end
	end
	ui.Portrait.Text = info.Icon
	ui.Portrait.BackgroundColor3 = info.Color
	ui.Stroke.Color = info.Color
	ui.Name.Text = string.format("%s  <font size='14' color='#b0c8da'>%s</font>", info.Name, info.Role)

	for _, child in ui.Actions:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	for index, action in info.Actions do
		UIKit.Button(action.Text, if index == 1 then info.Color else Theme.Colors.Neutral, function()
			self:DoAction(action)
		end, { TextSize = 14, LayoutOrder = index, ZIndex = 27, Parent = ui.Actions })
	end
	UIKit.Button("👋 Goodbye", Theme.Colors.Neutral, function()
		self:Close()
	end, { TextSize = 14, LayoutOrder = 99, ZIndex = 27, Parent = ui.Actions })

	ui.Panel.Visible = true
	ui.Panel.Position = ui.Home + UDim2.fromOffset(0, 30)
	UIKit.Tween(ui.Panel, 0.25, { Position = ui.Home }, Enum.EasingStyle.Back)
	controllers.Effects:Pop(ui.Portrait, 1.3)
	typewrite(ui.Line, info.Greetings[math.random(1, #info.Greetings)])
	controllers.Sound:Play("Click", 0.8)
end

function NPC:Close()
	typeToken += 1
	if talkingTo then
		talkingTo.Talking = false
		local prompt = talkingTo.Root:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Enabled = true
		end
		talkingTo = nil
	end
	ui.Panel.Visible = false
end

---------------------------------------------------------------------------
function NPC:Init(all)
	controllers = all
	self:BuildUI()
end

function NPC:Start()
	local map = Workspace:WaitForChild("Map")
	local hub = map:WaitForChild("Hub")
	local shops = hub:WaitForChild("Shops", 20)
	if shops then
		for _, model in shops:GetDescendants() do
			if model:IsA("Model") and model:GetAttribute("NPCId") then
				register(model)
			end
		end
	end

	ProximityPromptService.PromptTriggered:Connect(function(prompt, who)
		if who ~= player then
			return
		end
		local id = prompt:GetAttribute("NPCId")
		if type(id) == "string" then
			self:Open(id)
		end
	end)
	-- wave when you walk up
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local id = prompt:GetAttribute("NPCId")
		local rig = if type(id) == "string" then findRig(id) else nil
		if rig and os.clock() > rig.WaveUntil + 4 then
			rig.WaveUntil = os.clock() + 1.4
		end
	end)

	-- opening any menu window hides the dialogue; walking away closes it
	UIKit.WindowOpened:Connect(function()
		if ui.Panel.Visible then
			self:Close()
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		self:Animate(dt)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if talkingTo then
			if not root or (root.Position - talkingTo.Base.Position).Magnitude > 16 then
				self:Close()
			end
		end
		if shopWindow and shopRig then
			if not shopWindow.IsOpen then
				shopWindow, shopRig = nil, nil
			elseif not root or (root.Position - shopRig.Base.Position).Magnitude > 34 then
				shopWindow:Close()
				shopWindow, shopRig = nil, nil
				controllers.Notify:Toast("You walked away from the shop.", "Info", 2)
			end
		end
	end)
end

return NPC
