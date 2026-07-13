local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("vintage", {
	name = "Vintage",
	layers = {
		{
			name = "Vintage",
			tintColor = Color3.fromRGB(255, 196, 130),
			brightness = 0.08,
			contrast = -0.1,
			saturation = -1,
			hue = 0,
		},
	},
})
