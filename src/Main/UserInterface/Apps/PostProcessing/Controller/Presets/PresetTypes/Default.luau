local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("default", {
	name = "Default",
	layers = {
		{
			name = "Image",
			effects = {},
		},
	},
})
