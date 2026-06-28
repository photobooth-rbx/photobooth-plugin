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

local function operation(options: Types.CaptureViewportOptions, trove: Trove.Trove)
	if Lighting:FindFirstChildWhichIsA("Atmosphere") then
		error("WARN: Skybox cannot be removed when Atmosphere is present.", 0)
	end

	trove:Add(SceneControl.hideScreenUI())
	local colorCorrection = trove:Add(SceneControl.getAppliedColorCorrectionCopy())

	local fogBackground = Background.new(workspace)
	fogBackground:setColor(Color3.new(0, 0, 0))
	fogBackground:setEnabled(true)

	trove:Add(SceneControl.once(function()
		fogBackground:Destroy()
	end))

	local gradedOnBlack
	if SceneControl.isGradedLightingRequired() or Lighting.ExposureCompensation ~= 0 then
		local undoGradedLighting = trove:Add(SceneControl.applyGradedLighting())

		SceneControl.yieldUntilNextFrame()
		gradedOnBlack = Screenshot.rect(options.rect)
		trove:Add(function()
			gradedOnBlack:Destroy()
		end)

		undoGradedLighting()
	end

	-- prepare for retro scene capturing
	trove:Add(SceneControl.applyRetroLighting())

	-- capture on retro black
	SceneControl.yieldUntilNextFrame()
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

	local errorWatch, markComplete = SceneControl.cleanupOnError(trove)
	local capture = errorWatch(Composers.reverseBlend(onWhiteRetro, onBlackRetro, gradedOnBlack, colorCorrection))
	if options.alphaBleed then
		capture = errorWatch(Composers.alphaBleed(capture))
	end

	markComplete()
	return capture
end

return operation
