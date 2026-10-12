--!optimize 2

local function readBand(img: EditableImage, width: number, height: number, top: number, bottom: number)
	local clampedTop = math.max(0, top)
	local clampedBottom = math.min(height, bottom)
	if clampedBottom <= clampedTop then
		return buffer.create(0), clampedTop
	end

	return img:ReadPixelsBuffer(Vector2.new(0, clampedTop), Vector2.new(width, clampedBottom - clampedTop)), clampedTop
end

@native
local function worker(voronoi: EditableImage, crop: Rect, step: number)
	local voronoiSize = voronoi.Size
	local voronoiWidth, voronoiHeight = voronoiSize.X, voronoiSize.Y

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local seedBands: { buffer } = table.create(3)
	local bandTops: { number } = table.create(3)
	for oy = -1, 1 do
		local seedBand, bandTop = readBand(voronoi, voronoiWidth, voronoiHeight, minY + oy * step, maxY + oy * step)
		seedBands[oy + 2] = seedBand
		bandTops[oy + 2] = bandTop
	end

	local seedRead = seedBands[2]

	local seedWrite = buffer.create(cropWidth * cropHeight * 4)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local i = x + (y - 1) * voronoiWidth
			local j = ((y - 1 - minY) * voronoiWidth + x - 1) * 4

			local signedSeed = buffer.readi32(seedRead, j)
			local seedSign = math.sign(signedSeed)
			local sign = if math.abs(signedSeed) == i then seedSign else -seedSign

			local closestSeed = 0
			local closestDistSq = math.huge
			if seedSign == -sign then
				closestSeed = math.abs(signedSeed)
				local sy = math.floor((closestSeed - 1) / voronoiWidth) + 1
				local sx = closestSeed - (sy - 1) * voronoiWidth
				closestDistSq = (sx - x) ^ 2 + (sy - y) ^ 2
			end

			for oy = -1, 1 do
				local ny = y + oy * step
				if ny < 1 or ny > voronoiHeight then
					continue
				end

				local nSeedRead = seedBands[oy + 2]
				local rowOffset = (ny - 1 - bandTops[oy + 2]) * voronoiWidth

				for ox = -1, 1 do
					if ox == 0 and oy == 0 then
						continue
					end

					local nx = x + ox * step
					if nx < 1 or nx > voronoiWidth then
						continue
					end

					local n = (ny - 1) * voronoiWidth + nx
					local nSignedSeed = buffer.readi32(nSeedRead, (rowOffset + nx - 1) * 4)
					local nSeedSign = math.sign(nSignedSeed)
					local nAbsSeed = math.abs(nSignedSeed)
					local nSign = if nAbsSeed == n then nSeedSign else -nSeedSign

					local nSeed = 0
					local snx: number, sny: number
					if nSign == -sign then
						nSeed = n
						snx, sny = nx, ny
					elseif nSeedSign == -sign then
						nSeed = nAbsSeed
						sny = math.floor((nSeed - 1) / voronoiWidth) + 1
						snx = nSeed - (sny - 1) * voronoiWidth
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

			local cx = x - minX
			local cy = y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4
			if closestSeed > 0 then
				buffer.writei32(seedWrite, cj, -sign * closestSeed)
			else
				buffer.writei32(seedWrite, cj, sign * i)
			end
		end
	end

	return seedWrite
end

return worker
