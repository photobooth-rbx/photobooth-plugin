local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local Stroke = require(script.Parent)

type DropShadowEffect = EffectsRegistry.Effect<Stroke.Properties>
export type Props = EffectsRegistry.EffectProps<Stroke.Properties>

local function StrokeEffect(props: Props)
	return React.createElement(React.Fragment, nil, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Thickness = React.createElement(StudioProperties.Number, {
			FieldName = "Thickness",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.thickness,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.thickness = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Softness = React.createElement(StudioProperties.Number, {
			FieldName = "Softness",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.softness,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.softness = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
		}),

		Clipped = React.createElement(StudioProperties.Boolean, {
			FieldName = "Clipped",

			Value = props.Effect.properties.clipped,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.clipped = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 3,
		}),

		Offset = React.createElement(StudioProperties.Vector2, {
			FieldName = "Offset",

			Value = props.Effect.properties.offset,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.offset = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 4,
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
			LayoutOrder = 5,
		}),

		Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Color",

			Value = props.Effect.properties.color,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.color = newValue
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 6,
		}),
	})
end

return StrokeEffect
