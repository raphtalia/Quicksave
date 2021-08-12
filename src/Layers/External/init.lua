local Constants = require(script.Parent.Parent.QuicksaveConstants)

local ThrottleLayer = require(script.ThrottleLayer)
local Error = require(script.Parent.Parent.Error)

local ExternalRetryLayer = {}

function ExternalRetryLayer._retry(callback, ...)
	local attempts = 0

    local maxRetries = Constants.EXTERNAL_MAX_RETRIES
	while attempts < maxRetries do
		attempts = attempts + 1

		local ok, value = pcall(callback, ...)

		if ok then
			return value
		end

		if attempts < maxRetries then
			warn(("[Quicksave] Backup operation failed. Retrying...\nError:\n%s"):format(
				tostring(value)
			))
		else
			error(Error.new({
				kind = Error.Kind.ExternalError,
				error = value,
				context = ("Failed after %d retries."):format(maxRetries)
			}))
		end
	end
end

function ExternalRetryLayer.update(...)
	return ExternalRetryLayer._retry(function(...)
		return ThrottleLayer.update(...)
	end, ...)
end

function ExternalRetryLayer.read(...)
	return ExternalRetryLayer._retry(function(...)
		return ThrottleLayer.read(...)
	end, ...)
end

function ExternalRetryLayer.write(...)
	return ExternalRetryLayer._retry(function(...)
		return ThrottleLayer.write(...)
	end, ...)
end

function ExternalRetryLayer.isConfigured()
	return type(Constants.EXTERNAL_DATABASE_HANDLER) == "function"
end

return ExternalRetryLayer