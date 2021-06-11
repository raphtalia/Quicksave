local t = require(script.t)
local Promise = require(script.Promise)
local Collection = require(script.Collection)
local Error = require(script.Error)

local Quicksave = {
	t = t;
	Promise = Promise;
	Error = Error;

	_collections = {};
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
		for _,document in ipairs(collection:getActiveDocuments()) do
			table.insert(promises, document:close())
		end
	end

	Promise.all(promises):awaitStatus()
end)

return Quicksave