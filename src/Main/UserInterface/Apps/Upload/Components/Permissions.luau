local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local Lucide = require(pluginRoot.Packages.Lucide)
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Hooks = require(uiRoot.Hooks)

local ICON = assert(Lucide.GetAsset("ban", 48))

local function usePermissions()
	local hasCreateAssetPermission = Hooks.useHasCreateAssetPermission()
	local isLocalPlugin = Hooks.useIsLocalPlugin()
	local isStory = Hooks.useIsStory()
	if isStory then
		hasCreateAssetPermission = true
	end

	return {
		disabled = not (isLocalPlugin and hasCreateAssetPermission),
		isLocalPlugin = isLocalPlugin,
		hasCreateAssetPermission = hasCreateAssetPermission,
	}
end

local function Permissions(_props: {})
	local theme = StudioComponents.useTheme()
	local permissions = usePermissions()

	return React.createElement("Frame", {
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
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
			Size = UDim2.fromOffset(ICON.ImageRectSize.X, ICON.ImageRectSize.Y),
			BackgroundTransparency = 1,
			Image = ICON.Url,
			ImageColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
			ImageRectSize = ICON.ImageRectSize,
			ImageRectOffset = ICON.ImageRectOffset,
		}),
		Label = React.createElement("TextLabel", {
			LayoutOrder = 2,
			Size = UDim2.new(1, 0, 0, 18),
			BackgroundTransparency = 1,
			Text = "In order to use this tool:",
			FontFace = Font.fromName("SourceSansPro", Enum.FontWeight.Bold),
			TextScaled = true,
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
		}),
		Spacer = React.createElement("Frame", {
			LayoutOrder = 3,
			Size = UDim2.new(1, 0, 0, 4),
			BackgroundTransparency = 1,
		}),
		Label2 = React.createElement("TextLabel", {
			LayoutOrder = 4,
			Size = UDim2.new(0.8, 0, 0, 14),
			BackgroundTransparency = 1,
			Text = `1. It must be installed locally {if permissions.isLocalPlugin then "✅" else "❌"}`,
			TextSize = 14,
			FontFace = Font.fromName("SourceSansPro"),
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
		}),
		Label3 = React.createElement("TextLabel", {
			LayoutOrder = 5,
			BackgroundTransparency = 1,
			Size = UDim2.new(0.8, 0, 0, 14),
			TextSize = 14,
			Text = `2. The CreateAssetAsync Lua API Beta must be enabled {if permissions.hasCreateAssetPermission
				then "✅"
				else "❌"}`,
			FontFace = Font.fromName("SourceSansPro"),
			TextColor3 = theme:GetColor(Enum.StudioStyleGuideColor.MainText),
		}),
	})
end

return Permissions
