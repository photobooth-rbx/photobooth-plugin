local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local SelectionService = game:GetService("Selection")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local StateManager = require(pluginRoot.Main.StateManager)
local UIHider = require(pluginRoot.Main.Photo.Tools.UIHider)
local Captures = require(pluginRoot.Main.Photo.Captures)
local Photo = require(pluginRoot.Main.Photo)

local bindingRoot = pluginRoot.Main.Bindings.Interface
local RenderRect = require(bindingRoot.Helpers.RenderRect)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ToolbarButton = require(uiRoot.Helpers.ToolbarButton)

local CroppedViewport = require(script.Components.CroppedViewport)
local FullViewport = require(script.Components.FullViewport)

local ViewportApp = {}

function ViewportApp.mount(plugin: Plugin, toolbar: PluginToolbar)
	-- stylua: ignore
	local openButton = toolbar:CreateButton(
		"egomoose_photobooth_viewport_button",
		"Capture viewport images",
		"", "Viewport"
	)

	ToolbarButton.listen(openButton, "camera-plugin-button")

	local folder = Instance.new("Folder")
	folder.Name = "EgoMoosePhotobooth"
	folder.Archivable = false
	folder.Parent = CoreGui

	local function ViewportApp(): React.ReactNode?
		local isEnabled, setIsEnabled = React.useState(false)

		local isCapturing = StateManager.temporary:useSpecific()(function(state)
			return state.isCapturing
		end)

		local isFullscreen = StateManager.temporary:useSpecific()(function(state)
			return state.isFullscreen
		end)

		local captureRectRef = React.useRef(RenderRect.fromViewportCenter(workspace.CurrentCamera.ViewportSize / 2))
		local prevCaptureRectRef = React.useRef(captureRectRef.current)

		local screenGuiRef = React.useRef(nil :: ScreenGui?)

		local updatePrevCaptureRectRef = React.useCallback(function()
			local captureRect = captureRectRef.current
			if not StateManager.temporary:get().isFullscreen and captureRect then
				prevCaptureRectRef.current = captureRect
			end
		end, {})

		React.useEffect(function()
			local trove = Trove.new()
			trove:Add(openButton.Click:Connect(function()
				updatePrevCaptureRectRef()
				setIsEnabled(not isEnabled)
			end))

			return function()
				trove:Destroy()
			end
		end, { isEnabled })

		local onCapture = React.useCallback(function(rect: Rect)
			local captureTypeIndex = StateManager.temporary:get().viewportCaptureTypeIndex
			local captureType = assert(Captures.Viewport.Order[captureTypeIndex], "No capture type found")

			local trove = Trove.new()
			if screenGuiRef.current and UIHider.isViewportAppExcluded(rect) then
				trove:Add(UIHider.addExclusion(screenGuiRef.current))
			end

			local captures, err = Photo.captureViewport({
				rect = rect,
				type = captureType :: Captures.ViewportCaptureTypes,
			})

			trove:Destroy()

			local selection = Photo.export(captures, StarterGui)
			SelectionService:Set(selection :: any)
			return not err, err
		end, {})

		local onMinMax = React.useCallback(function()
			local prevRect = prevCaptureRectRef.current
			updatePrevCaptureRectRef()
			captureRectRef.current = prevRect
			StateManager.temporary:update()(function(state)
				state.isFullscreen = not state.isFullscreen
				return state
			end)
		end, {})

		openButton:SetActive(isEnabled)

		-- stylua: ignore
		return isEnabled and React.createElement("ScreenGui", {
			Name = "ViewportApp",
			DisplayOrder = math.huge, -- this is so enabled ScreenGuis in say StarterGui don't stop Photobooth from receiving input
			Archivable = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			ref = screenGuiRef,
		}, {
			Fullscreen = React.createElement(FullViewport, {
				OnMinimize = onMinMax,
				OnCapture = onCapture,
				Visible = isFullscreen :: boolean,
				Disabled = isCapturing,
			}),

			Cropped = React.createElement(CroppedViewport, {
				OnMaximize = onMinMax,
				OnCapture = onCapture,
				Visible = not isFullscreen :: boolean,
				Disabled = isCapturing,
			}),
		})
	end

	local coreGuiRoot = ReactRoblox.createRoot(folder)
	coreGuiRoot:render(React.createElement(StudioComponents.PluginProvider, {
		Plugin = plugin,
	}, {
		App = React.createElement(ViewportApp),
	}))

	plugin.Unloading:Connect(function()
		coreGuiRoot:unmount()
		folder:Destroy()
	end)
end

return ViewportApp
