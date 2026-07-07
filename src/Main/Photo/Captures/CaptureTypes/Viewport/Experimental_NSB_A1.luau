local Lighting = game:GetService("Lighting") :: Lighting

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Trove = require(pluginRoot.Packages.Trove)

local Types = require(pluginRoot.Main.Bindings.Interface.Types)

local photoRoot = script:FindFirstAncestor("Photo")
local Screenshot = require(photoRoot.Captures.Screenshot)
local Background = require(photoRoot.Tools.Background)
local SceneControl = require(photoRoot.SceneControl)

local capturesRoot = script:FindFirstAncestor("Captures")
local Composers = require(capturesRoot.Composers)

local function getAppliedAtmosphere(): Atmosphere?
	local children = Lighting:GetChildren()
	for i = #children, 1, -1 do
		local child = children[i]
		if child:IsA("Atmosphere") then
			return child
		end
	end
	return nil
end

local function operation(options: Types.CaptureViewportOptions, trove: Trove.Trove)
	trove:Add(SceneControl.hideScreenUI())
	local colorCorrection = trove:Add(SceneControl.getAppliedColorCorrectionCopy())

	-- capture on graded black
	local gradedOnBlack
	local preRetroYieldCount = 1
	if SceneControl.isGradedLightingRequired() or Lighting.ExposureCompensation ~= 0 then
		local undoGradedLighting = trove:Add(SceneControl.applyGradedLighting())

		local atmosphere = getAppliedAtmosphere()
		if atmosphere then
			preRetroYieldCount = 100

			trove:Add(SceneControl.setProperties(atmosphere, {
				Haze = 10,
				Glare = 0,
				Color = Color3.new(0, 0, 0),
				Decay = Color3.new(0, 0, 0),
			}))
		end

		-- SceneControl.yieldUntilNextFrame()
		gradedOnBlack = Screenshot.rect(options.rect)
		trove:Add(function()
			gradedOnBlack:Destroy()
		end)

		undoGradedLighting()
	end

	-- prepare for retro scene capturing
	trove:Add(SceneControl.applyRetroLighting())

	local fogBackground = Background.new(workspace)
	fogBackground:setColor(Color3.new(0, 0, 0))
	fogBackground:setEnabled(true)

	trove:Add(SceneControl.once(function()
		fogBackground:Destroy()
	end))

	-- capture on retro black
	for _i = 1, preRetroYieldCount do
		SceneControl.yieldUntilNextFrame()
	end
	local onBlackRetro = Screenshot.rect(options.rect)
	trove:Add(function()
		onBlackRetro:Destroy()
	end)

	-- capture on retro white
	fogBackground:setColor(Color3.new(1, 1, 1))
	SceneControl.yieldUntilNextFrame()
	local onWhiteRetro = Screenshot.rect(options.rect)
	trove:Add(function()
		onWhiteRetro:Destroy()
	end)

	-- remove background & alpha bleed
	local errorWatch, markComplete = SceneControl.cleanupOnError(trove)
	local capture = errorWatch(Composers.reverseBlend(onWhiteRetro, onBlackRetro, gradedOnBlack, colorCorrection))
	if options.alphaBleed then
		capture = errorWatch(Composers.alphaBleed(capture))
	end

	markComplete()
	return capture
end

return operation
