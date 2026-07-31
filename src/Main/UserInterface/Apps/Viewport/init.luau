local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local SelectionService = game:GetService("Selection")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local Future = require(pluginRoot.Packages.Future)
local React = require(pluginRoot.Packages.React)
local Trove = require(pluginRoot.Packages.Trove)

local StateManager = require(pluginRoot.Main.StateManager)
local UIHider = require(pluginRoot.Main.Photo.Tools.UIHider)
local Captures = require(pluginRoot.Main.Photo.Captures)
local Photo = require(pluginRoot.Main.Photo)

local bindingRoot = pluginRoot.Main.Bindings.Interface
local RenderRect = require(bindingRoot.Helpers.RenderRect)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Toolbar = require(uiRoot.Helpers.Toolbar)

local CroppedViewport = require(script.Components.CroppedViewport)
local FullViewport = require(script.Components.FullViewport)

local ViewportApp = {}

type RectRequest = {
	guid: string,
	scaleOS: Vector2,
	initialRect: Rect,
	resultFuture: Future.Future<Rect?>,
}

type RectRequestControl = {
	expect: () -> Rect?,
	cancel: () -> (),
}

local rectRequestQueue = ObservableValue.new({} :: { RectRequest })
local rectRequestControlByGuid: { [string]: RectRequestControl } = {}

local function safeComplete<T...>(f: Future.Future<T...>, ...: T...)
	if not f:isCompleted() then
		f:complete(...)
	end
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

local function createCenterRect(scale: Vector2, scaleOS: Vector2?)
	local renderScaleOS = scaleOS or StateManager.temporary:get().scaleOS
	local viewportSize = (workspace.CurrentCamera :: Camera).ViewportSize * renderScaleOS
	local rectSize = viewportSize * scale
	local absPosition = (viewportSize - rectSize) / 2
	return RenderRect.fromAbs(absPosition, rectSize)
end

local function useCaptureRect()
	local captureRectRef = React.useRef(createCenterRect(Vector2.new(0.5, 0.5)))
	local desiredCropRef = React.useRef(nil :: CroppedViewport.DesiredCrop?)
	local updateTicket, setUpdateTicket = React.useState(1)

	local update = React.useCallback(function(newRect: Rect)
		captureRectRef.current = newRect
		desiredCropRef.current = nil
		setUpdateTicket(function(ticket)
			return -ticket
		end)
	end, { updateTicket })

	return captureRectRef, desiredCropRef, update
end

local function appComponent(props: { Button: Toolbar.Button })
	local isEnabled, setIsEnabled = React.useState(false)
	local rectRequest, removeRectRequest = useRectRequest()
	local captureRectRef, desiredCropRef, updateCaptureRectRef = useCaptureRect()

	local isFirstAppOpenRef = React.useRef(true)
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
			if not newIsEnabled then
				ViewportApp.clearAllRectRequests()
			elseif isFirstAppOpenRef.current then
				isFirstAppOpenRef.current = false
				updateCaptureRectRef(createCenterRect(Vector2.new(0.5, 0.5)))
			end
			setIsEnabled(newIsEnabled)
		end))

		return function()
			trove:Destroy()
		end
	end, { isEnabled })

	React.useEffect(function()
		local connection
		if rectRequest then
			updateCaptureRectRef(rectRequest.initialRect)

			StateManager.temporary:update()(function(state)
				state.isFullscreen = false
				return state
			end)

			setIsEnabled(true)
			connection = rectRequestQueue:onChanged(function()
				if #rectRequestQueue:get() == 0 then
					setIsEnabled(false)
				end
			end)
		end

		return function()
			if connection then
				connection:Disconnect()
			end
		end
	end, { rectRequest })

	local onCapture = React.useCallback(function(rect: Rect)
		if rectRequest then
			safeComplete(rectRequest.resultFuture, rect)
			removeRectRequest()
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
				DesiredCropRef = desiredCropRef,
				UpdateCaptureRectRef = updateCaptureRectRef,
				OnMaximize = onMinMax,
				OnCapture = onCapture,
				Visible = not isFullscreen :: boolean,
				Disabled = isCapturing,
			}),
		})
end

function ViewportApp.requestRect(guid: string, rect: Rect?, scaleOS: Vector2?)
	local resultFuture = Future.new()
	local renderScaleOS = scaleOS or Vector2.one

	local entry = {
		guid = guid,
		scaleOS = renderScaleOS,
		initialRect = rect or createCenterRect(Vector2.new(0.5, 0.5), renderScaleOS),
		resultFuture = resultFuture,
	}

	rectRequestQueue:update()(function(queue)
		table.insert(queue, entry)
		return queue
	end)

	local function expect()
		local result = resultFuture:expect()
		rectRequestControlByGuid[entry.guid] = nil
		return result
	end

	local function cancel()
		if not resultFuture:isCompleted() then
			rectRequestQueue:update()(function(queue)
				local foundIndex = table.find(queue, entry)
				if foundIndex then
					table.remove(queue, foundIndex)
					rectRequestControlByGuid[entry.guid] = nil
				end
				return queue
			end)
			resultFuture:complete(nil)
		end
	end

	local requestControl: RectRequestControl = {
		expect = expect,
		cancel = cancel,
	}

	rectRequestControlByGuid[entry.guid] = requestControl

	return requestControl
end

function ViewportApp.getRectRequestByGuid(guid: string)
	return rectRequestControlByGuid[guid] :: RectRequestControl?
end

function ViewportApp.clearAllRectRequests()
	local queue = rectRequestQueue:get()
	rectRequestQueue:set({})
	table.clear(rectRequestControlByGuid)
	for _, rectRequest in pairs(queue) do
		safeComplete(rectRequest.resultFuture, nil)
	end
end

function ViewportApp.mount(plugin: Plugin, toolbar: Toolbar.Toolbar)
	-- stylua: ignore
	local openButton = toolbar:CreateButton(
		"egomoose_photobooth_viewport_button",
		"Capture viewport images",
		"camera-plugin-button", "Viewport"
	)

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
		coreGuiRoot:unmount()
		folder:Destroy()
	end)
end

return ViewportApp
