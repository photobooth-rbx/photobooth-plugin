local EffectsRegistry = {}

export type ImageInputs = {
	img: EditableImage,
	svf: EditableImage,
	scratch: EditableImage,
	output: EditableImage,
}

export type Effect<Properties> = {
	kind: string,
	name: string,
	index: number,
	renderTicket: number,
	properties: Properties,
}

export type EffectProps<Properties> = {
	Effect: Effect<Properties>,
	UpdateEffect: ((Effect<Properties>) -> Effect<Properties>) -> (),
	Disabled: boolean?,
}

export type Registration<Properties> = {
	renderAboveBase: boolean?,
	create: () -> Properties,
	render: (ImageInputs, Properties) -> (),
}

local effectByIndex = {}
local effectByKind = {}

function EffectsRegistry.register<Properties>(kind: string, registration: Registration<Properties>)
	local effectEntry = {
		kind = kind,
		index = #effectByIndex + 1,
		renderAboveBase = registration.renderAboveBase or false,

		create = registration.create,
		render = registration.render,
	}

	table.insert(effectByIndex, effectEntry)
	effectByKind[kind] = effectEntry

	return effectEntry
end

function EffectsRegistry.getByKind(kind: string)
	return effectByKind[kind]
end

local cachedKinds: { string }
function EffectsRegistry.getKinds()
	if not cachedKinds then
		local kinds = {}
		for _, effectEntry in effectByIndex do
			table.insert(kinds, effectEntry.kind)
		end
		table.freeze(kinds)
		cachedKinds = kinds
	end
	return cachedKinds
end

return EffectsRegistry
