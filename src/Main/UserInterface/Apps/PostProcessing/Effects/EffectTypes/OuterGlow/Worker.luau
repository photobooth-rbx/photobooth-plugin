--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	size: number,
	falloff: number,
	clipped: boolean,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

@native
local function worker(inputs: EffectsRegistry.ImageInputs, properties: Properties, crop: Rect)
	local imgSize = inputs.svf.Size
	local imgWidth, _imgHeight = imgSize.X, imgSize.Y
	local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local composed = buffer.create(cropWidth * cropHeight * 4)

	-- `size` is the outward reach in px; `falloff` shapes the curve (>1 concentrates the
	-- glow near the edge, <1 spreads it). Alpha is 1 at the edge and decays to 0 at `size`.
	local size = math.max(1e-3, properties.size)
	local falloff = math.max(0.01, properties.falloff)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local cx, cy = x - minX, y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4

			local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, x, y)
			local outward = math.max(0, signedDistance)
			local t = math.clamp(outward / size, 0, 1)
			local glowAlpha = (1 - t) ^ falloff

			-- Keep the glow out of the subject's own footprint when clipped.
			if properties.clipped and signedDistance < -1 then
				glowAlpha = 0
			end

			buffer.writeu8(composed, cj + 0, 255)
			buffer.writeu8(composed, cj + 1, 255)
			buffer.writeu8(composed, cj + 2, 255)
			buffer.writeu8(composed, cj + 3, 255 * glowAlpha)
		end
	end

	return composed
end

return worker
