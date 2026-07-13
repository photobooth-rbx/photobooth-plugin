local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local CreateStory = require(uiRoot.Stories.CreateStory)
local Hooks = require(uiRoot.Hooks)

local Widget = require(script.Parent)

local function Component(props: { Size: UDim2, Disabled: boolean? })
	local theme = StudioComponents.useTheme()

	local selected = Hooks.useSelection()
	local uploadInfos = Hooks.useEditableImageInfos(selected)

	return React.createElement("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = props.Size,
		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
	}, {
		Core = React.createElement(Widget, {
			Size = UDim2.fromScale(1, 1),

			UploadInfos = uploadInfos,

			TryUpload = function(index, _name, _editImage, _creator)
				task.wait(1)
				return index
			end,
			TestCreator = function(creator)
				return creator.Id > 0
			end,
			OnUploadComplete = function(output)
				print("[UploadWindow story] complete:", output)
			end,

			OnCancel = function()
				print("[UploadWindow story] cancelled")
			end,

			Disabled = props.Disabled,
		}),
	})
end

return CreateStory.theme(function(props)
	return React.createElement(Component, {
		Size = UDim2.fromOffset(360, 420),
		Disabled = props.Disabled,
	})
end)
