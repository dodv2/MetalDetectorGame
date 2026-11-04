--[[
	PromptController
	Draws every ProximityPrompt in the game in the game's own style (no default Roblox prompt):

	  ◆E◆ ┃ BEGIN EXCAVATION        a brass key medallion (E / X / TAP) with a slowly turning
	       ┃ Buried treasure detected  dotted ring, next to a sand-parchment ribbon with the action

	  * slides + scales in when you come in range, shrinks away when you leave
	  * the medallion squishes when you press the key; a light shimmer sweeps the ribbon
	  * touch screens: the whole prompt is a big tappable button (no keyboard needed)
	  * gamepads show the right button letter
	Every prompt in Workspace is switched to Style = Custom automatically, so new prompts
	(NPCs, shop slots, boards, the dig marker) all get this look with no extra work.
]]

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TextService = game:GetService("TextService")
local Workspace = game:GetService("Workspace")

local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local PromptUI = {}

local player = Players.LocalPlayer
local controllers
local shown: { [ProximityPrompt]: any } = {}

local GOLD = Color3.fromRGB(255, 196, 60)
local BRASS_LIGHT = Color3.fromRGB(255, 232, 150)
local BRASS_DARK = Color3.fromRGB(150, 104, 44)
local INK = Color3.fromRGB(62, 38, 16)
local PARCHMENT_TOP = Color3.fromRGB(255, 243, 214)
local PARCHMENT_BOTTOM = Color3.fromRGB(236, 206, 150)

-- accent per kind of prompt (attribute PromptKind, or guessed)
local ACCENTS = {
	Dig = Color3.fromRGB(90, 220, 130),
	NPC = Color3.fromRGB(60, 190, 210),
	Unlock = Color3.fromRGB(255, 120, 90),
	Shop = Color3.fromRGB(170, 110, 255),
	Default = GOLD,
}

local GAMEPAD_NAMES = { ButtonX = "X", ButtonY = "Y", ButtonA = "A", ButtonB = "B", ButtonL1 = "LB", ButtonR1 = "RB" }

local function keyText(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType): string
	if inputType == Enum.ProximityPromptInputType.Touch then
		return "TAP"
	elseif inputType == Enum.ProximityPromptInputType.Gamepad then
		return GAMEPAD_NAMES[prompt.GamepadKeyCode.Name] or prompt.GamepadKeyCode.Name
	end
	local name = prompt.KeyboardKeyCode.Name
	return if #name <= 2 then name else string.sub(name, 1, 3)
end

local function kindOf(prompt: ProximityPrompt): string
	local kind = prompt:GetAttribute("PromptKind")
	if type(kind) == "string" then
		return kind
	end
	if prompt:GetAttribute("NPCId") then
		return "NPC"
	end
	return "Default"
end

function PromptUI:Build(prompt: ProximityPrompt, inputType: Enum.ProximityPromptInputType)
	local accent = ACCENTS[kindOf(prompt)] or ACCENTS.Default
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Prompt_" .. prompt.Name
	gui.Adornee = prompt.Parent :: any
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Size = UDim2.fromOffset(280, 70)
	gui.StudsOffset = Vector3.new(0, 0.6, 0)
	gui.Active = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- everything scales/fades together from this root
	local root = UIKit.new("Frame", {
		Name = "Root",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Parent = gui,
	})
	local rootScale = Instance.new("UIScale")
	rootScale.Scale = 0.6
	rootScale.Parent = root

	-- ribbon (parchment) -----------------------------------------------------
	local ribbon = UIKit.new("Frame", {
		Name = "Ribbon",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 46, 0.5, 0),
		Size = UDim2.new(1, -52, 0, 46),
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 1,
		ClipsDescendants = true,
		Parent = root,
	}, {
		UIKit.Corner(10),
		UIKit.new("UIGradient", { Rotation = 90, Color = ColorSequence.new(PARCHMENT_TOP, PARCHMENT_BOTTOM) }),
		UIKit.Stroke(INK, 2, 0.15),
	})
	-- accent stripe on the left edge of the ribbon
	UIKit.new("Frame", { Name = "Stripe", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(0, 22, 1, 0), BackgroundColor3 = accent, BorderSizePixel = 0, ZIndex = 2, Parent = ribbon })
	-- shimmer
	local shine = UIKit.new("Frame", {
		Name = "Shine",
		Position = UDim2.new(-0.4, 0, 0, 0),
		Size = UDim2.new(0.3, 0, 1, 0),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = 0.55,
		BorderSizePixel = 0,
		Rotation = 0,
		ZIndex = 4,
		Parent = ribbon,
	}, { UIKit.new("UIGradient", { Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1) }) }) })

	local title = UIKit.Text({
		Name = "Action",
		Text = string.upper(prompt.ActionText),
		Font = Theme.Fonts.Title,
		TextSize = 19,
		TextColor3 = INK,
		Position = UDim2.fromOffset(32, 4),
		Size = UDim2.new(1, -40, 0, 22),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = ribbon,
	})
	local subtitle = UIKit.Text({
		Name = "Object",
		Text = prompt.ObjectText,
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = Color3.fromRGB(140, 98, 52),
		Position = UDim2.fromOffset(32, 25),
		Size = UDim2.new(1, -40, 0, 16),
		TextWrapped = false,
		TextTruncate = Enum.TextTruncate.AtEnd,
		ZIndex = 3,
		Parent = ribbon,
	})
	-- widen the card for long titles ("Unlock Shipwreck Coast") instead of cutting them off
	local function fitWidth()
		local bounds = Vector2.new(1000, 40)
		local actionWidth = TextService:GetTextSize(title.Text, 19, Theme.Fonts.Title, bounds).X
		local objectWidth = TextService:GetTextSize(subtitle.Text, 12, Theme.Fonts.Bold, bounds).X
		gui.Size = UDim2.fromOffset(math.max(280, math.max(actionWidth, objectWidth) + 104), 70)
	end
	fitWidth()

	-- key medallion -------------------------------------------------------------
	local medal = UIKit.new("Frame", {
		Name = "Medallion",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 32, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		BackgroundTransparency = 1,
		ZIndex = 5,
		Parent = root,
	})
	local medalScale = Instance.new("UIScale")
	medalScale.Parent = medal
	-- rotating dotted ring
	local dots = UIKit.new("Frame", { Name = "Dots", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 5, Parent = medal })
	for i = 0, 7 do
		local arm = UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1), Rotation = i * 45, BackgroundTransparency = 1, ZIndex = 5, Parent = dots })
		UIKit.new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0), Size = UDim2.fromOffset(5, 5), BackgroundColor3 = accent, ZIndex = 5, Parent = arm }, { UIKit.Round() })
	end
	-- brass diamond (rounded square turned 45°)
	local diamond = UIKit.new("Frame", {
		Name = "Diamond",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(38, 38),
		Rotation = 45,
		BackgroundColor3 = Color3.new(1, 1, 1),
		ZIndex = 6,
		Parent = medal,
	}, {
		UIKit.Corner(9),
		UIKit.new("UIGradient", { Rotation = -45, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, BRASS_LIGHT), ColorSequenceKeypoint.new(0.5, GOLD), ColorSequenceKeypoint.new(1, BRASS_DARK) }) }),
		UIKit.Stroke(INK, 2, 0.1),
	})
	-- inner jewel
	local jewel = UIKit.new("Frame", {
		Name = "Jewel",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = Color3.fromRGB(20, 52, 66),
		ZIndex = 7,
		Parent = medal,
	}, { UIKit.Round(), UIKit.Stroke(accent, 2, 0.1) })
	local key = UIKit.Text({
		Name = "Key",
		Text = keyText(prompt, inputType),
		Font = Theme.Fonts.Title,
		TextSize = if touch then 11 else 18,
		TextColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Center,
		TextWrapped = false,
		ZIndex = 8,
		Parent = jewel,
	})

	-- touch / click: the whole prompt is a button
	local button = UIKit.new("TextButton", {
		Name = "Hit",
		Text = "",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 20,
		Parent = gui,
	})
	button.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldBegin()
		end
	end)
	button.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			prompt:InputHoldEnd()
		end
	end)

	local entry = {
		Gui = gui,
		Root = root,
		Scale = rootScale,
		MedalScale = medalScale,
		Dots = dots,
		Diamond = diamond,
		Shine = shine,
		Title = title,
		Subtitle = subtitle,
		Born = os.clock(),
		Connections = {},
	}
	-- keep the text in sync if the prompt changes while shown
	table.insert(entry.Connections, prompt:GetPropertyChangedSignal("ActionText"):Connect(function()
		title.Text = string.upper(prompt.ActionText)
		fitWidth()
	end))
	table.insert(entry.Connections, prompt:GetPropertyChangedSignal("ObjectText"):Connect(function()
		subtitle.Text = prompt.ObjectText
		fitWidth()
	end))
	table.insert(entry.Connections, prompt.Triggered:Connect(function()
		medalScale.Scale = 0.8
		UIKit.Tween(medalScale, 0.25, { Scale = 1 }, Enum.EasingStyle.Back)
	end))

	-- in: pop up from small, sliding in from the left
	root.Position = UDim2.new(0.5, -24, 0.5, 0)
	UIKit.Tween(root, 0.25, { Position = UDim2.fromScale(0.5, 0.5) }, Enum.EasingStyle.Quad)
	UIKit.Tween(rootScale, 0.3, { Scale = 1 }, Enum.EasingStyle.Back)
	return entry
end

function PromptUI:Remove(prompt: ProximityPrompt)
	local entry = shown[prompt]
	if not entry then
		return
	end
	shown[prompt] = nil
	for _, connection in entry.Connections do
		connection:Disconnect()
	end
	UIKit.Tween(entry.Scale, 0.15, { Scale = 0.05 }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	task.delay(0.16, function()
		entry.Gui:Destroy()
	end)
end

local function customize(instance: Instance)
	if instance:IsA("ProximityPrompt") then
		instance.Style = Enum.ProximityPromptStyle.Custom
	end
end

function PromptUI:Init(all)
	controllers = all
end

function PromptUI:Start()
	for _, descendant in Workspace:GetDescendants() do
		customize(descendant)
	end
	Workspace.DescendantAdded:Connect(customize)

	ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
		if prompt.Style ~= Enum.ProximityPromptStyle.Custom then
			return
		end
		self:Remove(prompt)
		local entry = self:Build(prompt, inputType)
		if entry then
			shown[prompt] = entry
			local hidden
			hidden = prompt.PromptHidden:Connect(function()
				hidden:Disconnect()
				self:Remove(prompt)
			end)
		end
	end)

	-- idle animation: turning dots, a gentle bob and the ribbon shimmer
	game:GetService("RunService").RenderStepped:Connect(function()
		local reduced = controllers.Effects:Reduced()
		local t = os.clock()
		for _, entry in shown do
			if not reduced then
				entry.Dots.Rotation = (t * 40) % 360
				entry.Gui.StudsOffset = Vector3.new(0, 0.6 + math.sin(t * 2.4) * 0.08, 0)
				local phase = ((t - entry.Born) % 2.4) / 2.4
				entry.Shine.Position = UDim2.new(-0.4 + phase * 1.8, 0, 0, 0)
			end
		end
	end)
end

return PromptUI
