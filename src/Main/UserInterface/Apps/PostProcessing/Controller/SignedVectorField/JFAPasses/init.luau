--!strict

local AssetService = game:GetService("AssetService") :: AssetService

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)
local Parallel = require(pluginRoot.Packages.Parallel)

local PLUS_ONE = not not script.Parent:GetAttribute("PlusOne")
local ACTOR_COUNT = assert(script.Parent:GetAttribute("ActorCount") :: number?)

type WorkerAction = typeof(require(script.Worker))

local function jfaPasses(voronoi: EditableImage, regions: { Rect }, token: Cancellation.CancelToken)
	local scheduler = Parallel.new(ACTOR_COUNT, {
		script = script.Worker,
		typecast = (nil :: any) :: WorkerAction,
	})

	local unhookScheduler = token:onCancel(function()
		scheduler:cancelWork()
		scheduler:Destroy()
	end)

	scheduler:waitForReady()

	local voronoiSize = voronoi.Size
	local voronoiWidth, voronoiHeight = voronoiSize.X, voronoiSize.Y

	local seedbed = AssetService:CreateEditableImageAsync(Content.fromObject(voronoi))
	local seedbedUnhook = token:onCancel(function()
		seedbed:Destroy()
	end)

	local maxDim = math.max(voronoiWidth, voronoiHeight)
	local nextStep = math.max(1, math.floor(maxDim / 2))

	local passSteps = {}
	while nextStep >= 1 do
		table.insert(passSteps, nextStep)
		nextStep = math.floor(nextStep / 2)
	end

	if PLUS_ONE then
		table.insert(passSteps, 1)
	end

	local stitched = buffer.create(voronoiWidth * voronoiHeight * 4)
	for _, step in passSteps do
		for _, crop in regions do
			scheduler:schedule(seedbed, voronoi, crop, step)
		end

		local results, workCancelled = scheduler:workAsync()
		if workCancelled then
			break
		end

		local offset = 0
		for _i, getBuffer in results do
			local b = getBuffer()
			buffer.copy(stitched, offset, b)
			offset = offset + buffer.len(b)
		end

		voronoi:WritePixelsBuffer(Vector2.zero, voronoiSize, stitched)
	end

	unhookScheduler()
	seedbedUnhook()
	scheduler:Destroy()
	seedbed:Destroy()
end

return jfaPasses
