local Lighting = game:GetService("Lighting") :: Lighting

export type Fog = {
	FogColor: Color3,
	FogStart: number,
	FogEnd: number,
}

export type Transform = (fog: Fog) -> Fog

local FogOverride = {}

FogOverride.Priority = {
	ORTHOGRAPHIC_BACKDROP = 1,
	BLACKOUT = 2,
	CAPTURE = 3,
}

-- Private

local base: Fog? = nil
local transformByPriority: { [number]: Transform } = {}
local sortedPriorities: { number } = {}

local function readLighting(): Fog
	return {
		FogColor = Lighting.FogColor,
		FogStart = Lighting.FogStart,
		FogEnd = Lighting.FogEnd,
	}
end

local function writeLighting(fog: Fog)
	Lighting.FogColor = fog.FogColor
	Lighting.FogStart = fog.FogStart
	Lighting.FogEnd = fog.FogEnd
end

local function sortPriorities()
	table.clear(sortedPriorities)
	for priority in transformByPriority do
		table.insert(sortedPriorities, priority)
	end
	table.sort(sortedPriorities)
end

-- Public

function FogOverride.refresh()
	if #sortedPriorities == 0 then
		if base then
			writeLighting(base)
			base = nil
		end
		return
	end

	if not base then
		base = readLighting()
	end

	local fog = table.clone(base :: Fog)
	for _, priority in sortedPriorities do
		fog = transformByPriority[priority](fog)
	end
	writeLighting(fog)
end

function FogOverride.set(priority: number, transform: Transform)
	local isNewPriority = transformByPriority[priority] == nil
	transformByPriority[priority] = transform
	if isNewPriority then
		sortPriorities()
	end
	FogOverride.refresh()
end

function FogOverride.clear(priority: number)
	if transformByPriority[priority] then
		transformByPriority[priority] = nil
		sortPriorities()
		FogOverride.refresh()
	end
end

--

return FogOverride
