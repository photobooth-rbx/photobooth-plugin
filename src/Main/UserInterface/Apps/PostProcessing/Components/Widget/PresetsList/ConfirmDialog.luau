local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	RichText: boolean?,
	Message: string,
	ConfirmText: string?,

	OnConfirm: (() -> ())?,
	OnCancel: (() -> ())?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,
}

local function ConfirmDialog(props: Props)
	local theme = StudioComponents.useTheme()

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

		Message = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -30),
			FontFace = Font.fromName("SourceSansPro"),
			RichText = props.RichText,
			Text = props.Message,
			TextSize = 14,
			TextWrapped = true,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			TextColor3 = theme:GetColor(
				Enum.StudioStyleGuideColor.MainText,
				if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
			),
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
				Text = props.ConfirmText or "Confirm",
				LayoutOrder = -2,

				OnActivated = props.OnConfirm,

				Disabled = props.Disabled,
			}),
		}),
	})
end

return ConfirmDialog
