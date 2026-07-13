local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)

local EYE_ICON = assert(Lucide.GetAsset("eye", 16))
local EYE_OFF_ICON = assert(Lucide.GetAsset("eye-off", 16))

local ARROW_RIGHT = assert(Lucide.GetAsset("chevron-right", 16))
local ARROW_DOWN = assert(Lucide.GetAsset("chevron-down", 16))

local TRASH_ICON = assert(Lucide.GetAsset("trash", 16))
local IMAGE_ICON = assert(Lucide.GetAsset("file-image", 24))

-- One image in the layer's flattened preview, with its display-time tint/transparency
-- already folded in. Structurally a Controller.RenderLayer; offset is ignored at thumbnail
-- scale.
export type ThumbnailLayer = {
	name: string,
	editImage: EditableImage,
	offset: Vector2,
	tintColor: Color3,
	transparency: number,
}

export type Props = {
	Title: string,
	ThumbnailLayers: { ThumbnailLayer }?,
	IsVisible: boolean,
	IsSelected: boolean,
	IsExpanded: boolean?,

	OnSelected: (() -> ())?,
	OnVisibilityToggled: (() -> ())?,
	OnExpandToggled: (() -> ())?,
	OnDelete: (() -> ())?,

	LayoutOrder: number?,
	ZIndex: number?,
	Disabled: boolean?,

	children: React.ReactNode?,
}

local function Layer(props: Props)
	local theme = StudioComponents.useTheme()

	local hasSubEffects = props.children ~= nil and next(props.children :: any) ~= nil

	-- The thumbnail is the layer's preview stacked top-first as ImageLabels (each carrying
	-- its folded tint/transparency), or a placeholder icon when the layer renders nothing.
	-- Offset is dropped: at 38px it's sub-pixel.
	local thumbnailChildren: { [string]: React.ReactNode } = {}
	local thumbnailLayers = props.ThumbnailLayers
	if thumbnailLayers and #thumbnailLayers > 0 then
		for i, thumbnailLayer in thumbnailLayers do
			thumbnailChildren["Layer" .. i] = React.createElement("ImageLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ScaleType = Enum.ScaleType.Fit,
				ImageContent = Content.fromObject(thumbnailLayer.editImage),
				ImageColor3 = thumbnailLayer.tintColor,
				ImageTransparency = thumbnailLayer.transparency,
				ZIndex = -i,
			})
		end
	else
		thumbnailChildren.Icon = React.createElement("ImageLabel", {
			Size = UDim2.fromOffset(IMAGE_ICON.ImageRectSize.X, IMAGE_ICON.ImageRectSize.Y),
			Position = UDim2.fromScale(0.5, 0.5),
			AnchorPoint = Vector2.new(0.5, 0.5),
			BackgroundTransparency = 1,
			Image = IMAGE_ICON.Url,
			ImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Button),
			ImageRectSize = IMAGE_ICON.ImageRectSize,
			ImageRectOffset = IMAGE_ICON.ImageRectOffset,
		})
	end
	thumbnailChildren.UIStroke = React.createElement("UIStroke", {
		Thickness = 1,
		Transparency = 0,
		Color = theme:GetColor(
			Enum.StudioStyleGuideColor.InputFieldBorder,
			if props.IsSelected then Enum.StudioStyleGuideModifier.Hover else Enum.StudioStyleGuideModifier.Default
		),
		BorderStrokePosition = Enum.BorderStrokePosition.Outer,
	})

	local mainBackground = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground)
	local backgroundColor = if props.IsSelected
		then theme
			:GetColor(Enum.StudioStyleGuideColor.InputFieldBorder, Enum.StudioStyleGuideModifier.Selected)
			:Lerp(mainBackground, 0.9)
		else mainBackground

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = props.LayoutOrder,
		ZIndex = props.ZIndex,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			HorizontalAlignment = Enum.HorizontalAlignment.Left,
			VerticalAlignment = Enum.VerticalAlignment.Top,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		LineContent = React.createElement("Frame", {
			Active = true,
			BackgroundColor3 = backgroundColor,
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
			Size = UDim2.new(1, 0, 0, 48),
			LayoutOrder = 1,

			[React.Event.InputBegan] = function(_, input: InputObject)
				if input.UserInputType == Enum.UserInputType.MouseButton1 and props.OnSelected then
					props.OnSelected()
				end
			end,
		}, {
			UIPadding = React.createElement("UIPadding", {
				PaddingTop = UDim.new(0, 4),
				PaddingBottom = UDim.new(0, 4),
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 4),
			}),

			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Left,
				VerticalAlignment = Enum.VerticalAlignment.Center,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 4),
			}),

			Visibility = React.createElement(LucideIconButton, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(22, 22),
				IconSize = UDim2.fromOffset(14, 14),
				Icon = if props.IsVisible then EYE_ICON else EYE_OFF_ICON,
				Disabled = props.Disabled,
				LayoutOrder = 1,

				OnActivated = function()
					if props.OnVisibilityToggled then
						props.OnVisibilityToggled()
					end
				end,
			}),

			Expand = props.IsExpanded ~= nil and hasSubEffects and React.createElement(LucideIconButton, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(22, 22),
				Icon = if props.IsExpanded then ARROW_DOWN else ARROW_RIGHT,
				Disabled = props.Disabled,
				LayoutOrder = 2,

				OnActivated = function()
					if props.OnExpandToggled then
						props.OnExpandToggled()
					end
				end,
			}),

			-- Reserve the chevron's footprint so the icon/title don't shift when a
			-- layer has no sub-effects.
			ExpandSpacer = props.IsExpanded ~= nil and not hasSubEffects and React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(22, 22),
				LayoutOrder = 2,
			}),

			ImageIcon = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromOffset(38, 38),
				LayoutOrder = 3,
			}, thumbnailChildren),

			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -120, 1, 0),
				FontFace = Font.fromName("SourceSansPro"),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.MainText,
					if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
				),
				Text = props.Title,
				TextSize = 14,
				LayoutOrder = 4,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),
			}),

			Delete = React.createElement(LucideIconButton, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(22, 22),
				IconSize = UDim2.fromOffset(14, 14),
				Icon = TRASH_ICON,
				Disabled = props.Disabled,
				LayoutOrder = 5,

				OnActivated = function()
					if props.OnDelete then
						props.OnDelete()
					end
				end,
			}),
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Visible = props.IsExpanded,
			LayoutOrder = 2,
		}, {
			UIListLayout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				SortOrder = Enum.SortOrder.LayoutOrder,
				Padding = UDim.new(0, 0),
			}),
		}, props.children),
	})
end

return Layer
