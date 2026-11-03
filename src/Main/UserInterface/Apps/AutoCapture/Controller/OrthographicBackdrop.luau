local pluginRoot = script:FindFirstAncestor("PluginRoot")
local MeshPartFogBackground = require(pluginRoot.Main.Photo.Tools.Background.MeshPartFogBackground)
local FogOverride = require(pluginRoot.Main.Photo.Tools.FogOverride)
local Asphalt = require(pluginRoot.Main.UserInterface.Asphalt)
local Trove = require(pluginRoot.Packages.Trove)

local AABBHelper = require(script.Parent.AABBHelper)

local COVERAGE_SCALE = 1.1
local RENDER_DISTANCE = MeshPartFogBackground.RENDER_DISTANCE
local MIN_FOG_DISTANCE = RENDER_DISTANCE + MeshPartFogBackground.MARGIN_OF_ERROR_DISTANCE
local TILE_PIXELS = 50

local sessionBackgroundColor3 = Color3.fromRGB(25, 26, 31)
local sessionImageColor3 = Color3.fromRGB(255, 255, 255)

local OrthographicBackdropStatic = {}

local OrthographicBackdropClass = {}
OrthographicBackdropClass.__index = OrthographicBackdropClass
OrthographicBackdropClass.ClassName = "OrthographicBackdrop"

export type OrthographicBackdrop = typeof(setmetatable(
	{} :: {
		trove: Trove.Trove,
		part: Part,
		billboardGui: BillboardGui,
		visible: boolean,
	},
	OrthographicBackdropClass
))

function OrthographicBackdropStatic.new(): OrthographicBackdrop
	local self = setmetatable({}, OrthographicBackdropClass) :: OrthographicBackdrop

	local trove = Trove.new()

	local part = trove:Add(Instance.new("Part"))
	part.Name = "Backdrop"
	part.Archivable = false
	part.Locked = true
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part:AddTag(AABBHelper.IGNORE_TAG)

	local billboardGui = Instance.new("BillboardGui")
	billboardGui.Archivable = false
	billboardGui.AlwaysOnTop = false
	billboardGui.LightInfluence = 0
	billboardGui.Brightness = 1
	billboardGui.Adornee = part
	billboardGui.Parent = part

	local checkerboard = Instance.new("ImageLabel")
	checkerboard.Name = "Checkerboard"
	checkerboard.Size = UDim2.fromScale(1, 1)
	checkerboard.BorderSizePixel = 0
	checkerboard.BackgroundColor3 = sessionBackgroundColor3
	checkerboard.Image = Asphalt.misc.checkerboard
	checkerboard.ScaleType = Enum.ScaleType.Tile
	checkerboard.TileSize = UDim2.fromOffset(TILE_PIXELS, TILE_PIXELS)
	checkerboard.ImageColor3 = sessionImageColor3
	checkerboard.ImageTransparency = 0.9
	checkerboard.Parent = billboardGui

	trove:Add(checkerboard:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
		sessionBackgroundColor3 = checkerboard.BackgroundColor3
	end))

	trove:Add(checkerboard:GetPropertyChangedSignal("ImageColor3"):Connect(function()
		sessionImageColor3 = checkerboard.ImageColor3
	end))

	self.trove = trove
	self.part = part
	self.billboardGui = billboardGui
	self.visible = false

	return self
end

function OrthographicBackdropClass.setVisible(self: OrthographicBackdrop, visible: boolean)
	if self.visible == visible then
		return
	end

	self.visible = visible
	self.part.Parent = if visible then workspace.CurrentCamera else nil

	if visible then
		FogOverride.set(FogOverride.Priority.ORTHOGRAPHIC_BACKDROP, function(fog)
			return {
				FogColor = fog.FogColor,
				FogStart = math.max(fog.FogStart, MIN_FOG_DISTANCE),
				FogEnd = math.max(fog.FogEnd, MIN_FOG_DISTANCE),
			}
		end)
	else
		FogOverride.clear(FogOverride.Priority.ORTHOGRAPHIC_BACKDROP)
	end
end

function OrthographicBackdropClass.render(self: OrthographicBackdrop)
	if not self.visible then
		return
	end

	local camera = workspace.CurrentCamera
	local cameraCF = camera.CFrame

	self.part.CFrame = cameraCF * CFrame.new(0, 0, -RENDER_DISTANCE)

	local size = camera.ViewportSize * COVERAGE_SCALE
	local udimSize = UDim2.fromOffset(size.X, size.Y)
	if self.billboardGui.Size ~= udimSize then
		self.billboardGui.Size = udimSize
	end
end

function OrthographicBackdropClass.Destroy(self: OrthographicBackdrop)
	self:setVisible(false)
	self.trove:Destroy()
end

return OrthographicBackdropStatic
