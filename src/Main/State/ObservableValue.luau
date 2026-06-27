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

function ObservableValueClass.use<T>(self: ObservableValue<T>)
	local state, setState = React.useState({})
	local valueRef = React.useRef(self.value)

	React.useEffect(function()
		if valueRef.current ~= self.value then
			valueRef.current = self.value
			setState({})
		end

		local connection = self.signal:Connect(function()
			valueRef.current = self.value
			setState({})
		end)

		return function()
			connection:Disconnect()
		end
	end, { self :: any })

	local updateValue = React.useCallback(function(callback: (T) -> T)
		self:update()(callback)
	end, { self :: any, state :: any })

	return valueRef.current, updateValue
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
