local RunService = game:GetService("RunService")

local Constants = require(script.Parent.Parent.Parent.QuicksaveConstants)

local Promise = require(script.Parent.Parent.Parent.Promise)
local Error = require(script.Parent.Parent.Parent.Error)
local accurateWait = require(script.Parent.Parent.Parent.accurateWait)

local ThrottleLayer = {
	_queue = {},
}

local budget = Constants.MAX_BACKUP_REQUESTS
local function getBudget()
    return math.min(budget, Constants.MAX_BACKUP_REQUESTS)
end

local function useBudget(n)
    budget = math.clamp(budget - (n or 1), 0, Constants.MAX_BACKUP_REQUESTS)
end

function ThrottleLayer._perform(methodName, collectionName, ...)
	if getBudget() > 0 then
        useBudget(1)
		return Constants.BACKUP_HANDLER(methodName, collectionName, ...)
	end

	if ThrottleLayer._queue[methodName] == nil then
		ThrottleLayer._queue[methodName] = {}

		coroutine.wrap(function()
			RunService.Heartbeat:Wait()
			while #ThrottleLayer._queue[methodName] > 0 do
				local request = table.remove(ThrottleLayer._queue[methodName], 1)

				while getBudget() == 0 do
					RunService.Heartbeat:Wait()
				end

                useBudget(1)
				local ok, result = pcall(Constants.BACKUP_HANDLER, unpack(request.args))
				if ok then
					request.resolve(result)
				else
					request.reject(Error.new({
						kind = Error.Kind.BackupError,
						error = result
					}))
				end
			end

			ThrottleLayer._queue[methodName] = nil
		end)()
	end

	local args = { methodName, collectionName, ... }
	local promise = Promise.new(function(resolve, reject)
		table.insert(ThrottleLayer._queue[methodName], {
			args = args,
			resolve = resolve,
			reject = reject
		})
	end)

	return promise:expect()
end

function ThrottleLayer.update(collection, key, callback)
	return ThrottleLayer._perform("UpdateAsync", collection, key, callback)
end

function ThrottleLayer.read(collection, key)
	return ThrottleLayer._perform("GetAsync", collection, key)
end

--[[
function ThrottleLayer.write(collection, key, value)
	return ThrottleLayer._perform("SetAsync", collection, key, value)
end

function ThrottleLayer.remove(collection, key)
	return ThrottleLayer._perform("RemoveAsync", collection, key)
end
]]

coroutine.wrap(function()
    while true do
        accurateWait(60)
        budget = Constants.MAX_BACKUP_REQUESTS
    end
end)()

return ThrottleLayer