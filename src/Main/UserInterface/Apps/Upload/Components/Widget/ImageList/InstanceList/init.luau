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

		BackgroundColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainBackground),
		BorderColor3 = theme:GetColor(Enum.StudioStyleGuideColor.Border),

		LayoutOrder = props.Index,
		ZIndex = -props.Index,
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
					table.remove(list, props.Index)
					props.ForceRender()
					props.OnListElementRemoved(element)
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

	local lines: { [string]: React.Node } = {}
	for i, element in list do
		lines[`Line{i}`] = React.createElement(ListElement, {
			Index = i,
			Element = element,

			ListRef = props.ListRef,
			ForceRender = props.ForceRender,
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
					for _, selected in filteredSelection do
						local element: ListElement<T> = {
							name = selected.Name,
							instance = selected :: any,
							className = selected.ClassName,
						}

						table.insert(newElements, element)
						table.insert(list, element)
					end

					props.ForceRender()
					for _, element in newElements do
						props.OnListElementAdded(element)
					end
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
