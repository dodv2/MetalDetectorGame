--[[
	QuestsController
	📜 Quests window: 3 daily quests (claim rewards) and all achievements with progress bars.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Format = require(Shared.Format)
local Achievements = require(Shared.Config.Achievements)
local Equipment = require(Shared.Config.Equipment)
local GameMath = require(Shared.GameMath)
local UIKit = require(script.Parent.Parent.UI.UIKit)
local Theme = require(script.Parent.Parent.UI.Theme)

local Quests = {}

local controllers
local window
local tabs
local list: ScrollingFrame
local ui = {} :: any

local function rewardText(reward): string
	local parts = {}
	if reward.Cash then
		table.insert(parts, "💰 " .. Format.Cash(reward.Cash))
	end
	if reward.XP then
		table.insert(parts, "⭐ " .. Format.Commas(reward.XP) .. " XP")
	end
	if reward.Trinket then
		local trinket = Equipment.ById.Trinket[reward.Trinket]
		table.insert(parts, "🧿 " .. (if trinket then trinket.Name .. " (" .. Format.Luck(trinket.Luck) .. ")" else reward.Trinket))
	end
	return table.concat(parts, "   ")
end

local function goalText(def, value: number): string
	if def.Format == "Cash" then
		return Format.Cash(value) .. " / " .. Format.Cash(def.Goal)
	elseif def.Format == "Percent" then
		return math.floor(value * 100) .. "% / " .. math.floor(def.Goal * 100) .. "%"
	end
	return Format.Commas(value) .. " / " .. Format.Commas(def.Goal)
end

function Quests:Render()
	local data = controllers.State.Data
	if not data or not window.IsOpen then
		return
	end
	for _, child in list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end

	if tabs.Selected == "Daily Quests" then
		local secondsLeft = 86400 - (math.floor(controllers.State:Now()) % 86400)
		ui.Info.Text = "New quests in " .. Format.Time(secondsLeft) .. " (midnight UTC)"
		for index, quest in data.Quests.List do
			local done = quest.Progress >= quest.Target
			local row = UIKit.new("Frame", { BackgroundColor3 = Theme.Colors.PanelLight, Size = UDim2.new(1, -8, 0, 96), LayoutOrder = index, Parent = list }, { UIKit.Corner(14), UIKit.Stroke(if done then Theme.Colors.Green else Theme.Colors.Stroke, 2, if done then 0.2 else 0.7) })
			UIKit.Text({ Text = quest.Text, Font = Theme.Fonts.Title, TextSize = 19, Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -200, 0, 24), Parent = row })
			UIKit.Text({ Text = "Reward: " .. rewardText(quest.Reward), Font = Theme.Fonts.Bold, TextSize = 13, TextColor3 = Theme.Colors.Gold, Position = UDim2.fromOffset(14, 34), Size = UDim2.new(1, -200, 0, 18), Parent = row })
			local bar = UIKit.Bar({ Position = UDim2.fromOffset(14, 62), Size = UDim2.new(1, -200, 0, 20), Parent = row }, if done then Theme.Colors.Green else Theme.Colors.Teal)
			bar:Set(quest.Progress / quest.Target, Format.Commas(quest.Progress) .. " / " .. Format.Commas(quest.Target))
			local button = UIKit.Button(if quest.Claimed then "✔ Claimed" elseif done then "Claim!" else "In progress", if done and not quest.Claimed then Theme.Colors.Gold else Theme.Colors.Disabled, function()
				local result = controllers.State:Call("ClaimQuest", index)
				if result.Ok then
					controllers.Sound:Chime(4)
				end
			end, { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(160, 50), Parent = row })
			if quest.Claimed or not done then
				UIKit.SetButtonEnabled(button, false)
			end
		end
		if #data.Quests.List == 0 then
			UIKit.Text({ Text = "Quests are loading...", TextSize = 16, Size = UDim2.new(1, 0, 0, 30), Parent = list })
		end
	else
		local completed = 0
		for _ in data.Achievements do
			completed += 1
		end
		ui.Info.Text = string.format("🏆 %d / %d achievements completed", completed, #Achievements.List)
		local order = 0
		for _, category in Achievements.Categories do
			order += 1
			local header = UIKit.new("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 26), LayoutOrder = order, Parent = list })
			UIKit.Text({ Text = category, Font = Theme.Fonts.Title, TextSize = 20, TextColor3 = Theme.Colors.Sand, Size = UDim2.fromScale(1, 1), Parent = header })
			for _, def in Achievements.List do
				if def.Category == category then
					order += 1
					local done = data.Achievements[def.Id] == true
					local value = GameMath.AchievementStat(data, def.Stat)
					local row = UIKit.new("Frame", { BackgroundColor3 = if done then Color3.fromRGB(30, 70, 50) else Theme.Colors.PanelLight, Size = UDim2.new(1, -8, 0, 64), LayoutOrder = order, Parent = list }, { UIKit.Corner(12) })
					UIKit.Text({ Text = (if done then "✅ " else "🏆 ") .. def.Name, Font = Theme.Fonts.Bold, TextSize = 16, Position = UDim2.fromOffset(12, 6), Size = UDim2.new(0.5, 0, 0, 20), Parent = row })
					UIKit.Text({ Text = def.Description, TextSize = 13, TextColor3 = Theme.Colors.SubText, Position = UDim2.fromOffset(12, 28), Size = UDim2.new(0.5, 0, 0, 16), Parent = row })
					UIKit.Text({ Text = rewardText(def.Reward), TextSize = 12, Font = Theme.Fonts.Bold, TextColor3 = Theme.Colors.Gold, Position = UDim2.fromOffset(12, 44), Size = UDim2.new(0.55, 0, 0, 16), Parent = row })
					local bar = UIKit.Bar({ AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = UDim2.new(0.4, 0, 0, 22), Parent = row }, if done then Theme.Colors.Green else Theme.Colors.Teal)
					bar:Set(if done then 1 else value / def.Goal, if done then "Complete!" else goalText(def, value))
				end
			end
		end
	end
end

function Quests:Init(all)
	controllers = all
	window = UIKit.Window("Quests", "📜 Quests & Achievements", Vector2.new(820, 540))
	tabs = UIKit.Tabs(window.Content, { "Daily Quests", "Achievements" }, function()
		self:Render()
	end)
	ui.Info = UIKit.Text({ Text = "", Font = Theme.Fonts.Bold, TextSize = 14, TextColor3 = Theme.Colors.SubText, AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, 0, 0, 8), Size = UDim2.fromOffset(360, 20), TextXAlignment = Enum.TextXAlignment.Right, Parent = window.Content })
	list = UIKit.ScrollFrame({ Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 1, -44), Parent = window.Content })
	UIKit.List(nil, 8).Parent = list
	window.Opened:Connect(function()
		tabs.Select(tabs.Selected)
	end)
end

function Quests:Start()
	controllers.State.Changed:Connect(function()
		self:Render()
	end)
end

return Quests
