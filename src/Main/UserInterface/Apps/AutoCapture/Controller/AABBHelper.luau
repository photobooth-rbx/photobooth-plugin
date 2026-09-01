local AABBHelper = {}

AABBHelper.IGNORE_TAG = "photobooth:ignore"

-- Private

local function getPartBounds(part: BasePart)
	if part:IsA("MeshPart") then
		-- bug on Roblox's end means we need this hacky solution to read a mesh part's accurate CFrame / Size
		-- https://devforum.roblox.com/t/avatar-body-parts-dont-match-the-size-listed-in-the-explorer/3101124
		local meshPart = Instance.new("MeshPart")
		meshPart:ApplyMesh(part)
		meshPart.CFrame = part.CFrame
		meshPart.Size = part.Size

		local model = Instance.new("Model")
		meshPart.Parent = model
		local partCF, partSize = model:GetBoundingBox()
		model:Destroy()

		return partCF, partSize
	end
	return part.CFrame, part.Size
end

-- Public

function AABBHelper.getMinMax(orientation: CFrame, parts: { BasePart }): (Vector3, Vector3)
	local corners = {}
	local rotation = orientation.Rotation
	for _, part in parts do
		local partCorners = {}
		local partCF, partSize = getPartBounds(part)
		local partSize2 = partSize / 2

		for i = 0, 7 do
			-- stylua: ignore
			partCorners[i + 1] = partCF * (partSize2 * Vector3.new(
				2 * (math.floor(i / 4) % 2) - 1,
				2 * (math.floor(i / 2) % 2) - 1,
				2 * (i % 2) - 1
			))
		end

		for _, corner in partCorners do
			table.insert(corners, rotation:PointToObjectSpace(corner))
		end
	end

	local max = Vector3.zero
	local min = Vector3.zero
	if #corners > 0 then
		max = corners[1]
		min = corners[1]
		for i = 2, #corners do
			max = max:Max(corners[i])
			min = min:Min(corners[i])
		end
	end

	return min, max
end

function AABBHelper.getBoundingBox(orientation: CFrame, parts: { BasePart }): (CFrame, Vector3)
	local rotation = orientation.Rotation
	local min, max = AABBHelper.getMinMax(rotation, parts)
	return rotation * CFrame.new((min + max) / 2), max - min
end

--[[
The predicate of this function can return `true`, `false`, or `nil` with different behaviors for each:
	* `true`: The Instance successfully matches the criteria of the search.
	* `false`: The Instance does not match the criteria of the search, but will continue to look through its descendants.
	* `nil`: The Instance does not match the criteria of the search and will **not** continue to look through its descendants.
--]]
function AABBHelper.getFilteredParts(instance: Instance, filter: ((Instance) -> boolean?)?)
	local parts = {}
	if filter then
		local stack: { Instance } = { instance }
		while #stack > 0 do
			local popped = table.remove(stack) :: Instance
			local filterResult = filter(popped)
			if filterResult == nil then
				continue
			elseif filterResult == true and popped:IsA("BasePart") then
				table.insert(parts, popped)
			end

			for _, child in popped:GetChildren() do
				table.insert(stack, child)
			end
		end
	else
		parts = instance:QueryDescendants("BasePart")
		if instance:IsA("BasePart") then
			table.insert(parts, instance)
		end
	end

	return parts
end

function AABBHelper.ignoreTagFilter(candidate: Instance): boolean?
	return if candidate:HasTag(AABBHelper.IGNORE_TAG) then nil else true
end

--

return AABBHelper
