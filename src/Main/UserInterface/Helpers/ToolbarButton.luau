local uiRoot = script:FindFirstAncestor("UserInterface")
local Asphalt = require(uiRoot.Asphalt)

local ToolbarIcon = {}

local function getIcon(iconName: string)
	local theme = settings().Studio.Theme
	return assert(Asphalt.processed[theme.Name:lower()][iconName] :: string?)
end

function ToolbarIcon.listen(button: PluginToolbarButton, iconName: string)
	local function onThemeChanged()
		button.Icon = getIcon(iconName)
	end

	onThemeChanged()
	local connection = settings().Studio.ThemeChanged:Connect(onThemeChanged)

	button.Destroying:Once(function()
		connection:Disconnect()
	end)
end

return ToolbarIcon
