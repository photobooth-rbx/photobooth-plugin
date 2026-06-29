local AssetService = game:GetService("AssetService")
local HttpService = game:GetService("HttpService")
local ScriptEditorService = game:GetService("ScriptEditorService")
local SelectionService = game:GetService("Selection")
local StarterGui = game:GetService("StarterGui")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local Blackout = require(pluginRoot.Main.Photo.Tools.Blackout)
local StateManager = require(pluginRoot.Main.StateManager)
local Constants = require(pluginRoot.Constants)
local Photo = require(pluginRoot.Main.Photo)
local Wally = require(pluginRoot.Wally)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ToolbarButton = require(uiRoot.Helpers.ToolbarButton)

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

function GalleryApp.mount(plugin: Plugin, toolbar: PluginToolbar)
	-- stylua: ignore
	local openButton = toolbar:CreateButton(
		"egomoose_photobooth_gallery_button",
		"View photobooth images",
		"", "Gallery"
	)

	ToolbarButton.listen(openButton, "gallery-plugin-button")

	mountBlackoutMode(plugin)

	local dock = plugin:CreateDockWidgetPluginGuiAsync("PhotoboothGallery", WIDGET_INFO)
	dock.Name = "PhotoboothGallery"
	dock.Title = "Photobooth"
	dock.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function GalleryApp(): React.ReactNode
		local isEnabled, setIsEnabled = React.useState(dock.Enabled)

		local isCapturing = StateManager.temporary:useSpecific()(function(state)
			return state.isCapturing
		end)

		local galleryListExpanded = StateManager.saved:useSpecific()(function(state)
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
					StateManager.saved:update()(function(state)
						state.galleryListExpanded = not state.galleryListExpanded
						return state
					end)
				end,

				BackgroundType = backgroundType,
				SetBackgroundType = setBackgroundType,

				TryUpload = function(_i, name, editImage)
					local result: Enum.CreateAssetResult
					local value: number | string

					result, value = AssetService:CreateAssetAsync(editImage, Enum.AssetType.Image, {
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
				OnUploadComplete = function(completed)
					local module = Instance.new("ModuleScript")
					module.Name = `{DateTime.now():ToIsoDate()} - Photobooth Upload`

					ScriptEditorService:UpdateSourceAsync(module, function()
						local output = "return {\n"
						for _, entry in completed do
							output = output .. `\t["{entry.Name}"] = "rbxassetid://{entry.AssetId}",\n`
						end
						return output .. "}"
					end)
					module.Parent = StarterGui

					ScriptEditorService:OpenScriptDocumentAsync(module)
					SelectionService:Set({ module })
				end,

				OnImport = function()
					local result = Photo.importFiles(StarterGui)
					SelectionService:Set(result :: { any })
				end,

				Disabled = isCapturing,
			})
	end

	local dockRoot = ReactRoblox.createRoot(dock)
	dockRoot:render(React.createElement(StudioComponents.PluginProvider, {
		Plugin = plugin,
	}, {
		App = React.createElement(GalleryApp),
	}))

	plugin.Unloading:Connect(function()
		dockRoot:unmount()
	end)
end

return GalleryApp
