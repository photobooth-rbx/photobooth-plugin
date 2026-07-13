local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	IconSize: UDim2?,
	Icon: typeof(assert(Lucide.GetAsset("", 16))),

	OnActivated: () -> ()?,
	OnMouseButton1Down: () -> ()?,
	OnMouseButton1Up: () -> ()?,

	GetImageColor: ((Enum.StudioStyleGuideModifier) -> Color3)?,

	LayoutOrder: number?,
	Disabled: boolean?,
}

local function LucideIconButton(props: Props)
	local theme = StudioComponents.useTheme()
	local isHovering, setIsHovering = React.useState(false)
	local isSelected, setIsSelected = React.useState(false)

	local modifier = if props.Disabled
		then Enum.StudioStyleGuideModifier.Disabled
		elseif isSelected then Enum.StudioStyleGuideModifier.Selected
		elseif isHovering then Enum.StudioStyleGuideModifier.Hover
		else Enum.StudioStyleGuideModifier.Default

	local inputObjectRef = React.useRef(nil :: InputObject?)
	React.useEffect(function()
		local connection
		if isSelected and inputObjectRef.current then
			local reconciled = false
			connection = inputObjectRef.current:GetPropertyChangedSignal("UserInputState"):Connect(function()
				if not reconciled and inputObjectRef.current.UserInputState == Enum.UserInputState.End then
					reconciled = true
					setIsSelected(false)
					if props.OnMouseButton1Up then
						props.OnMouseButton1Up()
					end
				end
			end)
		end

		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { isSelected, props.OnMouseButton1Up } :: { any })

	return React.createElement("ImageButton", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,

		[React.Event.InputBegan] = function(_, input: InputObject)
			if input.UserInputType == Enum.UserInputType.MouseButton1 then
				inputObjectRef.current = input
				setIsSelected(true)
				if props.OnMouseButton1Down then
					props.OnMouseButton1Down()
				end
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
		Icon = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.5, 0),
			Size = props.IconSize or UDim2.fromOffset(props.Icon.ImageRectSize.X, props.Icon.ImageRectSize.Y),
			Image = props.Icon.Url,
			ImageRectSize = props.Icon.ImageRectSize,
			ImageRectOffset = props.Icon.ImageRectOffset,
			ImageColor3 = if props.GetImageColor
				then props.GetImageColor(modifier)
				else theme:GetColor(Enum.StudioStyleGuideColor.MainText, modifier),
		}),
	})
end

return LucideIconButton
