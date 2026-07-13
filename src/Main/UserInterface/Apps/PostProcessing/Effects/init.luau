local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local EffectsRegistry = require(script.EffectsRegistry)

export type ImageInputs = EffectsRegistry.ImageInputs

type Props = EffectsRegistry.EffectProps<any>
type Registered = typeof(EffectsRegistry.register("", {} :: any))

local componentsByKind: { [string]: React.FC<Props> } = {}

local function requireAny(module: Instance?)
	return require(module) :: any
end

local function loadEffects(names: { string })
	for _, name in names do
		local module = script.EffectTypes:FindFirstChild(name) :: ModuleScript
		local entry = requireAny(module) :: Registered
		local component = requireAny(module:FindFirstChild("Component"))
		componentsByKind[entry.kind] = component
	end
end

loadEffects({
	"Stroke",
	"DropShadow",
	"OuterGlow",
	"InnerGlow",
	"InnerShadow",
	"ChromaticAberration",
})

return {
	getByKind = EffectsRegistry.getByKind,
	getKinds = EffectsRegistry.getKinds,
	getReactComponentByKind = function(kind: string)
		return componentsByKind[kind]
	end,
}
