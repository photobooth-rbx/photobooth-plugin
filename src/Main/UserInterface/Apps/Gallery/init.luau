local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local Blackout = require(pluginRoot.Main.Photo.Tools.Blackout)
local StateManager = require(pluginRoot.Main.StateManager)
local Constants = require(pluginRoot.Constants)
local Wally = require(pluginRoot.Wally)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Toolbar = require(uiRoot.Helpers.Toolbar)

local Gallery = require(script.Components.Gallery)

local GalleryApp = {}

local WIDGET_INFO = DockWidgetPluginGuiInfo.new(
	Enum.InitialDockState.Float, -- Widget will be initialized in floating panel
	false, -- Widget will be initially enabled
	false, -- Don't override the previous enabled state
	Constants.DockWidgetSize.X, -- Default width of the floating window
	Constants.DockWidgetSize.Y, -- Default height of the floating window
	Constants.DockWidgetSize.X, -- Minimum width of the floating window
	Constants.DockWidgetSize.Y -- Minimum height of the floating window
)

local function mountBlackoutMode(plugin: Plugin)
	local function refreshBlackout()
		Blackout.setDisabled("default", not StateManager.temporary:get().isBlackoutMode)
	end

	refreshBlackout()
	local connection = StateManager.temporary:onChanged(refreshBlackout)

	plugin.Unloading:Connect(function()
		connection:Disconnect()
		Blackout.reset()
	end)
end

function GalleryApp.mount(plugin: Plugin, toolbar: Toolbar.Toolbar)
	-- stylua: ignore
	local openButton = toolbar:CreateButton(
		"egomoose_photobooth_gallery_button",
		"View photobooth images",
		"gallery-plugin-button", "Gallery"
	)

	mountBlackoutMode(plugin)

	local dock = plugin:CreateDockWidgetPluginGuiAsync("PhotoboothGallery", WIDGET_INFO)
	dock.Name = "PhotoboothGallery"
	dock.Title = "Photobooth"
	dock.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function App(): React.ReactNode
		local isEnabled, setIsEnabled = React.useState(dock.Enabled)

		local isCapturing = StateManager.temporary:useSpecific()(function(state)
			return state.isCapturing
		end)

		local galleryListExpanded = StateManager.settings:useSpecific()(function(state)
			return state.galleryListExpanded
		end)

		local backgroundType, setBackgroundType = React.useState("Checkerboard")

		React.useEffect(function()
			local buttonConnection = openButton.Click:Connect(function()
				setIsEnabled(not dock.Enabled)
			end)

			dock:BindToClose(function()
				setIsEnabled(false)
			end)

			return function()
				dock:BindToClose(nil)
				buttonConnection:Disconnect()
			end
		end, {})

		dock.Enabled = isEnabled
		openButton:SetActive(isEnabled)

		return isEnabled
			and React.createElement(Gallery, {
				IsExpanded = galleryListExpanded,
				SetIsExpanded = function()
					StateManager.settings:update()(function(state)
						state.galleryListExpanded = not state.galleryListExpanded
						return state
					end)
				end,

				BackgroundType = backgroundType,
				SetBackgroundType = setBackgroundType,

				TryUpload = function(_i, name, editImage, creator)
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
				end,
				TestCreator = function(creator)
					return creator.Id > 0
				end,

				Disabled = isCapturing,
			})
	end

	local dockRoot = ReactRoblox.createRoot(dock)
	dockRoot:render(React.createElement(StudioComponents.PluginProvider, {
		Plugin = plugin,
	}, {
		App = React.createElement(App),
	}))

	plugin.Unloading:Connect(function()
		dockRoot:unmount()
	end)
end

return GalleryApp
