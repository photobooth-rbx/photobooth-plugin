--!optimize 2

@native
local function worker(img: EditableImage, voronoi: EditableImage, crop: Rect)
	local imgWidth = img.Size.X

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local cropPixels = cropWidth * cropHeight

	local cropWrite = img:ReadPixelsBuffer(crop.Min, cropSize)
	local voronoiRead = voronoi:ReadPixelsBuffer(crop.Min, cropSize)

	local sXMin, sYMin = math.huge, math.huge
	local sXMax, sYMax = -math.huge, -math.huge
	for ci = 1, cropPixels do
		local cj = (ci - 1) * 4

		local seed = buffer.readi32(voronoiRead, cj)
		if seed <= 0 or buffer.readu8(cropWrite, cj + 3) > 0 then
			continue
		end

		local sy = math.floor((seed - 1) / imgWidth) + 1
		local sx = seed - (sy - 1) * imgWidth

		sXMin = math.min(sXMin, sx)
		sXMax = math.max(sXMax, sx)
		sYMin = math.min(sYMin, sy)
		sYMax = math.max(sYMax, sy)
	end

	if sXMin == math.huge then
		return cropWrite
	end

	local seedWidth = sXMax - sXMin + 1
	local seedRead = img:ReadPixelsBuffer(Vector2.new(sXMin - 1, sYMin - 1), Vector2.new(seedWidth, sYMax - sYMin + 1))

	for ci = 1, cropPixels do
		local cj = (ci - 1) * 4

		local seed = buffer.readi32(voronoiRead, cj)
		if seed <= 0 or buffer.readu8(cropWrite, cj + 3) > 0 then
			continue
		end

		local sy = math.floor((seed - 1) / imgWidth) + 1
		local sx = seed - (sy - 1) * imgWidth

		local k = ((sy - sYMin) * seedWidth + (sx - sXMin)) * 4
		local r = buffer.readu8(seedRead, k + 0)
		local g = buffer.readu8(seedRead, k + 1)
		local b = buffer.readu8(seedRead, k + 2)

		buffer.writeu8(cropWrite, cj + 0, r)
		buffer.writeu8(cropWrite, cj + 1, g)
		buffer.writeu8(cropWrite, cj + 2, b)
	end

	return cropWrite
end

return worker
