local RunService = game:GetService("RunService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")

local Uploader = {}

-- Public

function Uploader.build(plugin: Plugin)
	if not (RunService:IsStudio() and RunService:IsEdit()) then
		return
	end

	local UploaderApp = require(pluginRoot.Main.UserInterface.Apps.Upload)
	local toolbar = plugin:CreateToolbar("Photobooth_uploader")
	UploaderApp.mount(plugin, toolbar)
end

return Uploader
