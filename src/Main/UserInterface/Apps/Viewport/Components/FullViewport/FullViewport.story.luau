local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local FullViewport = require(script.Parent)

return CreateStory.theme(function(props)
	local isDisabled, setIsDisabled = React.useState(false)
	local focusLenseSizeRef = React.useRef(Rect.new(0, 0, 0, 0))

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 0, 1, 0),
		BackgroundTransparency = 1,
	}, {
		FullViewport = React.createElement(FullViewport, {
			ScaleOS = Vector2.new(1, 1),
			IsRectRequest = false,

			OnMinimize = function()
				print("Minimize")
			end,

			OnCapture = function(rect)
				setIsDisabled(true)
				print(focusLenseSizeRef.current)
				print(table.concat({
					"",
					"Viewport Capture",
					`> Rect: {rect}`,
					`> Size: ({rect.Width}, {rect.Height})`,
				}, "\n"))
				task.wait(1)
				setIsDisabled(false)
				return true
			end,

			Visible = true,
			Disabled = isDisabled or not not props.Disabled,
		}),
	})
end)
