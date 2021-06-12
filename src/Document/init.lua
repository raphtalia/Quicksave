local AUTOSAVE_INTERVAL = game:GetService("RunService"):IsStudio() and 30 or 5 * 60

local Promise = require(script.Parent.Promise)
local OSModules = require(script.Parent.OSModules)
local AccessLayer = require(script.Parent.Layers.AccessLayer)
local DocumentData = require(script.DocumentData)
local Error = require(script.Parent.Error)
local stackSkipAssert = require(script.Parent.stackSkipAssert).stackSkipAssert

local validateValue = require(script.validateValue)

local Document = {}
Document.__index = Document

function Document.new(collection, name)
	local document = setmetatable({
		collection = collection,
		name = name,
		lastSaved = tick(),

		saved = OSModules.Event(),
		closed = OSModules.Event(),
		changed = OSModules.Event(),

		_data = nil,
		_isSaving = false,
	}, Document)

	--[[
		We start a separate thread on each document to add some randomness
		to the timing to avoid ratelimits.
	]]
	Promise.delay(1):andThenCall(function()
		document = document:readyPromise():expect()

		repeat
			Promise.delay(AUTOSAVE_INTERVAL):andThenCall(function()
				if document.isDirty() and tick() - document.lastSaved > AUTOSAVE_INTERVAL then
					return document:save()
				end
			end):await()
		until document:isClosed()
	end)

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
	stackSkipAssert(self._data.isClosed == false, "Attempt to call :set() on a closed Document")

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
	stackSkipAssert(self._data.isClosed == false, "Attempt to call :save() on a closed Document")

	return Promise.new(function(resolve)
		self._data:save()
		self.lastSaved = tick()
		resolve()
	end):finally(function(status)
		self._isSaving = false
		self.saved:Fire(status)
	end)
end

function Document:close()
	stackSkipAssert(self._data.isClosed == false, "Attempt to call :close() on a closed Document")

	return Promise.new(function(resolve)
		self._data:close()
		self.lastSaved = tick()
		resolve()
	end):finally(function(status)
		self.collection:_removeDocument(self.name)
		self._isSaving = false
		self.saved:Fire(status)

		if status then
			self.closed:Fire()
		end
	end)
end

function Document:isLoaded()
	return self._data.isLoaded
end

function Document:isClosed()
	return self._data.isClosed
end

function Document:isDirty()
	return self._data.isDirty
end

function Document:isSaving()
	return self._isSaving
end

return Document