--[[
	SoundController
	Plays UI / detector sounds using Roblox's built-in sound files (no uploads needed).
	Every sound has a visual counterpart, so the game is fully playable with sound off.

	Ambience (Update 17): three soft looping layers - sea, air and life - that crossfade to each
	beach's own mix (gentle surf at Starting Beach, crashing waves and wind at Rocky Shore, gulls
	and distant voices on the Pier...). Uses Roblox's own public-domain audio library; a layer
	whose sound can't load simply stays silent. Off with the Sound setting, like everything else.
]]

local SoundService = game:GetService("SoundService")

local Sound = {}

local controllers

local SOUNDS = {
	Beep = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.5 },
	Click = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.5 },
	Dig = { Id = "rbxasset://sounds/action_footsteps_plastic.mp3", Volume = 0.9 },
	Reward = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.7 },
	Error = { Id = "rbxasset://sounds/clickfast.wav", Volume = 0.4 },
	LevelUp = { Id = "rbxasset://sounds/electronicpingshort.wav", Volume = 0.8 },
}

local templates: { [string]: Sound } = {}

-- Ambient loops (Roblox-uploaded library audio, free to use in any experience)
-- (all from Roblox's licensed "Pro Sound Effects" library in the Creator Store; checked to load)
local AMBIENT_IDS = {
	Surf = "rbxassetid://9120621776", -- Waves Rolling 2: distant ocean rolling onto the coast
	Waves = "rbxassetid://9119676058", -- Surf, waves crashing close by
	Wind = "rbxassetid://9114057128", -- light, whistling gusts
	Gulls = "rbxassetid://9112870701", -- seagulls flying overhead, distant
	Crowd = "rbxassetid://9112747323", -- beach promenade: distant surf, people passing by
	Jungle = "rbxassetid://9112805592", -- jungle birds and cicadas
	Dock = "rbxassetid://9120571336", -- calm water lapping against a dock
	Harbor = "rbxassetid://9112792352", -- harbour life: gulls, distant horns and engines
}
-- Each place's mix: [layer] = { sound, volume }
local MIX = {
	Pier = { Sea = { "Dock", 0.35 }, Air = { "Wind", 0.08 }, Life = { "Harbor", 0.18 } },
	StartingBeach = { Sea = { "Surf", 0.35 }, Air = { "Wind", 0.1 }, Life = { "Crowd", 0.12 } },
	RockyShore = { Sea = { "Waves", 0.45 }, Air = { "Wind", 0.25 }, Life = { "Gulls", 0.18 } },
	TropicalIsland = { Sea = { "Surf", 0.3 }, Air = { "Wind", 0.06 }, Life = { "Jungle", 0.2 } },
	AbandonedPier = { Sea = { "Dock", 0.3 }, Air = { "Wind", 0.22 }, Life = { "Gulls", 0.1 } },
	ShipwreckCoast = { Sea = { "Waves", 0.5 }, Air = { "Wind", 0.3 }, Life = { "Gulls", 0.06 } },
	AncientRuins = { Sea = { "Surf", 0.22 }, Air = { "Wind", 0.2 }, Life = { "Jungle", 0.06 } },
	SecretIsland = { Sea = { "Surf", 0.3 }, Air = { "Wind", 0.12 }, Life = { "Jungle", 0.14 } },
}
local layers: { [string]: Sound } = {}
local currentMix = ""

local function settings()
	local data = controllers.State.Data
	return if data then data.Settings else nil
end

function Sound:Play(name: string, pitch: number?, volumeScale: number?)
	local current = settings()
	if current and current.Sound == false then
		return
	end
	local template = templates[name]
	if not template then
		return
	end
	local sound = template:Clone()
	sound.PlaybackSpeed = pitch or 1
	local volume = template.Volume * (volumeScale or 1)
	if name == "Beep" and current then
		volume *= (current.BeepVolume or 0.6) / 0.6
	end
	sound.Volume = volume
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	task.delay(5, function()
		if sound.Parent then
			sound:Destroy()
		end
	end)
end

-- A short rising chord, higher for rarer finds
function Sound:Chime(tier: number)
	local base = 0.7 + tier * 0.06
	for index, step in { 1, 1.26, 1.5, 2 } do
		if index > 2 + math.ceil(tier / 3) then
			break
		end
		task.delay((index - 1) * 0.09, function()
			self:Play("Reward", base * step)
		end)
	end
end

-- Crossfade the ambient layers to a place's mix ("Pier" or a zone id)
function Sound:SetAmbience(place: string?)
	local current = settings()
	local enabled = not (current and current.Sound == false)
	local mix = MIX[place or "Pier"] or MIX.Pier
	local key = (place or "Pier") .. tostring(enabled)
	if key == currentMix then
		return
	end
	currentMix = key
	for _, layerName in { "Sea", "Air", "Life" } do
		local layer = layers[layerName]
		local entry = mix[layerName]
		local id = entry and AMBIENT_IDS[entry[1]] or ""
		local goal = if enabled and id ~= "" then entry[2] else 0
		if id ~= "" and layer.SoundId ~= id then
			-- fade out, swap, fade in
			local fade = SoundService:FindFirstChild("AmbienceFade")
			task.spawn(function()
				local start = layer.Volume
				for i = 1, 10 do
					layer.Volume = start * (1 - i / 10)
					task.wait(0.08)
				end
				layer.SoundId = id
				if not layer.IsPlaying then
					layer:Play()
				end
				for i = 1, 20 do
					layer.Volume = goal * i / 20
					task.wait(0.08)
				end
			end)
			local _ = fade
		else
			task.spawn(function()
				local start = layer.Volume
				for i = 1, 20 do
					layer.Volume = start + (goal - start) * i / 20
					task.wait(0.08)
				end
			end)
		end
	end
end

function Sound:Start()
	for _, layerName in { "Sea", "Air", "Life" } do
		local layer = Instance.new("Sound")
		layer.Name = "Ambience" .. layerName
		layer.Looped = true
		layer.Volume = 0
		layer.Parent = SoundService
		layers[layerName] = layer
	end
	controllers.State:OnChange(function(data)
		self:SetAmbience(data.CurrentZone)
	end)
end

function Sound:Init(all)
	controllers = all
	for name, info in SOUNDS do
		local sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = info.Id
		sound.Volume = info.Volume
		templates[name] = sound
	end
	all.UIKit = require(script.Parent.Parent.UI.UIKit)
	all.UIKit.ClickSound = function()
		self:Play("Click", 1.1, 0.8)
	end
end

return Sound
