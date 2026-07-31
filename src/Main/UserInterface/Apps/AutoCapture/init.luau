local CoreGui = game:GetService("CoreGui")
local StarterGui = game:GetService("StarterGui")
local SelectionService = game:GetService("Selection")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local StudioComponents = require(pluginRoot.Packages.StudioComponents)
local ReactRoblox = require(pluginRoot.Packages.ReactRoblox)
local React = require(pluginRoot.Packages.React)

local SceneControl = require(pluginRoot.Main.Photo.SceneControl)
local StateManager = require(pluginRoot.Main.StateManager)

local uiRoot = script:FindFirstAncestor("UserInterface")
local Toolbar = require(uiRoot.Helpers.Toolbar)
local Hooks = require(uiRoot.Hooks)

local FitterWindow = require(script.Components.FitterWindow)
local Widget = require(script.Components.Widget)

local Controller = require(script.Controller)

local AutoCapture = {}

local function hideWorkspace(callback: () -> ())
	local terrain = workspace.Terrain
	local camera = workspace.CurrentCamera

	local foundLuaSourceContainer = workspace:FindFirstChildWhichIsA("LuaSourceContainer", true)
	if foundLuaSourceContainer then
		-- This may seem like a really funny thing to do. Why create a module and immediately destroy it?
		-- This will trigger the script injection permissions check which is needed to re-parent the user's scripts back
		-- into the workspace. If we don't have this then we may error post-callback and the workspace will be unintentionally cleared
		local probe = Instance.new("ModuleScript")
		probe.Parent = workspace
		probe:Destroy()
	end

	local recording = ChangeHistoryService:TryBeginRecording("AutoCapture", "Auto Capture")

	local hidden = {}
	local children = workspace:GetChildren()
	for _, child in children do
		if child ~= camera and child ~= terrain then
			table.insert(hidden, {
				instance = child,
				archivable = child.Archivable,
			})

			child.Archivable = false
			child.Parent = nil
		end
	end

	local ok, err: string? = pcall(function()
		callback()
	end)

	for _, entry in hidden do
		entry.instance.Parent = workspace
		entry.instance.Archivable = entry.archivable
	end

	if recording then
		ChangeHistoryService:FinishRecording(
			recording,
			if ok then Enum.FinishRecordingOperation.Commit else Enum.FinishRecordingOperation.Cancel
		)
	end

	if not ok then
		error(err, 0)
	end
end

local function useController()
	local controller = Hooks.useConstant(function()
		return Controller.new()
	end)

	React.useEffect(function()
		return function()
			controller:Destroy()
		end
	end, {})

	return controller
end

local function appComponent(props: { ScaleOS: Vector2 })
	local plugin = StudioComponents.usePlugin() :: Plugin
	local pvsRef = React.useRef({} :: { [Widget.ListElement]: PVInstance })

	local controller = useController()
	local static = controller.staticObservableState:use()
	local dynamic = controller.dynamicObservableState:use()

	local captureRect, setCaptureRect = React.useState(Rect.new(0, 0, 0, 0))
	local cancelledRef = React.useRef(false)

	React.useEffect(function()
		return function()
			controller:unfocus()

			for element, _ in pvsRef.current do
				controller:unloadPVInstance(pvsRef.current[element])
				pvsRef.current[element]:Destroy()
				pvsRef.current[element] = nil
			end
		end
	end, {})

	return React.createElement(React.Fragment, nil, {
		Widget = React.createElement(Widget, {
			OnCapture = function()
				cancelledRef.current = false

				local success, err: string? = pcall(function()
					hideWorkspace(function()
						local focusedPV = controller:getFocusedPVInstance()
						if focusedPV then
							local result = controller:capture(props.ScaleOS)
							if result then
								local captureName = (focusedPV:GetAttribute("CaptureName") :: string?) or "Capture"
								result.Name = captureName
								result.Parent = StarterGui

								plugin:SelectRibbonTool(Enum.RibbonTool.Select, UDim2.fromOffset(0, 0))
								SelectionService:Set({ result })
							end
						end
					end)
				end)

				if not success then
					warn(err)
					return err
				end

				return nil
			end,
			OnCaptureAll = function()
				cancelledRef.current = false

				local success, err: string? = pcall(function()
					hideWorkspace(function()
						local folder = Instance.new("Folder")
						local prevFocusedPV = controller:getFocusedPVInstance()

						for i, pvInstance in controller:getPVInstances() do
							if cancelledRef.current then
								break
							end

							controller:focusAsync(true, pvInstance)
							SceneControl.yieldUntilNextFrame()

							local result = controller:capture(props.ScaleOS)
							if result then
								local captureName = (pvInstance:GetAttribute("CaptureName") :: string?) or "Capture"
								result.Name = `{i}_{captureName}`
								result.Parent = folder
							end
						end

						if #folder:GetChildren() > 0 then
							folder.Name = "AutoCaptures"
							folder.Parent = StarterGui

							plugin:SelectRibbonTool(Enum.RibbonTool.Select, UDim2.fromOffset(0, 0))
							SelectionService:Set({ folder })
						else
							folder:Destroy()
						end

						if prevFocusedPV then
							controller:focusAsync(false, prevFocusedPV)
						else
							controller:unfocus()
						end
					end)
				end)

				if not success then
					warn(err)
					return err
				end

				return nil
			end,
			OnCancel = function()
				cancelledRef.current = true
			end,

			OnListElementSelected = function(element)
				controller:unfocus()

				local pvInstance = element and pvsRef.current[element]
				if pvInstance then
					controller:focusAsync(false, pvInstance)
				end
			end,
			OnListElementAdded = function(element)
				if not pvsRef.current[element] then
					local archivable = element.instance.Archivable
					element.instance.Archivable = true
					local pvInstanceCopy = element.instance:Clone()
					element.instance.Archivable = archivable
					pvInstanceCopy.Archivable = archivable

					local focusPV = Instance.new("Model")
					focusPV.Archivable = false
					pvInstanceCopy.Parent = focusPV

					local bboxCF, _bboxSize = Controller.getPVBoundingBox(focusPV)
					local worldPivot = CFrame.new(bboxCF.Position)

					local pivotOffset = CFrame.identity
					local autoCapturePivot = pvInstanceCopy:FindFirstChild("PhotoboothAutoCapturePivot")
					if autoCapturePivot and autoCapturePivot:IsA("Attachment") then
						pivotOffset = worldPivot:ToObjectSpace(autoCapturePivot.WorldCFrame):Inverse()
					end

					focusPV.Name = "AutoCaptureModel"
					focusPV.WorldPivot = worldPivot
					focusPV:PivotTo(pivotOffset)

					focusPV:SetAttribute("CaptureName", pvInstanceCopy.Name)

					pvsRef.current[element] = focusPV
					controller:loadPVInstance(pvsRef.current[element])
				end
			end,
			OnListElementRemoved = function(element)
				if pvsRef.current[element] then
					controller:unloadPVInstance(pvsRef.current[element])
					pvsRef.current[element]:Destroy()
					pvsRef.current[element] = nil
				end
			end,

			Controller = controller,
			CaptureRect = captureRect,
		}),

		FitterWindow = ReactRoblox.createPortal(
			React.createElement("ScreenGui", {
				Name = "FitterWindow",
				Archivable = false,
				IgnoreGuiInset = true,
				ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			}, {
				Core = React.createElement(FitterWindow, {
					ScaleOS = props.ScaleOS,

					IsFullScreen = dynamic.isFullScreen,
					Resolution = Vector2.new(math.max(1, dynamic.captureSize.X), math.max(1, dynamic.captureSize.Y)),
					AnimationTrack = static.animationTrack,

					PaddingVisible = dynamic.fitType ~= "Free" and dynamic.paddingVisible,
					PaddingTop = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingTop,
					PaddingBottom = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingBottom,
					PaddingLeft = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingLeft,
					PaddingRight = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingRight,

					OnCaptureRectChanged = function(newRect)
						controller:setCaptureRect(newRect)
						setCaptureRect(newRect)
					end,
				}),
			}),
			CoreGui
		),
	})
end

function AutoCapture.mount(plugin: Plugin, toolbar: Toolbar.Toolbar)
	-- stylua: ignore
	local button = toolbar:CreateButton(
		"egomoose_photobooth_addon_auto_capture",
		"Photobooth Auto Capture", "switch-camera-button", "Auto"
	)

	local info = DockWidgetPluginGuiInfo.new(Enum.InitialDockState.Float, false, true, 300, 600, 300, 600)
	local dock = plugin:CreateDockWidgetPluginGuiAsync("egomoose_photobooth_addon_auto_capture", info)
	dock.Name = "Photobooth Auto Capture"
	dock.Title = "Photobooth - Auto Capture"
	dock.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

	local function App()
		local isEnabled = Hooks.useDockButton(dock, button)
		local scaleOS = StateManager.temporary:useSpecific()(function(state)
			return state.scaleOS
		end)

		return isEnabled and React.createElement(appComponent, {
			ScaleOS = scaleOS,
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
		dock:Destroy()
		button:Destroy()
	end)
end

return AutoCapture
