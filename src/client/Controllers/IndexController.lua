--[[
	IndexController
	📖 Treasure Index: every treasure in the game, per zone. Undiscovered ones show as
	dark silhouettes with "???" so players know what's left to find.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Treasures = require(Shared.Config.Treasures)
local Rarities = require(Shared.Config.Rarities)
local Zones = require(Shared.Config.Zones)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)
local Viewport = require(script.Parent.Parent.UI.Viewport)

local Index = {}

local controllers
local window
local tabs
local ui = {} :: any
local selected: string? = nil

local TAB_NAMES = {}
local TAB_TO_ZONE = {}
for _, zoneId in Zones.Order do
	local name = Zones.Info[zoneId].Name
	table.insert(TAB_NAMES, name)
	TAB_TO_ZONE[name] = zoneId
end
table.insert(TAB_NAMES, "🌙 Event")
TAB_TO_ZONE["🌙 Event"] = "Event"

local function listFor(zoneId: string)
	local list = {}
	for _, def in Treasures.List do
		if (zoneId == "Event" and def.Event) or (def.Zone == zoneId and not def.Event) then
			table.insert(list, def)
		end
	end
	table.sort(list, function(a, b)
		local ta, tb = Rarities.Tier(a.Rarity), Rarities.Tier(b.Rarity)
		if ta ~= tb then
			return ta < tb
		end
		return a.Order < b.Order
	end)
	return list
end

function Index:Render()
	local data = controllers.State.Data
	if not data or not window.IsOpen then
		return
	end
	local total = GameMath.IndexCount(data.Index)
	ui.Progress:Set(total / Treasures.Count, string.format("Discovered %d / %d  (%d%%)", total, Treasures.Count, math.floor(total / Treasures.Count * 100)))

	for _, child in ui.Grid:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	local zoneId = TAB_TO_ZONE[tabs.Selected] or "StartingBeach"
	local list = listFor(zoneId)
	local found = 0
	for order, def in list do
		local count = data.Index[def.Id] or 0
		local discovered = count > 0
		if discovered then
			found += 1
		end
		local cell = UIKit.new("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = if discovered then Theme.Colors.PanelLight else Theme.Colors.PanelDark,
			LayoutOrder = order,
			Parent = ui.Grid,
			OnActivated = function()
				selected = def.Id
				self:ShowDetail(def, count)
			end,
		}, { UIKit.Corner(12), UIKit.Stroke(UIKit.RarityColor(def.Rarity), 2, if discovered then 0.3 else 0.75) })
		local icon = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 70), Parent = cell })
		Viewport.Create(def.Id, { Silhouette = not discovered }).Parent = icon
		UIKit.Text({ Text = if discovered then def.Name else "???", Font = Theme.Fonts.Bold, TextSize = 11, Position = UDim2.fromOffset(4, 70), Size = UDim2.new(1, -8, 0, 26), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
		UIKit.RarityLabel(def.Rarity, { TextSize = 11, Position = UDim2.fromOffset(0, 96), Size = UDim2.new(1, 0, 0, 13), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
		UIKit.Text({ Text = if discovered then "Found ×" .. count else "Not found", TextSize = 10, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(0, 110), Size = UDim2.new(1, 0, 0, 12), TextXAlignment = Enum.TextXAlignment.Center, Parent = cell })
	end
	ui.ZoneProgress.Text = string.format("%s: %d / %d discovered", tabs.Selected, found, #list)
	if selected then
		local def = Treasures.ById[selected]
		if def then
			self:ShowDetail(def, data.Index[def.Id] or 0)
		end
	end
end

function Index:ShowDetail(def, count: number)
	local discovered = count > 0
	local zone = Zones.Info[def.Zone]
	local where = if def.Event then "Event treasure (Moonlit Night)" elseif zone then zone.Name else "?"
	local levelText = if def.MinLevel then "  •  appears from level " .. def.MinLevel else ""
	if discovered then
		ui.Detail.Text = string.format("<b>%s</b>  —  %s  •  worth about %s  •  📍 %s%s\n<i>%s</i>", def.Name, Rarities.Label(def.Rarity), Format.Cash(def.Value), where, levelText, def.Lore)
	else
		ui.Detail.Text = string.format("<b>???</b>  —  %s  •  📍 %s%s\nKeep detecting to discover this treasure!", Rarities.Label(def.Rarity), where, levelText)
	end
end

function Index:Init(all)
	controllers = all
	window = UIKit.Window("Index", "📖 Treasure Index", Vector2.new(900, 560))
	ui.Progress = UIKit.Bar({ Size = UDim2.new(1, 0, 0, 22), Parent = window.Content }, Theme.Colors.Gold)
	local tabHolder = UIKit.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 30), Size = UDim2.new(1, 0, 0, 66), Parent = window.Content })
	tabs = UIKit.Tabs(tabHolder, TAB_NAMES, function()
		selected = nil
		ui.Detail.Text = "Click a treasure to read about it."
		self:Render()
	end, 30)
	local layout = tabs.Frame:FindFirstChildOfClass("UIListLayout")
	if layout then
		layout.Wraps = true
	end
	tabs.Frame.Size = UDim2.new(1, 0, 0, 66)
	for _, button in tabs.Buttons do
		button.Size = UDim2.new(0, 0, 0, 30)
		button.TextSize = 13
	end
	ui.ZoneProgress = UIKit.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(0, 100), Size = UDim2.new(1, 0, 0, 18), Parent = window.Content })
	ui.Grid = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 122), Size = UDim2.new(1, 0, 1, -194), Parent = window.Content })
	UIKit.Grid(Vector2.new(104, 126), 8).Parent = ui.Grid
	UIKit.Padding(4).Parent = ui.Grid
	ui.Detail = UIKit.Text({
		Text = "Click a treasure to read about it.",
		TextSize = 14,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 0, 1, 0),
		Size = UDim2.new(1, 0, 0, 64),
		BackgroundTransparency = 0,
		BackgroundColor3 = Theme.Colors.PanelDark,
		Parent = window.Content,
	})
	UIKit.Corner(10).Parent = ui.Detail
	UIKit.Padding(6, 10).Parent = ui.Detail
	window.Opened:Connect(function()
		local data = controllers.State.Data
		local zone = data and data.CurrentZone
		if zone and Zones.Info[zone] then
			tabs.Select(Zones.Info[zone].Name)
		else
			tabs.Select(tabs.Selected)
		end
	end)
end

function Index:Start()
	controllers.State.Changed:Connect(function()
		self:Render()
	end)
end

return Index
