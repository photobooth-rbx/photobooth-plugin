local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local CroppedViewport = require(script.Parent)

CreateStory.theme(function(props)
	local isDisabled, setIsDisabled = React.useState(false)

	return React.createElement(CroppedViewport, {
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
