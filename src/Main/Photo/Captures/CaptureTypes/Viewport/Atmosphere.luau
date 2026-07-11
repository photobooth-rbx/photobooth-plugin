local Lighting = game:GetService("Lighting")

local pluginRoot = script:FindFirstAncestor("PluginRoot")
local Types = require(pluginRoot.Main.Bindings.Interface.Types)
local Trove = require(pluginRoot.Packages.Trove)

local photoRoot = script:FindFirstAncestor("Photo")
local Screenshot = require(photoRoot.Captures.Screenshot)
local Background = require(photoRoot.Tools.Background)
local SceneControl = require(photoRoot.SceneControl)

local capturesRoot = script:FindFirstAncestor("Captures")
local Composers = require(capturesRoot.Composers)

local NoSkybox = require(script.Parent.NoSkybox)

local function operation(options: Types.CaptureViewportOptions, isFullscreen: boolean?, trove: Trove.Trove)
	if not Lighting:FindFirstChildWhichIsA("Atmosphere") then
		return NoSkybox(options, isFullscreen, trove)
	end

	local isEmulator, undoEmulator = SceneControl.emulatorEnforcement()
	trove:Add(undoEmulator)

	trove:Add(SceneControl.hideScreenUI())
	local colorCorrection = trove:Add(SceneControl.getAppliedColorCorrectionCopy())
	local atmosphere = Lighting:FindFirstChildWhichIsA("Atmosphere")

	local fogBackground = Background.new(workspace)
	fogBackground:setMaterial(Enum.Material.Neon)
	fogBackground:setColor(Color3.new(0, 0, 0))
	fogBackground:setEnabled(true)

	trove:Add(SceneControl.once(function()
		fogBackground:Destroy()
	end))

	-- capture scene w/ atmosphere on black background
	SceneControl.yieldUntilNextFrame()
	local atmoOnBlackSubject = Screenshot.rect(options.rect, isFullscreen, isEmulator)
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
	local atmoOnBlackBackground = Screenshot.rect(options.rect, isFullscreen, isEmulator)
	trove:Add(function()
		atmoOnBlackBackground:Destroy()
	end)

	camera.CFrame = renderCF

	-- prepare for retro scene capturing
	trove:Add(SceneControl.applyRetroLighting())
	fogBackground:setMaterial(Enum.Material.SmoothPlastic)

	-- atmosphere on/off is not instant, there's are a few lighting update frames
	atmosphere.Parent = nil
	trove:Add(function()
		atmosphere.Parent = Lighting
	end)

	task.wait(0.5)

	-- capture on retro black
	SceneControl.yieldUntilNextFrame()
	local onBlackRetro = Screenshot.rect(options.rect, isFullscreen, isEmulator)
	trove:Add(function()
		onBlackRetro:Destroy()
	end)

	-- capture on retro white
	fogBackground:setColor(Color3.new(1, 1, 1))
	SceneControl.yieldUntilNextFrame()
	local onWhiteRetro = Screenshot.rect(options.rect, isFullscreen, isEmulator)
	trove:Add(function()
		onWhiteRetro:Destroy()
	end)

	undoEmulator()

	atmosphere.Parent = Lighting
	task.wait(0.5)

	local errorWatch, markComplete = SceneControl.cleanupOnError(trove)
	local capture = errorWatch(
		Composers.atmosphere(onWhiteRetro, onBlackRetro, atmoOnBlackSubject, atmoOnBlackBackground, colorCorrection)
	)
	if options.alphaBleed then
		capture = errorWatch(Composers.alphaBleed(capture))
	end

	markComplete()
	return capture
end

return operation
