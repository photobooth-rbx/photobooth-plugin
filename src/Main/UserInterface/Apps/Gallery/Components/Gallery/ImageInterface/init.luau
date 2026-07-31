local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local Hooks = require(uiRoot.Hooks)

local useImageControls = require(script.useImageControls)

local ToggleScrollList = require(script.ToggleScrollList)
local SplitDivider = require(script.SplitDivider)
local ImageViewer = require(script.ImageViewer)

local MIN_LIST_SCALE = 0.15
local MAX_LIST_SCALE = 0.75

local DIVIDER_THICKNESS = 5
local DIVIDER_LIST_OVERLAP = 1

local MAXIMIZE_ICON = assert(Lucide.GetAsset("chevrons-right", 16))
local MINIMIZE_ICON = assert(Lucide.GetAsset("chevrons-left", 16))

export type Props = {
	AnchorPoint: Vector2,
	Position: UDim2,
	Size: UDim2,

	EditableImageInfos: { Hooks.EditableImageInfo },

	IsExpanded: boolean,
	SetIsExpanded: (boolean) -> (),

	ListScale: number,
	SetListScale: (number) -> (),

	SelectedIndex: number,
	SetSelectedIndex: (number) -> (),

	UploadExclusions: { [Instance]: boolean },
	SetUploadExclusions: ({ [Instance]: boolean }) -> (),

	BackgroundType: string,
	SetBackgroundType: (string) -> (),

	ImageControls: useImageControls.ImageControls,
	ViewerRef: { current: GuiObject? },

	OnUpload: () -> (),

	SinkInput: boolean,
	Disabled: boolean,
}

local function getImageButtonColor(theme: StudioTheme, modifier: Enum.StudioStyleGuideModifier)
	if modifier == Enum.StudioStyleGuideModifier.Selected then
		return theme:GetColor(Enum.StudioStyleGuideColor.ButtonText, Enum.StudioStyleGuideModifier.Pressed)
	elseif modifier == Enum.StudioStyleGuideModifier.Hover then
		return theme:GetColor(Enum.StudioStyleGuideColor.ButtonText, Enum.StudioStyleGuideModifier.Hover)
	end
	return theme:GetColor(Enum.StudioStyleGuideColor.ButtonText, Enum.StudioStyleGuideModifier.Disabled)
end

local function ImageInterface(props: Props)
	local theme = StudioComponents.useTheme()

	local rootRef = React.useRef(nil :: GuiObject?)
	local grabOffsetRef = React.useRef(0)

	local minMaxIcon = if props.IsExpanded then MINIMIZE_ICON else MAXIMIZE_ICON

	local listScale = math.clamp(props.ListScale, MIN_LIST_SCALE, MAX_LIST_SCALE)
	local leftScale = if props.IsExpanded then listScale else 0

	local function getDraggedScale(absoluteX: number)
		local root = rootRef.current
		if not root or root.AbsoluteSize.X <= 0 then
			return listScale
		end
		local offsetX = absoluteX - root.AbsolutePosition.X - grabOffsetRef.current
		return math.clamp(offsetX / root.AbsoluteSize.X, MIN_LIST_SCALE, MAX_LIST_SCALE)
	end

	local selectedInfo = props.EditableImageInfos[props.SelectedIndex]
	local prevSelectedInstanceRef = React.useRef(if selectedInfo then selectedInfo.Instance else nil)

	React.useEffect(function()
		local info = props.EditableImageInfos[props.SelectedIndex]
		prevSelectedInstanceRef.current = if info then info.Instance else nil
	end, { props.SelectedIndex })

	React.useEffect(function()
		local index = 1
		local exclusions = {}
		local prevSelectedInstance = prevSelectedInstanceRef.current
		for i = #props.EditableImageInfos, 1, -1 do
			local info = props.EditableImageInfos[i]
			if prevSelectedInstance and info.Instance == prevSelectedInstance then
				index = i
			end

			if props.UploadExclusions[info.Instance] then
				exclusions[info.Instance] = true
			end
		end

		local info = props.EditableImageInfos[index]
		prevSelectedInstanceRef.current = if info then info.Instance else nil

		props.SetSelectedIndex(index)
		props.SetUploadExclusions(exclusions)
	end, { props.EditableImageInfos })

	return React.createElement("Frame", {
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		BackgroundTransparency = 1,
		ref = rootRef,
	}, {
		Left = React.createElement("Frame", {
			BackgroundTransparency = 0,
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromOffset(0, 0),
			Size = UDim2.new(leftScale, 0, 1, 0),
			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
		}, {
			MinMaxButton = React.createElement(LucideIconButton, {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.new(1, 0, 1, 0),
				Size = UDim2.fromOffset(minMaxIcon.ImageRectSize.X, minMaxIcon.ImageRectSize.Y),

				Icon = minMaxIcon,
				GetColor = function(modifier)
					return getImageButtonColor(theme, modifier)
				end,

				OnActivated = function()
					props.SetIsExpanded(not props.IsExpanded)
				end,

				Disabled = props.Disabled,
			}),

			ImageList = React.createElement(ToggleScrollList, {
				AnchorPoint = Vector2.new(0, 0),
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.new(1, 0, 1, 0),

				SelectedIndex = props.SelectedIndex,
				SetSelectedIndex = function(i)
					local info = props.EditableImageInfos[i]
					prevSelectedInstanceRef.current = if info then info.Instance else nil
					props.SetSelectedIndex(i)
				end,

				UploadExclusions = props.UploadExclusions,
				SetUploadExclusions = props.SetUploadExclusions,

				TitleHeight = 28,
				ElementHeight = 24,

				EditableImageInfos = props.EditableImageInfos,

				OnUpload = props.OnUpload,

				SinkInput = props.SinkInput,
				Disabled = props.Disabled,
			}),
		}),

		Divider = props.IsExpanded and React.createElement(SplitDivider, {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.new(leftScale, -DIVIDER_LIST_OVERLAP, 0, 0),
			Size = UDim2.new(0, DIVIDER_THICKNESS, 1, 0),

			LineOffset = DIVIDER_LIST_OVERLAP,

			OnDragStart = function(absoluteX)
				local root = rootRef.current
				grabOffsetRef.current = if root
					then absoluteX - root.AbsolutePosition.X - leftScale * root.AbsoluteSize.X
					else 0
			end,
			OnDrag = function(absoluteX)
				props.SetListScale(getDraggedScale(absoluteX))
			end,

			ZIndex = 1,
			Disabled = props.Disabled or props.SinkInput,
		}),

		Right = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(1 - leftScale, 0, 1, 0),
			ZIndex = -1,
		}, {
			ImageViewer = React.createElement(ImageViewer, {
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, 0, 1, 0),

				EditableImageInfo = props.EditableImageInfos[props.SelectedIndex],

				BackgroundType = props.BackgroundType,
				SetBackgroundType = props.SetBackgroundType,

				ImageControls = props.ImageControls,
				ViewerRef = props.ViewerRef,
			}),
		}),
	})
end

return ImageInterface
