local Codecs = require(script.Parent.Parent.Parent.Parent.RbxUtils).Codecs

return {
	["compressed/1"] = {
		pack = function(value)
			return Codecs.LZW.compress(value)
		end,
		unpack = function(value)
			return Codecs.LZW.decompress(value);
		end,
	},
	["compressed/2"] = {
		pack = function(value)
			return Codecs.Huffman.compress(Codecs.LZW.compress(value))
		end,
		unpack = function(value)
			return Codecs.LZW.decompress(Codecs.Huffman.decompress(value))
		end,
	}
}