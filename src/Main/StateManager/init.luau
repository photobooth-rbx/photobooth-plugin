local SaveVersions = require(script.SaveVersions)
local ObservableValue = require(script.ObservableValue)

local PLUGIN_SAVED_KEY = "egomoose_photobooth_save"
local DEFAULT_TEMPORARY = {
	scaleOS = Vector2.one,

	isCapturing = false,
	isFullscreen = false,
	isBlackoutMode = false,
	isExperimentalMode = false,

	uiCaptureTypeIndex = 1,
	viewportCaptureTypeIndex = 1,
}

local State = {}

State.saved = ObservableValue.new(SaveVersions.default())
State.temporary = ObservableValue.new(table.clone(DEFAULT_TEMPORARY))

function State.initPluginSaving(plugin: Plugin)
	local _success, _err = pcall(function()
		local pluginSave = plugin:GetSetting(PLUGIN_SAVED_KEY) :: SaveVersions.Saved?
		local pluginLoaded = pluginSave and SaveVersions.load(pluginSave)
		if pluginLoaded then
			State.saved:set(pluginLoaded)
		end
	end)

	plugin.Unloading:Connect(function()
		local pluginSave = SaveVersions.save(State.saved:get())
		plugin:SetSetting(PLUGIN_SAVED_KEY, pluginSave)
	end)
end

return State
