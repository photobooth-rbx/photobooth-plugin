local Lighting = game:GetService("Lighting") :: Lighting

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Trove = require(pluginRoot.Packages.Trove)

local RENDER_DISTANCE = 90_000
local MARGIN_OF_ERROR_DISTANCE = 1000

local PLANE_SCALE = 1_000_000_000
local AXIS_ALIGN_NUDGE = CFrame.Angles(0.01, 0.01, 0)

local MeshPartFogBackgroundClass = {}
MeshPartFogBackgroundClass.__index = MeshPartFogBackgroundClass
MeshPartFogBackgroundClass.ClassName = "MeshPartBackground"

export type MeshPartFogBackground = typeof(setmetatable(
	{} :: {
		part: BasePart,
		mesh: SpecialMesh,
		fogDistance: number,
		fogTrove: Trove.Trove,
	},
	MeshPartFogBackgroundClass
))

-- Constructors

function MeshPartFogBackgroundClass.new(parent: Instance): MeshPartFogBackground
	local self = setmetatable({}, MeshPartFogBackgroundClass) :: MeshPartFogBackground

	self.part, self.mesh = self:_createInstances()
	self.part.Parent = parent

	self.fogDistance = -1
	self.fogTrove = Trove.new()

	self:setEnabled(false)

	return self
end

function MeshPartFogBackgroundClass.neon(parent: Instance): MeshPartFogBackground
	local self = MeshPartFogBackgroundClass.new(parent)

	self.fogDistance = math.huge
	self.part.Material = Enum.Material.Neon

	return self
end

-- Private

function MeshPartFogBackgroundClass._createInstances(_self: MeshPartFogBackground)
	local part = Instance.new("Part")
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.identity
	part.Size = Vector3.new(2048, 2048, 2048)
	part.Color = Color3.new(1, 1, 1)
	part.Transparency = 0
	part.CastShadow = false
	part.CanCollide = false
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.Locked = true

	local mesh = Instance.new("SpecialMesh")
	mesh.Scale = Vector3.new(PLANE_SCALE, PLANE_SCALE, 0)
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Parent = part

	return part, mesh
end

-- Public

function MeshPartFogBackgroundClass.render(self: MeshPartFogBackground)
	local cameraCF = workspace.CurrentCamera.CFrame
	local intersection = cameraCF * Vector3.new(0, 0, -RENDER_DISTANCE)
	self.part.CFrame = CFrame.new(intersection) * cameraCF.Rotation * AXIS_ALIGN_NUDGE
	self.fogDistance = RENDER_DISTANCE - MARGIN_OF_ERROR_DISTANCE
end

function MeshPartFogBackgroundClass.setEnabled(self: MeshPartFogBackground, enabled: boolean)
	self:render()

	self.part.Transparency = if enabled then 0 else 1
	if enabled and self.fogDistance > 0 then
		local color = Lighting.FogColor
		local fogStart = Lighting.FogStart
		local fogEnd = Lighting.FogEnd
		self.fogTrove:Add(function()
			Lighting.FogColor = color
			Lighting.FogStart = fogStart
			Lighting.FogEnd = fogEnd
		end)

		Lighting.FogColor = self.part.Color
		Lighting.FogStart = self.fogDistance
		Lighting.FogEnd = self.fogDistance
	else
		self.fogTrove:Clean()
	end
end

function MeshPartFogBackgroundClass.setColor(self: MeshPartFogBackground, color: Color3)
	self.part.Color = color
	if self.part.Transparency == 0 then
		Lighting.FogColor = color
	end
end

function MeshPartFogBackgroundClass.Destroy(self: MeshPartFogBackground)
	self:setEnabled(false)
	self.fogTrove:Destroy()
	self.part:Destroy()
end

--

return MeshPartFogBackgroundClass
