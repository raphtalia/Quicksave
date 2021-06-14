local Constants = require(script.Parent.Parent.QuicksaveConstants)

local JSON = require(script.Parent.Parent.JSON)

local DataStores = require(script.Parent.DataStores)
local Backups = require(script.Parent.Backups)

local RawSchemes = require(script.Schemes.raw)
local CompressedSchemes = require(script.Schemes.compressed)

local DataLayer = {
	schemes = {
		["raw/1"] = RawSchemes["raw/1"],
		["compressed/1"] = CompressedSchemes["compressed/1"],
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

	local scheme = "raw/1"
	if Constants.COMPRESSION_ENABLED then
		if length > Constants.MINIMUM_LENGTH_TO_COMPRES.Standard then
			scheme = "compressed/1"
		end
	end

	return {
		scheme = scheme;
		data = DataLayer.schemes[scheme].pack(value)
	}
end

function DataLayer.update(collection, key, callback)
	local decompressed

	-- Attempt to update from DataStores
	pcall(DataStores.update, collection, key, function(value)
		decompressed = callback(DataLayer._unpack(value))

		if decompressed ~= nil then
			return DataLayer._pack(decompressed)
		else
			return nil
		end
	end)

	-- Attempt to update from Backups
	if Backups.isBackupsEnabled() then
		pcall(Backups.update, collection, key, function(value)
			local backupsDecompressed = callback(DataLayer._unpack(value))

			if backupsDecompressed ~= nil then
				if decompressed and backupsDecompressed.data.updatedAt > decompressed.data.updatedAt then
					warn(("[Quicksave] Using backup of document %q from collection %q"):format(key, collection))
					decompressed = backupsDecompressed
					return DataLayer._pack(backupsDecompressed)
				else
					return DataLayer._pack(decompressed)
				end
			else
				-- There currently is no backup, copy data from DataStores
				return DataLayer._pack(decompressed)
			end
		end)
	end

	--[[
		Use the backup if DataStore request succeeds in returning a document
		however the document is older than the backup. This is to avoid
		overwriting potentially more recent data on the DataStore if an error
		is thrown.
	]]
	--[[
	local decompressed = dataStoresDecompressed
	if dataStoresDecompressed and backupsDecompressed and backupsDecompressed.data.updatedAt > dataStoresDecompressed.data.updatedAt then
		warn(("[Quicksave] Using backup of document %q from collection %q"):format(key, collection))
		decompressed = backupsDecompressed
	end
	]]

	if decompressed and decompressed.data and decompressed.data.data then
		-- Deserializes Roblox types
		decompressed.data.data = JSON.deserializeTypes(decompressed.data.data)
	end

	return decompressed
end

--[[
function DataLayer.read(collection, key)
	return DataLayer._unpack(DataStores.read(collection, key))
end
]]

return DataLayer