local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local function applyBleed(img: EditableImage, voronoi: EditableImage, regions: { Rect }, workingBbox: Rect)
	local scheduler = Parallel.new(ACTOR_COUNT, {
		script = script.Worker,
		typecast = (nil :: any) :: WorkerAction,
	})

	scheduler:waitForReady()

	for _, crop in regions do
		scheduler:schedule(img, voronoi, crop)
	end

	local offset = 0
	local stitched = buffer.create(workingBbox.Width * workingBbox.Height * 4)

	local results = scheduler:workAsync()
	scheduler:Destroy()

	for _i, getCropBuffer in results do
		local cropBuffer = getCropBuffer()
		buffer.copy(stitched, offset, cropBuffer)
		offset = offset + buffer.len(cropBuffer)
	end

	img:WritePixelsBuffer(workingBbox.Min, workingBbox.Max - workingBbox.Min, stitched)
end

return applyBleed
