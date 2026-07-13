local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("neon", {
	name = "Neon",
	layers = {
		{
			name = "Neon",
			effects = {
				{
					kind = "Stroke",
					properties = {
						thickness = 2,
						softness = 1,
						color = Color3.new(1, 1, 1),
					} :: { [string]: any },
				},
				{
					kind = "Outer Glow",
					properties = {
						size = 22,
						falloff = 2.5,
						color = Color3.fromRGB(0, 200, 255),
					} :: { [string]: any },
				},
			},
		},
	},
})
