--[[
	ClientMain (LocalScript)
	Starts every client controller in StarterPlayerScripts > Controllers.
	Each controller may have :Init(controllers) (build UI) and :Start() (connect events).
]]

local controllersFolder = script.Parent:WaitForChild("Controllers")

local ORDER = {
	"State",
	"Sound",
	"Effects",
	"Prompt",
	"Notify",
	"HUD",
	"Hotbar",
	"Detector",
	"DigAnimator",
	"Dig",
	"Reveal",
	"NPC",
	"Shark",
	"Inventory",
	"EquipmentShop",
	"MyShop",
	"Index",
	"Quests",
	"Travel",
	"Luck",
	"Settings",
	"World",
	"Ambience",
	"Dev",
}

local controllers = {}
for _, name in ORDER do
	controllers[name] = require(controllersFolder:WaitForChild(name .. "Controller"))
end
for _, name in ORDER do
	local controller = controllers[name]
	if controller.Init then
		controller:Init(controllers)
	end
end
for _, name in ORDER do
	local controller = controllers[name]
	if controller.Start then
		task.spawn(function()
			controller:Start()
		end)
	end
end
