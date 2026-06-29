local uiRoot = script:FindFirstAncestor("UserInterface")
local Icons = require(uiRoot.Icons)

local ToolbarIcon = {}

local function getIcon(iconName: string)
	local theme = settings().Studio.Theme
	return assert(Icons.processed[theme.Name:lower()][iconName] :: string?)
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
