local TYPE_MARKER = "_T"

local HttpService = game:GetService("HttpService")

local Colors = require(script.Colors)

local JSON = {}

function JSON.serializeTypes(data, typeMarker)
    typeMarker = typeMarker or TYPE_MARKER

    for i,v in pairs(data) do
        local type = typeof(v)

        if type == "table" then
            data[i] = JSON.serializeTypes(v, typeMarker)
        elseif type == "Vector2" then
            data[i] = {
                typeMarker,
                1,
                v.X,
                v.Y,
            }
        elseif type == "Vector3" then
            data[i] = {
                typeMarker,
                2,
                v.X,
                v.Y,
                v.Z,
            }
        elseif type == "CFrame" then
            -- This could be optimized to ignore orientation if there is none
            data[i] = {
                typeMarker,
                3,
                v:GetComponents(),
            }
        elseif type == "Color3" then
            data[i] = {
                typeMarker,
                4,
                Colors.color3ToHex(v),
            }
        elseif type == "BrickColor" then
            data[i] = {
                typeMarker,
                5,
                v.Number,
            }
        elseif type == "ColorSequence" then
            data[i] = {
                typeMarker,
                6,
                JSON.serializeTypes(v.Keypoints, typeMarker),
            }
        elseif type == "ColorSequenceKeypoint" then
            data[i] = {
                typeMarker,
                7,
                v.Time,
                Colors.color3ToHex(v.Value, typeMarker),
            }
        elseif type == "NumberRange" then
            data[i] = {
                typeMarker,
                8,
                v.Min,
                v.Max,
            }
        elseif type == "NumberSequence" then
            data[i] = {
                typeMarker,
                9,
                JSON.serializeTypes(v.Keypoints, typeMarker),
            }
        elseif type == "NumberSequenceKeypoint" then
            -- This could be optimized to ignore envlope if it is 0
            data[i] = {
                typeMarker,
                10,
                v.Time,
                v.Value,
                v.Envelope,
            }
        elseif type == "UDim" then
            data[i] = {
                typeMarker,
                11,
                v.Scale,
                v.Offset,
            }
        elseif type == "UDim2" then
            data[i] = {
                typeMarker,
                12,
                v.X.Scale,
                v.X.Offset,
                v.Y.Scale,
                v.Y.Offset,
            }
        elseif type == "EnumItem" then
            data[i] = {
                typeMarker,
                13,
                tostring(v.EnumType),
                v.Name,
            }
        end
    end

    return data
end

function JSON.deserializeTypes(data, typeMarker)
    typeMarker = typeMarker or TYPE_MARKER

    for i,v in pairs(data) do
        if type(v) == "table" then
            if v[1] == typeMarker then
                local type = v[2]
                v = {select(3, unpack(v))}
                v = #v == 1 and v[1] or v

                if type == 1 then -- Vector2
                    data[i] = Vector2.new(v[1], v[2])
                elseif type == 2 then -- Vector3
                    data[i] = Vector3.new(v[1], v[2], v[3])
                elseif type == 3 then -- CFrame
                    data[i] = CFrame.new(v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11], v[12])
                elseif type == 4 then -- Color3
                    data[i] = Colors.color3FromHex(v)
                elseif type == 5 then -- BrickColor
                    data[i] = BrickColor.new(v)
                elseif type == 6 then -- ColorSequence
                    data[i] = ColorSequence.new(JSON.deserializeTypes(v, typeMarker))
                elseif type == 7 then -- ColorSequenceKeypoint
                    data[i] = ColorSequenceKeypoint.new(v[1], Colors.color3FromHex(v[2]))
                elseif type == 8 then -- NumberRange
                    data[i] = NumberRange.new(v[1], v[2])
                elseif type == 9 then -- NumberSequence
                    data[i] = NumberSequence.new(JSON.deserializeTypes(v, typeMarker))
                elseif type == 10 then -- NumberSequenceKeypoint
                    data[i] = NumberSequenceKeypoint.new(v[1], v[2], v[3])
                elseif type == 11 then -- UDim
                    data[i] = UDim.new(v[1], v[2])
                elseif type == 12 then -- UDim2
                    data[i] = UDim2.new(v[1], v[2], v[3], v[4])
                elseif type == 13 then
                    data[i] = Enum[v[1]][v[2]]
                end
            else
                data[i] = JSON.deserializeTypes(v, typeMarker)
            end
        end
    end

    return data
end

function JSON.serialize(data, typeMarker)
    return HttpService:JSONEncode(
        JSON.serializeTypes(
            data,
            typeMarker or TYPE_MARKER
        )
    )
end

function JSON.deserialize(data, typeMarker)
    return JSON.deserializeTypes(
        HttpService:JSONDecode(data),
        typeMarker or TYPE_MARKER
    )
end

function JSON.isJSON(str)
    local success = pcall(JSON.deserialize, str)
    return success
end

return JSON