local JSON = require(script.Parent.Parent.RbxUtils).JSON

local RetryLayer = require(script.Parent.RetryLayer)

local RawSchemes = require(script.Schemes.raw)
local CompressedSchemes = require(script.Schemes.compressed)

local MINIMUM_COMPRESS_LENGTHS = {
	Standard = 1000,
	High = 100000,
}

local DataLayer = {
	schemes = {
		["raw/1"] = RawSchemes["raw/1"],
		["compressed/1"] = CompressedSchemes["compressed/1"],
		["compressed/2"] = CompressedSchemes["compressed/2"],
	}
}

function DataLayer._unpack(value)
	if value == nil then
		return nil
	end

	local scheme = value.scheme

	if not DataLayer.schemes[scheme] then
		error(("Unknown scheme: %q"):format(scheme))
	end

	return JSON.deserialize(DataLayer.schemes[scheme].unpack(value.data))
end

function DataLayer._pack(value)
	value = JSON.serialize(value)
	local length = #value

	local scheme
	if length > MINIMUM_COMPRESS_LENGTHS.High then
		scheme = "compressed/2"
	elseif length > MINIMUM_COMPRESS_LENGTHS.Standard then
		scheme = "compressed/1"
	else
		scheme = "raw/1"
	end

	return {
		scheme = scheme;
		data = DataLayer.schemes[scheme].pack(value)
	}
end

function DataLayer.update(collection, key, callback)
	local decompressed

	RetryLayer.update(collection, key, function(value)
		decompressed = callback(DataLayer._unpack(value))

		if decompressed ~= nil then
			return DataLayer._pack(decompressed)
		else
			return nil
		end
	end)

	if decompressed and decompressed.data and decompressed.data.data then
		-- Deserializes Roblox types
		decompressed.data.data = JSON.deserializeTypes(decompressed.data.data)
	end

	return decompressed
end

function DataLayer.read(collection, key)
	return DataLayer._unpack(RetryLayer.read(collection, key))
end

return DataLayer