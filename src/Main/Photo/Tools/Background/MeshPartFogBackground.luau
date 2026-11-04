local FogOverride = require(script.Parent.Parent.FogOverride)

local RENDER_DISTANCE = 90_000
local MARGIN_OF_ERROR_DISTANCE = 1000
local PLANE_SCALE = 1_000_000_000

-- when yaw axis is world-aligned there's a bug that kills render distance
-- slightly nudging the part fixes this issue
local AXIS_ALIGN_NUDGE = CFrame.Angles(math.rad(0.01), math.rad(0.01), 0)

local MeshPartFogBackgroundClass = {}
MeshPartFogBackgroundClass.__index = MeshPartFogBackgroundClass
MeshPartFogBackgroundClass.ClassName = "MeshPartBackground"

MeshPartFogBackgroundClass.RENDER_DISTANCE = RENDER_DISTANCE
MeshPartFogBackgroundClass.MARGIN_OF_ERROR_DISTANCE = MARGIN_OF_ERROR_DISTANCE

export type MeshPartFogBackground = typeof(setmetatable(
	{} :: {
		part: BasePart,
		mesh: SpecialMesh,
		fogDistance: number,
		fogPriority: number,
		isFogApplied: boolean,
	},
	MeshPartFogBackgroundClass
))

-- Constructors

function MeshPartFogBackgroundClass.new(parent: Instance, fogPriority: number): MeshPartFogBackground
	local self = setmetatable({}, MeshPartFogBackgroundClass) :: MeshPartFogBackground

	self.part, self.mesh = self:_createInstances()
	self.part.Parent = parent

	self.fogDistance = -1
	self.fogPriority = fogPriority
	self.isFogApplied = false

	self:setEnabled(false)

	return self
end

function MeshPartFogBackgroundClass.neon(parent: Instance, fogPriority: number): MeshPartFogBackground
	local self = MeshPartFogBackgroundClass.new(parent, fogPriority)

	self.fogDistance = math.huge
	self.part.Material = Enum.Material.Neon

	return self
end

-- Private

function MeshPartFogBackgroundClass._createInstances(_self: MeshPartFogBackground)
	local part = Instance.new("Part")
	part.Archivable = false
	part.Name = "Backdrop"
	part.Material = Enum.Material.SmoothPlastic
	part.CFrame = CFrame.identity
	part.Size = Vector3.new(1, 1, 1)
	part.Color = Color3.new(1, 1, 1)
	part.Transparency = 0
	part.CastShadow = false
	part.CanCollide = false
	part.Anchored = true
	part.CanTouch = false
	part.CanQuery = false
	part.Locked = true

	local mesh = Instance.new("SpecialMesh")
	mesh.Archivable = false
	mesh.Scale = Vector3.new(PLANE_SCALE, PLANE_SCALE, 0)
	mesh.MeshType = Enum.MeshType.Brick
	mesh.Parent = part

	return part, mesh
end

-- Public

function MeshPartFogBackgroundClass.getNearZ(self: MeshPartFogBackground)
	local pp = self.part.CFrame.Position
	local pn = self.part.CFrame.LookVector

	local camera = workspace.CurrentCamera :: Camera
	local viewport = camera.ViewportSize
	local cameraCF = camera.CFrame
	local lv = cameraCF.LookVector

	local corners = {
		Vector2.new(0, 0),
		Vector2.new(viewport.X, 0),
		Vector2.new(0, viewport.Y),
		Vector2.new(viewport.X, viewport.Y),
	}

	local nearest = math.huge
	for _, corner in corners do
		-- ray / plane intersection
		local ray = camera:ViewportPointToRay(corner.X, corner.Y)
		local rp, rd = ray.Origin, ray.Direction
		local t = (pp - rp):Dot(pn) / rd:Dot(pn)
		local hit = rp + rd * t
		nearest = math.min(nearest, (hit - cameraCF.Position):Dot(lv))
	end

	return -nearest + MARGIN_OF_ERROR_DISTANCE
end

function MeshPartFogBackgroundClass.render(self: MeshPartFogBackground)
	local cameraCF = workspace.CurrentCamera.CFrame
	local intersection = cameraCF * Vector3.new(0, 0, -RENDER_DISTANCE)
	self.part.CFrame = CFrame.new(intersection) * cameraCF.Rotation * AXIS_ALIGN_NUDGE
	self.fogDistance = RENDER_DISTANCE - MARGIN_OF_ERROR_DISTANCE
end

function MeshPartFogBackgroundClass.setEnabled(self: MeshPartFogBackground, enabled: boolean)
	self:render()

	self.part.Transparency = if enabled then 0 else 1
	self.isFogApplied = enabled and self.fogDistance > 0
	if self.isFogApplied then
		FogOverride.set(self.fogPriority, function(_fog)
			return {
				FogColor = self.part.Color,
				FogStart = self.fogDistance,
				FogEnd = self.fogDistance,
			}
		end)
	else
		FogOverride.clear(self.fogPriority)
	end
end

function MeshPartFogBackgroundClass.setMaterial(self: MeshPartFogBackground, material: Enum.Material)
	self.part.Material = material
end

function MeshPartFogBackgroundClass.setColor(self: MeshPartFogBackground, color: Color3)
	self.part.Color = color
	if self.isFogApplied then
		FogOverride.refresh()
	end
end

function MeshPartFogBackgroundClass.Destroy(self: MeshPartFogBackground)
	self:setEnabled(false)
	self.part:Destroy()
end

--

return MeshPartFogBackgroundClass
