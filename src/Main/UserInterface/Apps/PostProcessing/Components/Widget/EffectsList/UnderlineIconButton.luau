local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local ICON_SIZE = 16

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Icon: typeof(assert(Lucide.GetAsset("", 16))),
	Text: string,
	OnActivated: (() -> ())?,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,
}

local function UnderlineIconButton(props: Props)
	local theme = StudioComponents.useTheme()
	local isHovering, setIsHovering = React.useState(false)
	local isSelected, setIsSelected = React.useState(false)

	if props.Disabled then
		isHovering = false
	end

	local inputObjectRef = React.useRef(nil :: InputObject?)
	React.useEffect(function()
		local connection
		if isSelected and inputObjectRef.current then
			connection = inputObjectRef.current:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if inputObjectRef.current.UserInputState == Enum.UserInputState.End then
					setIsSelected(false)
				end
			end)
		end

		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { isSelected })

	local color = theme:GetColor(
		Enum.StudioStyleGuideColor.MainText,
		if props.Disabled
			then Enum.StudioStyleGuideModifier.Disabled
			elseif isSelected then Enum.StudioStyleGuideModifier.Selected
			elseif isHovering then Enum.StudioStyleGuideModifier.Hover
			else Enum.StudioStyleGuideModifier.Default
	)

	return React.createElement("TextButton", {
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		Text = "",
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size or UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,

		[React.Event.InputBegan] = function(_, input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				inputObjectRef.current = input
				setIsSelected(true)
			end
		end,

		[React.Event.MouseEnter] = function()
			setIsHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setIsHovering(false)
		end,

		[React.Event.Activated] = function()
			if not props.Disabled and props.OnActivated then
				props.OnActivated()
			end
		end,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),

		Icon = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			Image = props.Icon.Url,
			ImageRectSize = props.Icon.ImageRectSize,
			ImageRectOffset = props.Icon.ImageRectOffset,
			ImageColor3 = color,
			LayoutOrder = 1,
		}),

		Label = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
			RichText = true,
			TextSize = 14,
			Text = if isHovering then `<u>{props.Text}</u>` else props.Text,
			TextColor3 = color,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 2,
		}),
	})
end

return UnderlineIconButton
