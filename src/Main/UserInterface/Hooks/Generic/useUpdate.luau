local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local function useUpdate()
	local state, setState = React.useState({})
	return React.useCallback(function()
		setState({})
	end, { state })
end

return useUpdate
