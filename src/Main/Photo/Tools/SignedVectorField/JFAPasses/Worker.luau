--!optimize 2

@native
local function worker(seedbed: EditableImage, voronoi: EditableImage, crop: Rect, step: number)
	local seedbedSize = voronoi.Size
	local seedbedWidth, seedbedHeight = seedbedSize.X, seedbedSize.Y

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local seedbedRead = seedbed:ReadPixelsBuffer(Vector2.zero, seedbedSize)
	local seedRead = voronoi:ReadPixelsBuffer(Vector2.zero, seedbedSize)

	local seedWrite = buffer.create(cropWidth * cropHeight * 4)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local i = x + (y - 1) * seedbedWidth
			local j = (i - 1) * 4

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

				for ox = -1, 1 do
					if ox == 0 and oy == 0 then
						continue
					end

					local nx = x + ox * step
					if nx < 1 or nx > seedbedWidth then
						continue
					end

					local k = ((ny - 1) * seedbedWidth + nx - 1) * 4
					local nSignedSeedbed = buffer.readi32(seedbedRead, k)
					local nSignedSeed = buffer.readi32(seedRead, k)

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
