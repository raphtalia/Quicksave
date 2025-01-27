local DatabaseSource = require(script.Parent.Parent.DatabaseSource)
local copyDeep = require(script.Parent.copyDeep)

local DocumentData = {}
DocumentData.__index = DocumentData

function DocumentData.new(options)
	return setmetatable({
		isLoaded = false,
		isDirty = false,

		_lockSession = options.lockSession,
		_readOnlyData = options.readOnlyData,
		_collection = options.collection,
		_currentData = nil,
	}, DocumentData)
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
			local defaultData = self._collection.defaultData
			newData = defaultData and copyDeep(defaultData) or {}
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
	self.isDirty = true
end

function DocumentData:save(source)
	source = source or DatabaseSource.Primary
	if self._lockSession == nil then
		error("Can't save on a readonly DocumentData")
	end

	self._lockSession:write(self._currentData, source)
	if source == DatabaseSource.All or source == DatabaseSource.Primary then
		self.isDirty = false
	end
end

function DocumentData:close()
	if self._lockSession then
		self._lockSession:unlockWithFinalData(self._currentData)
	end
end

function DocumentData:getLastWriteElapsedTime()
	return self._lockSession:getLastWriteElapsedTime()
end

return DocumentData