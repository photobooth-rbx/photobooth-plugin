local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local ChromaticAberration = require(script.Parent)

type ChromaticAberrationEffect = EffectsRegistry.Effect<ChromaticAberration.Properties>
export type Props = EffectsRegistry.EffectProps<ChromaticAberration.Properties>

local function ChromaticAberrationEffect(props: Props)
	return React.createElement(React.Fragment, nil, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Strength = React.createElement(StudioProperties.Number, {
			FieldName = "Strength",

			Step = 0.5,
			Min = 0,

			Value = props.Effect.properties.strength,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.strength = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Angle = React.createElement(StudioProperties.Number, {
			FieldName = "Angle",

			Step = 1,

			Value = props.Effect.properties.angle,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.angle = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}),

		Transparency = React.createElement(StudioProperties.Number, {
			FieldName = "Transparency",

			Min = 0,
			Max = 1,

			Value = props.Effect.properties.transparency,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.transparency = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}),
	})
end

return ChromaticAberrationEffect
