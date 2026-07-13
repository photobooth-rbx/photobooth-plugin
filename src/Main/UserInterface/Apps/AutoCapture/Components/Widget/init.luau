local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

local Properties = require(script.Properties)
local InstanceList = require(script.InstanceList)

local BUTTONS_HEIGHT = 38

local CAPTURE_ICON = assert(Lucide.GetAsset("camera", 16))
local CAPTURE_ALL_ICON = assert(Lucide.GetAsset("switch-camera", 16))

export type ListElement = InstanceList.ListElement<PVInstance>

export type Props = {
	OnCapture: () -> string?,
	OnCaptureAll: () -> string?,
	OnCancel: () -> (),
	OnListElementAdded: (ListElement) -> (),
	OnListElementSelected: (ListElement?) -> (),
	OnListElementRemoved: (ListElement) -> (),
	Controller: Controller.AutoCaptureController,
	CaptureRect: Rect,
	Disabled: boolean?,
}

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()
	local capturingState, setCapturingState = React.useState("None")
	local errorMessage, setErrorMessage = React.useState(function(): string?
		return nil
	end)

	local disabled = props.Disabled or capturingState ~= "None"

	local propertiesRef = React.useRef(nil)
	local propertiesAbsSize = Hooks.useRefProperty(propertiesRef, "AbsoluteSize", Vector2.zero)

	local animationRef = React.useRef(nil)
	local animationAbsSize = Hooks.useRefProperty(animationRef, "AbsoluteSize", Vector2.zero)

	local forceRender = Hooks.useUpdate()
	local listRef = React.useRef({} :: InstanceList.List<PVInstance>)
	local nList = #listRef.current

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = -1, -- Fixes dropdown issues
	}, {
		Overlay = capturingState ~= "None" and React.createElement("Frame", {
			BackgroundTransparency = 0.7,
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			LoadingDots = React.createElement(StudioComponents.LoadingDots, {}),
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -BUTTONS_HEIGHT),
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),

			Properties = React.createElement(Properties, {
				Controller = props.Controller,
				CaptureRect = props.CaptureRect,
				Disabled = disabled,
				LayoutOrder = 1,
				ref = propertiesRef,
			}),

			InstanceList = React.createElement(InstanceList, {
				Size = UDim2.new(1, 0, 1, -(propertiesAbsSize.Y + animationAbsSize.Y)),

				ForceRender = forceRender,
				ListRef = listRef,

				OnListElementAdded = props.OnListElementAdded,
				OnListElementSelected = props.OnListElementSelected,
				OnListElementRemoved = props.OnListElementRemoved,

				FilterSelection = function(instance)
					return if instance:IsA("PVInstance") then instance else nil
				end,

				Disabled = disabled,
				LayoutOrder = 3,
			}),
		}),

		Buttons = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, BUTTONS_HEIGHT),
			ClipsDescendants = true,
			ZIndex = 3,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 4),
			}),
			UIListLayout = React.createElement("UIListLayout", {
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				HorizontalFlex = Enum.UIFlexAlignment.Fill,
				FillDirection = Enum.FillDirection.Horizontal,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),

			CaptureButtons = capturingState ~= "CaptureAll" and React.createElement(React.Fragment, nil, {
				CaptureAll = React.createElement(StudioComponents.Button, {
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = "Capture All",
					Disabled = nList == 0 or disabled,
					LayoutOrder = 1,

					OnActivated = function()
						setErrorMessage(nil)
						setCapturingState("CaptureAll")
						local err = props.OnCaptureAll()
						setCapturingState("None")
						setErrorMessage(err)
					end,

					Icon = {
						Image = CAPTURE_ALL_ICON.Url,
						RectSize = CAPTURE_ALL_ICON.ImageRectSize,
						RectOffset = CAPTURE_ALL_ICON.ImageRectOffset,
						Size = Vector2.new(CAPTURE_ALL_ICON.ImageRectSize.X, CAPTURE_ALL_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},
				}),

				Capture = React.createElement(StudioComponents.MainButton, {
					Size = UDim2.fromScale(1, 1),
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = "Capture",
					Disabled = nList == 0 or disabled,
					LayoutOrder = 2,

					OnActivated = function()
						setErrorMessage(nil)
						setCapturingState("Capture")
						local err = props.OnCapture()
						setCapturingState("None")
						setErrorMessage(err)
					end,

					Icon = {
						Image = CAPTURE_ICON.Url,
						RectSize = CAPTURE_ICON.ImageRectSize,
						RectOffset = CAPTURE_ICON.ImageRectOffset,
						Size = Vector2.new(CAPTURE_ICON.ImageRectSize.X, CAPTURE_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},
				}),
			}),

			CancelButton = capturingState == "CaptureAll" and React.createElement(StudioComponents.Button, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "Cancel",
				Disabled = props.Disabled,
				LayoutOrder = 1,

				OnActivated = function()
					props.OnCancel()
				end,
			}),
		}),

		ErrorMessage = errorMessage ~= nil and React.createElement("Frame", {
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			BorderSizePixel = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 0, 1, -BUTTONS_HEIGHT),
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			ZIndex = 3,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 8),
				PaddingRight = UDim.new(0, 8),
				PaddingTop = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				HorizontalAlignment = Enum.HorizontalAlignment.Right,
				Padding = UDim.new(0, 6),
			}),

			Message = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, 0),
				AutomaticSize = Enum.AutomaticSize.Y,
				FontFace = Font.fromName("SourceSansPro"),
				Text = errorMessage,
				TextSize = 14,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.ErrorText),
				LayoutOrder = 1,
			}),

			Dismiss = React.createElement(StudioComponents.Button, {
				Size = UDim2.new(0, 76, 0, 22),
				Text = "Dismiss",
				LayoutOrder = 2,

				OnActivated = function()
					setErrorMessage(nil)
				end,
			}),
		}),
	})
end

return Widget
