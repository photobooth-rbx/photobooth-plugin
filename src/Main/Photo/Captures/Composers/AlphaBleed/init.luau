local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)
local SignedVectorField = require(pluginRoot.Main.Photo.Tools.SignedVectorField)

local ACTOR_COUNT = 32

local FIELD_OPTIONS: SignedVectorField.Options = {
	insideThreshold = 0,
	boundToOutside = true,
}

script:SetAttribute("ActorCount", ACTOR_COUNT)

local ApplyBleed = require(script.ApplyBleed)

local function alphaBleedJFA(img: EditableImage)
	local bled = AssetService:CreateEditableImageAsync(Content.fromObject(img))

	local voronoi: EditableImage? = nil
	local success, err: string? = pcall(function()
		local field, region = SignedVectorField.generateAsync(bled, FIELD_OPTIONS)
		voronoi = field

		if field and region then
			local applyRegions = RectSlicer.rows(region, ACTOR_COUNT)
			ApplyBleed(bled, field, applyRegions, region)
		end
	end)

	if voronoi then
		voronoi:Destroy()
	end

	if not success and err then
		bled:Destroy()
		error(err, 0)
	end

	return bled
end

return alphaBleedJFA
