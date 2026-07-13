local presetsRoot = script:FindFirstAncestor("Presets")
local PresetRegistry = require(presetsRoot.PresetRegistry)

return PresetRegistry.register("sticker", {
	name = "Sticker",
	layers = {
		{
			name = "Sticker",
			effects = {
				{
					kind = "Stroke",
					properties = {
						thickness = 6,
						softness = 1,
						color = Color3.new(1, 1, 1),
					} :: { [string]: any },
				},
				{
					kind = "Drop Shadow",
					properties = {
						blur = 8,
						spread = 2,
						shadowOffset = Vector2.new(6, 6),
						transparency = 0.5,
					} :: { [string]: any },
				},
			},
		},
	},
})
