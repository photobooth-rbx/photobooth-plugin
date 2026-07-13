local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)
local Effects = require(postProcessingRoot.Effects)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local Layer = require(script.Layer)
local LutProperty = require(script.LutProperty)
local Effect = require(script.Effect)
local EffectDialog = require(script.EffectDialog)
local UnderlineIconButton = require(script.UnderlineIconButton)

local SCROLL_GRADIENT_INSET_HEIGHT = 22
local MIDDLE_BAR_HEIGHT = 22

local SPARKLES_ICON = assert(Lucide.GetAsset("sparkles", 16))
local PLUS_ICON = assert(Lucide.GetAsset("plus", 16))
local UP_ICON = assert(Lucide.GetAsset("chevron-up", 16))
local DOWN_ICON = assert(Lucide.GetAsset("chevron-down", 16))

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Controller: Controller.PostProcessingController,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

type Selection = {
	layerId: string,
	effectId: string?,
}

local function makeSelection(layerId: string, effectId: string?): Selection
	return {
		layerId = layerId,
		effectId = effectId,
	}
end

local function resolveSelection(selection: Selection?, layers: { Controller.Layer })
	local selectedLayer: Controller.Layer?
	local selectedEffect: Controller.LayerEffect?
	if selection then
		for _, layer in layers do
			if layer.id == selection.layerId then
				selectedLayer = layer
				if selection.effectId then
					for _, item in layer.effects do
						if item.id == selection.effectId then
							selectedEffect = item
							break
						end
					end
				end
				break
			end
		end
	end
	return selectedLayer, selectedEffect
end

local function LayerProperties(props: {
	Controller: Controller.PostProcessingController,
	SelectedLayer: Controller.Layer,
	Disabled: boolean?,
})
	local controller = props.Controller
	local selectedLayer = props.SelectedLayer
	local layerId = selectedLayer.id

	return React.createElement(React.Fragment, nil, {
		Name = React.createElement(StudioProperties.String, {
			FieldName = "Name",
			Value = selectedLayer.name,
			Disabled = props.Disabled,
			LayoutOrder = 1,

			OnValueSubmitted = function(newName)
				controller:setLayerName(layerId, newName)
			end,
		}),

		ShowBaseImage = React.createElement(StudioProperties.Boolean, {
			FieldName = "Visible",
			Value = selectedLayer.showBaseImage,
			Disabled = props.Disabled,
			LayoutOrder = 2,

			OnValueSubmitted = function(newValue)
				controller:setLayerShowBaseImage(layerId, newValue)
			end,
		}),

		Offset = React.createElement(StudioProperties.Vector2, {
			FieldName = "Offset",
			Value = selectedLayer.offset,
			Disabled = props.Disabled,
			LayoutOrder = 3,

			OnValueSubmitted = function(newValue)
				controller:setLayerOffset(layerId, newValue)
			end,
		}),

		Transparency = React.createElement(StudioProperties.Number, {
			FieldName = "Transparency",
			Min = 0,
			Max = 1,
			Value = selectedLayer.transparency,
			Disabled = props.Disabled,
			LayoutOrder = 4,

			OnValueSubmitted = function(newValue)
				controller:setLayerTransparency(layerId, newValue)
			end,
		}),

		Color = React.createElement(StudioProperties.Color3, {
			FieldName = "Tint Color",
			Value = selectedLayer.tintColor,
			Disabled = props.Disabled,
			LayoutOrder = 5,

			OnValueSubmitted = function(newValue)
				controller:setLayerTint(layerId, newValue)
			end,
		}),

		Brightness = React.createElement(StudioProperties.Number, {
			FieldName = "Brightness",
			Min = -1,
			Max = 1,
			Value = selectedLayer.brightness,
			Disabled = props.Disabled,
			LayoutOrder = 6,

			OnValueSubmitted = function(newValue)
				controller:setLayerBrightness(layerId, newValue)
			end,
		}),

		Contrast = React.createElement(StudioProperties.Number, {
			FieldName = "Contrast",
			Min = -1,
			Max = 1,
			Value = selectedLayer.contrast,
			Disabled = props.Disabled,
			LayoutOrder = 7,

			OnValueSubmitted = function(newValue)
				controller:setLayerContrast(layerId, newValue)
			end,
		}),

		Saturation = React.createElement(StudioProperties.Number, {
			FieldName = "Saturation",
			Min = -1,
			Max = 1,
			Value = selectedLayer.saturation,
			Disabled = props.Disabled,
			LayoutOrder = 8,

			OnValueSubmitted = function(newValue)
				controller:setLayerSaturation(layerId, newValue)
			end,
		}),

		Hue = React.createElement(StudioProperties.Number, {
			FieldName = "Hue",
			Step = 1,
			Min = -180,
			Max = 180,
			Value = selectedLayer.hue,
			Disabled = props.Disabled,
			LayoutOrder = 9,

			OnValueSubmitted = function(newValue)
				controller:setLayerHue(layerId, newValue)
			end,
		}),

		Lut = React.createElement(LutProperty, {
			Controller = controller,
			LayerId = layerId,
			Lut = selectedLayer.lut,
			Disabled = props.Disabled,
			LayoutOrder = 10,
		}),
	})
end

local function EffectsList(props: Props)
	local theme = StudioComponents.useTheme()
	local controller = props.Controller

	local layers = controller:useLayers()
	local thumbnails = controller:useThumbnails()
	local selection, setSelection = React.useState(if #layers > 0 then makeSelection(layers[1].id) else nil)
	local pendingLayerId, setPendingLayerId = React.useState(nil :: string?)

	local hasSelection = selection ~= nil
	local isDialogOpen = pendingLayerId ~= nil
	local selectedLayer, selectedEffect = resolveSelection(selection, layers)

	React.useEffect(function()
		if not selectedLayer and #layers > 0 then
			setSelection(makeSelection(layers[1].id))
		end
	end, { selectedLayer, layers } :: { unknown })

	local function moveSelected(step: number)
		if not selection then
			return
		end

		if selection.effectId then
			controller:moveEffect(selection.layerId, selection.effectId, step)
		else
			controller:moveLayer(selection.layerId, step)
		end
	end

	local layerNodes: { [string]: React.ReactNode } = {}
	for layerOrder, layer in layers do
		local thumbnailLayers = thumbnails[layer.id]

		local effectNodes: { [string]: React.ReactNode } = {}
		for effectOrder, item in layer.effects do
			effectNodes["Effect_" .. item.id] = React.createElement(Effect, {
				Title = item.effect.name,
				IsVisible = item.isVisible,
				IsSelected = selection ~= nil and selection.layerId == layer.id and selection.effectId == item.id,
				LayoutOrder = effectOrder,
				Disabled = props.Disabled,

				OnSelected = function()
					setSelection(makeSelection(layer.id, item.id))
				end,
				OnVisibilityToggled = function()
					controller:toggleEffectVisibility(layer.id, item.id)
				end,
				OnDelete = function()
					controller:removeEffect(layer.id, item.id)
					setSelection(function(current: Selection?): Selection?
						if current and current.layerId == layer.id and current.effectId == item.id then
							return nil
						end
						return current
					end)
				end,
			})
		end

		layerNodes["Layer_" .. layer.id] = React.createElement(Layer, {
			Title = layer.name,
			ThumbnailLayers = thumbnailLayers,
			IsVisible = layer.isVisible,
			IsSelected = selection ~= nil and selection.layerId == layer.id and selection.effectId == nil,
			IsExpanded = layer.isExpanded,
			LayoutOrder = layerOrder,
			Disabled = props.Disabled,

			OnSelected = function()
				setSelection(makeSelection(layer.id))
			end,
			OnVisibilityToggled = function()
				controller:toggleLayerVisibility(layer.id)
			end,
			OnExpandToggled = function()
				controller:toggleLayerExpanded(layer.id)
			end,
			OnDelete = function()
				controller:removeLayer(layer.id)
				setSelection(function(current: Selection?): Selection?
					if current and current.layerId == layer.id then
						return nil
					end
					return current
				end)
			end,
		}, effectNodes)
	end

	-- ScrollBottom properties

	local propertyFragment: React.ReactNode
	if selectedEffect and selection then
		local component = Effects.getReactComponentByKind(selectedEffect.effect.kind)
		local layerId, effectId = selection.layerId, selection.effectId :: string

		propertyFragment = React.createElement(React.Fragment, nil, {
			Name = React.createElement(StudioProperties.String, {
				FieldName = "Name",
				Value = selectedEffect.effect.name,
				Disabled = props.Disabled,
				LayoutOrder = 1,

				OnValueSubmitted = function(newName)
					controller:setEffectName(layerId, effectId, newName)
				end,
			}),

			Body = component and React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				LayoutOrder = 2,
			}, {
				Component = React.createElement(component, {
					Effect = selectedEffect.effect,
					Disabled = props.Disabled,
					UpdateEffect = function(transform)
						controller:updateEffect(layerId, effectId, transform)
					end,
				}),
			}),
		})
	elseif selectedLayer then
		propertyFragment = React.createElement(LayerProperties, {
			Controller = props.Controller,
			SelectedLayer = selectedLayer,
			Disabled = props.Disabled,
		})
	else
		propertyFragment = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 48),
			FontFace = Font.fromName("SourceSansPro"),
			Text = "Select a layer or effect to edit its properties.",
			TextSize = 14,
			TextWrapped = true,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled),
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
			}),
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			ScrollTop = React.createElement(StudioProperties.VerticalScroll, {
				Size = UDim2.new(1, 0, 0.5, -MIDDLE_BAR_HEIGHT / 2),
				GradientHeight = SCROLL_GRADIENT_INSET_HEIGHT,
				ScrollInset = UDim.new(0, -2),
				ScrollBarTransparency = 0.7,
				ScrollBarFades = true,
				LayoutOrder = 1,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				Layers = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 1,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),
				}, layerNodes),

				Padding = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
					LayoutOrder = 2,
				}),
			}),

			MiddleBar = React.createElement("Frame", {
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				Size = UDim2.new(1, 0, 0, MIDDLE_BAR_HEIGHT),
				LayoutOrder = 2,
			}, {
				Left = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),

					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Left,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 12),
					}),

					AddLayer = React.createElement(UnderlineIconButton, {
						Text = "Add Layer",
						Icon = PLUS_ICON,
						Disabled = props.Disabled,
						LayoutOrder = 1,
						OnActivated = function()
							setSelection(makeSelection(controller:addLayer()))
						end,
					}),

					AddEffect = React.createElement(UnderlineIconButton, {
						Text = "Add Effect",
						Icon = SPARKLES_ICON,
						Disabled = props.Disabled or not selectedLayer,
						LayoutOrder = 2,
						OnActivated = function()
							if selection then
								setPendingLayerId(selection.layerId)
							elseif layers[#layers] then
								setPendingLayerId(layers[#layers].id)
							end
						end,
					}),
				}),

				Right = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					UIPadding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),

					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Horizontal,
						HorizontalAlignment = Enum.HorizontalAlignment.Right,
						VerticalAlignment = Enum.VerticalAlignment.Center,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 2),
					}),

					MoveUp = React.createElement(LucideIconButton, {
						Size = UDim2.fromOffset(22, 22),
						IconSize = UDim2.fromOffset(14, 14),
						Icon = UP_ICON,
						Disabled = props.Disabled or not hasSelection,
						LayoutOrder = 4,
						OnActivated = function()
							moveSelected(-1)
						end,
					}),
					MoveDown = React.createElement(LucideIconButton, {
						Size = UDim2.fromOffset(22, 22),
						IconSize = UDim2.fromOffset(14, 14),
						Icon = DOWN_ICON,
						Disabled = props.Disabled or not hasSelection,
						LayoutOrder = 5,
						OnActivated = function()
							moveSelected(1)
						end,
					}),
				}),
			}),

			ScrollBottom = React.createElement(StudioProperties.VerticalScroll, {
				Size = UDim2.new(1, 0, 0.5, -MIDDLE_BAR_HEIGHT / 2),
				GradientHeight = SCROLL_GRADIENT_INSET_HEIGHT,
				ScrollInset = UDim.new(0, -2),
				ScrollBarTransparency = 0.7,
				ScrollBarFades = true,
				LayoutOrder = 3,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),

				Properties = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 0),
					AutomaticSize = Enum.AutomaticSize.Y,
					LayoutOrder = 1,
				}, {
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),

					Properties = propertyFragment,
				}),

				Padding = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, SCROLL_GRADIENT_INSET_HEIGHT),
					LayoutOrder = 2,
				}),
			}),
		}),

		Overlay = isDialogOpen and React.createElement("ImageButton", {
			BorderSizePixel = 0,
			BackgroundTransparency = 0.7,
			BackgroundColor3 = Color3.new(0, 0, 0),
			Size = UDim2.fromScale(1, 1),
			AutoButtonColor = false,
			Image = "",
		}, {
			Dialog = React.createElement(EffectDialog, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(220, 120),

				Controller = props.Controller,

				OnConfirm = function(name, kind)
					local targetLayerId = pendingLayerId
					setPendingLayerId(nil :: any)
					if not targetLayerId then
						return
					end

					local effectId = controller:addEffect(targetLayerId, kind, name)
					setSelection(makeSelection(targetLayerId, effectId))
				end,

				OnCancel = function()
					setPendingLayerId(nil :: any)
				end,
			}),
		}),
	})
end

return EffectsList
