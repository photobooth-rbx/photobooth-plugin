local COMPARE_MARGIN = 0

local WHITE = { 255, 255, 255, 255 }
local BLACK = { 0, 0, 0, 255 }

@native
local function compareByMargin(a: { number }, b: { number }, margin: number): boolean
	-- stylua: ignore
	return (
			math.abs(a[1] - b[1]) <= margin 
		and math.abs(a[2] - b[2]) <= margin
		and math.abs(a[3] - b[3]) <= margin
	)
end

@native
local function worker(
	rect: Rect,
	onWhiteRetro: EditableImage,
	onBlackRetro: EditableImage,
	onBlack: EditableImage?,
	colorCorrection: ColorCorrectionEffect
)
	local brightness = colorCorrection.Brightness
	local contrast = colorCorrection.Contrast + 1
	local saturation = colorCorrection.Saturation + 1

	local tintColor = colorCorrection.TintColor
	local tint = { tintColor.R, tintColor.G, tintColor.B }

	local rectSize = rect.Max - rect.Min
	local width, height = rectSize.X, rectSize.Y

	local whiteRetroBuffer = onWhiteRetro:ReadPixelsBuffer(rect.Min, rectSize)
	local blackRetroBuffer = onBlackRetro:ReadPixelsBuffer(rect.Min, rectSize)
	local blackBuffer = if onBlack then onBlack:ReadPixelsBuffer(rect.Min, rectSize) else blackRetroBuffer

	for i = 1, width * height * 4 do
		local j = (i - 1) * 4

		local white = {
			buffer.readu8(whiteRetroBuffer, j + 0),
			buffer.readu8(whiteRetroBuffer, j + 1),
			buffer.readu8(whiteRetroBuffer, j + 2),
			buffer.readu8(whiteRetroBuffer, j + 3),
		}

		local black = {
			buffer.readu8(blackRetroBuffer, j + 0),
			buffer.readu8(blackRetroBuffer, j + 1),
			buffer.readu8(blackRetroBuffer, j + 2),
			buffer.readu8(blackRetroBuffer, j + 3),
		}

		if compareByMargin(white, WHITE, 0) and compareByMargin(black, BLACK, 0) then
			-- in both samples the pixels match their backgrounds perfectly
			-- this means that this pixel is guaranteed to be a background pixel
			buffer.writeu8(blackBuffer, j + 3, 0)
			continue
		end

		local rgba = {
			buffer.readu8(blackBuffer, j + 0),
			buffer.readu8(blackBuffer, j + 1),
			buffer.readu8(blackBuffer, j + 2),
			buffer.readu8(blackBuffer, j + 3),
		}

		if not compareByMargin(white, black, COMPARE_MARGIN) then
			-- the pixels differ between the two versions of the image
			-- this means their must be some alpha we have to calculate
			local maxAlpha = 0
			for k = 1, 3 do
				local alpha = (white[k] - black[k] - 255) / -255
				maxAlpha = math.max(maxAlpha, math.clamp(alpha, 0, 1))
			end

			for k = 1, 3 do
				rgba[k] = math.clamp((rgba[k] / maxAlpha) / 255, 0, 1)
			end

			rgba[4] = maxAlpha
		end

		-- color correction
		local gray = 0.345 * rgba[1] + 0.553 * rgba[2] + 0.114 * rgba[3]
		for k = 1, 3 do
			local component = rgba[k]
			component = component * saturation + (1 - saturation) * gray -- saturation
			component = ((component - 0.5) * math.max(0, contrast)) + 0.5 -- contrast
			component = component + brightness -- brightness
			component = component * tint[k] -- tint
			rgba[k] = math.clamp(component, 0, 1)
		end

		buffer.writeu8(blackBuffer, j + 0, rgba[1] * 255)
		buffer.writeu8(blackBuffer, j + 1, rgba[2] * 255)
		buffer.writeu8(blackBuffer, j + 2, rgba[3] * 255)
		buffer.writeu8(blackBuffer, j + 3, rgba[4] * 255)
	end

	return buffer.create(0)
end

return worker
