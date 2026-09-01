local UserInputService = game:GetService("UserInputService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local PriorityStepper = require(pluginRoot.Utilities.PriorityStepper)
local ObservableValue = require(pluginRoot.Utilities.ObservableValue)
local Signal = require(pluginRoot.Packages.Signal)
local Trove = require(pluginRoot.Packages.Trove)

local Photo = require(pluginRoot.Main.Photo)
local Captures = require(pluginRoot.Main.Photo.Captures)
local RenderRect = require(pluginRoot.Main.Bindings.Interface.Helpers.RenderRect)

local appRoot = script:FindFirstAncestor("AutoCapture")
local RenderPriorities = require(appRoot.RenderPriorities)

local AnimationManager = require(script.AnimationManager)
local AABBHelper = require(script.AABBHelper)
local PointCloud = require(script.PointCloud)

local CAMERA_TYPE = Enum.CameraType.Scriptable

local YAW_INIT = math.pi
local PITCH_INIT = 0
local PITCH_LIMIT = math.rad(89)

local ORBIT_SENSITIVITY = 0.005

local DISTANCE_SCALE_STEP = 1.05
local DISTANCE_SCALE_MIN = 0.01
local DISTANCE_SCALE_MAX = 100

local FREE_LOOK_SENSITIVITY = 0.005
local FREE_MOVE_SPEED_MAX = 1000

local FREE_MOVE_KEYS = {
	[Enum.KeyCode.D] = Vector3.xAxis,
	[Enum.KeyCode.A] = -Vector3.xAxis,
	[Enum.KeyCode.E] = Vector3.yAxis,
	[Enum.KeyCode.Q] = -Vector3.yAxis,
	[Enum.KeyCode.S] = Vector3.zAxis,
	[Enum.KeyCode.W] = -Vector3.zAxis,
}

local AutoCaptureControllerStatic = {}
local globalTicket = 0

local AutoCaptureControllerClass = {}
AutoCaptureControllerClass.__index = AutoCaptureControllerClass
AutoCaptureControllerClass.ClassName = "AutoCaptureController"

local function createStaticObservableState()
	return ObservableValue.new({
		isSynced = true,
		animationTrack = nil :: AnimationTrack?,
	})
end

local function createDynamicObservableState()
	return ObservableValue.new({
		alphaBleed = true,
		captureType = Captures.Viewport.Order[1],

		isFullScreen = false,
		captureDelay = 0,
		captureSize = Vector2.new(256, 256),

		fov = workspace.CurrentCamera.FieldOfView,
		fitType = "Orbital",
		tryUseMeshVertices = false,
		distanceScale = 1,

		paddingVisible = true,
		paddingUniform = true,
		padding = 0,
		paddingTop = 0,
		paddingRight = 0,
		paddingBottom = 0,
		paddingLeft = 0,
	})
end

local function createNewFocus()
	local dynamicObservable = createDynamicObservableState()
	local dynamicState = dynamicObservable:get()
	dynamicObservable:Destroy()

	return {
		yaw = YAW_INIT,
		pitch = PITCH_INIT,
		renderCF = CFrame.fromEulerAnglesYXZ(PITCH_INIT, YAW_INIT, 0),
		dynamicState = dynamicState,
	}
end

export type StaticState = typeof(createStaticObservableState():get())
export type StaticObservableState = ObservableValue.ObservableValue<StaticState>

export type DynamicState = typeof(createDynamicObservableState():get())
export type DynamicObservableState = ObservableValue.ObservableValue<DynamicState>

type Focus = {
	yaw: number,
	pitch: number,
	renderCF: CFrame,
	dynamicState: DynamicState,
}

type PVState = {
	ticket: number,
	pvInstance: PVInstance,
	focus: Focus,
	animationManager: AnimationManager.AnimationManager,
}

export type AutoCaptureController = typeof(setmetatable(
	{} :: {
		captureRect: Rect,
		isCapturing: boolean,

		staticObservableState: StaticObservableState,
		dynamicObservableState: DynamicObservableState,

		focusedPV: PVInstance?,
		focusedPVChanged: Signal.Signal<()>,

		focusShared: Focus,
		focusTrove: Trove.Trove,
		stateByPV: { [PVInstance]: PVState },

		isInputFrozen: boolean,
		meshDataCache: PointCloud.MeshDataCache,
	},
	AutoCaptureControllerClass
))

function AutoCaptureControllerStatic.new()
	local self = setmetatable({}, AutoCaptureControllerClass) :: AutoCaptureController

	self.captureRect = Rect.new(0, 0, 0, 0)
	self.isCapturing = false

	self.staticObservableState = createStaticObservableState()
	self.dynamicObservableState = createDynamicObservableState()

	self.focusedPV = nil
	self.focusedPVChanged = Signal.new()

	self.stateByPV = {}
	self.focusTrove = Trove.new()
	self.focusShared = createNewFocus()

	self.isInputFrozen = true
	self.meshDataCache = {}

	return self
end

-- Private

type Distortion = {
	anchor: Vector2,
	position: Vector2,
	size: Vector2,
}

local function distort(camera: Camera, distortion: Distortion)
	local viewportSize = camera.ViewportSize
	local aspectRatio = viewportSize.X / viewportSize.Y

	local hFactor = math.tan(math.rad(camera.FieldOfView) / 2)
	local wFactor = hFactor * aspectRatio

	local center = distortion.position - distortion.size * distortion.anchor + distortion.size / 2

	local w, h = distortion.size.X, distortion.size.Y
	local dx = 2 * wFactor * (0.5 - center.X)
	local dy = -2 * hFactor * (0.5 - center.Y)
	local dz = 1

	local m = math.max(math.abs(w), math.abs(h), math.abs(dx), math.abs(dy), math.abs(dz))

	return CFrame.new(0, 0, 0, w / m, 0, 0, 0, h / m, 0, dx / m, dy / m, dz / m)
end

local function viewProjectionEdgeHits(cloud: { Vector3 }, axis: "X" | "Y", depth: number, tanFov2: number)
	local max, min = -math.huge, math.huge

	for _, lp in cloud do
		local distance = depth - lp.Z
		local halfSpan = tanFov2 * distance

		local component = (lp :: any)[axis] :: number
		local a = component + halfSpan
		local b = component - halfSpan

		max = math.max(max, a, b)
		min = math.min(min, a, b)
	end

	return max, min
end

local function getStudioSetting<T>(keys: { string }, default: T): T
	for _, key in keys do
		local success, value = pcall(function()
			return (settings().Studio :: any)[key] :: T
		end)
		if success then
			return value
		end
	end
	return default
end

-- Methods

function AutoCaptureControllerClass._getActiveFocus(self: AutoCaptureController)
	local pvInstance = self.focusedPV
	local pvState = pvInstance and self.stateByPV[pvInstance]
	if pvState and not self.staticObservableState:get().isSynced then
		return pvState.focus
	end
	return self.focusShared
end

function AutoCaptureControllerClass._getPaddedRect(self: AutoCaptureController)
	local dynamic = self.dynamicObservableState:get()

	local top = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingTop
	local bottom = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingBottom
	local left = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingLeft
	local right = if dynamic.paddingUniform then dynamic.padding else dynamic.paddingRight

	local min = self.captureRect.Min + Vector2.new(left, top)
	local max = self.captureRect.Max - Vector2.new(right, bottom)

	return Rect.new(min, max)
end

function AutoCaptureControllerClass._listenOrbitInput(self: AutoCaptureController)
	local rotating = false
	local cleanupTrove = Trove.new()

	cleanupTrove:Add(UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end))

	cleanupTrove:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end))

	cleanupTrove:Add(UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if self.isInputFrozen then
			return
		end

		local focus = self:_getActiveFocus()
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			if rotating then
				focus.yaw = focus.yaw - input.Delta.X * ORBIT_SENSITIVITY
				focus.pitch = math.clamp(focus.pitch - input.Delta.Y * ORBIT_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
			end
		elseif input.UserInputType == Enum.UserInputType.MouseWheel then
			local factor = DISTANCE_SCALE_STEP ^ -input.Position.Z
			self.dynamicObservableState:update()(function(state)
				local scaled = math.round(state.distanceScale * factor * 1000) / 1000
				state.distanceScale = math.clamp(scaled, DISTANCE_SCALE_MIN, DISTANCE_SCALE_MAX)
				return state
			end)
		end
	end))

	local cameraTrove = Trove.new()

	local function cameraAdded(camera: Camera)
		cameraTrove:Clean()
		cameraTrove:Add(camera:GetPropertyChangedSignal("CFrame"):Connect(function()
			local focus = self:_getActiveFocus()
			local rx, ry, _rz = camera.CFrame:ToEulerAnglesYXZ()
			focus.pitch = rx
			focus.yaw = ry
		end))
	end

	cameraAdded(workspace.CurrentCamera)
	local currentCameraChanged = workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		cameraAdded(workspace.CurrentCamera)
	end)

	return function()
		currentCameraChanged:Disconnect()
		cameraTrove:Destroy()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._createPointCloud(self: AutoCaptureController, pvInstance: PVInstance)
	local tryUseMeshVertices = self.dynamicObservableState:get().tryUseMeshVertices
	local pointCloud = PointCloud.new(pvInstance, tryUseMeshVertices, self.meshDataCache)

	pointCloud.trove:Add(self.dynamicObservableState:onChanged(function()
		local newTryUseMeshVertices = self.dynamicObservableState:get().tryUseMeshVertices
		if pointCloud.tryUseMeshVertices ~= newTryUseMeshVertices then
			pointCloud.tryUseMeshVertices = newTryUseMeshVertices
			pointCloud:recalculateVertices()
		end
	end))

	return pointCloud
end

function AutoCaptureControllerClass._hookOrbital(self: AutoCaptureController)
	local pvInstance = assert(self.focusedPV)
	local pvState = assert(self.stateByPV[pvInstance])

	local cleanupTrove = Trove.new()

	local function render()
		if self.isCapturing then
			return
		end

		local focus = self:_getActiveFocus()
		local dynamic = self.dynamicObservableState:get()

		local camera = workspace.CurrentCamera
		camera.FieldOfView = dynamic.fov

		local viewportSize = camera.ViewportSize
		local rotation = CFrame.fromEulerAnglesYXZ(focus.pitch, focus.yaw, 0)

		local paddedRect = self:_getPaddedRect()
		local rectCenter = paddedRect.Min + (paddedRect.Max - paddedRect.Min) / 2

		local aspect = paddedRect.Width / paddedRect.Height
		local scaleY = paddedRect.Height / viewportSize.Y
		local scaledFov2 = math.atan(math.tan(math.rad(camera.FieldOfView / 2)) * scaleY)
		local sinFov2 = math.sin(scaledFov2 * math.min(1, aspect))

		local filteredParts = AABBHelper.getFilteredParts(pvInstance, AABBHelper.ignoreTagFilter)
		local _bboxCF, bboxSize = AABBHelper.getBoundingBox(pvInstance:GetPivot(), filteredParts)
		local radius = bboxSize.Magnitude / 2

		local distance = (radius / sinFov2) * dynamic.distanceScale
		local cameraCF = rotation * CFrame.new(0, 0, distance)

		local distortedCF = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = CAMERA_TYPE
		camera.CFrame = distortedCF
		camera.Focus = distortedCF

		focus.renderCF = distortedCF
		pvState.focus = table.clone(focus)
	end

	cleanupTrove:Add(self:_listenOrbitInput())
	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, render))
	render()

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._hookPointCloud(self: AutoCaptureController)
	local pvInstance = assert(self.focusedPV)
	local pvState = assert(self.stateByPV[pvInstance])

	local cleanupTrove = Trove.new()
	local pointCloud = self:_createPointCloud(pvInstance)

	cleanupTrove:Add(function()
		pointCloud:Destroy()
	end)

	cleanupTrove:Add(pvState.animationManager:onTransform(function()
		pointCloud:recalculateVertices()
	end))

	local function render()
		if self.isCapturing then
			return
		end

		local focus = self:_getActiveFocus()
		local dynamic = self.dynamicObservableState:get()

		local camera = workspace.CurrentCamera
		camera.FieldOfView = dynamic.fov

		local viewportSize = camera.ViewportSize
		local rotation = CFrame.fromEulerAnglesYXZ(focus.pitch, focus.yaw, 0)
		local rotationInv = rotation:Inverse()

		local paddedRect = self:_getPaddedRect()
		local rectCenter = paddedRect.Min + (paddedRect.Max - paddedRect.Min) / 2

		local tanYFov2 = math.tan(math.rad(camera.FieldOfView / 2))
		local tanYFov2Scaled = tanYFov2 * (paddedRect.Height / viewportSize.Y)
		local tanXFov2Scaled = tanYFov2 * (viewportSize.X / viewportSize.Y) * (paddedRect.Width / viewportSize.X)

		local worldPointCloud = pointCloud:getVertices()
		if #worldPointCloud == 0 then
			return
		end

		local cloud = { rotationInv * worldPointCloud[1] }
		local furthest = cloud[1].Z
		for i = 2, #worldPointCloud do
			local lp = rotationInv * worldPointCloud[i]
			furthest = math.min(furthest, lp.Z)
			cloud[i] = lp
		end

		local hMax, hMin = viewProjectionEdgeHits(cloud, "X", furthest, tanXFov2Scaled)
		local vMax, vMin = viewProjectionEdgeHits(cloud, "Y", furthest, tanYFov2Scaled)
		local distance = math.max(((hMax - hMin) / 2) / tanXFov2Scaled, ((vMax - vMin) / 2) / tanYFov2Scaled)
			* dynamic.distanceScale

		local cameraCF = rotation * CFrame.new((hMax + hMin) / 2, (vMax + vMin) / 2, furthest + distance)

		local distortedCF = cameraCF
			* distort(camera, {
				anchor = Vector2.new(0.5, 0.5),
				position = rectCenter / viewportSize,
				size = Vector2.new(1, 1),
			})

		camera.CameraType = CAMERA_TYPE
		camera.CFrame = distortedCF
		camera.Focus = distortedCF

		focus.renderCF = distortedCF
		pvState.focus = table.clone(focus)
	end

	cleanupTrove:Add(self:_listenOrbitInput())
	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, render))
	render()

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._hookFree(self: AutoCaptureController)
	local pvInstance = assert(self.focusedPV)
	local pvState = assert(self.stateByPV[pvInstance])

	local cleanupTrove = Trove.new()

	local startCF: CFrame
	if self.staticObservableState:get().isSynced then
		startCF = self.focusShared.renderCF
	else
		startCF = pvState.focus.renderCF
	end

	local position = startCF.Position
	local pitch, yaw = startCF:ToEulerAnglesYXZ()
	local rotating = false
	local moveSpeed = 0

	local function isShiftDown()
		return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	end

	cleanupTrove:Add(UserInputService.InputBegan:Connect(function(input, _gameProcessed)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = true
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCurrentPosition
		end
	end))

	cleanupTrove:Add(UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton2 then
			rotating = false
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
	end))

	cleanupTrove:Add(UserInputService.InputChanged:Connect(function(input, _gameProcessed)
		if self.isInputFrozen then
			return
		end

		if rotating and input.UserInputType == Enum.UserInputType.MouseMovement then
			yaw -= input.Delta.X * FREE_LOOK_SENSITIVITY
			pitch = math.clamp(pitch - input.Delta.Y * FREE_LOOK_SENSITIVITY, -PITCH_LIMIT, PITCH_LIMIT)
		end
	end))

	local function render(dt: number)
		if self.isCapturing then
			return
		end

		local focus = self:_getActiveFocus()
		local dynamic = self.dynamicObservableState:get()

		local camera = workspace.CurrentCamera
		camera.CameraType = CAMERA_TYPE
		camera.FieldOfView = dynamic.fov

		local rotation = CFrame.fromEulerAnglesYXZ(pitch, yaw, 0)

		if not self.isInputFrozen then
			local studioCameraSpeed = 15 --getStudioSetting({ "Camera Speed" }, 1.5) * 10
			local studioShiftSpeed = 2 --getStudioSetting({ "Camera Shift Speed", "Shift Speed" }, 0.2) * 10

			if isShiftDown() then
				moveSpeed = studioShiftSpeed
			else
				local newMoveSpeed = math.max(moveSpeed, studioCameraSpeed) + dt * (studioCameraSpeed / 2)
				moveSpeed = math.clamp(newMoveSpeed, studioShiftSpeed, FREE_MOVE_SPEED_MAX)
			end

			local move = Vector3.zero
			for keyCode, vec in FREE_MOVE_KEYS do
				if UserInputService:IsKeyDown(keyCode) then
					move = move + rotation:VectorToWorldSpace(vec)
				end
			end

			local moveMagnitude = move.Magnitude
			if moveMagnitude > 0 then
				local moveUnit = move / moveMagnitude
				position = position + moveUnit * moveSpeed * dt
			else
				moveSpeed = 0
			end
		end

		local cameraCF = CFrame.new(position) * rotation
		camera.CFrame = cameraCF
		camera.Focus = cameraCF

		focus.pitch = pitch
		focus.yaw = yaw
		focus.renderCF = cameraCF
		pvState.focus = table.clone(focus)
	end

	cleanupTrove:Add(PriorityStepper.render:connect(RenderPriorities.CAMERA, render))
	render(0)

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass._watchFitType(self: AutoCaptureController)
	local fitTypeTrove = Trove.new()

	local function setFitType(fitType: string)
		fitTypeTrove:Clean()
		if fitType == "Orbital" then
			fitTypeTrove:Add(self:_hookOrbital())
		elseif fitType == "Point Cloud" then
			fitTypeTrove:Add(self:_hookPointCloud())
		else
			fitTypeTrove:Add(self:_hookFree())
		end
	end

	local fitType = self.dynamicObservableState:get().fitType
	setFitType(fitType)

	self.focusTrove:Add(self.dynamicObservableState:onChanged(function()
		local newFitType = self.dynamicObservableState:get().fitType
		if fitType ~= newFitType then
			fitType = newFitType
			setFitType(fitType)
		end
	end))

	return function()
		fitTypeTrove:Destroy()
	end
end

function AutoCaptureControllerClass._watchIsSynced(self: AutoCaptureController)
	local pvInstance = assert(self.focusedPV)
	local pvState = assert(self.stateByPV[pvInstance])

	local isSynced = self.staticObservableState:get().isSynced
	if isSynced then
		self.dynamicObservableState:set(table.clone(self.focusShared.dynamicState))
	else
		self.dynamicObservableState:set(table.clone(pvState.focus.dynamicState))
	end

	local cleanupTrove = Trove.new()
	cleanupTrove:Add(self.staticObservableState:onChanged(function()
		local newIsSynced = self.staticObservableState:get().isSynced
		if isSynced ~= newIsSynced then
			isSynced = newIsSynced

			local dynamicStateNow = self.dynamicObservableState:get()
			if isSynced then
				self.focusShared = table.clone(pvState.focus)
				self.focusShared.dynamicState = table.clone(dynamicStateNow)
			else
				for _, otherPVState in self.stateByPV do
					otherPVState.focus = table.clone(self.focusShared)
					otherPVState.focus.dynamicState = table.clone(dynamicStateNow)
				end
			end
		end
	end))

	cleanupTrove:Add(function()
		local dynamicStateNow = self.dynamicObservableState:get()
		if isSynced then
			self.focusShared.dynamicState = table.clone(dynamicStateNow)
			for _, otherPVState in self.stateByPV do
				otherPVState.focus.dynamicState = table.clone(dynamicStateNow)
			end
		else
			pvState.focus.dynamicState = table.clone(dynamicStateNow)
		end
	end)

	return function()
		cleanupTrove:Destroy()
	end
end

function AutoCaptureControllerClass.setCaptureRect(self: AutoCaptureController, rect: Rect)
	self.captureRect = rect
end

function AutoCaptureControllerClass.getFocusedPVInstance(self: AutoCaptureController)
	return self.focusedPV
end

function AutoCaptureControllerClass.loadPVInstance(self: AutoCaptureController, pvInstance: PVInstance)
	local animationManager = AnimationManager.new(pvInstance)
	globalTicket = globalTicket + 1

	local focus
	local currentPVState = self.focusedPV and self.stateByPV[self.focusedPV]
	if currentPVState then
		focus = table.clone(currentPVState.focus)
		focus.dynamicState = table.clone(currentPVState.focus.dynamicState)
	else
		focus = createNewFocus()
	end

	self.stateByPV[pvInstance] = {
		focus = focus,
		pvInstance = pvInstance,
		ticket = globalTicket,
		animationManager = animationManager,
	}
end

function AutoCaptureControllerClass.unloadPVInstance(self: AutoCaptureController, pvInstance: PVInstance)
	local modelState = assert(self.stateByPV[pvInstance], "No state exists for the provided PVInstance.")
	if self.focusedPV == pvInstance then
		self:unfocus()
	end

	modelState.animationManager:Destroy()
	self.stateByPV[pvInstance] = nil

	if not next(self.stateByPV) then
		self.dynamicObservableState:set(table.clone(self.focusShared.dynamicState))
		self.staticObservableState:update()(function(state)
			state.isSynced = true
			return state
		end)
	end
end

function AutoCaptureControllerClass.focusAsync(
	self: AutoCaptureController,
	inputFrozen: boolean,
	pvInstance: PVInstance
)
	if not self.focusedPV then
		self.focusShared.dynamicState = table.clone(self.dynamicObservableState:get())
	end

	self:unfocus()

	local pvState = assert(self.stateByPV[pvInstance], "No state exists for the provided model.")

	self.focusedPV = pvInstance
	self.isInputFrozen = inputFrozen

	local camera = workspace.CurrentCamera
	local prevCameraType = camera.CameraType
	local prevCameraFov = camera.FieldOfView
	pvInstance.Parent = camera

	self.focusTrove:Add(function()
		self.focusedPV = nil
		self.isInputFrozen = false

		workspace.CurrentCamera.CameraType = prevCameraType
		workspace.CurrentCamera.FieldOfView = prevCameraFov
		pvInstance.Parent = nil
	end)

	self.focusTrove:Add(pvState.animationManager:hookTrack(function(track)
		self.staticObservableState:update()(function(state)
			state.animationTrack = track
			return state
		end)
	end))

	self.focusTrove:Add(self:_watchIsSynced())
	self.focusTrove:Add(self:_watchFitType())
end

function AutoCaptureControllerClass.unfocus(self: AutoCaptureController)
	self.focusTrove:Clean()
end

function AutoCaptureControllerClass.getPVInstances(self: AutoCaptureController)
	local modelAndIndexArr = {}
	for pvInstance, pvState in self.stateByPV do
		table.insert(modelAndIndexArr, {
			index = pvState.ticket,
			model = pvInstance,
		})
	end

	table.sort(modelAndIndexArr, function(a, b)
		return a.index < b.index
	end)

	local models = {}
	for _, modelAndIndex in modelAndIndexArr do
		table.insert(models, modelAndIndex.model)
	end

	return models
end

function AutoCaptureControllerClass.capture(self: AutoCaptureController, scaleOS: Vector2)
	self.isCapturing = true

	local camera = workspace.CurrentCamera
	local viewportSize = camera.ViewportSize

	local viewportDelta = (viewportSize * scaleOS) - viewportSize
	local absPosition = self.captureRect.Min + viewportDelta / 2
	local absSize = self.captureRect.Max - self.captureRect.Min

	local center = absPosition + absSize / 2
	local offset = (absSize / 2) * scaleOS
	local scaledRect = RenderRect.fromRect(Rect.new(center - offset, center + offset))

	local dynamic = self.dynamicObservableState:get()
	local result = Photo.captureViewport({
		rect = scaledRect,
		type = dynamic.captureType :: any,
		delay = dynamic.captureDelay,
		alphaBleed = dynamic.alphaBleed,
	})

	local exported = Photo.export(result, nil)

	self.isCapturing = false

	return exported[1]
end

function AutoCaptureControllerClass.Destroy(self: AutoCaptureController)
	self:unfocus()
end

--

return AutoCaptureControllerStatic
