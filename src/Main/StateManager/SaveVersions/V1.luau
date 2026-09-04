local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Sift = require(pluginRoot.Packages.Sift)

local SaveFormatV1 = {}

export type Serialized = {
	settings: {
		alphaBleedingEnabled: boolean,
		bindingsEnabled: boolean,
		galleryListExpanded: boolean,
		galleryListGridView: boolean,
		experimentalModeEnabled: boolean,

		autoCaptureOrigin: Vector3,
	},

	postProcessingPresets: { any },
}

export type Deserialized = {
	settings: {
		alphaBleedingEnabled: boolean,
		bindingsEnabled: boolean,
		galleryListExpanded: boolean,
		galleryListGridView: boolean,
		experimentalModeEnabled: boolean,

		autoCaptureOrigin: Vector3,
	},

	postProcessingPresets: { any },
}

SaveFormatV1.version = 1

function SaveFormatV1.default(): Deserialized
	return {
		settings = {
			alphaBleedingEnabled = true,
			bindingsEnabled = false,
			galleryListExpanded = true,
			galleryListGridView = false,
			experimentalModeEnabled = false,

			autoCaptureOrigin = Vector3.zero,
		},

		postProcessingPresets = {},
	}
end

function SaveFormatV1.migrate(_previousSerialized: any)
	error(`[SaveFormatV{SaveFormatV1.version}]: Cannot migrate from V1`)
end

function SaveFormatV1.serialize(deserialized: Deserialized): Serialized
	local default = SaveFormatV1.default()
	return {
		settings = Sift.Dictionary.merge(default.settings, deserialized.settings),
		postProcessingPresets = deserialized.postProcessingPresets or {},
	}
end

function SaveFormatV1.deserialize(serialized: Serialized): Deserialized
	local default = SaveFormatV1.default()
	return {
		settings = Sift.Dictionary.merge(default.settings, serialized.settings),
		postProcessingPresets = serialized.postProcessingPresets or {},
	}
end

return SaveFormatV1
