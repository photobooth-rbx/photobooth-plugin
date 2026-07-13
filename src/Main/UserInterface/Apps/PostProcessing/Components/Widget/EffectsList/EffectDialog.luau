local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)
local Effects = require(postProcessingRoot.Effects)

type TextInputProps = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	FieldName: string,
	Value: string,
	OnValueSubmitted: (string) -> ()?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,

	children: React.ReactNode?,
}

local function TextInput(props: TextInputProps)
	local theme = StudioComponents.useTheme()
	local isFocused, setIsFocused = React.useState(false)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
	}, {
		Left = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.225, 1),
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
			Label = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Font.fromName("SourceSansPro"),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.MainText,
					if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
				),
				Text = props.FieldName,
				TextSize = 14,
			}),
		}),
		Right = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.225, 0),
			Size = UDim2.fromScale(1 - 0.225, 1),
		}, {
			UIStroke = React.createElement("UIStroke", {
				Thickness = 1,
				Transparency = 0,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				BorderStrokePosition = Enum.BorderStrokePosition.Inner,
				LineJoinMode = Enum.LineJoinMode.Miter,
				Color = theme:GetColor(
					Enum.StudioStyleGuideColor.InputFieldBorder,
					if isFocused then Enum.StudioStyleGuideModifier.Selected else Enum.StudioStyleGuideModifier.Default
				),
			}),

			InputFrame = React.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -4, 1, -4),
			}, {
				Input = React.createElement(StudioProperties.StringBox, {
					Size = UDim2.fromScale(1, 1),

					Value = props.Value,
					OnValueSubmitted = props.OnValueSubmitted,

					OnFocus = function()
						setIsFocused(true)
					end,
					OnFocusLost = function()
						setIsFocused(false)
					end,

					HighlightOnFocus = true,
					Disabled = props.Disabled,
				}),
			}),
		}),
	})
end

type DropdownInputProps = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	FieldName: string,
	Value: string,
	List: { string },
	OnValueSubmitted: (string) -> ()?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,

	children: React.ReactNode?,
}

local function DropdownInput(props: DropdownInputProps)
	local theme = StudioComponents.useTheme()
	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
	}, {
		Left = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(0.225, 1),
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
			Label = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				FontFace = Font.fromName("SourceSansPro"),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.MainText,
					if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
				),
				Text = props.FieldName,
				TextSize = 14,
			}),
		}),
		Right = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromScale(0.225, 0),
			Size = UDim2.fromScale(1 - 0.225, 1),
		}, {
			Dropdown = React.createElement(StudioComponents.Dropdown, {
				Size = UDim2.fromScale(1, 1),
				Items = props.List,
				SelectedItem = props.Value,
				OnItemSelected = function(newPick)
					if props.OnValueSubmitted then
						props.OnValueSubmitted(newPick :: string)
					end
				end,
			}),
		}),
	})
end

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Controller: Controller.PostProcessingController,

	OnConfirm: (string, string) -> ()?,
	OnCancel: () -> ()?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function EffectDialog(props: Props)
	local theme = StudioComponents.useTheme()
	local effectType, setEffectType = React.useState(Effects.getKinds()[1])
	local name, setName = React.useState(effectType)

	return React.createElement("Frame", {
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,

		ZIndex = props.ZIndex,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 11),
			PaddingRight = UDim.new(0, 6),
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 8),
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -30),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 10),
			}),

			NameInput = React.createElement(TextInput, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 0, 22),
				FieldName = "Name",
				Value = name,
				OnValueSubmitted = setName,
			}, {
				Input = React.createElement(StudioProperties.StringBox, {
					Size = UDim2.fromScale(1, 1),
					Value = "",
				}),
			}),

			TypeInput = React.createElement(DropdownInput, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 0, 22),
				FieldName = "Type",
				List = Effects.getKinds(),
				Value = effectType,
				OnValueSubmitted = function(newPick)
					setEffectType(newPick)
					setName(newPick)
				end,
			}, {
				Input = React.createElement(StudioProperties.StringBox, {
					Size = UDim2.fromScale(1, 1),
					Value = "",
				}),
			}),
		}),

		Buttons = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 26),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Horizontal,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
			}),

			Cancel = React.createElement(StudioComponents.Button, {
				Size = UDim2.new(0, 76, 1, 0),
				Text = "Cancel",
				LayoutOrder = -1,

				OnActivated = props.OnCancel,

				Disabled = props.Disabled,
			}),

			Confirm = React.createElement(StudioComponents.MainButton, {
				Size = UDim2.new(0, 76, 1, 0),
				Text = "Confirm",
				LayoutOrder = -2,

				OnActivated = function()
					if props.OnConfirm then
						props.OnConfirm(name, effectType)
					end
				end,

				Disabled = props.Disabled,
			}),
		}),
	})
end

return EffectDialog
