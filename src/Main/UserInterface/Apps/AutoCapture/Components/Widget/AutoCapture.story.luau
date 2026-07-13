local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)
local Hooks = require(uiRoot.Hooks)

local AutoCaptureRoot = script:FindFirstAncestor("AutoCapture")
local Controller = require(AutoCaptureRoot.Controller)

local Widget = require(script.Parent)

local function Component(props: { Size: UDim2, Disabled: boolean? })
	local theme = StudioComponents.useTheme()
	local disabled, setDisabled = React.useState(false)

	local controller = Hooks.useConstant(function()
		return Controller.new()
	end)

	React.useEffect(function()
		return function()
			controller:Destroy()
		end
	end, {})

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Core = React.createElement(Widget, {
			OnCapture = function()
				setDisabled(true)
				task.wait(1)
				setDisabled(false)
				return nil :: string?
			end,
			OnCaptureAll = function()
				setDisabled(true)
				task.wait(1)
				setDisabled(false)
				return nil :: string?
			end,
			OnCancel = function() end,
			OnListElementAdded = function() end,
			OnListElementSelected = function() end,
			OnListElementRemoved = function() end,
			Controller = controller,
			CaptureRect = Rect.new(0, 0, 0, 0),
			Disabled = props.Disabled or disabled,
		}),
	})
end

return CreateStory.theme(function(props)
	return React.createElement(Component, {
		Size = UDim2.fromOffset(260, 650),
		Disabled = props.Disabled,
	})
end)
