--[[
	Signal
	A tiny event object used by both server services and client controllers.

	local s = Signal.new()
	local conn = s:Connect(function(a, b) print(a, b) end)
	s:Fire(1, 2)
	conn:Disconnect()
]]

local Signal = {}
Signal.__index = Signal

export type Connection = { Disconnect: (self: any) -> () }

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(fn: (...any) -> ())
	local handler = { fn = fn, connected = true }
	table.insert(self._handlers, handler)
	local signal = self
	return {
		Disconnect = function()
			handler.connected = false
			local index = table.find(signal._handlers, handler)
			if index then
				table.remove(signal._handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		if handler.connected then
			task.spawn(handler.fn, ...)
		end
	end
end

function Signal:Wait()
	local thread = coroutine.running()
	local connection
	connection = self:Connect(function(...)
		connection.Disconnect()
		task.spawn(thread, ...)
	end)
	return coroutine.yield()
end

return Signal
