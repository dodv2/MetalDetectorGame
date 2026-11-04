--[[
	DevService (Update 17)
	Developer test tools behind F1 / F2 / F3 - for the authorised developer account ONLY.

	SECURITY (all of it lives here, on the server - nothing on the client is trusted):
	  * Developers are identified by Roblox UserId (never by name): DEVELOPER_USER_IDS below.
	    The owner of the place (a user-owned game) is also allowed when ALLOW_PLACE_OWNER is on.
	  * The client's F1/F2/F3 key press is NOT proof of anything. Every single DevCommand call
	    re-checks the caller's UserId here; anyone else gets a flat "not available" and the attempt
	    is logged. Manually firing the remote from an exploit gets exactly the same answer.
	  * Commands only ever change the CALLER's own data, and every value is type-checked and clamped.
	  * Sandbox (on by default): while it's on, this session's data is never written to the
	    DataStore and never reaches the global leaderboards, so testing can't corrupt real
	    progression. Turning it off is an explicit choice (for controlled live testing).
	  * Live servers: allowed only while ALLOW_IN_LIVE_GAMES is true (Studio always works).

	Commands (DevCommand remote):
	  "Status"                      -> current values (the client only opens the panel if Ok)
	  "AddCash", amount             "SetCash", amount
	  "LevelUp", count              "SetLevel", level        "SetXP", xp
	  "SetDetector", tier           "SetShovel", tier         (1 = first ... n = best)
	  "SetLuck", points             session-only extra Luck (+N Luck; 0 removes it)
	  "Sandbox", on/off
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Equipment = require(Shared.Config.Equipment)
local Progression = require(Shared.Config.Progression)
local RemoteGuard = require(script.Parent.Parent.Util.RemoteGuard)

-- ▼ Authorised developer accounts (Roblox UserIds). Add more ids to give other testers access.
local DEVELOPER_USER_IDS: { [number]: boolean } = {
	[98951116] = true, -- EvilAzrie
}
-- Also allow whoever owns this place (only for games owned by a user, not a group)
local ALLOW_PLACE_OWNER = true
-- Allow the tools in live (published) servers for controlled testing. Studio always allows them.
local ALLOW_IN_LIVE_GAMES = true

local MAX_CASH = 1e15
local MAX_LUCK_POINTS = 100000

local DevService = {}

local services
local devLuck: { [Player]: number } = {}
local sandboxChosen: { [Player]: boolean } = {} -- the developer set the sandbox themselves

function DevService:IsDeveloper(player: Player): boolean
	if not RunService:IsStudio() and not ALLOW_IN_LIVE_GAMES then
		return false
	end
	if DEVELOPER_USER_IDS[player.UserId] then
		return true
	end
	return ALLOW_PLACE_OWNER and game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and player.UserId == game.CreatorId
end

-- Session-only Luck bonus (LuckService adds it; 1 = +100 Luck)
function DevService:GetLuckBonus(player: Player): number
	return devLuck[player] or 0
end

local function tierList(kind: string)
	return if kind == "Detector" then Equipment.Detectors else Equipment.Shovels
end

local function tierOf(kind: string, id: string): number
	for index, def in tierList(kind) do
		if def.Id == id then
			return index
		end
	end
	return 1
end

function DevService:Status(player: Player)
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Still loading" }
	end
	return {
		Ok = true,
		Cash = data.Cash,
		Level = data.Level,
		XP = data.XP,
		XPNeeded = Progression.XPForLevel(data.Level),
		MaxLevel = Progression.MaxLevel,
		Detector = tierOf("Detector", data.Equipment.Detector),
		DetectorCount = #Equipment.Detectors,
		DetectorName = (Equipment.ById.Detector[data.Equipment.Detector] or Equipment.Detectors[1]).Name,
		Shovel = tierOf("Shovel", data.Equipment.Shovel),
		ShovelCount = #Equipment.Shovels,
		ShovelName = (Equipment.ById.Shovel[data.Equipment.Shovel] or Equipment.Shovels[1]).Name,
		LuckPoints = math.floor((devLuck[player] or 0) * 100 + 0.5),
		TotalLuckPoints = math.floor(services.LuckService:GetLuck(player).Points * 100 + 0.5),
		Sandbox = services.DataService:IsSandboxed(player),
		Studio = RunService:IsStudio(),
	}
end

local function number(value: any, min: number, max: number): number?
	if type(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
		return nil
	end
	return math.clamp(math.floor(value), min, max)
end

local function setEquipment(player: Player, data, kind: string, tier: number)
	local def = tierList(kind)[tier]
	if not def then
		return false
	end
	data.Owned[kind][def.Id] = true
	data.Equipment[kind] = def.Id
	services.ToolService:GiveTools(player)
	return true
end

function DevService:Run(player: Player, command: any, value: any)
	if not self:IsDeveloper(player) then
		warn(("[DevService] refused DevCommand %q from %s (%d) - not an authorised developer"):format(tostring(command), player.Name, player.UserId))
		return { Ok = false, Error = "Not available." }
	end
	if type(command) ~= "string" then
		return { Ok = false, Error = "Bad command" }
	end
	local data = services.DataService:Get(player)
	if not data then
		return { Ok = false, Error = "Still loading" }
	end
	if command == "Status" then
		return self:Status(player)
	end

	local message
	if command == "Sandbox" then
		if type(value) ~= "boolean" then
			return { Ok = false, Error = "Bad value" }
		end
		services.DataService:SetSandbox(player, value)
		message = if value then "🧪 Sandbox ON - nothing from this session is saved" else "💾 Sandbox OFF - this session saves normally again"
	else
		-- any change to your data turns the sandbox on first, unless you switched it off yourself
		if not sandboxChosen[player] then
			services.DataService:SetSandbox(player, true)
		end
		if command == "AddCash" then
			local amount = number(value, 1, MAX_CASH)
			if not amount then
				return { Ok = false, Error = "Enter a whole number" }
			end
			data.Cash = math.min(MAX_CASH, data.Cash + amount)
			message = "+$" .. amount
		elseif command == "SetCash" then
			local amount = number(value, 0, MAX_CASH)
			if not amount then
				return { Ok = false, Error = "Enter a whole number" }
			end
			data.Cash = amount
			message = "Cash set"
		elseif command == "LevelUp" then
			local count = number(value, 1, Progression.MaxLevel) or 1
			services.LevelService:SetLevel(player, math.min(Progression.MaxLevel, data.Level + count))
			message = "Level " .. data.Level
		elseif command == "SetLevel" then
			local level = number(value, 1, Progression.MaxLevel)
			if not level then
				return { Ok = false, Error = "Enter a level (1-" .. Progression.MaxLevel .. ")" }
			end
			services.LevelService:SetLevel(player, level)
			message = "Level " .. data.Level
		elseif command == "SetXP" then
			local needed = Progression.XPForLevel(data.Level)
			local xp = number(value, 0, math.max(0, needed - 1))
			if not xp then
				return { Ok = false, Error = "Enter XP (0-" .. (needed - 1) .. ")" }
			end
			data.XP = xp
			message = "XP set"
		elseif command == "SetDetector" or command == "SetShovel" then
			local kind = if command == "SetDetector" then "Detector" else "Shovel"
			local tier = number(value, 1, #tierList(kind))
			if not tier or not setEquipment(player, data, kind, tier) then
				return { Ok = false, Error = "Bad tier" }
			end
			message = tierList(kind)[tier].Name .. " equipped"
		elseif command == "SetLuck" then
			local points = number(value, 0, MAX_LUCK_POINTS)
			if not points then
				return { Ok = false, Error = "Enter Luck points (0-" .. MAX_LUCK_POINTS .. ")" }
			end
			devLuck[player] = if points > 0 then points / 100 else nil
			message = if points > 0 then "+" .. points .. " test Luck (this session only)" else "Test Luck removed"
		else
			return { Ok = false, Error = "Unknown command" }
		end
	end
	if command == "Sandbox" then
		sandboxChosen[player] = true
	end
	services.LeaderboardService:UpdateLeaderstats(player)
	services.AchievementService:Check(player)
	services.StateService:Push(player) -- the HUD updates straight away
	local status = self:Status(player)
	status.Message = message
	return status
end

function DevService:Init(allServices)
	services = allServices
end

function DevService:Start()
	RemoteGuard.Handle("DevCommand", 0.12, function(player, command, value)
		return self:Run(player, command, value)
	end)
	Players.PlayerRemoving:Connect(function(player)
		devLuck[player] = nil
		sandboxChosen[player] = nil
	end)
end

return DevService
