local EncodingService = game:GetService("EncodingService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Bufferize = require(pluginRoot.Packages.Bufferize)

local SaveVersions = require(script.SaveVersions)

local SAVING_ENABLED = true
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
		local pluginSave = plugin:GetSetting(PLUGIN_SAVED_KEY) :: string?
		local encoded = pluginSave and EncodingService:Base64Decode(buffer.fromstring(pluginSave))
		local decodedSave = encoded and Bufferize.decode(encoded)
		local pluginLoaded = decodedSave and SaveVersions.load(decodedSave)
		if pluginLoaded then
			assert(pluginLoaded.settings, "Failed to load saved settings.")
			State.settings:set(pluginLoaded.settings)

			assert(pluginLoaded.postProcessingPresets, "Failed to load post-processing presets.")
			State.postProcessingPresets:set(pluginLoaded.postProcessingPresets)
		end
	end)

	plugin.Unloading:Connect(function()
		if not SAVING_ENABLED then
			plugin:SetSetting(PLUGIN_SAVED_KEY, nil)
			return
		end

		local pluginSave = SaveVersions.save({
			settings = State.settings:get(),
			postProcessingPresets = State.postProcessingPresets:get(),
		})

		local encoded = EncodingService:Base64Encode(Bufferize.encode(pluginSave))
		plugin:SetSetting(PLUGIN_SAVED_KEY, buffer.tostring(encoded))
	end)
end

return State
