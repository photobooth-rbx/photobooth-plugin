--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsHelper = require(effectsRoot.EffectsHelper)

-- First leg of the shadow's separable box blur. Dilates the silhouette off the signed
-- distance field (`spread` places the 50%-coverage contour at that signed distance from the
-- edge, with a 1px anti-aliased band) and runs the horizontal mean of radius `blur` over it.
-- Output coverage is written to the alpha channel; the vertical leg reads it back.
@native
local function worker(svf: EditableImage, spread: number, blur: number, crop: Rect)
	local imgSize = svf.Size
	local imgWidth = imgSize.X
	local svfBuffer = svf:ReadPixelsBuffer(Vector2.zero, imgSize)

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local composed = buffer.create(cropWidth * cropHeight * 4)

	local radius = math.max(0, math.floor(blur + 0.5))

	-- Row prefix sum of the dilated mask (index 0 is 0), rebuilt per row and reused for the
	-- O(1) box mean.
	local prefix = buffer.create((imgWidth + 1) * 4)

	for y = minY + 1, maxY do
		local running = 0
		buffer.writef32(prefix, 0, 0)
		for x = 1, imgWidth do
			local signedDistance = EffectsHelper.readSignedDistance(svfBuffer, imgWidth, x, y)
			local mask = math.clamp(spread - signedDistance + 0.5, 0, 1)
			running += mask
			buffer.writef32(prefix, x * 4, running)
		end

		for x = minX + 1, maxX do
			local lo = math.max(1, x - radius)
			local hi = math.min(imgWidth, x + radius)
			local mean = (buffer.readf32(prefix, hi * 4) - buffer.readf32(prefix, (lo - 1) * 4)) / (hi - lo + 1)

			local cx, cy = x - minX, y - minY
			local cj = ((cx - 1) + (cy - 1) * cropWidth) * 4
			buffer.writeu8(composed, cj + 3, 255 * mean)
		end
	end

	return composed
end

return worker
