local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local Gallery = require(script.Parent)

return CreateStory.theme(function(props)
	local theme = StudioComponents.useTheme()
	local backgroundType, setBackgroundType = React.useState("Checkerboard")
	local isExpanded, setIsExpanded = React.useState(true)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 600),
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Widget = React.createElement(Gallery, {
			IsExpanded = isExpanded,
			SetIsExpanded = setIsExpanded,

			BackgroundType = backgroundType,
			SetBackgroundType = setBackgroundType,

			TryUpload = function(i, _, _, creator)
				task.wait(1)
				return i
			end,
			TestCreator = function(creator)
				print("testing creator", creator)
				task.wait(0.5)
				return creator.Id > 0
			end,
			OnUploadComplete = function(completed)
				print(completed)
			end,

			Disabled = not not props.Disabled,
		}),
	})
end)
