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

	onWhiteSpatial: EditableImage?,
	onBlackSpatial: EditableImage?,

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
		scheduler:schedule(
			rowRect,
			onWhiteRetro,
			onBlackRetro,
			onWhiteSpatial,
			onBlackSpatial,
			subjectOnBlack,
			backgroundOnBlack,
			colorCorrection
		)
	end

	local results = scheduler:workAsync()

	local output = AssetService:CreateEditableImageAsync(Content.fromObject(onWhiteRetro))
	for i, unpackResult in results do
		local rowRect = rows[i]
		output:WritePixelsBuffer(rowRect.Min, rowRect.Max - rowRect.Min, unpackResult())
	end

	return output
end

return reverseBlend
