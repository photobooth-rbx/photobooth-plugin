local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)

local SaveVersions = require(script.SaveVersions)

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

local defaultSave = SaveVersions.default()
State.settings = ObservableValue.new(defaultSave.settings)
State.postProcessingPresets = ObservableValue.new(defaultSave.postProcessingPresets)

State.temporary = ObservableValue.new(table.clone(DEFAULT_TEMPORARY))

function State.initPluginSaving(plugin: Plugin)
	local _success, _err: string? = pcall(function()
		local pluginSave = plugin:GetSetting(PLUGIN_SAVED_KEY) :: SaveVersions.Saved?
		local pluginLoaded = pluginSave and SaveVersions.load(pluginSave)
		if pluginLoaded then
			assert(pluginLoaded.settings, "Failed to load saved settings.")
			State.settings:set(pluginLoaded.settings)

			assert(pluginLoaded.postProcessingPresets, "Failed to load post-processing presets.")
			State.postProcessingPresets:set(pluginLoaded.postProcessingPresets)
		end
	end)

	plugin.Unloading:Connect(function()
		local pluginSave = SaveVersions.save({
			settings = State.settings:get(),
			postProcessingPresets = State.postProcessingPresets:get(),
		})

		plugin:SetSetting(PLUGIN_SAVED_KEY, pluginSave)
	end)
end

return State
