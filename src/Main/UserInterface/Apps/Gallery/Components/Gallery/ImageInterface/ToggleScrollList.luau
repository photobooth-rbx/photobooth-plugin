local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local StateManager = require(pluginRoot.Main.StateManager)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local Hooks = require(uiRoot.Hooks)

local UPLOAD_ICON = assert(Lucide.GetAsset("upload", 16))
local GRID_ICON = assert(Lucide.GetAsset("layout-grid", 16))
local LIST_ICON = assert(Lucide.GetAsset("layout-list", 16))

local N_COLUMNS = 3
local COLUMN_PADDING_SCALE = 0.025

export type Props = {
	AnchorPoint: Vector2,
	Position: UDim2,
	Size: UDim2,

	SelectedIndex: number,
	SetSelectedIndex: (number) -> (),

	UploadExclusions: { [Instance]: boolean },
	SetUploadExclusions: ({ [Instance]: boolean }) -> (),

	TitleHeight: number,
	ElementHeight: number,

	OnUpload: () -> (),

	EditableImageInfos: { Hooks.EditableImageInfo },

	SinkInput: boolean,
	Disabled: boolean,
}

local function ToggleScrollList(props: Props)
	local theme = StudioComponents.useTheme()
	local hasCreateAssetPermission = Hooks.useHasCreateAssetPermission()
	local isStory = Hooks.useIsStory()

	local isGridView = StateManager.settings:useSpecific()(function(state)
		return state.galleryListGridView
	end)

	local scrollRef = React.useRef(nil :: ScrollingFrame?)
	local scrollAbsSize = Hooks.useRefProperty(scrollRef, "AbsoluteSize", Vector2.zero)

	local cellPadding = math.ceil(scrollAbsSize.X * COLUMN_PADDING_SCALE)
	local cellSize = (scrollAbsSize.X - cellPadding * (N_COLUMNS + 1)) / N_COLUMNS

	local nSelected = #props.EditableImageInfos
	local uploadHeight = if isStory or hasCreateAssetPermission then 36 else 0

	local lines: { [string]: React.Node } = {}
	for i, info in props.EditableImageInfos do
		if not isGridView then
			lines[`Line{i}`] = React.createElement("TextButton", {
				Size = UDim2.new(1, 0, 0, props.ElementHeight),
				AutoButtonColor = false,
				Text = "",

				BackgroundColor3 = if i == props.SelectedIndex
					then theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton)
					else theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

				LayoutOrder = i,

				[React.Event.Activated] = function()
					props.SetSelectedIndex(i)
				end,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
					PaddingTop = UDim.new(0, 0),
					PaddingBottom = UDim.new(0, 0),
				}),
				Checkbox = React.createElement(StudioComponents.Checkbox, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.new(0, StudioComponents.Constants.DefaultToggleHeight, 1, 0),

					Value = not props.UploadExclusions[info.Instance],
					OnChanged = function()
						props.UploadExclusions[info.Instance] = not props.UploadExclusions[info.Instance]
						props.SetUploadExclusions(table.clone(props.UploadExclusions))
					end,

					Disabled = props.Disabled,
				}),
				Label = React.createElement(StudioComponents.Label, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, StudioComponents.Constants.DefaultToggleHeight + 2, 0.5, 0),
					Size = UDim2.new(1, -StudioComponents.Constants.DefaultToggleHeight, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColorStyle = if i == props.SelectedIndex
						then Enum.StudioStyleGuideColor.DialogMainButtonText
						else Enum.StudioStyleGuideColor.MainText,
					Text = info.Name,
				}),
			})
		else
			lines[`Line{i}`] = React.createElement("TextButton", {
				Size = UDim2.fromOffset(cellSize, cellSize),
				AutoButtonColor = false,
				Text = "",

				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				BorderColor3 = theme:GetColor(
					Enum.StudioStyleGuideColor.InputFieldBorder,
					if i == props.SelectedIndex
						then Enum.StudioStyleGuideModifier.Selected
						else Enum.StudioStyleGuideModifier.Default
				),

				LayoutOrder = i,

				[React.Event.Activated] = function()
					props.SetSelectedIndex(i)
				end,
			}, {
				Interact = React.createElement("ImageButton", {
					BackgroundTransparency = 1,
					Size = UDim2.fromScale(1, 1),
					ZIndex = 3,
				}, {
					Selector = React.createElement("ImageButton", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
						ZIndex = -1,

						[React.Event.Activated] = function()
							if not props.Disabled then
								props.SetSelectedIndex(i)
							end
						end,
					}),

					Toggle = React.createElement("Frame", {
						BackgroundTransparency = 1,
						Size = UDim2.fromScale(1, 1),
					}, {
						Padding = React.createElement("UIPadding", {
							PaddingLeft = UDim.new(0, 2),
							PaddingRight = UDim.new(0, 2),
							PaddingTop = UDim.new(0, 2),
							PaddingBottom = UDim.new(0, 2),
						}),
						Checkbox = React.createElement(StudioComponents.Checkbox, {
							Position = UDim2.fromScale(0, 0),
							Size = UDim2.fromOffset(
								StudioComponents.Constants.DefaultToggleHeight,
								StudioComponents.Constants.DefaultToggleHeight
							),

							Value = not props.UploadExclusions[info.Instance],
							OnChanged = function()
								props.UploadExclusions[info.Instance] = not props.UploadExclusions[info.Instance]
								props.SetUploadExclusions(table.clone(props.UploadExclusions))
							end,

							Disabled = props.Disabled,
						}),
					}),
				}),

				ImageContainer = React.createElement("Frame", {
					LayoutOrder = 2,
					Size = UDim2.fromScale(1, 1),
					SizeConstraint = Enum.SizeConstraint.RelativeYY,
					BackgroundTransparency = 1,
				}, {
					AspectContainer = React.createElement("Frame", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.fromScale(1, 1),
					}, {
						AspectConstraint = React.createElement("UIAspectRatioConstraint", {
							AspectType = Enum.AspectType.ScaleWithParentSize,
							DominantAxis = Enum.DominantAxis.Width,
							AspectRatio = info.EditableImage.Size.X / info.EditableImage.Size.Y,
						}),

						ImageLabel = React.createElement("ImageLabel", {
							BackgroundTransparency = 1,
							Size = UDim2.fromScale(1, 1),
							ImageContent = Content.fromObject(info.EditableImage),
						}),
					}),
				}),

				Label = React.createElement(StudioComponents.Label, {
					AnchorPoint = Vector2.new(0, 1),
					Position = UDim2.fromScale(0, 1),
					Size = UDim2.new(1, 0, 0, StudioComponents.Constants.DefaultToggleHeight),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColorStyle = if i == props.SelectedIndex
						then Enum.StudioStyleGuideColor.DialogMainButtonText
						else Enum.StudioStyleGuideColor.MainText,
					Text = info.Name,
					ZIndex = 2,
				}, {
					Padding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 4),
						PaddingRight = UDim.new(0, 4),
					}),
					UIStroke = React.createElement("UIStroke", {
						Thickness = 1,
						Transparency = 0,
						Color = theme:GetColor(Enum.StudioStyleGuideColor.Border),
					}),
				}),
			})
		end
	end

	local exclusionCount = React.useMemo(function()
		local count = 0
		for _, info in props.EditableImageInfos do
			if props.UploadExclusions[info.Instance] then
				count = count + 1
			end
		end
		return count
	end, { props.UploadExclusions })

	local inclusionCount = nSelected - exclusionCount

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
	}, {
		Title = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0),
			Position = UDim2.fromScale(0, 0),
			Size = UDim2.new(1, 0, 0, props.TitleHeight),

			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Light),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

			ZIndex = 2,
		}, {
			BorderLine = React.createElement("Frame", {
				BorderSizePixel = 0,
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				Position = UDim2.fromOffset(0, 1),
				Size = UDim2.new(1, 0, 0, 1),
				Visible = not (props.SinkInput or props.Disabled),
			}),
			Clipped = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				ClipsDescendants = true,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
					PaddingTop = UDim.new(0, 0),
					PaddingBottom = UDim.new(0, 0),
				}),
				Checkbox = React.createElement(StudioComponents.Checkbox, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromScale(1, 1),

					Value = inclusionCount > 0,
					OnChanged = function()
						if inclusionCount > 0 then
							local exclusions = {}
							for _, info in props.EditableImageInfos do
								exclusions[info.Instance] = true
							end
							props.SetUploadExclusions(exclusions)
						else
							props.SetUploadExclusions({})
						end
					end,

					Disabled = props.Disabled or (#props.EditableImageInfos == 0),
				}),
				Label = React.createElement(StudioComponents.Label, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, StudioComponents.Constants.DefaultToggleHeight + 2, 0.5, 0),
					Size = UDim2.new(1, -StudioComponents.Constants.DefaultToggleHeight, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColorStyle = Enum.StudioStyleGuideColor.MainText,
					Text = `{inclusionCount} selected`,
				}),

				GridToggle = React.createElement(LucideIconButton, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.new(1, 0, 0.5, 1),
					Size = UDim2.fromOffset(16, 16),
					Icon = if isGridView then LIST_ICON else GRID_ICON,
					Disabled = props.Disabled,
					OnActivated = function()
						StateManager.settings:update()(function(state)
							state.galleryListGridView = not state.galleryListGridView
							return state
						end)
					end,
				}),
			}),
		}),

		ScrollContainer = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, props.TitleHeight),
			Size = UDim2.new(1, 0, 1, -props.TitleHeight - uploadHeight),
			ref = scrollRef,
		}, {
			Scroll = React.createElement(StudioProperties.VerticalScroll, {
				Size = UDim2.fromScale(1, 1),

				GradientColor = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
				GradientHeight = 8,

				Disabled = props.Disabled or props.SinkInput,
			}, {
				ListLayout = not isGridView and React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
				Padding = isGridView and React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, cellPadding),
					PaddingRight = UDim.new(0, cellPadding),
					PaddingTop = UDim.new(0, cellPadding),
					PaddingBottom = UDim.new(0, cellPadding),
				}),
				GridLayout = isGridView and React.createElement("UIGridLayout", {
					CellPadding = UDim2.fromOffset(cellPadding, cellPadding),
					CellSize = UDim2.fromOffset(cellSize, cellSize),
					FillDirection = Enum.FillDirection.Horizontal,
					SortOrder = Enum.SortOrder.LayoutOrder,
				}),
			}, lines),
		}),

		Upload = React.createElement("Frame", {
			BackgroundTransparency = 1,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, uploadHeight),
			Visible = uploadHeight > 0,
			ClipsDescendants = true,
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 3),
				PaddingRight = UDim.new(0, 3),
				PaddingTop = UDim.new(0, 3),
				PaddingBottom = UDim.new(0, 3),
			}),
			ClipFrame = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, 0),
				ClipsDescendants = true,
			}, {
				Button = React.createElement(StudioComponents.Button, {
					LayoutOrder = -2,
					Size = UDim2.new(1, -2, 1, -2),
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					TextXAlignment = Enum.TextXAlignment.Center,
					Text = "Upload",
					Disabled = props.Disabled or inclusionCount == 0,
					OnActivated = props.OnUpload,

					Icon = {
						Image = UPLOAD_ICON.Url,
						RectSize = UPLOAD_ICON.ImageRectSize,
						RectOffset = UPLOAD_ICON.ImageRectOffset,
						Size = Vector2.new(UPLOAD_ICON.ImageRectSize.X, UPLOAD_ICON.ImageRectSize.Y),
						UseThemeColor = true,
					},
				}),
			}),
		}),
	})
end

return ToggleScrollList
