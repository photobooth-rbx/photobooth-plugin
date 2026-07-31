local Button = require(script.Button)

local MENU_BUTTON_ID = "egomoose_photobooth_compact_button"
local MENU_BUTTON_TOOLTIP = "Open the Photobooth menu"
local MENU_BUTTON_TEXT = "Photobooth"
local MENU_BUTTON_ICON = "logo"

local MENU_ID = "egomoose_photobooth_compact_menu"
local MENU_TITLE = "Photobooth"

local ToolbarStatic = {}

local ToolbarClass = {}
ToolbarClass.__index = ToolbarClass
ToolbarClass.ClassName = "Toolbar"

export type Button = Button.Button

export type Toolbar = typeof(setmetatable(
	{} :: {
		plugin: Plugin,
		toolbar: PluginToolbar,
		buttons: { Button },
		menuButton: Button?,
		isMenuOpen: boolean,
		menuCount: number,
	},
	ToolbarClass
))

function ToolbarStatic.new(plugin: Plugin, toolbar: PluginToolbar, compact: boolean)
	local self = setmetatable({}, ToolbarClass) :: Toolbar

	self.plugin = plugin
	self.toolbar = toolbar
	self.buttons = {}
	self.isMenuOpen = false
	self.menuCount = 0

	if compact then
		local menuButton = Button.new(MENU_BUTTON_ID, MENU_BUTTON_TOOLTIP, MENU_BUTTON_ICON, MENU_BUTTON_TEXT, toolbar)
		self.menuButton = menuButton

		menuButton.Click:Connect(function()
			self:_showMenu()
		end)

		plugin.Unloading:Connect(function()
			menuButton:Destroy()
		end)
	end

	return self
end

function ToolbarClass._showMenu(self: Toolbar)
	local menuButton = self.menuButton
	if not menuButton then
		return
	end

	if self.isMenuOpen then
		return
	end

	self.menuCount = self.menuCount + 1
	local menu = self.plugin:CreatePluginMenu(`{MENU_ID}_{self.menuCount}`, MENU_TITLE)
	local buttonByAction: { [PluginAction]: Button } = {}

	for _, button in self.buttons do
		if button.destroyed then
			continue
		end

		local action = menu:AddNewAction(`{button.id}_{button.iconVariant}`, button.text, button.icon)
		buttonByAction[action] = button
	end

	self.isMenuOpen = true
	menuButton:SetActive(true)

	local selected = menu:ShowAsync() :: PluginAction?

	menuButton:SetActive(false)
	self.isMenuOpen = false

	local button = if selected then buttonByAction[selected] else nil
	menu:Destroy()

	if button then
		button:Activate()
	end
end

function ToolbarClass.CreateButton(self: Toolbar, id: string, toolTip: string, iconName: string, text: string): Button
	local backing = if self.menuButton then nil else self.toolbar
	local button = Button.new(id, toolTip, iconName, text, backing)

	table.insert(self.buttons, button)

	return button
end

return ToolbarStatic
