local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local SPLIT_CURSOR = "rbxasset://SystemCursors/SplitEW"

export type Props = {
	AnchorPoint: Vector2,
	Position: UDim2,
	Size: UDim2,

	LineOffset: number,

	OnDragStart: (absoluteX: number) -> (),
	OnDrag: (absoluteX: number) -> (),

	ZIndex: number?,
	Disabled: boolean,
}

local function SplitDivider(props: Props)
	local theme = StudioComponents.useTheme()
	local mouseIcon = StudioComponents.useMouseIcon()

	local hovered, setHovered = React.useState(false)

	local dragger = Hooks.useMouseDrag({
		onDragCallback = function(_rbx, input)
			props.OnDrag(input.Position.X)
		end,
		onBeganCallback = function(_rbx, input)
			props.OnDragStart(input.Position.X)
		end,
		deps = { props.OnDrag },
	})

	local isDragging = dragger.isActive()

	React.useEffect(function()
		if props.Disabled and isDragging then
			dragger.cancel()
		end
	end, { props.Disabled, isDragging } :: { any })

	React.useEffect(function()
		if (hovered or isDragging) and not props.Disabled then
			mouseIcon.setIcon(SPLIT_CURSOR)
		else
			mouseIcon.clearIcon()
		end
	end, { mouseIcon, hovered, isDragging, props.Disabled } :: { any })

	local function onInputBegan(rbx: GuiObject, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setHovered(true)
		end
		if not props.Disabled then
			dragger.onInputBegan(rbx, input)
		end
	end

	local function onInputChanged(rbx: GuiObject, input: InputObject)
		if not props.Disabled then
			dragger.onInputChanged(rbx, input)
		end
	end

	local function onInputEnded(rbx: GuiObject, input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			setHovered(false)
		end
		if not props.Disabled then
			dragger.onInputEnded(rbx, input)
		end
	end

	return React.createElement("Frame", {
		Active = true,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		ZIndex = props.ZIndex,

		[React.Event.InputBegan] = onInputBegan,
		[React.Event.InputChanged] = onInputChanged,
		[React.Event.InputEnded] = onInputEnded,
	}, {
		Highlight = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(props.LineOffset, 0),
			Size = UDim2.new(0, 1, 1, 0),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton),
			BorderSizePixel = 0,
			Visible = (hovered or isDragging) and not props.Disabled,
		}),
	})
end

return SplitDivider
