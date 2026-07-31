--!optimize 2

local COMPARE_MARGIN = 0
local WHITE = 0xFFFFFFFF
local BLACK = 0xFF000000

@native
local function worker(
	rect: Rect,
	onWhiteRetro: EditableImage,
	onBlackRetro: EditableImage,

	subjectOnBlack: EditableImage?,
	backgroundOnBlack: EditableImage?,

	colorCorrection: ColorCorrectionEffect,
	sceneCorrected: boolean?
)
	local rectSize = rect.Max - rect.Min
	local width, height = rectSize.X, rectSize.Y

	local whiteRetroBuffer = onWhiteRetro:ReadPixelsBuffer(rect.Min, rectSize)
	local blackRetroBuffer = onBlackRetro:ReadPixelsBuffer(rect.Min, rectSize)

	local subjectBuffer = if subjectOnBlack
		then subjectOnBlack:ReadPixelsBuffer(rect.Min, rectSize)
		else blackRetroBuffer
	local backgroundBuffer = if backgroundOnBlack then backgroundOnBlack:ReadPixelsBuffer(rect.Min, rectSize) else nil

	local brightness = colorCorrection.Brightness
	local contrast = colorCorrection.Contrast + 1
	local saturation = colorCorrection.Saturation + 1

	local tintColor = colorCorrection.TintColor
	local tint = { tintColor.R, tintColor.G, tintColor.B }

	for i = 1, width * height do
		local j = (i - 1) * 4

		if buffer.readu32(whiteRetroBuffer, j + 0) == WHITE and buffer.readu32(blackRetroBuffer, j + 0) == BLACK then
			-- in both samples the pixels match their backgrounds perfectly
			-- this means that this pixel is guaranteed to be a background pixel
			buffer.writeu32(whiteRetroBuffer, j + 0, 0)
			continue
		end

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

		local isNearMargin = (
			math.abs(white[1] - black[1]) <= COMPARE_MARGIN
			and math.abs(white[2] - black[2]) <= COMPARE_MARGIN
			and math.abs(white[3] - black[3]) <= COMPARE_MARGIN
		)

		local pixelAlpha = 1
		if not isNearMargin then
			-- the pixels differ between the two versions of the image
			-- this means their must be some alpha we have to calculate
			local maxAlpha = 0
			for k = 1, 3 do
				local alpha = (white[k] - black[k] - 255) / -255
				maxAlpha = math.max(maxAlpha, math.clamp(alpha, 0, 1))
			end
			pixelAlpha = maxAlpha
		end

		if pixelAlpha <= 0 then
			buffer.writeu32(whiteRetroBuffer, j + 0, 0)
			continue
		end

		local rgba = { 0, 0, 0, pixelAlpha }
		for k = 0, 2 do
			local bo = buffer.readu8(subjectBuffer, j + k) / 255
			local bb = if backgroundBuffer then buffer.readu8(backgroundBuffer, j + k) / 255 else 0
			rgba[k + 1] = math.clamp((bo - (1 - pixelAlpha) * bb) / pixelAlpha, 0, 1)
		end

		-- color correction
		if not sceneCorrected then
			local gray = 0.345 * rgba[1] + 0.553 * rgba[2] + 0.114 * rgba[3]
			for k = 1, 3 do
				local component = rgba[k]
				component = component * saturation + (1 - saturation) * gray -- saturation
				component = ((component - 0.5) * math.max(0, contrast)) + 0.5 -- contrast
				component = component + brightness -- brightness
				component = component * tint[k] -- tint
				rgba[k] = math.clamp(component, 0, 1)
			end
		end

		buffer.writeu8(whiteRetroBuffer, j + 0, rgba[1] * 255)
		buffer.writeu8(whiteRetroBuffer, j + 1, rgba[2] * 255)
		buffer.writeu8(whiteRetroBuffer, j + 2, rgba[3] * 255)
		buffer.writeu8(whiteRetroBuffer, j + 3, rgba[4] * 255)
	end

	return whiteRetroBuffer
end

return worker
