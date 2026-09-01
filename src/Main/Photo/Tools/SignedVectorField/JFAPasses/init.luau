local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)

local Scheduler = require(script.Parent.Scheduler)

local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)
local PLUS_ONE = not not script.Parent:GetAttribute("PlusOne")

type WorkerAction = typeof(require(script.Worker))

local acquireScheduler = Scheduler.pool(ACTOR_COUNT, {
	script = script.Worker,
	typecast = (nil :: any) :: WorkerAction,
})

local function jfaPasses(
	voronoi: EditableImage,
	regions: { Rect },
	region: Rect,
	maxDistance: number?,
	token: Cancellation.CancelToken?
): number
	local regionSize = region.Max - region.Min
	local regionWidth, regionHeight = regionSize.X, regionSize.Y

	local maxRegionDim = math.max(regionWidth, regionHeight)
	local nextStep = math.min(
		if maxDistance then math.floor(2 ^ math.ceil(math.log(maxDistance, 2))) else math.huge,
		math.max(1, math.floor(maxRegionDim / 2))
	)

	local passSteps = {}
	while nextStep >= 1 do
		table.insert(passSteps, nextStep)
		nextStep = math.floor(nextStep / 2)
	end

	if #passSteps == 0 then
		return 0
	end

	if PLUS_ONE then
		table.insert(passSteps, 1)
	end

	local scheduler, release = acquireScheduler(token)

	local seedbed = AssetService:CreateEditableImageAsync(Content.fromObject(voronoi))
	local unhookSeedbed = if token
		then token:onCancel(function()
			seedbed:Destroy()
		end)
		else nil

	local nPasses = 0
	local stitched = buffer.create(regionWidth * regionHeight * 4)

	for _, step in passSteps do
		for _, crop in regions do
			scheduler:schedule(seedbed, voronoi, crop, step)
		end

		local results, workCancelled = scheduler:workAsync()
		if workCancelled then
			break
		end

		local offset = 0
		for _i, getCropBuffer in results do
			local cropBuffer = getCropBuffer()
			buffer.copy(stitched, offset, cropBuffer)
			offset = offset + buffer.len(cropBuffer)
		end

		voronoi:WritePixelsBuffer(region.Min, regionSize, stitched)
		nPasses = nPasses + 1
	end

	release()

	if unhookSeedbed then
		unhookSeedbed()
	end
	seedbed:Destroy()

	return nPasses
end

return jfaPasses
