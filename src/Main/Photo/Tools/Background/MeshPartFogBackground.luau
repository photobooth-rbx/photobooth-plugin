local Lighting = game:GetService("Lighting") :: Lighting

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Trove = require(pluginRoot.Packages.Trove)

local RENDER_DISTANCE = 90_000
local MARGIN_OF_ERROR_DISTANCE = 1000
local PLANE_SCALE = 1_000_000_000

-- when yaw axis is world-aligned there's a bug that kills render distance
-- slightly nudging the part fixes this issue
local AXIS_ALIGN_NUDGE = CFrame.Angles(math.rad(0.01), math.rad(0.01), 0)

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
	part.Archivable = false
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

function MeshPartFogBackgroundClass.setMaterial(self: MeshPartFogBackground, material: Enum.Material)
	self.part.Material = material
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
