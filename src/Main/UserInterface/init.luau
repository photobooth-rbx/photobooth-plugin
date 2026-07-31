local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Constants = require(pluginRoot.Constants)

local Toolbar = require(script.Helpers.Toolbar)

local UserInterface = {}

local function tryMountApps(plugin: Plugin, toolbar: Toolbar.Toolbar, appNames: { string })
	for _, appName in appNames do
		local appModule = script.Apps:FindFirstChild(appName)
		if appModule then
			local app = require(appModule) :: any
			app.mount(plugin, toolbar)
		end
	end
end

function UserInterface.mountApps(plugin: Plugin, toolbar: PluginToolbar)
	local appToolbar = Toolbar.new(plugin, toolbar, Constants.CompactToolbarButton)

	tryMountApps(plugin, appToolbar, {
		"Viewport",
		"CaptureUI",
		"Gallery",
		"AutoCapture",
		"PostProcessing",
	})
end

return UserInterface
