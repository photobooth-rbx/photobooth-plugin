local StudioService = game:GetService("StudioService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local postProcessingRoot = script:FindFirstAncestor("PostProcessing")
local Controller = require(postProcessingRoot.Controller)
local CubeLut = require(postProcessingRoot.Controller.CubeLut)

local CLEAR_ICON = assert(Lucide.GetAsset("trash", 16))
local IMPORT_ICON = assert(Lucide.GetAsset("folder-open", 16))

local ICON_WIDTH = 22

export type Props = {
	Controller: Controller.PostProcessingController,
	LayerId: string,
	Lut: Controller.Lut?,
	Disabled: boolean?,
	LayoutOrder: number?,
}

local function LutProperty(props: Props)
	local theme = StudioComponents.useTheme()
	local errorText, setErrorText = React.useState(function(): string?
		return nil
	end)

	React.useEffect(function()
		setErrorText(nil)
	end, { props.Lut })

	local hasLut = props.Lut ~= nil

	local displayText: string
	local displayColor: Color3
	if errorText then
		displayText = errorText
		displayColor = theme:GetColor(Enum.StudioStyleGuideColor.ErrorText)
	elseif props.Lut then
		displayText = `{props.Lut.name} ({props.Lut.size}³)`
		displayColor = theme:GetColor(
			Enum.StudioStyleGuideColor.MainText,
			if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
		)
	else
		displayText = "Import .cube…"
		displayColor = theme:GetColor(Enum.StudioStyleGuideColor.MainText, Enum.StudioStyleGuideModifier.Disabled)
	end

	local function importLut()
		if props.Disabled then
			return
		end
		task.spawn(function()
			local file = (StudioService:PromptImportFileAsync({ "cube" }) :: any) :: File?
			if not file then
				return
			end

			local lut, err = CubeLut.parse(file:GetBinaryContents(), file.Name)
			if lut then
				props.Controller:setLayerLut(props.LayerId, lut)
			else
				local message = err or "Failed to parse .cube file."
				setErrorText(message)
				warn(`[LUT] {file.Name}: {message}`)
			end
		end)
	end

	return React.createElement(StudioProperties.PropertyLine, {
		FieldName = "LUT",
		Disabled = props.Disabled,
		LayoutOrder = props.LayoutOrder,

		Interface = React.createElement("Frame", {
			Active = false,
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			ImportButton = React.createElement("TextButton", {
				AutoButtonColor = false,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, -ICON_WIDTH, 1, 0),
				FontFace = Font.fromName("SourceSansPro"),
				TextYAlignment = Enum.TextYAlignment.Center,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = displayColor,
				Text = displayText,
				TextSize = 14,

				[React.Event.Activated] = function()
					importLut()
				end,
			}, {
				UIPadding = React.createElement("UIPadding", {
					PaddingLeft = UDim.new(0, 4),
					PaddingRight = UDim.new(0, 4),
				}),
			}),

			ActionButton = React.createElement("ImageButton", {
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, ICON_WIDTH, 1, 0),
				BackgroundTransparency = 1,
				AutoButtonColor = not props.Disabled,

				[React.Event.Activated] = function()
					if props.Disabled then
						return
					end
					if hasLut then
						props.Controller:setLayerLut(props.LayerId, nil)
					else
						importLut()
					end
				end,
			}, {
				Icon = React.createElement("ImageLabel", {
					BackgroundTransparency = 1,
					AnchorPoint = Vector2.new(0.5, 0.5),
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromOffset(12, 12),
					Image = if hasLut then CLEAR_ICON.Url else IMPORT_ICON.Url,
					ImageRectSize = if hasLut then CLEAR_ICON.ImageRectSize else IMPORT_ICON.ImageRectSize,
					ImageRectOffset = if hasLut then CLEAR_ICON.ImageRectOffset else IMPORT_ICON.ImageRectOffset,
					ImageColor3 = theme:GetColor(
						Enum.StudioStyleGuideColor.MainText,
						if props.Disabled then Enum.StudioStyleGuideModifier.Disabled else nil
					),
				}),
			}),
		}) :: React.ReactNode,
	})
end

return LutProperty
