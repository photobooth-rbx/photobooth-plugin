local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("blackWhite", {
	name = "Black & White",
	layers = {
		{
			name = "Black & White",
			saturation = -1,
		},
	},
})
