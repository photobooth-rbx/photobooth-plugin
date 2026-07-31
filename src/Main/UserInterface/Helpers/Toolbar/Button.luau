local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Signal = require(pluginRoot.Packages.Signal)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Asphalt = require(uiRoot.Asphalt)

local ButtonStatic = {}

local ButtonClass = {}
ButtonClass.__index = ButtonClass
ButtonClass.ClassName = "ToolbarButton"

export type Button = typeof(setmetatable(
	{} :: {
		Click: Signal.Signal<()>,

		id: string,
		toolTip: string,
		text: string,
		iconName: string,

		icon: string,
		iconVariant: string,
		enabled: boolean,
		active: boolean,
		destroyed: boolean,

		instance: PluginToolbarButton?,
		connections: { RBXScriptConnection },
	},
	ButtonClass
))

local function getIconVariant(selected: boolean): string
	local themeName = settings().Studio.Theme.Name:lower()
	return if selected then `{themeName}_selected` else themeName
end

function ButtonStatic.new(id: string, toolTip: string, iconName: string, text: string, toolbar: PluginToolbar?)
	local self = setmetatable({}, ButtonClass) :: Button

	self.Click = Signal.new()

	self.id = id
	self.toolTip = toolTip
	self.text = text
	self.iconName = iconName

	self.icon = ""
	self.iconVariant = ""
	self.enabled = true
	self.active = false
	self.destroyed = false
	self.connections = {}

	if toolbar then
		-- stylua: ignore
		local instance = toolbar:CreateButton(
			id, toolTip,
			"", text
		)

		self.instance = instance
		table.insert(
			self.connections,
			instance.Click:Connect(function()
				self:Activate()
			end)
		)
	end

	self:_refreshIcon()
	table.insert(
		self.connections,
		settings().Studio.ThemeChanged:Connect(function()
			self:_refreshIcon()
		end)
	)

	return self
end

function ButtonClass._refreshIcon(self: Button)
	self.iconVariant = getIconVariant(self.instance == nil and self.active)
	self.icon = assert(Asphalt.processed[self.iconVariant][self.iconName] :: string?)

	local instance = self.instance
	if instance then
		instance.Icon = self.icon
	end
end

function ButtonClass.Activate(self: Button)
	if self.enabled and not self.destroyed then
		self.Click:Fire()
	end
end

function ButtonClass.SetEnabled(self: Button, enabled: boolean)
	self.enabled = enabled

	local instance = self.instance
	if instance then
		instance.Enabled = enabled
	end
end

function ButtonClass.SetActive(self: Button, active: boolean)
	if self.active == active then
		return
	end

	self.active = active

	local instance = self.instance
	if instance then
		instance:SetActive(active)
	else
		self:_refreshIcon()
	end
end

function ButtonClass.Destroy(self: Button)
	if self.destroyed then
		return
	end

	self.destroyed = true

	for _, connection in self.connections do
		connection:Disconnect()
	end
	table.clear(self.connections)

	local instance = self.instance
	if instance then
		instance:Destroy()
		self.instance = nil
	end

	self.Click:Destroy()
end

return ButtonStatic
