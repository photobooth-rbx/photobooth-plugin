local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)

local Worker = require(script.Worker)

type WorkerAction = typeof(Worker)
export type Properties = Worker.Properties

local scheduler = Parallel.new(32, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

return EffectsRegistry.register("Outer Glow", {
	create = function()
		local properties: Properties = {
			size = 15,
			falloff = 2,
			clipped = false,
			transparency = 0,
			offset = Vector2.zero,
			color = Color3.new(1, 1, 1),
		}
		return properties
	end,
	render = function(inputs, properties)
		scheduler:waitForReady()

		local imgSize = inputs.svf.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y
		local stitched = buffer.create(imgWidth * imgHeight * 4)

		if properties.size > 0 then
			local region = Rect.new(0, 0, imgWidth, imgHeight)
			local rows = RectSlicer.rows(region, scheduler:getActorCount())
			for _, rowRect in rows do
				scheduler:schedule(inputs, properties, rowRect)
			end

			local offset = 0
			local results = scheduler:workAsync()
			for _, getBuffer in results do
				local b = getBuffer()
				buffer.copy(stitched, offset, b)
				offset = offset + buffer.len(b)
			end
		end

		inputs.output:WritePixelsBuffer(Vector2.zero, imgSize, stitched)
	end,
})
