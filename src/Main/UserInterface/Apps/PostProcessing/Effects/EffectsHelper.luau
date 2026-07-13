local EffectsHelper = {}

function EffectsHelper.smoothStep(edge0: number, edge1: number, x: number)
	local t = math.clamp((x - edge0) / (edge1 - edge0), 0, 1)
	return t * t * (3.0 - 2.0 * t)
end

function EffectsHelper.sampleBilinearRGBA(img: buffer, width: number, height: number, fx: number, fy: number)
	local x0 = math.floor(fx)
	local y0 = math.floor(fy)
	local tx = fx - x0
	local ty = fy - y0

	local pr, pg, pb, pa = 0, 0, 0, 0
	for dy = 0, 1 do
		local wy = if dy == 0 then 1 - ty else ty
		local sy = y0 + dy
		for dx = 0, 1 do
			local wx = if dx == 0 then 1 - tx else tx
			local sx = x0 + dx
			local w = wx * wy
			if w > 0 and sx >= 0 and sx < width and sy >= 0 and sy < height then
				local j = (sx + sy * width) * 4
				local a = buffer.readu8(img, j + 3) / 255
				pr += buffer.readu8(img, j + 0) * a * w
				pg += buffer.readu8(img, j + 1) * a * w
				pb += buffer.readu8(img, j + 2) * a * w
				pa += a * w
			end
		end
	end

	local a, b, c, d = 0, 0, 0, 0
	if pa > 0 then
		a, b, c, d = pr / pa, pg / pa, pb / pa, pa * 255
	end

	return a, b, c, d
end

function EffectsHelper.readSignedDistance(svf: buffer, width: number, x: number, y: number)
	local i = x + (y - 1) * width
	local j = (i - 1) * 4

	local signedPixelIndex = buffer.readi32(svf, j)
	local pixelIndex = math.abs(signedPixelIndex)
	local sign = math.sign(signedPixelIndex)

	local ny = math.floor((pixelIndex - 1) / width) + 1
	local nx = pixelIndex - (ny - 1) * width
	local ox = math.max(0, math.abs(x - nx) - 0.5)
	local oy = math.max(0, math.abs(y - ny) - 0.5)
	local distance = math.sqrt(ox * ox + oy * oy)

	return distance * sign
end

function EffectsHelper.readIntegral(integral: buffer, width: number, height: number, x: number, y: number): number
	local cx = math.min(x, width)
	local cy = math.min(y, height)
	if cx > 0 and cy > 0 then
		return buffer.readu32(integral, ((cx - 1) + (cy - 1) * width) * 4)
	end
	return 0
end

function EffectsHelper.boxAverageAlpha(
	integral: buffer,
	width: number,
	height: number,
	x: number,
	y: number,
	radius: number
)
	local minX, minY = x - radius, y - radius
	local maxX, maxY = x + radius, y + radius

	local sum = EffectsHelper.readIntegral(integral, width, height, maxX, maxY)
		- EffectsHelper.readIntegral(integral, width, height, minX - 1, maxY)
		- EffectsHelper.readIntegral(integral, width, height, maxX, minY - 1)
		+ EffectsHelper.readIntegral(integral, width, height, minX - 1, minY - 1)

	local cMinX = math.clamp(minX, 1, width)
	local cMaxX = math.clamp(maxX, 1, width)
	local cMinY = math.clamp(minY, 1, height)
	local cMaxY = math.clamp(maxY, 1, height)
	local count = (cMaxX - cMinX + 1) * (cMaxY - cMinY + 1)

	return sum / (count * 255)
end

return EffectsHelper
