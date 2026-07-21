local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local OverlayLayer = require(script.OverlayLayer)

local MENU_WIDTH = 150
local ITEM_HEIGHT = 22
local ICON_SIZE = 16
local CHECK_WIDTH = 14
local VERTICAL_PADDING = 0

export type Item = {
	Text: string,
	Icon: string,
	Selected: boolean,
	OnActivated: () -> (),
}

type ItemProps = {
	Text: string,
	Icon: string,
	Selected: boolean,
	OnActivated: () -> (),
	LayoutOrder: number?,
}

local function MenuItem(props: ItemProps)
	local theme = StudioComponents.useTheme()
	local isHovering, setIsHovering = React.useState(false)

	local textColor = theme:GetColor(
		Enum.StudioStyleGuideColor.MainText,
		if isHovering then Enum.StudioStyleGuideModifier.Hover else Enum.StudioStyleGuideModifier.Default
	)

	return React.createElement("TextButton", {
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Button, Enum.StudioStyleGuideModifier.Hover),
		BackgroundTransparency = if isHovering then 0 else 1,
		BorderSizePixel = 0,
		AutoButtonColor = false,
		Text = "",
		Size = UDim2.new(1, 0, 0, ITEM_HEIGHT),
		LayoutOrder = props.LayoutOrder,

		[React.Event.MouseEnter] = function()
			setIsHovering(true)
		end,
		[React.Event.MouseLeave] = function()
			setIsHovering(false)
		end,
		[React.Event.Activated] = function()
			props.OnActivated()
		end,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Horizontal,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Center,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 4),
		}),
		UIPadding = React.createElement("UIPadding", {
			PaddingLeft = UDim.new(0, 6),
			PaddingRight = UDim.new(0, 6),
		}),

		Check = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(CHECK_WIDTH, ITEM_HEIGHT),
			FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
			Text = if props.Selected then "✓" else "",
			TextSize = 14,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 1,
		}),

		Icon = React.createElement("ImageLabel", {
			BackgroundTransparency = 1,
			Size = UDim2.fromOffset(ICON_SIZE, ICON_SIZE),
			Image = props.Icon,
			LayoutOrder = 2,
		}),

		Label = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			AutomaticSize = Enum.AutomaticSize.X,
			Size = UDim2.new(0, 0, 1, 0),
			FontFace = Font.fromName("SourceSansPro"),
			Text = props.Text,
			TextSize = 14,
			TextColor3 = textColor,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			LayoutOrder = 3,
		}),
	})
end

export type Props = {
	Origin: Vector2,
	Items: { Item },
	OnClose: () -> (),
	ZIndex: number?,
}

local function OverlayMenu(props: Props)
	local theme = StudioComponents.useTheme()
	local overlayMenuFrame = OverlayLayer.useTarget()
	local containerSize = overlayMenuFrame.AbsoluteSize

	local menuHeight = #props.Items * ITEM_HEIGHT + VERTICAL_PADDING * 2
	local x = math.clamp(props.Origin.X, 0, math.max(0, containerSize.X - MENU_WIDTH))
	local y = math.clamp(props.Origin.Y, 0, math.max(0, containerSize.Y - menuHeight))

	local itemElements: { [string]: React.ReactNode } = {}
	for i, item in props.Items do
		itemElements["Item" .. i] = React.createElement(MenuItem, {
			Text = item.Text,
			Icon = item.Icon,
			Selected = item.Selected,
			OnActivated = item.OnActivated,
			LayoutOrder = i,
		})
	end

	return ReactRoblox.createPortal(
		React.createElement("Frame", {
			Active = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = props.ZIndex,

			[React.Event.InputBegan] = function(_rbx: GuiObject, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 then
					props.OnClose()
				end
			end,
		}, {
			DropShadow = React.createElement(StudioComponents.DropShadowFrame, {
				Position = UDim2.fromOffset(x, y),
				Size = UDim2.fromOffset(MENU_WIDTH, menuHeight),
			}, {
				Menu = React.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
					BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				}, {
					UIPadding = React.createElement("UIPadding", {
						PaddingTop = UDim.new(0, VERTICAL_PADDING),
						PaddingBottom = UDim.new(0, VERTICAL_PADDING),
					}),
					UIListLayout = React.createElement("UIListLayout", {
						FillDirection = Enum.FillDirection.Vertical,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 0),
					}),

					Items = React.createElement(React.Fragment, nil, itemElements),
				}),
			}),
		}),
		overlayMenuFrame
	)
end

export type Controls = {
	origin: Vector2?,
	open: (screenPosition: Vector2) -> (),
	close: () -> (),
}

-- Manages the open/closed state of a context menu and converts an absolute screen
-- position (e.g. from an InputObject) into a position relative to the overlay layer,
-- which is what OverlayMenu expects for its `Origin` prop.
local function useContextMenu(): Controls
	local overlayMenuFrame = OverlayLayer.useTarget()
	local origin, setOrigin = React.useState(nil :: Vector2?)

	local open = React.useCallback(function(screenPosition: Vector2)
		setOrigin(screenPosition - overlayMenuFrame.AbsolutePosition)
	end, { overlayMenuFrame } :: { any })

	local close = React.useCallback(function()
		setOrigin(nil :: any)
	end, {})

	return {
		origin = origin,
		open = open,
		close = close,
	}
end

return {
	component = OverlayMenu,
	useTarget = OverlayLayer.useTarget,
	useContextMenu = useContextMenu,
	provider = OverlayLayer.provider,
}
