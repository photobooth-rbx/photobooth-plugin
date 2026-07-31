local RunService = game:GetService("RunService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")

local Uploader = {}

-- Public

function Uploader.build(plugin: Plugin)
	if not (RunService:IsStudio() and RunService:IsEdit()) then
		return
	end

	local UploaderApp = require(pluginRoot.Main.UserInterface.Apps.Upload)
	local Toolbar = require(pluginRoot.Main.UserInterface.Helpers.Toolbar)

	local toolbar = Toolbar.new(plugin, plugin:CreateToolbar("Photobooth_uploader"), false)
	UploaderApp.mount(plugin, toolbar)
end

return Uploader
