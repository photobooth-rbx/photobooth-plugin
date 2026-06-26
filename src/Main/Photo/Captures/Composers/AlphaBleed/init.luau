local AssetService = game:GetService("AssetService")
local pluginRoot = script:FindFirstAncestor("PluginRoot")
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

local ACTOR_COUNT = 32

script:SetAttribute("ActorCount", ACTOR_COUNT)
script:SetAttribute("JFAPlusOne", true)

local PlantSeeds = require(script.PlantSeeds)
local JFAPasses = require(script.JFAPasses)
local ApplyBleed = require(script.ApplyBleed)

local function alphaBleedJFA(img: EditableImage)
	local bled = AssetService:CreateEditableImageAsync(Content.fromObject(img))
	local voronoi = AssetService:CreateEditableImageAsync(Content.fromObject(img))

	local success, err: string? = pcall(function()
		local imgSize = bled.Size
		local sourceRect = Rect.new(0, 0, imgSize.X, imgSize.Y)
		local plantRegions = RectSlicer.rows(sourceRect, ACTOR_COUNT)

		local workingBbox = PlantSeeds(bled, voronoi, plantRegions)

		if workingBbox then
			local jfaRegions = RectSlicer.rows(workingBbox, ACTOR_COUNT)
			local nPasses = JFAPasses(bled, voronoi, jfaRegions, workingBbox)

			if nPasses > 0 then
				ApplyBleed(bled, voronoi, jfaRegions, workingBbox)
			end
		end
	end)

	voronoi:Destroy()

	if not success and err then
		bled:Destroy()
		error(err, 0)
	end

	return bled
end

return alphaBleedJFA
