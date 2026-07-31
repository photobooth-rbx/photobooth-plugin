local pluginRoot = script:FindFirstAncestor("PluginRoot")
local React = require(pluginRoot.Packages.React)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Toolbar = require(uiRoot.Helpers.Toolbar)

local function useDockButton(dock: DockWidgetPluginGui, button: Toolbar.Button)
	local isEnabled, setIsEnabled = React.useState(dock.Enabled)

	React.useEffect(function()
		button:SetActive(dock.Enabled)
		setIsEnabled(dock.Enabled)

		dock:BindToClose(function()
			dock.Enabled = false
		end)

		local onClick = button.Click:Connect(function()
			dock.Enabled = not dock.Enabled
		end)

		local onToggle = dock:GetPropertyChangedSignal("Enabled"):Connect(function()
			button:SetActive(dock.Enabled)
			setIsEnabled(dock.Enabled)
		end)

		return function()
			onClick:Disconnect()
			onToggle:Disconnect()
		end
	end, {})

	return isEnabled
end

return useDockButton
