local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)
local StateManager = require(pluginRoot.Main.StateManager)

local function useStatePath<T>(readFromPath: (StateManager.State) -> T)
	local function read()
		return readFromPath({
			saved = StateManager.saved:get(),
			temporary = StateManager.temporary:get(),
		})
	end

	local value, setValue = React.useState(read())

	React.useEffect(function()
		setValue(read())

		local savedConnection = StateManager.saved:onChanged(function()
			setValue(read())
		end)
		local temporaryConnection = StateManager.temporary:onChanged(function()
			setValue(read())
		end)

		return function()
			savedConnection:Disconnect()
			temporaryConnection:Disconnect()
		end
	end, {})

	return value
end

return useStatePath
