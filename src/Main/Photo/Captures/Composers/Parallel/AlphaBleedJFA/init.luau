local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Image = require(pluginRoot.Utilities.Image)

local Constants = require(pluginRoot.Constants)

local PlantSeeds = require(script.PlantSeeds)
local JFAPasses = require(script.JFAPasses)
local Bleed = require(script.Bleed)

local function sliceIntoStrips(region: Rect, nSlices: number)
	local width = region.Max.X - region.Min.X
	local height = region.Max.Y - region.Min.Y
	local x0 = region.Min.X
	local y0 = region.Min.Y

	nSlices = math.max(1, math.min(nSlices, height))

	local regions = {}
	local stepY = math.floor(height / nSlices)
	for dy = 1, nSlices do
		local subY0 = y0 + (dy - 1) * stepY
		local subY1 = if dy == nSlices then y0 + height else y0 + dy * stepY
		table.insert(regions, Rect.new(x0, subY0, x0 + width, subY1))
	end

	return regions
end

local function alphaBleedJFA(img: Image.Image)
	local imgEdit = img:save()
	local voronoiEdit = img:save()

	local bledImg
	local success, err: string? = pcall(function()
		local imgSize = imgEdit.Size
		local fullRegion = Rect.new(0, 0, imgSize.X, imgSize.Y)
		local plantRegions = sliceIntoStrips(fullRegion, Constants.JFAActorCount)

		local workingBbox = PlantSeeds(imgEdit, voronoiEdit, plantRegions)

		if workingBbox then
			local jfaRegions = sliceIntoStrips(workingBbox, Constants.JFAActorCount)
			local nPasses = JFAPasses(imgEdit, voronoiEdit, jfaRegions, workingBbox)

			if nPasses > 0 then
				Bleed(imgEdit, voronoiEdit, jfaRegions, workingBbox)

				bledImg = Image.fromEditableImage(imgEdit)
				bledImg.templateUri = img.templateUri
			end
		end
	end)

	imgEdit:Destroy()
	voronoiEdit:Destroy()

	if not success and err then
		error(err, 0)
	end

	return bledImg
end

return alphaBleedJFA
