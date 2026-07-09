local StarterGui = game:GetService("StarterGui")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local RenderRect = require(pluginRoot.Main.Bindings.Interface.Helpers.RenderRect)
local StateManager = require(pluginRoot.Main.StateManager)

local ALWAYS_CLIPPED = true
local ALWAYS_CLIP_TEXT = true

-- Class

local UIBoundsClass = {}
UIBoundsClass.__index = UIBoundsClass
UIBoundsClass.ClassName = "UIBounds"

export type UIBounds = typeof(setmetatable(
	{} :: {
		scale: Vector2,
		subject: GuiObject,

		screenGui: ScreenGui,

		showDevelopmentGui: boolean,

		backgroundFrame: Frame,
		aabbFrame: Frame,
	},
	UIBoundsClass
))

-- Constructors

function UIBoundsClass.new(subject: GuiObject, scale: Vector2): UIBounds
	local self = setmetatable({}, UIBoundsClass) :: UIBounds

	self.scale = scale
	self.subject = subject

	self.screenGui = self:_createSurface(StarterGui)
	self.backgroundFrame, self.aabbFrame = self:_createBackgroundFrame(subject)
	self.backgroundFrame.Parent = self.screenGui

	self.showDevelopmentGui = StarterGui.ShowDevelopmentGui
	StarterGui.ShowDevelopmentGui = true

	self:SetColor(Color3.new(1, 1, 1))

	return self
end

-- Private

function UIBoundsClass._findNearestStyleLink(self: UIBounds)
	local styleLink: StyleLink?
	local pointer = self.subject.Parent :: Instance?

	while pointer and not styleLink do
		styleLink = pointer:FindFirstChildWhichIsA("StyleLink")
		pointer = pointer.Parent
	end

	return styleLink
end

function UIBoundsClass._createSurface(self: UIBounds, parent: Instance)
	local layerCollector = self.subject:FindFirstAncestorWhichIsA("LayerCollector")
	local zIndexBehavior = if layerCollector then layerCollector.ZIndexBehavior else Enum.ZIndexBehavior.Sibling

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "UIBounds"
	screenGui.ZIndexBehavior = zIndexBehavior
	screenGui.IgnoreGuiInset = true
	screenGui.DisplayOrder = 2 ^ 31 - 1
	screenGui.Parent = parent

	return screenGui
end

function UIBoundsClass._resolveUniformScale(self: UIBounds): number
	local scaleOS = StateManager.temporary:get().scaleOS
	local uiScale = self.scale / scaleOS

	assert(
		uiScale.X == uiScale.Y,
		`UIBounds: ScreenGui capture only supports uniform scaling, but got scale {self.scale}`
			.. ` (effective {uiScale} after OS scale {scaleOS}). Non-uniform scaling requires a SurfaceGui canvas.`
	)

	return uiScale.X
end

local function isClipped(frame: GuiObject, root: GuiObject): boolean
	local parent: Instance = frame
	while parent ~= root do
		parent = parent.Parent :: Instance

		if parent:IsA("GuiObject") and (ALWAYS_CLIPPED or parent.ClipsDescendants) then
			-- if the ancestor is a canvas group it's for sure clipped
			-- if not, then the ancestor must have not have any rotation for clipping to work
			if parent:IsA("CanvasGroup") or parent.AbsoluteRotation == 0 then
				return true
			end
		end
	end

	return false
end

local function getQualified(root: GuiObject): { GuiObject }
	local qualified = {}
	local stack: { Instance } = { root }

	while #stack > 0 do
		local popped = table.remove(stack) :: Instance

		if popped:IsA("GuiObject") then
			if popped.Visible and not isClipped(popped, root) then
				table.insert(qualified, popped)
			else
				continue
			end
		elseif popped:IsA("ScreenGui") then
			if not popped.Enabled then
				continue
			end
		elseif not popped:IsA("Folder") then
			continue
		end

		for _, child in popped:GetChildren() do
			table.insert(stack, child)
		end
	end

	return qualified
end

local function isTextFrame(frame: GuiObject): boolean
	return frame:IsA("TextLabel") or frame:IsA("TextButton") or frame:IsA("TextBox")
end

local function getCorners(frame: GuiObject): { Vector2 }
	local absSize = frame.AbsoluteSize
	local absPosition = frame.AbsolutePosition
	local absRotation = frame.AbsoluteRotation

	local center = absPosition + absSize / 2
	local rotator = CFrame.fromEulerAnglesXYZ(0, 0, math.rad(absRotation))

	local corners = {}
	for w = 0, 1 do
		for h = 0, 1 do
			local delta = (absPosition + absSize * Vector2.new(w, h)) - center
			local rDelta = rotator * Vector3.new(delta.X, delta.Y, 0)
			local newCorner = center + Vector2.new(rDelta.X, rDelta.Y)
			table.insert(corners, newCorner)
		end
	end

	return corners
end

local function getTextBoundsCorners(textFrame: TextLabel | TextButton | TextBox)
	local anchorX = 1
	if textFrame.TextXAlignment == Enum.TextXAlignment.Left then
		anchorX = 0
	elseif textFrame.TextXAlignment == Enum.TextXAlignment.Center then
		anchorX = 0.5
	end

	local anchorY = 1
	if textFrame.TextYAlignment == Enum.TextYAlignment.Top then
		anchorY = 0
	elseif textFrame.TextYAlignment == Enum.TextYAlignment.Center then
		anchorY = 0.5
	end

	local absSize = textFrame.AbsoluteSize
	local absPosition = textFrame.AbsolutePosition
	local absRotation = textFrame.AbsoluteRotation

	local center = absPosition + absSize / 2
	local rotator = CFrame.fromEulerAnglesXYZ(0, 0, math.rad(absRotation))

	local textBounds = textFrame.TextBounds
	local anchor = Vector2.new(anchorX, anchorY)
	local tlc = (absSize - textBounds) * anchor

	local corners = {}
	for w = 0, 1 do
		for h = 0, 1 do
			local delta = (absPosition + tlc + textBounds * Vector2.new(w, h)) - center
			local rDelta = rotator * Vector3.new(delta.X, delta.Y, 0)
			local newCorner = center + Vector2.new(rDelta.X, rDelta.Y)
			table.insert(corners, newCorner)
		end
	end

	return corners
end

local function getBoundingRect(qualified: { GuiObject }): Rect
	local corners = {}
	for _, frame in qualified do
		for _, corner in getCorners(frame) do
			table.insert(corners, corner)
		end

		if not ALWAYS_CLIP_TEXT and not frame.ClipsDescendants and isTextFrame(frame) then
			for _, corner in getTextBoundsCorners(frame :: TextLabel) do
				table.insert(corners, corner)
			end
		end
	end

	local max = corners[1]
	local min = corners[1]
	for i = 2, #corners do
		max = max:Max(corners[i])
		min = min:Min(corners[i])
	end

	return RenderRect.fromAbs(min, max - min)
end

local function getMinZIndex(subject: GuiObject): number
	local minZIndex = subject.ZIndex
	for _, descendant in subject:QueryDescendants("GuiObject") do
		if descendant:IsA("GuiObject") then
			minZIndex = math.min(minZIndex, descendant.ZIndex)
		end
	end
	return minZIndex
end

function UIBoundsClass._createBackgroundFrame(self: UIBounds, subject: GuiObject)
	local qualified = getQualified(subject)
	local aabbRect = getBoundingRect(qualified)
	local minSubjectZIndex = getMinZIndex(subject)

	local backgroundFrame = Instance.new("Frame")
	backgroundFrame.ZIndex = minSubjectZIndex - 1
	backgroundFrame.Size = UDim2.fromOffset(aabbRect.Width + 1, aabbRect.Height + 1)
	backgroundFrame.BorderSizePixel = 0

	local uiScale = Instance.new("UIScale")
	uiScale.Scale = self:_resolveUniformScale()
	uiScale.Parent = backgroundFrame

	local boundingFrame = Instance.new("Frame")
	boundingFrame.ZIndex = minSubjectZIndex - 1
	boundingFrame.Size = UDim2.fromOffset(aabbRect.Width, aabbRect.Height)
	boundingFrame.BorderSizePixel = 0
	boundingFrame.BackgroundTransparency = 1
	boundingFrame.Parent = backgroundFrame

	local subjectAbsSize = subject.AbsoluteSize
	local subjectAbsPosition = subject.AbsolutePosition
	local subjectRect = RenderRect.fromAbs(subjectAbsPosition, subjectAbsSize)

	local folder = Instance.new("Folder")
	folder.Name = "SubjectFolder"
	folder.Parent = boundingFrame

	local styleLink = self:_findNearestStyleLink()
	if styleLink then
		styleLink:Clone().Parent = folder
	end

	local subjectCopy = subject:Clone()
	subjectCopy.AnchorPoint = Vector2.zero
	subjectCopy.Size = UDim2.fromOffset(subjectRect.Width, subjectRect.Height)
	subjectCopy.Rotation = subject.AbsoluteRotation
	subjectCopy.Position = UDim2.fromOffset(subjectRect.Min.X - aabbRect.Min.X, subjectRect.Min.Y - aabbRect.Min.Y)
	subjectCopy.Parent = folder

	return backgroundFrame, boundingFrame
end

-- Public

function UIBoundsClass.GetRect(self: UIBounds)
	-- aabbFrame's absolute geometry is in on-screen (viewport) pixels and already includes
	-- the UIScale; convert to captured-screenshot pixels by applying the OS scale.
	local scaleOS = StateManager.temporary:get().scaleOS
	return RenderRect.fromAbs(self.aabbFrame.AbsolutePosition * scaleOS, self.aabbFrame.AbsoluteSize * scaleOS)
end

function UIBoundsClass.SetColor(self: UIBounds, color: Color3)
	self.backgroundFrame.BackgroundColor3 = color
end

function UIBoundsClass.GetLayerCollector(self: UIBounds)
	return self.screenGui
end

function UIBoundsClass.Destroy(self: UIBounds)
	self.screenGui:Destroy()
	StarterGui.ShowDevelopmentGui = self.showDevelopmentGui
end

--

return UIBoundsClass
