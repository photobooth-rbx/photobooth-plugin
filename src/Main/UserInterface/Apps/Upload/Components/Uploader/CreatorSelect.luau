local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local React = require(pluginRoot.Packages.React)

type Props = {
	Creator: string,
	SetCreator: (string) -> (),

	GroupId: number,
	SetGroupId: (number) -> (),

	GroupError: string?,

	Disabled: boolean,
}

local function useCreatorTargets()
	return { "Me", "Group" }
end

local function CreatorSelect(props: Props)
	local theme = StudioComponents.useTheme()
	local creatorTargets = useCreatorTargets()

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, -152, 1, 0),
		Position = UDim2.fromOffset(4, 0),
	}, {
		SizeConstraint = React.createElement("UISizeConstraint", {
			MaxSize = Vector2.new(200, math.huge),
		}),
		Layout = React.createElement("UIListLayout", {
			SortOrder = Enum.SortOrder.LayoutOrder,
			FillDirection = Enum.FillDirection.Horizontal,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			Padding = UDim.new(0, 4),
		}),

		Inputs = not props.GroupError and React.createElement(React.Fragment, nil, {
			Label = React.createElement(StudioComponents.Label, {
				BackgroundTransparency = 1,
				Size = UDim2.new(0, 44, 1, 0),
				Text = "Creator:",
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				LayoutOrder = 1,
			}),

			Container = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -48, 0, StudioComponents.Constants.DefaultDropdownHeight),
				LayoutOrder = 2,
			}, {
				Layout = React.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Horizontal,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Left,
					Padding = UDim.new(0, 4),
				}),

				Dropdown = React.createElement(StudioComponents.Dropdown, {
					LayoutOrder = 1,
					Disabled = props.Disabled,
					Size = UDim2.fromScale(0.4, 1),
					Items = creatorTargets,
					SelectedItem = props.Creator,
					OnItemSelected = function(item)
						props.SetCreator(item :: string)
					end,
				}),

				Input = props.Creator == "Group" and React.createElement("Frame", {
					BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
					BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
					Size = UDim2.new(0.5, -4, 1, 0),
					LayoutOrder = 2,
				}, {
					Box = React.createElement(StudioProperties.NumberBox, {
						Disabled = props.Disabled,
						Size = UDim2.fromScale(1, 1),
						HighlightOnFocus = true,
						HighlightMode = "TextboxFocused",

						Min = 0,
						Step = 1,
						StepButtonsDisabled = true,

						Value = props.GroupId,
						OnValueSubmitted = function(groupId)
							props.SetGroupId(groupId)
						end,
					}),
				}),
			}),
		}),

		Error = props.GroupError and React.createElement("TextLabel", {
			ZIndex = 5,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 0, -4),
			Size = UDim2.new(1, -4, 0, StudioComponents.Constants.DefaultTextSize + 8),

			Text = props.GroupError,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ErrorText),
			TextSize = StudioComponents.Constants.DefaultTextSize,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Font = StudioComponents.Constants.DefaultFont,

			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ErrorText),
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
				PaddingTop = UDim.new(0, 2),
				PaddingBottom = UDim.new(0, 2),
			}),
		}),
	})
end

return CreatorSelect
