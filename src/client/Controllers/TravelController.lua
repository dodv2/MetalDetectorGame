--[[
	TravelController
	🧭 Travel window: teleport between unlocked beaches, your shop and the town hub.
	Beaches are bought at the unlock station beside each beach's barrier (level + cash); this
	window shows what each one needs and takes you to the neighbouring beach. Secret Treasure
	Island has no barrier, so it's unlocked here once you've found its map.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Zones = require(Shared.Config.Zones)
local Treasures = require(Shared.Config.Treasures)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Travel = {}

local controllers
local window
local list: ScrollingFrame

local function travel(destination: string)
	local result = controllers.State:Call("TravelTo", destination)
	if result.Ok then
		window:Close()
		controllers.World:AlignCamera()
	end
end

function Travel:Render()
	local data = controllers.State.Data
	if not data or not window.IsOpen then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	for order, zoneId in Zones.Order do
		local zone = Zones.Info[zoneId]
		local unlocked = data.Zones[zoneId] == true
		local here = data.CurrentZone == zoneId
		local row = UIKit.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, Size = UDim2.new(1, -8, 0, 100), LayoutOrder = order, Parent = list }, {
			UIKit.Corner(14),
			UIKit.Stroke(if here then Theme.Colors.Gold else Theme.Colors.Stroke, 2, if here then 0.1 else 0.7),
		})
		UIKit.new("Frame", { BackgroundColor3 = zone.Color, Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(80, 80), Parent = row }, {
			UIKit.Corner(14),
			UIKit.Gradient(Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 150)),
		})
		UIKit.Text({ Text = tostring(zone.Index), Font = Theme.Fonts.Title, TextSize = 40, TextColor3 = Color3.fromRGB(60, 50, 30), Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(80, 80), TextXAlignment = Enum.TextXAlignment.Center, Parent = row })
		UIKit.Text({ Text = zone.Name .. (if here then "  📍 You are here" else ""), Font = Theme.Fonts.Title, TextSize = 21, Position = UDim2.fromOffset(102, 6), Size = UDim2.new(1, -290, 0, 26), Parent = row })
		UIKit.Text({ Text = zone.Description, TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(102, 32), Size = UDim2.new(1, -290, 0, 32), Parent = row })
		local chances = GameMath.GetChances(zoneId, data.Luck.Total, 1)
		-- (buying happens at the barrier, see above)
		UIKit.Text({
			Text = string.format("Level %d  •  Unlock %s  •  Legendary %.2f%%  •  XP x%s", zone.Level, if zone.Price > 0 then Format.Cash(zone.Price) else "free", chances.Legendary * 100, tostring(zone.XPMult)),
			Font = Theme.Fonts.Bold,
			TextSize = 12,
			Position = UDim2.fromOffset(102, 70),
			Size = UDim2.new(1, -290, 0, 18),
			Parent = row,
		})

		local text, color, enabled, action = "", Theme.Colors.Disabled, false, nil
		if unlocked then
			text, color, enabled = if here then "You're here" else "🧭 Travel", Theme.Colors.Teal, not here
			action = function()
				travel(zoneId)
			end
		elseif data.Level < zone.Level then
			text = "🔒 Level " .. zone.Level
		elseif zone.RequiresDiscovery and not data.Index[zone.RequiresDiscovery] then
			local def = Treasures.ById[zone.RequiresDiscovery]
			text = "🗺 Find the " .. (if def then def.Name else "map")
		elseif not zone.RequiresDiscovery then
			-- bought at its barrier: offer a trip to the beach next to it
			local previous = Zones.Order[order - 1]
			if previous and data.Zones[previous] then
				text, color, enabled = "🧭 Go to its barrier", Theme.Colors.Orange, true
				action = function()
					travel(previous)
					controllers.Notify:Toast("🔓 Walk to the unlock station beside the " .. zone.Name .. " barrier.", "Info", 5)
				end
			else
				text = "🔒 Unlock the beach before"
			end
		else
			enabled = data.Cash >= zone.Price
			text, color = "🔓 Unlock " .. Format.Cash(zone.Price), if enabled then Theme.Colors.Gold else Theme.Colors.Disabled
			action = function()
				local result = controllers.State:Call("UnlockZone", zoneId)
				if result.Ok then
					controllers.Sound:Chime(4)
				end
			end
		end
		local button = UIKit.Button(text, color, action, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.fromOffset(170, 52), TextSize = 15, Parent = row })
		if not enabled then
			UIKit.SetButtonEnabled(button, false)
		end
	end
end

function Travel:Init(all)
	controllers = all
	window = UIKit.Window("Travel", "🧭 Travel", Vector2.new(820, 560))
	local top = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 42), Parent = window.Content }, { UIKit.List(Enum.FillDirection.Horizontal, 8) })
	UIKit.Button("⚓ The Pier", Theme.Colors.Neutral, function()
		travel("Hub")
	end, { Size = UDim2.fromOffset(150, 40), TextSize = 16, Parent = top })
	UIKit.Button("🏪 My Shop", Theme.Colors.Neutral, function()
		travel("MyShop")
	end, { Size = UDim2.fromOffset(150, 40), TextSize = 16, Parent = top })
	UIKit.Text({ Text = "Unlock each beach at the station beside its barrier (level + cash). Better beaches = rarer, more valuable treasure.", TextSize = 13, TextColor3 = Theme.Colors.SubText, Size = UDim2.fromOffset(460, 40), Parent = top })
	list = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 1, -50), Parent = window.Content })
	UIKit.List(nil, 8).Parent = list
	window.Opened:Connect(function()
		self:Render()
	end)
end

function Travel:Start()
	controllers.State.Changed:Connect(function()
		self:Render()
	end)
end

return Travel
