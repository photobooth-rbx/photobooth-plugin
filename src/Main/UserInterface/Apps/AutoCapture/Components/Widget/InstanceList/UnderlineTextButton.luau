local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Text: string,
	TextXAlignment: Enum.TextXAlignment?,
	TextYAlignment: Enum.TextYAlignment?,
	OnActivated: () -> ()?,

	ZIndex: number?,
	LayoutOrder: number?,
	Disabled: boolean?,

	children: React.ReactNode?,
}

local function UnderlineTextButton(props: Props)
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

	return React.createElement("TextButton", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,

		TextXAlignment = props.TextXAlignment,
		TextYAlignment = props.TextYAlignment,
		FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
		RichText = true,
		TextSize = 14,
		Text = if isHovering then `<u>{props.Text}</u>` else props.Text,
		TextColor3 = theme:GetColor(
			Enum.StudioStyleGuideColor.MainText,
			if props.Disabled
				then Enum.StudioStyleGuideModifier.Disabled
				elseif isSelected then Enum.StudioStyleGuideModifier.Selected
				elseif isHovering then Enum.StudioStyleGuideModifier.Hover
				else Enum.StudioStyleGuideModifier.Default
		),

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
	}, props.children)
end

return UnderlineTextButton
