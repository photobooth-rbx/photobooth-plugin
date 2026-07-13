--!optimize 2

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

export type Properties = {
	size: number,
	falloff: number,
	angle: number,
	transparency: number,
	offset: Vector2,
	color: Color3,
}

@native
local function worker(inputs: EffectsRegistry.ImageInputs, properties: Properties, crop: Rect)
	local imgSize = inputs.svf.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y
	local svf = inputs.svf:ReadPixelsBuffer(Vector2.zero, imgSize)

	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local minX, maxX = crop.Min.X, crop.Max.X
	local minY, maxY = crop.Min.Y, crop.Max.Y

	local composed = buffer.create(cropWidth * cropHeight * 4)

	local size = math.max(1e-3, properties.size)
	local falloff = math.max(0.01, properties.falloff)

	local theta = math.rad(properties.angle)
	local lightX = math.cos(theta)
	local lightY = -math.sin(theta)

	-- March toward the light in ~1px steps: the nearer we cross the silhouette boundary, the
	-- closer the lit edge and the darker the shadow at this pixel.
	local steps = math.max(1, math.ceil(size))
	local stepLength = size / steps

	for y = minY + 1, maxY do
		for x = minX + 1, maxX do
			local cx, cy = x - minX, y - minY
			local ci = cx + (cy - 1) * cropWidth
			local cj = (ci - 1) * 4

			local signedDistance = EffectsHelper.readSignedDistance(svf, imgWidth, x, y)
			local interiorMask = 1 - EffectsHelper.smoothStep(-1, 1, signedDistance)

			local shadowAlpha = 0
			if interiorMask > 0 then
				for s = 1, steps do
					local d = s * stepLength
					local sx = math.round(x + lightX * d)
					local sy = math.round(y + lightY * d)

					local outside
					if sx < 1 or sx > imgWidth or sy < 1 or sy > imgHeight then
						-- Stepped off the canvas: nothing there to block light, treat as edge.
						outside = true
					else
						outside = EffectsHelper.readSignedDistance(svf, imgWidth, sx, sy) >= 0
					end

					if outside then
						local t = d / size
						shadowAlpha = (1 - t) ^ falloff
						break
					end
				end
			end

			shadowAlpha = shadowAlpha * interiorMask

			buffer.writeu8(composed, cj + 0, 255)
			buffer.writeu8(composed, cj + 1, 255)
			buffer.writeu8(composed, cj + 2, 255)
			buffer.writeu8(composed, cj + 3, 255 * shadowAlpha)
		end
	end

	return composed
end

return worker
