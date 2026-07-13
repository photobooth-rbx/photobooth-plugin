local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Signal = require(pluginRoot.Packages.Signal)
local React = require(pluginRoot.Packages.React)

local ObservableValueStatic = {}

local ObservableValueClass = {}
ObservableValueClass.__index = ObservableValueClass
ObservableValueClass.ClassName = "ObservableValue"

export type ObservableValue<T> = typeof(setmetatable(
	{} :: {
		value: T,
		signal: Signal.Signal<()>,
	},
	ObservableValueClass
))

function ObservableValueStatic.new<T>(value: T)
	local self = setmetatable({}, ObservableValueClass) :: ObservableValue<T>

	self.value = value
	self.signal = Signal.new()

	return self
end

function ObservableValueClass.get<T>(self: ObservableValue<T>)
	return self.value
end

function ObservableValueClass.set<T>(self: ObservableValue<T>, state: T)
	self.value = state
	self.signal:Fire()
end

function ObservableValueClass.update<T>(self: ObservableValue<T>)
	-- this is crazy syntax, but it works w/ the type system so it is what it is
	return function(callback: (T) -> T)
		self:set(callback(self.value))
	end
end

local function useInternal<T, U>(self: ObservableValue<T>, read: (T) -> U, predicate: (U, U) -> boolean)
	local state, setState = React.useState({})
	local valueRef = React.useRef(read(self.value))

	React.useEffect(function()
		local function refresh()
			local readValue = read(self.value)
			if predicate(readValue, valueRef.current) then
				valueRef.current = readValue
				setState({})
			end
		end

		refresh()
		local connection = self.signal:Connect(function()
			refresh()
		end)

		return function()
			connection:Disconnect()
		end
	end, { self :: any })

	return valueRef.current, state
end

function ObservableValueClass.useSpecific<T>(self: ObservableValue<T>)
	return function<U>(read: (T) -> U)
		local value = useInternal(self, read, function(new, prev)
			return new ~= prev
		end)

		return value
	end
end

function ObservableValueClass.use<T>(self: ObservableValue<T>)
	local value, state = useInternal(self, function(selfValue)
		return selfValue
	end, function()
		return true
	end)

	local updateValue = React.useCallback(function(callback: (T) -> T)
		self:update()(callback)
	end, { self :: any, state :: any })

	return value, updateValue
end

function ObservableValueClass.onChanged<T>(self: ObservableValue<T>, callback: () -> ())
	return self.signal:Connect(callback)
end

function ObservableValueClass.waitForChange<T>(self: ObservableValue<T>)
	self.signal:Wait()
	return self:get()
end

function ObservableValueClass.Destroy<T>(self: ObservableValue<T>)
	self.signal:Destroy()
end

return ObservableValueStatic
