local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Constants = require(pluginRoot.Constants)

local CompactToolbar = require(script.Helpers.CompactToolbar)

local UserInterface = {}

local function tryMountApps(plugin: Plugin, toolbar: PluginToolbar, appNames: { string })
	for _, appName in appNames do
		local appModule = script.Apps:FindFirstChild(appName)
		if appModule then
			local app = require(appModule) :: any
			app.mount(plugin, toolbar)
		end
	end
end

function UserInterface.mountApps(plugin: Plugin, toolbar: PluginToolbar)
	local appToolbar = toolbar
	if Constants.CompactToolbarButton then
		-- the apps get menu entries under a single toolbar button rather than a button each
		appToolbar = CompactToolbar.new(plugin, toolbar) :: any
	end

	tryMountApps(plugin, appToolbar, {
		"Viewport",
		"CaptureUI",
		"Gallery",
		"AutoCapture",
		"PostProcessing",
	})
end

return UserInterface
