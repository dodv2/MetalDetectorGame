--[[
	Format
	Number / text helpers shared by UI and server messages.
]]

local GameConfig = require(script.Parent.Config.GameConfig)

local Format = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx" }

local function trimZeros(text: string): string
	if string.find(text, "%.") then
		text = (string.gsub(text, "0+$", ""))
		text = (string.gsub(text, "%.$", ""))
	end
	return text
end

-- 1234 -> "1.23K", 5600000 -> "5.6M"
function Format.Number(n: number?): string
	local value = n or 0
	local negative = value < 0
	value = math.abs(value)
	if value < 1000 then
		local text = if value == math.floor(value) then tostring(value) else trimZeros(string.format("%.1f", value))
		return (if negative then "-" else "") .. text
	end
	local index = 1
	while value >= 1000 and index < #SUFFIXES do
		value /= 1000
		index += 1
	end
	local text
	if value >= 100 then
		text = string.format("%.0f", value)
	elseif value >= 10 then
		text = trimZeros(string.format("%.1f", value))
	else
		text = trimZeros(string.format("%.2f", value))
	end
	return (if negative then "-" else "") .. text .. SUFFIXES[index]
end

-- 1234567 -> "1,234,567"
function Format.Commas(n: number?): string
	local text = tostring(math.floor(n or 0))
	local result = text
	while true do
		local replaced, count = string.gsub(result, "^(-?%d+)(%d%d%d)", "%1,%2")
		result = replaced
		if count == 0 then
			break
		end
	end
	return result
end

function Format.Cash(n: number?): string
	return "$" .. Format.Number(n)
end

-- 0.125 -> "+12.5%"
function Format.Percent(x: number?, noPlus: boolean?): string
	local value = (x or 0) * 100
	local text
	if value >= 100 then
		text = string.format("%.0f%%", value)
	elseif value >= 10 then
		text = trimZeros(string.format("%.1f", value)) .. "%"
	else
		text = trimZeros(string.format("%.2f", value)) .. "%"
	end
	return (if noPlus then "" else "+") .. text
end

-- Luck is additive: internal 0.125 -> "+12.5 Luck" (1 Luck point = +1% rare-find luck)
function Format.LuckNumber(x: number?): string
	local points = (x or 0) * 100
	local text
	if math.abs(points) >= 10 then
		text = tostring(math.floor(points + 0.5))
	else
		text = trimZeros(string.format("%.1f", points))
	end
	return (if points >= 0 then "+" else "") .. text
end

function Format.Luck(x: number?): string
	return Format.LuckNumber(x) .. " Luck"
end

-- 1.5 -> "x1.50"
function Format.Mult(x: number?): string
	return string.format("x%.2f", x or 1)
end

function Format.Time(seconds: number?): string
	local s = math.max(0, math.floor(seconds or 0))
	if s >= 3600 then
		return string.format("%dh %02dm", s // 3600, (s % 3600) // 60)
	elseif s >= 60 then
		return string.format("%dm %02ds", s // 60, s % 60)
	end
	return string.format("%ds", s)
end

-- Roblox: 1 stud = 0.28 m
function Format.Meters(studs: number?): string
	return string.format("%.1f m", (studs or 0) * GameConfig.StudsToMeters)
end

function Format.Plural(count: number, word: string): string
	return tostring(count) .. " " .. word .. (if count == 1 then "" else "s")
end

return Format
