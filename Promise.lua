-- Promise.lua

-- Safely runs asynchrous steps in a straight line rather than nested callbacks

local Promise = {}
Promise.__index = Promise

function Promise.new(executor)
	local self = setmetatable({
		_status = "pending", -- "pending", "fulfilled" or "rejected"
		_result = nil,
		_callbacks = {},
		_errbacks = {},
		_finallybacks = {}
	}, Promise)
	
	local function resolve(value)
		if self._status == "pending" then
			self._status = "fulfilled"
			self._result = value
			
			for _, cb in pairs(self._callbacks) do
				cb(value)
			end
			for _, fb in pairs(self._finallybacks) do
				fb()
			end
		end
	end
	
	local function reject(reason)
		if self._status == "pending" then
			self._status = "rejected"
			self._result = reason
		end
		
		for _, eb in pairs(self._errbacks) do
			eb(reason)
		end
		for _, fb in pairs(self._finallybacks) do
			fb()
		end
	end
	
	task.spawn(function()
		executor(resolve,reject)
	end)
	
	
	return self
end


function Promise:Then(callback)
	return Promise.new(function(resolve, reject)
		local function handle(value)
			local success, result = pcall(callback, value)
			
			if success then
				resolve(result) 
			else
				reject(result) 
			end
		end
		
		local function handleRejected(reason)
			reject(reason)
		end
		
		if self._status == "fulfilled" then
			handle(self._result)
		elseif self._status == "rejected" then
			handleRejected(self._result)
		else
			table.insert(self._callbacks, handle)
			table.insert(self._errbacks, handleRejected)
		end
	end)
end


function Promise:Finally(callback)
	return Promise.new(function(resolve,reject)
		local function runFinally()
			local success, result = pcall(callback)
			
			if success then
				if self._status == "fulfilled" then
					resolve(result) 
				else
					reject(result) 
				end
			else
				reject(result) 
			end
		end
		
		if self._status ~= "pending" then
			runFinally()
		else
			table.insert(self._finallybacks, runFinally)
		end
		
	end)
end


function Promise:Catch(callback)
	return Promise.new(function(resolve,reject)
		local function handleRejected(value)
			local success, result = pcall(callback, value)
			
			if success then
				resolve(result) 
			else
				reject(result) 
			end
		end
		
		if self._status == "rejected" then
			handleRejected(self._result)
		else
			table.insert(self._errbacks, handleRejected)
		end
		
	end)
end




return Promise
