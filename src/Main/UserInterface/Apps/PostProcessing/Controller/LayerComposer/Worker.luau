--!optimize 2

local Types = require(script.Parent.Types)

-- Rec. 601 luma weights, shared by the saturation lerp and the hue-rotation matrix.
local LR, LG, LB = 0.299, 0.587, 0.114

@native
local function sampleLut(
	data: buffer,
	size: number,
	cr: number,
	cg: number,
	cb: number,
	dminR: number,
	dminG: number,
	dminB: number,
	dmaxR: number,
	dmaxG: number,
	dmaxB: number
): (number, number, number)
	local last = size - 1
	local fr = math.clamp((cr - dminR) / (dmaxR - dminR), 0, 1) * last
	local fg = math.clamp((cg - dminG) / (dmaxG - dminG), 0, 1) * last
	local fb = math.clamp((cb - dminB) / (dmaxB - dminB), 0, 1) * last

	local r0, g0, b0 = math.floor(fr), math.floor(fg), math.floor(fb)
	local r1 = math.min(r0 + 1, last)
	local g1 = math.min(g0 + 1, last)
	local b1 = math.min(b0 + 1, last)
	local dr, dg, db = fr - r0, fg - g0, fb - b0

	local outR, outG, outB = 0, 0, 0
	for corner = 0, 7 do
		local ri = if corner % 2 >= 1 then r1 else r0
		local gi = if corner % 4 >= 2 then g1 else g0
		local bi = if corner >= 4 then b1 else b0

		local wr = if corner % 2 >= 1 then dr else 1 - dr
		local wg = if corner % 4 >= 2 then dg else 1 - dg
		local wb = if corner >= 4 then db else 1 - db
		local w = wr * wg * wb

		if w > 0 then
			local j = ((bi * size + gi) * size + ri) * 3 * 4
			outR += buffer.readf32(data, j + 0) * w
			outG += buffer.readf32(data, j + 4) * w
			outB += buffer.readf32(data, j + 8) * w
		end
	end

	return outR, outG, outB
end

@native
local function worker(
	layers: { Types.Layer },
	crop: Rect,
	fullSize: Vector2,
	adjust: Types.Adjustment?,
	lut: Types.Lut?
)
	local cropMin = crop.Min
	local cropSize = crop.Max - crop.Min
	local cropWidth, cropHeight = cropSize.X, cropSize.Y
	local fullWidth, fullHeight = fullSize.X, fullSize.Y
	local composed = buffer.create(cropWidth * cropHeight * 4)

	local layerCount = #layers
	local layerBuffers: { buffer } = table.create(layerCount)
	local layerTops: { number } = table.create(layerCount)
	local layerOffsetXs: { number } = table.create(layerCount)
	local layerOffsetYs: { number } = table.create(layerCount)
	local layerTintRs: { number } = table.create(layerCount)
	local layerTintGs: { number } = table.create(layerCount)
	local layerTintBs: { number } = table.create(layerCount)
	local layerOpacities: { number } = table.create(layerCount)
	for i, layer in layers do
		local offsetX = math.floor(layer.offset.X)
		local offsetY = math.floor(layer.offset.Y)

		local top = math.clamp(cropMin.Y - offsetY, 0, fullHeight)
		local bottom = math.clamp(cropMin.Y + cropHeight - offsetY, 0, fullHeight)

		layerBuffers[i] = if bottom > top
			then layer.editImage:ReadPixelsBuffer(Vector2.new(0, top), Vector2.new(fullWidth, bottom - top))
			else buffer.create(0)
		layerTops[i] = top
		layerOffsetXs[i] = offsetX
		layerOffsetYs[i] = offsetY
		layerTintRs[i] = layer.tintColor.R
		layerTintGs[i] = layer.tintColor.G
		layerTintBs[i] = layer.tintColor.B
		layerOpacities[i] = 1 - layer.transparency
	end

	-- Precompute the color-grade coefficients once per strip. The hue-rotation matrix is
	-- the standard luma-preserving (YIQ-derived) form; at hue 0 it collapses to identity.
	local brightness, contrast, saturation = 0, 1, 1
	local m00, m01, m02 = 1, 0, 0
	local m10, m11, m12 = 0, 1, 0
	local m20, m21, m22 = 0, 0, 1
	if adjust then
		brightness, contrast, saturation = adjust.brightness, adjust.contrast + 1, adjust.saturation + 1
		local h = math.rad(adjust.hue)
		local U, W = math.cos(h), math.sin(h)
		m00, m01, m02 = LR + U * (1 - LR) - W * LR, LG - U * LG - W * LG, LB - U * LB + W * (1 - LB)
		m10, m11, m12 = LR - U * LR + W * 0.143, LG + U * (1 - LG) + W * 0.140, LB - U * LB - W * 0.283
		m20, m21, m22 = LR - U * LR - W * (1 - LR), LG - U * LG + W * LG, LB + U * (1 - LB) + W * LB
	end

	-- Hoist the LUT's buffer/size/domain out of the pixel loop.
	local lutData, lutSize
	local ldMinR, ldMinG, ldMinB = 0, 0, 0
	local ldMaxR, ldMaxG, ldMaxB = 1, 1, 1
	if lut then
		lutData, lutSize = lut.data, lut.size
		ldMinR, ldMinG, ldMinB = lut.domainMin.X, lut.domainMin.Y, lut.domainMin.Z
		ldMaxR, ldMaxG, ldMaxB = lut.domainMax.X, lut.domainMax.Y, lut.domainMax.Z
	end

	for y = 0, cropHeight - 1 do
		local gy = cropMin.Y + y
		for x = 0, cropWidth - 1 do
			local gx = cropMin.X + x

			local br, bg, bb, ba = 0, 0, 0, 0
			for i = layerCount, 1, -1 do
				local sx = gx - layerOffsetXs[i]
				local sy = gy - layerOffsetYs[i]

				if sx >= 0 and sx < fullWidth and sy >= 0 and sy < fullHeight then
					local sj = (sx + (sy - layerTops[i]) * fullWidth) * 4

					local layerBuffer = layerBuffers[i]
					local r = buffer.readu8(layerBuffer, sj + 0) * layerTintRs[i]
					local g = buffer.readu8(layerBuffer, sj + 1) * layerTintGs[i]
					local b = buffer.readu8(layerBuffer, sj + 2) * layerTintBs[i]
					local a = buffer.readu8(layerBuffer, sj + 3) * layerOpacities[i]

					local aAlpha = a / 255
					local bAlpha = ba / 255

					local outAlpha = aAlpha + bAlpha * (1 - aAlpha)
					if outAlpha > 0 then
						br = (r * aAlpha + br * bAlpha * (1 - aAlpha)) / outAlpha
						bg = (g * aAlpha + bg * bAlpha * (1 - aAlpha)) / outAlpha
						bb = (b * aAlpha + bb * bAlpha * (1 - aAlpha)) / outAlpha
					else
						br, bg, bb = 0, 0, 0
					end
					ba = outAlpha * 255
				end
			end

			if adjust then
				local cr = br / 255
				local cg = bg / 255
				local cb = bb / 255

				-- Contrast pivots around mid-grey, then brightness offsets.
				cr = (cr - 0.5) * contrast + 0.5 + brightness
				cg = (cg - 0.5) * contrast + 0.5 + brightness
				cb = (cb - 0.5) * contrast + 0.5 + brightness

				-- Saturation lerps each channel toward / away from luma.
				local luma = cr * LR + cg * LG + cb * LB
				cr = luma + (cr - luma) * saturation
				cg = luma + (cg - luma) * saturation
				cb = luma + (cb - luma) * saturation

				-- Hue rotation. Alpha (ba) is untouched.
				br = math.clamp(cr * m00 + cg * m01 + cb * m02, 0, 1) * 255
				bg = math.clamp(cr * m10 + cg * m11 + cb * m12, 0, 1) * 255
				bb = math.clamp(cr * m20 + cg * m21 + cb * m22, 0, 1) * 255
			end

			-- LUT is applied last, mapping the graded color through the lookup. Alpha is
			-- untouched; fully transparent pixels are skipped since their color is unused.
			if lutData and ba > 0 then
				local nr, ng, nb = sampleLut(
					lutData,
					lutSize,
					br / 255,
					bg / 255,
					bb / 255,
					ldMinR,
					ldMinG,
					ldMinB,
					ldMaxR,
					ldMaxG,
					ldMaxB
				)
				br = math.clamp(nr, 0, 1) * 255
				bg = math.clamp(ng, 0, 1) * 255
				bb = math.clamp(nb, 0, 1) * 255
			end

			local oj = (x + y * cropWidth) * 4

			buffer.writeu8(composed, oj + 0, br)
			buffer.writeu8(composed, oj + 1, bg)
			buffer.writeu8(composed, oj + 2, bb)
			buffer.writeu8(composed, oj + 3, ba)
		end
	end

	return composed
end

return worker
