local PresetsRegistry = {}

export type EffectSpec = {
	kind: string,
	name: string?,
	properties: { [string]: any }?,
}

export type LayerSpec = {
	name: string?,
	tintColor: Color3?,
	transparency: number?,
	brightness: number?,
	contrast: number?,
	saturation: number?,
	hue: number?,
	effects: { EffectSpec }?,
}

export type PresetSpec = {
	name: string,
	layers: { LayerSpec },
}

local presetByIndex = {}
local presetByKind = {}

function PresetsRegistry.register(kind: string, spec: PresetSpec)
	local presetEntry = {
		kind = kind,
		index = #presetByIndex + 1,
		spec = spec,
	}

	table.insert(presetByIndex, presetEntry)
	presetByKind[kind] = presetEntry

	return presetEntry
end

function PresetsRegistry.getByIndex()
	return presetByIndex
end

return PresetsRegistry
