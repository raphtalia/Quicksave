local Constants = require(script.Parent.Parent.QuicksaveConstants)

local ThrottleLayer = require(script.Parent.ThrottleLayer)
local Error = require(script.Parent.Parent.Error)

local RetryLayer = {}

function RetryLayer._retry(callback, ...)
	local attempts = 0

	while attempts < Constants.MAX_RETRIES do
		attempts = attempts + 1

		local ok, value = pcall(callback, ...)

		if ok then
			return value
		end

		if attempts < Constants.MAX_RETRIES then
			warn(("[Quicksave] DataStore operation failed. Retrying...\nError:\n%s"):format(
				tostring(value)
			))
		else
			error(Error.new({
				kind = Error.Kind.DataStoreError,
				error = value,
				context = ("Failed after %d retries."):format(Constants.MAX_RETRIES)
			}))
		end
	end

end

function RetryLayer.update(...)
	return RetryLayer._retry(function(...)
		return ThrottleLayer.update(...)
	end, ...)
end

function RetryLayer.read(...)
	return RetryLayer._retry(function(...)
		return ThrottleLayer.read(...)
	end, ...)
end

return RetryLayer