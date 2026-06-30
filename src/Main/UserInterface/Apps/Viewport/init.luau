local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local SelectionService = game:GetService("Selection")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local Future = require(pluginRoot.Packages.Future)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local ObservableValue = require(pluginRoot.Main.StateManager.ObservableValue)
local StateManager = require(pluginRoot.Main.StateManager)
local UIHider = require(pluginRoot.Main.Photo.Tools.UIHider)
local Captures = require(pluginRoot.Main.Photo.Captures)
local Photo = require(pluginRoot.Main.Photo)

local bindingRoot = pluginRoot.Main.Bindings.Interface
local RenderRect = require(bindingRoot.Helpers.RenderRect)

local uiRoot = script:FindFirstAncestor("UserInterface")
local ToolbarButton = require(uiRoot.Helpers.ToolbarButton)
local Hooks = require(uiRoot.Hooks)

local CroppedViewport = require(script.Components.CroppedViewport)
local FullViewport = require(script.Components.FullViewport)

local ViewportApp = {}

type RectRequest = {
	scaleOS: Vector2,
	initialRect: Rect?,
	resultFuture: Future.Future<Rect?>,
}

local rectRequestQueue = ObservableValue.new({} :: { RectRequest })

local function clearAllRectRequests()
	local queue = rectRequestQueue:get()
	rectRequestQueue:set({})
	for _, rectRequest in pairs(queue) do
		rectRequest.resultFuture:complete(nil)
	end
	table.clear(queue)
end

local function useRectRequest()
	local rectQueue = rectRequestQueue:use()
	local rectRequest = rectQueue[1]

	local remove = React.useCallback(function()
		rectRequestQueue:update()(function(queue)
			table.remove(queue, 1)
			return queue
		end)
	end, { rectRequest })

	return rectRequest, remove
end

local function createCenterRect(scale: Vector2)
	local scaleOS = StateManager.temporary:get().scaleOS
	local currentCamera = workspace.CurrentCamera :: Camera
	return RenderRect.fromViewportCenter((currentCamera.ViewportSize * scale) / scaleOS)
end

local function useCaptureRect()
	-- we use a ref b/c in most cases we don't need to re-render the whole tree when we update this value
	-- we have a custom update value which can be used to trigger re-renders, but it's used only when
	-- there's a hard override we want to set (which doesn't occur often)
	local captureRectRef = React.useRef(createCenterRect(Vector2.new(0.5, 0.5)))
	local forceUpdate = Hooks.useUpdate()

	local update = React.useCallback(function(newRect: Rect)
		captureRectRef.current = newRect
		forceUpdate()
	end, { forceUpdate })

	return captureRectRef, update
end

local function appComponent(props: { Button: PluginToolbarButton })
	local isEnabled, setIsEnabled = React.useState(false)
	local rectRequest, removeRectRequest = useRectRequest()
	local captureRectRef, updateCaptureRectRef = useCaptureRect()
	local screenGuiRef = React.useRef(nil :: ScreenGui?)

	local isCapturing = StateManager.temporary:useSpecific()(function(state)
		return state.isCapturing
	end)

	local isFullscreen = StateManager.temporary:useSpecific()(function(state)
		return state.isFullscreen
	end)

	local scaleOS = StateManager.temporary:useSpecific()(function(state)
		return state.scaleOS
	end)

	React.useEffect(function()
		local trove = Trove.new()
		trove:Add(props.Button.Click:Connect(function()
			local newIsEnabled = not isEnabled
			if newIsEnabled then
				updateCaptureRectRef(createCenterRect(Vector2.new(0.5, 0.5)))
			else
				clearAllRectRequests()
			end
			setIsEnabled(newIsEnabled)
		end))

		return function()
			trove:Destroy()
		end
	end, { isEnabled })

	React.useEffect(function()
		if rectRequest then
			if rectRequest.initialRect then
				updateCaptureRectRef(rectRequest.initialRect)
			end

			StateManager.temporary:update()(function(state)
				state.isFullscreen = false
				return state
			end)

			setIsEnabled(true)
		end
	end, { rectRequest })

	local onCapture = React.useCallback(function(rect: Rect)
		if rectRequest then
			rectRequest.resultFuture:complete(rect)
			removeRectRequest()
			setIsEnabled(false)
			return true, "" :: string?
		end

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
	end, { rectRequest })

	local onMinMax = React.useCallback(function()
		StateManager.temporary:update()(function(state)
			state.isFullscreen = not state.isFullscreen
			return state
		end)
	end, {})

	props.Button:SetActive(isEnabled)

	return isEnabled
		and React.createElement("ScreenGui", {
			Name = "ViewportApp",
			DisplayOrder = math.huge, -- this is so enabled ScreenGuis in say StarterGui don't stop Photobooth from receiving input
			Archivable = false,
			IgnoreGuiInset = true,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			ref = screenGuiRef,
		}, {
			Fullscreen = React.createElement(FullViewport, {
				IsRectRequest = not not rectRequest,
				ScaleOS = scaleOS,
				OnMinimize = onMinMax,
				OnCapture = onCapture,
				Visible = isFullscreen :: boolean,
				Disabled = isCapturing,
			}),

			Cropped = React.createElement(CroppedViewport, {
				IsRectRequest = not not rectRequest,
				ScaleOS = if rectRequest then rectRequest.scaleOS else scaleOS,
				CaptureRectRef = captureRectRef,
				UpdateCaptureRectRef = updateCaptureRectRef,
				OnMaximize = onMinMax,
				OnCapture = onCapture,
				Visible = not isFullscreen :: boolean,
				Disabled = isCapturing,
			}),
		})
end

function ViewportApp.requestRect(rect: Rect?, scaleOS: Vector2?)
	local resultFuture = Future.new()
	rectRequestQueue:update()(function(queue)
		table.insert(queue, {
			scaleOS = scaleOS or Vector2.one,
			initialRect = rect,
			resultFuture = resultFuture,
		})
		return queue
	end)

	local resultRect = resultFuture:expect()
	return resultRect
end

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

	local coreGuiRoot = ReactRoblox.createRoot(folder)
	coreGuiRoot:render(React.createElement(StudioComponents.PluginProvider, {
		Plugin = plugin,
	}, {
		App = React.createElement(appComponent, {
			Button = openButton,
		}),
	}))

	plugin.Unloading:Connect(function()
		clearAllRectRequests()
		coreGuiRoot:unmount()
		folder:Destroy()
	end)

	task.delay(5, function()
		local scaleOS = Vector2.new(1, 1)
		local size = Vector2.new(512, 512)

		local viewportSize = (workspace.CurrentCamera :: Camera).ViewportSize * scaleOS
		local absPosition = (viewportSize - size) / 2
		local rect = RenderRect.fromAbs(absPosition, size)

		local result = ViewportApp.requestRect(rect, scaleOS)
		print(result)
	end)
end

return ViewportApp
