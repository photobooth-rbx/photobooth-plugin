local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRipple = require(pluginRoot.Packages.ReactRipple)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local Photo = require(pluginRoot.Main.Photo)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local OverlayMenu = require(uiRoot.Components.OverlayMenu)
local Hooks = require(uiRoot.Hooks)

local EffectsList = require(script.EffectsList)
local PresetsList = require(script.PresetsList)
local ImageViewer = require(script.ImageViewer)

local ACTION_BAR_HEIGHT = 38

local IMAGE_ICON = assert(Lucide.GetAsset("image", 16))
local IMAGES_ICON = assert(Lucide.GetAsset("images", 16))
local RIGHT_ICON = assert(Lucide.GetAsset("chevron-right", 16))
local LEFT_ICON = assert(Lucide.GetAsset("chevron-left", 16))
local FOCUS_ICON = assert(Lucide.GetAsset("eye-off", 48))

export type Props = {
	Disabled: boolean?,
}

local function useTransparencyFade(initial: number)
	local transparencyBinding, control = ReactRipple.useSpring(initial)
	local transparency = Hooks.useBindingState(transparencyBinding)

	local setGoal = React.useCallback(function(value: number)
		control:setGoal(value)
	end, {})

	local setImmediate = React.useCallback(function(value: number)
		control:setGoal(value)
		control:setPosition(value)
		control:setVelocity(0)
	end, {})

	return {
		value = transparency,
		setGoal = setGoal,
		setImmediate = setImmediate,
	}
end

local function useController()
	local controller = Hooks.useConstant(function()
		return Controller.new()
	end)

	React.useEffect(function()
		return function()
			controller:Destroy()
		end
	end, {})

	return controller
end

local function useSelectedEditImages(selected: { Instance })
	local index, setIndex = React.useState(1)

	local filtered, names = React.useMemo(function()
		local editImages = {}
		local nameByEditImage = {}
		for _, instance in selected do
			if instance:IsA("MeshPart") then
				local editImage = instance.TextureContent.Object
				if editImage and editImage:IsA("EditableImage") then
					table.insert(editImages, editImage)
					nameByEditImage[editImage] = instance.Name
				end
			end
		end
		return editImages, nameByEditImage
	end, { selected })

	React.useEffect(function()
		setIndex(1)
	end, { selected })

	return {
		images = filtered,
		nameByImage = names,
		count = #filtered,
		index = index,
		setIndex = setIndex,
	}
end

local function getImageButtonColor(theme: StudioTheme, modifier: Enum.StudioStyleGuideModifier)
	if modifier == Enum.StudioStyleGuideModifier.Selected then
		return theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Pressed)
	elseif modifier == Enum.StudioStyleGuideModifier.Hover then
		return theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Hover)
	end
	return theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled)
end

local function Widget(props: Props)
	local theme = StudioComponents.useTheme()
	local blurTransparency = useTransparencyFade(1)
	local isColorPickerOpen = StudioProperties.useColorPickerOpen()

	local controller = useController()
	local selection = Hooks.useSelection()
	local selected = useSelectedEditImages(selection)

	local layers = controller:useComposited()
	local selectedTab, setSelectedTab = React.useState("Effects")
	local loadingLayer, setLoadingLayer = React.useState(nil :: Controller.RenderLayer?)
	local applyingState, setApplyingState = React.useState("None")
	local cancelApplyingRef = React.useRef(false)

	local selectedEditImage = selected.images[selected.index]
	local approvedImage, setApprovedImage = React.useState(selectedEditImage)

	local isDirty = not not selectedEditImage and selectedEditImage ~= approvedImage
	local disabled = isColorPickerOpen or applyingState ~= "None" or not not props.Disabled

	React.useEffect(function()
		return function()
			controller:unloadImage()
		end
	end, {})

	React.useEffect(function()
		if not selectedEditImage then
			setApprovedImage(nil :: any)
		end
	end, { selectedEditImage })

	React.useEffect(function()
		blurTransparency.setGoal(if isDirty then 0 else 1)
	end, { isDirty })

	React.useEffect(function()
		if applyingState ~= "None" then
			return
		end

		if not approvedImage then
			controller:unloadImage()
			setLoadingLayer(nil :: any)
		elseif not controller:isLoadedImage(approvedImage) then
			task.spawn(function()
				setLoadingLayer(Controller.loadingLayer(approvedImage))
				controller:loadImageAsync(approvedImage)
				setLoadingLayer(nil :: any)
			end)
		end
	end, { approvedImage, applyingState } :: { any })

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = true,
		ZIndex = -1, -- Fixes dropdown issues
	}, {
		Container = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Content = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 1, -ACTION_BAR_HEIGHT),
			}, {
				Right = React.createElement("Frame", {
					BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
					BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
					AnchorPoint = Vector2.new(1, 0),
					Position = UDim2.fromScale(1, 0),
					Size = UDim2.new(0, 280, 1, 0),
				}, {
					Tabs = React.createElement(StudioComponents.TabContainer, {
						SelectedTab = selectedTab,
						OnTabSelected = setSelectedTab,
						Disabled = disabled,
					}, {
						Effects = {
							LayoutOrder = 1,
							Content = React.createElement(EffectsList, {
								Size = UDim2.fromScale(1, 1),
								Controller = controller,
								Disabled = disabled,
							}),
						},

						Presets = {
							LayoutOrder = 2,
							Content = React.createElement(PresetsList, {
								Size = UDim2.fromScale(1, 1),
								Controller = controller,
								Disabled = disabled,
							}),
						},
					}),
				}),

				Left = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, -280, 1, 0),
				}, {
					ImageViewer = React.createElement(ImageViewer, {
						Size = UDim2.fromScale(1, 1),
						Title = "Image",
						IsLoading = not not loadingLayer,
						Layers = if loadingLayer then { loadingLayer } else layers,
					}),
				}),
			}),

			Overlay = applyingState ~= "None" and React.createElement("ImageButton", {
				BorderSizePixel = 0,
				BackgroundTransparency = 0.7,
				BackgroundColor3 = Color3.new(0, 0, 0),
				Size = UDim2.fromScale(1, 1),
				AutoButtonColor = false,
				Image = "",
				ZIndex = 2,
			}, {
				Dots = React.createElement(StudioComponents.LoadingDots, {
					Size = UDim2.fromScale(1, 1),
				}),
			}),

			ActionBarBottom = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, ACTION_BAR_HEIGHT),

				BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),
				BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
			}, {
				ImageIndexer = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.new(0, 8, 0.5, 0),
					Size = UDim2.fromOffset(16 * 6, 16),
				}, {
					LeftButton = React.createElement(LucideIconButton, {
						AnchorPoint = Vector2.new(0, 0.5),
						Position = UDim2.new(0, 0, 0.5, 0),
						Size = UDim2.fromOffset(LEFT_ICON.ImageRectSize.X, LEFT_ICON.ImageRectSize.Y),
						Disabled = props.Disabled,
						Icon = LEFT_ICON,
						GetImageColor = function(modifier)
							return getImageButtonColor(theme, modifier)
						end,
						OnActivated = function()
							local index = math.max(0, (((selected.index - 1) - 1) % selected.count) + 1)
							selected.setIndex(index)
							setApprovedImage(selected.images[index])
						end,
					}),

					CountLabel = React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.fromScale(0.5, 0.5),
						Size = UDim2.new(1, -40, 1, 0),

						Text = `{math.min(selected.index, selected.count)} / {selected.count}`,
						TextColor3 = theme:GetColor(
							Enum.StudioStyleGuideColor.MainText,
							Enum.StudioStyleGuideModifier.Disabled
						),
						TextXAlignment = Enum.TextXAlignment.Center,
						TextYAlignment = Enum.TextYAlignment.Center,
						TextTruncate = Enum.TextTruncate.AtEnd,
					}),

					RightButton = React.createElement(LucideIconButton, {
						AnchorPoint = Vector2.new(1, 0.5),
						Position = UDim2.new(1, 0, 0.5, 0),
						Size = UDim2.fromOffset(RIGHT_ICON.ImageRectSize.X, RIGHT_ICON.ImageRectSize.Y),
						Disabled = props.Disabled,
						Icon = RIGHT_ICON,
						GetImageColor = function(modifier)
							return getImageButtonColor(theme, modifier)
						end,
						OnActivated = function()
							local index = math.max(0, (((selected.index + 1) - 1) % selected.count) + 1)
							selected.setIndex(index)
							setApprovedImage(selected.images[index])
						end,
					}),
				}),
			}),

			ActionBarTop = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0, 1),
				Position = UDim2.fromScale(0, 1),
				Size = UDim2.new(1, 0, 0, ACTION_BAR_HEIGHT),
				BackgroundTransparency = 1,
				ZIndex = 3,
			}, {
				ComposeButtons = React.createElement("Frame", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.new(0, 280, 1, 0),
					ClipsDescendants = true,
				}, {
					Padding = React.createElement("UIPadding", {
						PaddingLeft = UDim.new(0, 3),
						PaddingRight = UDim.new(0, 3),
						PaddingTop = UDim.new(0, 3),
						PaddingBottom = UDim.new(0, 4),
					}),
					UIListLayout = React.createElement("UIListLayout", {
						HorizontalAlignment = Enum.HorizontalAlignment.Center,
						HorizontalFlex = Enum.UIFlexAlignment.Fill,
						FillDirection = Enum.FillDirection.Horizontal,
						SortOrder = Enum.SortOrder.LayoutOrder,
						Padding = UDim.new(0, 4),
					}),

					ComposeButtons = applyingState ~= "ComposeAll" and React.createElement(React.Fragment, nil, {
						Compose = React.createElement(StudioComponents.MainButton, {
							Size = UDim2.fromScale(1, 1),
							Text = "Compose",
							Disabled = disabled,
							LayoutOrder = -1,

							Icon = {
								Image = IMAGE_ICON.Url,
								RectSize = IMAGE_ICON.ImageRectSize,
								RectOffset = IMAGE_ICON.ImageRectOffset,
								Size = Vector2.new(IMAGE_ICON.ImageRectSize.X, IMAGE_ICON.ImageRectSize.Y),
								UseThemeColor = true,
							},

							OnActivated = function()
								cancelApplyingRef.current = false
								setApplyingState("Compose")

								local editImage = controller.editImage
								if editImage then
									local composed = controller:composeImageAsync(editImage)
									local name = selected.nameByImage[editImage]
									local meshPart = Photo.getQuadMeshPart()
									meshPart.Name = if name then `{name}_Composed` else "Composed"
									meshPart.TextureContent = Content.fromObject(composed)
									meshPart.Parent = game:GetService("StarterGui")
								end

								setApplyingState("None")
							end,
						}),

						ComposeAll = React.createElement(StudioComponents.Button, {
							Size = UDim2.fromScale(1, 1),
							Text = "Compose All",
							Disabled = disabled,
							LayoutOrder = -2,

							Icon = {
								Image = IMAGES_ICON.Url,
								RectSize = IMAGES_ICON.ImageRectSize,
								RectOffset = IMAGES_ICON.ImageRectOffset,
								Size = Vector2.new(IMAGES_ICON.ImageRectSize.X, IMAGES_ICON.ImageRectSize.Y),
								UseThemeColor = true,
							},

							OnActivated = function()
								cancelApplyingRef.current = false
								setApplyingState("ComposeAll")

								local folder = Instance.new("Folder")
								for i, editImage in selected.images do
									if cancelApplyingRef.current then
										break
									end

									local composed = controller:composeImageAsync(editImage)
									local meshPart = Photo.getQuadMeshPart()
									meshPart.Name = selected.nameByImage[editImage] or `{i}_Composition`
									meshPart.TextureContent = Content.fromObject(composed)
									meshPart.Parent = folder
								end

								if #folder:GetChildren() > 0 then
									folder.Name = "Composed"
									folder.Parent = game:GetService("StarterGui")

									game:GetService("Selection"):Set({ folder })
								else
									folder:Destroy()
								end

								setApplyingState("None")
							end,
						}),
					}),

					CancelButton = applyingState == "ComposeAll" and React.createElement(StudioComponents.Button, {
						Size = UDim2.fromScale(1, 1),
						Text = "Cancel",
						Disabled = props.Disabled,
						LayoutOrder = -1,

						OnActivated = function()
							cancelApplyingRef.current = true
						end,
					}),
				}),
			}),
		}),

		Focus = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 2,
		}, {
			Tracker = isDirty and React.createElement("ImageButton", {
				ZIndex = 2,
				BackgroundTransparency = 1,
				Size = UDim2.fromScale(1, 1),
				[React.Event.Activated] = function()
					setApprovedImage(selectedEditImage)
				end,
			}),

			Blur = blurTransparency.value < 1 and React.createElement("Frame", {
				BorderSizePixel = 0,
				BackgroundTransparency = math.lerp(0.3, 1, blurTransparency.value),
				BackgroundColor3 = Color3.new(0, 0, 0),
				Size = UDim2.fromScale(1, 1),
			}, {
				UILayout = React.createElement("UIListLayout", {
					SortOrder = Enum.SortOrder.LayoutOrder,
					FillDirection = Enum.FillDirection.Vertical,
					VerticalAlignment = Enum.VerticalAlignment.Center,
					HorizontalAlignment = Enum.HorizontalAlignment.Center,
					Padding = UDim.new(0, 16),
				}),

				Label = React.createElement("TextLabel", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, 0, 0, 24),
					BackgroundTransparency = 1,
					FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
					Text = "Selection changed - Click to refresh",
					TextScaled = true,
					TextTransparency = blurTransparency.value,
					TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
					LayoutOrder = 1,
				}),
				Icon = React.createElement("ImageLabel", {
					Size = UDim2.fromOffset(FOCUS_ICON.ImageRectSize.X, FOCUS_ICON.ImageRectSize.Y),
					BackgroundTransparency = 1,
					Image = FOCUS_ICON.Url,
					ImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
					ImageTransparency = blurTransparency.value,
					ImageRectSize = FOCUS_ICON.ImageRectSize,
					ImageRectOffset = FOCUS_ICON.ImageRectOffset,
					LayoutOrder = 2,
				}),
			}),
		}),
	})
end

return function(props: Props)
	return React.createElement(OverlayMenu.provider, nil, {
		Widget = React.createElement(Widget, props),
	})
end
