local AssetService = game:GetService("AssetService")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Cancellation = require(pluginRoot.Utilities.Cancellation)
local RectSlicer = require(pluginRoot.Utilities.RectSlicer)

local ACTOR_COUNT = 32

local PLUS_ONE = true
local INSIDE_THRESHOLD = 127.5

script:SetAttribute("PlusOne", PLUS_ONE)
script:SetAttribute("ActorCount", ACTOR_COUNT)

local SignedVectorField = {}

local PlantSeeds = require(script.PlantSeeds)
local JFAPasses = require(script.JFAPasses)

function SignedVectorField.generate(content: Content)
	return Cancellation.new(function(token)
		local imgEdit = AssetService:CreateEditableImageAsync(content)
		local unhookImgEdit = token:onCancel(function()
			imgEdit:Destroy()
		end)

		local voronoiEdit = AssetService:CreateEditableImageAsync(content)
		local unhookVoronoiEdit = token:onCancel(function()
			voronoiEdit:Destroy()
		end)

		local success, err: string? = pcall(function()
			local imgSize = imgEdit.Size
			local fullRegion = Rect.new(0, 0, imgSize.X, imgSize.Y)
			local rows = RectSlicer.rows(fullRegion, ACTOR_COUNT)

			PlantSeeds(imgEdit, voronoiEdit, rows, INSIDE_THRESHOLD, token)
			if not token:isCancelled() then
				JFAPasses(voronoiEdit, rows, token)
			end
		end)

		unhookImgEdit()
		imgEdit:Destroy()

		if not success and err and not token:isCancelled() then
			error(err, 0)
		end

		unhookVoronoiEdit()
		return voronoiEdit
	end)
end

return SignedVectorField
