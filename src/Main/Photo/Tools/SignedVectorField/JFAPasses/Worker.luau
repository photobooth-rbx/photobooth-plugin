--!optimize 2

-- Reads the full-width rows (top, bottom] clamped to the image, returning the buffer and its 0-based top row.
-- Neighbour lookups only ever land on rows y - step, y, and y + step, so each worker only needs three
-- crop-height bands instead of the entire image.
local function readBand(img: EditableImage, width: number, height: number, top: number, bottom: number)
	local clampedTop = math.max(0, top)
	local clampedBottom = math.min(height, bottom)
	if clampedBottom <= clampedTop then
		return buffer.create(0), clampedTop
	end

	return img:ReadPixelsBuffer(Vector2.new(0, clampedTop), Vector2.new(width, clampedBottom - clampedTop)), clampedTop
end

@native
local function worker(seedbed: EditableImage, voronoi: EditableImage, crop: Rect, step: number)
	local seedbedSize = voronoi.Size
	local seedbedWidth, seedbedHeight = seedbedSize.X, seedbedSize.Y

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	-- indexed by oy + 2
	local seedbedBands: { buffer } = table.create(3)
	local seedBands: { buffer } = table.create(3)
	local bandTops: { number } = table.create(3)
	for oy = -1, 1 do
		local top, bottom = minY + oy * step, maxY + oy * step
		local seedbedBand, bandTop = readBand(seedbed, seedbedWidth, seedbedHeight, top, bottom)
		local seedBand = readBand(voronoi, seedbedWidth, seedbedHeight, top, bottom)
		seedbedBands[oy + 2] = seedbedBand
		seedBands[oy + 2] = seedBand
		bandTops[oy + 2] = bandTop
	end

	local seedbedRead = seedbedBands[2]
	local seedRead = seedBands[2]

	local seedWrite = buffer.create(cropWidth * cropHeight * 4)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local j = ((y - 1 - minY) * seedbedWidth + x - 1) * 4

			local signedSeedbedSeed = buffer.readi32(seedbedRead, j)
			local signedSeed = buffer.readi32(seedRead, j)
			local sign = math.sign(signedSeedbedSeed)

			local closestSeed = math.abs(signedSeed)
			if math.sign(signedSeed) == sign then
				closestSeed = 0
			end

			local closestDistSq = math.huge
			if closestSeed > 0 then
				local sy = math.floor((closestSeed - 1) / seedbedWidth) + 1
				local sx = closestSeed - (sy - 1) * seedbedWidth
				closestDistSq = (sx - x) ^ 2 + (sy - y) ^ 2
			end

			for oy = -1, 1 do
				local ny = y + oy * step
				if ny < 1 or ny > seedbedHeight then
					continue
				end

				local nSeedbedRead = seedbedBands[oy + 2]
				local nSeedRead = seedBands[oy + 2]
				local rowOffset = (ny - 1 - bandTops[oy + 2]) * seedbedWidth

				for ox = -1, 1 do
					if ox == 0 and oy == 0 then
						continue
					end

					local nx = x + ox * step
					if nx < 1 or nx > seedbedWidth then
						continue
					end

					local k = (rowOffset + nx - 1) * 4
					local nSignedSeedbed = buffer.readi32(nSeedbedRead, k)
					local nSignedSeed = buffer.readi32(nSeedRead, k)

					local nSeed = 0
					local snx: number, sny: number
					if math.sign(nSignedSeedbed) == -sign then
						nSeed = math.abs(nSignedSeedbed)
						snx, sny = nx, ny
					elseif math.sign(nSignedSeed) == -sign then
						nSeed = math.abs(nSignedSeed)
						sny = math.floor((nSeed - 1) / seedbedWidth) + 1
						snx = nSeed - (sny - 1) * seedbedWidth
					end

					if nSeed > 0 then
						local distSq = (snx - x) ^ 2 + (sny - y) ^ 2
						if distSq < closestDistSq then
							closestDistSq = distSq
							closestSeed = nSeed
						end
					end
				end
			end

			if closestSeed > 0 then
				local cx = x - minX
				local cy = y - minY
				local ci = cx + (cy - 1) * cropWidth
				local cj = (ci - 1) * 4
				buffer.writei32(seedWrite, cj, -sign * closestSeed)
			end
		end
	end

	return seedWrite
end

return worker
