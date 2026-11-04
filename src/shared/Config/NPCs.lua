--[[
	NPCs
	The two shopkeepers at the base. Their 3D models live in
	Workspace > Map > Hub > Shops > <EquipmentShop | SellShop> > NPC
	(each NPC model has the attribute NPCId matching a key below).

	Actions (buttons in the dialogue box):
	  Window + Tab  opens that menu (EquipmentShop tabs: Detectors, Shovels, Boosts, Skins)
	  Do            special action handled by the client: "SellMode", "QuickSell", "Appraise"
]]

local NPCs = {}

NPCs.ById = {
	EquipmentShop = {
		Name = "Marina",
		Role = "Equipment Shop",
		Icon = "🛒",
		Color = Color3.fromRGB(40, 170, 190),
		Greetings = {
			"Welcome in! Detectors, shovels, boosts - if it helps you dig, I sell it.",
			"Rare treasure fights back. A stronger shovel makes the sand give up faster!",
			"Every detector comes with its own coil - a new detector means a better coil too!",
			"Backpack full? Sell the junk to the Captain next door and put the gems in your shop.",
			"Hear that beep? That's the sound of money, sweetie!",
		},
		Actions = {
			{ Text = "🛒 Browse equipment", Window = "EquipmentShop", Tab = "Detectors" },
			{ Text = "⛏ Shovels", Window = "EquipmentShop", Tab = "Shovels" },
			{ Text = "🎨 Detector skins", Window = "EquipmentShop", Tab = "Skins" },
			{ Text = "🍀 Boosts", Window = "EquipmentShop", Tab = "Boosts" },
		},
	},
	SellShop = {
		Name = "Captain Goldtooth",
		Role = "Sell Shop",
		Icon = "💰",
		Color = Color3.fromRGB(230, 170, 40),
		Greetings = {
			"Arr, let's see what the sea gave ye today!",
			"I pay fair coin for every trinket. Mostly fair. Fair-ish.",
			"Keep the rare ones for yer shop, sell me the rest. That's how fortunes are made!",
		},
		Actions = {
			{ Text = "💰 Sell treasures", Do = "SellMode" },
			{ Text = "⚡ Quick Sell", Do = "QuickSell" },
			{ Text = "🔍 Appraise backpack", Do = "Appraise" },
		},
	},
}

return NPCs
