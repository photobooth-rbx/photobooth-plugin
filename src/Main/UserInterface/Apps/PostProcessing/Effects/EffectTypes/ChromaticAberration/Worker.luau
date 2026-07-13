--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	strength: number,
	angle: number,
	offset: Vector2,
	transparency: number,
	color: Color3,
}

-- Uniform chromatic aberration: the red and blue channels are sampled from a constant
-- screen-space offset (opposite directions along `angle`), the green channel stays put.
-- The whole subject shifts by the same amount, so fringes are even across the image.
@native
local function worker(inputs: EffectsRegistry.ImageInputs, properties: Properties, crop: Rect)
	local imgSize = inputs.img.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y
	local img = inputs.img:ReadPixelsBuffer(Vector2.zero, imgSize)

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, minY = crop.Min.X, crop.Min.Y

	local composed = buffer.create(cropWidth * cropHeight * 4)

	local theta = math.rad(properties.angle)
	local dx = math.cos(theta) * properties.strength
	local dy = math.sin(theta) * properties.strength

	for y = 0, cropHeight - 1 do
		local gy = minY + y
		for x = 0, cropWidth - 1 do
			local gx = minX + x

			local r, _, _, ar = EffectsHelper.sampleBilinearRGBA(img, imgWidth, imgHeight, gx - dx, gy - dy)
			local _, g, _, ag = EffectsHelper.sampleBilinearRGBA(img, imgWidth, imgHeight, gx, gy)
			local _, _, b, ab = EffectsHelper.sampleBilinearRGBA(img, imgWidth, imgHeight, gx + dx, gy + dy)

			local cj = (x + y * cropWidth) * 4
			buffer.writeu8(composed, cj + 0, r)
			buffer.writeu8(composed, cj + 1, g)
			buffer.writeu8(composed, cj + 2, b)
			buffer.writeu8(composed, cj + 3, (ar + ag + ab) / 3)
		end
	end

	return composed
end

return worker
