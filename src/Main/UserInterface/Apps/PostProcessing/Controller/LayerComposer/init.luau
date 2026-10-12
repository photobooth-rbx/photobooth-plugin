local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

local AlphaBleed = require(pluginRoot.Main.Photo.Captures.Composers.AlphaBleed)

local Types = require(script.Types)

local LayerComposer = {}

export type Layer = Types.Layer
export type Adjustment = Types.Adjustment
export type Lut = Types.Lut

type WorkerAction = typeof(require(script.Worker))

local scheduler = Parallel.new(32, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

function LayerComposer.composeAsync(
	editImage: EditableImage,
	layers: { Layer },
	adjustment: Adjustment?,
	lut: Types.Lut?
)
	scheduler:waitForReady()

	local imgSize = editImage.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y
	local fullRegion = Rect.new(0, 0, imgWidth, imgHeight)

	local rows = RectSlicer.rows(fullRegion, scheduler:getActorCount())
	for _, rowRect in rows do
		scheduler:schedule(layers, rowRect, imgSize, adjustment, lut)
	end

	local results = scheduler:workAsync()

	local composedEdit = AssetService:CreateEditableImageAsync(Content.fromObject(editImage))
	for i, getBuffer in results do
		local rowRect = rows[i]
		composedEdit:WritePixelsBuffer(rowRect.Min, rowRect.Max - rowRect.Min, getBuffer())
	end

	AlphaBleed(composedEdit)

	return composedEdit
end

return LayerComposer
