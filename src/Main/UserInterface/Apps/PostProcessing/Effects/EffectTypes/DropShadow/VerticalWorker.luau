--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsHelper = require(effectsRoot.EffectsHelper)

-- Second leg of the separable box blur, over one vertical column strip. Runs the vertical
-- mean of radius `blur` over the horizontally-blurred coverage in `scratch`, sampling at the
-- shadow offset, and writes the finished shadow (white + coverage alpha). `clipped` keeps it
-- out of the subject's own footprint. The result is a strip rectangle the caller blits into
-- the output at the strip's x-origin.
@native
local function worker(
	scratch: EditableImage,
	svf: EditableImage,
	blur: number,
	offX: number,
	offY: number,
	clipped: boolean,
	crop: Rect
)
	local imgSize = scratch.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y
	local scratchBuffer = scratch:ReadPixelsBuffer(Vector2.zero, imgSize)
	local svfBuffer = if clipped then svf:ReadPixelsBuffer(Vector2.zero, imgSize) else nil

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X

	local composed = buffer.create(cropWidth * cropHeight * 4)

	local radius = math.max(0, math.floor(blur + 0.5))

	-- Column prefix sum of the source column's coverage (index 0 is 0), rebuilt per column.
	local prefix = buffer.create((imgHeight + 1) * 4)

	for x = minX + 1, maxX do
		local cx = x - minX
		local sx = x - offX

		-- A source column off-canvas casts no shadow; leave the strip column transparent.
		if sx < 1 or sx > imgWidth then
			continue
		end

		local running = 0
		buffer.writef32(prefix, 0, 0)
		for y = 1, imgHeight do
			local cov = buffer.readu8(scratchBuffer, ((sx - 1) + (y - 1) * imgWidth) * 4 + 3)
			running += cov
			buffer.writef32(prefix, y * 4, running)
		end

		for y = 1, imgHeight do
			local sy = y - offY
			local cov = 0
			if sy >= 1 and sy <= imgHeight then
				local lo = math.max(1, sy - radius)
				local hi = math.min(imgHeight, sy + radius)
				cov = (buffer.readf32(prefix, hi * 4) - buffer.readf32(prefix, (lo - 1) * 4)) / ((hi - lo + 1) * 255)
			end

			if clipped and cov > 0 and EffectsHelper.readSignedDistance(svfBuffer :: buffer, imgWidth, x, y) < -1 then
				cov = 0
			end

			local cj = ((cx - 1) + (y - 1) * cropWidth) * 4
			buffer.writeu8(composed, cj + 0, 255)
			buffer.writeu8(composed, cj + 1, 255)
			buffer.writeu8(composed, cj + 2, 255)
			buffer.writeu8(composed, cj + 3, 255 * cov)
		end
	end

	return composed
end

return worker
