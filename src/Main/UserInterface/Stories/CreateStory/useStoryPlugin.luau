--!nolint DeprecatedApi

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local function createPlugin()
	-- selene: allow(undefined_variable)
	return PluginManager():CreatePlugin() :: Plugin
end

local function useStoryPlugin()
	local pluginRef = React.useRef(createPlugin())

	React.useEffect(function()
		return function()
			pluginRef.current:Destroy()
		end
	end, {})

	return pluginRef.current
end

return useStoryPlugin
