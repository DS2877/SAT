-- Minimal synchronous signal used to decouple services (no BindableEvent overhead).

local Signal = {}
Signal.__index = Signal

function Signal.new()
	return setmetatable({ _handlers = {} }, Signal)
end

function Signal:Connect(handler)
	local handlers = self._handlers
	table.insert(handlers, handler)
	return {
		Disconnect = function()
			local index = table.find(handlers, handler)
			if index then
				table.remove(handlers, index)
			end
		end,
	}
end

function Signal:Fire(...)
	for _, handler in table.clone(self._handlers) do
		local ok, err = pcall(handler, ...)
		if not ok then
			warn("[Signal] handler error:", err)
		end
	end
end

return Signal
