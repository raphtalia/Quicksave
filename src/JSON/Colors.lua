local Colors = {}

-- ExtraContent/LuaPackages/AppTempCommon
function Colors.rgbFromHex(hexColor)
	assert(hexColor >= 0 and hexColor <= 0xffffff, "RgbFromHex: Out of range")

	local b = hexColor % 256
	hexColor = (hexColor - b) / 256
	local g = hexColor % 256
	hexColor = (hexColor - g) / 256
	local r = hexColor

	return r, g, b
end

function Colors.color3FromHex(hexColor)
	return Color3.fromRGB(Colors.rgbFromHex(hexColor))
end

function Colors.color3ToHex(color)
    return math.floor(color.R * 255) *256^2 + math.floor(color.G * 255) * 256 + math.floor(color.B * 255)
end

return Colors