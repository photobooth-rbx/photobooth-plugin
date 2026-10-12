local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Parallel = require(pluginRoot.Packages.Parallel)
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local EffectsHelper = require(effectsRoot.EffectsHelper)

local Worker = require(script.Worker)

type WorkerAction = typeof(Worker)
export type Properties = Worker.Properties

local scheduler = Parallel.new(32, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

return EffectsRegistry.register("Inner Shadow", {
	renderAboveBase = true,
	create = function()
		local properties: Properties = {
			size = 10,
			falloff = 2,
			angle = 135,
			transparency = 0,
			offset = Vector2.zero,
			color = Color3.new(0, 0, 0),
		}
		return properties
	end,
	render = function(inputs, properties)
		scheduler:waitForReady()

		local imgSize = inputs.svf.Size
		local imgWidth, imgHeight = imgSize.X, imgSize.Y

		if properties.size > 0 then
			local region = Rect.new(0, 0, imgWidth, imgHeight)
			local rows = RectSlicer.rows(region, scheduler:getActorCount())
			for _, rowRect in rows do
				scheduler:schedule(inputs, properties, rowRect)
			end

			local results = scheduler:workAsync()
			for i, getBuffer in results do
				local rowRect = rows[i]
				inputs.output:WritePixelsBuffer(rowRect.Min, rowRect.Max - rowRect.Min, getBuffer())
			end
		else
			EffectsHelper.clear(inputs.output)
		end
	end,
})
