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
	local voronoi: EditableImage? = nil
	local success, err: string? = pcall(function()
		local field, region = SignedVectorField.generateAsync(img, FIELD_OPTIONS)
		voronoi = field

		if field and region then
			local applyRegions = RectSlicer.rows(region, ACTOR_COUNT)
			ApplyBleed(img, field, applyRegions)
		end
	end)

	if voronoi then
		voronoi:Destroy()
	end

	if not success and err then
		error(err, 0)
	end
end

local function timedAlphaBleedJFA(img: EditableImage)
	local t = os.clock()
	alphaBleedJFA(img)
	print(os.clock() - t)
end

return timedAlphaBleedJFA
