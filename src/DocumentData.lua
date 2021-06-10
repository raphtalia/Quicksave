local DocumentData = {}
DocumentData.__index = DocumentData

-- TODO: Backups

function DocumentData.new(options)
	return setmetatable({
		isLoaded = false;
		isClosed = false;
		_lockSession = options.lockSession;
		_readOnlyData = options.readOnlyData;
		_collection = options.collection;
		_currentData = nil;
	}, DocumentData)
end

function DocumentData:isClosed()
	return self.isClosed
end

function DocumentData:_load()
	if self._lockSession then
		return self._lockSession:read()
	else
		return self._readOnlyData
	end
end

function DocumentData:read()
	if self.isLoaded == false then
		local newData = self:_load()

		if newData == nil then
			newData = self._collection.defaultData or {}
		end

		assert(self._collection:validateData(newData))

		self._currentData = newData
		self.isLoaded = true
	end

	return self._currentData
end

function DocumentData:write(value)
	if self._lockSession == nil then
		error("Can't write to a readonly DocumentData")
	end

	self._currentData = value
end

function DocumentData:save()
	if self._lockSession == nil then
		error("Can't save on a readonly DocumentData")
	end

	self._lockSession:write(self._currentData)
end

function DocumentData:close()
	self.isClosed = true

	if self._lockSession then
		self._lockSession:unlockWithFinalData(self._currentData)
	end
end

return DocumentData