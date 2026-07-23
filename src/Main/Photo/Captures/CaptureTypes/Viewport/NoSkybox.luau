local Lighting = game:GetService("Lighting") :: Lighting

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Types = require(pluginRoot.Main.Bindings.Interface.Types)
local Trove = require(pluginRoot.Packages.Trove)

local photoRoot = script:FindFirstAncestor("Photo")
local Screenshot = require(photoRoot.Captures.Screenshot)
local Background = require(photoRoot.Tools.Background)
local SceneControl = require(photoRoot.SceneControl)

local capturesRoot = script:FindFirstAncestor("Captures")
local Composers = require(capturesRoot.Composers)

local function operation(options: Types.CaptureViewportOptions, isFullscreen: boolean?, trove: Trove.Trove)
	local isEmulator, undoEmulator = SceneControl.emulatorEnforcement()
	trove:Add(undoEmulator)

	trove:Add(SceneControl.hideScreenUI())
	local colorCorrection = trove:Add(SceneControl.getAppliedColorCorrectionCopy())
	local undoColorCorrection = trove:Add(SceneControl.hideColorCorrections())

	local fogBackground = Background.new(workspace)
	fogBackground:setColor(Color3.new(0, 0, 0))
	fogBackground:setEnabled(true)

	trove:Add(SceneControl.once(function()
		fogBackground:Destroy()
	end))

	local gradedOnBlack
	local atmoOnBlackSubject
	local atmoOnBlackBackground
	local setAtmosphereHidden

	if Lighting:FindFirstChildWhichIsA("Atmosphere") then
		fogBackground:setMaterial(Enum.Material.Neon)

		setAtmosphereHidden = SceneControl.getAtmosphereHider()
		trove:Add(function()
			setAtmosphereHidden(false)
		end)

		SceneControl.yieldUntilNextFrame()
		atmoOnBlackSubject = Screenshot.rect(options.rect, isFullscreen, isEmulator)
		trove:Add(function()
			atmoOnBlackSubject:Destroy()
		end)

		-- capture scene w/ atmosphere only skybox
		-- re-parenting the model is not good b/c it's expensive and it causes particles to restart
		-- I use this trick to override the camera's near plane z so we only render the skybox
		local camera = workspace.CurrentCamera
		local renderCF = camera.CFrame
		local nearZ = fogBackground:getNearZ()
		local nz = ((camera.NearPlaneZ + nearZ) / camera.NearPlaneZ)
		camera.CFrame = renderCF * CFrame.new(0, 0, 0, 1 / nz, 0, 0, 0, 1 / nz, 0, 0, 0, 1 / nz)
		trove:Add(function()
			camera.CFrame = renderCF
		end)

		SceneControl.yieldUntilNextFrame()
		atmoOnBlackBackground = Screenshot.rect(options.rect, isFullscreen, isEmulator)
		trove:Add(function()
			atmoOnBlackBackground:Destroy()
		end)

		camera.CFrame = renderCF
		fogBackground:setMaterial(Enum.Material.SmoothPlastic)
	elseif SceneControl.isGradedLightingRequired() or Lighting.ExposureCompensation ~= 0 then
		local undoGradedLighting = trove:Add(SceneControl.applyGradedLighting())

		SceneControl.yieldUntilNextFrame()
		gradedOnBlack = Screenshot.rect(options.rect, isFullscreen, isEmulator)
		trove:Add(function()
			gradedOnBlack:Destroy()
		end)

		undoGradedLighting()
	end

	-- prepare for retro scene capturing
	trove:Add(SceneControl.applyRetroLighting())

	if setAtmosphereHidden then
		setAtmosphereHidden(true)
		task.wait(0.5)
	end

	-- capture on retro black
	SceneControl.yieldUntilNextFrame()
	local onBlackRetro = Screenshot.rect(options.rect, isFullscreen, isEmulator)
	trove:Add(function()
		onBlackRetro:Destroy()
	end)

	-- capture on retro white
	fogBackground:setColor(Color3.new(1, 1, 1))

	if setAtmosphereHidden then
		task.wait(0.5)
	end

	SceneControl.yieldUntilNextFrame()
	local onWhiteRetro = Screenshot.rect(options.rect, isFullscreen, isEmulator)
	trove:Add(function()
		onWhiteRetro:Destroy()
	end)

	undoEmulator()
	undoColorCorrection()

	if setAtmosphereHidden then
		setAtmosphereHidden(false)
		task.wait(0.5)
	end

	local capture
	local errorWatch, markComplete = SceneControl.cleanupOnError(trove)
	if not setAtmosphereHidden then
		capture = errorWatch(Composers.reverseBlend(onWhiteRetro, onBlackRetro, gradedOnBlack, nil, colorCorrection))
	else
		capture = errorWatch(
			Composers.reverseBlend(
				onWhiteRetro,
				onBlackRetro,
				atmoOnBlackSubject,
				atmoOnBlackBackground,
				colorCorrection
			)
		)
	end

	if options.alphaBleed then
		capture = errorWatch(Composers.alphaBleed(capture))
	end

	markComplete()
	return capture
end

return operation
