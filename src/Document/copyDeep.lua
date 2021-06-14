local function copyDeep(dictionary)
	-- https://github.com/Reselim/Quicksave/commit/b703fc4928c99927409f78900e62b20809b1a06a
	local new = {}

	for key, value in pairs(dictionary) do
		if type(value) == "table" then
			new[key] = copyDeep(value)
		else
			new[key] = value
		end
	end

	return new
end

return copyDeep