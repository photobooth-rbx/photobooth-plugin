local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local PlaybackBar = require(script.PlaybackBar)
local DashedStroke = require(script.DashedStroke)

export type Props = {
	ScaleOS: Vector2,

	Resolution: Vector2,
	IsFullScreen: boolean,

	PaddingVisible: boolean,
	PaddingLeft: number,
	PaddingRight: number,
	PaddingTop: number,
	PaddingBottom: number,

	FocusOffset: Vector2?,

	AnimationTrack: AnimationTrack?,

	OnFocusRectChanged: (Rect) -> (),

	Disabled: boolean?,
}

local function Fitter(props: Props)
	local theme = StudioComponents.useTheme()

	local viewportRef = React.useRef(nil)
	local viewportAbsSize = Hooks.useRefProperty(viewportRef, "AbsoluteSize", Vector2.zero)
	local viewportAbsPosition = Hooks.useRefProperty(viewportRef, "AbsolutePosition", Vector2.zero)
	local viewportRect = Rect.new(viewportAbsPosition, viewportAbsSize)
	local viewportAbsCenter = viewportAbsSize / 2

	local scaledResolution = props.Resolution / props.ScaleOS
	local scaledResolutionRect =
		Rect.new(viewportAbsCenter - (scaledResolution / 2), viewportAbsCenter + (scaledResolution / 2))

	local focusOffset = not props.IsFullScreen and props.FocusOffset or Vector2.zero
	local focusRect = if props.IsFullScreen then viewportRect else scaledResolutionRect

	React.useEffect(function()
		props.OnFocusRectChanged(focusRect)
	end, { focusRect })

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
	}, {
		Focus = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = if props.IsFullScreen
				then UDim2.fromScale(1, 1)
				else UDim2.fromOffset(
					math.round(scaledResolutionRect.Width),
					math.round(scaledResolutionRect.Height)
				),
		}, {
			DashedStroke = React.createElement(DashedStroke, {
				Thickness = 2,
				Transparency = if focusOffset:Dot(focusOffset) == 0 then 1 else 0.3,
				DashLength = 8,
				GapLength = 6,
				Color = theme:GetColor(Enum.StudioStyleGuideColor.WarningText),
				BorderStrokePosition = Enum.BorderStrokePosition.Outer,
				ZIndex = 2,
			}),

			Padding = React.createElement("CanvasGroup", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				GroupTransparency = 0.7,
				GroupColor3 = Color3.new(0, 0, 0),
				Visible = props.PaddingVisible,
			}, {
				Top = React.createElement("Frame", {
					Size = UDim2.new(1, 0, 0, math.round(props.PaddingTop / props.ScaleOS.Y)),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
				Right = React.createElement("Frame", {
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, math.round(props.PaddingRight / props.ScaleOS.X), 1, 0),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
				Bottom = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, math.round(props.PaddingBottom / props.ScaleOS.Y)),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
				Left = React.createElement("Frame", {
					Size = UDim2.new(0, math.round(props.PaddingLeft / props.ScaleOS.X), 1, 0),
					BackgroundColor3 = Color3.new(1, 1, 1),
					BackgroundTransparency = 0,
					BorderSizePixel = 0,
				}),
			}),
		}),

		CaptureBox = React.createElement("Frame", {
			ZIndex = 2,
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, focusOffset.X, 0.5, focusOffset.Y),
			Size = if props.IsFullScreen
				then UDim2.fromScale(1, 1)
				else UDim2.fromOffset(
					math.round(scaledResolutionRect.Width),
					math.round(scaledResolutionRect.Height)
				),
		}, {
			UIStroke = React.createElement("UIStroke", {
				Thickness = 2,
				Transparency = 0.3,
				Color = theme:GetColor(
					Enum.StudioStyleGuideColor.InputFieldBorder,
					Enum.StudioStyleGuideModifier.Selected
				),
				BorderStrokePosition = if props.IsFullScreen
					then Enum.BorderStrokePosition.Inner
					else Enum.BorderStrokePosition.Outer,
				ZIndex = 2,
			}),

			UIStrokeBlinder = React.createElement("UIStroke", {
				Thickness = 100_000,
				Transparency = 0.7,
				Color = Color3.new(0, 0, 0),
			}),

			AnimationBar = React.createElement(PlaybackBar, {
				AnchorPoint = Vector2.new(0.5, 0),
				Position = UDim2.new(0.5, 0, 1, 8),
				Size = UDim2.new(0, 300, 0, 28),
				AnimationTrack = props.AnimationTrack,
				Disabled = props.Disabled,
			}),
		}),

		Viewport = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ref = viewportRef,
		}),
	})
end

return Fitter
