local CancelTokenStatic = {}

local CancelTokenClass = {}
CancelTokenClass.__index = CancelTokenClass
CancelTokenClass.ClassName = "CancelToken"

export type CancelToken = typeof(setmetatable({} :: {}, CancelTokenClass))

type Private = {
	_isCancelled: () -> boolean,
	_cancelCallbacks: { [() -> ()]: boolean },
}

local weakRefs = setmetatable({} :: { [CancelToken]: Private }, { __mode = "k" })

function CancelTokenStatic.new(isCancelled: () -> boolean)
	local self = setmetatable({}, CancelTokenClass) :: CancelToken

	weakRefs[self] = {
		_isCancelled = isCancelled,
		_cancelCallbacks = {},
	}

	return self
end

function CancelTokenStatic.cancel(self: CancelToken)
	local private = weakRefs[self]
	local callbacks = private._cancelCallbacks
	private._cancelCallbacks = {}
	for callback, _ in callbacks do
		task.spawn(callback)
	end
end

function CancelTokenClass.onCancel(self: CancelToken, callback: () -> ())
	local private = weakRefs[self]
	if self:isCancelled() then
		task.spawn(callback)
	else
		private._cancelCallbacks[callback] = true
	end

	return function()
		private._cancelCallbacks[callback] = nil
	end
end

function CancelTokenClass.isCancelled(self: CancelToken)
	local private = weakRefs[self]
	return private._isCancelled()
end

return CancelTokenStatic
