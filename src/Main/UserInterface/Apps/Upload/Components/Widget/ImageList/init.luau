local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local InstanceList = require(script.InstanceList)

local IMAGE_ICON = assert(Lucide.GetAsset("images", 48))
local UPLOAD_ICON = assert(Lucide.GetAsset("upload", 16))

type EditableImageInfo = Hooks.EditableImageInfo

export type Props = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	Visible: boolean?,
	OnSubmit: ({ EditableImageInfo }) -> (),

	Disabled: boolean?,
}

local function ImageList(props: Props)
	local theme = StudioComponents.useTheme()

	local forceRender = Hooks.useUpdate()
	local listRef = React.useRef({} :: InstanceList.List<MeshPart>)
	local nList = #listRef.current

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		Visible = props.Visible,
	}, {
		List = React.createElement(InstanceList, {
			Size = UDim2.new(1, 0, 1, -38),

			ForceRender = forceRender,
			ListRef = listRef,

			OnListElementAdded = function() end,
			OnListElementRemoved = function() end,

			FilterSelection = function(instance)
				local content = if instance:IsA("MeshPart") then instance.TextureContent else nil
				local editImage = if content then content.Object else nil
				return if editImage and editImage:IsA("EditableImage") then instance else nil
			end,

			Disabled = props.Disabled,
		}),

		Overlay = nList == 0 and React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 23),
			Size = UDim2.new(1, 0, 1, -38 - 23),
			ZIndex = -1,
		}, {
			Layout = React.createElement("UIListLayout", {
				SortOrder = Enum.SortOrder.LayoutOrder,
				FillDirection = Enum.FillDirection.Vertical,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, 4),
			}),

			Icon = React.createElement("ImageLabel", {
				LayoutOrder = 0,
				Size = UDim2.fromOffset(IMAGE_ICON.ImageRectSize.X, IMAGE_ICON.ImageRectSize.Y),
				BackgroundTransparency = 1,
				Image = IMAGE_ICON.Url,
				ImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
				ImageTransparency = 0.7,
				ImageRectSize = IMAGE_ICON.ImageRectSize,
				ImageRectOffset = IMAGE_ICON.ImageRectOffset,
			}),
			Label2 = React.createElement("TextLabel", {
				LayoutOrder = 3,
				Size = UDim2.new(0, 200, 0, 18),
				BackgroundTransparency = 1,
				Text = "No Images Selected",
				TextScaled = true,
				TextTransparency = 0.7,
				TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
			}),
		}),

		Buttons = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 38),
			ClipsDescendants = true,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 4),
			}),

			Submit = React.createElement(StudioComponents.MainButton, {
				Size = UDim2.fromScale(1, 1),
				TextXAlignment = Enum.TextXAlignment.Center,
				Text = "Submit",
				Disabled = nList == 0 or not not props.Disabled,

				Icon = {
					Image = UPLOAD_ICON.Url,
					RectSize = UPLOAD_ICON.ImageRectSize,
					RectOffset = UPLOAD_ICON.ImageRectOffset,
					Size = Vector2.new(UPLOAD_ICON.ImageRectSize.X, UPLOAD_ICON.ImageRectSize.Y),
					UseThemeColor = true,
				},

				OnActivated = function()
					local list: { EditableImageInfo } = {}
					for _, element in listRef.current do
						local editImage = element.instance.TextureContent.Object
						if editImage and editImage:IsA("EditableImage") then
							table.insert(list, {
								Name = element.instance.Name,
								Instance = element.instance,
								EditableImage = editImage,
							})
						end
					end
					props.OnSubmit(list)
				end,
			}),
		}),
	})
end

return ImageList
