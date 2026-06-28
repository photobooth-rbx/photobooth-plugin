local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)
local StateManager = require(pluginRoot.Main.StateManager)

local function useState(): StateManager.State
	local function snapshot()
		return {
			saved = StateManager.saved:get(),
			temporary = StateManager.temporary:get(),
		}
	end

	local value, setValue = React.useState(snapshot())

	React.useEffect(function()
		setValue(snapshot())

		local savedConnection = StateManager.saved:onChanged(function()
			setValue(snapshot())
		end)
		local temporaryConnection = StateManager.temporary:onChanged(function()
			setValue(snapshot())
		end)

		return function()
			savedConnection:Disconnect()
			temporaryConnection:Disconnect()
		end
	end, {})

	return value
end

return useState
