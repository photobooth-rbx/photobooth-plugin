--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	size: number,
	falloff: number,
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

	-- `size` is the inward reach in px; `falloff` shapes the curve. The glow is brightest at
	-- the subject edge and decays to 0 by `size` pixels inside. `interiorMask` confines it to
	-- the subject (this effect composites above the base, so anything outside would paint
	-- over empty canvas) with a soft 2px band that anti-aliases the silhouette edge.
	local size = math.max(1e-3, properties.size)
	local falloff = math.max(0.01, properties.falloff)

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local cx, cy = x - minX, y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4

			local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, x, y)
			local inward = math.max(0, -signedDistance)
			local t = math.clamp(inward / size, 0, 1)
			local glowAlpha = (1 - t) ^ falloff

			local interiorMask = 1 - EffectsHelper.smoothStep(-1, 1, signedDistance)
			glowAlpha = glowAlpha * interiorMask

			buffer.writeu8(composed, cj + 0, 255)
			buffer.writeu8(composed, cj + 1, 255)
			buffer.writeu8(composed, cj + 2, 255)
			buffer.writeu8(composed, cj + 3, 255 * glowAlpha)
		end
	end

	return composed
end

return worker
