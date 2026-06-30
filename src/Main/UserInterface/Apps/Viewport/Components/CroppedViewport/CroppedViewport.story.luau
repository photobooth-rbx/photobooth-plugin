local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local CroppedViewport = require(script.Parent)

return CreateStory.theme(function(props)
	local isDisabled, setIsDisabled = React.useState(false)
	local captureRectRef = React.useRef(Rect.new(0, 0, 512, 512))
	local updateCaptureRectRef = React.useCallback(function(rect: Rect)
		captureRectRef.current = rect
	end, {})

	return React.createElement(CroppedViewport, {
		ScaleOS = Vector2.new(1, 1),
		IsRectRequest = false,
		CaptureRectRef = captureRectRef,
		UpdateCaptureRectRef = updateCaptureRectRef,

		OnReady = function(viewport)
			local absPosition = viewport.AbsolutePosition
			local absSize = viewport.AbsoluteSize
			local center = absPosition + absSize / 2
			captureRectRef.current = Rect.new(center - absSize / 4, center + absSize / 4)
		end,

		OnMaximize = function()
			print("Maximize")
		end,

		OnCapture = function(rect)
			setIsDisabled(true)
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
	})
end)
