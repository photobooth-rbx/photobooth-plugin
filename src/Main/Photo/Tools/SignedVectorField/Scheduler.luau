local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)
local Parallel = require(pluginRoot.Packages.Parallel)

local Scheduler = {}

function Scheduler.pool<T..., U...>(actorCount: number, required: Parallel.Required<T..., U...>)
	local pooled = Parallel.new(actorCount, required)

	return function(token: Cancellation.CancelToken?): (Parallel.Parallel<T..., U...>, () -> ())
		if not token then
			pooled:waitForReady()
			return pooled, function() end
		end

		local scheduler = Parallel.new(actorCount, required)
		local unhook = token:onCancel(function()
			scheduler:cancelWork()
			scheduler:Destroy()
		end)

		scheduler:waitForReady()

		return scheduler, function()
			unhook()
			scheduler:Destroy()
		end
	end
end

return Scheduler
