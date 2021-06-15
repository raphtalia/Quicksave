local Constants = require(script.Parent.Parent.QuicksaveConstants)

local ThrottleLayer = require(script.ThrottleLayer)
local Error = require(script.Parent.Parent.Error)

local DataStoresRetryLayer = {}

function DataStoresRetryLayer._retry(callback, ...)
	local attempts = 0

	local maxRetries = Constants.DATASTORES_MAX_RETRIES
	while attempts < maxRetries do
		attempts = attempts + 1

		local ok, value = pcall(callback, ...)

		if ok then
			return value
		end

		if attempts < maxRetries then
			warn(("[Quicksave] DataStore operation failed. Retrying...\nError:\n%s"):format(
				tostring(value)
			))
		else
			error(Error.new({
				kind = Error.Kind.DataStoreError,
				error = value,
				context = ("Failed after %d retries."):format(maxRetries)
			}))
		end
	end
end

function DataStoresRetryLayer.update(...)
	return DataStoresRetryLayer._retry(function(...)
		return ThrottleLayer.update(...)
	end, ...)
end

function DataStoresRetryLayer.read(...)
	return DataStoresRetryLayer._retry(function(...)
		return ThrottleLayer.read(...)
	end, ...)
end

function DataStoresRetryLayer.write(...)
	return DataStoresRetryLayer._retry(function(...)
		return ThrottleLayer.write(...)
	end, ...)
end

-- Allows DataStores to be used as secondary database with ease
function DataStoresRetryLayer.isConfigured()
	return true
end

return DataStoresRetryLayer