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
	tryMountApps(plugin, toolbar, {
		"Viewport",
		"CaptureUI",
		"Gallery",
		"AutoCapture",
		"PostProcessing",
	})
end

return UserInterface
