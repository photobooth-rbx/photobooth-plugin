local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local function applyBleed(img: EditableImage, voronoi: EditableImage, regions: { Rect })
	local scheduler = Parallel.new(ACTOR_COUNT, {
		script = script.Worker,
		typecast = (nil :: any) :: WorkerAction,
	})

	scheduler:waitForReady()

	for _, crop in regions do
		scheduler:schedule(img, voronoi, crop)
	end

	local results = scheduler:workAsync()
	scheduler:Destroy()

	for i, getCropBuffer in results do
		local crop = regions[i]
		img:WritePixelsBuffer(crop.Min, crop.Max - crop.Min, getCropBuffer())
	end
end

return applyBleed
