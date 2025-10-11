local Signal = {}
Signal.__index = Signal

function Signal.new()
	local self = setmetatable({}, Signal)
	self._connections = {}
	
	return self
end

function Signal:Wait(duration : number?)
	local running = coroutine.running()
	local currentDelay = nil
	
	if duration then
		currentDelay = task.delay(duration, function(thread)
			task.defer(thread)
		end, running)
	end
	
	self:Once(function(...)
		if currentDelay then
			task.cancel(currentDelay)
		end
		
		task.defer(running, ...)
	end)
	

	return coroutine.yield()
end

function Signal:Once(callback : (...any) -> (...any))	
	local connection
	
	connection = self:Connect(function(...)
		task.spawn(callback, ...)
		connection:Disconnect()
	end)
	
	return connection
end

function Signal:Connect(callback : (...any) -> (...any))
	local signal = self
	local connection = {
		Connected = true,
		Callback = callback
	}
	
	function connection:Disconnect()
		if not self.Connected then return end
		self.Connected = false
		
		for i, conn in ipairs(signal._connections) do
			if conn == self then
				table.remove(signal._connections, i)
				break
			end
		end
		
		self.Callback = nil
		self.Connected = nil
		setmetatable(self, nil)
	end
	
	table.insert(signal._connections, connection)
	return connection
end

function Signal:Fire(...)
	if not self._connections then return end
	for _, conn in ipairs(self._connections) do
		if conn.Connected and conn.Callback then
			task.spawn(conn.Callback, ...)
		end
	end
end

function Signal:Destroy()
	if self._connections then
		for _, conn in ipairs(self._connections) do
			conn:Disconnect()
		end
	end
	
	self._connections = nil
	setmetatable(self, nil)
end


return Signal
