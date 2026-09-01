local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)

local Scheduler = require(script.Parent.Scheduler)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local acquireScheduler = Scheduler.pool(ACTOR_COUNT, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local function plantSeeds(
	img: EditableImage,
	voronoi: EditableImage,
	regions: { Rect },
	insideThreshold: number,
	token: Cancellation.CancelToken?
): (boolean, Rect?)
	local scheduler, release = acquireScheduler(token)

	local imgSize = img.Size
	local imgWidth, imgHeight = imgSize.X, imgSize.Y

	for _, crop in regions do
		scheduler:schedule(img, crop, insideThreshold)
	end

	local results, workCancelled = scheduler:workAsync()
	if workCancelled then
		release()
		return false, nil
	end

	local offset = 0
	local stitched = buffer.create(imgWidth * imgHeight * 4)

	local hasInside = false
	local tXMin, tYMin = math.huge, math.huge
	local tXMax, tYMax = -math.huge, -math.huge

	for _i, getCropBuffer in results do
		local cropBuffer, chunkHasInside, cXMin, cYMin, cXMax, cYMax = getCropBuffer()
		buffer.copy(stitched, offset, cropBuffer)
		offset = offset + buffer.len(cropBuffer)

		hasInside = hasInside or chunkHasInside

		tXMin = math.min(tXMin, cXMin)
		tXMax = math.max(tXMax, cXMax)
		tYMin = math.min(tYMin, cYMin)
		tYMax = math.max(tYMax, cYMax)
	end

	voronoi:WritePixelsBuffer(Vector2.zero, imgSize, stitched)

	release()

	if tXMin == math.huge then
		return hasInside, nil
	end

	return hasInside, Rect.new(tXMin - 1, tYMin - 1, tXMax, tYMax)
end

return plantSeeds
