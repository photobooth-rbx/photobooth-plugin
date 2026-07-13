local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local ImageList = require(script.ImageList)
local Uploader = require(script.Parent.Uploader)

type EditableImageInfo = Hooks.EditableImageInfo

export type Creator = Uploader.Creator
export type TryUpload = Uploader.TryUpload
export type TestCreator = Uploader.TestCreator

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	TryUpload: TryUpload,
	TestCreator: TestCreator,

	Disabled: boolean?,
}

local function Widget(props: Props)
	local infos, setInfos = React.useState(nil :: { EditableImageInfo }?)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
	}, {
		ImageList = React.createElement(ImageList, {
			Size = UDim2.fromScale(1, 1),
			Visible = not infos,
			OnSubmit = function(newInfos)
				setInfos(newInfos)
			end,

			Disabled = props.Disabled,
		}),

		Uploader = infos and React.createElement(Uploader, {
			Size = UDim2.fromScale(1, 1),

			UploadInfos = infos,

			TryUpload = props.TryUpload,
			TestCreator = props.TestCreator,

			OnClose = function()
				setInfos(nil :: any)
			end,

			Disabled = props.Disabled,
		}),
	})
end

return Widget
