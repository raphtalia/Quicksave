local Constants = require(script.Parent.QuicksaveConstants)

local Promise = require(script.Parent.Promise)
local OSModules = require(script.Parent.OSModules)
local AccessLayer = require(script.Parent.Layers.AccessLayer)
local DocumentData = require(script.DocumentData)
local Error = require(script.Parent.Error)
local accurateWait = require(script.Parent.accurateWait)
local stackSkipAssert = require(script.Parent.stackSkipAssert).stackSkipAssert
local validateValue = require(script.validateValue)

local Document = {}
Document.__index = Document

function Document.new(collection, name)
	local document = setmetatable({
		collection = collection,
		name = name,

		saved = OSModules.Event(),
		closed = OSModules.Event(),
		changed = OSModules.Event(),

		_data = nil,
		_isSaving = false,
		_isClosed = false,
	}, Document)

	if Constants.AUTOSAVE_ENABLED then
		--[[
			We start a separate thread on each document to add some randomness
			to the timing to avoid ratelimits.
		]]
		Promise.delay(1):andThenCall(function()
			document = document:readyPromise():expect()

			repeat
				accurateWait(Constants.AUTOSAVE_INTERVAL)
				if document:isDirty()
				and not document:isClosed()
				and not document:isSaving()
				and document:getLastSaveElapsedTime() > Constants.AUTOSAVE_INTERVAL then
					return document:save()
				end
			until document:isClosed()
		end)
	end

	return document
end

function Document:readyPromise()
	if self._readyPromise == nil then
		self._readyPromise = Promise.new(function(resolve, reject)
			self._data = DocumentData.new({
				lockSession = AccessLayer.acquireLockSession(self.collection.name, self.name, self.collection._migrations);
				collection = self.collection;
			})

			local schemaOk, schemaError = self.collection:validateData(self._data:read())

			if not schemaOk then
				reject(Error.new({
					kind = Error.Kind.SchemaValidationFailed,
					error = schemaError,
					context = ("Schema validation failed when loading data in collection %q key %q"):format(
						self.collection.name,
						self.name
					)
				}))
			end

			resolve(self)
		end)
	end

	-- Wrap in Promise.resolve to track unique consumers
	return Promise.resolve(self._readyPromise)
end

function Document:get(key)
	key = tostring(key)

	stackSkipAssert(self.collection:keyExists(key), ("Key %q does not appear in %q's schema."):format(
		key,
		self.collection.name
	))

	return self._data:read()[key]
end

function Document:set(key, value)
	stackSkipAssert(self._isClosed == false, "Attempt to call :set() on a closed Document")

	key = tostring(key)

	stackSkipAssert(validateValue(value))

	stackSkipAssert(self.collection:validateKey(key, value))

	local current = self._data:read()
	local currentValue = current[key]
	if currentValue ~= value then
		current[key] = value
		self._data:write(current)

		self.changed:Fire(key, value, currentValue)
	end
end

function Document:save()
	stackSkipAssert(self._isClosed == false, "Attempt to call :save() on a closed Document")
	stackSkipAssert(Constants.ALLOW_CLEAN_SAVING or self._data.isDirty == true, "Attempt to call :save() on a clean Document")
	stackSkipAssert(self._isSaving == false, "Attempt to call :save() on a saving Document")

	self._isSaving = true

	return Promise.new(function(resolve)
		self._data:save()
		resolve()
	end):finally(function(status)
		local isResolved = status == Promise.Status.Resolved

		self._isSaving = false
		self.saved:Fire(isResolved)
	end)
end

function Document:close()
	stackSkipAssert(self._isClosed == false, "Attempt to call :close() on a closed Document")
	stackSkipAssert(self._isSaving == false, "Attempt to call :close() on a saving Document")

	self._isSaving = true
	self._isClosed = true

	return Promise.new(function(resolve)
		self._data:close()
		resolve()
	end):finally(function(status)
		local isResolved = status == Promise.Status.Resolved

		self._isSaving = false
		self.saved:Fire(isResolved)

		if isResolved then
			self.collection:_removeDocument(self.name)
		end

		-- If closing failed reopen the document
		self._isClosed = isResolved
		self.closed:Fire(isResolved)
	end)
end

function Document:getLastSaveElapsedTime()
	return self._data:getLastWriteElapsedTime()
end

function Document:isLoaded()
	return self._data.isLoaded
end

function Document:isClosed()
	return self._isClosed
end

function Document:isDirty()
	return self._data.isDirty
end

function Document:isSaving()
	return self._isSaving
end

return Document