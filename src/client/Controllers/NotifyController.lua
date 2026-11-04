--[[
	NotifyController
	Toast messages (top of screen), celebrations (purchases), server-wide rare-find announcements,
	and the two-stage LEVEL-UP sequence:
	  1. a compact, slightly translucent "LEVEL UP!  LEVEL 10" notice slides in (with the reward)
	  2. when it has gone, small text lines list what just became AVAILABLE
	     ("Iron Shovel Available in Equipment Shop", "Rocky Shore Available to Unlock", ...)
	A queue plays them strictly in order, so they never overlap or get lost - several level-ups
	arriving together are merged into one notice for the newest level.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local Format = require(Shared.Format)
local Equipment = require(Shared.Config.Equipment)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Notify = {}

local controllers
local toastHolder: Frame
local bannerHolder: Frame
local celebrateHolder: Frame
local levelHolder: Frame
local levelQueue = {}
local levelBusy = false
local MAX_TOASTS = 4
local order = 0

function Notify:Toast(text: string, kind: string?, duration: number?)
	local color = Theme.NotifyColors[kind or "Info"] or Theme.NotifyColors.Info
	order += 1
	local toast = UIKit.new("Frame", {
		Size = UDim2.fromOffset(480, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color,
		BackgroundTransparency = 0.05,
		LayoutOrder = order,
		Parent = toastHolder,
	}, {
		UIKit.Corner(12),
		UIKit.Stroke(Color3.new(1, 1, 1), 2, 0.7),
		UIKit.Padding(10, 14),
	})
	local label = UIKit.Text({
		Text = text,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Font = Theme.Fonts.Bold,
		TextSize = 17,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = toast,
	})
	UIKit.TextStroke(0.6).Parent = label

	local toasts = {}
	for _, child in toastHolder:GetChildren() do
		if child:IsA("Frame") then
			table.insert(toasts, child)
		end
	end
	if #toasts > MAX_TOASTS then
		table.sort(toasts, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		for i = 1, #toasts - MAX_TOASTS do
			toasts[i]:Destroy()
		end
	end

	task.delay(duration or (if kind == "Rare" or kind == "Event" then 6 else 4), function()
		if toast.Parent then
			UIKit.Tween(toast, 0.3, { BackgroundTransparency = 1 })
			UIKit.Tween(label, 0.3, { TextTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

-- Big centred banner (level up etc.)
function Notify:Banner(title: string, subtitle: string?, color: Color3?, lines: { string }?, duration: number?)
	bannerHolder:ClearAllChildren()
	local banner = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(520, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = color or Theme.Colors.Gold,
		Parent = bannerHolder,
	}, {
		UIKit.Corner(18),
		UIKit.Stroke(Color3.new(1, 1, 1), 3, 0.3),
		UIKit.Padding(14, 18),
		UIKit.List(nil, 4, Enum.HorizontalAlignment.Center),
		UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
	})
	local textColor = UIKit.ContrastText(color or Theme.Colors.Gold)
	UIKit.Text({ Text = title, Font = Theme.Fonts.Title, TextSize = 40, TextColor3 = textColor, Size = UDim2.new(1, 0, 0, 46), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, Parent = banner })
	if subtitle then
		UIKit.Text({ Text = subtitle, Font = Theme.Fonts.Bold, TextSize = 18, TextColor3 = textColor, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, Parent = banner })
	end
	for index, line in lines or {} do
		UIKit.Text({ Text = "🔓 " .. line, Font = Theme.Fonts.Body, TextSize = 15, TextColor3 = textColor, Size = UDim2.new(1, 0, 0, 20), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2 + index, Parent = banner })
	end
	banner.Position = UDim2.new(0.5, 0, 0, -40)
	UIKit.Tween(banner, 0.35, { Position = UDim2.fromScale(0.5, 0) }, Enum.EasingStyle.Back)
	local rays = controllers.Effects:Rays(bannerHolder, color or Theme.Colors.Gold, 520)
	rays.Position = UDim2.new(0.5, 0, 0, 50)
	controllers.Effects:Pop(banner, 0.7)
	task.delay(duration or 4.5, function()
		if banner.Parent then
			UIKit.Tween(banner, 0.3, { Position = UDim2.new(0.5, 0, 0, -300) })
			task.wait(0.3)
			banner:Destroy()
			rays:Destroy()
		end
	end)
end

-- Centre-top celebration pop (purchases, upgrades): icon, title, subtitle, rays, sparkles
function Notify:Celebrate(icon: string, title: string, subtitle: string?, color: Color3?, duration: number?)
	celebrateHolder:ClearAllChildren()
	local accent = color or Theme.Colors.Gold
	local frame = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(380, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = Theme.Colors.Panel,
		ZIndex = 2,
		Parent = celebrateHolder,
	}, {
		UIKit.Corner(18),
		UIKit.Stroke(accent, 3, 0.05),
		UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 195, 215)),
		UIKit.Padding(12, 16),
		UIKit.List(nil, 2, Enum.HorizontalAlignment.Center),
	})
	local rays = controllers.Effects:Rays(celebrateHolder, accent, 360)
	local iconLabel = UIKit.Text({ Text = icon, TextSize = 44, Size = UDim2.new(1, 0, 0, 50), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 1, ZIndex = 2, Parent = frame })
	local titleLabel = UIKit.Text({ Text = title, Font = Theme.Fonts.Title, TextSize = 30, TextColor3 = accent, Size = UDim2.new(1, 0, 0, 34), TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 2, ZIndex = 2, Parent = frame })
	UIKit.TextStroke(0.3).Parent = titleLabel
	if subtitle then
		UIKit.Text({ Text = subtitle, Font = Theme.Fonts.Bold, TextSize = 15, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, TextXAlignment = Enum.TextXAlignment.Center, LayoutOrder = 3, ZIndex = 2, Parent = frame })
	end
	controllers.Effects:Pop(frame, 0.6)
	controllers.Effects:Pop(iconLabel, 1.8)
	task.delay(duration or 2.6, function()
		if frame.Parent then
			UIKit.Tween(frame, 0.25, { Position = UDim2.fromScale(0.5, 0.2), BackgroundTransparency = 1 })
			for _, d in frame:GetDescendants() do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 0.25, { TextTransparency = 1 })
				end
			end
			task.wait(0.26)
			frame:Destroy()
			rays:Destroy()
		end
	end)
end

-- Sparkle ring around your character (upgrades, level ups)
function Notify:CharacterSparkle(color: Color3)
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		controllers.Effects:Sparkles(root.Position, color, 40, 14)
		controllers.Effects:Shockwave(root.Position - Vector3.new(0, 2.8, 0), color, 14)
	end
end

local function purchaseDetails(payload): (string, string, string)
	local category, id = payload.Category, payload.Id
	if category == "Shovel" then
		local def = Equipment.ById.Shovel[id]
		if def then
			return "⛏", "NEW SHOVEL!", string.format("%s equipped\nstronger, faster swings  ·  digs through everything quicker", def.Name)
		end
	elseif category == "Detector" then
		local def = Equipment.ById.Detector[id]
		if def then
			return "📡", "NEW DETECTOR!", string.format("%s equipped  ·  built-in %s  ·  range %s", def.Name, def.Coil or "coil", Format.Meters(def.Range))
		end
	elseif category == "Skin" then
		return "🎨", "NEW LOOK!", tostring(payload.Name) .. " detector paint"
	elseif category == "Theme" then
		return "🏠", "SHOP THEME!", tostring(payload.Name) .. " unlocked for your shop"
	end
	return "🛒", "PURCHASED!", tostring(payload.Name)
end

---------------------------------------------------------------------------
-- Level-up sequence
---------------------------------------------------------------------------
local UNLOCK_ICONS = { Equipment = "🛒", Beach = "🏖", Shop = "🏪", Cosmetic = "🎨", Feature = "✨" }

-- Stage 1: compact translucent "LEVEL UP! LEVEL n" notice
local function showLevelNotice(payload): number
	levelHolder:ClearAllChildren()
	local notice = UIKit.new("Frame", {
		Name = "LevelUp",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, -10),
		Size = UDim2.fromOffset(0, 54),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundColor3 = Theme.Colors.PanelDark,
		BackgroundTransparency = 0.22,
		Parent = levelHolder,
	}, {
		UIKit.Corner(27),
		UIKit.Stroke(Theme.Colors.Gold, 2, 0.15),
		UIKit.Padding(0, 10),
		UIKit.List(Enum.FillDirection.Horizontal, 10, nil, Enum.VerticalAlignment.Center),
	})
	UIKit.new("UIPadding", { PaddingRight = UDim.new(0, 18), Parent = notice })
	local badge = UIKit.new("Frame", { Size = UDim2.fromOffset(40, 40), BackgroundColor3 = Theme.Colors.Gold, LayoutOrder = 1, Parent = notice }, {
		UIKit.Round(),
		UIKit.Gradient(Color3.fromRGB(255, 236, 160), Color3.fromRGB(230, 160, 40)),
	})
	UIKit.Text({ Text = "⬆", Font = Theme.Fonts.Title, TextSize = 22, TextColor3 = Color3.fromRGB(70, 42, 10), Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center, Parent = badge })
	local texts = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.fromOffset(0, 46), AutomaticSize = Enum.AutomaticSize.X, LayoutOrder = 2, Parent = notice }, {
		UIKit.List(nil, 0, nil, Enum.VerticalAlignment.Center),
	})
	local title = UIKit.Text({
		Text = string.format("LEVEL UP!  <font color='#ffffff'>LEVEL %d</font>", payload.Level),
		Font = Theme.Fonts.Title,
		TextSize = 22,
		TextColor3 = Theme.Colors.Gold,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextWrapped = false,
		LayoutOrder = 1,
		Parent = texts,
	})
	UIKit.TextStroke(0.4).Parent = title
	local reward = "+" .. Format.Cash(payload.Cash or 0)
	for _, boost in payload.Boosts or {} do
		local def = Equipment.ById.Boost[boost.Id]
		reward ..= "  ·  free " .. (if def then def.Name else "Luck boost") .. " (" .. Format.Time(boost.Duration) .. ")"
	end
	if payload.From and payload.Level - payload.From > 1 then
		reward = string.format("Levels %d → %d  ·  ", payload.From, payload.Level) .. reward
	end
	UIKit.Text({ Text = reward, Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Theme.Colors.SubText, Size = UDim2.fromOffset(0, 16), AutomaticSize = Enum.AutomaticSize.X, TextWrapped = false, LayoutOrder = 2, Parent = texts })

	-- slide down + pop, shine sweep, then away
	local scale = Instance.new("UIScale")
	scale.Scale = 0.7
	scale.Parent = notice
	UIKit.Tween(notice, 0.35, { Position = UDim2.new(0.5, 0, 0, 0) }, Enum.EasingStyle.Back)
	UIKit.Tween(scale, 0.35, { Scale = 1 }, Enum.EasingStyle.Back)
	controllers.Effects:Pop(badge, 1.4)
	local duration = 2.4
	task.delay(duration, function()
		if notice.Parent then
			UIKit.Tween(notice, 0.25, { Position = UDim2.new(0.5, 0, 0, -30), BackgroundTransparency = 1 })
			UIKit.Tween(scale, 0.25, { Scale = 0.85 })
			for _, d in notice:GetDescendants() do
				if d:IsA("TextLabel") then
					UIKit.Tween(d, 0.25, { TextTransparency = 1 })
				elseif d:IsA("UIStroke") then
					UIKit.Tween(d, 0.25, { Transparency = 1 })
				elseif d:IsA("Frame") then
					UIKit.Tween(d, 0.25, { BackgroundTransparency = 1 })
				end
			end
			task.wait(0.27)
			notice:Destroy()
		end
	end)
	return duration + 0.3
end

-- Stage 2: small text lines, one after another, for everything that's now available
local function showUnlocks(unlocks): number
	if #unlocks == 0 then
		return 0
	end
	levelHolder:ClearAllChildren()
	local list = UIKit.new("Frame", {
		Name = "Unlocks",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 0),
		AutomaticSize = Enum.AutomaticSize.XY,
		BackgroundTransparency = 1,
		Parent = levelHolder,
	}, { UIKit.List(nil, 4, Enum.HorizontalAlignment.Center) })
	local shown = math.min(#unlocks, 6)
	local lines = {}
	for index = 1, shown do
		local entry = unlocks[index]
		local text = (UNLOCK_ICONS[entry.Kind] or "🔓") .. "  " .. entry.Text
		if index == 6 and #unlocks > 6 then
			text = string.format("✨  …and %d more unlocks", #unlocks - 5)
		end
		local line = UIKit.new("TextLabel", {
			Text = text,
			Font = Theme.Fonts.Bold,
			TextSize = 14,
			TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = Theme.Colors.PanelDark,
			BackgroundTransparency = 1,
			TextTransparency = 1,
			Size = UDim2.fromOffset(0, 26),
			AutomaticSize = Enum.AutomaticSize.X,
			TextWrapped = false,
			LayoutOrder = index,
			Parent = list,
		}, { UIKit.Corner(13), UIKit.Padding(0, 14) })
		local stroke = UIKit.TextStroke(1)
		stroke.Parent = line
		table.insert(lines, line)
		task.delay((index - 1) * 0.22, function()
			if line.Parent then
				UIKit.Tween(line, 0.25, { BackgroundTransparency = 0.3, TextTransparency = 0 })
				UIKit.Tween(stroke, 0.25, { Transparency = 0.5 })
				controllers.Effects:Pop(line, 1.12)
			end
		end)
	end
	local duration = 2.6 + shown * 0.45
	task.delay(duration, function()
		for _, line in lines do
			if line.Parent then
				UIKit.Tween(line, 0.3, { BackgroundTransparency = 1, TextTransparency = 1 })
			end
		end
		task.wait(0.32)
		list:Destroy()
	end)
	return duration + 0.35
end

local function runLevelQueue()
	if levelBusy then
		return
	end
	levelBusy = true
	task.spawn(function()
		while #levelQueue > 0 do
			-- several level-ups waiting? show one notice for the newest level, all unlocks together
			local payload = table.remove(levelQueue, 1)
			while #levelQueue > 0 do
				local nextOne = table.remove(levelQueue, 1)
				payload = {
					From = payload.From,
					Level = nextOne.Level,
					Cash = (payload.Cash or 0) + (nextOne.Cash or 0),
					Boosts = table.move(nextOne.Boosts or {}, 1, #(nextOne.Boosts or {}), #(payload.Boosts or {}) + 1, table.clone(payload.Boosts or {})),
					Unlocks = table.move(nextOne.Unlocks or {}, 1, #(nextOne.Unlocks or {}), #(payload.Unlocks or {}) + 1, table.clone(payload.Unlocks or {})),
				}
			end
			controllers.Sound:Chime(5)
			Notify:CharacterSparkle(Theme.Colors.Gold)
			controllers.HUD:BumpLevel()
			task.wait(showLevelNotice(payload)) -- stage 1 always first
			task.wait(showUnlocks(payload.Unlocks or {})) -- stage 2 only after stage 1 is gone
		end
		levelBusy = false
	end)
end

function Notify:Init(all)
	controllers = all
	toastHolder = UIKit.new("Frame", {
		Name = "Toasts",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 54),
		Size = UDim2.fromOffset(480, 300),
		BackgroundTransparency = 1,
		ZIndex = 40,
		Parent = UIKit.Screen,
	}, { UIKit.List(nil, 6, Enum.HorizontalAlignment.Center) })
	UIKit.AddScale(toastHolder)

	celebrateHolder = UIKit.new("Frame", {
		Name = "Celebrate",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(380, 200),
		BackgroundTransparency = 1,
		ZIndex = 44,
		Parent = UIKit.Screen,
	})
	UIKit.AddScale(celebrateHolder)

	bannerHolder = UIKit.new("Frame", {
		Name = "Banner",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.16, 0),
		Size = UDim2.fromOffset(520, 200),
		BackgroundTransparency = 1,
		ZIndex = 45,
		Parent = UIKit.Screen,
	})
	UIKit.AddScale(bannerHolder)

	-- level-up notice + unlock lines: upper-middle, small, never over the hotbar or menus
	levelHolder = UIKit.new("Frame", {
		Name = "LevelUpHolder",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0.2, 0),
		Size = UDim2.fromOffset(460, 200),
		BackgroundTransparency = 1,
		ZIndex = 43,
		Parent = UIKit.Screen,
	})
	UIKit.AddScale(levelHolder)
end

function Notify:Start()
	Net.Event("Notify").OnClientEvent:Connect(function(payload)
		if type(payload) == "table" and type(payload.Text) == "string" then
			self:Toast(payload.Text, payload.Kind)
			if payload.Kind == "Success" or payload.Kind == "Rare" then
				controllers.Sound:Play("Reward", if payload.Kind == "Rare" then 1.3 else 1.1, 0.6)
			end
		end
	end)

	Net.Event("Announcement").OnClientEvent:Connect(function(payload)
		local def = Treasures.ById[payload.TreasureId]
		if not def then
			return
		end
		local zone = Zones.Info[payload.Zone]
		local isMe = payload.UserId == game:GetService("Players").LocalPlayer.UserId
		local who = if isMe then "You" else payload.Player
		self:Toast(string.format("🌟 %s found a %s %s%s!", who, string.upper(def.Rarity), def.Name,
			if zone then " at " .. zone.Name else ""), "Rare", 6)
	end)

	Net.Event("LevelUp").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Level) ~= "number" then
			return
		end
		table.insert(levelQueue, payload)
		runLevelQueue()
	end)

	Net.Event("Purchased").OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" then
			return
		end
		local icon, title, subtitle = purchaseDetails(payload)
		self:Celebrate(icon, title, subtitle, Theme.Colors.Gold)
		self:CharacterSparkle(Theme.Colors.Gold)
		controllers.Sound:Chime(4)
	end)
end

-- Reference so Rarities stays a dependency for rarity text in announcements
Notify.Rarities = Rarities

return Notify
