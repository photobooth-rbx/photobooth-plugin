local AssetService = game:GetService("AssetService") :: AssetService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)
local Parallel = require(pluginRoot.Packages.Parallel)

type WorkerAction = typeof(require(script.Worker))

local scheduler = Parallel.new(32, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local function reverseBlend(
	onWhiteRetro: EditableImage,
	onBlackRetro: EditableImage,

	subjectOnBlack: EditableImage?,
	backgroundOnBlack: EditableImage?,

	colorCorrection: ColorCorrectionEffect
)
	scheduler:waitForReady()

	local size = onWhiteRetro.Size
	local width, height = size.X, size.Y

	local sourceRect = Rect.new(0, 0, width, height)
	local rows = RectSlicer.rows(sourceRect, scheduler:getActorCount())
	for _, rowRect in rows do
		scheduler:schedule(rowRect, onWhiteRetro, onBlackRetro, subjectOnBlack, backgroundOnBlack, colorCorrection)
	end

	local results = scheduler:workAsync()

	local offset = 0
	local stitched = buffer.create(width * height * 4)
	for _, unpackResult in results do
		local slice = unpackResult()
		buffer.copy(stitched, offset, slice)
		offset = offset + buffer.len(slice)
	end

	local output = AssetService:CreateEditableImageAsync(Content.fromObject(onWhiteRetro))
	output:WritePixelsBuffer(Vector2.zero, size, stitched)

	return output
end

return reverseBlend
