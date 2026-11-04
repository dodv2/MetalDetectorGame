--[[
	RevealController
	The treasure discovery moment (after excavation reaches 100%):

	  1. The treasure bursts out of the hole, spins and hovers. Effects scale with rarity:
	       Common    sand burst + soft sparkles
	       Uncommon  green sparkles
	       Rare      blue light pillar + ground shockwave
	       Epic      purple sparkle storm + double shockwave (+ server beam others can see)
	       Legendary golden flash, camera shake, confetti, "LEGENDARY!" stamp
	       Mythical  bigger flash/shake, rays, "MYTHICAL!!" stamp
	       Secret    rainbow pillar, triple shockwave, rainbow confetti, "★ SECRET ★"
	     Every effect has a visual form, so sound is optional (hard-of-hearing friendly).
	  2. The server has ALREADY put the treasure in your backpack. A simple discovery card
	     (bottom-centre) shows its name, rarity and value - no selling or shop buttons here:
	     you sell at the Sell Shop and display in your own shop, back at base.
	  3. After a moment the treasure flies into its hotbar slot and the backpack counter bumps.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Format = require(Shared.Format)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local TreasureModels = require(Shared.TreasureModels)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Viewport = require(script.Parent.Parent.UI.Viewport)

local Reveal = {}

local player = Players.LocalPlayer
local controllers
local queue = {}
local showing = false
local card: Frame
local cardHome: UDim2
local stamp: TextLabel
local SHOW_TIME = 2.6 -- seconds the discovery card stays (a little longer for rarer finds)

local STAMPS = {
	[5] = "LEGENDARY!",
	[6] = "MYTHICAL!!",
	[7] = "★ SECRET ★",
}

---------------------------------------------------------------------------
-- 3D effect in the world
---------------------------------------------------------------------------
function Reveal:WorldEffect(payload)
	local def = Treasures.ById[payload.Item.TreasureId]
	if not def then
		return
	end
	local rarity = Rarities.Info[def.Rarity]
	local tier = rarity.Tier
	local color = UIKit.RarityColor(def.Rarity)
	local position: Vector3 = payload.Position
	local effects = controllers.Effects
	local reduced = effects:Reduced()

	-- everyone gets the sand explosion
	effects:SandBurst(position, 26 + tier * 4)
	effects:Sparkles(position + Vector3.new(0, 1, 0), color, 10 + tier * 10, 8 + tier * 2)
	if tier >= 3 then
		effects:Shockwave(position, color, 10 + tier * 3)
	end
	if tier == 3 then
		effects:Beam(position, color, 26, false, 2.2)
	end
	if tier >= 4 then
		task.delay(0.18, function()
			effects:Shockwave(position, color, 16 + tier * 4)
		end)
	end
	if tier >= 7 then
		effects:Beam(position, color, 80, true, 3.5)
		task.delay(0.36, function()
			effects:Shockwave(position, Color3.new(1, 1, 1), 40)
		end)
	end
	if tier >= 5 then
		effects:Flash(if tier >= 7 then Color3.new(1, 1, 1) else color, 0.35 + (tier - 5) * 0.1)
		effects:Shake(0.35 + (tier - 5) * 0.2, 0.35 + (tier - 5) * 0.15)
		effects:Confetti(if tier >= 7 then nil else color, 30 + (tier - 5) * 20)
		if tier >= 6 then
			task.delay(0.6, function()
				effects:Confetti(nil, 30)
			end)
		end
	end

	-- the treasure itself pops out of the hole, spins and hovers
	local model = TreasureModels.Build(def.Id, { Scale = 1.15 })
	model.Parent = Workspace
	local start = CFrame.new(position - Vector3.new(0, 1.2, 0))
	local finish = CFrame.new(position + Vector3.new(0, 3.6, 0))
	model:PivotTo(start)
	local root = model.PrimaryPart :: BasePart
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = 10 + tier * 3
	light.Brightness = 1 + tier * 0.6
	light.Parent = root
	if tier >= 2 then
		local aura = Instance.new("ParticleEmitter")
		aura.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		aura.Color = ColorSequence.new(color)
		aura.LightEmission = 1
		aura.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 0) })
		aura.Speed = NumberRange.new(1, 3)
		aura.SpreadAngle = Vector2.new(180, 180)
		aura.Lifetime = NumberRange.new(0.5, 1)
		aura.Rate = 6 + tier * 4
		aura.Parent = root
	end

	if reduced then
		model:PivotTo(finish)
	else
		local t0 = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local elapsed = os.clock() - t0
			if not model.Parent then
				connection:Disconnect()
				return
			end
			-- a quick wobble as the sand lets go, then it bursts up out of the hole and hovers
			if elapsed < 0.22 then
				local shake = (0.22 - elapsed) / 0.22
				model:PivotTo(start * CFrame.new(0, elapsed * 1.5, 0) * CFrame.Angles(math.sin(elapsed * 70) * 0.12 * shake, 0, math.cos(elapsed * 63) * 0.12 * shake))
				return
			end
			local alpha = math.clamp((elapsed - 0.22) / 0.9, 0, 1)
			local eased = 1 - (1 - alpha) ^ 3
			local bob = if alpha >= 1 then math.sin(elapsed * 3) * 0.25 else 0
			model:PivotTo(start:Lerp(finish, eased) * CFrame.new(0, bob, 0) * CFrame.Angles(0, (elapsed - 0.22) * (2 + tier * 0.4), 0))
		end)
	end

	task.delay(2.4 + tier * 0.15, function()
		for _, part in model:GetDescendants() do
			if part:IsA("BasePart") then
				TweenService:Create(part, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			elseif part:IsA("ParticleEmitter") then
				part.Enabled = false
			end
		end
		TweenService:Create(light, TweenInfo.new(0.5), { Brightness = 0 }):Play()
		task.wait(0.55)
		model:Destroy()
	end)
end

---------------------------------------------------------------------------
-- Discovery card
---------------------------------------------------------------------------
function Reveal:ShowStamp(tier: number, color: Color3)
	local text = STAMPS[tier]
	if not text then
		return
	end
	stamp.Text = text
	stamp.TextColor3 = if tier >= 7 then Color3.new(1, 1, 1) else color
	stamp.Visible = true
	stamp.TextTransparency = 0
	stamp.Rotation = -8
	local gradient = stamp:FindFirstChildOfClass("UIGradient")
	if gradient then
		gradient.Enabled = tier >= 7
	end
	controllers.Effects:Pop(stamp, 2.2)
	task.delay(1.8, function()
		UIKit.Tween(stamp, 0.4, { TextTransparency = 1 })
		task.wait(0.4)
		stamp.Visible = false
	end)
end

function Reveal:ShowCard(payload)
	local item = payload.Item
	local def = Treasures.ById[item.TreasureId]
	if not def then
		return
	end
	showing = true
	for _, child in card:GetChildren() do
		child:Destroy()
	end
	local tier = Rarities.Tier(def.Rarity)
	local color = UIKit.RarityColor(def.Rarity)
	UIKit.Corner(18).Parent = card
	UIKit.Stroke(color, if tier >= 5 then 4 else 3, 0.05).Parent = card
	UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(180, 195, 215)).Parent = card
	if tier >= 5 then
		controllers.Effects:Rays(card, color, 360)
	end

	-- icon -----------------------------------------------------------------
	local iconHolder = UIKit.new("Frame", {
		Name = "Icon",
		Position = UDim2.fromOffset(12, 12),
		Size = UDim2.fromOffset(94, 94),
		BackgroundColor3 = Theme.Colors.PanelDark,
		ZIndex = 2,
		Parent = card,
	}, { UIKit.Corner(16), UIKit.Gradient(color:Lerp(Color3.new(0, 0, 0), 0.4), Theme.Colors.PanelDark), UIKit.Stroke(color, 2, 0.3) })
	local view = Viewport.Create(def.Id, { Spin = not controllers.Effects:Reduced() })
	view.ZIndex = 3
	view.Parent = iconHolder

	-- text -----------------------------------------------------------------
	local info = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(118, 10), Size = UDim2.new(1, -130, 0, 98), ZIndex = 2, Parent = card }, {
		UIKit.List(nil, 2),
	})
	local header = UIKit.Text({
		Text = if payload.IsNew then "✨ NEW DISCOVERY!" else "TREASURE FOUND",
		Font = Theme.Fonts.Bold,
		TextSize = 12,
		TextColor3 = if payload.IsNew then Theme.Colors.Gold else Theme.Colors.SubText,
		Size = UDim2.new(1, 0, 0, 14),
		LayoutOrder = 1,
		ZIndex = 2,
		Parent = info,
	})
	UIKit.TextStroke(0.5).Parent = header
	local name = UIKit.Text({ Text = def.Name, Font = Theme.Fonts.Title, TextSize = 24, Size = UDim2.new(1, 0, 0, 28), TextTruncate = Enum.TextTruncate.AtEnd, TextWrapped = false, LayoutOrder = 2, ZIndex = 2, Parent = info })
	UIKit.TextStroke(0.4).Parent = name
	UIKit.RarityLabel(def.Rarity, { Text = Rarities.Label(def.Rarity) .. "  " .. UIKit.TierPips(def.Rarity), TextSize = 15, Size = UDim2.new(1, 0, 0, 18), LayoutOrder = 3, ZIndex = 2, Parent = info })
	local zone = Zones.Info[item.Zone]
	local data = controllers.State.Data
	local backpackText = if data then string.format(" (%d/%d)", #data.Inventory, data.Capacity) else ""
	UIKit.Text({
		Text = string.format("💰 <b>%s</b>  ·  🎒 added to your backpack%s", Format.Cash(item.Value), backpackText),
		Font = Theme.Fonts.Body,
		TextSize = 13,
		Size = UDim2.new(1, 0, 0, 16),
		TextWrapped = false,
		LayoutOrder = 4,
		ZIndex = 2,
		Parent = info,
	})
	local rewards = "+" .. Format.Commas(payload.XP) .. " XP"
	if payload.BonusCash and payload.BonusCash > 0 then
		rewards ..= "  ·  +" .. Format.Cash(payload.BonusCash) .. " sifted coins"
	end
	if zone then
		rewards ..= "  ·  📍 " .. zone.Name
	end
	UIKit.Text({ Text = rewards, Font = Theme.Fonts.Bold, TextSize = 12, TextColor3 = Theme.Colors.XP, Size = UDim2.new(1, 0, 0, 14), TextWrapped = false, TextTruncate = Enum.TextTruncate.AtEnd, LayoutOrder = 5, ZIndex = 2, Parent = info })

	local timerBar = UIKit.new("Frame", {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 14, 1, -4),
		Size = UDim2.new(1, -28, 0, 3),
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		ZIndex = 3,
		Parent = card,
	}, { UIKit.Corner(2) })

	local closed = false
	local function close()
		if closed then
			return
		end
		closed = true
		local from = iconHolder.AbsolutePosition + iconHolder.AbsoluteSize / 2
		UIKit.Tween(card, 0.18, { Position = cardHome + UDim2.fromOffset(0, 40) })
		UIKit.Tween(card, 0.18, { BackgroundTransparency = 1 })
		controllers.Hotbar:FlyIn(def.Id, from)
		task.delay(0.2, function()
			card.Visible = false
			showing = false
			self:Next()
		end)
	end

	-- show it
	card.Visible = true
	card.BackgroundTransparency = 0.04
	card.Position = cardHome + UDim2.fromOffset(0, 50)
	UIKit.Tween(card, 0.32, { Position = cardHome }, Enum.EasingStyle.Back)
	controllers.Effects:Pop(iconHolder, 1.35)
	controllers.Sound:Chime(tier)
	self:ShowStamp(tier, color)

	local duration = SHOW_TIME + math.max(0, tier - 4) * 0.6
	UIKit.Tween(timerBar, duration, { Size = UDim2.new(0, 0, 0, 3) }, Enum.EasingStyle.Linear)
	task.delay(duration, close)
end

function Reveal:Next()
	if showing then
		return
	end
	local payload = table.remove(queue, 1)
	if payload then
		self:ShowCard(payload)
	end
end

function Reveal:Init(all)
	controllers = all
	card = UIKit.new("Frame", {
		Name = "DiscoveryCard",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -94),
		Size = UDim2.fromOffset(460, 118),
		BackgroundColor3 = Theme.Colors.Panel,
		Visible = false,
		ZIndex = 30,
		Parent = UIKit.Screen,
	})
	cardHome = card.Position
	UIKit.AddScale(card)

	-- big rarity stamp (Legendary+), centred a bit above the middle so it never blocks the dig
	local stampHolder = UIKit.new("Frame", {
		Name = "RarityStamp",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(600, 90),
		BackgroundTransparency = 1,
		ZIndex = 45,
		Parent = UIKit.Screen,
	})
	UIKit.AddScale(stampHolder)
	stamp = UIKit.new("TextLabel", {
		Name = "Text",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Font = Theme.Fonts.Title,
		TextSize = 72,
		Text = "",
		Visible = false,
		ZIndex = 45,
		Parent = stampHolder,
	})
	UIKit.TextStroke(0.1).Parent = stamp
	UIKit.new("UIGradient", {
		Enabled = false,
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 110, 110)),
			ColorSequenceKeypoint.new(0.25, Color3.fromRGB(255, 230, 110)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(110, 255, 160)),
			ColorSequenceKeypoint.new(0.75, Color3.fromRGB(110, 190, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(220, 120, 255)),
		}),
		Parent = stamp,
	})
end

function Reveal:Start()
	Net.Event("TreasureFound").OnClientEvent:Connect(function(payload)
		self:WorldEffect(payload)
		table.insert(queue, payload)
		task.delay(1.1, function()
			self:Next()
		end)
	end)
end

-- keep the player reference used by effects helpers
Reveal.Player = player

return Reveal
