local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")

local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local StudioProperties = require(pluginRoot.Packages.StudioProperties)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)
local Wally = require(pluginRoot.Wally)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Toolbar = require(uiRoot.Helpers.Toolbar)
local Hooks = require(uiRoot.Hooks)

local Widget = require(script.Components.Widget)
local Permissions = require(script.Components.Permissions)

local Upload = {
	priority = 3000,
}

local function tryUpload(_index: number, name: string, editImage: EditableImage, creator: Widget.Creator): number?
	local result: Enum.CreateAssetResult
	local value: number | string

	result, value = AssetService:CreateAssetAsync(editImage, Enum.AssetType.Image, {
		CreatorId = creator.Id,
		CreatorType = creator.Type,

		Name = name,
		Description = table.concat({
			"Uploaded with the Photobooth plugin.",
			"",
			HttpService:JSONEncode({
				Dimensions = { editImage.Size.X, editImage.Size.Y },
				Version = Wally.package.version,
			}),
		}, "\n"),
	})

	if result == Enum.CreateAssetResult.Success then
		return value :: number
	end

	warn(value :: string)
	return nil
end

local function testCreator(creator: Widget.Creator): boolean
	return creator.Id > 0
end

function Upload.mount(plugin: Plugin, toolbar: Toolbar.Toolbar)
	-- stylua: ignore
	local button = toolbar:CreateButton(
		"egomoose_photobooth_addon_upload",
		"Photobooth Upload", "upload-button", "Upload"
	)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 360, 420, 360, 420)
	local dock = plugin:CreateDockWidgetPluginGuiAsync("egomoose_photobooth_addon_upload", info)
	dock.Name = "Photobooth Upload"
	dock.Title = "Photobooth - Upload"
	dock.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function App()
		local isEnabled = Hooks.useDockButton(dock, button)

		return React.createElement(React.Fragment, nil, {
			Widget = isEnabled and React.createElement(Widget, {
				Size = UDim2.fromScale(1, 1),

				TryUpload = tryUpload,
				TestCreator = testCreator,

				Disabled = false,
			}),

			Permissions = not isEnabled and React.createElement(Permissions, {}),
		})
	end

	local dockRoot = ReactRoblox.createRoot(dock)
	dockRoot:render(React.createElement(StudioProperties.PluginContext.Provider, {
		value = plugin,
	}, {
		ComponentsPlugin = React.createElement(StudioComponents.PluginProvider, {
			Plugin = plugin,
		}, {
			App = React.createElement(App),
		}),
	}))

	plugin.Unloading:Connect(function()
		dockRoot:unmount()
		dock:Destroy()
		button:Destroy()
	end)
end

return Upload
