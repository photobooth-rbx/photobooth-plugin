local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local EYE_ICON = assert(Lucide.GetAsset("eye", 16))
local EYE_OFF_ICON = assert(Lucide.GetAsset("eye-off", 16))

local TRASH_ICON = assert(Lucide.GetAsset("trash", 16))

export type Props = {
	Title: string,
	IsVisible: boolean,
	IsSelected: boolean,

	OnSelected: (() -> ())?,
	OnVisibilityToggled: (() -> ())?,
	OnDelete: (() -> ())?,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,
}

local function Layer(props: Props)
	local theme = StudioComponents.useTheme()

	local mainBackground = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	local backgroundColor = if props.IsSelected
		then theme
			:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder, Enum.StudioStyleGuideModifier.Selected)
			:Lerp(mainBackground, 0.9)
		else mainBackground

	return React.createElement("Frame", {
		Active = true,
		BackgroundColor3 = backgroundColor,
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		Size = UDim2.new(1, 0, 0, 32),
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,

		[React.Event.InputBegan] = function(_, input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 and props.OnSelected then
				props.OnSelected()
			end
		end,
	}, {
		UIPadding = React.createElement("UIPadding", {
			PaddingTop = UDim.new(0, 4),
			PaddingBottom = UDim.new(0, 4),
			PaddingLeft = UDim.new(0, 4 + 22 + 4),
			PaddingRight = UDim.new(0, 4),
		}),

		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),

		Visibility = React.createElement(LucideIconButton, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(22, 22),
			IconSize = UDim2.fromOffset(14, 14),
			Icon = if props.IsVisible then EYE_ICON else EYE_OFF_ICON,
			Disabled = props.Disabled,
			LayoutOrder = 1,

			OnActivated = function()
				if props.OnVisibilityToggled then
					props.OnVisibilityToggled()
				end
			end,
		}),

		Title = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -52, 1, 0),
			FontFace = Font.fromName("SourceSansPro"),
			TextYAlignment = Enum.TextYAlignment.Center,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextColor3 = theme:GetColor(
				Enum.StudioStyleGuideColor.MainText,
				if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
			),
			Text = props.Title,
			TextSize = 14,
			LayoutOrder = 2,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),
		}),

		Delete = React.createElement(LucideIconButton, {
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.fromScale(0, 0.5),
			Size = UDim2.fromOffset(22, 22),
			IconSize = UDim2.fromOffset(14, 14),
			Icon = TRASH_ICON,
			Disabled = props.Disabled,
			LayoutOrder = 3,

			OnActivated = function()
				if props.OnDelete then
					props.OnDelete()
				end
			end,
		}),
	})
end

return Layer
