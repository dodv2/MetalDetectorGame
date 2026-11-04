-- Loads game ModuleScripts outside Roblox (for logic tests) using Lune.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local Harness = {}
local cache = {}

local function makeNode(path: string)
	local node = { __path = path }
	return setmetatable(node, {
		__index = function(self, key)
			if key == "Parent" then
				local parent = string.match(path, "^(.*)/[^/]+$")
				return makeNode(parent)
			end
			local child = path .. "/" .. key
			return makeNode(child)
		end,
	})
end

local function load(node)
	local path = node.__path
	if cache[path] then return cache[path] end
	local file = path .. ".lua"
	if not fs.isFile(file) then
		error("module not found: " .. file)
	end
	local env = setmetatable({
		script = node,
		require = function(target) return load(target) end,
		Color3 = roblox.Color3, Vector3 = roblox.Vector3, CFrame = roblox.CFrame,
		Random = { new = function(seed) local r = {}; local s = seed or os.clock()*1000
			function r:NextNumber(a, b) local x = math.random(); if a then return a + (b-a)*x end return x end
			function r:NextInteger(a, b) return math.random(a, b) end
			return r end },
	}, { __index = _G })
	local fn = luau.load(fs.readFile(file), { debugName = file, environment = env })
	local result = fn()
	cache[path] = result
	return result
end

function Harness.require(path: string)
	return load(makeNode(path))
end

return Harness
