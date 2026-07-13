local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)
local Parallel = require(pluginRoot.Packages.Parallel)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local function plantSeeds(
	img: EditableImage,
	voronoi: EditableImage,
	regions: { Rect },
	insideThreshold: number,
	token: Cancellation.CancelToken
)
	local scheduler = Parallel.new(ACTOR_COUNT, {
		script = script.Worker,
		typecast = (nil :: any) :: WorkerAction,
	})

	local unhook = token:onCancel(function()
		scheduler:cancelWork()
		scheduler:Destroy()
	end)

	scheduler:waitForReady()

	local imgSize = img.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

	for _, crop in regions do
		scheduler:schedule(img, crop, insideThreshold)
	end

	local results, workCancelled = scheduler:workAsync()
	if workCancelled then
		return
	end

	local offset = 0
	local stitched = buffer.create(imgWidth * imgHeight * 4)
	for _i, getBuffer in results do
		local cropBuffer = getBuffer()
		buffer.copy(stitched, offset, cropBuffer)
		offset = offset + buffer.len(cropBuffer)
	end

	voronoi:WritePixelsBuffer(Vector2.zero, imgSize, stitched)

	unhook()
	scheduler:Destroy()
end

return plantSeeds
