local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Asphalt = require(uiRoot.Asphalt)
local Hooks = require(uiRoot.Hooks)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local widgetRoot = script:FindFirstAncestor("Widget")
local OverlayMenu = require(widgetRoot.OverlayMenu)

local HighResImageSplit = require(script.HighResImageSplit)

local BACKGROUND_TYPES = { "Checkerboard", "Black", "White", "None" }

local OUTLINE_THICKNESS = 2
local DIMENSIONS_FONT_SIZE = 7
local DIMENSIONS_FONT = Font.fromEnum(Enum.Font.Legacy)

export type Props = {
	Size: UDim2,
	Position: UDim2,
	AnchorPoint: Vector2,

	Title: string,
	IsLoading: boolean,
	Layers: { Controller.RenderLayer },
}

local function useBackgroundType()
	local origin, setOrigin = React.useState(nil :: Vector2?)
	local value, setValue = React.useState("Checkerboard")

	local openMenu = React.useCallback(function(newOrigin: Vector2)
		setOrigin(newOrigin)
	end, {})

	local closeMenu = React.useCallback(function()
		setOrigin(nil :: any)
	end, {})

	return {
		origin = origin,
		value = value,
		setValue = setValue,
		open = openMenu,
		close = closeMenu,
	}
end

local function DisplayImage(props: Props)
	local theme = StudioComponents.useTheme()
	local backgroundType = useBackgroundType()
	local overlayMenuFrame = OverlayMenu.useTarget()

	local menuItems: { OverlayMenu.Item } = {}
	for _, name in BACKGROUND_TYPES do
		table.insert(menuItems, {
			Text = name,
			Icon = Asphalt.menu[name:lower()] or "",
			Selected = name == backgroundType.value,
			OnActivated = function()
				backgroundType.setValue(name)
				backgroundType.close()
			end,
		})
	end

	local bottomLabel = React.useRef(nil :: TextLabel?)
	local bottomLabelTextFits = Hooks.useRefProperty(bottomLabel, "TextFits", true)

	local size = Vector2.zero
	local layerLabels: { [string]: React.ReactNode } = {}
	for i, layer in props.Layers do
		size = size:Max(layer.editImage.Size)
		layerLabels["Layer" .. i] = React.createElement(HighResImageSplit, {
			Position = UDim2.fromOffset(layer.offset.X, layer.offset.Y),
			Size = UDim2.fromScale(1, 1),
			ImageColor3 = layer.tintColor,
			ImageTransparency = layer.transparency,
			EditableImage = layer.editImage,
			ZIndex = -i,
		})
	end

	local aspectRatio = size.X / size.Y
	local dimensionsText = `{size.X} x {size.Y} - {props.Title}`

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		Container = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = props.AnchorPoint,
			Position = props.Position,
			Size = props.Size,
		}, {
			AspectContainer = React.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(1, 1),
			}, {
				SizeConstraint = React.createElement("UISizeConstraint", {
					MaxSize = size,
				}),
				AspectConstraint = React.createElement("UIAspectRatioConstraint", {
					AspectType = Enum.AspectType.ScaleWithParentSize,
					DominantAxis = Enum.DominantAxis.Width,
					AspectRatio = aspectRatio,
				}),

				ImageContainer = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
				}, {
					OutlineStroke = React.createElement("UIStroke", {
						Thickness = OUTLINE_THICKNESS,
						LineJoinMode = Enum.LineJoinMode.Miter,
						Color = theme:GetColor(
							Enum.StudioStyleGuideColor.InputFieldBorder,
							Enum.StudioStyleGuideModifier.Selected
						),
					}),
					AttachedDimensions = React.createElement("TextLabel", {
						Size = UDim2.new(1, OUTLINE_THICKNESS * 2, 0, 10),
						Position = UDim2.new(0, -OUTLINE_THICKNESS, 1, 4),
						BackgroundTransparency = 1,
						Text = dimensionsText,
						TextSize = DIMENSIONS_FONT_SIZE,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextYAlignment = Enum.TextYAlignment.Bottom,
						TextTruncate = Enum.TextTruncate.AtEnd,
						TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
						TextTransparency = if bottomLabelTextFits then 0.7 else 1,
						FontFace = DIMENSIONS_FONT,
						ref = bottomLabel,
					}),

					Layers = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ClipsDescendants = true,
					}, layerLabels),

					Overlay = props.IsLoading and React.createElement("Frame", {
						BorderSizePixel = 0,
						BackgroundTransparency = 0.3,
						BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
						Size = UDim2.fromScale(1, 1),
						ZIndex = 2,
					}, {
						Dots = React.createElement(StudioComponents.LoadingDots, {
							Size = UDim2.fromScale(1, 1),
						}),
					}),

					RightClickButton = React.createElement("Frame", {
						ZIndex = 3,
						Active = false,
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						[React.Event.InputBegan] = function(_, input: InputObject)
							if input.UserInputType == Enum.UserInputType.MouseButton2 then
								local origin = Vector2.new(input.Position.X, input.Position.Y)
									- overlayMenuFrame.AbsolutePosition
								backgroundType.open(origin)
							end
						end,
					}),
				}),

				BackgroundContrast = React.createElement("Frame", {
					Size = UDim2.fromScale(1, 1),
					BackgroundTransparency = 1,
					ClipsDescendants = true,
					ZIndex = -1,
				}, {
					Checkerboard = backgroundType.value == "Checkerboard" and React.createElement("ImageLabel", {
						BackgroundTransparency = 1,
						Image = Asphalt.misc.checkerboard,
						ScaleType = Enum.ScaleType.Tile,
						TileSize = UDim2.fromOffset(50, 50),
						Size = UDim2.new(1, 100, 1, 100),
						Position = UDim2.fromOffset(-(size.X % 50) / 2, -(size.Y % 50) / 2),
						ImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
					}),

					Black = backgroundType.value == "Black" and React.createElement("ImageLabel", {
						BorderSizePixel = 0,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.new(0, 0, 0),
						Size = UDim2.fromScale(1, 1),
					}),

					White = backgroundType.value == "White" and React.createElement("ImageLabel", {
						BorderSizePixel = 0,
						BackgroundTransparency = 0,
						BackgroundColor3 = Color3.new(1, 1, 1),
						Size = UDim2.fromScale(1, 1),
					}),
				}),
			}),
		}),

		UnattachedDimensions = not bottomLabelTextFits and React.createElement("TextLabel", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			Text = dimensionsText,
			TextSize = DIMENSIONS_FONT_SIZE,
			--TextWrapped = true,
			TextTransparency = 0.7,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Bottom,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
			TextTruncate = Enum.TextTruncate.AtEnd,
			FontFace = DIMENSIONS_FONT,
			ZIndex = -1,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 6),
				PaddingBottom = UDim.new(0, 6),
			}),
		}),

		Menu = backgroundType.origin and React.createElement(OverlayMenu.component, {
			Origin = backgroundType.origin,
			Items = menuItems,
			OnClose = backgroundType.close,
			ZIndex = 10,
		}),
	})
end

return DisplayImage
