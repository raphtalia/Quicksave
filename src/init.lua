local Constants = require(script.QuicksaveConstants)

local t = require(script.t)
local Promise = require(script.Promise)
local Collection = require(script.Collection)
local Error = require(script.Error)
local JSON = require(script.JSON)
local accurateWait = require(script.accurateWait)

local Quicksave = {
	Constants = Constants,

	t = t,
	Promise = Promise,
	Error = Error,
	JSON = JSON,

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
	if Constants.AUTO_CLOSE_DOCUMENTS then
		local promises = {}

		--[[
			Allow for backup requests to finish, Promise.delay() seems to
			infinitely yield for some reason until terminated by the 30
			second deadline.
		]]
		if Constants.BACKUP_HANDLER then
			table.insert(promises, Promise.promisify(accurateWait)(0.5))
		end

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
	end
end)

return Quicksave