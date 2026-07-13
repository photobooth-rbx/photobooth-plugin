--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	thickness: number,
	softness: number,
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

	local thickness = properties.thickness
	local softness = properties.softness

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local cx, cy = x - minX, y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4

			local strokeAlpha = 0
			local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, x, y)
			strokeAlpha = 1 - EffectsHelper.smoothStep(thickness - softness, thickness + softness, signedDistance)
			if properties.clipped and signedDistance < -1 then
				strokeAlpha = 0
			end

			buffer.writeu8(composed, cj + 0, 255)
			buffer.writeu8(composed, cj + 1, 255)
			buffer.writeu8(composed, cj + 2, 255)
			buffer.writeu8(composed, cj + 3, 255 * strokeAlpha)
		end
	end

	return composed
end

return worker
