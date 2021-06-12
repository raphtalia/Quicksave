local Constants = require(script.QuicksaveConstants)

local t = require(script.t)
local Promise = require(script.Promise)
local Collection = require(script.Collection)
local Error = require(script.Error)

local Quicksave = {
	Constants = Constants,

	t = t,
	Promise = Promise,
	Error = Error,

	_collections = {},
}

function Quicksave.createCollection(name, options)
	if Quicksave._collections[name] then
		error(("Collection %q already exists"):format(name))
	end

	Quicksave._collections[name] = Collection.new(name, options)

	return Quicksave._collections[name]
end

function Quicksave.getCollection(name)
	return Quicksave._collections[name] or error(("Collection %q hasn't been created yet!"):format(name))
end

game:BindToClose(function()
	local promises = {}

	for _,collection in pairs(Quicksave._collections) do
		for _,document in pairs(collection:getActiveDocuments()) do
			if document:isDirty() then
				--[[
					Check if the document has edits and if it is already in the
					process of saving.
				]]
				if document:isSaving() then
					table.insert(promises, Promise.fromEvent(document.saved))
				else
					if not document:isClosed() then
						table.insert(promises, document:close())
					end
				end
			end
		end
	end

	Promise.all(promises):awaitStatus()
end)

return Quicksave