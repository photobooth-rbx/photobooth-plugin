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

	for _, crop in regions do
		scheduler:schedule(img, crop, insideThreshold)
	end

	local results, workCancelled = scheduler:workAsync()
	if workCancelled then
		release()
		return false, nil
	end

	local hasInside = false
	local tXMin, tYMin = math.huge, math.huge
	local tXMax, tYMax = -math.huge, -math.huge

	for i, getCropBuffer in results do
		local crop = regions[i]
		local cropBuffer, chunkHasInside, cXMin, cYMin, cXMax, cYMax = getCropBuffer()
		voronoi:WritePixelsBuffer(crop.Min, crop.Max - crop.Min, cropBuffer)

		hasInside = hasInside or chunkHasInside

		tXMin = math.min(tXMin, cXMin)
		tXMax = math.max(tXMax, cXMax)
		tYMin = math.min(tYMin, cYMin)
		tYMax = math.max(tYMax, cYMax)
	end

	release()

	if tXMin == math.huge then
		return hasInside, nil
	end

	return hasInside, Rect.new(tXMin - 1, tYMin - 1, tXMax, tYMax)
end

return plantSeeds
