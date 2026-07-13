local PresetRegistry = require(script.PresetRegistry)

local Presets = {}

local function loadPresetTypes(names: { string })
	local presetTypes = script.PresetTypes
	for _, name in names do
		local module = presetTypes:FindFirstChild(name)

		local _ = require(module) :: any
	end
end

loadPresetTypes({
	"Default",
	"Sticker",
	"BlackWhite",
	"Vintage",
	"Neon",
})

-- Public

export type EffectSpec = PresetRegistry.EffectSpec
export type LayerSpec = PresetRegistry.LayerSpec
export type PresetSpec = PresetRegistry.PresetSpec

function Presets.get()
	return PresetRegistry.getByIndex()
end

return Presets
