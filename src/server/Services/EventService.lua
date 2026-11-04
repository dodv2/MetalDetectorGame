--[[
	EventService
	Runs server-wide limited-time events (see Config > Events).
	The active event is published as attributes on ReplicatedStorage so every client can show it:
	  ReplicatedStorage:GetAttribute("EventId")    -- "" when none
	  ReplicatedStorage:GetAttribute("EventEnds")  -- unix time
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Events = require(Shared.Config.Events)
local Signal = require(Shared.Signal)

local EventService = {}
EventService.Changed = Signal.new()

local services
local active = nil
local endsAt = 0
local lastEventId = nil

function EventService:GetActive()
	if active and os.time() < endsAt then
		return active
	end
	return nil
end

function EventService:GetLuckBonus(): number
	local event = self:GetActive()
	return if event then event.LuckBonus or 0 else 0
end

function EventService:GetSpawnMult(): number
	local event = self:GetActive()
	return if event then event.SpawnMult or 1 else 1
end

function EventService:GetDigSpeedMult(): number
	local event = self:GetActive()
	return if event then event.DigSpeedMult or 1 else 1
end

function EventService:StartEvent(eventId: string, duration: number?)
	local def = Events.ById[eventId]
	if not def then
		return
	end
	active = def
	lastEventId = def.Id
	endsAt = os.time() + (duration or Events.Duration)
	ReplicatedStorage:SetAttribute("EventId", def.Id)
	ReplicatedStorage:SetAttribute("EventEnds", endsAt)
	for _, player in services.DataService:GetLoadedPlayers() do
		services.StateService:Notify(player, def.Icon .. " " .. def.Name .. " has begun! " .. def.Description, "Event")
		services.TreasureService:UpgradeRolls(player)
	end
	EventService.Changed:Fire(def)
end

function EventService:EndEvent()
	if not active then
		return
	end
	local def = active
	active = nil
	ReplicatedStorage:SetAttribute("EventId", "")
	ReplicatedStorage:SetAttribute("EventEnds", 0)
	for _, player in services.DataService:GetLoadedPlayers() do
		services.StateService:Notify(player, def.Icon .. " " .. def.Name .. " has ended.", "Info")
	end
	EventService.Changed:Fire(nil)
end

function EventService:Init(allServices)
	services = allServices
	ReplicatedStorage:SetAttribute("EventId", "")
	ReplicatedStorage:SetAttribute("EventEnds", 0)
end

function EventService:Start()
	task.wait(Events.FirstDelay)
	while true do
		-- pick a different event than last time
		local choices = {}
		for _, def in Events.List do
			if def.Id ~= lastEventId then
				table.insert(choices, def)
			end
		end
		local pick = choices[math.random(1, #choices)]
		self:StartEvent(pick.Id)
		task.wait(Events.Duration)
		self:EndEvent()
		task.wait(math.max(10, Events.Interval - Events.Duration))
	end
end

return EventService
