local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Future = require(pluginRoot.Packages.Future)
local Trove = require(pluginRoot.Packages.Trove)

local AABBHelper = require(script.Parent.AABBHelper)

local BLOCK = { 0, 1, 2, 3, 4, 5, 6, 7 }
local WEDGE = { 0, 1, 3, 4, 5, 7 }
local CORNER_WEDGE = { 0, 1, 4, 5, 6 }

local PointCloudStatic = {}

local PointCloudClass = {}
PointCloudClass.__index = PointCloudClass
PointCloudClass.ClassName = "PointCloud"

type Watcher = {
	part: BasePart,
	getPointCloud: () -> { Vector3 },
	cleanup: () -> (),
}

export type MeshData = {
	localVertices: { Vector3 },
	naturalSize: Vector3,
}

export type MeshDataCache = { [string]: {
	data: MeshData?,
} }

export type PointCloud = typeof(setmetatable(
	{} :: {
		trove: Trove.Trove,
		subject: Instance,
		tryUseMeshVertices: boolean?,
		meshDataCache: MeshDataCache,
		watchers: { [BasePart]: Watcher },
		vertices: { Vector3 },
	},
	PointCloudClass
))

function PointCloudStatic.new(subject: Instance, tryUseMeshVertices: boolean?, meshDataCache: MeshDataCache)
	local self = setmetatable({}, PointCloudClass) :: PointCloud

	self.trove = Trove.new()
	self.subject = subject
	self.tryUseMeshVertices = tryUseMeshVertices
	self.meshDataCache = meshDataCache
	self.watchers = {}
	self.vertices = {}

	self:_initWatchers()
	self:recalculateVertices()

	return self
end

-- Private

local function getPointCloud(cf: CFrame, size2: Vector3, indices: { number })
	local pointCloud = {}
	for i, j in indices do
		-- stylua: ignore
		pointCloud[i] = cf * (size2 * Vector3.new(
			2 * (math.floor(j / 4) % 2) - 1,
			2 * (math.floor(j / 2) % 2) - 1,
			2 * (j % 2) - 1
		))
	end
	return pointCloud
end

local function getPartPointCloud(part: BasePart)
	local indices = BLOCK
	if part:IsA("WedgePart") then
		indices = WEDGE
	elseif part:IsA("CornerWedgePart") then
		indices = CORNER_WEDGE
	end

	local partCF, partSize = part.CFrame, part.Size
	return getPointCloud(partCF, partSize / 2, indices)
end

function PointCloudClass._tryGetMeshData(self: PointCloud, meshPart: MeshPart)
	local meshContent = meshPart.MeshContent
	local cacheKey = if meshContent.SourceType == Enum.ContentSourceType.Uri then meshContent.Uri else nil

	if cacheKey and not self.meshDataCache[cacheKey] then
		local meshData: MeshData?
		local success, _err: string? = pcall(function()
			local editMesh = AssetService:CreateEditableMeshAsync(meshPart.MeshContent)

			local vertices = {}
			for _, vertexId in editMesh:GetVertices() do
				table.insert(vertices, editMesh:GetPosition(vertexId))
			end

			local newMeshData: MeshData = {
				localVertices = vertices,
				naturalSize = editMesh:GetSize(),
			}

			editMesh:Destroy()
			meshData = newMeshData
		end)

		if not success then
			self.meshDataCache[cacheKey] = { data = nil }
		else
			self.meshDataCache[cacheKey] = { data = meshData }
		end
	end

	local cached = if cacheKey then self.meshDataCache[cacheKey] else nil
	return if cached then cached.data else nil
end

function PointCloudClass._tryGetMeshDataFuture(self: PointCloud, meshPart: MeshPart)
	local request = Future.new()

	local thread = task.spawn(function()
		local data = self:_tryGetMeshData(meshPart)
		request:complete(data)
	end)

	self.trove:Add(function()
		task.cancel(thread)
	end)

	return request
end

function PointCloudClass._watchPart(self: PointCloud, part: BasePart): Watcher
	local trove = Trove.new()

	trove:Add(part:GetPropertyChangedSignal("CFrame"):Connect(function()
		self:recalculateVertices()
	end))

	trove:Add(part:GetPropertyChangedSignal("Size"):Connect(function()
		self:recalculateVertices()
	end))

	local meshDataFuture
	local function getWatchedPointCloud()
		if self.tryUseMeshVertices and part:IsA("MeshPart") then
			if not meshDataFuture then
				meshDataFuture = self:_tryGetMeshDataFuture(part)
				self:recalculateVertices()
			else
				local meshData = meshDataFuture:expect()
				if meshData then
					local partCF = part.CFrame
					local scale = part.Size / meshData.naturalSize
					local cloud = table.create(#meshData.localVertices)
					for i, lp in meshData.localVertices do
						cloud[i] = partCF * (lp * scale)
					end
					return cloud
				end
			end
		end
		return getPartPointCloud(part)
	end

	return {
		part = part,
		getPointCloud = getWatchedPointCloud,
		cleanup = function()
			trove:Destroy()
		end,
	}
end

function PointCloudClass._initWatchers(self: PointCloud)
	if self.subject:IsA("BasePart") then
		self.watchers[self.subject] = self:_watchPart(self.subject)
	end

	for _, part in self.subject:QueryDescendants("BasePart") do
		self.watchers[part] = self:_watchPart(part)
	end

	self.trove:Add(self.subject.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("BasePart") then
			self.watchers[descendant] = self:_watchPart(descendant)
			self:recalculateVertices()
		end
	end))

	self.trove:Add(self.subject.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BasePart") and self.watchers[descendant] then
			self.watchers[descendant].cleanup()
			self.watchers[descendant] = nil
			self:recalculateVertices()
		end
	end))

	self.trove:Add(function()
		for part, _ in self.watchers do
			self.watchers[part].cleanup()
			self.watchers[part] = nil
		end
	end)
end

function PointCloudClass.recalculateVertices(self: PointCloud)
	local vertices = {}
	for _part, watcher in self.watchers do
		local pointCloud = watcher.getPointCloud()
		for _, wp in pointCloud do
			table.insert(vertices, wp)
		end
	end
	self.vertices = vertices
end

function PointCloudClass.getVertices(self: PointCloud)
	return self.vertices
end

function PointCloudClass.Destroy(self: PointCloud)
	self.trove:Destroy()
end

return PointCloudStatic
