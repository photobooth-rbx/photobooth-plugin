--!optimize 2

local COMPARE_MARGIN = 0
local WHITE = 0xFFFFFFFF
local BLACK = 0xFF000000

@native
local function extractAlpha(whiteBuffer: buffer, blackBuffer: buffer, j: number)
	if buffer.readu32(whiteBuffer, j + 0) == WHITE and buffer.readu32(blackBuffer, j + 0) == BLACK then
		-- in both samples the pixels match their backgrounds perfectly
		-- this means that this pixel is guaranteed to be a background pixel
		return 0
	end

	local isNearMargin = true
	for k = 0, 2 do
		if math.abs(buffer.readu8(whiteBuffer, j + k) - buffer.readu8(blackBuffer, j + k)) > COMPARE_MARGIN then
			isNearMargin = false
			break
		end
	end

	if isNearMargin then
		return 1
	end

	-- the pixels differ between the two versions of the image
	-- this means their must be some alpha we have to calculate
	local maxAlpha = 0
	for k = 0, 2 do
		local alpha = (buffer.readu8(whiteBuffer, j + k) - buffer.readu8(blackBuffer, j + k) - 255) / -255
		maxAlpha = math.max(maxAlpha, math.clamp(alpha, 0, 1))
	end
	return maxAlpha
end

@native
local function worker(
	rect: Rect,
	onWhiteRetro: EditableImage,
	onBlackRetro: EditableImage,

	onWhiteSpatial: EditableImage?,
	onBlackSpatial: EditableImage?,

	subjectOnBlack: EditableImage?,
	backgroundOnBlack: EditableImage?,

	colorCorrection: ColorCorrectionEffect
)
	local rectSize = rect.Max - rect.Min
	local width, height = rectSize.X, rectSize.Y

	local whiteRetroBuffer = onWhiteRetro:ReadPixelsBuffer(rect.Min, rectSize)
	local blackRetroBuffer = onBlackRetro:ReadPixelsBuffer(rect.Min, rectSize)

	local whiteSpatialBuffer = if onWhiteSpatial then onWhiteSpatial:ReadPixelsBuffer(rect.Min, rectSize) else nil
	local blackSpatialBuffer = if onBlackSpatial then onBlackSpatial:ReadPixelsBuffer(rect.Min, rectSize) else nil

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

		local outputAlpha = extractAlpha(whiteRetroBuffer, blackRetroBuffer, j)
		if whiteSpatialBuffer and blackSpatialBuffer and outputAlpha < 1 then
			local spatialAlpha = extractAlpha(whiteSpatialBuffer, blackSpatialBuffer, j)
			outputAlpha = math.max(outputAlpha, spatialAlpha)
		end

		if outputAlpha <= 0 then
			buffer.writeu32(whiteRetroBuffer, j + 0, 0)
			continue
		end

		local rgba = { 0, 0, 0, outputAlpha }
		for k = 0, 2 do
			local bo = buffer.readu8(subjectBuffer, j + k) / 255
			local bb = if backgroundBuffer then buffer.readu8(backgroundBuffer, j + k) / 255 else 0
			rgba[k + 1] = math.clamp((bo - (1 - outputAlpha) * bb) / outputAlpha, 0, 1)
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

		buffer.writeu8(whiteRetroBuffer, j + 0, rgba[1] * 255)
		buffer.writeu8(whiteRetroBuffer, j + 1, rgba[2] * 255)
		buffer.writeu8(whiteRetroBuffer, j + 2, rgba[3] * 255)
		buffer.writeu8(whiteRetroBuffer, j + 3, rgba[4] * 255)
	end

	return whiteRetroBuffer
end

return worker
