local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

local ACTOR_COUNT = 32

local PLUS_ONE = true
local INSIDE_THRESHOLD = 127.5

script:SetAttribute("ActorCount", ACTOR_COUNT)
script:SetAttribute("PlusOne", PLUS_ONE)

local PlantSeeds = require(script.PlantSeeds)
local JFAPasses = require(script.JFAPasses)

local SignedVectorField = {}

export type Options = {
	insideThreshold: number?,
	maxDistance: number?,
	boundToOutside: boolean?,
	token: Cancellation.CancelToken?,
}

function SignedVectorField.generateAsync(img: EditableImage, options: Options?): (EditableImage?, Rect?)
	local settings: Options = options or {}
	local token = settings.token
	local insideThreshold = settings.insideThreshold or INSIDE_THRESHOLD

	local voronoi = AssetService:CreateEditableImageAsync(Content.fromObject(img))
	local unhookVoronoi = if token
		then token:onCancel(function()
			voronoi:Destroy()
		end)
		else nil

	local fieldRegion: Rect? = nil
	local success, err: string? = pcall(function()
		local imgSize = img.Size
		local fullRegion = Rect.new(0, 0, imgSize.X, imgSize.Y)
		local plantRegions = RectSlicer.rows(fullRegion, ACTOR_COUNT)

		local hasInside, outsideRegion = PlantSeeds(img, voronoi, plantRegions, insideThreshold, token)
		if token and token:isCancelled() then
			return
		end

		local region: Rect? = fullRegion
		if settings.boundToOutside then
			region = if hasInside then outsideRegion else nil
		end

		if not region then
			return
		end

		local passRegions = RectSlicer.rows(region, ACTOR_COUNT)
		local nPasses = JFAPasses(voronoi, passRegions, region, settings.maxDistance, token)
		if nPasses > 0 then
			fieldRegion = region
		end
	end)

	if unhookVoronoi then
		unhookVoronoi()
	end

	local isCancelled = if token then token:isCancelled() else false
	if not success or isCancelled then
		voronoi:Destroy()

		if not success and err and not isCancelled then
			error(err, 0)
		end

		return nil, nil
	end

	return voronoi, fieldRegion
end

function SignedVectorField.generate(content: Content, options: Options?)
	return Cancellation.new(function(token): (EditableImage?, Rect?)
		local img = AssetService:CreateEditableImageAsync(content)
		local unhookImg = token:onCancel(function()
			img:Destroy()
		end)

		local settings: Options = if options then table.clone(options) else {}
		settings.token = token

		local field: EditableImage?, fieldRegion: Rect?
		local success, err: string? = pcall(function()
			field, fieldRegion = SignedVectorField.generateAsync(img, settings)
		end)

		unhookImg()
		img:Destroy()

		if not success and err and not token:isCancelled() then
			error(err, 0)
		end

		return field, fieldRegion
	end)
end

return SignedVectorField
