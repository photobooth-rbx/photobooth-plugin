local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Future = require(pluginRoot.Packages.Future)

local CancelToken = require(script.CancelToken)

local CancellationStatic = {}

local CancellationClass = {}
CancellationClass.__index = CancellationClass
CancellationClass.ClassName = "Cancellation"

export type CancelToken = CancelToken.CancelToken

export type Cancellation<T...> = typeof(setmetatable(
	{} :: {
		resolutionFuture: Future.Future<(() -> T...)?>,
		cancelToken: CancelToken,
		cancelThread: thread,
	},
	CancellationClass
))

function CancellationStatic.new<T...>(callbackAsync: (CancelToken) -> T...)
	local self = setmetatable({}, CancellationClass) :: Cancellation<T...>

	self.resolutionFuture = Future.new()

	self.cancelToken = CancelToken.new(function()
		if self.resolutionFuture:isCompleted() then
			return self.resolutionFuture:expect() == nil
		end
		return false
	end)

	self.cancelThread = task.spawn(function()
		local unpackCallback = Future.packAsCallback(callbackAsync(self.cancelToken))
		if not self.resolutionFuture:isCompleted() then
			self.resolutionFuture:complete(unpackCallback)
		end
	end)

	return self
end

function CancellationClass.expect<T...>(self: Cancellation<T...>)
	return self.resolutionFuture:expect()
end

function CancellationClass.cancel<T...>(self: Cancellation<T...>)
	if not self.resolutionFuture:isCompleted() then
		self.resolutionFuture:complete(nil)
		CancelToken.cancel(self.cancelToken)
		if coroutine.status(self.cancelThread) == "suspended" then
			task.cancel(self.cancelThread)
		end
	end
end

return CancellationStatic
