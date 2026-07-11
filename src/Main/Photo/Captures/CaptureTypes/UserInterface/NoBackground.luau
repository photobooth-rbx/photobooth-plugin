local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Types = require(pluginRoot.Main.Bindings.Interface.Types)
local Trove = require(pluginRoot.Packages.Trove)

local photoRoot = script:FindFirstAncestor("Photo")
local Screenshot = require(photoRoot.Captures.Screenshot)
local SceneControl = require(photoRoot.SceneControl)
local UIBounds = require(photoRoot.Tools.UIBoundsScreen)
local UIHider = require(photoRoot.Tools.UIHider)

local capturesRoot = script:FindFirstAncestor("Captures")
local Composers = require(capturesRoot.Composers)

local function operation(options: Types.CaptureUIOptions, trove: Trove.Trove)
	local uiBounds = UIBounds.new(options.subject, options.scale or Vector2.new(1, 1))
	local undoExclude = UIHider.addExclusion(uiBounds:GetLayerCollector())
	local uiHider = UIHider.new({ "LayerCollector" })

	trove:Add(function()
		uiBounds:Destroy()
		uiHider:Destroy()
		undoExclude()
	end)

	local targetRect = uiBounds:GetRect()
	local isFullscreen = Screenshot.isFullscreenRect(targetRect)

	local isEmulator, undoEmulator = SceneControl.emulatorEnforcement()
	trove:Add(undoEmulator)

	uiBounds:SetColor(Color3.new(1, 1, 1))
	SceneControl.yieldUntilNextFrame()
	local onWhite = Screenshot.rect(targetRect, isFullscreen, isEmulator)
	trove:Add(function()
		onWhite:Destroy()
	end)

	uiBounds:SetColor(Color3.new(0, 0, 0))
	SceneControl.yieldUntilNextFrame()
	local onBlack = Screenshot.rect(targetRect, isFullscreen, isEmulator)
	trove:Add(function()
		onBlack:Destroy()
	end)

	undoEmulator()

	local colorCorrection = Instance.new("ColorCorrectionEffect")
	trove:Add(colorCorrection)

	local errorWatch, markComplete = SceneControl.cleanupOnError(trove)
	local capture = errorWatch(Composers.reverseBlend(onWhite, onBlack, nil, colorCorrection))
	if options.alphaBleed then
		capture = errorWatch(Composers.alphaBleed(capture))
	end

	markComplete()
	return capture
end

return operation
