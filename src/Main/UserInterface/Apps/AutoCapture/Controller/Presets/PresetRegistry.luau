local PresetsRegistry = {}

export type StateSpec = {
	alphaBleed: boolean?,
	captureType: string?,

	isFullScreen: boolean?,
	captureDelay: number?,
	captureSize: Vector2?,

	fov: number?,
	fitType: string?,
	tryUseMeshVertices: boolean?,
	distanceScale: number?,

	paddingVisible: boolean?,
	paddingUniform: boolean?,
	padding: number?,
	paddingTop: number?,
	paddingRight: number?,
	paddingBottom: number?,
	paddingLeft: number?,
}

export type PresetSpec = {
	name: string,
	yaw: number?,
	pitch: number?,
	renderCF: CFrame?,
	dynamicState: StateSpec?,
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
