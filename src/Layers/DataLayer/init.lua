local Constants = require(script.Parent.Parent.QuicksaveConstants)
local Events = require(script.Parent.Parent.QuicksaveEvents)

local JSON = require(script.Parent.Parent.JSON)
local DatabaseSource = require(script.Parent.Parent.DatabaseSource)

local PrimaryDB = require(script.Parent.DataStores)
local SecondaryDB = require(script.Parent.Backups)

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

	return JSON.deserialize(DataLayer.schemes[scheme].unpack(value.data)), value.savedAt
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

function DataLayer.update(source, collection, key, callback)
	local isSecondaryDBConfigured = SecondaryDB.isConfigured()
	local primaryDecompressed, primarySavedAt
	local secondaryDecompressed, secondarySavedAt

	local primaryDatabaseSuccess, primaryDatabaseError
	if source == DatabaseSource.All and isSecondaryDBConfigured then
		primaryDatabaseSuccess, primaryDatabaseError = pcall(function()
			local decompressed, savedAt = DataLayer._unpack(PrimaryDB.read(collection, key))
			primaryDecompressed = callback(decompressed)
			primarySavedAt = savedAt
		end)
	elseif source == DatabaseSource.Primary or not isSecondaryDBConfigured then
		primaryDatabaseSuccess, primaryDatabaseError = pcall(PrimaryDB.update, collection, key, function(value)
			primaryDecompressed = callback(DataLayer._unpack(value))

			if primaryDecompressed ~= nil then
				local compressed = DataLayer._pack(primaryDecompressed)
				compressed.savedAt = os.time()
				return compressed
			else
				return nil
			end
		end)
	end

	local secondaryDatabaseSuccess, secondaryDatabaseError
	if isSecondaryDBConfigured then
		if source == DatabaseSource.All then
			secondaryDatabaseSuccess, secondaryDatabaseError = pcall(function()
				local decompressed, savedAt = DataLayer._unpack(SecondaryDB.read(collection, key))
				secondaryDecompressed = callback(decompressed)
				secondarySavedAt = savedAt
			end)
		elseif source == DatabaseSource.Secondary then
			secondaryDatabaseSuccess, secondaryDatabaseError = pcall(SecondaryDB.update, collection, key, function(value)
				secondaryDecompressed = callback(DataLayer._unpack(value))

				if secondaryDecompressed ~= nil then
					local compressed = DataLayer._pack(secondaryDecompressed)
					compressed.savedAt = os.time()
					return compressed
				else
					return nil
				end
			end)
		end
	end

	if primaryDatabaseSuccess == false then
		Events.PrimaryDatabaseError:Fire(collection, key, primaryDatabaseError)
	end
	if secondaryDatabaseSuccess == false then
		warn("[Quicksave] Secondary database is configured but could not be reached.")
		Events.SecondaryDatabaseError:Fire(collection, key, secondaryDatabaseError)
	end
	if not primaryDecompressed and secondaryDecompressed then
		error([[
			[Quicksave] Secondary database returned data but primary database was not reachable.
			Backup will not be used to avoid potentially overwriting primary database.
		]])
	end

	--[[
		When comparing data returned from separate databases the results from
		the primary database are favored.

		If the secondary database returns data with an older createdAt
		timestamp this indicates the database was not reachable at the time and
		DataStores lost data resulting in a new document to be crated, this is
		an unlikely production scenario but is encountered in any offline
		session through MockDataStores.

		If the createdAt timestamps are the same the next property compared is
		savedAt which is the time the data was written to the database. More
		recent timestamps are favored.

		If all properties are identical the backup is likely up-to-date with
		the primary database and the primary database will be used.
	]]
	local decompressed = primaryDecompressed or secondaryDecompressed
	if source == DatabaseSource.All and secondaryDecompressed then
		if primaryDecompressed.data.createdAt > secondaryDecompressed.data.createdAt then
			warn(("[Quicksave] Secondary database returned document %q from collection %q with an older creation date"):format(key, collection))
			decompressed = secondaryDecompressed
		else
			if not primaryDecompressed.data.data and secondaryDecompressed.data.data then
				warn(("[Quicksave] Primary database returned no data, using backup of document %q from collection %q"):format(key, collection))
				decompressed = secondaryDecompressed
			elseif primaryDecompressed.data.data and secondaryDecompressed.data.data and (primarySavedAt or math.huge) < (secondarySavedAt or -math.huge) then
				warn(("[Quicksave] Primary database returned outdated data, using backup of document %q from collection %q"):format(key, collection))
				decompressed = secondaryDecompressed
			end
		end
	end

	if decompressed then
		if source == DatabaseSource.All and isSecondaryDBConfigured then
			local compressed = DataLayer._pack(decompressed)
			compressed.savedAt = os.time()

			pcall(PrimaryDB.write, collection, key, compressed)

			if secondaryDecompressed then
				pcall(SecondaryDB.write, collection, key, compressed)
			end
		end

		if decompressed.data.data then
			-- Deserializes Roblox types
			decompressed.data.data = JSON.deserializeTypes(decompressed.data.data)
		end
	end

	return decompressed
end

--[[
function DataLayer.read(collection, key)
	return DataLayer._unpack(PrimaryDB.read(collection, key))
end
]]

return DataLayer