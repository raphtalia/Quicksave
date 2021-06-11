local SUPPORTED_TYPES = {
    "string",
    "boolean",
    "number",

    "Vector2",
    "Vector3",
    "CFrame",
    "Color3",
    "BrickColor",
    "ColorSequence",
    "ColorSequenceKeypoint",
    "NumberRange",
    "NumberSequence",
    "NumberSequenceKeypoint",
    "UDim",
    "UDim2",
    "EnumItem",
}

function validateValue(value)
    if type(value) == "table" then
        if getmetatable(value) then
            return false, "Tables with metatables are not supported"
        else
            for _,v in pairs(value) do
                if not validateValue(v) then
                    return false, "Table contains unsupported data"
                end
            end
        end
    else
        local type = typeof(value)
        if not table.find(SUPPORTED_TYPES, type) then
            return false, ("Datatype %q is not supported"):format(type)
        end
    end

    return true
end

return validateValue