local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local effectsRoot = script:FindFirstAncestor("Effects")
local EffectsRegistry = require(effectsRoot.EffectsRegistry)
local InnerGlow = require(script.Parent)

type InnerGlowEffect = EffectsRegistry.Effect<InnerGlow.Properties>
export type Props = EffectsRegistry.EffectProps<InnerGlow.Properties>

local function InnerGlowEffect(props: Props)
	return React.createElement(React.Fragment, nil, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Size = React.createElement(StudioProperties.Number, {
			FieldName = "Size",

			Step = 1,
			Min = 0,

			Value = props.Effect.properties.size,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.size = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 1,
		}),

		Falloff = React.createElement(StudioProperties.Number, {
			FieldName = "Falloff",

			Min = 0.1,

			Value = props.Effect.properties.falloff,
			OnValueSubmitted = function(newValue)
				props.UpdateEffect(function(layer)
					layer.properties.falloff = newValue
					layer.renderTicket += 1
					return layer
				end)
			end,

			Disabled = props.Disabled,
			LayoutOrder = 2,
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
			LayoutOrder = 3,
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
			LayoutOrder = 4,
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
			LayoutOrder = 5,
		}),
	})
end

return InnerGlowEffect
