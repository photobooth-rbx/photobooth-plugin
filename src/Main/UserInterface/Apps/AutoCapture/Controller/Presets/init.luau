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
})

-- Public

export type StateSpec = PresetRegistry.StateSpec
export type PresetSpec = PresetRegistry.PresetSpec

function Presets.get()
	return PresetRegistry.getByIndex()
end

return Presets
