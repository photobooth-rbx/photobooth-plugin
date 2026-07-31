-- Stands in for a PluginToolbar, but instead of giving every app its own toolbar button
-- it creates a single button that opens a plugin menu listing each of the apps.
-- The objects handed back by CreateButton support the subset of the PluginToolbarButton
-- api that the apps make use of, so the apps do not need to know which one they got.

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Signal = require(pluginRoot.Packages.Signal)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ToolbarButton = require(uiRoot.Helpers.ToolbarButton)

local BUTTON_ID = "egomoose_photobooth_compact_button"
local BUTTON_TOOLTIP = "Open the Photobooth menu"
local BUTTON_TEXT = "Photobooth"
local BUTTON_ICON = "camera-plugin-button"

local MENU_ID = "egomoose_photobooth_compact_menu"
local MENU_TITLE = "Photobooth"

-- MenuEntry

local MenuEntryStatic = {}

local MenuEntryClass = {}
MenuEntryClass.__index = MenuEntryClass
MenuEntryClass.ClassName = "MenuEntry"

export type MenuEntry = typeof(setmetatable(
	{} :: {
		-- PluginToolbarButton stand ins
		Click: Signal.Signal<()>,
		Destroying: Signal.Signal<()>,
		Enabled: boolean,
		Icon: string,

		actionId: string,
		toolTip: string,
		text: string,
		active: boolean,
		destroyed: boolean,
	},
	MenuEntryClass
))

function MenuEntryStatic.new(actionId: string, toolTip: string, text: string)
	local self = setmetatable({}, MenuEntryClass) :: MenuEntry

	self.Click = Signal.new()
	self.Destroying = Signal.new()
	self.Enabled = true
	self.Icon = ""

	self.actionId = actionId
	self.toolTip = toolTip
	self.text = text
	self.active = false
	self.destroyed = false

	return self
end

function MenuEntryClass.SetActive(self: MenuEntry, active: boolean)
	self.active = active
end

function MenuEntryClass.Destroy(self: MenuEntry)
	self.destroyed = true
	self.Destroying:Fire()
	self.Destroying:Destroy()
	self.Click:Destroy()
end

-- CompactToolbar

local CompactToolbarStatic = {}

local CompactToolbarClass = {}
CompactToolbarClass.__index = CompactToolbarClass
CompactToolbarClass.ClassName = "CompactToolbar"

export type CompactToolbar = typeof(setmetatable(
	{} :: {
		plugin: Plugin,
		button: PluginToolbarButton,
		entries: { MenuEntry },
		isMenuOpen: boolean,
		menuCount: number,
	},
	CompactToolbarClass
))

function CompactToolbarStatic.new(plugin: Plugin, toolbar: PluginToolbar)
	local self = setmetatable({}, CompactToolbarClass) :: CompactToolbar

	self.plugin = plugin
	self.entries = {}
	self.isMenuOpen = false
	self.menuCount = 0

	-- stylua: ignore
	self.button = toolbar:CreateButton(
		BUTTON_ID,
		BUTTON_TOOLTIP,
		"", BUTTON_TEXT
	)

	ToolbarButton.listen(self.button, BUTTON_ICON)

	local clickConnection = self.button.Click:Connect(function()
		self:_showMenu()
	end)

	plugin.Unloading:Connect(function()
		clickConnection:Disconnect()
		self.button:Destroy()
	end)

	return self
end

function CompactToolbarClass._showMenu(self: CompactToolbar)
	-- ShowAsync yields, so guard against the menu being opened on top of itself
	if self.isMenuOpen then
		return
	end

	-- the menu is rebuilt on every open so that it can pick up icon changes from
	-- the studio theme as well as the enabled/active state of each entry
	-- the count keeps each build's id unique, the old menus are destroyed after use
	self.menuCount = self.menuCount + 1
	local menu = self.plugin:CreatePluginMenu(`{MENU_ID}_{self.menuCount}`, MENU_TITLE)
	local entryByAction: { [PluginAction]: MenuEntry } = {}

	for _, entry in self.entries do
		if entry.destroyed then
			continue
		end

		local action = menu:AddNewAction(entry.actionId, entry.text, entry.Icon)
		-- action.StatusTip = entry.toolTip
		-- action.Enabled = entry.Enabled
		-- action.Checked = entry.active

		entryByAction[action] = entry
	end

	self.isMenuOpen = true
	self.button:SetActive(true)

	local selected = menu:ShowAsync() :: PluginAction?

	self.button:SetActive(false)
	self.isMenuOpen = false

	local entry = if selected then entryByAction[selected] else nil
	menu:Destroy()

	if entry then
		entry.Click:Fire()
	end
end

function CompactToolbarClass.CreateButton(
	self: CompactToolbar,
	id: string,
	toolTip: string,
	_iconAsset: string,
	text: string?
): PluginToolbarButton
	local entry = MenuEntryStatic.new(id, toolTip, text or toolTip)
	table.insert(self.entries, entry)

	-- the entry is not a real instance, but it walks and talks like the parts of a
	-- PluginToolbarButton that the apps use
	return entry :: any
end

return CompactToolbarStatic
