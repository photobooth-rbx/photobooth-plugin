local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Types = require(postProcessingRoot.Controller.LayerComposer.Types)

export type Lut = Types.Lut

local CubeLut = {}
local idCounter = 0

function CubeLut.parse(text: string, name: string): (Lut?, string?)
	local size: number? = nil
	local domainMin = Vector3.zero
	local domainMax = Vector3.one

	local data: buffer? = nil
	local written = 0

	for line in string.gmatch(text, "[^\r\n]+") do
		local trimmed = string.gsub(line, "#.*$", "")
		trimmed = string.match(trimmed, "^%s*(.-)%s*$") or ""
		if trimmed == "" then
			continue
		end

		local tokens = {}
		for token in string.gmatch(trimmed, "%S+") do
			table.insert(tokens, token)
		end

		local keyword = string.upper(tokens[1])
		if keyword == "TITLE" then
			continue
		elseif keyword == "LUT_1D_SIZE" then
			return nil, "1D .cube LUTs are not supported (use a 3D LUT)."
		elseif keyword == "LUT_3D_SIZE" then
			local n = tonumber(tokens[2])
			if not n or n < 2 or n % 1 ~= 0 then
				return nil, "Invalid LUT_3D_SIZE."
			end
			size = n
			data = buffer.create(n * n * n * 3 * 4)
		elseif keyword == "DOMAIN_MIN" then
			local r, g, b = tonumber(tokens[2]), tonumber(tokens[3]), tonumber(tokens[4])
			if not (r and g and b) then
				return nil, "Invalid DOMAIN_MIN."
			end
			domainMin = Vector3.new(r, g, b)
		elseif keyword == "DOMAIN_MAX" then
			local r, g, b = tonumber(tokens[2]), tonumber(tokens[3]), tonumber(tokens[4])
			if not (r and g and b) then
				return nil, "Invalid DOMAIN_MAX."
			end
			domainMax = Vector3.new(r, g, b)
		else
			local r, g, b = tonumber(tokens[1]), tonumber(tokens[2]), tonumber(tokens[3])
			if not (r and g and b) then
				return nil, `Unrecognized line: "{trimmed}".`
			end
			if not data or not size then
				return nil, "Data appears before LUT_3D_SIZE."
			end

			local expected = size * size * size
			if written >= expected then
				return nil, "More data rows than LUT_3D_SIZE allows."
			end

			local offset = written * 3 * 4
			buffer.writef32(data, offset + 0, r)
			buffer.writef32(data, offset + 4, g)
			buffer.writef32(data, offset + 8, b)
			written += 1
		end
	end

	if not size or not data then
		return nil, "Missing LUT_3D_SIZE."
	end

	local expected = size * size * size
	if written ~= expected then
		return nil, `Expected {expected} data rows but found {written}.`
	end

	idCounter += 1
	local lut: Lut = {
		id = tostring(idCounter),
		name = name,
		size = size,
		data = data,
		domainMin = domainMin,
		domainMax = domainMax,
	}

	return lut, nil
end

return CubeLut
