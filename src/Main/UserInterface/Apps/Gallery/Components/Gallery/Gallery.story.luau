local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)

local Gallery = require(script.Parent)

local function Widget(props: { Size: UDim2, Disabled: boolean? })
	local theme = StudioComponents.useTheme()
	local backgroundType, setBackgroundType = React.useState("Checkerboard")
	local isExpanded, setIsExpanded = React.useState(true)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Widget = React.createElement(Gallery, {
			IsExpanded = isExpanded,
			SetIsExpanded = setIsExpanded,

			BackgroundType = backgroundType,
			SetBackgroundType = setBackgroundType,

			TryUpload = function(i)
				task.wait(1)
				return i
			end,
			OnUploadComplete = function(completed)
				print(completed)
			end,

			OnImport = function()
				print("Import!")
			end,

			Disabled = not not props.Disabled,
		}),
	})
end

return CreateStory.theme(function(props)
	local selectedTab, setSelectedTab = React.useState("Small")

	return React.createElement(StudioComponents.TabContainer, {
		SelectedTab = selectedTab,
		OnTabSelected = setSelectedTab,
	}, {
		["Small"] = {
			LayoutOrder = 1,
			Content = React.createElement(Widget, {
				Size = UDim2.fromOffset(500, 350),
				Disabled = props.Disabled,
			}),
		},
		["Medium"] = {
			LayoutOrder = 2,
			Content = React.createElement(Widget, {
				Size = UDim2.fromScale(0.5, 0.5),
				Disabled = props.Disabled,
			}),
		},
		["Large"] = {
			LayoutOrder = 3,
			Content = React.createElement(Widget, {
				Size = UDim2.new(1, -30, 1, -30),
				Disabled = props.Disabled,
			}),
		},
	})
end)
