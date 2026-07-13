local StudioService = game:GetService("StudioService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local LucideIconButton = require(uiRoot.Components.LucideIconButton)
local Hooks = require(uiRoot.Hooks)

local UnderlineTextButton = require(script.UnderlineTextButton)

local HEADER_HEIGHT = 23
local ELEMENT_HEIGHT = 23

local CLEAR_ICON = assert(Lucide.GetAsset("circle-x", 16))
local CLEAR_ALL_ICON = assert(Lucide.GetAsset("trash", 12))

local LEFT_ICON = assert(Lucide.GetAsset("chevron-left", 16))
local RIGHT_ICON = assert(Lucide.GetAsset("chevron-right", 16))

export type ListElement<T> = {
	instance: T & Instance,
	className: string,
	isSelected: boolean?,
}

export type List<T> = { ListElement<T> }

export type Props<T> = {
	AnchorPoint: Vector2?,
	Position: UDim2?,
	Size: UDim2?,

	ListRef: { current: List<T> },
	ForceRender: () -> (),
	OnListElementAdded: (ListElement<T>) -> (),
	OnListElementSelected: (ListElement<T>?) -> (),
	OnListElementRemoved: (ListElement<T>) -> (),

	OverrideClassName: string?,
	FilterSelection: (Instance) -> Instance?,

	LayoutOrder: number?,
	Disabled: boolean?,
}

type ListProps<T> = {
	Index: number,
	Element: ListElement<T>,

	ListRef: { current: List<T> },
	ForceRender: () -> (),
	OnListElementSelected: (ListElement<T>?) -> (),
	OnListElementRemoved: (ListElement<T>) -> (),

	OverrideClassName: string?,

	Disabled: boolean?,
}

type ClassIcon = {
	Image: string,
	ImageRectOffset: Vector2,
	ImageRectSize: Vector2,
}

local function ListElement<T>(props: ListProps<T>)
	local element = props.Element
	local list = props.ListRef.current
	local classIcon = StudioService:GetClassIcon(props.OverrideClassName or element.className) :: ClassIcon

	local theme = StudioComponents.useTheme()
	local elementName, setElementName = React.useState(element.instance.Name)

	React.useEffect(function()
		setElementName(element.instance.Name)
		local connection = element.instance:GetPropertyChangedSignal("Name"):Connect(function()
			setElementName(element.instance.Name)
		end)

		return function()
			connection:Disconnect()
		end
	end, { element.instance })

	return React.createElement("TextButton", {
		Size = UDim2.new(1, 0, 0, ELEMENT_HEIGHT),
		AutoButtonColor = false,
		Text = "",

		BackgroundColor3 = if element.isSelected
			then theme:GetColor(Enum.StudioStyleGuideColor.DialogMainButton)
			else theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

		LayoutOrder = props.Index,
		ZIndex = -props.Index,

		[React.Event.Activated] = function()
			if not props.Disabled and not element.isSelected then
				for _, otherInfo in list do
					otherInfo.isSelected = nil
				end
				element.isSelected = true
				props.ForceRender()
				props.OnListElementSelected(element)
			end
		end,
	}, {
		Container = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Padding = React.createElement("UIPadding", {
				PaddingLeft = UDim.new(0, 4),
				PaddingRight = UDim.new(0, 0),
				PaddingTop = UDim.new(0, 0),
				PaddingBottom = UDim.new(0, 0),
			}),

			ClassIcon = React.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(22, 22),
			}, {
				Icon = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(classIcon.ImageRectSize.X, classIcon.ImageRectSize.Y),
					Image = classIcon.Image,
					ImageRectSize = classIcon.ImageRectSize,
					ImageRectOffset = classIcon.ImageRectOffset,
					ImageColor3 = theme:GetColor(
						Enum.StudioStyleGuideColor.MainText,
						if props.Disabled
							then Enum.StudioStyleGuideModifier.Disabled
							else Enum.StudioStyleGuideModifier.Default
					),
				}),
			}),

			Label = React.createElement(StudioComponents.Label, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 26, 0.5, 0),
				Size = UDim2.new(1, -26, 1, 0),
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColorStyle = if element.isSelected
					then Enum.StudioStyleGuideColor.DialogMainButtonText
					else Enum.StudioStyleGuideColor.MainText,
				Text = elementName,
				Disabled = props.Disabled,
			}),
			ClearButton = React.createElement(LucideIconButton, {
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.fromOffset(22, 22),
				IconSize = UDim2.fromOffset(14, 14),
				Icon = CLEAR_ICON,
				Disabled = props.Disabled,
				OnActivated = function()
					local popped = table.remove(list, props.Index)
					local prev = list[math.max(1, props.Index - 1)]
					if popped and popped.isSelected and prev then
						prev.isSelected = true
					end

					props.ForceRender()
					props.OnListElementRemoved(element)

					if prev then
						props.OnListElementSelected(prev)
					else
						props.OnListElementSelected(nil)
					end
				end,
			}),
		}),
	})
end

local function InstanceList<T>(props: Props<T>)
	local theme = StudioComponents.useTheme()
	local selection = Hooks.useSelection()

	local filteredSelection = {}
	for _, selected in selection do
		local result = props.FilterSelection(selected)
		if result then
			table.insert(filteredSelection, result)
		end
	end

	local nSelection = #filteredSelection
	local list = props.ListRef.current
	local nList = #list

	local selectedIndex = 0
	local lines: { [string]: React.Node } = {}
	for i, element in list do
		if element.isSelected then
			selectedIndex = i
		end

		lines[`Line{i}`] = React.createElement(ListElement, {
			Index = i,
			Element = element,

			ListRef = props.ListRef,
			ForceRender = props.ForceRender,
			OnListElementSelected = props.OnListElementSelected,
			OnListElementRemoved = props.OnListElementRemoved,

			OverrideClassName = props.OverrideClassName,

			Disabled = props.Disabled,
		})
	end

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = props.AnchorPoint,
		Position = props.Position,
		Size = props.Size,
		LayoutOrder = props.LayoutOrder,
	}, {
		UIListLayout = React.createElement("UIListLayout", {
			FillDirection = Enum.FillDirection.Vertical,
			SortOrder = Enum.SortOrder.LayoutOrder,
			Padding = UDim.new(0, 0),
		}),

		Header = React.createElement("Frame", {
			Size = UDim2.new(1, 0, 0, HEADER_HEIGHT),

			BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Titlebar),
			BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

			LayoutOrder = 1,
			ZIndex = 2,
		}, {
			ClearAllButton = React.createElement(LucideIconButton, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.fromScale(0, 0.5),
				Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
				Icon = CLEAR_ALL_ICON,
				Disabled = props.Disabled,
				OnActivated = function()
					local allElements = table.clone(list)
					table.clear(list)
					props.ForceRender()
					for _, element in allElements do
						props.OnListElementRemoved(element)
					end
					props.OnListElementSelected(nil)
				end,
			}),

			AddMore = React.createElement(UnderlineTextButton, {
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, HEADER_HEIGHT, 0.5, 0),
				Size = UDim2.new(0, 100, 1, 0),

				Text = `+ Add Selected ({nSelection})`,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,

				OnActivated = function()
					local newElements = {}
					local prevLastIndex = nList
					for _, selected in filteredSelection do
						local element: ListElement<T> = {
							name = selected.Name,
							instance = selected :: any,
							className = selected.ClassName,
						}

						table.insert(newElements, element)
						table.insert(list, element)
					end

					local firstNewElement = list[prevLastIndex + 1]
					if firstNewElement then
						for _, element in list do
							element.isSelected = false
						end
						firstNewElement.isSelected = true
					end

					props.ForceRender()
					for _, element in newElements do
						props.OnListElementAdded(element)
					end
					props.OnListElementSelected(firstNewElement)
				end,

				Disabled = nSelection == 0 or not not props.Disabled,
			}, {
				Padding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 0),
					PaddingTop = UDim.new(0, 0),
					PaddingBottom = UDim.new(0, 0),
				}),
			}),

			Counter = React.createElement("Frame", {
				BackgroundTransparency = 1,
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.fromScale(1, 0.5),
				Size = UDim2.new(0, HEADER_HEIGHT * 3.5, 1, 0),
			}, {
				Left = React.createElement(LucideIconButton, {
					AnchorPoint = Vector2.new(0, 0.5),
					Position = UDim2.fromScale(0, 0.5),
					Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
					Icon = LEFT_ICON,
					Disabled = nList == 0 or not not props.Disabled,
					OnActivated = function()
						local nextIndex = ((selectedIndex - 2) % nList) + 1
						list[selectedIndex].isSelected = false
						list[nextIndex].isSelected = true
						props.ForceRender()
						props.OnListElementSelected(list[nextIndex])
					end,
				}),
				Right = React.createElement(LucideIconButton, {
					AnchorPoint = Vector2.new(1, 0.5),
					Position = UDim2.fromScale(1, 0.5),
					Size = UDim2.fromOffset(HEADER_HEIGHT, HEADER_HEIGHT),
					Icon = RIGHT_ICON,
					Disabled = nList == 0 or not not props.Disabled,
					OnActivated = function()
						local nextIndex = (selectedIndex % nList) + 1
						list[selectedIndex].isSelected = false
						list[nextIndex].isSelected = true
						props.ForceRender()
						props.OnListElementSelected(list[nextIndex])
					end,
				}),

				CenterLabel = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.new(1, -HEADER_HEIGHT * 2, 1, 0),
					TextXAlignment = Enum.TextXAlignment.Center,
					TextYAlignment = Enum.TextYAlignment.Center,
					TextTruncate = Enum.TextTruncate.AtEnd,
					TextColor3 = theme:GetColor(
						Enum.StudioStyleGuideColor.MainText,
						if props.Disabled or nList == 0
							then Enum.StudioStyleGuideModifier.Disabled
							else Enum.StudioStyleGuideModifier.Default
					),
					FontFace = Font.fromName("SourceSansPro"),
					Text = `{selectedIndex} / {#list}`,
					TextScaled = true,
				}, {
					UITextSizeConstraint = React.createElement("UITextSizeConstraint", {
						MaxTextSize = 14,
						MinTextSize = 1,
					}),
				}),
			}),
		}),

		Content = React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 1, -HEADER_HEIGHT),
			LayoutOrder = 2,
		}, {
			Scroll = React.createElement(StudioProperties.VerticalScroll, {
				Size = UDim2.fromScale(1, 1),
				GradientHeight = 22,
				ScrollInset = UDim.new(0, -2),
				ScrollBarTransparency = 0.7,
				ScrollBarFades = true,
			}, {
				UIListLayout = React.createElement("UIListLayout", {
					FillDirection = Enum.FillDirection.Vertical,
					SortOrder = Enum.SortOrder.LayoutOrder,
					Padding = UDim.new(0, 0),
				}),
				BottomPadding = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Size = UDim2.new(1, 0, 0, 22),
					LayoutOrder = nList + 1,
				}),
			}, lines),
		}),
	})
end

return InstanceList
